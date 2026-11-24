# Native materials and scene allocation — 23 November 2026

The completed material path at `48bfcd2` now combines mapped ambient with lighting
and samples separate gloss directly. This refresh compares native specular sampling
against forced CPU packing **in the same build**, with all other capabilities
unchanged. It also begins step 4 of the [progression](../design.md#recommended-next-progression)
by attributing scene allocations to individual phases.

## Findings

- Edited 256×256 gloss maps show a substantial CPU submission reduction on both
  measured backends. Static maps show no consistent timing improvement.
- Both paths still upload the whole edited map once per frame. Independent
  sampling removes packing work, not the source upload or lighting submissions.
- Edited shared gloss allocates 144 fewer managed bytes per frame. Warm unchanged
  materials have identical allocation and submission counts on both paths.
- Scene editing, lighting preparation and picking allocate zero measured bytes in
  this workload. Rendering accounts for the remaining 624–11,504 bytes/frame.
- Isolated probes identify 368 bytes per drawing-state scope and 32 bytes per
  cached text draw. These are concrete allocation targets before expanding the
  retained-rendering design.

## Reproduce

Build release applications sequentially from the SDK directory:

```sh
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/material-metal mod/max2d.mod/benchmarks/material_geometry.bmx
bin/bmk makeapp -r -ud max2d_gl -o /tmp/material-gl mod/max2d.mod/benchmarks/material_geometry.bmx
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/scene-metal mod/max2d.mod/tests/scene_workload.bmx
bin/bmk makeapp -r -ud max2d_gl -o /tmp/scene-gl mod/max2d.mod/tests/scene_workload.bmx
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/allocations-metal mod/max2d.mod/benchmarks/render_allocations.bmx
bin/bmk makeapp -r -ud max2d_gl -o /tmp/allocations-gl mod/max2d.mod/benchmarks/render_allocations.bmx
```

For each material executable, run these separately:

```sh
/tmp/material-metal > native-64.csv
/tmp/material-metal --packed > packed-64.csv
/tmp/material-metal --large-maps > native-256.csv
/tmp/material-metal --large-maps --packed > packed-256.csv
```

Repeat with `/tmp/material-gl`. Run separate GPU-query trials with
`/tmp/material-gl --gpu` and `/tmp/material-gl --gpu --packed`. For allocation
attribution, run each scene executable with `--trials-only`, then each allocation
probe executable without arguments. `--quick` remains a correctness smoke mode
for the material and scene workloads. The scene workload's default still includes
its existing 60,000-frame soak; `--trials-only` deliberately omits that soak.

The runs use the same macOS arm64 host as the earlier material baseline, on macOS
27.0.1 (26A434), with SDL GPU/Metal and native OpenGL. Windows/Linux performance
was not measured. Every graphics run executes separately, with no presentation
inside its measured interval.

## Raw results and boundaries

Each material CSV has 228 rows: three trials of 72 rendering cases and four
isolated CPU-packing cases. Trials use eight warmup frames and thirty measured
frames. `--large-maps` changes rendering maps to 256×256; the CPU-only builder
cases still cover both 64×64 and 256×256. `forced_packing` records the selected
provider capability. The provider wrapper changes only `MappedSpecular`; current
whole-mesh and ambient-composition paths are used in both modes.

| Backend | 64×64 native / packed | 256×256 native / packed |
| --- | --- | --- |
| Metal | [native](2026-11-23-material-refresh-sdlgpu-64-native.csv) / [packed](2026-11-23-material-refresh-sdlgpu-64-packed.csv) | [native](2026-11-23-material-refresh-sdlgpu-256-native.csv) / [packed](2026-11-23-material-refresh-sdlgpu-256-packed.csv) |
| OpenGL | [native](2026-11-23-material-refresh-gl-64-native.csv) / [packed](2026-11-23-material-refresh-gl-64-packed.csv) | [native](2026-11-23-material-refresh-gl-256-native.csv) / [packed](2026-11-23-material-refresh-gl-256-packed.csv) |

The [original measurement boundaries](2026-11-23-material-geometry.md#workload-and-measurement-boundaries)
still apply. `draw_us` includes clear, drawing, flush, lazy preparation and driver
waits. `drained_us` additionally includes source editing, instrumentation and final
readback. Neither is pure GPU time. Values below are medians of three per-trial
means; trial ordering is fixed, not randomized. Small timing differences should
not be read as established improvements.

The rendering cases use directional lights without occluders or projected maps.
They do not remeasure atlas pressure, shadow rebuilds, arbitrary mesh deformation,
HDR, or different hardware. Native/packed pixel parity is checked outside measured
intervals, as is mesh/sprite parity. Material storage used by the reference draw
is discarded before warmup. Every trial checks exact group/ambient counts,
zero new textures and expected upload counts. Every case checks native image-frame
and charged lighting-storage cleanup. All fourteen result files completed their
checks successfully; this is a bounded measurement, not a new general leak proof.

## Edited versus unchanged gloss

Sixteen receivers share one material and seventeen lights. Both modes submit
32 batches/frame. Editing changes one pixel but invalidates/uploads the whole map.

| Backend | Map | Packed draw µs | Native draw µs | Packed drained µs | Native drained µs |
| --- | --- | ---: | ---: | ---: | ---: |
| Metal | Edited 64×64 | 100.05 | 74.45 | 109.96 | 81.41 |
| Metal | Edited 256×256 | 591.06 | 104.64 | 604.12 | 116.47 |
| OpenGL | Edited 64×64 | 180.08 | 178.50 | 303.73 | 299.49 |
| OpenGL | Edited 256×256 | 663.20 | 180.18 | 822.19 | 316.19 |

Edited gloss allocates **912 → 768 managed bytes/frame** on both backends and at
both sizes. Uploads remain one per frame: 4,096 or 65,536 pixels. Unchanged gloss
allocates 512 bytes/frame, uploads nothing and creates no textures on either path.

For unchanged 64×64 gloss, Metal draw times are 14.02 µs packed and 14.01 µs native;
OpenGL is 105.70 versus 131.35 µs. At 256×256 they are 14.01 versus 14.08 µs on
Metal and 127.74 versus 125.08 µs on OpenGL. These runs support the dynamic-map
benefit, not a general claim that five samplers are faster. Native sampling also
uses original normal and gloss textures instead of a single derived texture;
these counters do not establish a reduction in total GPU memory.

## Combined effect of recent geometry/material work

All current eligible affine meshes use two submissions and 32 managed bytes/frame
for seventeen lights with both emission and specular maps, regardless of whether
they contain 2, 8, 32 or 128 triangles. Both backends agree on those counts.
The original 128-triangle mapped-emission baseline used 384 submissions and 6,144
bytes/frame. This reduction belongs to the combined whole-mesh and ambient work;
forcing packing in the current renderer also retains the new two-submission path.
Independent gloss does not reduce that submission count further.

Value checking and geometry preparation still cost CPU time as triangle count
grows. On Metal the current both-map draw interval rises from 1.35 µs at two
triangles to 6.13 µs at 128. OpenGL submission timing varies substantially across
these short cases; the raw rows retain that variation rather than implying a
monotonic speed curve.

## Separate OpenGL GPU-query runs

[Native](2026-11-23-material-refresh-gl-gpu-native.csv) and
[packed](2026-11-23-material-refresh-gl-gpu-packed.csv) each collected 6,480 samples,
with no pending, rejected or discarded samples. For sixteen receivers and seventeen
lights, median query intervals in microseconds were:

| Material | Packed | Native |
| --- | ---: | ---: |
| Unchanged gloss | 192.00 | 202.42 |
| Unchanged emission and gloss | 199.51 | 199.88 |
| Edited gloss | 274.76 | 247.50 |

Queries bracket clear and drawing, including command-stream gaps. They are not
isolated shader busy time; CPU packing can affect command availability. The
small static differences are insufficient to claim a GPU throughput improvement.
Metal has no equivalent query result with the bundled SDL GPU API.

## Scene allocation attribution

The scene workload retains its 1,000 cached background sprites, 128 lit receivers,
eight lights, two shadow lights, four occluders, bloom/mask composition and eight
HUD labels. The new counters bracket editing, lighting preparation, picking and
rendering separately, and assert that the phase deltas sum to the total.
Extra GC-stat reads sit outside each phase's timing but remain in the drained
interval. That instrumentation differs from earlier timing snapshots.

[Metal](2026-11-23-material-refresh-scene-sdlgpu.csv) and
[OpenGL](2026-11-23-material-refresh-scene-gl.csv) each contain three 120-frame
trials of four cases. Measured managed bytes/frame agree exactly:

| Case | Editing | Prepare | Picking | Render | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cached | 0 | 0 | 0 | 624 | 624 |
| Mask-only edit | 0 | 0 | 0 | 2,464 | 2,464 |
| Lights-only edit | 0 | 0 | 0 | 11,136 | 11,136 |
| Combined edit | 0 | 0 | 0 | 11,504 | 11,504 |

Zero allocation does not mean zero CPU cost. Picking still takes roughly 12–15 µs
in this workload. Retained scene/shadow/atlas storage stays at 6,088,640 / 131,072 /
16,777,216 bytes, with no new textures or uploads. Charged storage returns to zero
on cleanup. This run omits the long soak; its allocation counts match the earlier
[stage-reuse soak](2026-11-22-stage-reuse.md).

## Isolated render allocations and next implementation

The new `render_allocations.bmx` probes perform three trials of 2,000 calls per
case after 32 warmup calls, flushing each call. They report allocation rather than
timing. [Metal](2026-11-23-material-refresh-allocations-sdlgpu.csv) and
[OpenGL](2026-11-23-material-refresh-allocations-gl.csv) agree:

| Operation | Managed bytes/call |
| --- | ---: |
| Flush only | 0 |
| Open and close a drawing-state scope | 368 |
| Render an empty scene/layer | 368 |
| Render a scene with one sprite | 368 |
| Render a scene with eight cached text nodes | 624 |

The 256-byte text increment is 32 bytes per node in these cases. Inspection finds
that a layout-cache hit removes its old LRU list entry and allocates a new entry.
Drawing-state scopes construct a scope, saved entry, state copy and stack link.
The probe measurements account for the cached scene's entire 624-byte baseline;
they do not attribute every allocation inside effects or lighting.

The first implementation target is reusable **internal drawing-state snapshots**
for scene/composition rendering, with explicit nesting, exception recovery,
context-lifetime and borrowed-reference tests. Public scopes must retain their
idempotent close and outer-scope unwind guarantees; blindly pooling exposed scope
objects could make an old reference close a later save. Cache-hit LRU bookkeeping
is the next smaller target. Rerun these probes and the combined workload after
changes before attempting instruction retention. Retained groups remain useful
for measured traversal/submission costs, but do not by themselves remove these
scope and text allocations.
