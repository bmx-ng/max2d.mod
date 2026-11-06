# Blending

Blending combines the colour you draw (the **source**) with the colour already
in the drawing surface (the **destination**). The familiar modes still work:
`SOLIDBLEND`, `MASKBLEND`, `ALPHABLEND`, `LIGHTBLEND` and `SHADEBLEND`.
`SUBTRACTBLEND` adds alpha-controlled darkening. Custom modes let you choose the
colour equation and alpha equation separately.

## Start with subtraction

```blitzmax
Graphics 800, 450
If Max2DSupportsBlend(SUBTRACTBLEND) Then
	SetBlend(SUBTRACTBLEND)
	SetColor(100, 40, 20)
	SetAlpha(0.5)
	DrawRect(100, 100, 200, 120)
End If
SetBlend(ALPHABLEND)
SetAlpha(1)
```

This subtracts `(50, 20, 10)` from destination RGB. Destination alpha is unchanged.
A black source has no effect. A white source darkens every colour channel;
a coloured source removes different amounts from different channels. Source
image alpha and drawing alpha both control the strength. Integer/normalized
surfaces clamp at zero; floating-point render images can retain negative values.
This is coloured darkening, not a physical lighting or shadow simulation.

## Create once, draw normally

```blitzmax
Local screen:Int = CreateBlendMode(BLEND_ONE, BLEND_ONE_MINUS_SRC_COLOR)

Graphics 800, 450
If Max2DSupportsBlend(screen) Then
	SetBlend(screen)
	DrawImage(highlight, 100, 100)
End If
```

`CreateBlendMode` returns an opaque `Int`, with no object or graphics allocation.
The same description returns the same value. You may create modes before
`Graphics`, share them between contexts, and store them alongside other drawing
settings. There is no matching free function. Do not depend on the integer's
internal encoding.

`Max2DSupportsBlend` checks the **current graphics context**; query it again after
changing backend or recreating graphics. A query may prepare and cache native
pipeline state. `SetBlend` throws for unsupported modes, leaving the previous
mode selected. Max2D does not silently approximate your equation.

Custom modes work with sprites, text, primitives, render images, and the drawing
state stack. `GetBlend` returns the selected value. Mode changes split batches
just as changes between ordinary modes do. Native states are reused and released
when their graphics context is destroyed. Both native SDL GPU sprite submission
paths support custom modes.

## The equations

```blitzmax
CreateBlendMode(sourceFactor, destinationFactor, colourOperation, ..
	sourceAlphaFactor, destinationAlphaFactor, alphaOperation)
```

Defaults are `BLEND_OP_ADD`, `BLEND_ONE`, `BLEND_ONE_MINUS_SRC_ALPHA`, and
`BLEND_OP_ADD` for the last four arguments. Thus the default alpha equation is
source-over: `sourceAlpha + destinationAlpha * (1 - sourceAlpha)`.

For RGB, first form `S = sourceRGB * sourceFactor` and
`D = destinationRGB * destinationFactor`, component by component:

| Operation | Result |
| --- | --- |
| `BLEND_OP_ADD` | `S + D` |
| `BLEND_OP_SUBTRACT` | `S - D` |
| `BLEND_OP_REVERSE_SUBTRACT` | `D - S` |
| `BLEND_OP_MIN` | `min(sourceRGB, destinationRGB)`; factors ignored |
| `BLEND_OP_MAX` | `max(sourceRGB, destinationRGB)`; factors ignored |

The alpha equation works the same way with scalar alpha components. Alpha
factors with colour names are aliases for their alpha equivalents. Invalid
factor or operation constants throw when creating the mode.

Available factors: `BLEND_ZERO`, `BLEND_ONE`, `BLEND_SRC_COLOR`,
`BLEND_ONE_MINUS_SRC_COLOR`, `BLEND_SRC_ALPHA`, `BLEND_ONE_MINUS_SRC_ALPHA`,
`BLEND_DST_COLOR`, `BLEND_ONE_MINUS_DST_COLOR`, `BLEND_DST_ALPHA`,
`BLEND_ONE_MINUS_DST_ALPHA`.

Source RGB is **straight colour**, after texture sampling and `SetColor` tint.
Source alpha includes texture alpha and `SetAlpha`. A render image used as a
source is converted from premultiplied storage before the custom equation.
The destination is the surface's **stored value**: on transparent render images,
RGB is premultiplied by alpha. There is no hidden conversion of destination RGB.

## Recipes

Always check support before using these. Except the normal-alpha recipe, the
following recipes preserve destination alpha. They are particularly useful for
opaque scenes. Some intentionally ignore source alpha; see the notes below.

