# Reusing unchanged effect stages

Follow-up to the [combined workload baseline](2026-11-22-workload.md), measured
on the same M4 Max/macOS installation on 22 November 2026. Build and run commands,
scene contents, three 120-frame trials and the 20 × 3,000-frame allocation soak
are unchanged. The mask-only assertion now expects one stage update.

Raw results: [Metal](2026-11-22-stage-reuse-metal.csv),
[OpenGL](2026-11-22-stage-reuse-gl.csv). Both complete runs passed.

## Implementation

Automatic composites retain references to their existing stage outputs and track
the earliest invalidated stage. On an unchanged canvas, only that stage and its
successors need preparation and processing. A changed source still processes the
whole chain. Canvas changes, stage-list replacement/reordering, release and
failure discard prefix reuse. Explicit `InvalidateEffects()` refreshes all stages.
No extra render images are allocated. See [composition caching](../composites.md).

## Mask-only comparison

Median CPU microseconds per frame across three trials. These timings include
submission and possible driver waits; drained intervals also include block-end
readback and diagnostic overhead. They are not GPU timings or frame-rate estimates.

| Metric | Before | After |
| --- | ---: | ---: |
| Stage updates/frame, both backends | 2 | 1 |
| Submissions/frame, both backends | 11 | 6 |
| Managed bytes/frame, both backends | 5,616 | 2,464 |
| Metal render submit, µs/frame | 15.96 | 9.17 |
| Metal drained interval, µs/frame | 188.27 | 143.79 |
| OpenGL render submit, µs/frame | 218.59 | 94.93 |
| OpenGL drained interval, µs/frame | 258.96 | 149.35 |

The deterministic savings are one stage update, five submissions and 3,152 managed
bytes per mask-only frame (56.1% less allocation). Source capture remains reused.
Desktop timing varies between runs; the counters and pixel comparisons establish
the removed work more directly than a timing percentage.

## Combined allocation soak

Both backends completed another 60,000 combined frames. The combined case changes
source pixels and therefore still updates both stages: 143 submissions, one
capture, two stages, 128 grouped receiver passes and two shadow rebuilds per frame.
Allocation fell from 11,920 to 11,504 bytes/frame; unchanged stage preparation can
be skipped even when source changes require processing. Cached and lights-only
allocation stayed at 624 and 11,136 bytes/frame respectively.

| Metric | Metal | OpenGL |
| --- | ---: | ---: |
| Median render submit, µs/frame | 198.63 | 891.61 |
| Median drained interval, µs/frame | 257.60 | 916.48 |
| In-use heap after collection, bytes, every block | 1,564,672 | 1,572,864 |
| Collector heap, bytes, every block | 11,829,248 | 11,829,248 |
| Natural collections in measured intervals | 61 | 61 |

There were no new textures or texture uploads in any measured case. Retained scene,
shadow and map storage remained 6,088,640, 131,072 and 16,777,216 bytes respectively,
and all charged storage returned to zero on cleanup. Post-collection in-use heap
was stable within each run, 4,096 bytes above the respective baseline. These are
collector-accounted quantities, not exact object payload or process memory.

The combined case shows no timing improvement established by these runs; its
render work is unchanged and remains the dominant CPU interval. The useful gain
is concentrated in effect-only edits. This finite checkpointed soak is not a
proof against leaks in other workloads.

## Correctness coverage

`tests/scene_composite.bmx` passed 65 checks on each of Metal and OpenGL, including:

- Final-stage and middle-stage edits, multiple invalidations and explicit full refresh.
- Pixel-for-pixel equality of reused bloom plus a moved mask against full processing.
- Changed bloom padding, source content, resolution, reordered stages and release.
- A deliberately failing suffix stage, restored render target, released retained
  storage and successful recovery with a full capture and processing.
- Existing nested caches, clipping, transforms, context replacement and warm allocation checks.

This tranche changes shared scene composition code. The measurements above cover
Metal/OpenGL only. Subsequent [Direct3D validation](../validation/2026-11-23-d3d-materials.md)
confirms the composition regression suite on D3D9 and D3D11 under Windows/Parallels;
those functional checks add no timing evidence. The SDL renderer provider was not
rerun for this change. Remaining managed allocations and richer material/shader support
are separate work from this bounded cache optimisation.
