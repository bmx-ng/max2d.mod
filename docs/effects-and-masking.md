# Effects and group masking

## Current checkpoint (2026-11-20)

The core effects architecture is implemented. This checkpoint records the public
APIs, their limits and remaining validation work.

| Area | Implemented |
| --- | --- |
| Group composition | Alpha/inverse masks, opacity, nested layers and scissor clipping |
| Direct image effects | Explicit effect draws, repeated-sprite batches and captured parameters; optional OpenGL built-in effects |
| Layer processing | Ordered chains, small blur, reduced-resolution blur, colourize and outlines |
| Retained resources | Context-owned effect buffers, cached bloom, outer and inner shadows |
| Colour and HDR | Linear artwork conversion, float composition, tone mapping and extended-linear HDR output |
| Shader authoring | Versioned packages, typed parameters, BlitzMax generation/embedding tools |
| Custom sampling | Coordinates, combined grading/distortion, displacement and bounded atlas sampling |
| Secondary maps | One extra texture, independent transforms, shared placement across sprites |
| Reveals | Weighted channel masks, inversion, glowing dissolve and soft threshold masks |

The [gallery](effects-gallery.md) provides two pages covering these effect families.
The [shader package guide](shader-packages.md) documents the current ABI contracts;
[HDR output](hdr-output.md) distinguishes float rendering, SDR presentation and
actual HDR display output.

### Deliberate limits and remaining work

- Shader packages support colour, coordinates and one secondary texture through
  ABI 1–4. Arbitrary resource layouts, additional maps and shader reflection are
  not implemented. Source/map sampling in coordinate packages uses mip level zero.
- Effects expose their passes and resource ownership. Retained buffers are
  available; a general memory-budgeted scratch pool and automatic effect graph
  are not implemented. Padding and result invalidation remain explicit.
- Custom shader packages use native SDL GPU for ABI 1–4. OpenGL supports ABI 1/2
  colour and coordinate packages with desktop GLSL assets through its optional effect provider.
  OpenGL ABI 3/4, legacy Direct3D and SDL_Renderer report packages unsupported.
  Fixed-function layer operations remain available where their exact blends work.
- Metal and Windows/Ubuntu Vulkan have regression coverage. Direct3D bytecode
  compiles, but Direct3D runtime validation remains outstanding.
- Physical HDR output has been demonstrated on macOS. The VMs test unsupported
  HDR requests and SDR fallback, not physical Windows/Linux HDR output. HDR10/PQ
  and automatic colour management are not implemented.
- Submission/resource counters and CPU benchmark captures exist. Comprehensive
  GPU timestamps, pass accounting and isolated performance captures remain work
  to do; existing CPU timings do not establish GPU speedups.

### Checkpoint regression sweep

The accumulated effects suite passed **125 checks** on 2026-11-20, using release
builds. The [per-profile test record](effects-checkpoint-results.json) lists every
selected test. This is a bounded effects/integration sweep, not the complete
repository suite.

| Platform/profile | Passed checks |
| --- | ---: |
| macOS package generation | 1 |
| macOS Metal | 28 |
| macOS software SDL | 26 |
| macOS OpenGL | 14 |
| Windows VM Vulkan | 28 |
| Ubuntu VM Vulkan | 28 |

Coverage includes package generation, colour/coordinate/two-texture shaders,
map transforms and shared mapping, threshold masks, cached helpers, buffers,
linear colour, HDR requests, blending, layer composition, integration, drawing
state and native context lifetime. Software/OpenGL passes include explicit
unsupported-shader handling; they do not imply those backends implement shaders.
This sweep predates the optional OpenGL provider described below; its validation
is recorded separately. VM HDR passes cover rejection and SDR fallback. Direct3D execution, physical VM
HDR output and GPU performance are outside this sweep.

The expanded gallery was built as a macOS GUI app and visually checked on Metal
for page navigation, colour matrices, combined grading/distortion, displacement,
dissolve, moving/shared masks, soft thresholds and returning to cached bloom.

## Choosing an API

