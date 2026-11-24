# Rendering a scene

`Max2D.Scene` now draws sprites, text, meshes and custom geometry using the active
Max2D backend. It adds no mandatory ECS, physics, asset loader or application loop.
The [foundation guide](foundation.md) explains ownership, updates and transforms.

## Display an image

Create graphics with your chosen Max2D backend, then build the visual tree once:

```blitzmax
Import Max2D.Scene

Local scene:TScene = TScene.Create()
Local layer:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(layer)
Local sprite:TSpriteNode = TSpriteNode.Create(myImage)
sprite.SetPosition(320, 180)
layer.AddChild(sprite)
```

In the application's loop, call `scene.Update(dt)` when using update callbacks,
then `scene.Render()` between your own `Cls` and `Flip` calls. Call
`scene.Destroy()` during shutdown. Images and fonts remain application-owned.
A sprite respects its image's handle; `SetFrame` selects an existing frame and
`SetImage` resets the frame to zero. A Null image draws nothing.

See [scene_gallery.bmx](../../examples/scene_gallery.bmx) for a complete runnable
example with moving groups, shared sprites, meshes, text and custom drawing.
It uses generated artwork and a system font when available, falling back to the
built-in font. Space hides the satellites; P pauses updates; Escape exits.

## Groups, colour and visibility

A `TSceneNode2D` groups children without drawing anything itself. All spatial
ancestors contribute their full affine transforms, tint and alpha. Non-spatial
nodes preserve that inheritance. Children draw after their parent, in insertion
order by default. Parents can opt into stable z-index sorting. Root layers draw
in insertion order.

```blitzmax
Local group:TSceneNode2D = New TSceneNode2D
group.SetPosition(200, 120)
group.SetRotation(20)
group.SetTint(120, 220, 255)
group.SetAlpha(0.7)
layer.AddChild(group)
sprite.Reparent(group)
```

Tint channels are 0..255; alpha is 0..1. Invalid values are rejected. Inherited
alpha applies separately to each draw, so overlapping children can build up
opacity. Use [TCompositeNode.SetOpacity](composites.md) for flattened group opacity.
`SetVisible(False)` hides an entire subtree while leaving its updates enabled.

## Text and meshes

`TTextNode.Create(text, font)` requires a non-Null shared `TImageFont`; use
`TImageFont.DefaultFont()` explicitly for the built-in font. `SetText` and
`SetFont` update the node. Text uses the font's normal layout cache, so first use
can allocate layout/glyph resources.

`TMeshNode.Create(mesh)` references an existing `TMesh2D`. `SetMesh(Null)` disables
its own drawing. Neither node takes exclusive ownership of its resource.

## Custom drawing

```blitzmax
Type TBadge Extends TCustomDrawNode
    Method OnDraw(context:TSceneDrawContext)
        context.SetColor(255, 180, 80)
        DrawOval(-16, -16, 32, 32)
        context.SetColor(255, 255, 255)
        context.SetAlpha(0.5)
        DrawRect(-4, -4, 8, 8)
    End Method
End Type
```

Geometry uses ordinary Max2D calls in node-local coordinates. Use the supplied
context to set colour and alpha: it multiplies each supplied value by inherited
values. Repeated context calls are not cumulative. Do not store the context;
it is borrowed only for the callback and reused for other nodes.

Every drawable starts with identity object transform, zero primitive handle and
origin, alpha blending, line width one, and its effective scene transform/tint.
Custom drawing starts with the caller's font. Text nodes select their explicit
font. Changes to these drawing settings do not leak into the next node.

Inside a node method, an unqualified `SetTransform` or `SetAlpha` names the node
setter. For temporary drawing transforms use `TranslateCoordinates`,
`RotateCoordinates` and `ScaleCoordinates`; if needed, qualify low-level setters
as `Max2D.Core.SetTransform`. Use `context.SetAlpha` for inherited opacity.

Do not change the graphics canvas, render target, viewport or virtual presentation,
clear, flip, or mutate the scene from `OnDraw`. Balance any drawing scopes before
returning. Scene setters reject mutation during rendering. The renderer detects
unbalanced scopes and target/view changes on normal callback return. An exception
restores the caller's drawing state and leaves the scene usable for later calls;
already submitted pixels are not rolled back.

## Cameras and clips

Each layer starts with an identity camera. `layer.SetCamera(camera)` snapshots a
`TCamera2D`; editing the supplied object later has no effect until set again.
`SetCamera(Null)` restores identity. Camera offsets use absolute virtual-surface
coordinates. The viewport clips drawing without shifting the camera origin.

`layer.SetViewport(TSceneRect.Create(x, y, width, height))` copies a virtual clip.
Fractional edges round outward to integer virtual coordinates. Zero dimensions
remain empty. `ClearViewport()` uses the caller's clip. A layer clip always
intersects the caller's viewport and cannot enlarge it.

