# Render allocation attribution and alpha-mask scopes — 23 November 2026

The scene workload now accepts `--allocation-detail`. Benchmark-only subclasses
measure allocations inside lit-receiver draws, bloom-stage updates and alpha-mask
updates. These intervals do not overlap; the remaining render allocation is
reported separately. Production rendering has no new instrumentation.

## What allocates during a redraw

On the same macOS arm64 host used in the
[text-cache follow-up](2026-11-23-text-cache.md), both Metal and native OpenGL report
the following bytes/frame before this change:

| Workload | Lit receivers | Bloom | Alpha mask | Other render work | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cached | 0 | 0 | 0 | 32 | 32 |
| Mask changes | 0 | 0 | 1,472 | 400 | 1,872 |
| Lighting changes | 5,568 | 2,736 | 1,472 | 432 | 10,208 |
| Combined changes | 5,568 | 2,736 | 1,472 | 800 | 10,576 |

Receiver measurements include any lazy lighting preparation and shadow updates
triggered during their draw calls. They are not exclusively per-sprite submission
costs. Bloom and mask measurements include their nested effects and state saves.
The remainder includes composite orchestration, capture and presentation; it is
not yet individually attributed.

## Removing redundant mask state saves

The alpha-mask stage had an outer drawing-state scope and two nested scopes for
its coverage and output passes. Each pass already establishes its view and drawing
settings, and no caller code runs between them. The nested saves/restores are now
removed; the outer scope restores the caller once, on both success and failure.
The masking operation's own scope remains intact.

This removes two 368-byte scopes per update on the measured host:

| Workload | Before, bytes/frame | After, bytes/frame |
| --- | ---: | ---: |
| Cached | 32 | 32 |
| Mask changes | 1,872 | 1,136 |
| Lighting changes | 10,208 | 9,472 |
| Combined changes | 10,576 | 9,840 |

The mask stage itself falls from 1,472 to 736 bytes/update. Other measured components
are unchanged. All three trials on both backends return identical byte counts.
Plain runs with detail mode disabled return the same total allocations as the
detailed runs, demonstrating that this instrumentation adds no measured allocation.

All workload runs pass warm-texture, stable resource-charge and cleanup checks.
The alpha-mask regression passes 43 checks on each backend, including normal and
inverse mask pixels, resolution changes, cache invalidation, picking and resource
release. New direct-update checks verify target, virtual dimensions, clip, colour,
camera, transforms and stack depth after success, after a locked-mask draw failure,
and after a subsequent successful retry.

These are managed allocation measurements, not a claim of improved frame rate.
Windows/Linux and a new 60,000-frame soak were not run. The next attribution targets
are the 5,568 bytes in receiver drawing and 2,736 in bloom during group redraws.

## Reproduce and interpret

Build `tests/scene_workload.bmx` in release mode using `-ud max2d_sdlgpu` or
`-ud max2d_gl`, as shown in the
[baseline commands](2026-11-23-material-refresh.md#reproduce). Run sequentially:

```sh
/tmp/scene-metal --trials-only --allocation-detail > detailed.csv
/tmp/scene-metal --trials-only > plain.csv
```

The workload retains three 120-frame trials per case. `--quick` remains available
for a smoke check. Detail mode appends `allocation_detail`,
`receiver_bytes_per_frame`, `bloom_bytes_per_frame`, `mask_bytes_per_frame` and
`other_render_bytes_per_frame`. With detail disabled the three component counters
are zero (unmeasured), and `other_render_bytes_per_frame` contains the entire render
total. Extra GC-counter reads occur inside the render timing interval in detail
mode; do not compare those timings with ordinary runs as a performance result.

| Backend | Before, detailed | After, detailed | After, plain |
| --- | --- | --- | --- |
| Metal | [CSV](2026-11-23-render-attribution-before-metal.csv) | [CSV](2026-11-23-render-attribution-after-sdlgpu.csv) | [CSV](2026-11-23-render-attribution-plain-sdlgpu.csv) |
| OpenGL | [CSV](2026-11-23-render-attribution-before-gl.csv) | [CSV](2026-11-23-render-attribution-after-gl.csv) | [CSV](2026-11-23-render-attribution-plain-gl.csv) |
