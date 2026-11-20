# HDR display output

`Max2D.SDL3GPUMax2D` supports optional extended linear HDR presentation through
SDL GPU. SDR remains the default. This feature changes both the window drawing
buffer and the swapchain: HDR uses RGBA16F storage and extended linear sRGB
output, so brightness values above ordinary white can reach the display.

```blitzmax
Framework Max2D.SDL3GPUMax2D

Graphics(900, 440)
Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(TMax2DGraphics.Current().context)
If context.SupportsHDROutput() Then context.SetHDROutput(True)
```

`examples/hdr_scene.bmx` also accepts `-ud max2d_gl` to demonstrate the same
linear artwork and bloom with SDR tone mapping. This does not enable HDR window
presentation on OpenGL; the HDR toggle is shown only in the SDL GPU build.

## Capabilities and display state

- `SupportsHDROutput()` checks extended linear swapchain and float target support.
  It can be true even on a display with no current HDR brightness headroom.
- `SetHDROutput(True)` selects HDR; `False` restores SDR. Unsupported requests
  throw and leave the mode unchanged. Select the window first. The context must
  be current. A mode change flushes pending drawing and clears the window buffer.
- `HDROutput()` reports the selected output mode, not measured display brightness.
- `HDRHeadroom()` reports the OS's available brightness relative to SDR white.
  A value of 1 means no extra brightness is currently available.
- `SDRWhiteLevel()` reports the OS white point in linear output units. It is 1
  on macOS EDR; Windows may use a different value.

White level and headroom can change when the window moves between displays or
when display settings change. Query them again as needed. The application can
choose SDR fallback when the output format is unsupported or headroom is absent.
No display settings are changed by Max2D.

## Colour contract

HDR window drawing interprets numeric RGB values as **linear sRGB**. A value of
1 is reference white; multiply scene values by `SDRWhiteLevel()` to align normal
white with the desktop. Values above that white level produce HDR highlights,
subject to the display and OS limits. This API does not implement HDR10/PQ output.

This is an explicit rendering mode, not automatic colour management. Ordinary
8-bit textures, `SetColor` and clear colours are not automatically decoded from
sRGB. Existing artwork must be converted to linear values before composing it
with an HDR scene. `SetColor(128,128,128)` supplies approximately 0.5 linear RGB
in HDR mode, which looks brighter than sRGB code value 128 in SDR mode.

Floating-point render images and effects retain their existing numerical
semantics. For an HDR scene, keep composition linear and draw the float result
to the HDR window without the SDR tone mapper or gamma-encoding step. The
existing `hdr_bloom.bmx` example still demonstrates HDR rendering followed by
**SDR tone mapping**; `hdr_output.bmx` demonstrates actual HDR presentation.

Normal drawing, image effects, compact sprites, resize and `Flip(0)` / `Flip(1)`
use the selected window format. Switching formats requires native overlay
integrations to rebuild their pipelines using `WindowOverlayFormat()`.
`GrabPixmap` cannot capture an HDR window: it reports an error instead of silently
clipping the result. Render to a floating-point render image and read its texture
data when HDR capture is needed.

SDR rendering retains its existing pass count and storage. HDR changes the
window storage to 8 bytes per pixel and uses the existing presentation blit;
it does not add a tone-mapping pass.

## Preparing artwork and presenting a linear scene

`Max2D.Effects` provides `SRGBPixmapToLinearTextureData(pixmap)` for ordinary
8-bit sRGB artwork. It returns one RGBA32F level, with straight alpha unchanged.
Convert once at loading time, before texture filtering or mip generation:

```blitzmax
Local pixels:TPixmap = LoadPixmap("artwork.png")
Local image:TImage = LoadImage(SRGBPixmapToLinearTextureData(pixels), FILTEREDIMAGE)
```

The source pixmap is not changed. RGB uses the piecewise sRGB decode curve,
including its linear section near black. Input must be an 8-bit pixmap with
straight alpha and sRGB colour values. Embedded ICC profiles, wide-gamut artwork,
and premultiplied source files need separate preparation. The returned texture
contains no colour metadata: applications must keep track of its linear encoding.
RGBA32F costs 16 bytes per pixel; check texture-format support before upload.

The optional SDL GPU provider implements `CreateLinearOutputEffect()` for the
last draw of a linear scene. It has two explicit modes:

- `SetHDR(True)`: clamp negative channels to zero, apply the exposure multiplier,
  then multiply by the selected SDR white level. Values above white survive.
- `SetHDR(False)`: clamp negative channels to zero, apply exposure, map each
  channel with Reinhard, then encode with the piecewise sRGB transfer curve.
  The white-level setting is ignored in this mode.

```blitzmax
Local output:TMax2DLinearOutputEffect = CreateLinearOutputEffect()
' Update these when the window mode or OS white level changes:
output.SetHDR(context.HDROutput())
output.SetWhiteLevel(context.SDRWhiteLevel())
output.SetExposure(1)
SetRenderImage(Null)
SetColor(255, 255, 255)
SetAlpha(1)
SetBlend(SOLIDBLEND)
DrawImageEffect(scene, output, 0, 0)
```

Check `Max2DSupportsImageEffect(output)` for the selected target. The effect does
not change the window's mode. Compose into an opaque linear floating-point scene,
then present it once; blending separately encoded SDR sprites would blend in the
wrong colour space. Per-channel Reinhard can alter saturation. This is explicit
sRGB conversion and presentation, not general ICC colour management.

The transfer functions follow the [sRGB specification](https://www.w3.org/Graphics/Color/srgb).
The older `CreateToneMapEffect` keeps its original configurable power-curve
behaviour; use the new output effect when piecewise sRGB encoding is needed.

`examples/hdr_scene.bmx` combines decoded artwork with HDR emitters and cached
linear bloom. H switches HDR/SDR, Space toggles bloom, and the arrow keys adjust
threshold/exposure. Exposure and mode changes only affect presentation; threshold
changes rebuild the cached bloom. Each final scene draw is one effect submission,
with no intermediate output image or additional transfer pass.


## Display checks

HDR format support and visible brightness headroom are separate. Check the
context queries on the user's display; a screenshot cannot establish physical
HDR luminance. Virtual machines may report only SDR even on an HDR host display.
Physical Windows/Linux HDR output and SDL GPU Direct3D 12 HDR require further
hardware coverage; use the explicit SDR presentation path when unavailable.

`tests/hdr_output.bmx` exercises output switching and rejection;
`tests/linear_colour.bmx` checks sRGB conversion and linear presentation.
