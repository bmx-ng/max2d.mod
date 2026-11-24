# Composite nodes and caching

Import `Max2D.SceneEffects` to use `TCompositeNode`. A composite always captures
its children into an image, then presents that image as one scene drawable.
It is useful for group opacity, effect chains and caching static subtrees.
Ordinary `TSceneNode2D` groups still draw directly without capture resources.

```blitzmax
Local group:TCompositeNode = TCompositeNode.Create()
layer.AddChild(group)
group.AddChild(TSpriteNode.Create(image))
group.SetCacheMode(ESceneCacheMode.Automatic)
group.SetOpacity(0.7)
group.SetPosition(200, 120)

' Optional: import an effects provider matching the graphics backend.
Local stage:TSceneChainStage = TSceneChainStage.Create( ..
    [TMax2DImageEffect(CreateSaturationEffect(0))])
group.SetStages([TSceneEffectStage(stage)])
```

No GPU resources are allocated by construction. The first nonempty visible render
prepares the capture and stage images. With no stages, only the capture is needed;
this works without a shader provider on backends supporting render images.
Unsupported effects report an error during preparation.

## Opacity and inherited colour

`SetAlpha` retains the normal scene behaviour: alpha is inherited by each child
draw. Overlapping children therefore accumulate opacity. `SetOpacity` applies
once to the flattened composite, so its overlapping regions fade together.

Inherited tint and per-draw alpha are baked into captured pixels. Composite
opacity is applied when presenting them. Moving, rotating, scaling or changing
the opacity of a composite reuses its own local pixels. An enclosing composite
must refresh because its view of that child has changed. Capture uses local
transform chains, so no inverse of the group's world transform is required.

## Automatic caching

The default `ESceneCacheMode.None` captures and processes on every render.
`Automatic` skips that work while tracked dependencies remain unchanged.
The choice changes reuse, not group-opacity or effect semantics.

| Change | Own capture | Enclosing capture |
| --- | --- | --- |
| Composite position, rotation, scale or flattened opacity | Reuse | Refresh |
| Inherited tint or per-draw alpha | Refresh | Refresh |
| Child geometry, transform, visibility, order, text or image | Refresh | Refresh |
| Attached stage invalidation | Reuse if capture layout is unchanged; rerun changed stage and successors | Refresh |
| Capture region, resolution or format | Reprepare and refresh | Refresh |
| Layer camera or viewport | Reuse | Reuse |

An Automatic ancestor cannot freeze a visible descendant using None: it refreshes
so the descendant gets rendered. This dependency is retained with subtree bounds;
unchanged cached groups do not walk their children to rediscover it each frame.
Hidden descendants do not force capture work.

Custom drawing data and shared image/mesh/font edits need `InvalidateContent()`
on affected nodes. After editing a raw effect description, call the attached
stage's `Invalidate()` or the composite's `InvalidateEffects()`. The notification
propagates to enclosing captures. Effect-only changes reuse source pixels when
the rounded canvas, inherited tint and child content are unchanged. A changed
canvas origin, padding extent, resolution or format requires a fresh capture.
With an unchanged canvas, stage setters and `stage.Invalidate()` preserve the
outputs before the earliest changed stage. That stage and its successors are
prepared and updated in order. For example, moving an alpha mask after bloom
reuses the completed bloom output. No extra textures are needed: the composite
retains references to outputs already owned by its stages.

`group.InvalidateEffects()` explicitly refreshes the entire chain. Use it when
several shared descriptions changed and you do not invalidate each owning stage.
Source changes rerun all stages; canvas changes, replacing/reordering the stage
list, resource release and failed processing discard reuse. Custom stage outputs
must remain valid until that stage is updated, re-prepared or released, as defined
by the stage contract. Skipped stages receive neither Prepare nor Update.

Keep gameplay in update callbacks: cached children may not receive OnDraw.
Updates, picking and focus continue to use the live scene tree.

## Capture bounds, padding and resolution

Automatic sizing requires complete known drawing bounds. It includes nested
composites' effect-expanded output, while `GetContentBounds()` on the composite
itself describes its content before its own stages. `GetOutputBounds()` includes
its stage padding. Culling uses output bounds so an onscreen halo is retained
even if the source geometry is outside the viewport. Effects do not enlarge
pointer hit regions.

For unbounded custom drawing or a stable region:

```blitzmax
group.SetCaptureRect(TSceneRect.Create(-20, -10, 320, 180))
group.SetResolutionScale(2)
```

The capture region clips children before stage processing. Stage padding lies
outside it and starts transparent. Negative and fractional origins are accepted;
both canvas allocation and fixed-region clipping round outward to whole logical
units. `ClearCaptureRect()` restores automatic sizing. Empty captures do no image
or stage work. Existing storage can remain retained until reuse or release.

Resolution defaults to one pixel per logical unit. Higher resolution is explicit:
camera zoom does not silently allocate larger textures. Chain descriptions retain
their original pixel/UV parameter units. `SetPixelFormat` accepts RGBA8888,
RGBA16F or RGBA32F, subject to backend support. See the
[stage guide](stages.md) for padding and provider contracts.

