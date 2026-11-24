# Scene tree and transform foundation

Import `Max2D.Scene` to use retained node trees independently of a graphics
context. It provides ownership, lifecycle, explicit updates and 2D affine
transforms. Continue with [rendering and layer cameras](rendering.md),
[picking](picking.md), [pointer routing](pointer.md), [keyboard focus](interaction.md)
and optional [scene effects and composites](composites.md). The
[design and contracts](design.md) distinguish current behaviour from extensions.

## A moving hierarchy

```blitzmax
SuperStrict
Framework BRL.StandardIO
Import Max2D.Scene

Type TMovingNode Extends TSceneNode2D
    Field elapsed:Double
    Method OnUpdate(dt:Double)
        elapsed :+ dt
        SetPosition(Float(elapsed * 60), 0)
    End Method
End Type

Local scene:TScene = TScene.Create()
Local layer:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(layer)
Local parent:TMovingNode = New TMovingNode
parent.SetProcessing(True)
layer.AddChild(parent)
Local child:TSceneNode2D = New TSceneNode2D
child.SetPosition(10, 20)
parent.AddChild(child)
scene.Update(0.5)
Local x:Float, y:Float
child.LocalToWorld(0, 0, x, y)
Print x + ", " + y ' 40, 20
scene.Destroy()
```

Layers are direct children of the non-spatial scene root. Spatial content must
be beneath a layer. Ordinary non-spatial nodes can group spatial children there
without breaking transform inheritance. Nodes start with processing disabled;
`SetFixedProcessing(True)` separately enables `OnFixedUpdate`. The application
supplies finite, nonnegative seconds and owns its fixed-step accumulator.
`SetPaused(True)` suppresses processing except for nodes explicitly enabled with
`SetProcessWhenPaused(True)`.

## Ownership and callbacks

`AddChild` requires an unparented node. `RemoveChild` detaches a reusable subtree;
it does not destroy it. `Reparent` explicitly moves an existing node. Cycles and
multiple parents are rejected. To move between scenes, detach first, then attach
outside callbacks.

Enter callbacks visit parents before children. Ready callbacks visit children
before parents, once per node lifetime. Exit callbacks visit children before
parents. Moving within the same scene does not repeat these callbacks.

Structural changes requested during scene callbacks commit at the traversal
boundary. Newly added nodes wait until the next update; pending destruction
immediately suppresses subsequent updates. Conflicting queued operations are
validated again at commit. Operations targeting destroyed nodes are discarded
and counted by `DiscardedOperations()`; other invalid operations raise an error.
Scalar edits take effect immediately. A callback exception ends update traversal,
but queued changes and structural cleanup still complete before it is rethrown.
A 100,000-operation boundary limit prevents callbacks generating changes forever.

`Destroy` is recursive and terminal; repeated calls are harmless. Destroy the
root through `scene.Destroy()`. Detached nodes remain application-owned.
`OnReleaseResources` runs before `OnDestroy`, and also through
`scene.ReleaseResources()` without destruction. Custom release hooks must be
idempotent. Shared application images/fonts are not automatically released.

## Coordinates and affine transforms

`SetTransform(x, y, rotation, scaleX, scaleY, pivotX, pivotY)` composes translation,
clockwise rotation in degrees, scale, then negative pivot translation. Negative
and zero scales are supported. `LocalToWorld` and `WorldToLocal` use layer-world
coordinates. Failed inverse/point conversions return False and leave outputs
unchanged. Setters reject non-finite values.

`Reparent(parent, True)` preserves the complete world matrix, including shear,
within the same layer. A singular new parent is rejected before membership changes.
For deferred reparenting the preserved transform is the one at commit time.
This enters raw affine mode, as does `SetLocalTransform`. `SetPosition` then edits
matrix translation; rotation, scale and pivot setters require an explicit
`SetTransform` reset to component mode. This avoids silently losing shear.

## Memory and hot loops

Nodes retain child-array capacity after removal. The scene retains its traversal
stack and deferred-command arrays. Numeric matrices live inline in each spatial
node and resolve lazily. Extra capacity is intentional: normal movement and
traversal reuse memory instead of creating temporary objects each frame.

- Call `scene.Reserve(nodeCapacity, operationCapacity)` and
  `node.ReserveChildren(capacity)` during loading when counts are predictable.
- Use `ChildCount`/`ChildAt` for indexed access. `Children()` allocates a snapshot.
- Reuse a `TSceneTransform` with `CopyLocalTransform` or `CopyWorldTransform`.
  `LocalTransform()` and `WorldTransform()` deliberately allocate snapshots.
- `scene.TrimStorage()` shrinks attached child arrays and drops scene scratch
  storage while idle. Subsequent activity may allocate to grow it again.
- Removed/consumed reference slots are cleared even when callbacks throw. Spare
  capacity does not intentionally keep removed nodes alive. Application-held
  snapshots and references still do.

These APIs are intended for one application thread. They do not disable GC or
promise a maximum collection pause. Application callbacks may allocate; tree
creation, capacity growth and snapshots also allocate. See the [rendering guide](rendering.md) for measured rendering behaviour; input
allocation behaviour will be measured when that extension exists.

## Regression test

From the Max2D repository, using the SDK's `bmk`:

```sh
../../bin/bmk makeapp -r -t console -o /tmp/scene_foundation tests/scene_foundation.bmx
/tmp/scene_foundation
```

The test covers tree ownership, lifecycle order, deferred changes, exception
cleanup, pause/fixed updates, affine preservation and singular inverses. It also
compares cumulative `GCGetStats` allocation counters across warmed movement/query
and deferred-reparent loops. It requires no graphics driver or window.
