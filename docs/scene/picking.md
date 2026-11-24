# Coordinates and pointer picking

`Max2D.Scene` can convert coordinates and find the topmost interactive node
without a Graphics context. The application still polls or receives input;
[pointer routing and capture](pointer.md), [hover and keyboard focus](interaction.md)
are also available.

## Enable a target

Nodes are not interactive by default. Enable only the nodes that should receive
hits, and configure the scene's interactive area:

```blitzmax
Local scene:TScene = TScene.Create()
Local layer:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(layer)
scene.SetInputClip(TSceneRect.Create(0, 0, 960, 640))

Local button:TSceneNode2D = New TSceneNode2D
button.SetPosition(100, 80)
button.SetHitRect(TSceneRect.Create(0, 0, 160, 48))
button.SetInteractive(True)
layer.AddChild(button)

Local hit:TSceneNode2D = scene.Pick(120, 100) ' button
```

The plain node above defines an invisible hit region. Sprites, text, meshes and
custom drawing nodes can use the same API. Without an explicit hit rectangle,
the default `HitTestLocal` tests known **self bounds**, not aggregate child bounds.
Unknown or empty bounds miss. Sprite bounds include the shared image handle;
text uses ink bounds and meshes use their vertex bounding rectangle. These are
geometric tests, not pixel-alpha tests.

`SetHitRect` copies its argument and does not change drawing bounds.
`ClearHitRect` restores self-bound testing. Rectangles include left/top edges and
exclude right/bottom edges. Override `HitTestLocal(x, y)` for another local shape:

```blitzmax
Type TCircleTarget Extends TSceneNode2D
    Method HitTestLocal:Int(x:Float, y:Float)
        Return x*x + y*y <= 40*40
    End Method
End Type
```

Hit-test and self-bound callbacks used during picking are read-only: do not
change scene properties, tree membership, or begin another traversal. Exceptions
propagate to the caller after retained references and traversal state are cleared.

## Coordinates and clipping

“Screen” in `LocalToScreen` and `ScreenToLocal` means the scene's **virtual
surface**, not native window pixels. The methods combine the layer's camera
snapshot and the node's complete affine transform, including ancestors, pivots,
rotation, negative scales and shear. Non-spatial nodes use their inherited
transform. They resolve changes immediately; no Update or Render is required.

```blitzmax
Local mx:Float, my:Float
If GetVirtualMouse(mx, my) Then
    Local target:TSceneNode2D = scene.Pick(mx, my)
    If target Then
        Local localX:Float, localY:Float
        If scene.ScreenToLocal(target, mx, my, localX, localY) Then
            ' Use coordinates relative to the target.
        End If
    End If
End If
```

For touch or other native window input, use Max2D's `WindowToVirtual` (or a
reusable `TMax2DInputMapping`) before calling `Pick`.

Conversion does not clip or test visibility. Detached nodes, nodes in another
scene, nodes pending destruction and nodes outside a layer have no screen
mapping. Inverse conversion also fails for singular transforms. False leaves
both output variables unchanged. Forward conversion can map a collapsed axis.

`SetInputClip` copies the outer interactive rectangle in virtual coordinates.
Until set, picking returns Null. Passing Null clears it. Keep it synchronized
with the viewport used for interactive presentation; rendering into an offscreen
buffer never changes it. Layer viewports also clip picking, with the same outward
integer rounding used by rendering. Neither clip shifts the coordinate origin.

`TCompositeNode.SetClipRect` also clips fresh picking and hover in the group's
local coordinates, including descendants and the group's own hit shape. Nested
clips intersect. See [local clipping](composites.md#local-rectangular-clipping).
`SetCaptureRect` alone crops drawing without restricting input. Neither operation
changes delivery to an already captured pointer.

[Alpha-mask stages](stages.md#optional-alpha-aware-picking) optionally test a copied
CPU alpha snapshot. Their local restrictions intersect with rectangular and
ancestor clips. Rendering a mask alone leaves picking unchanged.

Custom `TSceneRenderGroup` providers can override `HitTestInputClip(x, y)` to
reject an entire branch. The scene supplies local coordinates and rejects
singular transforms before calling it. The default accepts all points. Like
other picking callbacks, it must not mutate the scene or start another traversal.

## Which node wins?

`Pick` returns one node, or Null. It checks candidates in reverse drawing order:
children above their parent, later siblings above earlier siblings, and stable
z-index order where sorting is enabled. A subtree stays together, just as when
rendered. The first successful hit stops further hit-test callbacks.

Hidden, zero-opacity and pending-destruction branches are excluded. A singular
transform cannot produce a hit. Disabling interactivity on a parent does not
disable its descendants. Transparent image pixels do not automatically pass
through; use a custom hit shape when needed.

Picking requires an idle scene. It uses retained candidate and traversal arrays;
`Reserve` prepares capacity and `TrimStorage` releases it. Default self-bound
scratch rectangles may allocate on first use, and text may warm its font-layout
cache. Warm traversal and coordinate conversion allocate no framework objects.
Candidate collection visits the visible tree; bounds-based spatial acceleration
is not implemented. Custom hit callbacks may have their own allocation costs.

## Runnable example and checks

[scene_picking.bmx](../../examples/scene_picking.bmx) highlights the topmost card
under the pointer. Reverse z order, toggle sorting, rotate a card or hide one to
see how picking follows rendering. The example owns mouse polling; hover is
application code, not scene event routing.

[scene_picking.bmx tests](../../tests/scene_picking.bmx) cover transforms, clips,
ordering, eligibility, callback failure recovery and allocation after warmup.
