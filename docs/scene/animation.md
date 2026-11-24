# Scene animation

Import `Max2D.SceneAnimation` for `TSceneTweenNode`, a reusable timeline that
animates its spatial parent. It uses the normal transform and alpha setters, so
bounds, picking and composite invalidation follow the existing scene rules.
It needs no Graphics context until you render the scene.

## First animation

```blitzmax
Import Max2D.SceneAnimation

' badge is a TSceneNode2D already attached beneath a scene layer.
Local movement:TSceneTweenNode = New TSceneTweenNode
badge.AddChild(movement)
movement.Position(40, 100, 340, 100, 1.5, 0, ESceneEase.SmoothStep)
movement.Alpha(0, 1, 0.4)
movement.Play()

' In the application loop, before rendering:
scene.Update(dt) ' Seconds, supplied by the application.
```

The timeline is a child of the animated node. Destroying that parent destroys
the timeline and releases its tracks. Detaching the timeline or its ancestor
suspends automatic updates without resetting time; reattachment resumes them.
A scene pause also suspends updates unless you explicitly enable
`SetProcessWhenPaused(True)` on the timeline. `IsPlaying()` describes playback
state, not whether the scene currently permits updates.

## Tracks and timing

| Builder | Endpoints |
| --- | --- |
| `Position(fromX, fromY, toX, toY, duration, at=0, ease=Linear)` | Local position |
| `Rotation(fromDegrees, toDegrees, duration, at=0, ease=Linear)` | Clockwise component rotation |
| `Scale(fromX, fromY, toX, toY, duration, at=0, ease=Linear)` | Component scale, including zero and negative values |
| `Alpha(fromAlpha, toAlpha, duration, at=0, ease=Linear)` | Opacity in 0..1 |

All times are seconds. Duration must be positive; start time must be nonnegative.
All values must be finite. Builders return the timeline for optional chaining.
Endpoints are explicit: replay and seeking never capture the previous pose as
a new starting value. Rotation interpolates the supplied degrees directly;
use 0 to 720 for two full turns. Rotation and scale require component transforms;
a parent using a raw affine matrix supports position and alpha tracks only.

`ESceneEase` provides `Linear`, `SmoothStep`, `InQuad`, `OutQuad` and `InOutQuad`.
Each track eases its own normalized interval. The initial value is held before
its start and the final value after its end.

Different properties run in parallel. For a sequence on the same property,
append tracks in increasing start-time order:

```blitzmax
movement.Position(40, 100, 340, 100, 1.5)
movement.Position(340, 100, 340, 220, 0.5, 1.5, ESceneEase.OutQuad)
```

A later track takes over its property when its start time is reached, including
when it overlaps an earlier track. Equal start times use insertion order, with
the last track winning. Future tracks do not overwrite the active track.
Use matching endpoints for continuous motion; different endpoints intentionally
jump. There is no additive blending. Avoid multiple timelines or application
updates writing the same property unless you intend traversal order to decide
the final value.

## Playback controls

- `Play()` applies time zero and starts or restarts variable-step playback.
- `Pause()` and `Resume()` retain time and pose. To restart after completion, use `Play()`.
- `Stop()` pauses and resets the clock while leaving the current pose visible.
- `Seek(seconds)` applies an absolute time without changing playback state.
- `SetSpeed(value)` sets a nonnegative multiplier; zero holds time.
- `SetLoop(True)` repeats. `SetLoop(True, True)` alternates forward and backward.
- `Duration()` returns the maximum track end time, including initial delays.
- `Clear()` stops and drops all tracks/storage while preserving the visible pose.

Pause before adding tracks or changing loop mode. Playback starts only after
`Play` or `Resume`; constructing/configuring a timeline does not change the parent.
Seeking a non-looping timeline beyond its duration applies its final pose.
Looping uses modulo time: an exact forward-loop boundary returns to the beginning;
a ping-pong boundary at `Duration()` reaches the end. Delays form part of the loop,
so a ping-pong timeline also traverses its initial hold on the return leg.
Large time steps cross any number of cycles without per-cycle iteration.

## Ownership and allocations

Each builder allocates one retained track; the track array grows geometrically.
Configure once and replay with `Play()` instead of rebuilding every frame.
Normal playback, easing and seeking create no track, matrix or event objects.
The timeline retains only its tracks; its target is resolved through `Parent()`.
It owns no images, shaders or GPU resources. `scene.ReleaseResources()` therefore
does not erase animation state. Destruction releases tracks, while `Clear()`
allows a live node to be reconfigured.

The application continues to own the update loop and time-step policy. This
module currently provides transform/opacity tweens, not sprite-frame clips,
keyframe asset loading, completion callbacks, arbitrary property bindings or
animation blending. Existing atlas animation remains available separately.

## Runnable example

[`examples/scene_animation.bmx`](../../examples/scene_animation.bmx) compares four
easing curves while animating position, rotation, scale and opacity together.
It uses a delayed ping-pong timeline, Space to pause the scene, and R to restart.
From the SDK directory:

```sh
bin/bmk makeapp -r -t gui -o /tmp/scene-animation mod/max2d.mod/examples/scene_animation.bmx
```

The example uses SDL GPU. The headless `scene_animation` regression runs in the
`core` test profile and checks timing, seeking, ownership and validation.
