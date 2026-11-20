# Applying effects

Max2D effects use the same images, drawing state and render targets as ordinary
Max2D drawing. There are three useful starting points:

| What you need | Use | When work happens |
| --- | --- | --- |
| Change one image as it is drawn | `DrawImageEffect(image, effect, x, y)` | One effect draw per call; no intermediate image. |
| Process a group through several effects | Draw the group into a layer, then `buffers.ApplyChain(source, 0, chain)` | One pass per effect into retained images. |
| Reuse bloom or a shadow | `Prepare`, `Update(source)`, then draw `Result()` | Rebuild only when source pixels or settings change. |

For a hard rectangular clip, use `IntersectViewport` in a drawing-state scope.
For a simple image fade, use `SetAlpha` with `DrawImage`. Neither needs an effect
pass. Use a layer when a whole group must be filtered or faded as one image.

## Choose a provider

Select one framework and import its matching effects provider:

| Framework | Effects import |
| --- | --- |
| `Max2D.SDL3GPUMax2D` | `Max2D.SDL3GPUEffects` |
| `Max2D.GLMax2D` | `Max2D.GLEffects` |
| `Max2D.D3D9Max2D` | `Max2D.D3D9Effects` |
| `Max2D.D3D11Max2D` | `Max2D.D3D11Effects` |

Each provider imports the shared `Max2D.Effects` and `Max2D.ShaderEffects` APIs.
Importing only `Max2D.Effects` provides descriptions, buffers and fixed-function
layer operations; it does not install a shader provider. SDL_Renderer has no
shader provider. Native D3D9 and D3D11 require Windows; D3D9 effects require
pixel shader 3.0.

Call `Max2DSupportsImageEffect(effect)` **after `Graphics`**, with the intended
target and blend selected. It checks that combination, and may compile/cache a
pipeline on first use. It does not validate a particular source image, bound
map or prepared buffer layout. For example, blur and outline need a render-image
source, and coordinate effects reject trimmed sprites. Chains and cached helpers
also validate their actual intermediate targets before processing them.

Check `Max2DSupportsRenderImage` for the dimensions, flags and format you need.
An unsupported operation throws; it does not silently run on the CPU. An
application can choose a simpler drawing path when a capability is unavailable.

## A complete example

This asset-free program draws a grayscale image directly, a cached blur/colour
chain, and a cached shadow. The source contains transparent padding for halos.
All image allocations and cached processing happen outside the frame loop.

Source: [effects_quickstart.bmx](../examples/effects_quickstart.bmx).
From the SDK root, build and run:

```sh
./bin/bmk makeapp -r -t gui mod/max2d.mod/examples/effects_quickstart.bmx
```