`scene.Render()` draws on the caller's current window or render image and retains
its virtual presentation. It ignores surrounding object/coordinate transforms,
camera, tint and alpha, and restores them afterward, including after a failing
callback. It neither clears the target nor flips the window.

## Bounds and current limits

`GetSelfBounds(rect)` fills reusable caller storage and describes only the node's
own drawing in local coordinates. Plain spatial nodes and empty resources have
empty bounds. Sprites use logical image size and handle; meshes enclose their
vertices; text uses layout ink bounds. Text measurement may build CPU layout data.

Custom nodes default to unknown bounds: False, with output unchanged. Supply
copied bounds using `SetSelfBounds(rect)`, clear them using `ClearSelfBounds()`,
or override `GetSelfBounds`. Unknown does not mean empty.

`GetContentBounds` and `GetOutputBounds` provide cached subtree measurements;
`SetSortableChildren` and `SetZIndex` provide stable sibling ordering. See
[bounds and draw ordering](bounds-order.md) for their contracts and example.

[Culling](culling.md), [coordinate conversion and picking](picking.md),
[scene input](pointer.md) and [composite/effect nodes](composites.md) are available.
Ordinary drawing visits eligible visible nodes in insertion or opted-in sorted
order, with no extra render images or forced flush per ordinary node. Composites
introduce explicit capture and processing boundaries.

## Allocation behaviour and checks

The scene reuses its traversal array, draw context and drawing-state object.
There is one outer `ScopedMax2DState` per render call; it currently allocates.
Backend submission, text/image preparation and custom code can allocate too.
There is no promise that a complete rendered frame allocates zero bytes.

`tests/scene_render.bmx` checks pixels, inherited state, camera snapshotting,
clipping, exception restoration, mutation rejection, and allocation growth when
increasing empty drawables from one to 1,000. Build it with `bmk makeapp -r -t
console`; use `-ud max2d_gl` or `-ud max2d_sdlgpu` to select those backends. The
default is SDL3 Renderer. The test requires a working graphics session.

The existing regression runner also includes these tests. From the SDK root:

```sh
python3 mod/max2d.mod/tests/run_regressions.py core --test scene_foundation
python3 mod/max2d.mod/tests/run_regressions.py sdl gl sdlgpu --test scene_render
```

## Textured meshes

A `TMesh2D` can carry one normalized UV pair per vertex. Supply UVs as the third
argument to `Create`, or replace them with `SetUV`. Both operations copy arrays.
UVs must be finite and in 0..1; they address the complete logical image rectangle.

```blitzmax
Local mesh:TMesh2D = TMesh2D.Create( ..
    [0.0,0.0,160.0,0.0,160.0,80.0,0.0,80.0], ..
    [0,1,2,0,2,3], ..
    [0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0])
Local panel:TMeshNode = TMeshNode.Create(mesh,image)
layer.AddChild(panel)
```

For immediate drawing, use `DrawTexturedMesh(mesh,image,x,y,frame)`. Scene nodes
support `SetImage` and `SetFrame`; clearing the image restores filled mesh drawing.
Mesh geometry supplies bounds and placement; image handles are ignored. Default
picking still uses the mesh bounds, not per-triangle or texture-alpha coverage. Current
transforms, tint, alpha, blend and clipping still apply. Interpolation is affine
within each triangle, so triangle placement matters for deformed artwork. There
is no automatic perspective correction or repeating UV mode.

Atlas frames map UVs into their stored rectangle with ordinary image filtering
rules. Trimmed CPU byte images use the existing image-owned expanded sampling
storage, preserving transparent margins. Unsupported trimmed storage throws. The
first use may prepare this storage; unchanged draws reuse it. Nodes share meshes
and images and do not release application artwork.

For animated geometry, edit the retained `mesh.xy` array and call
`node.InvalidateContent()`. Use the same notification after UV or artwork pixel
edits, on every affected scene consumer. Raw array edits must
preserve valid indices, lengths and finite UVs in range. `SetUV` validates a
replacement before changing it. Cached composites observe these notifications.

[Textured mesh example](../../examples/scene_textured_mesh.bmx) deforms a grid
without rebuilding the mesh or image each frame. Build it from the SDK directory:

```sh
bin/bmk makeapp -r -t gui -o /tmp/TexturedMesh mod/max2d.mod/examples/scene_textured_mesh.bmx
```

The default is SDL renderer; add `-ud max2d_sdlgpu` or `-ud max2d_gl` for those
backends, or `-ud max2d_d3d9` / `-ud max2d_d3d11` on Windows. A console build
with `--test` renders three frames and exits. This is ordinary textured drawing;
use `TLitMeshNode` for [direct mesh lighting](../lighting.md#direct-textured-mesh-receivers).
Per-vertex colour is not implemented.

[Textured-mesh validation](validation/2026-11-23-textured-mesh.md) records image
parity and cache checks across the supported rendering paths.