| Task | API / guide |
| --- | --- |
| Alpha masks, cutouts and opacity | `ApplyLayerAlphaMask`, `ApplyLayerInverseAlphaMask`, `ApplyLayerOpacity` (below) |
| Single or repeated image effects | `DrawImageEffect`, `DrawImageEffectBatch` |
| Ordered effects on a layer | `ApplyLayerEffects` |
| Wide blur | `TMax2DScaledBlur` |
| Retained intermediate storage | [TMax2DEffectBuffers](effect-buffers.md) |
| Cached inner shadows | [TMax2DInnerShadow](inner-shadows.md) |
| Cached soft shadows | [TMax2DShadow](shadows.md) |
| Complete cached bloom | [TMax2DBloom](bloom.md) |
| Linear artwork and HDR/SDR presentation | [Colour handling and HDR output](hdr-output.md) |
| Custom colour, coordinate and two-texture effects | [Shader packages](shader-packages.md) |
| Texture masks, dissolve and soft thresholds | [Shader packages](shader-packages.md#soft-threshold-masks) |
| Map placement across independently transformed sprites | [Shared texture mapping](shader-packages.md#sharing-a-map-across-sprites) |
| Interactive comparisons | [Effects gallery](effects-gallery.md) |

SDL GPU shader effects require `Max2D.SDL3GPUEffects`; OpenGL built-in, colour-package and coordinate-package effects require `Max2D.GLEffects`. The descriptions and buffer owners live in
`Max2D.Effects`; package schemas and factories live in `Max2D.ShaderEffects`.
Optional effects add no work to ordinary drawing when
unused. The sections below retain the low-level APIs for custom composition.

## Layer masking

`Max2D.Effects` is optional. Import it only in applications that use layer
compositing. Layer masking provides `ApplyLayerAlphaMask(mask)`,
`ApplyLayerInverseAlphaMask(mask)` and `ApplyLayerOpacity(opacity)` on a
caller-owned `TRenderImage`. All multiply stored RGB and alpha, so a transparent layer remains in Max2D's
premultiplied format. They use one ordinary draw over the layer bounds, without
readback, new allocation or a shader package. Query `Max2DSupportsLayerAlpha()`
and `Max2DSupportsRenderImage(width, height, flags)` after opening graphics.
Unsupported capabilities are reported and the operation throws rather than
silently using a CPU fallback.

```blitzmax
Import Max2D.Effects

If Max2DSupportsRenderImage(240, 160, 0) And Max2DSupportsLayerAlpha() Then
	Local group:TRenderImage = CreateRenderImage(240, 160, 0)
	' mask is a distinct 240x160 image with alpha at every pixel.
	SetRenderImage(group)
	SetClsColor(0, 0, 0, 0)
	Cls
	DrawImage(sprite, 20, 20)
	ApplyLayerAlphaMask(mask)
	SetRenderImage(Null)
	DrawImage(group, 100, 100)
End If
```

Create and retain the group and mask images across frames. Generate or redraw
the mask only when it changes. `ApplyLayerAlphaMask` samples the mask's alpha;
its RGB is irrelevant. It requires the mask and layer to have equal dimensions
and rejects sampling the same render image being written. The helper ignores
the current camera, transforms, image handle and viewport while it composites,
then restores drawing state and the current target. The layer's pixels outside
the mask become transparent only if those mask pixels have zero alpha.
`ApplyLayerOpacity` also costs a pass; use `SetAlpha` on a single draw instead.

### Inverse masks and cutouts

`ApplyLayerInverseAlphaMask(mask)` multiplies the selected layer's stored RGB and
alpha by **1 − mask alpha**. Opaque mask pixels erase the layer, transparent pixels
leave it untouched, and partial mask alpha fades it. Mask RGB is ignored. This
cuts holes without allocating an inverted mask image or requiring shader effects.

Query `Max2DSupportsLayerInverseAlpha()` after opening graphics, alongside
render-image support. It checks the exact inverse-alpha blend independently of
normal masking. The mask must match the layer dimensions and cannot be the layer
itself. Ordinary and render-image masks are accepted. As with normal masking,
source handles and caller transforms, tint and viewport do not affect the pass;
drawing state and target views are restored. Source mask pixels are unchanged.

Each call costs one ordinary draw. A warmed call creates no texture, uploads no
pixels and performs no readback. It modifies the layer in place: repeated calls
multiply coverage again. Redraw or retain the unmasked source when toggling modes.
The layer example uses Space to switch normal/inverse masking.

`inverse_layer_masks` passes on macOS Metal/OpenGL and Windows/Ubuntu Vulkan.
It checks the alpha-product formula across eight source and mask alpha values,
ordinary and render-image masks, ignored handles/transforms/tint/viewport, source
mask preservation, feedback rejection, both native sprite paths and two context
lifetimes. Warmed operations use one submission without texture creation, upload
or readback. Software SDL passes explicit unsupported-blend rejection. Existing
normal mask/opacity tests also pass on Metal, OpenGL and software SDL. The GUI
example was visually checked in normal and inverse modes.

For nested groups, composite an inner render image into an outer one, then
apply the outer mask. This exposes target switches and memory cost to the caller.
The example [layer_effects.bmx](../examples/layer_effects.bmx) shows both a
soft group mask and nested rectangular clipping. For a hard screen-aligned
rectangle, use `ScopedMax2DState` and `IntersectViewport`; nested intersections
use the backend scissor and allocate no intermediate image. Viewport coordinates
are virtual screen coordinates and do not move with cameras or object transforms.
For a camera-moving shape, draw that shape into a coverage image under the same
camera, then mask a group layer. `MASKBLEND` only thresholds the source alpha of
individual draws; it does not clip a group.

## Native SDL GPU image effects

Import `Max2D.SDL3GPUEffects` alongside `Max2D.SDL3GPUMax2D` to register the
optional built-in image-effect shader provider. The effect description lives in
`Max2D.Effects` and can be created before opening graphics:

```blitzmax
Local saturation:TMax2DSaturationEffect = CreateSaturationEffect(0)

' After Graphics, with the desired target and blend selected:
If Max2DSupportsImageEffect(saturation) Then
	DrawImageEffect(group, saturation, 100, 100)
End If
```

Zero saturation gives grayscale, one retains colour, and values above one
increase saturation. Alpha is unchanged. The effect uses weighted luminance
on the sampled RGB components without an implicit colour-space conversion.
Tint is applied before the effect; the existing blend and premultiplied-storage
rules run afterwards. `DrawImageEffect` accepts an ordinary image or a render
image, uses its normal handle and the current camera/transform/viewport, and
rejects sampling the current render target. A completed soft-masked group is a
normal render-image input. See [image_effects.bmx](../examples/image_effects.bmx)
for a cached masked group drawn in original colour, grayscale and adjustable
saturation.

Each `DrawImageEffect` call is an explicit batch boundary and one image draw.
Separate calls are not coalesced. Use a cached group for a whole composition,
or `DrawImageEffectBatch` for repeated copies of one image. `SetAmount` changes a reusable parameter object
without allocating resources. Values are copied into the native draw record;
changing the description afterwards cannot alter queued draws. Ordinary
`DrawImage` continues using its existing shader and does not consult the effect
provider registry. No ambient effect selection is added to Push/Pop state.

### Repeated sprites

`DrawImageEffectBatch(image, effect, positions, frame)` accepts a reusable
`Float[]` containing x,y pairs in drawing order. All copies share the image frame,
effect parameters and current drawing state. The native provider captures the
parameters once, uses the existing triangle or compact sprite buffer, and splits
only when that buffer fills. It flushes before returning and leaves no effect
selected. No position-array copy or intermediate image is created.

```blitzmax
' Allocate once; update these coordinates in place when the sprites move.
Local positions:Float[] = [Float(20), Float(30), Float(60), Float(30)]
DrawImageEffectBatch(sprite, saturation, positions)
```

Empty positions are a no-op; odd lengths are rejected before drawing. The image
and effect must be non-null even for an empty batch. A provider can override
`TMax2DImageEffectBackend.DrawBatch` to accelerate this operation; its default
implementation draws each copy separately. Image handles, scale, rotation,
camera, tint, viewport and blend follow normal `DrawImage` semantics.

The extended regression passed on Metal and both Vulkan VMs: 100 warmed copies
produce one submission, 600 vertices, no texture creation, pixel upload or
readback. Capacity-plus-one copies produce two submissions in both sprite paths.
It also checks pixel output, parameter snapshots, ordinary draws surrounding the
batch, and empty/malformed inputs. The GUI example now displays 100 miniatures
and their submission count beneath the three colour treatments.

The native context caches one shader per package key and pipelines by target
format, blend mode and triangle/compact submission path. A support query warms
the exact current combination. Both sprite paths are implemented. Closing the
context releases the cache; effect descriptions can be reused with a new
context. The native recorder carries an extra effect pointer and 16-byte
parameter snapshot per batch (24 bytes on 64-bit hosts), but ordinary drawing
adds no pass, uniform upload, texture copy or per-draw allocation. Effects use
one extra 16-byte fragment-uniform upload per submitted effect batch. They allocate no
intermediate surface. The existing growable draw/vertex buffers remain shared.

The [built-in shader package](../sdl3gpueffects.mod/shaders/README.md) contains
equivalent Metal, SPIR-V and shader-model 5.1 DXBC implementations. Only the
optional module links those assets. Backends without a registered provider, including D3D9, D3D11 and SDL_Renderer,
report this shader effect unsupported. OpenGL now supplies saturation and colourize
through the optional `Max2D.GLEffects` provider described below. The public API does not silently fall back to a CPU conversion.
The saturation provider described here uses a fixed built-in shader. Custom
colour, coordinate and two-texture shaders use the versioned package API below.

## Basic OpenGL image effects

Import `Max2D.GLEffects` alongside `Max2D.GLMax2D` to enable saturation, colourize, outlines,
layer blur, bright-pass extraction, tone mapping and linear output through the existing effect API:

```blitzmax
Framework Max2D.GLMax2D
Import Max2D.GLEffects

Graphics(800,600)
Local grey:TMax2DSaturationEffect=CreateSaturationEffect(0)
Local silhouette:TMax2DColorizeEffect=CreateColorizeEffect(80,160,240)
' DrawImageEffect(image,grey,x,y)
' DrawImageEffectBatch(image,silhouette,positions)
```

The implementation remains within Max2D. It uses the existing OpenGL 2.1 / GLSL
1.20 backend and leaves BRL.GLGraphics and Pub.GLEW unchanged. Effect source is
kept as readable multiline strings in the optional BlitzMax module. Without its
import, these descriptions continue to report unsupported on OpenGL.

Saturation operates on straight sampled RGB after drawing tint; colourize replaces
RGB with its chosen colour before tint. Both preserve sampled alpha and apply
drawing alpha once. Ordinary images, coverage textures, atlas views and
premultiplied render images use their normal orientation and interpretation.
Floating-point targets retain HDR and negative values when the backend supports
them. Sampling inherits the normal GL filter and mip selection; these are colour
effects, not the bounded coordinate/map sampling contracts of the package API.

Shader programs are compiled lazily and cached by graphics context. A support
query warms the cache without changing the selected effect. Each effect draw
flushes the preceding batch, submits its captured parameters and clears the
selection, including on failure. Repeated copies share a submission up to the
existing vertex-buffer capacity. Warmed effects add no intermediate texture,
texture upload or readback. Ordinary draws use their original shader; no optional
effect shader is compiled unless requested. Closing a context releases its cache,
and reusable descriptions can be used in a new context.

Blur uses the same nine-tap binomial kernel as SDL GPU, with radius 0–4 and
horizontal/vertical passes. It requires a premultiplied render-image source,
accumulates premultiplied colour and alpha, and treats taps outside the image as
transparent. A small coordinate tolerance keeps exact boundary taps inside despite
interpolator rounding. Floating-point layers retain HDR and negative RGB values.
Blur always samples mip level zero; the previous texture mip range is restored
before returning, so subsequent ordinary draws resume normal mip selection.

Outlines use a circular alpha stencil with integer radius 0–4, returning the
maximum neighbouring alpha minus the centre alpha. Source RGB is ignored; drawing
tint colours the result. They require a render image, sample mip zero with
transparent outside taps, and restore the mip range just as blur does.

Bright-pass extraction preserves sampled RGB and scales alpha by the fraction of
luminance above its threshold. Tone mapping applies exposure, nonnegative
per-channel Reinhard mapping and a configurable gamma. Linear output provides
either nonnegative linear gain or Reinhard mapping with the piecewise sRGB curve.
All three share the ordinary source interpretation, tint, alpha, filter and mip
rules of the colour effects.

Layer chains can combine these built-in effects. Retained effect buffers,
scaled blur, `TMax2DBloom`, `TMax2DShadow` and `TMax2DInnerShadow` use the same
public APIs on OpenGL and SDL GPU.
The blur, colourize, outline, layer-chain, scaled-blur, bloom and HDR-bloom examples
accept `-ud max2d_gl`. The HDR example renders into float layers and tone maps to
an SDR window. Linear HDR values in a float texture do not enable HDR window
presentation; that remains a separate SDL GPU capability.
Chains containing unsupported effects reject during preflight before writing.
ABI 1 colour and ABI 2 coordinate packages also work through this provider;
secondary maps remain future OpenGL work. The gallery offers its layer/cached-effects page on OpenGL; its shader-package
page requires SDL GPU;
[the OpenGL comparison](../examples/gl_effects.bmx) shows the supported subset.
Left/Right adjusts saturation and Space changes the silhouette colour.

### OpenGL provider validation (2026-11-20)

Twelve release regressions pass on each of macOS, Windows and Ubuntu OpenGL:
`gl_effects`, `gl_effects_optional`, `image_effects`, `colorize_effects`,
`custom_blending`, `layer_effects`, `float_targets`, `coverage_atlas`,
`integration`, `gl_targets`, `gl_mipmaps` and `drawing_state`. The saturation and
colourize regressions also pass on macOS SDL GPU and software SDL (explicit
rejection), for 40 selected checks across the profiles, excluding reruns.

Checks cover two graphics lifetimes, parameter changes, 100-sprite batching and
capacity overflow, failure cleanup, feedback rejection, custom blends, ordinary
draws surrounding effects, transformed atlas views, render-image orientation,
coverage textures and alpha-test thresholds. HDR/negative-value checks ran on
all three OpenGL platforms without skipping float targets. This initial sweep
predated blur support; at that point mixed chains rejected blur before writes.
The existing target/mipmap/integration checks exercise the shared ordinary path.
These are correctness and submission-count checks, not GPU timing measurements.

The macOS GUI demo was visually checked with saturation and silhouette-colour
changes; its 100-sprite batch reports one submission. Shader programs use GLSL
1.20, but this does not establish coverage of every OpenGL 2.1 driver.

### OpenGL blur validation (2026-11-20)

Nine selected regressions pass on each of macOS, Windows and Ubuntu OpenGL: `gl_effects`,
`gl_effects_optional`, `image_effects`, `colorize_effects`, `blur_effects`,
`scaled_blur`, `layer_effect_chain`, `effect_buffers` and `gl_mipmaps`.
The five shared blur/chain/buffer regressions also pass on macOS SDL GPU and
software SDL (including explicit unsupported-effect paths): 37 selected checks
across the profiles, excluding reruns. Float checks ran on all three OpenGL
platforms without skipping.

The checks cover fractional and zero radii, transparent boundary taps,
premultiplied colour, two-pass output, colourize/blur chains, retained resources,
caller-state restoration and two graphics lifetimes. Scaled blur is compared
against an independent CPU reference at full, half and quarter resolution,
including odd dimensions and taps exactly on the texture boundary.

The OpenGL-specific test also verifies minified blur reads mip zero, restores the
texture mip range and lets the next ordinary draw use mipmaps. Floating-point
blur is compared with premultiplied kernel calculations for HDR and negative RGB.
These checks establish pixel correctness and retained-resource costs, not speed.

All four updated examples build as macOS OpenGL GUI apps. The scaled-blur demo
was visually checked in both equal-radius and wider-radius modes.

### OpenGL bloom and output validation (2026-11-20)

Nine release regressions pass on macOS, Windows and Ubuntu OpenGL:
`bloom_pipeline`, `linear_colour`, `gl_effects`, `gl_effects_optional`,
`effect_buffers`, `outline_effects`, `bloom_effects`, `hdr_bloom` and `scaled_blur`.
The four bloom/linear-output regressions also pass on macOS SDL GPU and software
SDL (explicit unsupported paths), for 35 selected checks excluding reruns.
Floating-point tests ran on all three OpenGL platforms without skipping.

Bright-pass tests compare threshold extraction with CPU luminance calculations,
including tint, opacity, straight/premultiplied sources, batching and ordinary
draws after effects. HDR tests use both RGBA16F and RGBA32F layers, exposures
0/0.5/1/4, gamma 1/2.2, negative RGB and values up to 1000. They check retained
highlight extraction, scaled blur, additive composition and mapped display
against reference values. The warmed full HDR path uses nine submissions with
no texture creation, upload or readback.

Linear-output tests compare the sRGB curve and linear gain against a 256-step
CPU reference, check alpha and unpremultiplication, and verify filtering occurs
in linear light before output conversion. Reusable bloom tests cover retained
buffers, glow intensity, cached-result validity and state restoration. The
optional-import check covers all seven built-in descriptions. The window-state
regression sets an explicit 64×64 virtual scene because Windows can enlarge the
requested client width to its minimum size (130 pixels on the tested VM).

Both bloom examples build as OpenGL GUI apps. The HDR-bloom comparison was
visually checked on macOS, including threshold, exposure and bloom toggling.
The window presents tone-mapped SDR; the float-layer checks establish HDR
rendering correctness, not HDR display output or GPU performance.

### OpenGL cached shadows and gallery validation (2026-11-20)

`shadow_pipeline`, `inner_shadow`, `bloom_pipeline`, `inverse_layer_masks` and
`effect_buffers` pass on macOS, Windows and Ubuntu OpenGL. The two shadow tests
also pass on macOS SDL GPU and software SDL (explicit unsupported paths), for
19 selected checks excluding reruns. They require the OpenGL capabilities and
run float reference checks rather than silently accepting unsupported effects.

Soft-shadow alpha is compared with an independent blur kernel. Inner-shadow
alpha is compared with a shifted kernel including fractional offsets, partial
coverage and a hole. Tests cover source preservation, state restoration,
invalid-parameter cache preservation, layout invalidation and two context
lifetimes. Warmed soft-shadow updates use three draws at full resolution or six
with two reduction levels; inner shadows use five or eight. These updates create
no textures, upload no pixels and perform no readbacks. Cached-result retrieval
performs no rendering. Window sampling uses an explicit logical resolution.

The gallery and both focused shadow examples build as OpenGL GUI apps. The
SDL GPU gallery also builds with its two pages. The OpenGL gallery was visually
checked on macOS for soft shadows, independent/group inner shadows, radius
changes and bloom. Its keys select only the nine supported layer views; Tab does
not enter shader-package views. All work uses the existing shadow helpers and
OpenGL effects without additional backend changes.

## Two-pass layer blur

`CreateBlurEffect(radius, horizontal)` describes one axis of a blur. Radius is
finite and between zero and four source pixels; `SetRadius` and `SetHorizontal`
update the reusable description. The native SDL GPU provider requires a
`TRenderImage` source, whose stored colour is premultiplied. For an ordinary
image, first draw it into a transparent render image. This avoids colour fringes
when fractional sample positions interpolate pixels with different alpha.

Use two effect descriptions and two caller-owned output images:

```blitzmax
Local horizontal:TMax2DBlurEffect = CreateBlurEffect(4, True)
Local vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)
' source, scratch and result are distinct, same-sized render images.
' Use default image handles and identity drawing transforms for these passes.
Local scope:TMax2DStateScope = ScopedMax2DState()
Try
	SetColor(255, 255, 255)
	SetAlpha(1)
	SetBlend(SOLIDBLEND)
	SetRenderImage(scratch)
	DrawImageEffect(source, horizontal, 0, 0)
	SetRenderImage(result)
	DrawImageEffect(scratch, vertical, 0, 0)
Finally
	scope.Close()
End Try
```

Check support with the desired output and blend selected before use. A pass
uses the normal image handle, transforms, viewport, tint and blend. `SOLIDBLEND`
replaces the whole output, so transparent source pixels erase previous contents;
alpha blending into an uncleared output would accumulate old frames. The caller
owns any state scope around the pair of passes. There is no transactional rollback
of output pixels if the second pass fails.

Create the render images with `FILTEREDIMAGE` for smooth fractional radii.
The kernel weights are `[1,8,28,56,70,56,28,8,1] / 256`, sampled along the selected
axis with spacing `radius / 4`. This is a small binomial blur, not a general
large-radius Gaussian filter. Radius four uses one-pixel spacing; radius zero
is an identity operation but still costs a draw. Sampling uses the base mip level
so radius is measured in source pixels. Out-of-image taps are transparent. Keep
at least `Ceil(radius)` transparent pixels around group content, or the output
image will crop its halo. Linear filtering at the image boundary uses the normal
sampler, so transparent padding is also needed to avoid clamped edge colours.

The shader averages premultiplied colour and alpha together, converts back to
straight colour for tint and custom blending, and applies the backend's ordinary
output convention. It is suitable for a completed soft-masked group. Blur after
masking spreads the mask's edge; mask after blur clips the softened result.

A two-dimensional blur needs two image draws, nine texture samples per fragment
per pass, and two retained output images. Their logical RGBA8 storage totals
`width * height * 8` bytes, in addition to the source. No scratch allocation,
pixel upload or readback is performed by a warmed draw. Cache the result and
rebuild only when source pixels or radius change, as shown in the
[interactive blur example](../examples/blur_effects.bmx). Wider blur is available through the retained reduction levels described below.
For explicit ownership of reusable scratch images, use `TMax2DEffectBuffers`.
Automatic scratch pooling remains future work.

## Chaining whole-layer effects

`ApplyLayerEffects(source, destination, effects, scratch)` processes a complete
layer with an ordered, reusable `TMax2DImageEffect[]`. It alternates destination
and scratch so the last pass always finishes in destination. The source is left
unchanged. All images must have equal dimensions; source and destination must
be distinct, and chains of two or more effects require a third, distinct scratch
image. A single effect needs no scratch. An empty chain copies the source with
one ordinary image draw.

```blitzmax
' Create these descriptions and the array once.
Local horizontal:TMax2DBlurEffect = CreateBlurEffect(4)
Local vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)
Local grayscale:TMax2DSaturationEffect = CreateSaturationEffect(0)
Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(horizontal), ..
	TMax2DImageEffect(vertical), TMax2DImageEffect(grayscale)]

' Reuse source, result and scratch; rerun only when content/parameters change.
ApplyLayerEffects(source, result, chain, scratch)
DrawImage(result, x, y)
```

Each pass replaces the full layer using white tint, unit alpha, identity
coordinates and `SOLIDBLEND`. Image handles are compensated without modifying
the images. Camera, transform, origin, viewport, target and other caller state
are restored. The destination and scratch retain their own original virtual
resolution and clipping viewport, including when support validation throws.
The caller does not need to add a state scope around this helper.

Dimensions and aliasing are checked first. The helper then checks every effect
against its actual output target before drawing the chain; an unsupported later
effect does not leave an earlier effect's pixels in either output. These checks
may create native textures, shaders or pipelines on first use. A runtime failure
after drawing starts restores state but does not roll back already written pixels.

A warmed nonempty chain submits one draw per effect and creates no textures,
pixel uploads or readbacks. There is no final copy pass, no implicit scratch
allocation and no per-pass array allocation. The helper creates up to three CPU
state-scope snapshots per invocation, independent of chain length. It performs
capability checks and target switches; direct draws remain available when callers
manage those themselves. Cache outputs when possible. Scratch contents are
intermediate work, not an additional stable result to retain across chain changes.
The [chain example](../examples/layer_effect_chain.bmx) shows the two-blur-pass
intermediate for its fixed three-step chain and lets you toggle grayscale.

## Architecture for general shader effects

The public [shader package API](shader-packages.md) implements colour (ABI 1),
coordinates (ABI 2), a secondary texture (ABI 3), and independent map transforms
(ABI 4). ABI 1–3 packages remain compatible. Built-ins and custom packages use
the same registration path. BlitzMax tools validate manifests, generate shader
wrappers and embed the Metal, SPIR-V and DXBC assets. This is schema/container
validation, not general shader reflection.

Two execution models remain explicit:

- **Direct draw effects** change source sampling or colour without reading the
  destination. The submitted draw captures effect parameters and texture bindings;
  later setter calls cannot change queued draws. `DrawImageEffectBatch` shares a
  captured configuration across repeated copies. Ordinary drawing does not select
  an effect or allocate effect intermediates.
- **Layer effects** read a previously rendered group. Chains and cached helpers
  expose their passes and retained outputs. `TMax2DEffectBuffers` owns configurable
  render images and blur levels; it is not a global pool. Sampling the active
  destination is rejected, and callers provide adequate padding for halos.

Package descriptions own immutable shader assets and typed parameter layouts.
Reusable effect instances hold values and optional map images. Native shaders
and pipelines belong to the current graphics context; descriptions may outlive
it and are checked again when used in another context. Buffer owners similarly
validate context ownership and must be prepared for the new context.

The wrapper interprets ordinary, premultiplied render-image and coverage inputs,
applies drawing tint and preserves the output alpha convention. Coordinate and
map sampling stays within the selected image/view bounds with explicit
transparent, clamp or repeat edge modes. RGB remains unclamped for floating-point
HDR targets. There is no implicit colour-space conversion.

`SetTextureTransform` controls map placement relative to each source image.
`SetTextureMapping` converts a captured virtual-space placement into source-local
coordinates so independently transformed sprites can share one map. The latter
captures the source transform per call; distinct placements require separate
effect draws. Neither helper adds a render target or redraws the map.

Arbitrary texture layouts and normal/light-map data contracts would be future
extensions. OpenGL two-texture packages and separate legacy Direct3D
implementations are also future work; SDL_Renderer has no general custom shader hook.

## Cost and validation boundaries

The default draw path needs zero effect lookups, passes, copies or allocations
when no effect is selected. A rectangular clip changes scissor state and can
split a batch; this is cheaper than a layer. Each alpha-mask or opacity call
adds one target draw and can cause a target switch. Reuse caller-owned layers
and masks; future scratch pooling should key by width, height, format, flags
and context, with a bounded memory budget. Avoid GPU readbacks and CPU/GPU
fences in normal effect use. Readback is appropriate only in tests or capture.

The current `layer_effects` regression establishes a small no-effect baseline:
100 same-state rectangles submit as one batch. The alpha mask and opacity
operations each submit one additional batch and perform no readback on macOS
SDL GPU, OpenGL and the default SDL renderer. The warmed opacity operation
creates no texture and uploads no pixels. These counters do not measure render
passes, target switches or GPU time. For broader performance work, compare
representative scenes with no effect, a rectangular clip and a masked layer
using the existing `benchmarks/renderer.bmx` and GPU comparison harness.
Native GPU profiling should additionally record render passes, uniform uploads,
temporary bytes and CPU/GPU frame time at several group sizes. The regression
also checks compositing pixels and state restoration where the backend supports
the exact operation.

## Initial shader validation (2026-11-17)

`image_effects` passed on macOS Metal and on Windows 11 and Ubuntu 25.10 ARM64
under Parallels, both using Vulkan. It checks pixel output for ordinary and
premultiplied inputs, identity/grayscale, parameter snapshots, custom blending,
triangle and compact paths, context recreation, feedback rejection and recovery
from an invalid frame. The warmed draw uses one submission and no texture
creation, pixel upload or readback. The unsupported-provider path passed with
SDL software and macOS OpenGL. The existing Metal `custom_blending`,
`layer_effects` and `sdl_gpu_lifetime` regressions also passed.

The DXBC asset was compiled with D3DCompile on Windows, but Direct3D 12 could not
create graphics in this VM. Direct3D runtime validation remains outstanding;
the Windows Vulkan pass does not validate DXBC. The macOS GUI example was also
opened and inspected: original, grayscale and saturated soft-masked groups
rendered correctly, and keyboard parameter changes updated the image.

The [initial benchmark capture](effects-macos-smoke.csv) is a single Metal smoke
run with both VMs running, 30 warm-up and 120 measured frames per case. At both
128 and 512 pixels, cached ordinary and shader draws each submitted one batch;
rebuilding, masking and drawing submitted three. All measured cases had zero
texture creations, pixel uploads and readbacks. Retained logical layer/mask
storage was 128 KiB and 2 MiB respectively. CPU whole-frame means were roughly
19.5–20 ms with p95 around 41 ms, showing presentation pacing despite `Flip(0)`.
These timings do not establish shader speed or GPU cost; use repeated captures
and GPU profiling for that comparison.

## Blur validation (2026-11-17)

`blur_effects` passed on macOS Metal and Windows/Ubuntu Vulkan under Parallels,
with both triangle and compact sprite paths and two context lifetimes. Pixel
checks cover the exact kernel, both axes, zero radius, fractional spacing and
preserved red colour around transparent pixels. Straight-image inputs and invalid
radii are rejected. Software SDL and OpenGL report the shader unsupported. The
existing saturation/batching regression still passes on Metal. DXBC compilation
passed without warnings; Direct3D runtime validation remains outstanding.

The macOS GUI example was opened and visually checked, including live radius
changes. The [blur benchmark capture](blur-macos-smoke.csv) records a single
30-warm-up/120-measured-frame smoke run per case. Rebuilding both blur passes and
drawing the output takes three submissions; drawing the cached result takes one.
Both have zero measured texture creations, pixel uploads or readbacks. The blur
cases retain four images, totaling 256 KiB at 128 square and 4 MiB at 512 square.
Two of those images are the blur outputs; the other two are the source layer and
its retained mask. CPU timings include compositor/presentation effects and do not
establish GPU execution time or a speedup.

## Chain validation (2026-11-17)

The chain regression checks empty copies and chains of one, two and three effects,
including odd/even pass ordering, pixel output and one warmed submission per
effect with no texture creation, upload or readback. It checks non-default image
handles, transformed/camera drawing state, separate viewports on all three images,
source preservation, alias rejection and support failure before output writes.
Both native sprite paths pass on Metal and Windows/Ubuntu Vulkan. Software SDL
and OpenGL pass the empty-copy and unsupported-effect paths where render images
are supported. The macOS GUI example was launched and visually inspected.

## Colourized silhouettes

`CreateColorizeEffect(red, green, blue)` returns a reusable
`TMax2DColorizeEffect`. `SetColor` validates all components (0–255) before changing
any of them; `GetColor` returns the selected RGB. It replaces sampled RGB and
preserves alpha for ordinary images and render images. Drawing tint multiplies
the replacement RGB, and drawing alpha multiplies source alpha. The default is
white. The optional native SDL GPU provider supplies Metal, SPIR-V and DXBC.

For a shadow or glow, chain colourize, horizontal blur and vertical blur using
`ApplyLayerEffects`. Keep transparent padding around source content. Draw a black
blurred result offset behind the original for a soft shadow; draw a coloured
result with `LIGHTBLEND` behind it for a glow. This is a small silhouette blur,
not a brightness-extraction or HDR bloom filter. The
[example](../examples/colorize_effects.bmx) caches separate shadow and glow results
and rebuilds them only when settings change. Each rebuild uses three submissions
and the caller's retained scratch image; displaying a cached result is an
ordinary image draw. No changes were needed in the base renderer.

At very low alpha, 8-bit premultiplied storage can visibly quantize recovered RGB,
particularly after several passes. This is a storage precision limit.

### Colourize validation (2026-11-17)

The colourize regression passed on macOS Metal and Windows/Ubuntu Vulkan in
Parallels, with two context lifetimes and both native sprite paths. Checks cover
ordinary and premultiplied inputs, alpha preservation, independence from source
RGB, drawing tint/alpha, parameter changes, batching, custom blend inputs,
ordinary draws after effects, and the three-pass colourize/blur chain. Software
SDL and OpenGL report unsupported effects as expected. Existing image-effect
and chain regressions also passed on macOS native, software and OpenGL profiles.
DXBC compiled successfully; Direct3D runtime validation remains outstanding.
The macOS GUI example was opened and inspected, including colour and radius
changes through its live controls.

## Wider blur with retained reduction levels

`CreateScaledBlur(radius)` returns a reusable `TMax2DScaledBlur` description.
`SetRadius` and `GetRadius` use full-resolution source pixels. Call
`blur.Apply(source, destination, levels, scratch)` to reduce, blur and enlarge.

The caller creates and retains every image:

- Source and destination have equal dimensions and are distinct.
- `levels` runs from largest to smallest. Each level halves both preceding
  dimensions, rounded up: for example 129×97 → 65×49 → 33×25.
- Scratch matches the smallest level. An empty levels array uses source size.
- All images are distinct. Source, levels and scratch use `FILTEREDIMAGE`
  without `MIPMAPPEDIMAGE`; the final destination can use either sampling mode.

The radius must fit the existing four-pixel kernel at the smallest level:
`radius × smallestWidth / sourceWidth <= 4`, and likewise for height. For even,
square images, zero, one and two levels permit radii up to 4, 8 and 16. Odd or
narrow dimensions may reduce that limit. Invalid dimensions, aliases, sampling
flags and oversized radii are rejected before drawing. Shader support is checked
before output pixels are written. Runtime errors after drawing starts cannot
roll back output pixels.

Successive bilinear reductions avoid skipping large spans of source pixels in a
single resize. At exact halves each output averages a 2×2 source footprint.
Odd sizes use approximate bilinear resampling, not exact area integration.
All filtering operates on premultiplied render-image storage to avoid coloured
fringes from transparent pixels. Keep transparent padding around source content;
edge sampling during resizing clamps to the image boundary.

The radius describes the blur kernel before the additional smoothing from
reduction and enlargement. Reduced output is approximate and loses fine detail;
even radius zero still filters when levels exist. Zero radius with no levels is
an identity operation. The [comparison example](../examples/scaled_blur.bmx)
toggles between equal radii (quality comparison) and wider radii at lower
resolutions. Results are rebuilt only when the setting changes.

| Reduction levels | Rebuild draws | Smallest size for 256² source | Maximum radius |
| --- | ---: | ---: | ---: |
| None | 2 | 256² | 4 |
| One | 4 | 128² | 8 |
| Two | 5 | 64² | 16 |

The helper restores caller state and every target's viewport and virtual
resolution. It allocates state scopes, but no images, arrays or effect objects.
Cached output costs one ordinary image draw. The wider path adds reduction and
enlargement passes while doing its two nine-tap blur passes on fewer pixels;
this tradeoff does not guarantee faster frames for small images.

### Scaled-blur validation (2026-11-17)

The independent CPU reference checks all output alpha pixels for even and odd
rectangular images, at zero, one and two reduction levels. A fine checkerboard
exercises reduction filtering; transparent coloured pixels exercise premultiplied
colour preservation. Tests cover both native sprite paths, two context lifetimes,
non-default handles, saved caller/output views, source preservation, zero-radius
identity, invalid radius and scratch alias rejection. They pass on macOS Metal
and Windows/Ubuntu Vulkan. Software SDL and OpenGL pass explicit unsupported
shader handling and state restoration. The macOS GUI comparison was opened and
both equal-radius and wider-radius modes were visually checked.

The benchmark smoke captures use 20 warm-up and 60 measured frames per case:
[macOS](scaled-blur-macos-smoke.csv), [Ubuntu](scaled-blur-linux-smoke.csv),
and [Windows](scaled-blur-windows-smoke.csv). Full, half and quarter-resolution
rebuilds plus display cost 3, 5 and 6 submissions respectively; cached display
costs one. All measured cases have zero texture creation, upload and readback.
At 256², retained RGBA8 image storage per case is 768, 640 and 608 KiB respectively;
at 512² it is 3, 2.5 and 2.375 MiB. Captures measure CPU frame time and include
presentation pacing and VM overhead. They do not establish GPU execution cost
or a reliable speedup, and the three rebuild cases use different blur radii.

## Alpha outlines

`CreateOutlineEffect(radius)` returns a reusable `TMax2DOutlineEffect` for the
optional native SDL GPU or OpenGL provider. Radius is an integer from zero to four source
pixels; `SetRadius` validates changes and `GetRadius` returns the current value.
It works with `DrawImageEffect`, `DrawImageEffectBatch` and `ApplyLayerEffects`.
Sources must be render images; ordinary images and atlas entries should first
be drawn into a padded render layer.

The effect ignores source RGB. Within a circular pixel stencil it finds the
maximum alpha, subtracts the centre alpha and clamps the difference to zero.
The output is a white mask, coloured by drawing tint and scaled by drawing
alpha. Opaque interiors vanish, while transparent pixels next to content form
the border. Soft alpha transitions produce a difference mask, including around
holes; compositing this mask behind partially transparent content is not the
same as replacing that content with a fully dilated silhouette. Radius zero
produces a transparent mask.

Padding is explicit: leave at least `radius` transparent source pixels around
the content. The draw geometry stays inside the original image rectangle, so
an unpadded edge clips the outline. Samples outside the image are transparent;
mip level zero and the source's sampling filter are used. Output alpha obeys
the ordinary mask threshold and blend rules. The discrete circular stencil can
show pixel steps at large display scales; it is not a distance-field stroke.

A draw uses one submission with no intermediate image. Radius four selects 49
alpha samples inside a fixed 9×9 loop, so it is more expensive per output pixel
than the nine-tap blur. Batch repeated copies to share a submission. For cached
coloured outlines, chain outline and colourize into caller-owned images, then
draw the cached border behind the original. The
[interactive example](../examples/outline_effects.bmx) shows the original,
white outline mask, and coloured composite; arrow keys adjust radius and Space
changes colour. It rebuilds the two-pass chain only when settings change.

### OpenGL outline validation (2026-11-20)

Six selected release regressions pass on each of macOS, Windows and Ubuntu
OpenGL: `gl_effects`, `gl_effects_optional`, `outline_effects`, `blur_effects`,
`colorize_effects` and `layer_effect_chain`. The shared outline test also passes
on macOS SDL GPU and software SDL (explicit rejection), for 20 selected checks
across the profiles, excluding reruns.

The OpenGL provider runs the same independent CPU disk-stencil comparisons as
SDL GPU, for every pixel at radii 0–4. Cases include holes, edge content, partial
alpha, source-colour independence, parameter changes, batched copies, drawing
alpha/tint, custom blending, colourize chains and two graphics lifetimes.
Ordinary images and feedback are rejected. Warmed two-copy batches use one
submission with no texture creation, upload or readback.

The OpenGL-specific regression also checks mip-range restoration and ordinary
mipmapped drawing after an outline. The optional-import regression confirms
outlines remain unavailable without `Max2D.GLEffects`.

The example builds with `-ud max2d_gl -t gui`. Its original, white mask and
coloured composite were visually checked on macOS, including radius and colour
changes. This is correctness coverage, not a GPU performance measurement or
coverage of every legacy OpenGL driver.

### Outline validation (2026-11-17)

The outline regression compares every alpha pixel with an independent CPU disk
stencil for all five radii. It includes partial alpha, holes, image-edge content,
and varied source RGB. It checks captured parameter changes, two-copy batching,
custom blending, drawing tint/alpha, ordinary draws after effects, colourize
chains, image handles, feedback rejection and render-image-only input. Both
native sprite paths and two context lifetimes pass on macOS Metal and
Windows/Ubuntu Vulkan under Parallels. The warmed batch takes one submission
with zero texture creations, uploads and readbacks. Software SDL and OpenGL
report the effect unsupported; existing colourize and chain regressions also
pass on those macOS profiles and Metal. The GUI example was visually inspected,
including live radius and colour changes. DXBC compiles without warnings;
Direct3D runtime validation remains outstanding.

## Brightness extraction and bloom

`CreateBrightPassEffect(threshold)` returns a reusable `TMax2DBrightPassEffect`.
Its default threshold is 0.6; `SetThreshold` accepts finite nonnegative values
and `GetThreshold` returns the current value. It supports ordinary images,
render images, effect batches and layer chains through the optional native SDL
GPU provider.

After sampling and drawing tint, the effect computes straight-RGB luminance
using weights 0.2126, 0.7152 and 0.0722. It keeps RGB and multiplies alpha by
`max(luminance - threshold, 0) / luminance`; zero luminance gets zero alpha.
Drawing alpha also multiplies the result. Thus pixels at or below the threshold
contribute no light, and brighter pixels contribute only their excess brightness
while retaining their colour ratios. Zero threshold retains positive-luminance
pixels; opaque black becomes transparent. A threshold of one removes normalized
RGB highlights up to white. There is no implicit colour-space conversion.

Bloom is an explicit composition of the existing operations:

1. Extract highlights into a retained full-size render image using
   `ApplyLayerEffects` with a one-entry bright-pass chain.
2. Use `TMax2DScaledBlur.Apply` with retained reduction levels, scratch and glow
   images. Keep transparent padding around content to retain the halo.
3. Draw the original with `ALPHABLEND`, then the glow with `LIGHTBLEND`.
   Drawing alpha can reduce glow strength during composition without rebuilding.

The [bloom example](../examples/bloom_effects.bmx) shows the original, extracted
highlights and additive result. Left/right adjust threshold, up/down adjust blur
radius, and Space toggles the glow without rebuilding it. It caches extraction
and blur until settings change. With two reduction levels, a rebuild uses one
extraction draw plus five scaled-blur draws; cached composition uses two ordinary
image draws. Retained images are source, extracted highlights, glow, two
reduction levels and low-resolution scratch. No hidden scratch allocation or
readback is introduced.

This example uses 8-bit normalized storage and clips additive channels at white.
It is a bloom composition without tone mapping or exposure adaptation. Reduced
blur loses fine detail, and low-alpha RGBA8 storage quantizes recovered colours;
these limitations also apply to the extracted and blurred highlight layers.

### Bloom validation (2026-11-17)

Extraction pixels match an independent luminance/energy reference for black,
gray levels, primary colours, opaque and half-transparent inputs, thresholds
0–2, and ordinary and premultiplied images. Checks cover parameter capture,
batching, drawing tint/alpha, custom blending and ordinary draws after the effect.
The complete extraction/reduction/blur path produces a halo beyond the source;
every additive-composite pixel matches the expected original-plus-glow energy.
The warmed two-level rebuild uses six submissions with zero texture creation,
upload or readback. Both native sprite paths and two context lifetimes pass on
macOS Metal and Windows/Ubuntu Vulkan. Software SDL and OpenGL report the shader
unsupported; existing image-effect and scaled-blur regressions pass on all three
macOS profiles. The GUI example was inspected with threshold/radius changes and
bloom toggled off/on. DXBC compiles without warnings; Direct3D runtime validation
remains outstanding. These pixel and submission checks are not GPU timing data.

## HDR bloom and tone mapping

`CreateToneMapEffect(exposure, gamma)` returns a reusable `TMax2DToneMapEffect`.
Exposure defaults to one and accepts finite nonnegative multipliers. Gamma also
defaults to one and accepts values from 0.1 to 10. The matching setters/getters
update or inspect the description without allocating graphics resources.

After normal sampling, source unpremultiplication and drawing tint, each channel
is clamped to nonnegative values and mapped with the per-channel Reinhard curve
`1 - 1/(1 + channel*exposure)`. The result is raised to `1/gamma`. Alpha is
preserved, apart from normal drawing alpha. Zero exposure produces black while
retaining alpha. Gamma one leaves mapped values linear; the example's gamma 2.2
is a simple display power curve. No automatic transfer-function conversion,
colour management, exposure adaptation or scene-wide brightness measurement is
performed. Mapping channels independently can change colour ratios in highlights.

Keep the source, extracted highlights, reduction levels, blur scratch, glow and
composite in the same supported floating-point format, such as `PF_RGBA16F`.
Check both float texture and render-image support. Bright-pass thresholds above
one then select HDR highlights without first clipping them to white. The blur
and effect-chain helpers accept these float render images without an intermediate
RGBA8 copy. Combine source and glow in the HDR composite, then tone-map once at
the final display draw:

```blitzmax
Local tone:TMax2DToneMapEffect = CreateToneMapEffect(1, 2.2)
' hdrComposite contains the scene plus glow in floating-point storage.
SetRenderImage(Null)
SetBlend(ALPHABLEND)
DrawImageEffect(hdrComposite, tone, 0, 0)
```

The composite needs valid alpha everywhere its light will be displayed.
`LIGHTBLEND` adds colour while preserving destination alpha. Clear the HDR
composite to an opaque background, draw the scene with `ALPHABLEND`, then add
its glow. Adding light into zero-alpha pixels and subsequently treating that
image as premultiplied content loses the halo when it is converted back to
straight RGB. The example starts with an opaque HDR scene and copies it before
adding the glow.

The [HDR comparison](../examples/hdr_bloom.bmx) uploads synthetic linear float
content once, keeps its work in RGBA16F, and compares clipped input, tone-mapped
input and tone-mapped HDR bloom. Left/right change the extraction threshold,
up/down change exposure and Space toggles the bloom. Exposure and toggle changes
reuse the cached HDR images; only threshold changes rebuild the composite.

With two reduction levels, rebuilding the cached HDR composite takes eight draws:
one extraction, five scaled-blur passes, a source copy and additive glow. Displaying
it with tone mapping adds one draw. The comparison's additional panels add their
own display draws. The retained work comprises four full-size images (source,
highlights, glow, composite), two reduction levels and low-resolution scratch;
RGBA16F takes eight bytes per pixel. There is no per-frame texture allocation,
upload or readback in the warmed operations. Float readback is used only by tests.

### HDR validation (2026-11-17)

The HDR regression passes on macOS Metal and Windows/Ubuntu Vulkan for both
RGBA16F and RGBA32F targets, both native sprite paths and two context lifetimes.
It compares tone-mapped energy and alpha against an independent CPU formula for
negative channels, black, values up to 1000, partial alpha, four exposures and
two gamma values. It checks parameter snapshots, batches, custom blending,
drawing tint/alpha, float tone-map output and ordinary HDR drawing afterwards.
Bright-pass extraction above one retains HDR colour and the expected alpha.

The full float extraction/blur/composite path retains values above white and
halo coverage outside the bright source. Every final display pixel matches the
tone-mapped float composite. A warmed rebuild plus mapped display uses nine
submissions with zero texture creation, upload or readback. Software SDL and
OpenGL report the shader unsupported, and the existing bloom regression passes
on all three macOS profiles. The GUI comparison was inspected with exposure and
threshold changes and bloom toggled off/on. DXBC compiles without warnings;
Direct3D runtime validation remains outstanding. This particular regression validates SDR display of HDR content. Actual HDR
window output was added separately; see [HDR output](hdr-output.md) for the
implementation, display checks and remaining platform limits.

## Reusable buffer ownership

`TMax2DEffectBuffers` can own the intermediate render images and blur pyramid
used by the operations above. See [reusable effect buffers](effect-buffers.md)
for preparation, indexed results, resizing, context ownership and release.

For reusable image masks, use `CreateTextureMaskEffect(maskImage,inverted=False)`.
It supports alpha, colour-channel and weighted masks with the same texture bounds
and batching as other two-texture effects. See [texture masks](shader-packages.md#texture-masks)
and the [live example](../examples/texture_masks.bmx).

Two-texture built-ins support `SetTextureTransform(offsetX,offsetY,scaleX,scaleY,rotation)`
for independent map placement without redrawing the map. See
[positioning the map](shader-packages.md#positioning-the-map).

For one map spanning independently transformed sprites, capture its placement with
`CaptureImageTransform` and call `effect.SetTextureMapping(placement,sprite,x,y)`
before each effect draw. See [sharing a map](shader-packages.md#sharing-a-map-across-sprites).

For soft texture-driven reveals, use `CreateThresholdMaskEffect(map,low,high)`.
It adds a smooth transition band after channel selection and filtering, supports
inversion and shares the same mapping helpers. See
[soft threshold masks](shader-packages.md#soft-threshold-masks).
