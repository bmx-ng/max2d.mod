# Snowfall presentation timing

The default SDL3 build was reported to have small visible pauses despite smooth
OpenGL playback. The active default renderer here was `metal`, not SDL's `gpu`
renderer. No renderer implementation is switched by this change.

The original windowed `Graphics 800,600,0` plus plain `Flip` selects BRL.Graphics'
software 60 Hz timer. That timer uses millisecond Delay calls and presents with
VSync disabled. Snow motion also advances by a fixed amount per frame.

The interactive sample now uses `Flip(1)` and monotonic elapsed-time movement,
scaled to the original 60 updates/second. Wind phase also advances with elapsed
time. Long interruptions are capped at 100 ms to avoid a large restoration jump.
The first frame is cleared. This changes presentation to the display cadence
without doubling motion speed on a 120 Hz display. It does not change the global
Flip API, SDL renderer defaults or other applications. `sample_test` retains
fixed steps and unsynchronised presentation for deterministic correctness checks.

## Measurements

macOS, 2026-09-22; 72 warm-up frames then 240 recorded frames. Times are CPU
wall-clock intervals through event handling, animation, submission, Flip and Cls,
not GPU timestamps or measured on-screen display intervals. No logging occurs
inside the measured loop; CSV is written after it completes.

| Build | Mean ms | p95 ms | p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| Original SDL3 Metal / timer | 16.666 | 17.728 | 18.488 | 18.669 |
| Original OpenGL / timer | 16.670 | 17.915 | 18.548 | 18.686 |
| Revised SDL3 Metal / VSync + elapsed motion | 8.288 | 8.902 | 9.012 | 9.043 |

The original CPU distributions are similar. They do **not** establish the cause
of the reported difference in visible smoothness. VSync avoids submitting at an
independent timer cadence and is the appropriate first correction; confirming
that it removes the perceived pauses still requires visual feedback. These are
short runs and cannot exclude rare stalls. SDL and GL also differ in drawable
resolution and mipmap use, so this is not a renderer throughput comparison.

Raw captures are in `benchmarks/results/2026-09-22-snowfall-*.csv`.

## Reproducing

Build `examples/snowfall.bmx` with `-ud sample_pacing` for a bounded capture of the
revised loop, or `-ud sample_pacing,pacing_legacy` for its original timer/fixed-step
behaviour. Add `max2d_gl` for OpenGL, or `max2d_sdl_gpu` to explicitly select SDL's
GPU renderer. Use `-t gui -hi` on macOS. The run writes `snowfall-pacing.csv` to a
writable AppDir and closes automatically. Build without these definitions for
normal interactive use. Use only one of `sample_test` and `sample_pacing`.
