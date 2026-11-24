# Scene effect stages

`Max2D.SceneEffects` is an optional module importing `Max2D.Scene` and
`Max2D.Effects`. It provides **layouts, the stage provider contract, image-effect chains,
alpha masks, bloom, shadows and lighting adapters**. [Composite nodes](composites.md) provide
automatic subtree capture, stage ownership and tracked caching. Shared scene budgets include these captures and stage buffers.

Import the effects provider matching your graphics backend for shader stages.
An empty chain is a copy and works without a shader provider on backends with
render-image support. Unsupported shader stages throw during preparation.

## Local alpha masks

`TSceneAlphaMaskStage` maps frame zero of a shared image to a local rectangle.
Its RGB is ignored; alpha fades the preceding stage output. An inverted mask
cuts that coverage out instead. It uses checked layer blending without a shader
provider. Unsupported blending reports an error during preparation.

```blitzmax
Local mask:TSceneAlphaMaskStage = TSceneAlphaMaskStage.Create( ..
    maskImage, TSceneRect.Create(0, 0, 240, 160))
panel.SetStages([TSceneEffectStage(mask)])
panel.SetCacheMode(ESceneCacheMode.Automatic)
```

The rectangle is copied, while the image stays application-owned. Image handles
are ignored. Outside the rectangle alpha is zero: a normal mask removes those
pixels, an inverted mask leaves them unchanged. A zero-area mask therefore
removes everything in normal mode and nothing in inverted mode. The mask does
not expand or shrink capture bounds. Negative origins, nested composites,
affine transforms and explicit capture resolution work in the same local space
as other stages.

Stage order is explicit: put a mask **after** bloom to clip the glow, or **before**
bloom to let the masked shape glow beyond its boundary. An outer composite's
`SetClipRect` can still clip the completed result. `SetMask(image, rect, inverted)`
replaces the configuration and clears the optional input snapshot.
`SetMaskRect(rect)` moves/resizes the mask without allocating or discarding that
snapshot; `SetInverted(value)` also retains it. These setters support animated
masking without repeatedly copying CPU coverage. After editing
the shared image, call `mask.Invalidate()`; an Automatic composite reprocesses
its stages without recapturing unchanged children. Enclosing caches also refresh.

### Optional alpha-aware picking

Drawing alone does not change picking. Supply a CPU pixmap explicitly when
fresh picking and hover should test mask coverage:

```blitzmax
mask.SetInputMask(maskPixels, 128) ' Copies alpha; accepts coverage >= 128/255.
' mask.SetInputMask(Null) restores ordinary picking.
```

The snapshot is copied once, then sampled without allocations or GPU readbacks.
Any positive pixmap dimensions are accepted and mapped across the local mask
rectangle. Sampling uses the nearest texel and a threshold from 1 to 255, after
inversion. This is an input policy, not a test of the final framebuffer: texture
filtering, later glows/displacement and other child image transparency can differ.
Refresh the snapshot after changing artwork. A GPU-generated mask can use a
separately supplied CPU approximation or leave picking unrestricted.

All attached stage input restrictions intersect with the composite's rectangular
clip and ancestor restrictions. Captured pointers keep receiving movement and
release outside the mask. Provider stages can override `HitTestInputClip(x, y)`;
it receives group-local coordinates and must not mutate the scene or start another
traversal.

### Mask resources

The stage retains **two full-canvas render images**, in addition to the composite's
capture: one mapped coverage image and one result. Both participate in preparation
peak checks, scene texture budgets, caching and explicit resource release. The
shared source image and optional CPU snapshot are excluded from texture budgets.
Warm processing allocates no render images and performs no readback. Releasing
resources retains configuration and the CPU snapshot for later recreation.

[scene_alpha_masks.bmx](../../examples/scene_alpha_masks.bmx) demonstrates soft
coverage, inverted cutouts, transformed clipping and optional alpha picking.
Space pauses animation to show cache reuse; H toggles alpha picking.

## Live subtree alpha masks

`TSceneSubtreeMaskStage` captures a scene subtree's current alpha. Attach it to a
composite like other stages; standalone `Update` is not supported.

```blitzmax
' Both the consumer and the source eventually belong to the same scene.
Local maskSources:TSceneNode2D = New TSceneNode2D
maskSources.SetVisible(False)
layer.AddChild(maskSources)
Local source:TSceneNode2D = New TSceneNode2D
maskSources.AddChild(source)
source.AddChild(myMaskArtwork)
source.SetPosition(80, 60)

Local mask:TSceneSubtreeMaskStage = TSceneSubtreeMaskStage.Create(source)
consumer.SetCacheMode(ESceneCacheMode.Automatic)
consumer.SetStages([TSceneEffectStage(mask)])
' Later updates automatically refresh consumers and their cached ancestors:
source.SetPosition(120, 70)
mask.SetOffset(-10, 0)
mask.SetInverted(True)
```

