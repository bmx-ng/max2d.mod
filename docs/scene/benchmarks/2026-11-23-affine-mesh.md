# Affine mesh lighting — 23 November 2026

This implements the first part of step 2 in the [recommended progression](../design.md#recommended-next-progression).
With light batching enabled, eligible meshes now share their lighting setup and
submissions across all triangles. The native shader layouts and material samplers
are unchanged. Arbitrarily deformed meshes still use the existing triangle path.

## Eligibility and ownership

A mesh is eligible when it contains 2–512 triangles, every triangle has exactly
the same nonsingular UV-to-geometry affine mapping, and no triangle interiors
overlap. Shared boundaries and either winding are allowed. This includes regular
subdivisions of a plane, including mirrored/sheared affine geometry. Exact basis
comparison is intentionally conservative; floating-point geometry that only
approximately shares a mapping can use the fallback.

The processor retains one value snapshot of XY, UV and index data. It does not
retain the caller's mesh object. Warm draws compare values, so direct array edits
and replacement arrays cannot silently reuse stale analysis. Array storage is
reused when it fits, with larger snapshots allocated on demand. `Release()` drops
the snapshot. This CPU storage is additional to the existing triangle scratch and
is not charged to scene render-texture budgets.

Initial overlap analysis is quadratic, bounded by the 512-triangle limit. It is
performed in UV space after verifying a common invertible geometry mapping.
Unchanged geometry uses linear comparisons. Geometry-only edits can reuse the
UV/index overlap result; changed UVs or indices require new analysis. Alternating
different mesh topologies in one processor may repeatedly rebuild this single
cache. The timings below measure warmed analysis, not that cold cost.

The new optional provider capability `AffineMeshGeometry()` requires
`MeshGeometry()` and defaults to false. Existing mesh providers receive single
triangles exactly as before. Opting-in providers may receive several disjoint
triangles sharing one basis and must consume all borrowed indices before returning.
Native providers opt in. Unsupported light/material combinations can still use
ordinary shaders on eligible geometry. The optimization never groups overlapping
triangles across passes, which would change translucent painter-order results.

Application code continues to use `DrawMesh`, `TLitMeshNode` and
`SetLightBatching(True)`. Scene callers must still call `InvalidateContent()` after
raw geometry edits; immediate lighting's value checks do not invalidate an already
cached scene composite.

## Reproduce

Use the same [material/geometry harness and methodology](2026-11-23-material-geometry.md)
as the baseline, at this revision. The harness now expects one receiver submission
unit per eligible affine mesh, while retaining all pixel and cleanup checks.

```sh
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/material-geometry-metal mod/max2d.mod/benchmarks/material_geometry.bmx
bin/bmk makeapp -r -ud max2d_gl -o /tmp/material-geometry-gl mod/max2d.mod/benchmarks/material_geometry.bmx
/tmp/material-geometry-metal > /tmp/affine-mesh-metal.csv
/tmp/material-geometry-gl > /tmp/affine-mesh-gl.csv
/tmp/material-geometry-gl --gpu > /tmp/affine-mesh-gl-gpu.csv
```

Build and run sequentially. The pre-change harness/results are available at commit
`d358018`. The host remains an Apple M4 Max with 40 GPU cores and 64 GB RAM, macOS
27.0.1 (26A434), release arm64 builds. Each file contains 228 rows: three trials of
72 rendering cases and four CPU packing cases. Each trial has eight warmup frames
and thirty measured frames. Raw results:

- [Metal](2026-11-23-affine-mesh-metal.csv)
- [OpenGL](2026-11-23-affine-mesh-gl.csv)
- [Separate OpenGL GPU-query run](2026-11-23-affine-mesh-gl-gpu.csv)

## Measured work reduction

Fixed 256×256 coverage, seventeen directional lights, uniform material:

| Triangles | Submissions before → after | Managed bytes/frame before → after | Metal draw µs before → after | OpenGL draw µs before → after |
| --- | ---: | ---: | ---: | ---: |
| 2 | 4 → 2 | 64 → 32 | 1.88 → 1.21 | 17.03 → 10.59 |
| 8 | 16 → 2 | 256 → 32 | 6.44 → 1.41 | 107.64 → 10.53 |
| 32 | 64 → 2 | 1,024 → 32 | 25.52 → 2.39 | 223.28 → 11.53 |
| 128 | 256 → 2 | 4,096 → 32 | 99.73 → 6.44 | 851.35 → 14.70 |

Times are medians of per-trial means. Submission/allocation counts matched on both
backends. The remaining CPU time still grows with validation, value comparison,
geometry conversion and vertex submission. This is not constant-cost rendering.

Mapped emission now adds one ambient submission for an eligible whole mesh. For
128 triangles and seventeen lights, that changes 384 submissions to 3; uniform
emission remains combined with the first light group. Separate specular maps still
reuse their packed image; edits upload once per frame. Every measured case created
zero textures after warmup, and every workload passed its release/accounting checks.

For 128 triangles, the baseline/optimized drained CPU intervals were 308.18/51.12 µs
on Metal and 1,062.76/259.56 µs on OpenGL. These short intervals include the final
readback and queue waits; they are not presentation times or isolated GPU costs.
For small meshes, drain variation can overwhelm the saved submission work. No
production frame-rate guarantee follows from these figures.

The separate OpenGL GPU-query run collected all 6,480 rendering samples with zero
pending, rejected or discarded samples. For 128 triangles, the median of per-trial
mean elapsed GPU intervals changed from 414.39 to 66.28 µs. Those intervals include
clear/draw commands and possible command-stream gaps; the shader itself is
unchanged. Metal GPU timestamps remain unavailable through the bundled SDL API.

## Correctness coverage

`tests/lighting_affine_mesh.bmx` compares an opt-in renderer with a wrapper around
the same native renderer that advertises triangle-only support. Its 76 checks
cover capability defaults/validation, complete pixel comparisons, exact pass
counts, shared normal/specular/emission materials, filtered shadows and projected
patterns, translucent artwork, affine lighting transforms, drawing rotation/scale,
handles, tint/alpha, clipping, reversed winding and reflection. Raw XY/UV/index
edits exercise deformation and overlapping fallback, geometry-only updates,
restored eligibility, repeated cached draws and invalid-UV rejection before drawing.
Release and subsequent drawing recreate the analysis.

The existing mesh suite also covers unlit drawing, trimmed artwork, image handles,
deformed receivers, scene cache invalidation and image-only provider fallback.
The material-map suite expects one grouped draw for its eligible two-triangle mesh.
The benchmark compares every subdivided mesh against a scaled sprite and verifies
group/ambient counts, uploads, texture reuse and native frame-registry cleanup.

[Completed validation runs](../validation/2026-11-23-affine-mesh.csv) record:

| Suite | Metal | OpenGL | D3D9 | D3D11 |
| --- | ---: | ---: | ---: | ---: |
| Affine mesh | 76 | 76 | 76 | 76 |
| Existing mesh lighting | 96 | 96 | 96 | 96 |
| Material maps | 61 | 61 | 61 | 61 |
| Scene lighting | 1,050 | 1,050 | 1,050 | 1,050 |

All checks passed. Windows release x64 executables ran under Windows 11 ARM64 in
Parallels; those are functional checks, not native Windows hardware performance
measurements. The focused test is registered for all four shader-capable regression
profiles. Build it from the SDK with `bin/bmk makeapp -r -ud max2d_sdlgpu -o
/tmp/lighting-affine mod/max2d.mod/tests/lighting_affine_mesh.bmx`, replacing the
profile and output path as appropriate, then run the executable.

## Remaining step-2 work

General deformed meshes have different UV-to-world and normal bases across
triangles. Supporting those in one submission requires geometry/shader transport
for that varying data, with explicit backend capabilities and a correct fallback.
Overlapping geometry also needs ordered partitioning or continued triangle drawing.
The 512-triangle bound, cold-analysis cost and single-cache behaviour should be
revisited against representative applications. This tranche does not claim those
problems are solved or mark the broader whole-mesh step complete.
