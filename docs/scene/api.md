# Scene API outline

**Implemented API overview; the [foundation](foundation.md), [rendering](rendering.md),
[bounds/ordering](bounds-order.md), [picking](picking.md),
[pointer routing](pointer.md), and [hover/keyboard focus](interaction.md) and [culling/render counters](culling.md) subsets are implemented.**
The [layout, chain, bloom and shadow stages](stages.md) and
[composite nodes with automatic caching](composites.md) are also implemented.
The outline records the main APIs alongside the [behavioural specification](design.md).
Module bbdoc is the complete reference; planned work is listed separately in the
[development sequence](design.md#development-sequence). This is not a
compilable module header. Implementation state is inaccessible to application
code. Snapshot/value objects may be mutable; changing them never changes the
scene that returned them.

## Scene and tree

```blitzmax
' TScene
Function Create:TScene()
Method Root:TSceneNode()
Method Reserve(nodeCapacity:Int = 64, operationCapacity:Int = 64)
Method ReservePointers(capacity:Int = 8)
Method TrimStorage()
Method DiscardedOperations:Long()
Method Update(dt:Double)
Method FixedUpdate(dt:Double)
Method Render()
Method SetCulling(enabled:Int)
Method SetPaused(paused:Int)
Method SetInputClip(rect:TSceneRect)
Method Pick:TSceneNode2D(x:Float, y:Float)
Method DispatchPointer:Int(kind:EScenePointerKind, deviceId:Long, pointerId:Long, x:Float, y:Float, button:Int = 0, buttons:Int = 0)
Method DispatchKey:Int(kind:ESceneKeyKind, key:Int, modifiers:Int = 0, repeated:Int = False)
Method CancelInput()
Method SetPointerHover(deviceId:Long, pointerId:Long, enabled:Int = True)
Method FocusedNode:TSceneNode2D()
Method SetFocus(node:TSceneNode2D)
Method FocusNext(reverse:Int = False)
Method LocalToScreen:Int(node:TSceneNode, x:Float, y:Float, screenX:Float Var, screenY:Float Var)
Method ScreenToLocal:Int(node:TSceneNode, x:Float, y:Float, localX:Float Var, localY:Float Var)
Method SetStorageLimitBytes(bytes:Long)
Method GetStorageLimitBytes:Long()
Method RetainedStorageBytes:Long()
Method ReleaseResources()
Method Destroy()
Method InspectTree:String()
Method CaptureStats:TSceneStats()
Method CopyStats(output:TSceneStats)
Method SetDebugOverlay(enabled:Int)
Method GetDebugOverlay:Int()

' TSceneNode
Method SetName(name:String)
Method GetName:String()
Method Parent:TSceneNode()
Method Scene:TScene()
Method ChildCount:Int()
Method ChildAt:TSceneNode(index:Int)
Method ReserveChildren(capacity:Int)
Method SetSortableChildren(enabled:Int)
Method Children:TSceneNode[]() ' Detached array snapshot.
Method AddChild(child:TSceneNode, index:Int = -1)
Method RemoveChild(child:TSceneNode)
Method Reparent(parent:TSceneNode, preserveWorld:Int = False)
Method Destroy()
Method SetProcessing(enabled:Int)
Method SetFixedProcessing(enabled:Int)
Method SetProcessWhenPaused(enabled:Int)
Method SetInputEnabled(enabled:Int)

' Overridable lifecycle/processing hooks on TSceneNode.
Method OnEnterScene()
Method OnReady()
Method OnExitScene()
Method OnDestroy()
Method OnUpdate(dt:Double)
Method OnFixedUpdate(dt:Double)
Method OnReleaseResources()
Method OnPointerCapture(event:TScenePointerEvent)
Method OnPointer(event:TScenePointerEvent)
Method OnPointerBubble(event:TScenePointerEvent)
Method OnKeyCapture(event:TSceneKeyEvent)
Method OnKey(event:TSceneKeyEvent)
Method OnKeyBubble(event:TSceneKeyEvent)
```

Time arguments are finite nonnegative seconds. FixedUpdate is one explicit
step; the application owns its accumulator and interpolation policy. Neither
Update nor FixedUpdate polls native input. Multiple update steps before a render
are supported. Nested traversal on the same scene is rejected.

`CancelInput` cancels pointer captures and active presses, clears hover state,
and drops keyboard focus. Call it on application focus loss or input-device
reset. Synthetic cancellation does not require a valid pointer position.
`DispatchPointer`/`DispatchKey` accept primitive values and reject nested public
dispatch on the same scene. Callback event objects are borrowed and reusable;
`Copy()` creates a durable data snapshot. `SetFocus(Null)` clears focus. Setting focus to an
unattached or ineligible node is an error. FocusNext does nothing when no eligible
node exists. The scene root cannot be detached or reparented.

The shared scene budget covers registered composite targets and temporary
replacement reservations, excluding shared application assets and driver overhead.
`SetStorageLimitBytes(bytes)` defaults to 256 MiB and requires positive bytes at
least as large as current ownership. `GetStorageLimitBytes()` returns the limit;
`RetainedStorageBytes()` returns current registered usage. See the
[composition guide](composites.md) for lifecycle and provider rules.

The implemented [render counters](culling.md) cover traversal, culling, bounds,
world-matrix rebuilding, captures, stage updates and cache hits. Stats also expose
`RetainedStorageBytes()` and `PeakStorageBytes()` for the most recent render.
Tree inspection and the bounds/hit-region overlay are also implemented; see the diagnostic guide.
Statistics cover the most recent render; structural-command diagnostics are
cumulative. Tree inspection performs no GPU reads. TSceneStats provides read-only counts for
node visits, culled nodes, local/world transform recomputations, bounds
recomputations, captures, stage passes, cache hits, estimated owned texture
bytes and texture allocations. Overlay drawing is excluded from scene statistics
but still appears in the backend's ordinary drawing statistics.

## Value objects

`TSceneRect.Create(x, y, width, height)` creates a detached rectangle with public
Float fields of those names. `TSceneTransform.Create(xx, xy, yx, yy, tx, ty)`
creates a detached affine matrix: x maps to `xx*x + xy*y + tx`, y maps to
`yx*x + yy*y + ty`. Setters validate and copy these values. Snapshot fields can
be edited without invalidating scene state because the scene does not retain
the snapshot as its internal state.

## Spatial nodes and views

```blitzmax
' TSceneNode2D Extends TSceneNode
Method SetPosition(x:Float, y:Float)
Method GetPosition(x:Float Var, y:Float Var)
Method SetRotation(degrees:Float)
Method SetScale(x:Float, y:Float)
Method SetPivot(x:Float, y:Float)
Method SetTransform(x:Float, y:Float, rotation:Float, scaleX:Float = 1, scaleY:Float = 1, pivotX:Float = 0, pivotY:Float = 0)
Method SetLocalTransform(transform:TSceneTransform)
Method LocalTransform:TSceneTransform()
Method WorldTransform:TSceneTransform()
Method CopyLocalTransform(output:TSceneTransform)
Method CopyWorldTransform(output:TSceneTransform)
Method LocalToWorld:Int(x:Float, y:Float, worldX:Float Var, worldY:Float Var)
Method WorldToLocal:Int(x:Float, y:Float, localX:Float Var, localY:Float Var)
Method SetVisible(visible:Int)
Method SetTint(red:Int, green:Int, blue:Int)
Method SetAlpha(alpha:Float)
Method SetZIndex(index:Int)
Method GetSelfBounds:Int(bounds:TSceneRect)
Method GetContentBounds:Int(bounds:TSceneRect)
Method GetOutputBounds:Int(bounds:TSceneRect)
Method SetInteractive(enabled:Int)
Method SetHitRect(rect:TSceneRect)
Method ClearHitRect()
Method HitTestLocal:Int(x:Float, y:Float)
Method SetFocusable(enabled:Int)
Method SetFocusOrder(order:Int)
Method OnFocusGained()
Method OnFocusLost()
Method InvalidateContent()

' TLayerNode Extends TSceneNode; may only attach directly to TScene.Root().
Function Create:TLayerNode()
Method SetCamera(camera:TCamera2D)
Method SetViewport(rect:TSceneRect)
Method ClearViewport()
```

Tint channels are 0..255 and alpha is 0..1; setters reject values outside these
ranges. Camera, transform and rectangle setters copy their arguments. A Null
camera is identity. Layer viewport coordinates refer to the scene's virtual
surface. Unset viewport uses that entire surface intersected with caller clip.
Spatial conversion queries resolve dirty matrices immediately, without requiring
Update or Render first. Detached trees have a local root world space; conversion
to screen requires attachment beneath a layer. False indicates unavailable or
singular mapping; output parameters remain unchanged on failure.

Bounds queries fill a caller-owned rectangle. False means unknown, True with
zero width/height means empty. Self bounds include only the node's own drawing;
content bounds include visible descendants; output bounds include compositing
expansion. All three are in that node's local space. Rectangles have finite
coordinates and nonnegative sizes. A plain TSceneNode2D has empty self bounds.
`SetHitRect` copies the rectangle and does not change drawing bounds. The default
HitTestLocal uses the explicit hit rectangle or self bounds, with inclusive
left/top and exclusive right/bottom edges. Subclasses may implement another
local shape without GPU readback.

## Drawables and custom drawing

```blitzmax
' TSpriteNode Extends TSceneNode2D
Function Create:TSpriteNode(image:TImage, frame:Int = 0)
Method SetImage(image:TImage)
Method SetFrame(frame:Int)

' TTextNode Extends TSceneNode2D
Function Create:TTextNode(text:String, font:TImageFont)
Method SetText(text:String)
Method SetFont(font:TImageFont)

' TMeshNode Extends TSceneNode2D
Function Create:TMeshNode(mesh:TMesh2D, image:TImage = Null, frame:Int = 0)
Method SetMesh(mesh:TMesh2D)
Method SetImage(image:TImage)
Method SetFrame(frame:Int)

' TCustomDrawNode Extends TSceneNode2D
Method SetSelfBounds(rect:TSceneRect)
Method ClearSelfBounds()
Method GetSelfBounds:Int(bounds:TSceneRect) ' Override for calculated bounds.
Method OnDraw(context:TSceneDrawContext)     ' Override for local drawing.

' TSceneDrawContext, valid only during OnDraw.
Method SetColor(red:Int, green:Int, blue:Int)
Method SetAlpha(alpha:Float)
```

TCustomDrawNode defaults to unknown bounds. SetSelfBounds supplies a copied
rectangle for the default bounds implementation; ClearSelfBounds makes it
unknown again. Custom subclasses can override GetSelfBounds instead. Custom
bounds and content must be invalidated when their underlying application data
changes. These nodes also inherit normal children, transforms and interaction.

A sprite's default frame is zero; a frame must exist in its image. SetImage
resets its frame to zero. Null image/mesh is allowed and draws nothing with empty
bounds. Text requires a supplied font, avoiding dependence on unrelated global
font state. Empty text has empty bounds. Resource-dependent queries require the
resource's CPU metadata, but never materialise a GPU frame just to measure it.

Context colour/alpha setters are relative to inherited effective tint/alpha,
not cumulative with earlier calls in the same hook. The draw context starts at
white/local alpha one. Line width, font and blend start at documented defaults
(1, the scene's built-in default font and ALPHABLEND) for each custom draw;
custom nodes may change those using ordinary Max2D state functions. Context
instances are borrowed and cannot be retained after the hook.

## Input records

```blitzmax
' EScenePointerKind: Down, Move, Up, Cancel, Enter, Leave, CaptureLost
' ESceneKeyKind: Down, Up

' TScenePointerEvent
Method Copy:TScenePointerSnapshot()
Method Kind:EScenePointerKind()
Method DeviceId:Long()
Method PointerId:Long()
Method ScreenX:Float()
Method ScreenY:Float()
Method Button:Int()
Method Buttons:Int()
Method Target:TSceneNode2D()
Method CurrentTarget:TSceneNode()
Method PositionIn:Int(node:TSceneNode, x:Float Var, y:Float Var)
Method CapturePointer(node:TSceneNode2D)
Method ReleasePointer()
Method Handle()
Method StopPropagation()

' TSceneKeyEvent
Method Copy:TSceneKeySnapshot()
Method Kind:ESceneKeyKind()
Method Key:Int()
Method Modifiers:Int()
Method Repeated:Int()
Method Target:TSceneNode2D()
Method CurrentTarget:TSceneNode()
Method Handle()
Method StopPropagation()
```

Callback events must not be stored after the callback returns. Their `Copy()`
snapshots retain scalar input data and target/current-target references as they
were at copy time, with no capture, propagation or coordinate-query methods.
Snapshots therefore keep those nodes reachable until the snapshots are released.
Store scalar IDs instead when node retention is unwanted.

SetInputClip copies the interactive presentation's outer clip in virtual
coordinates. It is required before pointer hit testing; before it is supplied,
uncaptured pointer events have no hit target. It does not set the rendering
viewport. Applications keep it in sync with the viewport they use for the
interactive presentation. Offscreen renders do not overwrite it. Captured
pointers continue receiving events outside this clip; adapters must forward
unclipped coordinates for move/up rather than discarding them at the window edge.

Native input adapters inject Down/Move/Up/Cancel; Enter/Leave/CaptureLost are
scene-generated. Pointer positions are scene virtual coordinates. PositionIn
performs the same inverse view and node transform as picking and returns False
for invalid mappings or events without a usable position. This also works for a
non-spatial node by using its inherited transform. Cancel input positions are
ignored. Button/key values follow existing BRL input constants; modifier bits
are `SCENE_MOD_SHIFT=1`, `SCENE_MOD_CONTROL=2`, `SCENE_MOD_ALT=4` and
`SCENE_MOD_META=8`, with adapters responsible for mapping.

Only the current callback receiver may claim capture for itself, and it must
be an eligible TSceneNode2D on the dispatch path for that pointer's Down event.
Claiming an already captured pointer for another node is rejected. ReleasePointer
is valid only for the capture owner during its pointer callback. Capture ends
automatically after Up; explicit release and automatic end deliver CaptureLost.
Cancel delivers Cancel then CaptureLost. Enter/Leave target individual nodes
and do not bubble. Other pointer kinds use the normal dispatch path. Keyboard
records contain physical key actions, not composed text.

## Composition extension

Layouts, the base stage contract, chain/bloom/shadow/lighting/alpha-mask stages and TCompositeNode are
implemented; see the [stage guide](stages.md) and [composite guide](composites.md).
Shared scene and per-composite budgets are implemented.

```blitzmax
' ESceneCacheMode: None, Automatic

' TCompositeNode Extends TSceneRenderGroup; in Max2D.SceneEffects
Function Create:TCompositeNode()
Method SetStages(stages:TSceneEffectStage[])
Method SetCacheMode(mode:ESceneCacheMode)
Method SetOpacity(opacity:Float)
Method SetCaptureRect(rect:TSceneRect)
Method SetClipRect(rect:TSceneRect)
Method CopyClipRect:Int(output:TSceneRect)
Method ClearCaptureRect()
Method SetResolutionScale(scale:Int)
Method SetPixelFormat(format:Int)
Method SetStorageLimitBytes(bytes:Long)
Method InvalidateEffects()

' TSceneEffectStage: abstract stage, configured before attachment.
Method Invalidate()
Method Revision:Long()

' TSceneChainStage Extends TSceneEffectStage
Function Create:TSceneChainStage(effects:TMax2DImageEffect[], left:Float = 0, top:Float = 0, right:Float = 0, bottom:Float = 0)

' TSceneAlphaMaskStage Extends TSceneEffectStage
Function Create:TSceneAlphaMaskStage(mask:TImage, rect:TSceneRect, inverted:Int = False)
Method SetMask(image:TImage, region:TSceneRect, inverse:Int = False)
Method SetMaskRect(region:TSceneRect)
Method SetInverted(value:Int)
Method SetInputMask(pixmap:TPixmap, threshold:Int = 1)

' TSceneSubtreeMaskStage Extends TSceneEffectStage
Function Create:TSceneSubtreeMaskStage(source:TSceneNode2D, inverted:Int = False)
Method SetSource(source:TSceneNode2D)
Method SetOffset(x:Float, y:Float)
Method SetInverted(value:Int)

' TSceneBloomStage Extends TSceneEffectStage
Function Create:TSceneBloomStage(threshold:Float = 1, radius:Float = 8, intensity:Float = 1)
Method SetThreshold(threshold:Float)
Method SetRadius(radius:Float)
Method SetIntensity(intensity:Float)
Method SetOpaqueBackground(value:Int)
Method GetOpaqueBackground:Int()
```

Composite defaults: no stages, cache None, opacity one, automatic capture
bounds, resolution scale one, RGBA8888. Stage padding is finite nonnegative
logical units. The current per-composite storage limit defaults to 64 MiB. Stage setters and Invalidate notify their attached composite.
SetStages copies the array; stage instances cannot appear twice or belong to two
composites. Replacing with the same instances preserves ownership where possible
but invalidates processing. Chain-stage effect descriptions remain shared; its
array is copied. Reconfigure its effect sequence by supplying a new stage.

`SetClipRect` clips drawing and fresh picking in local coordinates;
`SetCaptureRect` alone crops drawing. Image-alpha masks leave picking unchanged
until `SetInputMask` supplies an explicit copied CPU snapshot. Live subtree masks
leave picking unchanged and do not offer an implicit pixel-coverage snapshot. See the
[mask guide](stages.md#local-alpha-masks) for filtering, inversion and stage order.

Bloom radius is logical; raw chain parameters retain their existing units.
Scene bloom validates nonnegative finite threshold, radius and intensity.
Changing radius can change both output bounds and blur storage. Floating-point
output requires an explicit supported composite pixel format. Scene bloom
defaults to transparent composition; SetOpaqueBackground(True) selects opaque black.

Custom providers implement these hooks on TSceneEffectStage. Applications
configure stages; the scene invokes the hooks and owns their call order.

```blitzmax
' TSceneEffectStage provider hooks.
Method HitTestInputClip:Int(x:Float, y:Float) ' Defaults to True.
Method ExpandBounds(input:TSceneRect, output:TSceneRect) Abstract
Method EstimateStorageBytes:Long(layout:TSceneStageLayout) Abstract
Method Prepare(layout:TSceneStageLayout) Abstract
Method Update:TRenderImage(source:TRenderImage) Abstract
Method UpdateInGroup:TRenderImage(source:TRenderImage, context:TSceneGroupContext) ' Defaults to Update.
Method ReleaseResources() Abstract

' TSceneStageLayout is a read-only layout descriptor.
Function Create:TSceneStageLayout(canvas:TSceneRect, resolutionScale:Int = 1, pixelFormat:Int = PF_RGBA8888)
Method PixelWidth:Int()
Method PixelHeight:Int()
Method ResolutionScale:Int()
Method PixelFormat:Int()
Method CanvasRect:TSceneRect() ' Detached logical rectangle, including padding.
Method CopyCanvasRect(output:TSceneRect)
Method EstimateImageBytes:Long(count:Int = 1)
```

ExpandBounds receives a detached input and must fill a finite rectangle containing
it; the initial interface permits expansion, not cropping or moving the content.
The framework computes a common canvas from all stages before preparation.
EstimateStorageBytes reports a conservative bound for the layout's image storage,
including scratch and any temporary candidate storage. Existing storage is
accounted separately during replacement. Providers must not allocate beyond
that declared bound; stable-layout Update must allocate no render images.
Scene budgets and byte statistics use these estimates, excluding driver overhead.
Prepare receives the final full-canvas layout, allocates retained storage on the
current context and validates processing support against the actual output targets.
It preserves caller state and existing storage on failure where possible.
Support cannot be inferred from the window target's format; source-specific
validation still happens during Update. Repeated identical preparation must reuse
storage.

Update takes the full padded source canvas and returns distinct, same-sized,
same-format borrowed output. The stage preserves source pixels and caller state;
it must not alias its result with the source. A later update, reprepare or release
may invalidate the returned image. ReleaseResources is idempotent and retains
configuration. Configuration setters call the base Invalidate method, which
increments a private revision and notifies the attached composite. Updating
pixels itself does not change that configuration revision.

These hooks expose backend-independent layout and ownership, without exposing
scratch indices or native graphics commands. The first two built-in adapters
must use the same contract as external stage implementations.

## Defaults and extension boundaries

A new node is detached, named with an empty string, not processing, input-enabled,
and not opted into processing while paused. A spatial node is visible, white,
alpha one, at identity transform, z-index zero, with sorting off, interaction off
and focus off. A new scene is unpaused. Animation, pointer adapters, tilemaps and
physics are explicit application dependencies. No native resources are allocated
by these constructors.

The working examples deliberately use factories and subclasses, with no string
method lookup or reflection requirement. A later saved-scene facility can use
registered factories and asset references while preserving these same setters,
attachment hooks and resource rules.

## Direct lit meshes (`Max2D.SceneLighting`)

```blitzmax
' TLitNode subclass drawing helper
Method DrawLitMesh(mesh:TMesh2D, image:TImage, frame:Int = 0)

' TLitMeshNode Extends TLitNode
Function Create:TLitMeshNode(mesh:TMesh2D, image:TImage, lighting:TSceneLighting, material:TMax2DLightingMaterial = Null)
Method SetMesh(value:TMesh2D)
Method SetImage(value:TImage) ' resets frame zero
Method SetFrame(value:Int)
```

Null geometry/artwork draws nothing. Bounds follow geometry, ignoring image
handles. Material/environment behavior follows `TLitSpriteNode`. Call
`InvalidateContent` after shared geometry, UV or artwork edits. Lighting can group
eligible non-overlapping affine meshes as a whole; other meshes retain grouped or
ordinary passes per triangle. See [mesh lighting](../lighting.md#direct-textured-mesh-receivers)
for UV constraints, costs and a worked example.

## Material map selections (`Max2D.Lighting`)

```blitzmax
' TMax2DLightingMaterial
Method SetEmissionMap(image:TImage, frame:Int = 0)
Method GetEmissionMap:TImage()
Method GetEmissionFrame:Int()
Method SetSpecularMap(image:TImage, frame:Int = 0)
Method GetSpecularMap:TImage()
Method GetSpecularFrame:Int()
Method InvalidateMaps()
Method ReleaseResources()
```

Maps are optional shared artwork. Specular maps use retained CPU packing with
matching normal dimensions; emission maps use a dedicated ambient shader. See
[material map usage and limits](../lighting.md#emission-and-separate-specular-maps).