## Local rectangular clipping

Use `SetClipRect` when the visible boundary should also limit pointer picking:

```blitzmax
Local panel:TCompositeNode = TCompositeNode.Create()
layer.AddChild(panel)
panel.SetClipRect(TSceneRect.Create(0, 0, 320, 180))
panel.SetCacheMode(ESceneCacheMode.Automatic)
panel.SetPosition(200, 120)
panel.SetRotation(15)
panel.AddChild(content)
```

The rectangle is copied in the composite's local coordinates. Rendering and
fresh picking use the same edges, rounded outward to whole logical units,
regardless of resolution scale. Left/top edges are inclusive; right/bottom
edges are exclusive. A zero width or height hides the contents and rejects
picking. Rotation, reflection, shear and layer cameras transform the clipped
result normally; picking tests the local rectangle, not its screen bounding box.
Nested clips intersect. A captured pointer continues receiving move/up events
outside the clip so a drag can finish normally.

`CopyClipRect(destination)` copies the effective rounded rectangle without
allocating, returning False without changing the destination when no input clip
is active. `SetCaptureRect` replaces the region with a drawing-only crop and
removes the input restriction. `ClearCaptureRect` removes either kind of region
and restores automatic capture sizing. Changing a clip invalidates the capture
and enclosing cached composites immediately.

