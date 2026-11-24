# Stable-tree and live-mask scaling — 23 November 2026

The [scaling benchmark](../../../tests/scene_scaling.bmx) measures scene sizes of
16, 256 and 4,096 sprites, ordinary traversal versus automatic pixel caches, and
live-mask sources shared by 1, 4 or 16 consumers. Separate chain cases use 256
source sprites and dependency depths of 4 and 16. This is a workload baseline,
not a frame-rate target or a comparison against another engine.

## Reproducing the measurement

Build both profiles from the SDK directory before measuring:

```sh
bin/bmk makeapp -r -o /tmp/scene_scaling mod/max2d.mod/tests/scene_scaling.bmx
bin/bmk makeapp -r -ud max2d_gl -o /tmp/scene_scaling_gl mod/max2d.mod/tests/scene_scaling.bmx
/tmp/scene_scaling 120 > /tmp/scene_scaling_metal.csv
/tmp/scene_scaling_gl 120 > /tmp/scene_scaling_gl.csv
```

The optional argument is an even number of measured frames per trial (default
40, minimum 2). Every case warms for 12 frames, then runs three trials with a GC
collection before each. There are 52 cases, giving 18,720 measured frames per
invocation at 120 frames per trial. Run profiles sequentially in a desktop session,
with no concurrent builds, benchmarks or animated demos.

Ordinary and cached cases use identical 4×4 white sprites at a four-unit spacing
in a 64-column grid. Captures have a fixed 256×256 canvas. Changes are idle,
parent translation, camera translation, one leaf's alpha, and every leaf's alpha.
Edits alternate each frame, including across trial boundaries. Mask consumers
contain a single cached rectangle; the source's parent is hidden so only explicit
mask captures draw it. Each shared consumer has its own coverage/output targets.
A chain links separately cached masked composites beneath the hidden parent.

## What the columns mean

- `edit_us`: application edits, including propagation performed by setters.
- `submit_us`: clear, scene render and flush; excludes edits and the final drain.
- `prepare_us`: time inside outermost composite dependency-preparation calls,
  included in submission. A benchmark-only subclass wraps the existing virtual
  hook. Nested calls are not counted twice. It includes clock overhead and omits
  the scene's registry loop, so it is an attribution probe, not exact profiling of
  every preparation instruction. Ordinary/cached cases do not register this hook.
- `drained_us`: edits, submission, GC-stat sampling and a one-pixel readback to
  drain queued work. This is not GPU execution time or a frame-rate estimate.
- Managed bytes cover edits and submission, excluding readback and CSV output.
- Batches, captures, stage updates and cache hits are per-frame averages. Mask
  source captures count as captures even when consumer artwork stays cached.
- Retained/peak bytes are scene texture-budget estimates, not driver memory or
  total managed heap. The shared sprite image and destination target are excluded.

Every trial checks stable retained charges and zero new textures after warmup.
Cached idle/parent/camera cases must perform no captures; edited cached artwork
must recapture each frame. Stable masks must perform no stage updates. Edited
masks must propagate through every consumer/link, with one source capture per
stage update and no consumer-artwork redraws. Destroying every scene must return
its registered storage charge to zero. These checks do not replace the separate
pixel, cycle, lifetime and graphics-context regression suites.

## Camera measurement correction — 24 November 2026

The historical `camera_move` rows below did not move the rendered camera:
`SetCamera` copies its values, and the benchmark only changed the original camera.
Those rows are invalid as camera-motion measurements. Other cases are unaffected.
The corrected benchmark reapplies the camera and checks a moving edge pixel every
measured frame; see the [release checks](2026-11-24-release-review.md).

## Recorded results

Renderer source: `b0a952f`, with this benchmark added and no renderer changes.
Host: Apple M4 Max, macOS 27.0.1 (26A434), arm64 release builds. Profiles ran
sequentially in the order Metal, OpenGL, Metal repeat. All **56,160 measured
frames** passed the work, allocation/storage and cleanup assertions, plus warmup
frames. The short Metal smoke run also passed all 52 cases before measurement.

