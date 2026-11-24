# Material and geometry workload — 23 November 2026

This is the first measurement step from the [capability review](../design.md#recommended-next-progression).
It isolates the newest material channels and mesh submission costs; the earlier
combined scene workload remains the baseline for scene traversal, caches and shadows.

## Reproduce

From the SDK directory, build sequentially:

```sh
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/material-geometry-metal mod/max2d.mod/benchmarks/material_geometry.bmx
bin/bmk makeapp -r -ud max2d_gl -o /tmp/material-geometry-gl mod/max2d.mod/benchmarks/material_geometry.bmx
/tmp/material-geometry-metal > /tmp/material-geometry-metal.csv
/tmp/material-geometry-gl > /tmp/material-geometry-gl.csv
/tmp/material-geometry-gl --gpu > /tmp/material-geometry-gl-gpu.csv
```

Run executables separately. `--quick` runs three measured frames after two warmup
frames, one trial per case, for correctness checks only. Defaults are three trials
of thirty measured frames, each preceded by eight warmup frames. The harness is
BlitzMax and creates all artwork procedurally. Windows profiles `max2d_d3d9` and
`max2d_d3d11` are included in the source but were not run for this report.

The checked-in runs used release macOS arm64 builds on an Apple M4 Max, 40 GPU
cores, 64 GB RAM, macOS 27.0.1 (26A434). They exercise SDL3 GPU/Metal and native
OpenGL on the same machine. No hardware or cross-engine performance parity is
implied. Raw results:

- [Metal baseline](2026-11-23-material-geometry-metal.csv)
- [OpenGL baseline](2026-11-23-material-geometry-gl.csv)
- [Separate OpenGL GPU-query run](2026-11-23-material-geometry-gl-gpu.csv)

Each run contains 228 rows: three trials of 72 rendering cases and four CPU
packing cases. Every run ends with the successful cleanup marker; failures exit
with a nonzero status.

## Workload and measurement boundaries

Rendering always covers a 256×256 offscreen target. Geometry is either one scaled
sprite, sixteen tiled sprites sharing one material, or one mesh subdivided into
2, 8, 32 or 128 triangles. The mesh's affine UV mapping and total coverage stay
constant. One or seventeen directional lights exercise one and multiple groups.
Materials use 64×64 normal/maps and uniform specular response in every case:

| Case | Additional material work |
| --- | --- |
| `uniform` | Uniform source-coloured emission, no extra maps. |
| `emission` | Unchanged emission map. |
| `specular` | Unchanged separate specular map. |
| `both` | Both unchanged maps. |
| `edit_specular` | Change one specular pixel through `ReplacePixels` every frame. |
| `edit_emission` | Change one emission pixel through `ReplacePixels` every frame. |

Edits invalidate a complete image; this is not a partial-upload benchmark.
The CPU-only packing cases call `TMax2DLightingMaterialMap.Update` with unchanged
or edited inputs at 64×64 and 256×256. They never draw/upload the packed output.
They isolate builder cost but do not measure the complete material rendering path.

`edit_us` measures source mutation. `draw_us` measures clear, drawing and explicit
flush, including any lazy packing/upload and, in the query run, timer submission.
The CPU packing rows use that column for the builder call instead. `drained_us`
includes the entire measured loop and a final one-pixel readback for rendering
cases, following an initial drain outside the measured interval. It includes driver
waits and instrumentation; it is not GPU time. Presentation is outside measurement.
The short trials show substantial queue/drain variation, so submission counters
are stronger evidence than small timing differences between materials.

Managed allocation uses cumulative GC byte deltas around edit and draw only.
Printing, pixel validation, final readback, GPU polling and explicit collections
are excluded from these deltas. Post-collection heap use includes collector
accounting and conservative retention. Texture/update counters are totals per
trial; columns labelled `per_frame` are averages. Uploaded pixels describe core
uploads, not native driver bandwidth. Native submission counts are Max2D batches,
not a guarantee about the number of low-level driver calls.

## Geometry results

Median CPU submission time across three trials, with seventeen lights and the
uniform material. Allocation and submission counts matched on both backends.

| Geometry | Submissions/frame | Managed bytes/frame | Metal draw µs/frame | OpenGL draw µs/frame |
| --- | ---: | ---: | ---: | ---: |
| One sprite | 2 | 32 | 1.08 | 10.04 |
| 2 triangles | 4 | 64 | 1.88 | 17.03 |
| 8 triangles | 16 | 256 | 6.44 | 107.64 |
| 32 triangles | 64 | 1,024 | 25.52 | 223.28 |
| 128 triangles | 256 | 4,096 | 99.73 | 851.35 |

The deterministic result is two groups per triangle, even though every mesh
covers the same square. Adding an emission map changes that to three submissions
per triangle: two light groups and a separate mapped ambient pass. Unchanged
separate specular maps do not add passes or uploads.

Whole-mesh lighting is therefore a justified next optimisation. It should preserve
the existing per-triangle UV/normal/world mapping semantics while reducing repeated
submission and material setup. These data do not predict a particular speedup for
arbitrary deformed meshes, shadow-heavy scenes or other hardware.

## Shared and edited materials

Seventeen lights, sixteen sprites sharing one material; median draw interval:

| Case | Submissions/frame | Managed bytes/frame | Uploads/frame | Metal draw µs | OpenGL draw µs |
| --- | ---: | ---: | ---: | ---: | ---: |
| Uniform | 32 | 512 | 0 | 12.05 | 103.88 |
| Emission map | 48 | 768 | 0 | 14.86 | 177.93 |
| Specular map | 32 | 512 | 0 | 12.04 | 104.48 |
| Both maps | 48 | 768 | 0 | 15.56 | 148.52 |
| Edited specular | 32 | 912 | 1 | 96.45 | 175.63 |
| Edited emission | 48 | 1,024 | 1 | 78.30 | 198.19 |

Every edited rendering case uploads 4,096 pixels per frame, including shared
materials and meshes. Unchanged cases have zero uploads. All measured cases have
zero new textures. Packing/upload invalidation is thus shared, rather than
repeated once per receiver or triangle. This supports keeping the existing packing
fallback for compatible static artwork even if native material sampling is extended.

## Isolated CPU packing

| Input | Metal-run builder µs | OpenGL-run builder µs | Managed bytes/iteration |
| --- | ---: | ---: | ---: |
| Unchanged 64×64 | 0.035 | 0.021 | 0 |
| Edited 64×64 | 28.12 | 29.49 | 288 |
| Unchanged 256×256 | 0.025 | 0.021 | 0 |
| Edited 256×256 | 429.24 | 462.98 | 288 |

These are CPU operations; the backend labels identify the surrounding run, not a
GPU implementation. Sub-microsecond unchanged-call times should be treated as
timer/instrumentation-scale observations. The unchanged builder allocates no
measured managed bytes. Edited inputs rebuild the full image, approximately
scaling with area here, while preserving output identity. Source replacement is
timed separately (roughly 0.4 µs at 64×64 and 4.4–4.5 µs at 256×256).

## GPU timing

The separate OpenGL query run collected 6,478 samples, with two still pending at
the end of their trials, zero rejected submissions and zero discarded samples.
Pending samples are reported and released without waiting indefinitely. Medians
of per-trial mean elapsed GPU intervals for uniform material/seventeen lights were
63.48 µs for one sprite, then 58.15, 85.49, 224.89 and 414.39 µs for 2/8/32/128
triangles. These intervals bracket clear and drawing and can include command-stream
gaps; they are not isolated shader execution or pure GPU busy time. Query overhead
and differing queue behaviour mean they should not be subtracted from baseline
CPU intervals. The bundled SDL GPU API has no timestamp provider, so Metal has no
equivalent GPU-query result here.

## Correctness and cleanup

Before measurement, each mesh is compared against an equivalently scaled sprite
over all 256×256 pixels, allowing three units per channel. Every measured rendering
case verifies grouped lighting, absence of ordinary fallback, exact group/ambient
counts, warmed texture reuse and expected edit uploads. Packing checks preserve
output identity. After every workload, derived material/builder storage and source
images are released, the native release queue is drained, the frame registry count
must return to its starting value, and charged shadow/light-atlas storage must be
zero. These cases have no shadows/projected light atlas; they do not remeasure
those caches. Native driver memory and RSS are outside this accounting.

The first cleanup check exposed a bookkeeping error: `DrainReleases` removed links
directly, leaving `TList.Count()` stale if it had already been queried. It now uses
`frames.RemoveLink(link)` to update the list's cached count. Resources had been
disposed; the defect was in registry count reporting. Every workload primes and
checks that count, providing regression coverage on Metal and OpenGL.
The existing SDL GPU resource-lifetime test also passes with explicit cached-count
checks after deferred release and context closure.

This is a bounded measurement, not another 60,000-frame soak or a general leak
proof. It does not cover scene preparation/picking, live subtree edits, atlas
pressure, shadows, HDR, arbitrary UV deformation or newest-feature performance on
Windows/Linux. The existing correctness suites cover broader material semantics.

## Next step

Proceed with whole-mesh lighting, using this harness for unchanged coverage,
pass counts, allocation, pixel parity and cleanup. Follow with native material
sampling: mapped ambient has an explicit extra-pass cost, while dynamic CPU
packing becomes substantial at larger resolutions. Retained render groups address
different scene CPU costs and should retain their own measured design step.
