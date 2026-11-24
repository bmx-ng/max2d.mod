# Touch Playground

A complete scene-input example: drag three tiles using native touch, a mouse,
or a built-in two-pointer simulation. Each tile captures one pointer, keeping
its drag offset in its parent's coordinates. A rotated, unevenly scaled parent
and nonzero tile pivots make coordinate mistakes visible.

## Build and run

From the BlitzMax SDK directory, on macOS:

```sh
bin/bmk makeapp -r -t gui -o /tmp/touch_playground mod/max2d.mod/demos/touch_playground/touch_playground.bmx
open /tmp/touch_playground.app
```

The default backend is SDL3 GPU. Add `-ud max2d_sdlrender` to use SDL3 Renderer.
Both use the same SDL3 event adapter. On Windows or Linux choose a local output
path and launch the executable directly.

For integration checks, omit `-t gui` and run the executable with `--test`.
Checks require a graphics display. They cover simultaneous ownership, affine
drag offsets, release beyond the input clip, hide/detach/singular-transform
cancellation, full-width native identifiers and stale moves after cancellation.

## Controls

| Input | Action |
| --- | --- |
| Touch or left mouse drag | Pick up a tile |
| T | Toggle two simulated pointers |
| C | Cancel all input and stop the simulation |
| R | Restore layout, visibility and transforms; cancel input |
| H | Hide/show cyan |
| X | Detach/reattach cyan |
| Z | Give the parent zero horizontal scale; press again to restore |
| D | Toggle scene bounds overlay |
| Escape | Quit |

Try T followed by H, X or Z. A cancelled tile shows CANCELLED when visible
again. Other valid captures continue independently. R restores an accessible
layout if a tile has been dragged offscreen. Counters record actual drag ends;
the CaptureLost notification following Up does not count a second time.

The dark region limits **new presses**, not captured movement or rendering.
Crosshairs show active adapter contacts, including contacts whose tile capture
has been cancelled. Such a finger must lift and press again to acquire a tile.
The simulation uses the scene dispatch API, not native touch injection.

## Component and adapter

- [drag_tile.bmx](drag_tile.bmx) contains the reusable scene component.
- [input.bmx](input.bmx) converts native SDL events.
- [touch_playground.bmx](touch_playground.bmx) owns setup, frame timing, experiments
  and the diagnostic HUD.
- [playground_tests.bmx](playground_tests.bmx) exercises the same component and adapter.

A component's Down callback converts the pointer with
`event.PositionIn(Parent(), x, y)`, subtracts the node's position, and retains
that offset. Subsequent moves use the same coordinate space. It records both
device and pointer identifiers and ignores another pointer while held.
Up, Cancel and CaptureLost clear ownership. Hiding or invalidating transforms
is reconciled at the scene's next update/dispatch boundary; detachment also
cleans up capture.

For application-driven input the essential sequence is:

```blitzmax
scene.ReservePointers(20)
scene.SetInputClip(TSceneRect.Create(30,155,1040,360))

' Values below are already in scene virtual coordinates.
scene.DispatchPointer(EScenePointerKind.Down, deviceId, pointerId, x, y, 1, 1)
scene.DispatchPointer(EScenePointerKind.Move, deviceId, pointerId, x, y, 0, 1)
scene.DispatchPointer(EScenePointerKind.Up, deviceId, pointerId, x, y, 1, 0)

' On focus loss, cancel while the scene is idle.
scene.CancelInput()
```

### Native event handling

The application disables automatic polling and polls explicitly while the scene
is idle. Its event hook observes SDL3's copied metadata and returns the original
event for other hooks. It captures the window input mapping before polling.

SDL touch positions are normalized window coordinates. The adapter converts
them through `TMax2DInputMapping`, which accounts for drawable pixel density and
letterboxing. Only Down requires an inside point; Move and Up retain unclamped
coordinates so capture works beyond the input region.

Sixteen retained slots map the exact `ULong` touch-device/finger pair to stable
scene identifiers. Slot reuse happens after release or cancellation. Contacts
beyond capacity are ignored and counted. Mouse, touch and simulation use distinct
scene device namespaces. Touch-generated mouse events are ignored using SDL's
reserved mouse ID, preventing duplicate drags. Mouse-generated touch events
are also ignored. Ordinary mouse devices share one
desktop pointer in this example.

This is a **single-window adapter**. A multi-window application should route
metadata by `windowID` to each window's mapping and scene. Application suspension
cancels the scene and clears slots. A later Move or Up cannot restart a cancelled
touch. Resume requires a new Down.

The hook is removed before destroying the scene. A detached cyan tile is
explicitly destroyed by the application, since the scene no longer owns it.

## Allocation and scope

Tiles, touch slots and scene pointer capacity are created during setup.
Drag updates mutate positions and reuse scene event records. SDL's copied event
payloads, the per-frame mapping snapshot and diagnostic HUD strings can allocate;
this demo is not an allocation-free input benchmark.

This demonstrates capture and cancellation, not gesture recognition, drag
thresholds or drop targets. Those can be built above the same event model.

macOS validation covers SDL3 GPU and SDL3 Renderer, synthetic simultaneous input,
and live keyboard controls. Native mouse/touch conversion is checked with injected
payload values. Physical mouse and touchscreen interaction still require hardware verification.