The stage borrows the source; it does not reparent, destroy or hide it. Its own
local transform, tint, alpha, visibility and descendants apply. Its ancestors'
transforms, tint, visibility and layer camera do not. Source-parent coordinates
map directly to consumer-local coordinates plus `SetOffset`. A hidden parent, as
above, suppresses ordinary source presentation while allowing explicit capture.
Hiding the source itself supplies empty coverage. Mask bounds do not enlarge or
shrink the consumer's canvas; use `SetCaptureRect`/`SetClipRect` as appropriate.

A detached, destroyed or other-scene source supplies empty coverage: an ordinary
mask erases the consumer and an inverse mask retains it. Reattaching a live source
to the consumer's scene automatically refreshes coverage. Multiple stages may
borrow one source. Each stage owns two coverage/output targets; source composites
retain their own independently budgeted storage. Releasing a mask never releases
borrowed source resources. Detaching a source does not itself release that source's
resources; normal scene resource ownership rules still apply.

Before drawing, the scene resolves registered mask dependencies in dependency
order, including hidden consumers and consumers beneath cached ancestors. Source
changes invalidate the affected stage and its successors, preserving unchanged
consumer artwork and earlier stage outputs. Source composites with cache mode
`None` request updates every frame. Raw shared image/mesh/custom-drawing edits
still require `InvalidateContent` on affected source nodes. Custom draw callbacks
must not rely on running without invalidation when their consumers are cached.

`SetStages` and `SetSource` reject dependency cycles before replacing configuration.
Later structural changes can introduce a cycle; the next render then fails during
preparation, before scene drawing. Fix the tree or source reference and render
again. Membership follows scene attachment automatically. Preprocessing walks
source subtrees to resolve nested dependencies. Each node is resolved at most once
per render attempt, so shared and overlapping sources reuse completed results.
A new render walks them again; scene attachment changes discard earlier results.
Failed walks are retried, and continuously rendered sources still refresh their
consumers. This uses retained node state without per-frame traversal allocations;
it does not share captured pixels between stages or retain GPU instructions.

**Picking is unchanged.** There is no implicit GPU readback or CPU alpha snapshot
for a live source. Existing rectangular clips and pointer-capture rules still
apply. Applications needing custom input coverage can supply a separate input
policy; the captured output does not imply pixel-exact hit testing.

The [live-mask example](../../examples/scene_subtree_masks.bmx) animates one source
shared by ordinary and inverse masks inside cached ancestors. Space pauses to
show cache reuse; D detaches/reattaches the source; R releases buffers. Hovering
shows that visually erased areas retain ordinary input behaviour.

## Bounds and storage

Stages describe padding in logical units. Expansion does not move the original
content: capture must translate by the negative canvas origin, and presentation
must restore that origin. Bounds are expanded in stage order; the final common
canvas is rounded outward to whole logical units and multiplied by an explicit
integer resolution scale. Raw effect parameters remain in their existing pixel
or UV units; the chain adapter never silently rescales them.

```blitzmax
Local stage:TSceneChainStage = TSceneChainStage.Create( ..
    [TMax2DImageEffect(CreateSaturationEffect(0))], 12, 12, 12, 12)
Local bounds:TSceneRect = TSceneRect.Create(-5, 0, 100, 80)
stage.ExpandBounds(bounds, bounds)
Local layout:TSceneStageLayout = TSceneStageLayout.Create(bounds, 2)
stage.Prepare(layout)
' source must be a distinct render image matching layout dimensions and format.
Local result:TRenderImage = stage.Update(source)
```

Layouts are immutable. `CanvasRect()` returns a detached snapshot;
`CopyCanvasRect(rect)` fills reusable storage. Construction, bounds expansion and
storage estimation require no graphics context. Zero-area layouts, nonfinite
rectangles, negative padding, invalid scales and overflow are rejected.
RGBA8888, RGBA16F and RGBA32F are accepted subject to backend support.

`EstimateStorageBytes(layout)` reports the full replacement storage, not a delta:
one output for zero or one effect, or output plus scratch for multiple effects.
When budgeting a replacement, add the existing storage because the candidate is
allocated before the previous images are released. Estimates exclude driver
alignment, pipeline caches and allocation overhead. Composites enforce both per-node and shared scene budgets; standalone stages leave budgeting to callers.

