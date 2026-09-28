# Floating-point render images

Use a floating-point render image when intermediate drawing needs to retain colour
values above 1.0 or below 0.0. For example, additive lights can accumulate their
full brightness before you reduce exposure for display. An ordinary RGBA8 target
clips that brightness during drawing, so reducing exposure afterwards cannot
recover the lost detail.

## Choose a supported format

```blitzmax
Local target:TRenderImage
If Max2DSupportsRenderImage(512,512,FILTEREDIMAGE,PF_RGBA16F) Then
	target=CreateRenderImage(512,512,FILTEREDIMAGE,PF_RGBA16F)
Else
	target=CreateRenderImage(512,512,FILTEREDIMAGE)
End If
```

OpenGL, D3D11 and native SDL GPU support floating-point targets when the device supports both
rendering and blending in the requested format. SDL3 Renderer and D3D9 currently
return `False`. Sampled float-texture support alone does not imply target support.
Query again after changing graphics contexts or devices.

`PF_RGBA16F` uses 8 bytes per pixel; `PF_RGBA32F` uses 16 and offers greater
precision and range. RGBA8 remains the default, at 4 bytes per pixel. Floating-point
targets do not support `MIPMAPPEDIMAGE`; pass explicit flags such as
`FILTEREDIMAGE` rather than inheriting automatic image flags that request mipmaps.
Capability checks cannot guarantee sufficient memory for allocation.

## Draw normally

Select the image with `SetRenderImage(target)`, clear and draw, then return to the
window with `SetRenderImage(Null)`. Cameras, drawing-state scopes and image views
work as with ordinary targets. Use `DrawImage(target,x,y)` to sample the result.

The [lighting example](../examples/float_render_images.bmx) draws identical
additive lights into RGBA8 and floating-point targets. Left/Right changes exposure
using drawing colour modulation. Build normally for OpenGL, or with the
`max2d_d3d11` custom build condition for D3D11 or `max2d_sdlgpu` for native SDL GPU.

This adds intermediate colour range, not an HDR display mode, automatic tone
mapping or automatic colour-space conversion. Ordinary windows and RGBA8 targets
still limit final output to their usual range. As with other render images,
D3D11 device recovery recreates storage but clears its contents: redraw your scene.

## Read back without clipping

Keep the image on the GPU when possible. Readback waits for rendering and copies
the result into CPU memory:

```blitzmax
Local data:TTextureData=ReadRenderTextureData(target)
If data.Level().Format()=PF_RGBA32F Then
	Local pixels:Float Ptr=Float Ptr(data.Level().Data())
	Local firstRed:Float=pixels[0]
	Local firstAlpha:Float=pixels[3]
End If
```

Floating-point targets return native-endian `PF_RGBA32F`, including RGBA16F targets
(whose channels are widened). Rows start at the top left. GPU targets use
premultiplied storage; readback returns straight alpha, dividing RGB by nonzero
alpha and returning zero RGB when alpha is zero. Keep `data` alive while using its
borrowed pointer.

Ordinary targets return `PF_RGBA8888`. `ReadRenderImage` and pixmap read operations
reject floating-point targets rather than silently quantizing them; `TPixmap`
behavior is unchanged. For an explicit conversion, use the general BRL.TextureData API:

```blitzmax
Local options:TTexturePixmapOptions=New TTexturePixmapOptions
options.exposureStops=-2
options.toneMap=ETextureToneMap.Reinhard
' Choose SRGB output only if the source drawing represents linear-light colours.
options.outputEncoding=ETextureEncoding.SRGB
Local pixels:TPixmap=data.ConvertToPixmap(options)
```

The result can be saved with existing pixmap encoders. This CPU operation should
be cached, not repeated for every draw. See the
[conversion example](../examples/texture_conversion.bmx) and BRL.TextureData's
README for alpha, encoding and exceptional-value rules.
