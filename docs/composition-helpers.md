# Composition helpers

`Max2D.Effects` provides two optional helpers for composing ordinary Max2D
images. They use the existing render-image and effect APIs, with explicit
allocation, capture, processing and release.

| Helper | Owns | Typical use |
| --- | --- | --- |
| `TMax2DEffectChain` | One output and, when needed, one scratch image | Retain a sequence of effects without managing buffer indices. |
| `TMax2DEffectLayer` | One padded source image and its logical layout | Capture a group and draw its source or processed result at the same position. |

Import the [effects provider](effects-quickstart.md#choose-a-provider) matching
your graphics backend. Layer capture and empty-chain copies also work without
a shader provider, provided render images are supported.

## A complete example

[composition_helpers.bmx](../examples/composition_helpers.bmx) draws a captured
group, a cached grayscale version and a padded shadow. The image has twice the
logical resolution, but all three are drawn in ordinary logical coordinates.

From the SDK root:

```sh
./bin/bmk makeapp -r -t gui mod/max2d.mod/examples/composition_helpers.bmx
```

Use `bin\bmk.exe` on Windows. Add `-ud max2d_gl` for OpenGL; the default uses
SDL GPU. Escape or closing the window exits. No assets are required.

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

Graphics 760, 280
Local layer:TMax2DEffectLayer = New TMax2DEffectLayer
' 160 x 100 logical content, 24 units of padding, two pixels per unit.
layer.Prepare(160, 100, 24, 24, 24, 24, 2)
Using
	Local capture:TMax2DStateScope = layer.Capture()
Do
	SetColor(255, 145, 45)
	DrawOval(0, 0, 90, 90)
	SetColor(60, 190, 235)
	DrawRect(75, 35, 85, 65)
End Using

Local chain:TMax2DEffectChain = CreateEffectChain([TMax2DImageEffect(CreateSaturationEffect(0))])
chain.Prepare(layer.Image().width, layer.Image().height)
chain.Update(layer.Image())
Local shadow:TMax2DShadow = CreateShadow(16) ' Eight logical units at scale two.
shadow.Prepare(layer.Image().width, layer.Image().height, 3)
shadow.Update(layer.Image())

Local testMode:Int = AppArgs.Length > 1 And AppArgs[1] = "--test"
Local frames:Int
SetClsColor(24, 28, 38)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls
	SetColor(255, 255, 255)
	SetAlpha(1)
	layer.Draw(40, 90)
	layer.Draw(290, 90, chain.Result())
	SetColor(0, 0, 0)
	SetAlpha(0.7)
	layer.Draw(540+6, 90+8, shadow.Result())
	SetColor(255, 255, 255)
	SetAlpha(1)
	layer.Draw(540, 90)
	DrawText("Captured layer", 40, 35)
	DrawText("Retained chain", 290, 35)
	DrawText("Padded shadow", 540, 35)
	Flip
	frames :+ 1
	If testMode And frames = 3 Then Exit
Wend
shadow.Release()
chain.Release()
layer.Release()
EndGraphics
If testMode Then Print "PASS composition example"
```

## Retained chains

`CreateEffectChain(effects)` retains the descriptions and copies their array.
Editing a description affects its next `Update`; changing your original array
does not alter the chain. `SetEffects(effects)` replaces the sequence and
requires another `Prepare`, even when the dimensions are unchanged.

`Prepare(width, height, pixelFormat)` allocates one output for zero or one
effect, or an output and scratch for two or more. An empty sequence copies the
source. Existing `TMax2DEffectBuffers` and `ApplyLayerEffects` remain useful
when several operations deliberately share explicitly indexed storage.

`Update(source)` always processes the complete source. It checks each effect
against its actual output target, restores caller state, and returns the
borrowed output. It does not include bloom or scaled-blur helpers as chain
stages: those remain separate operations with their own storage.

`Result()` performs no rendering. Identical preparation preserves the result;
changed storage, `SetEffects`, a failed update or `Release` invalidates it.
Changing a retained effect's parameters alone leaves the previous result
available until the next update. A runtime failure can leave partially written
pixels, so `Result` rejects access after a failed update.

## Capture, padding and resolution

`Prepare(width, height, left, top, right, bottom, resolutionScale, pixelFormat)`
uses integer logical dimensions, nonnegative padding and a positive integer
resolution scale. The defaults are no padding, scale one and `PF_RGBA8888`.
Storage dimensions are `(content + padding) * resolutionScale`. Use
`Image().width` and `Image().height` to prepare effects with matching storage.

Inside `Capture()`, `(0,0)` is the content origin. Capture resets camera,
coordinates, transform, handle, tint and blend, clears the entire image to
transparent black, and allows drawing into the padding. Font and line settings
are inherited. `Capture(False)` keeps existing pixels. Close the returned
scope using `Using` or `Finally`; this restores the previous target and drawing
state, including when drawing throws. Different layers can nest captures.

Padding is explicit. Choose enough for the blur halo and any offset you want
to retain. Effects operate in **image pixels**: multiply logical blur radii or
shadow offsets by the resolution scale. Padding is not inferred from shader
code, and bounds are not inferred from draw calls.

`Draw(x, y)` places the content origin at `(x,y)`. `Draw(x,y,result)` uses the
same placement for a matching-sized effect result. Both include the padding,
ignore image handles, and respect the caller's camera, transform, tint, alpha,
blend and clipping. Drawing does not change those settings. You can therefore
move, rotate or tint cached output without rebuilding it.

## Updating and ownership

Capture and processing are independent. When source content changes, capture
it again and call `Update` on the affected effects. If only effect parameters
change, update the effects without recapturing. For an animated effect, update
every frame; for static art, retain `Result()` until it changes.

There is no automatic dirty tracking or global cache. Keep application revision
checks where they are useful. Changing only a layer's logical interpretation
while preserving its pixel dimensions reuses its storage; capture again if
you need pixels drawn under the new interpretation.

All returned images are borrowed. Do not release them independently or retain
them across a changed allocation, release or context closure. Close capture
before drawing the layer, sampling its image, preparing it again or releasing
it. Deselect owned images before release. Do not keep borrowed images in saved
drawing states across reallocation. Release each helper explicitly while
shutting down; repeated releases are harmless. A layer does not own an effect
helper whose result you pass to `Draw`.