## Processing and ownership

`Prepare` allocates retained storage and validates effects against the actual
output format under the blend mode used for processing. This validation belongs
in preparation: a query against the window's format could incorrectly report
support for a different offscreen format. A rejected replacement preserves the
previous storage and caller drawing state. Source-specific checks still happen
in `Update`; preparation cannot guarantee every possible source is supported.

Identical pixel layouts reuse textures. A changed logical origin or scale with
identical pixel dimensions also reuses storage; callers must recapture content
if its logical interpretation changed. Warm updates allocate no render images;
the underlying drawing operations still use state scopes.

The stage copies its effect array and retains the descriptions by reference.
After editing a description, call `Invalidate()` and compare `Revision()` in
your application to decide when to process again. Processing does not change
the configuration revision. There is no automatic pixel cache in a standalone stage; an attached composite owns that decision.
Use a new stage when changing the effect sequence or padding.

The returned image is borrowed. Do not release it, use it as the stage's source,
or retain it across a changed preparation, another update, release or context
closure. Discard it after a failed update. `ReleaseResources()` is explicit and
idempotent; it preserves configuration and clears preparation. Deselect output
before replacing or releasing it. Release resources before moving a stage to
another context, including after the old context closes. No finalizer releases
graphics resources.

## Custom providers

Extend `TSceneEffectStage` and implement:

| Method | Contract |
| --- | --- |
| `ExpandBounds(input, output)` | Finite containing bounds; allow aliased arguments; leave output unchanged on failure. |
| `EstimateStorageBytes(layout)` | Conservative full candidate texture storage; no texture allocation. |
| `Prepare(layout)` | Retained storage, actual-target support validation and caller-state restoration. |
| `Update(source)` | Distinct same-size/same-format output; source preserved; no warm texture allocations. |
| `ReleaseResources()` | Explicit, idempotent cleanup retaining configuration. |

Configuration setters validate their input, call the inherited `Invalidate()`
before committing changes, then update their private fields. This lets attached
stages reject mutation during rendering without partially changing configuration.
Keep processing state
private. A provider must report unsupported processing rather than returning an
unprocessed image. Composite attachment takes ownership of stage storage and receives invalidation
notifications. Applications own unattached stages explicitly.

## Runnable example

[scene_stages.bmx](../../examples/scene_stages.bmx) captures a scene once and
shows its original and processed output. Space changes saturation and processes
the retained source again, without recapturing the scene or allocating textures.
The example explicitly translates the scene layer camera for the padded canvas.

From the SDK root:

```sh
./bin/bmk makeapp -r -t gui mod/max2d.mod/examples/scene_stages.bmx
```

Add `-ud max2d_gl` for OpenGL; the default uses SDL GPU. The
[regression](../../tests/scene_stages.bmx) checks layout arithmetic, padding,
ownership, source preservation, state restoration, unsupported stages and warm
texture reuse on SDL Renderer, OpenGL and SDL GPU.

## Bloom in a composite

```blitzmax
Local bloom:TSceneBloomStage = TSceneBloomStage.Create(0.5, 8, 1)
Local panel:TCompositeNode = TCompositeNode.Create()
panel.SetCacheMode(ESceneCacheMode.Automatic)
panel.SetStages([TSceneEffectStage(bloom)])
layer.AddChild(panel)
' Add sprites or other scene children to panel.
' Changing intensity reprocesses the retained source without redrawing children:
bloom.SetIntensity(1.5)
```

Scene bloom preserves transparency by default. Padded pixels outside the glow
remain transparent, so the composite can be drawn over other scene content with
ordinary alpha blending. Glow RGB is added to the source; its coverage is combined
with source alpha using `glowAlpha + sourceAlpha*(1-glowAlpha)`. Intensity scales
glow coverage up to one; higher values amplify RGB only. Zero intensity preserves
source RGBA, including partially transparent pixels. This represents a composited
glow with coverage; for light added directly to a background, compose that
background into the source first.

Call `bloom.SetOpaqueBackground(True)` to flatten the full padded canvas over
black instead. Changing this mode reruns stages without recapturing children or
reallocating textures. The standalone `TMax2DBloom` retains its opaque default.

Threshold is in source colour units: values below one suit ordinary SDR colours;
floating-point sources can use values above one. Pixel format and HDR window
output remain explicit application choices.

