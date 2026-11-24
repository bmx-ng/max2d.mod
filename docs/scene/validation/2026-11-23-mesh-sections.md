# Consecutive mesh-section lighting

The affine mesh fast path now recognizes consecutive sections within a deformed
mesh. Each section has one exact UV-to-geometry mapping and no overlapping
triangle interiors. Different sections can have different mappings and overlap
each other. Completing all passes for one section before drawing the next keeps
index order and translucent composition intact. Matching nonconsecutive triangles
are never reordered.

This uses the existing `AffineMeshGeometry` provider capability. No shader assets,
public signatures or vertex layouts change. Triangle-only providers receive the
same individual triangles as before. Providers may reject a section in `Supports`,
which uses ordinary lighting for that section.

## Pixel and count checks

`tests/lighting_affine_mesh.bmx` now performs 136 checks. It compares independent
sessions using the same native shaders: one advertises only triangle support,
and the other also advertises affine geometry. RGBA comparisons allow at most
two channel units. The material includes normal/specular maps, mapped emission,
a projected pattern and a filtered shadow, with 17 point lights.

Added cases cover:

- Two differently mapped sections, including overlap across their boundary.
- Interleaved indices that must retain individual draws.
- Raw XY/UV changes, degenerate geometry, winding and reflection.
- Rotation, scale, handle, tint, alpha and clipping on sectioned meshes.
- A 128-triangle bent strip with eight affine sections, repeated warm and after
  a geometry edit.
- Returning to smaller arrays after growing retained storage.
- A provider declining groups, followed by release/recreation and invalid UV edits.

The bent-strip counts are asserted against the triangle-only reference:

| Provider capacity | Reference grouped passes | Section grouped passes |
| --- | ---: | ---: |
| 16 lights | 256 | 16 |
| 8 lights | 384 | 24 |

These are **direct-light grouped passes**. The tested mapped-emission material
also needs a separate ambient/emission pass per triangle or section. Counts are
not elapsed-time, GPU-time or game frame-rate measurements.

The [run results](2026-11-23-mesh-sections.csv) record release-build validation on
macOS arm64 (Metal and OpenGL) and Windows x64 on ARM64 Parallels (D3D9 and D3D11).
Each profile also runs the existing mesh-lighting, material-map and scene-lighting
regressions. This report does not establish coverage on Linux or native Windows
hardware.

## Retained storage and limits

One processor retains coordinate/UV/index snapshots, section boundaries and
section meshes. Section meshes share the coordinate snapshots; their index buffers
are reused when sizes match. The caller's mesh and arrays are not retained.
Warm analysis compares values, so direct array replacement/editing is detected.
`Release()` discards all section storage.

Changed geometry rebuilds section analysis. Unlike the original whole-affine
analysis, it must reconsider section boundaries when only XY changes. Overlap
analysis remains quadratic in the worst case and is bounded to meshes of at most
512 triangles. This tradeoff needs timing measurements for frequently deformed
meshes; the submission counts alone do not establish an animation speedup.

Arbitrary deformation with a different affine basis on every triangle continues
through individual draws. General whole-mesh support remains open work and needs
richer geometry/material transport. The original [affine timing measurements](../benchmarks/2026-11-23-affine-mesh.md)
remain measurements of that earlier fixed-affine workload.

## Reproduction

From the SDK directory:

```sh
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/lighting_affine_mesh mod/max2d.mod/tests/lighting_affine_mesh.bmx
/tmp/lighting_affine_mesh
```

Use `max2d_gl` for OpenGL. On Windows, use `bin/bmk.exe`, `-g x64`, Windows paths
and `max2d_d3d9` or `max2d_d3d11`. Run in an interactive desktop session.