Clipping occurs **before effects**. A glow or shadow may extend beyond the
rectangle. To clip the finished effect, put the effected group inside an outer
composite and set the clip on that outer group. Effects and transparent image
pixels do not automatically change picking; `SetClipRect` supplies rectangular
clipping only. An [alpha-mask stage](stages.md#local-alpha-masks) can additionally
apply image coverage and an explicit CPU input mask.

Each clipped composite uses an offscreen capture, with the same caching,
resolution, storage budgets and explicit resource cleanup as other composites.
Use ordinary layer viewports for screen-aligned clipping when a local transformed
boundary is unnecessary. See [scene_clipping.bmx](../../examples/scene_clipping.bmx)
for animated, rotated and nested panels, with pointer picking and cache counters.

## Stage ownership and resources

`SetStages` copies the array and owns each attached stage's mutable storage.
Duplicate entries and stages already attached elsewhere are rejected before
ownership changes. Removed stages release storage and can be attached elsewhere.
Do not manually prepare, update or release an attached stage. Configuration
setters and `Invalidate()` remain available between scene traversals.

Each composite defaults to a **64 MiB texture-storage limit**, configurable with
`SetStorageLimitBytes(bytes)`. This checks the capture and every stage's declared
storage. Preparation checks retained storage plus providers’ additional peak
allocation estimates. Stable built-in stage layouts need no replacement textures.
Removed stages return their estimated storage immediately after successful release.
Nested composites have separate limits and also share the scene budget, which
defaults to **256 MiB**. Estimates exclude shared application images/fonts,
driver overhead and pipeline caches. There is no automatic eviction.

```blitzmax
scene.SetStorageLimitBytes(32 * 1024 * 1024)
group.SetName("Inventory preview") ' Included in shared-budget errors.
scene.Render()
scene.CopyStats(stats)
Print "Retained bytes: " + stats.RetainedStorageBytes()
Print "Peak reservation: " + stats.PeakStorageBytes()
```

The scene limit must be positive. Lowering it below currently charged storage
is rejected without changing it. Every preparation reserves old plus candidate
storage before allocating: a resize can exceed the limit even if its final
result would fit. A rejection identifies the group, its requested peak, other
groups' ownership and the scene limit. The message includes the node's name and
its child-index path from the root, so unnamed groups can also be distinguished.

Hidden and detached groups remain charged while their textures exist.
`scene.ReleaseResources()` releases registered detached captures too, preserving
the detached nodes. `scene.Destroy()` does the same while destroying its attached
tree. Release a prepared group before rendering it in another scene. A detached
group can also release explicitly through its resource-release hook.

`scene.RetainedStorageBytes()` reports current ownership after edits or cleanup.
The stats methods describe the last render attempt: retained bytes at exit and
the highest accepted reservation, starting with ownership at entry. Rejected
requests do not inflate the peak. Estimates may conservatively retain a charge
when a custom provider fails to release resources.

Rendering failures invalidate output and attempt to release owned storage.
Partially processed or stale pixels are not presented as a successful result.
Caller target and drawing state are restored when capture or a child throws.

Use `scene.ReleaseResources()` to release prepared storage while preserving the
tree and configuration. The next render recaptures it. `scene.Destroy()` also
releases resources. There are no GC finalizers for graphics cleanup. Subclasses overriding
OnReleaseResources or OnDestroy must call the inherited implementation. Detached
subtrees retain their resources until explicitly released or destroyed.

A prepared scene is bound to one live graphics context. Release its resources
before rendering on another live context. After its context closes, the next
render releases invalid resources before preparing them on the new context.
Different render targets on the same context share the retained pixels.

## Diagnostics and example

`TSceneStats.Captures()`, `CacheHits()` and `StagePasses()` report the most recent
render. A stage update may perform multiple GPU draws; StagePasses counts stage
updates, not GPU draw calls. Warm Automatic output performs no captures, stage
updates or texture allocations. Drawing it still uses the scene's normal outer
state scope.

[scene_composite.bmx](../../examples/scene_composite.bmx) compares per-draw alpha,
flattened opacity and a processed composite. The groups move continuously while
their captures remain cached. A animates a child; C changes cache mode; Space
changes saturation; B switches to animated bloom intensity; O toggles its opaque
background; S changes resolution between 1x and 2x; R releases resources.
D toggles diagnostic bounds; I prints an inspection snapshot to standard output. The HUD shows the resulting work.

```sh
./bin/bmk makeapp -r -t gui mod/max2d.mod/examples/scene_composite.bmx
```

Run from the SDK root. Add `-ud max2d_gl` for OpenGL; the default is SDL GPU.

Custom composition providers can extend `TSceneRenderGroup` in `Max2D.Scene`.
Its borrowed `TSceneGroupContext` captures children and records diagnostics
without exposing internal tree storage. Most applications should use composite
nodes and implement custom `TSceneEffectStage` providers only when needed.
Custom render-group providers call `context.ReserveStorageBytes(peak)` before
allocating, then `ReportStorageBytes(finalBytes)` after preparation. Release paths
report reduced ownership, reaching zero only after successful cleanup. Standalone
stages and application-owned images are outside this registered accounting.


### Capturing a selected subtree

Custom `TSceneRenderGroup` providers can call
`context.RenderSubtree(source, offsetX, offsetY)` during `OnRenderGroup`.
Select and clear a capture target first. The source must be a live
`TSceneNode2D` in the same scene; the method draws that node and its descendants.
It includes the source's own local transform, tint, alpha and visibility, while
excluding all ancestor transforms, tint, visibility, cameras and layer viewports.
The offsets translate the result in the source parent's local coordinate system.
The current target's virtual resolution and clip still apply. Caller drawing
state, target and viewport are restored even when drawing throws.

For example, a source at `(20, 30)` captured with offsets `(-20, -30)` begins at
the capture origin. Putting that source below a hidden parent suppresses its
ordinary presentation without hiding it during explicit capture. The source's
own `SetVisible(False)` still hides the capture. Ownership and input routing
remain unchanged; use the existing input-enable controls independently.

This method allocates no target and preserves source ownership. Nested composites
retain their normal caching and scene storage accounting. Each explicit capture
increments the capture counter. Traversal storage is reused after growth; drawing
scope bookkeeping may allocate. The source is checked for active render groups
before drawing, including hidden branches. A request containing an already active
render group is rejected before that request draws pixels. This runtime guard
is separate from configuration-time validation of a complete dependency graph.

This is a provider primitive. It does not
register dependencies or invalidate a consumer's cached output when its source
changes. Providers must arrange refreshes themselves. For automatically tracked masks, use
[`TSceneSubtreeMaskStage`](stages.md#live-subtree-alpha-masks), which supplies
dependency invalidation and explicit source lifetime/input rules. Do not retain the borrowed context or use it outside its callback.

`tests/scene_subtree_capture.bmx` checks isolated transforms/tint, hidden ancestors,
source visibility/alpha, reflected geometry, invalid and recursive sources,
failure recovery, nested composite caching and resource release.


Providers with external dependencies can opt into `SetRenderPreparation(True)`
and override `PrepareRenderDependencies(epoch)`. The scene calls only registered
groups before drawing, including hidden groups; registration follows attachment
and destruction. Hooks may invalidate output but must not draw, change structure
or preparation membership, or start another scene traversal. A hook exception
aborts the frame before scene submission. `TSceneSubtreeMaskStage` manages this
registration for its owning composite; application code need not enable it.
`VisualRevision()` tracks an isolated subtree's drawing and own placement, excluding
ancestor properties; explicit external-resource invalidation remains necessary.


## Preparing dependencies in custom providers

A `TSceneRenderGroup` provider can opt into the scene's pre-draw dependency phase
with `SetRenderPreparation(True)`. Its `PrepareRenderDependencies(epoch)` hook
runs even when hidden or beneath a cached ancestor. Providers may invalidate
output there, but must not draw, mutate tree structure or start scene traversal.

Within that hook, `PrepareSourceDependencies(source,epoch)` resolves an attached
same-scene subtree and returns whether any of its render groups requires continuous
rendering. It first prepares opted-in source providers and then their descendants.
Shared and overlapping traversals reuse successful results during that render
attempt. The scene retains scalar bookkeeping on nodes; no application-owned map
or per-frame allocation is needed. The helper rejects calls outside the current
preparation phase, foreign/detached sources and recursive source dependencies.
An exception leaves unfinished nodes available for retry. Attachment changes reset
the cache, including moves between scenes with coincident epoch numbers.

This is a provider facility. Ordinary applications use `TSceneSubtreeMaskStage`,
which handles missing sources, revision checks and consumer invalidation itself.
The helper does not capture artwork, share coverage textures or replace resource
ownership and invalidation rules.
