# Native SDL GPU performance comparison

## What this means for an application

On this Mac, switching to the direct GPU backend did not produce a consistent
whole-frame speed improvement in these workloads. All three paths batched the
same geometry successfully. Choose the native backend for its supported rendering
features; these measurements do not justify promising higher frame rates.

VSync gave the Snowfall-style scene steadier frame intervals than unsynchronised
presentation. Median VSync intervals were approximately 8.33 ms across all paths.
The `Flip(0)` runs still showed substantial presentation pacing, usually with
intervals near 8.3 and 16.7 ms. They therefore do not establish maximum throughput.

## Setup

- Apple M4 Max, macOS 15.7.4 (24G517), 2026-09-27.
- Release builds of Max2D at `c521a90`, plus the comparison harness committed with
  this report. No renderer optimisations were made during measurement.
- SDL_Renderer explicitly requested `metal` or `gpu`; native SDL GPU requested
  `metal`. Captures confirm the selected renderer/native driver.
- Matching 800×600 drawing buffers, linear filtering, no mipmaps.
- Three repetitions, each with 120 warm-up frames and 360 measured frames.
  Backend order rotates between repetitions. No concurrent test/build jobs ran.
- Normal desktop applications and the two idle Parallels VMs remained open;
  this was a desktop measurement, not an isolated performance lab.
- All 36 retained captures passed the window-visibility check. They contain
  12,960 measured frames. This is macOS evidence, not Windows/Linux or D3D12 data.

## Whole-frame times

Values below are the **range of per-run means** across three repetitions, in ms.
Lower means less CPU wall-clock time for a complete application frame. This
includes event handling, deterministic animation, drawing, flushing and `Flip`.

| Workload | SDL_Renderer Metal | SDL_Renderer GPU | Native Metal |
| --- | ---: | ---: | ---: |
| 1,000 Snowfall-style particles, Flip(0) | 11.665–12.289 | 12.336–12.475 | 12.406–12.476 |
| 10,000 atlas sprites, Flip(0) | 11.781–12.474 | 12.360–12.476 | 12.406–12.499 |
| 4,096 separate-texture sprites, Flip(0) | 12.270–12.432 | 12.383–12.499 | 12.383–12.475 |
| 1,000 Snowfall-style particles, Flip(1) | 8.329–11.286 | 8.331–8.333 | 8.331–8.353 |

The unsynchronised results are dominated by presentation pacing. Their bimodal
frame distribution makes a single median particularly sensitive to which side
contains slightly more frames. Means and the raw distributions should be read
together; small differences here are not evidence of greater GPU throughput.

## Snowfall-style VSync consistency

| Backend | Median interval, range (ms) | Per-run p99 intervals (ms) | Worst frame (ms) |
| --- | ---: | ---: | ---: |
| SDL_Renderer Metal | 8.333–8.341 | 9.634, 80.519, 9.491 | 436.155 |
| SDL_Renderer GPU | 8.332–8.338 | 10.171, 9.385, 9.089 | 16.357 |
| Native SDL GPU (Metal) | 8.325–8.345 | 9.099, 9.038, 9.755 | 17.057 |

The second SDL_Renderer Metal VSync run contained a burst of long frames,
including one 436 ms interval. Its other repetitions did not reproduce that
burst. The raw capture is retained; the outlier is neither discarded nor assigned
to a backend defect without further evidence. Native Metal had one interval near
17 ms in its final VSync run. These short captures cannot rule out rare pauses.

## Batching

All backends reported identical Max2D geometry submissions and vertices per frame:

| Workload | Submissions | Vertices |
| --- | ---: | ---: |
| Snowfall-style | 1 | 6,000 |
| Atlas sprites | 8 | 60,000 |
| Separate textures | 4,096 | 24,576 |

Atlas sprites are split at the core vertex-buffer capacity. Separate textures
require ordered texture changes. These counters do not include presentation
blits, driver-internal operations or guarantee identical hardware draw calls.

The split between draw/flush time and Flip time is recorded for diagnostics.
Different backends defer submission at different boundaries, so a shorter drawing
interval alone cannot establish a faster renderer.

## Measurement limits and next work

An earlier unguarded capture abruptly changed to sub-millisecond intervals even
with VSync requested. The user reported no sleep, lock or desktop switch. Its
cause remains unexplained, and that capture is excluded from the tables. The
harness was then extended to record visibility flags and the entire experiment
rerun. Visibility flags cannot detect every compositor or display-state change.

CPU intervals are not GPU timestamps or measured on-screen presentation cadence.
The particle scene is inspired by Snowfall, with a procedural texture and fixed
animation steps; it does not reproduce every detail of the original sample.
VSync here controls presentation timing, not animation speed in a real game.

A useful next experiment would isolate GPU/command-submission throughput from
window presentation, then cover uploads and render-target switching. That would
provide better evidence for specific optimisations than tuning from these paced
window timings. Windows/Linux comparisons should be reported separately, with
VM results distinguished from physical hardware.

## Reproduce and inspect

See [benchmark instructions](../benchmarks/README.md#native-sdl-gpu-comparison).
The [JSON summary](../benchmarks/results/2026-09-27-native-gpu/summary.json) includes
all repetitions. [Raw per-frame CSVs and stderr](../benchmarks/results/2026-09-27-native-gpu/raw-captures.tar.gz)
are archived alongside it. No logging occurs inside the measured frame loop.