```blitzmax
' Ordinary alpha compositing, expressed as a custom equation.
Local normal:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA)

' Add light, weighted by source opacity; preserve destination alpha.
Local add:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE, BLEND_OP_ADD, ..
	BLEND_ZERO, BLEND_ONE)

' Same equation as SUBTRACTBLEND. Matching RGB/alpha operations also allows
' SDL renderer drivers that cannot use different operations for colour/alpha.
Local darken:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE, BLEND_OP_REVERSE_SUBTRACT, ..
	BLEND_ZERO, BLEND_ONE, BLEND_OP_REVERSE_SUBTRACT)

' Multiply: same RGB equation as SHADEBLEND. Ignores source alpha.
Local multiply:Int = CreateBlendMode(BLEND_DST_COLOR, BLEND_ZERO, BLEND_OP_ADD, ..
	BLEND_ZERO, BLEND_ONE)

' Screen: brightens the destination. Ignores source alpha.
Local screen:Int = CreateBlendMode(BLEND_ONE, BLEND_ONE_MINUS_SRC_COLOR, BLEND_OP_ADD, ..
	BLEND_ZERO, BLEND_ONE)

' Erase coverage and stored RGB together, using source alpha as the mask.
' Useful for cutting holes in transparent render images.
Local erase:Int = CreateBlendMode(BLEND_ZERO, BLEND_ONE_MINUS_SRC_ALPHA, BLEND_OP_ADD, ..
	BLEND_ZERO, BLEND_ONE_MINUS_SRC_ALPHA)

' Change alpha only, keeping stored RGB. This can break premultiplied storage!
Local alphaOnly:Int = CreateBlendMode(BLEND_ZERO, BLEND_ONE, BLEND_OP_ADD, ..
	BLEND_ONE, BLEND_ZERO)

' Keep the darker/lighter source or destination value, per channel.
' Alpha is preserved, so these need independent colour/alpha operations.
Local minimum:Int = CreateBlendMode(BLEND_ONE, BLEND_ONE, BLEND_OP_MIN, ..
	BLEND_ZERO, BLEND_ONE)
Local maximum:Int = CreateBlendMode(BLEND_ONE, BLEND_ONE, BLEND_OP_MAX, ..
	BLEND_ZERO, BLEND_ONE)
```

`SetAlpha` only fades RGB if your factors use source alpha. For example, screen
and multiply above continue to affect RGB at `SetAlpha(0)`. A fully transparent
pixel is not automatically discarded by custom blending. Use an appropriate
alpha-dependent equation or limit the drawn geometry; custom blending is not a
replacement for `MASKBLEND`.

MIN/MAX are component-wise, not comparisons of overall brightness. They ignore
source alpha unless you explicitly include it in another stage of your effect.
Fixed-function blending cannot express every compositing formula: overlay,
soft-light, and arbitrary masked interpolation may require a shader or extra
rendering passes.

## Transparent render images

Max2D stores render-image RGB premultiplied by alpha. Ordinary `ALPHABLEND` and
the custom `normal` recipe produce that representation. The `erase` recipe
reduces RGB and alpha together and therefore preserves it. The runnable
[render-image example](../examples/blend_render_image.bmx) demonstrates this.

Arbitrary equations can produce RGB inconsistent with alpha. For example,
writing alpha without changing RGB, or adding light into pixels whose alpha is
zero, is not ordinary translucent compositing. Later drawing/readback interprets
those values as premultiplied colour. Choose matching RGB and alpha equations,
or use an opaque intermediate surface when the effect does not need transparency.
A custom blend does not change a render image's storage convention.

## Backend support

| Backend | Custom blending / subtraction |
| --- | --- |
| `Max2D.GLMax2D` | Separate RGB and alpha factors and all five operations |
| `Max2D.D3D11Max2D` | Separate RGB and alpha factors and all five operations; native state creation checked |
| `Max2D.D3D9Max2D` | Device blend-factor/operation capabilities checked |
| `Max2D.SDL3GPUMax2D` | Native pipeline state, including compact sprite and triangle paths |
| `Max2D.SDL3RenderMax2D` | Depends on the selected SDL renderer; exact texture and primitive blend support checked |
| SDL software renderer | Custom modes and `SUBTRACTBLEND` unavailable |
| Legacy `Max2D.D3D7Max2D` | Custom modes and `SUBTRACTBLEND` unavailable; existing modes unchanged |

For SDL renderer drivers requiring the same colour and alpha operation,
`SUBTRACTBLEND` uses `destinationAlpha * ONE - sourceAlpha * ZERO`, preserving
alpha without a separate ADD operation. A seemingly equivalent custom equation
using ADD for alpha can therefore have different availability.

## Try the examples

- [Blend gallery](../examples/custom_blending.bmx): subtraction, add, multiply,
  screen, minimum and maximum, with an adjustable source opacity.
- [Transparent render image](../examples/blend_render_image.bmx): use a mask to
  erase part of a cached image, then composite it over a chequerboard.

Both examples default to the SDL3 renderer. Build with `-ud max2d_gl`,
`-ud max2d_sdlgpu`, `-ud max2d_d3d9` or `-ud max2d_d3d11` to compare backends.
Unsupported effects are labelled instead of silently substituted.
