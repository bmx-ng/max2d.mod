# Scene performance and allocation measurements

The benchmark in [scene_benchmark.bmx](../../tests/scene_benchmark.bmx) measures
warmed scene operations and compares retained sprite rendering with equivalent
immediate Max2D drawing. It is a developer measurement tool, not a frame-rate
demo or a timing-based regression gate.

[Initial macOS results and raw measurements](benchmarks/2026-11-21-macos-arm64.md)
are available for SDL3 GPU/Metal and OpenGL.

The [effect support-check follow-up](benchmarks/2026-11-21-effects.md) records
lower bloom allocation after removing unnecessary drawing-state saves.

## Running it

From the BlitzMax SDK directory:

```sh
bin/bmk makeapp -r -o /tmp/scene_benchmark mod/max2d.mod/tests/scene_benchmark.bmx
/tmp/scene_benchmark > /tmp/scene_benchmark_sdlgpu.csv

bin/bmk makeapp -r -ud max2d_gl -o /tmp/scene_benchmark_gl mod/max2d.mod/tests/scene_benchmark.bmx
/tmp/scene_benchmark_gl > /tmp/scene_benchmark_gl.csv
```

Build both executables before measuring. Run them separately, without concurrent
builds or other benchmark runs. Close animated demos and leave the machine
otherwise quiet. Choose appropriate executable paths on Windows/Linux.
The default profile is SDL3 GPU; OpenGL links SDL3 only for its nanosecond clock.

Pass `--logic` to run update, transform and pointer tests without opening a
graphics window. Use release builds for representative timing. Three trials
are emitted for each workload and size; retain all rows, not just the fastest.

## Workloads

Each scene has a root, layer, spatial parent and either 1,000 or 10,000 leaves.

| Case | One measured operation |
| --- | --- |
| update_idle | Update a tree with no processing callbacks enabled |
| update_callbacks | Update every leaf; callback adds elapsed time to a checksum |
| parent_move_world_queries | Move the parent and query every child's world position |
| all_nodes_move_world_queries | Move every child and query each world position |
| pick_miss | Pick inside the input clip, outside all hit rectangles; exhaustive flat-tree miss |
| captured_pointer_move | Dispatch one move to an already captured node |
| render_empty | Render only root/layer/parent, establishing outer-scope overhead |
| immediate_sprites | Draw every sprite directly with Max2D |
| scene_static | Render the equivalent static sprite tree |
| scene_parent_move | Move the parent and render the uncached tree |
| scene_one_child_move | Move one child and render the uncached tree |
| cached_parent_move | Move a cached composite; reuse finished pixels |
| bloom_parameter | Change bloom intensity; process the retained source |
| bloom_source_move | Move a captured child; capture and process again |

All sprites share one opaque 4x4 image and occupy a non-overlapping grid.
The rendering target is 512x512. Culling is disabled so all leaves participate.
The 1,000-sprite composite captures 500x50 units; the 10,000-sprite composite
captures 500x500 units. Bloom uses threshold 0.3 and radius 4.

Update/query loops warm for 20 operations; graphics loops warm for 12 frames.
Logic iterations scale inversely with tree size, except captured moves use
100,000 iterations per trial. Each graphics trial contains 60 measured frames.
Capacity growth and cold shader/texture setup happen before measurements.

The benchmark checks that the intended pointer is captured, that no warmed
graphics case creates textures, and that cached/effect workloads report the
expected source captures and stage updates. It throws if these paths are not
exercised. Timings themselves have no pass/fail thresholds.

Output includes lines beginning with `#` for backend/checksum metadata.
Skip those lines when loading it as CSV.

## Reading the CSV

- **submit_us:** average microseconds per operation. Graphics cases include clear,
  application mutations/drawing, scene render and Max2D flush. This includes any
  driver waiting within those calls; it is not pure traversal time.
- **drained_us:** graphics interval extended through a one-pixel readback.
  This bounds outstanding work but also includes readback/GC-stat sampling cost.
  It is **not GPU execution time**, a normal present loop, or a prediction of FPS.
  Logic rows use zero because they perform no GPU work.
- **managed_bytes_per_op:** cumulative GC allocation delta during the measured
  operation, divided by iterations. Uses `allocedBytesBeforeGC +
  bytesAllocedSinceGC`, so intervening collections do not reset the total.
- **gc_cycles_in_interval:** collections observed within those same allocation
  intervals. Collections outside them, including in the readback, are excluded.
- **new_textures:** native texture allocations across the warmed graphics trial.
- **batches_per_frame:** backend geometry submissions; not interchangeable with
  scene effect-stage counts.
- **captures_per_frame / stages_per_frame / hits_per_frame:** scene work counters.

Printing, result snapshots, setup and readback allocations are excluded from the
managed allocation interval. The outer scene-render scope and effect machinery
are included. GC bytes are allocator-accounted bytes, not object payload sizes
or live heap size. Native driver allocations are outside these GC statistics.

## Limits

These tests use shallow trees, shared textures, simple geometry and tiny
callbacks. They do not measure deep trees, mixed-texture batching, text shaping,
complex custom drawing, mutation queues, sorting churn, UI layout or production
gameplay. Full-tree picking is deliberately a demanding miss, not an average
interaction workload.

Readback serializes graphics work, and cases run in fixed order. Desktop
scheduling, driver behaviour, cache state and thermal conditions affect results.
Use medians and trial ranges; investigate large changes with repeated runs.
Do not extrapolate these measurements to other workloads, backends or hardware.

A zero-allocation result applies only to the measured warmed operation.
Application callbacks, input adapters, inspection snapshots and effects can
allocate independently. No allocation-free complete-frame promise is made.

## Combined workload and allocation soak

The [combined workload report](benchmarks/2026-11-22-workload.md) adds cached
backgrounds, normal/specular lighting, shadows, bloom, alpha masking, picking
and an unlit HUD. It includes separate CPU intervals, three trials per mutation
case and 60,000 combined frames per backend with collection checkpoints.
See the report for its distinct drain protocol, raw CSV and reproduction steps.

The [stage reuse follow-up](benchmarks/2026-11-22-stage-reuse.md) measures skipping
unchanged bloom when only its following alpha mask changes, with pixel parity
checks and the same combined allocation workload.

## Stable trees and live-mask dependencies

The [scaling investigation](benchmarks/2026-11-23-scene-scaling.md) covers ordinary
versus cached trees, parent/camera motion, partial/full edits, shared mask sources
and dependency depth. It records edit/submission/preparation timing separately,
alongside allocation, resource charges and cache-work assertions.

The [shared-source preparation follow-up](benchmarks/2026-11-24-source-preparation.md)
compares per-render dependency reuse against the same scaling baseline, including
its single-source overhead, retained node memory and regression coverage.
