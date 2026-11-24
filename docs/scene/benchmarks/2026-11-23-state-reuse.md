# Reusable scene drawing snapshots — 23 November 2026

Scene rendering now retains a drawing-state snapshot per rendering boundary:
the scene, each render-group child pass and the diagnostic overlay. State,
view and camera settings are refreshed on entry. The caller's original state
object is restored on exit, so alternating a scene between canvases cannot make
their drawing settings share a mutable snapshot. Font and render-target references
are cleared from the retained snapshot on exit.

Public `ScopedMax2DState` handles remain one-shot objects. Closing an outer scope
still invalidates inner scopes, and stale public handles remain harmless after a
scene renders again. The existing stack list still allocates one 32-byte link per
boundary on this host. No BRL changes or application scene API changes are needed.

## Measured allocations

Release builds on the same macOS arm64 host as the
[allocation baseline](2026-11-23-material-refresh.md), using SDL GPU/Metal and
native OpenGL. Both backends returned the same byte counts in all three trials.
These are managed allocations, not retained memory or GPU memory.

| Warm operation | Before, bytes/call | After, bytes/call |
| --- | ---: | ---: |
| Public drawing-state scope | 368 | 368 |
| Empty scene | 368 | 32 |
| Single-sprite scene | 368 | 32 |
| Scene with eight cached text labels | 624 | 288 |

The isolated probes run 2,000 calls per trial after 32 warmup calls, flushing each
call. They create no textures and report no GC cycles during the measured calls.

| Full scene workload | Before, bytes/frame | After, bytes/frame |
| --- | ---: | ---: |
| Cached | 624 | 288 |
| Mask changes | 2,464 | 2,128 |
| Lighting changes | 11,136 | 10,464 |
| Combined changes | 11,504 | 10,832 |

The full workload uses the existing three 120-frame trials per case. Editing,
preparation and picking still allocate zero measured bytes; all remaining measured
allocation is in rendering. No warm textures are created, resource charges stay
stable and cleanup checks pass. The cached case saves 336 bytes/frame (54%);
lighting and combined cases save 672 bytes/frame across two retained boundaries.
The eight text-cache updates still account for 256 bytes/frame. Other allocations
inside lighting and effects have not been removed by this change.

This is an allocation improvement. These short runs do not establish a frame-time
or GPU-throughput gain. The 60,000-frame soak was not rerun, and Windows/Linux
backends were not exercised in this tranche.

## Results and reproduction

| Backend | Isolated probes | Full workload |
| --- | --- | --- |
| Metal | [CSV](2026-11-23-state-reuse-allocations-sdlgpu.csv) | [CSV](2026-11-23-state-reuse-scene-sdlgpu.csv) |
| OpenGL | [CSV](2026-11-23-state-reuse-allocations-gl.csv) | [CSV](2026-11-23-state-reuse-scene-gl.csv) |

Use the allocation and scene build commands in the
[baseline report](2026-11-23-material-refresh.md#reproduce), then run each
allocation executable without arguments and each scene workload with
`--trials-only`. Run graphics workloads sequentially.

On each backend, `scene_render` passes 62 checks, including stale public scopes,
failed callbacks, two-canvas alternation and surrounding public scopes;
`scene_composite` passes 65 checks including nested captures and failure recovery;
`scene_inspection` passes 16 checks. `drawing_state` also checks independent camera
copies, storage reuse, absent cameras and recapture after restoring a snapshot.

## Low-level snapshot support

`TMax2DState.CopyTo(destination)` copies scalar settings and independent camera
values into existing storage. `TMax2DGraphics.CaptureState(snapshot)` captures
state, font, target and view without pushing a stack entry or changing its flags.
These support retained rendering infrastructure; ordinary applications should
continue using `ScopedMax2DState` for automatic restoration. Never overwrite a
snapshot still on a state stack. `RestoreState` installs the snapshot's state as
live state; a subsequent `CaptureState` detaches that alias before copying.

Next is allocation-free layout-cache bookkeeping, followed by further attribution
of changing lighting/effect work. The remaining stack link is a separate small
allocation target.
