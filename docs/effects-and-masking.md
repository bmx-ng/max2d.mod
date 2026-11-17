# Effects and group masking

`Max2D.Effects` is optional. Import it only in applications that use layer
compositing. The first slice provides two operations on a caller-owned
`TRenderImage`: `ApplyLayerAlphaMask(mask)` and `ApplyLayerOpacity(opacity)`.
Both multiply stored RGB and alpha, so a transparent layer remains in Max2D's
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
optional saturation and blur shader provider. The effect description lives in
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
optional module links those assets. Backends without a registered provider,
including OpenGL, D3D9, D3D11 and SDL_Renderer, report this shader effect
unsupported. The public API does not silently fall back to a CPU conversion.
This first package does not expose arbitrary shaders or additional texture
slots; those require the validated package design below.

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
[interactive blur example](../examples/blur_effects.bmx). Wider blurs and automatic
scratch pooling remain future work.

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

The operations above exercise the target, parameter and compositing contracts.
Further shader work should keep two explicit categories:

* **Direct draw effects** change a draw's sampling or colour without needing the
  destination. A selected immutable effect snapshot joins texture, blend, clip
  and target in the batch key. Changing effect or parameter values ends the
  pending batch. Queued draws retain their submitted snapshot even if the
  caller changes a parameter object later. A parameter object is reusable; one
  fixed-size native uniform upload per changed batch is preferable to per-draw
  allocations. Ordinary drawing continues through its current pipeline.
* **Layer effects** sample a previously rendered group. They declare input
  textures, output format, sampling radius/padding and bounds. They require an
  explicit render-image target or an opt-in scoped group API. A radius-zero
  colour effect can cover just the group's bounds; a blur expands by its sample
  radius. Rendering a full window when the group occupies a small rectangle
  would waste bandwidth. An effect chain can ping-pong between two compatible
  scratch targets owned by the graphics context. A source may never be the
  active destination in the same pass.

An effect description should contain a stable name, typed parameter layout,
declared texture slots, colour convention, bounds/padding and a package version.
Create effect instances once, then update typed values between draws. Built-in
and third-party shader packages should use the same backend registration
contract. The package should carry precompiled SPIR-V for Vulkan, Metal source
or metallib for Metal, and appropriate Direct3D bytecode, plus GLSL 1.20 for
the desktop OpenGL baseline. This matches the current SDL GPU shader-source
layout but needs a versioned binding manifest and reflection/validation at
registration. A package is supported only when its exact format and resource
limits fit the active context. Direct3D 9 needs a separate shader profile and
Direct3D 11 a separate device implementation. `SDL3RenderMax2D` has no general
shader hook; it must report custom shader effects unsupported. The SDL renderer
named `gpu` is still SDL_Renderer and does not make it the native SDL GPU
backend. Fixed-function operations such as this alpha multiplication can be
supported where the selected SDL renderer exposes the exact blend equation.

Texture slots should be explicit rather than implicit global image bindings.
The package must declare whether a slot expects a straight-alpha image,
premultiplied render image, coverage map or other data. Rendering a layer into
RGBA starts premultiplied; a shader's output to that layer must preserve the
same convention. Normal maps and light maps can later use typed data slots
without changing sprite texture semantics. The resource owner is the current
`TMax2DContext`; pipelines, parameter buffers and scratch targets are released
on context close or device loss. Shader package descriptions may outlive a
context, but native objects cannot. Capability checks must be repeated after
changing backend or recreating graphics.

## Cost and validation plan

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