On Windows, use `bin\bmk.exe`. Add `-ud max2d_gl` for the OpenGL version.
The default uses SDL GPU. See the [main README](../README.md#get-started) for
SDK and module dependencies. Escape or closing the window exits.

```blitzmax
SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import BRL.StandardIO

Graphics 800, 300
Const layerWidth:Int = 240, layerHeight:Int = 180
If Not Max2DSupportsRenderImage(layerWidth, layerHeight, FILTEREDIMAGE) Then Throw "Filtered render images are required"

' Allocate and draw this padded source once. Keep it for subsequent frames.
Local source:TRenderImage = CreateRenderImage(layerWidth, layerHeight, FILTEREDIMAGE)
Using
	Local scope:TMax2DStateScope = ScopedMax2DState()
Do
	SetRenderImage(source)
	SetVirtualResolution(layerWidth, layerHeight)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(255, 145, 45)
	DrawOval(40, 35, 100, 100)
	SetColor(60, 190, 235)
	DrawRect(115, 65, 80, 70)
End Using

' Descriptions allocate no render images and can be retained and edited.
Local grayscale:TMax2DSaturationEffect = CreateSaturationEffect(0)
Local tint:TMax2DColorizeEffect = CreateColorizeEffect(100, 185, 255)
Local horizontal:TMax2DBlurEffect = CreateBlurEffect(4, True)
Local vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)
If Not Max2DSupportsImageEffect(grayscale) Then Throw "Import an effects provider supported by this graphics context"

' A retained two-image owner handles the alternating outputs of this chain.
Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(horizontal), TMax2DImageEffect(vertical), TMax2DImageEffect(tint)]
Local buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
buffers.Prepare(layerWidth, layerHeight)
Local softened:TRenderImage = buffers.ApplyChain(source, 0, chain)

' Cached helpers own their intermediate images. Update only when needed.
Local shadow:TMax2DShadow = CreateShadow(8)
shadow.Prepare(layerWidth, layerHeight, 2)
shadow.Update(source)

Local testMode:Int = AppArgs.Length > 1 And AppArgs[1] = "--test"
Local frames:Int
SetClsColor(24, 28, 38)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls
	SetBlend(ALPHABLEND)
	SetColor(255, 255, 255)
	SetAlpha(1)
	DrawImageEffect(source, grayscale, 10, 60)
	DrawImage(softened, 280, 60)
	SetColor(0, 0, 0)
	SetAlpha(0.65)
	DrawImage(shadow.Result(), 550+8, 60+8)
	SetColor(255, 255, 255)
	SetAlpha(1)
	DrawImage(source, 550, 60)
	DrawText("Direct effect", 30, 30)
	DrawText("Cached blur + colour", 280, 30)
	DrawText("Cached shadow", 550, 30)
	Flip
	frames:+1
	If testMode And frames=3 Then Exit
Wend

' Borrowed results expire here; select a separate target before releasing.
SetRenderImage(Null)
shadow.Release()
buffers.Release()
source.ReleaseFrames()
EndGraphics
If testMode Then Print "PASS effects quickstart"
```

## Drawing state and effect settings

`DrawImageEffect` follows `DrawImage`: source handle, camera, transform, viewport,
tint, alpha and blend all apply. Pass the effect explicitly; there is no global
`SetEffect` to reset afterwards. Subsequent ordinary draws are unaffected.

Create descriptions once and edit them as needed. Submitted draws capture their
settings, so changing saturation or shader parameters cannot alter earlier work.
A state scope restores **drawing state**, not edits to an effect object.

`DrawImageEffectBatch(image, effect, positions)` draws repeated copies using an
interleaved `Float[]` of x,y pairs. All copies share the frame, settings and current
drawing state. Reuse the array. Separate `DrawImageEffect` calls are explicit batch
boundaries; use the batch function when copies can share one configuration.

## Layers, chains and storage

Render a group into a transparent `TRenderImage`. Finish drawing the source before
sampling it. Source, destination and any scratch image must be distinct; rendering
an effect back into its input is not supported.

`ApplyLayerEffects(source, destination, chain, scratch)` is the lower-level form.
`TMax2DEffectBuffers.ApplyChain` uses the same processing with owned, indexed
outputs. Chain entries run in array order. Two or more effects need a distinct
scratch image (index 1 by default); one effect needs only the destination. An
empty chain copies the source. The final result always lands in the requested
destination, regardless of chain length.

Whole-layer processing ignores drawing tint, camera, transforms, clipping and
source handles. It replaces the complete output and restores the caller's drawing
state and target views. Apply placement, tint and alpha when drawing the result.
The buffer owner's `ApplyChain` returns a borrowed image; the lower-level function
writes into the destination supplied by the caller.

`ApplyLayerAlphaMask`, `ApplyLayerInverseAlphaMask` and `ApplyLayerOpacity` are the
in-place exceptions: they multiply the **currently selected layer's** pixels.
Repeated application compounds the change. For a reusable source, redraw or copy
it before applying the mask. Masks must match the layer size. See
[layer masking](effects-and-masking.md#layer-masking).

## Cache lifecycle

The same pattern applies to `TMax2DBloom`, `TMax2DShadow` and `TMax2DInnerShadow`:

1. Create and retain the helper.
2. `Prepare` after opening graphics, and again when its dimensions/layout change.
3. `Update(source)` after source pixels or processing settings change.
4. Draw `Result()` each frame. Retrieving it performs no rendering.
5. `Release()` when finished, after selecting a different render target.

There is no automatic dirty tracking. Changing a setter keeps the old result until
`Update`. Changing a prepared layout invalidates it; identical preparation retains
it. Results are borrowed: do not independently release them, and reacquire them
after reconfiguration. Owners belong to one graphics context. Do not retain their
images across release, layout changes or context closure, including in saved state
scopes. See [buffer ownership](effect-buffers.md#ownership-resizing-and-release).

A source's handle is independent of the result's default zero handle. For matching placement
under rotation and scale, deliberately assign matching handles to source and
result, then draw at the same position. With identity transforms, subtracting the
source handle from the result's drawing position is another option. Retain transparent padding inside the source;
processing does not enlarge its bounds or return an automatic placement offset.

Outer shadows are drawn **before** the source; inner shadows are drawn **after**
it. Their colour and opacity are ordinary draw-time settings. A group shadow
uses the combined alpha of every shape; use separate layers/results when nearby
shapes must not affect each other's shading.

## Blur, bloom and colour

`CreateBlurEffect` provides one axis of a radius 0–4 pixel blur. Horizontal then
vertical passes blur in two dimensions. `CreateScaledBlur` handles wider radii
using a prepared reduction pyramid; the radius must fit four pixels at its
smallest level. Reduced blur is approximate and requires filtered inputs without
mipmaps. See [wide blur](effects-and-masking.md#wider-blur-with-retained-reduction-levels).

`TMax2DBloom` defaults to floating-point storage and returns an **opaque** scene
flattened over black, with bloom added. It is not a transparent glow sprite.
For glow-only output, use bright-pass extraction and blur, then composite it with
`LIGHTBLEND`. For an ordinary LDR scene, `PF_RGBA8888` can be explicitly selected
but clips values above its range. See [bloom](bloom.md).

Floating-point layers preserve bright values; they do not enable HDR monitor
output. For linear rendering, convert artwork once, compose in linear space,
then present through `CreateLinearOutputEffect`. Actual HDR display output needs
separate SDL GPU context support. See [HDR and colour handling](hdr-output.md).

## Next recipes

- [Effect operations and limits](effects-and-masking.md): masks, chains, outlines,
  bright-pass extraction and manual composition.
- [Reusable buffers](effect-buffers.md), [bloom](bloom.md),
  [soft shadows](shadows.md), [inner shadows](inner-shadows.md).
- [Shader packages](shader-packages.md): colour matrices, distortion, displacement,
  dissolve, transformed masks, typed parameters and custom shader authoring.
- [Effects gallery](effects-gallery.md): side-by-side visual comparisons.
