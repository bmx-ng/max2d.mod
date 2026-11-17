# HDR display output

`Max2D.SDL3GPUMax2D` supports optional extended linear HDR presentation through
SDL GPU. SDR remains the default. This feature changes both the window drawing
buffer and the swapchain: HDR uses RGBA16F storage and extended linear sRGB
output, so brightness values above ordinary white can reach the display.

```blitzmax
Graphics(900, 440)
Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(TMax2DGraphics.Current().context)
If context.SupportsHDROutput() Then context.SetHDROutput(True)
```

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

## Validation (2026-11-17)

`tests/hdr_output.bmx` verifies the SDR default, both sprite submission paths,
unclipped float window values, an image effect targeting the HDR window,
synchronisation changes, resize, rejection of mode changes while a render image
is selected, restoration of SDR readback, and two graphics context lifetimes.
Unsupported systems verify rejection without losing SDR rendering.

- macOS / Metal: HDR format supported; OS reported 16x headroom and white level 1.
  The live demo selected HDR successfully, and the user confirmed visibly brighter
  output. Screen captures cannot establish physical HDR luminance.
- Windows 11 VM / Vulkan: HDR format unsupported, headroom 1; SDR fallback passed.
- Ubuntu VM / Vulkan: HDR format unsupported, headroom 1; SDR fallback passed.

The VMs do not validate physical Windows/Linux HDR display output. Direct3D 12
HDR output is also unverified. HDR availability varies with the backend, OS,
display configuration and virtualisation environment.
