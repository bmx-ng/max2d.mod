# Shared source preparation — 24 November 2026

Live subtree masks now share completed dependency walks within each render attempt.
This addresses the repeated CPU work identified by the
[scaling baseline](2026-11-23-scene-scaling.md). It changes no mask pixels, input
semantics or stage ownership, and does not share mask coverage textures.

## Implementation and trade-offs

`TSceneRenderGroup.PrepareSourceDependencies(source,epoch)` is a provider helper
used by the live-mask stage. It prepares opted-in source groups, visits descendants
and returns the combined continuous-render requirement. Successful results are
retained on each node for the current epoch. Shared and overlapping source roots
reuse those results. Attachment changes reset the epoch, preventing accidental
reuse across independent scenes. Recursive walks fail before capture, unfinished
walks do not publish a completed result, and in-progress flags clear on failure.
Every new scene render starts a fresh attempt.

The bookkeeping adds one Long and two Int fields to every scene node: 16 bytes
of scalar fields before allocator/alignment effects. It retains no extra scene or
source references and makes no per-frame collection allocations. It still visits
each distinct source node once per frame; unchanged topology is not retained
across frames. The extra bookkeeping can cost more for an unshared source. The old
SceneEffects-specific recursive walk has been removed.

The [provider contract](../composites.md#preparing-dependencies-in-custom-providers)
and [live-mask usage](../stages.md#live-subtree-alpha-masks) describe the API and
lifetime rules.

## Correctness and resource checks

All **14 local regression runs passed** on Metal and OpenGL: 582 assertions in
total ([individual results](../validation/2026-11-24-source-preparation.csv)),
comprising 17 source-preparation, 39 live-mask, 68 subtree-capture, 65
composite, 56 image-alpha-mask, 22 culling and 24 storage checks per backend.
The new suite covers shared/overlapping roots in both visit orders, continuous
requirements, failed renders, same-attempt retry, recursion rejection, scene
transfer with equal epoch numbers, detach/reattach and destruction. Existing
suites cover mask pixels, cached ancestors, nested/shared source changes,
configuration/structural cycles, budgets and graphics-context recreation.

Two current Metal scaling invocations at 120 frames per trial and an OpenGL
invocation at 40 frames pass **43,680 measured frames**, plus warmups. A further
37,440 measured frames belong to the baseline timing runs. Work, retained/peak
storage and allocation columns match the baseline for every case. Warm cached
frames remain at 32 managed bytes; changed masks retain their existing per-stage
allocation costs. All cases create zero new textures after warmup and release
scene resource charges on destruction.

The regression runners register the new suite for supported desktop profiles.
The subsequent [release review](2026-11-24-release-review.md) validates this
implementation on Windows D3D9/D3D11 and Ubuntu SDL GPU/OpenGL.

The historical `camera_move` rows in these raw files did not reapply the copied
camera settings and therefore do not measure camera movement. The release review
corrects that fixture and verifies movement by pixel readback. All shared-mask
comparisons reported here are unaffected.

## Timing comparison

Host: Apple M4 Max, macOS 27.0.1 (26A434), arm64 release builds. The saved baseline
executable is from `6249172`; current executables use that revision plus this
source-preparation change. The benchmark source is unchanged. After all builds and
regressions finished, runs alternated baseline/current twice on Metal, followed by
the OpenGL current run. Each Metal invocation contains three 120-frame trials per
case. The table reports medians of six trial averages per version in microseconds,
not frame percentiles, GPU execution time or FPS.

| Workload | Before submit | After submit | Before preparation | After preparation |
| --- | ---: | ---: | ---: | ---: |
| 4,096 sprites, ordinary idle | 178.97 | 188.83 | 0.00 | 0.00 |
| 4,096 sprites, cached idle | 1.47 | 1.52 | 0.00 | 0.00 |
| 4,096-node source, 1 consumer, idle | 34.21 | 37.70 | 32.72 | 36.06 |
| 4,096-node source, 4 consumers, idle | 119.75 | 36.34 | 117.56 | 34.06 |
| 4,096-node source, 16 consumers, idle | 466.66 | 44.51 | 458.52 | 36.88 |
| 4,096-node source, 16 consumers, leaf edit | 3743.00 | 3333.53 | 492.58 | 73.95 |
| 256-node source, depth 16, idle | 7.86 | 8.30 | 4.59 | 5.08 |

For the sixteen-consumer unchanged 4,096-node case, the two pairs independently
show preparation around 458–459 µs before and 37 µs after. Total submission falls
from about 466–467 µs to 45 µs: approximately **90% less CPU submission time** for
this specific workload. Single-consumer preparation rises from about 33 µs to
34–37 µs; there is no blanket improvement claim. Changing masks still capture
the source separately for each consumer, so drawing cost remains substantial.

The attribution clock is inside the benchmark's outermost preparation callbacks;
its overhead is present in both executables. Current preparation uses the public
provider helper; a source group without dependencies no longer receives a no-op
preparation callback. The OpenGL run establishes workload invariants only: no
paired OpenGL timing comparison was made. Background desktop activity was not
controlled, so treat small differences as noise; the large shared-source reduction
repeats in both Metal pairs.

Raw trials:

- [Baseline Metal, first](2026-11-24-source-preparation-before-metal-1.csv)
- [Current Metal, first](2026-11-24-source-preparation-after-metal-1.csv)
- [Baseline Metal, repeat](2026-11-24-source-preparation-before-metal-2.csv)
- [Current Metal, repeat](2026-11-24-source-preparation-after-metal-2.csv)
- [Current OpenGL](2026-11-24-source-preparation-after-gl.csv)

## Next step

The repeated shared walk is resolved. Remaining source preparation is still linear
in distinct source nodes. Evaluate retaining dependency topology across frames
only if that residual cost matters in application-sized cases. Large frequently
changing masks still pay separate source captures and stage work; sharing pixels
would need explicit layout, offset, resolution and resource-lifetime contracts.
Retained draw instructions remain a separate investigation for ordinary tree
traversal and changing artwork.