Radius is in logical scene units and is multiplied by the composite resolution
scale. The adapter chooses enough ceil-halved reduction levels for the existing
blur kernel. Nonzero radii reserve `ceil(2*radius+2)` logical units on each edge
for blur and filtering. Three full-size images, reduction images and a final
scratch image are included in the storage estimate. A radius change can resize
the canvas and pyramid, requiring a new capture and replacement storage.

For standalone use, call `Prepare(layout)` after changing settings, then
`Update(source)`. Attached stages are prepared automatically; do not prepare or
release them manually. Preparation validates effect support against the actual
format and additive blend operation. Unsupported backends throw.

Custom providers can override `EstimatePreparationBytes(layout)` to report
additional peak texture storage above their current ownership. The default is
a full candidate allocation. Return zero only when `Prepare` reuses textures.
This lets composites enforce their budgets without charging stable parameter
updates for an allocation that never happens.

## Flat lighting stage

`TSceneLightingStage` applies ambient and coloured point/directional illumination to captured
artwork, with one reusable output image and unchanged bounds. Light edits reuse
unchanged source captures. `SetLightTexture` adds a shared projected pattern to
a point slot in composite-local units; call it again after shared pattern edits
to invalidate the output. For per-object materials and selective receivers, use
`Max2D.SceneLighting` instead. The [lighting guide](../lighting.md) explains both
paths and their coordinate, alpha and caching rules.


## Soft and inner shadows

`TSceneShadowStage` draws a coloured soft shadow behind the original capture.
`TSceneInnerShadowStage` overlays a coloured inner shadow on that capture. Both
return **source plus shadow**; the lower-level `TMax2DShadow` and
`TMax2DInnerShadow` helpers continue to return **shadow only**.

```blitzmax
Local shadow:TSceneShadowStage = TSceneShadowStage.Create(8, 6, 4)
shadow.SetShadowColor(10, 20, 35, 0.7)
group.SetStages([TSceneEffectStage(shadow)])
group.SetCacheMode(ESceneCacheMode.Automatic)

' Alternatively, shade inside the captured silhouette:
Local inner:TSceneInnerShadowStage = TSceneInnerShadowStage.Create(6, 3, 3)
inner.SetShadowColor(0, 0, 0, 0.5)
' group.SetStages([TSceneEffectStage(inner)])
```

Radius and offsets are logical scene units, multiplied by the composite's
resolution scale exactly once. Automatic reduction levels keep the blur radius
within the helper's supported range. Bounds include conservative blur padding
(`ceil(2*radius+2)` for nonzero radius) plus the offset on its affected sides.
Inner shadows also need sampling padding, although their output remains within
source coverage. Positive inner offsets expose shading along left/top edges.

Composition follows ordinary source-over drawing, including its alpha behaviour:
on translucent pixels, adding the shadow can increase coverage. It is not an
alpha-preserving material-darkening effect. Transparent unused padding stays
transparent; opacity zero preserves the source. Inner shadows operate on the
whole captured silhouette, not independently on every child or RGB boundary.
Use separate composites when objects need independent inner shadows.

`SetRadius`, `SetOffset` and `SetShadowColor` validate before changing settings
and automatically invalidate attached composites. A colour/opacity edit reuses
captured content and allocated images. Radius or offset changes can alter bounds,
requiring recapture. For animated offsets, call `shadow.SetPadding(50)` to reserve fixed symmetric
stage padding, sized for the maximum radius and offset. `ClearPadding()` restores
automatic padding. Insufficient fixed padding is rejected during bounds queries.
A fixed composite capture rectangle can additionally stabilize changing content
bounds; by itself it does not stop stages expanding their output bounds. With
both extents stable, the stage can reprocess without recapturing artwork.
Changing blur-pyramid depth still requires replacement processing storage.

Stages own their helper buffers and combined-output image. Outer shadows retain
three full-size images, inner shadows four, plus reduction levels and blur scratch.
Storage estimates participate in composite and scene budgets. Updates reuse
textures after preparation; state scopes can allocate. Release is explicit through
the owning composite or `ReleaseResources()` for standalone use. Returned images
are borrowed and expire on reconfiguration, release or context closure. Live
stages cannot migrate graphics contexts without release.

Preparation rejects missing shader/blend support on the actual target format.
The SDL renderer without an effects provider cannot run these stages.
See [scene_shadows.bmx](../../examples/scene_shadows.bmx) for an asset-free,
interactive example. `tests/scene_shadows.bmx` compares scaled output against the
standalone helpers and checks alpha, padding, state, cache invalidation, exact
storage budgets, warm texture reuse and unsupported-provider failure.