- [Metal raw trials](2026-11-23-scene-scaling-metal.csv)
- [OpenGL raw trials](2026-11-23-scene-scaling-gl.csv)
- [Metal repeat raw trials](2026-11-23-scene-scaling-metal-repeat.csv)

The table shows medians of three 120-frame trial averages for each Metal
invocation, in microseconds. These are not individual-frame percentiles.

| Workload | First submit | Repeat submit | First preparation | Repeat preparation |
| --- | ---: | ---: | ---: | ---: |
| 4,096 ordinary sprites, idle | 185.81 | 180.92 | 0.00 | 0.00 |
| 4,096 cached sprites, idle | 1.16 | 1.52 | 0.00 | 0.00 |
| 4,096 cached sprites, parent move | 1.15 | 1.37 | 0.00 | 0.00 |
| 4,096 cached sprites, leaf edit | 274.81 | 281.42 | 0.00 | 0.00 |
| 4,096-node mask, 1 consumer, idle | 31.97 | 31.84 | 30.75 | 30.63 |
| 4,096-node mask, 4 consumers, idle | 116.17 | 116.38 | 113.99 | 113.86 |
| 4,096-node mask, 16 consumers, idle | 457.20 | 463.01 | 448.69 | 454.29 |
| 256-node mask, depth 16, idle | 6.79 | 8.22 | 3.93 | 4.76 |

The cached-parent case additionally spends about 9.90 / 10.35 µs in the edit
setter in the first/repeat run. The historical camera rows cannot establish a
comparison with camera movement. A leaf edit invalidates the cached artwork and requires a full
capture: pixel caching does not make frequently changing large trees cheap.

Unchanged ordinary trees, cached trees and masks allocate 32 managed bytes per
frame at all tested sizes. Edited cached trees allocate 224 bytes per frame.
Edited masks allocate 32 + 400 bytes per updated stage: 432 for one consumer,
1,632 for four, and 6,432 for sixteen consumers or a sixteen-stage chain. Those
updates create no new textures. Cached artwork retains 262,144 bytes; each mask
consumer/link retains 786,432 bytes, reaching 12 MiB at sixteen. Peak scene charges
match retained charges after warmup, and destruction returns charges to zero.

OpenGL passed the same invariant checks but its timing trials had substantial
variation, including non-monotonic source/consumer cases. A process sample during
that run showed the editor's C++ indexer at about 93% CPU and WindowServer at about
69%. Background activity was not stopped. Retain those raw timings as observed
results, but do not use them to estimate an OpenGL speedup or compare backends.
The repeated Metal timings support the narrower conclusion about this workload's
CPU preparation cost. This is not an isolated-machine benchmark or GPU profile.

## Decision

Prioritise **shared live-mask dependency preparation** before retained draw
instructions. With 4,096 unchanged source sprites, preparation grows from roughly
31 µs for one consumer to 449–454 µs for sixteen. No pixels are recaptured and no
stages run in these idle cases. The implementation confirms the mechanism:
`PrepareMaskSource` walks every source descendant for each consumer, even when
another consumer already resolved the same source during this render epoch.

Start by evaluating per-render memoisation of source traversal and continuous-render
requirements. Its contract must include scene/epoch identity, overlapping sources,
nested mask dependencies, cycle rejection, reparenting, detach/reattach, destruction
and failure/retry. A failed preparation must never publish a reusable successful
result. Preserve continuously rendered sources and preparation before cached
ancestor traversal. Re-run this identical benchmark and the existing mask suites
before claiming an improvement. Retained dependency adjacency across frames is a
later option if a once-per-epoch walk still matters.

Retained rendering instructions remain a separate opportunity for large ordinary
trees or changing artwork. Existing pixel caches already handle stable large trees
well; they cannot replace ordinary drawing in every application. These measurements
justify a narrower dependency optimisation first, without changing the public
scene API or committing to a new renderer.
