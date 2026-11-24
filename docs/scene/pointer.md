# Pointer events and capture

`Max2D.Scene` routes pointer presses and movement through the scene tree. The
application supplies input; the module does not poll a mouse, consume native
SDL events or own the main loop. Mouse, pen and touch adapters use the same API.
[Keyboard focus, key routing and opt-in hover](interaction.md) are also available.

## Feed input into the scene

Enable targets and set the input clip as described in [picking](picking.md), then
forward input in **virtual surface coordinates**:

```blitzmax
scene.DispatchPointer(EScenePointerKind.Down, deviceId, pointerId, x, y, button, buttons)
scene.DispatchPointer(EScenePointerKind.Move, deviceId, pointerId, x, y, 0, buttons)
scene.DispatchPointer(EScenePointerKind.Up, deviceId, pointerId, x, y, button, buttons)
```

The `(deviceId, pointerId)` pair identifies one independent press/drag stream.
Use distinct device IDs for different input sources and retain native touch
finger IDs as pointer IDs. Coordinates must be finite for Down/Move/Up.
Button codes and button-state values are supplied unchanged by the adapter;
use the application's existing BRL button convention consistently. The scene
neither interprets those values nor synthesizes clicks, double-clicks or gestures.

There is one active press per pair. A duplicate Down while that pair has an
active press is rejected. For a mouse adapter with several independently held
buttons, assign a separate pointer ID to each button stream and forward movement
to each active stream. A Down that hits nothing creates no active press.
Uncaptured Move and Up use current picking, even if Down hit a different node.
Capture explicitly when a control needs the whole drag/release sequence.

`DispatchPointer` returns True when a callback handles the main event. Use False
for application fallback controls. Synthetic cancellation and capture-loss
notifications do not change the handled result of a normal Move/Up.

Use `WindowToVirtual`, `GetVirtualMouse` or a retained `TMax2DInputMapping` to map
window input. A touch adapter first converts normalized touch positions into
window coordinates. **Forward Move and Up even outside the input clip:** the
mapping's coordinates remain useful when its inside test returns False. Capture
allows a drag to continue beyond a node, layer viewport or scene input clip.
Do not pass native pixel coordinates directly to DispatchPointer.

## Event phases

For a picked or captured target, the scene records its ancestor path and calls:

1. `OnPointerCapture(event)` on ancestors from root towards the target's parent.
2. `OnPointer(event)` on the target.
3. `OnPointerBubble(event)` on ancestors from parent towards root.

The target does not receive the ancestor-phase hooks. `StopPropagation()` stops
further visits but leaves the event unhandled. `Handle()` both stops propagation
and marks the event handled. Pending-destruction nodes are skipped on the rest of
a normal path. Cancel and CaptureLost still reach a pending-destruction target
before its exit/destruction callbacks.

Node properties may change inside handlers. Structural operations queue until
the dispatch boundary; the active path does not change underneath a callback.
Nested public DispatchPointer, Update, Render, Pick or CancelInput on the same
scene is rejected. Finish the current callback before beginning another traversal.

## Capture a drag

Capture during the receiver's Down callback. The receiver can capture only
itself, must be an eligible interactive spatial node, and cannot steal an
existing capture. An ancestor can capture itself in its capture-phase hook.

```blitzmax
Type TDragHandle Extends TSceneNode2D
    Field dragging:Int
    Field device:Long, pointer:Long
    Field offsetX:Float, offsetY:Float

    Method OnPointer(event:TScenePointerEvent)
        Select event.Kind()
            Case EScenePointerKind.Down
                If dragging Then Return
                Local x:Float, y:Float, px:Float, py:Float
                If Not event.PositionIn(Parent(), x, y) Then Return
                GetPosition(px, py)
                offsetX = x-px; offsetY = y-py
                device = event.DeviceId(); pointer = event.PointerId()
                dragging = True
                event.CapturePointer(Self)
                event.Handle()
            Case EScenePointerKind.Move
                If Not dragging Or event.DeviceId()<>device Or event.PointerId()<>pointer Then Return
                Local x:Float, y:Float
                If event.PositionIn(Parent(), x, y) Then SetPosition(x-offsetX, y-offsetY)
                event.Handle()
            Case EScenePointerKind.Up, EScenePointerKind.Cancel, EScenePointerKind.CaptureLost
                If event.DeviceId()=device And event.PointerId()=pointer Then dragging = False
        End Select
    End Method
End Type
```

Attach the handle beneath a layer, provide a hit rectangle and call
`SetInteractive(True)`. Measuring the drag in the parent's coordinates preserves
the grab offset even under parent rotation or scaling. An application control
can accept several pointers by storing its own per-pointer drag state instead
of this example's single `dragging` flag.

Move/Up target the capture owner. `ReleasePointer()` is allowed only from that
owner's callback and takes effect after the current path finishes, then routes
CaptureLost. Up releases automatically. CaptureLost uses the normal ancestor
phases, but capture is already cleared when those callbacks run.

## Cancellation and failures

Call `scene.CancelInput()` on application focus loss, input-device reset or a
modal transition that abandons active controls. For one interrupted native
pointer, inject `EScenePointerKind.Cancel` with its IDs; positions are ignored.
Both operations send Cancel to the capture owner (or the original pressed target
if there is no capture), then CaptureLost if needed, and release the record.
An ancestor capture assumes responsibility for the press; the original child
does not receive a second terminal event.

Detachment, reparenting and destruction cancel affected presses/captures before
exit or unlinking. Reparenting within the same scene also cancels. Hiding,
zero opacity, disabled interactivity or singular transforms cancel at the next
update/dispatch boundary. Changes inside a handler are reconciled at that
handler's dispatch boundary. Clipping changes do not cancel a capture.

Cancel and CaptureLost have no usable position: their coordinates are zero and
`PositionIn` returns False without changing outputs. Cancellation handlers should
clear application interaction state, without assuming the node is still editable:
it may already be pending destruction.

If a handler throws, traversal stops, its active pointer is cancelled, queued
structural cleanup still runs, and the first error is rethrown. Cancellation
continues across all active pointers even when a cancellation handler throws.
No callbacks run from GC finalizers.

## Borrowed events and memory

Events are borrowed for one callback. Do not store them. Read scalar values or
call `event.Copy()` when durable data is needed. The allocated
`TScenePointerSnapshot` has read-only data accessors and retains Target and
CurrentTarget references, with no capture, propagation or coordinate methods.

The scene reuses its event, path array and pointer records. `Reserve` prepares
path storage; `ReservePointers(8)` can prepare simultaneous presses during loading.
Arrays grow when required and records are reused after Up/Cancel. `TrimStorage`
releases unused pointer records while preserving active ones. Framework dispatch
allocates no objects after warmup; custom handlers and explicit Copy calls may
allocate. Coordinate queries use the current transform, while the ancestor path
is fixed for the event.

[scene_drag.bmx](../../examples/scene_drag.bmx) is a runnable draggable-card
example with an application-owned mouse adapter. Press C to cancel; existing
sorting, rotation and visibility controls let you exercise scene changes.
[scene_pointer.bmx](../../tests/scene_pointer.bmx) tests independent pointer pairs,
phases, propagation, snapshots, capture, cancellation, callback failure recovery
and allocation after warmup. Native touch-device testing is separate from these
injected pointer-stream tests.
