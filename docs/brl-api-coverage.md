# BRL.Max2D public API audit

Compared against the local BRL checkout at `c22ccef`. This audit concerns ordinary
application functions exported by `BRL.Max2D`, not binary compatibility or its
image-frame/driver internals. `Max2D.Core` owns different resource types; do not
import it alongside `BRL.Max2D` in one application.

## Available surface

| Area | Functions | Notes |
| --- | --- | --- |
| Primitives | `Cls`, `Plot`, `DrawRect`, `DrawLine`, `DrawOval`, `DrawPoly` | Float/Double coordinate overloads; polygon input remains Float[] |
| Images | `DrawImage`, `DrawImageRect`, `DrawSubImageRect`, `TileImage` | Float/Double coordinates, same frame-index convention |
| Text | `LoadImageFont`, `SetImageFont`, `GetImageFont`, `DrawText`, `TextWidth`, `TextHeight` | DrawText accepts Float/Double; scalable fonts are an explicit optional loader |
| Colors | `SetColor`, `GetColor`, `SetClsColor`, `GetClsColor`, `SetAlpha`, `GetAlpha` | RGB and SColor8 overloads; RGB plus Float alpha outputs; Double SetAlpha |
| Blending/lines | `SetBlend`, `GetBlend`, `SetLineWidth`, `GetLineWidth` | Double line width; see unsupported blend modes below |
| Presentation | `SetVirtualResolution`, `VirtualResolutionWidth`, `VirtualResolutionHeight` | Float/Double input, plus new presentation modes |
| Mouse | `VirtualMouseX`, `VirtualMouseY`, `VirtualMouseXSpeed`, `VirtualMouseYSpeed`, `MoveVirtualMouse` | Float/Double warp coordinates; high-DPI/bar-aware conversions |
| Cursor | `ShowMouse`, `HideMouse` | Already exported through BRL.System; no duplicate wrappers |
| Drawing state | `SetViewport`, `GetViewport`, `SetOrigin`, `GetOrigin`, `SetHandle`, `GetHandle`, `SetRotation`, `GetRotation`, `SetScale`, `GetScale`, `SetTransform` | Double setters; Float output variables as in BRL |
| Image loading | `LoadImage`, `LoadAnimImage`, `CreateImage` | CPU pixmap input and loader URLs; shared storage/padded animation pages |
| Image properties | `SetImageHandle`, `MidHandleImage`, `ImageWidth`, `ImageHeight`, `AutoMidHandle`, `AutoImageFlags`, `GetAutoImageFlags` | Double image handles; automatic flags/handles also apply to CreateRenderImage |
| Mask color | `SetMaskColor`, `GetMaskColor` | CPU color-key loading for images without an alpha channel |
| Pixel editing | `LockImage`, `UnlockImage`, `ClearImage`, `GrabImage`, `DrawPixmap`, `GrabPixmap` | ClearImage has RGBA and SColor8 overloads; see contracts below |
| Render images | `CreateRenderImage`, `SetRenderImage` | TRenderImage, with Null selecting the window |

`SetTransform()` and `TileImage(image)` retain unambiguous defaults. Double
wrappers narrow values explicitly to the Float geometry used by the renderer,
as BRL does; these overloads do not introduce double-precision rendering.
Mixed Int/Float/Double expressions select the appropriate numeric overload.

The BRL `GetClsColor(r,g,b,alpha)` function declaration contains a by-value alpha
parameter. Here alpha is correctly declared `Float Var`, so it is an output.
`GetColor` and `GetClsColor` round-trip an SColor8 value's alpha byte separately
from the Float blend/clear alpha. Setting a color alone does not implicitly
change the independent drawing alpha; `ClearImage(image,color)` does use color.a.

## Pixel transfers and image clearing

`DrawPixmap` and `GrabPixmap` address physical pixels of the complete current
output surface. DrawPixmap copies at 1:1 scale using SOLIDBLEND, unaffected by
origin, handle, transform, virtual resolution, bars, tint, alpha, or viewport
clipping. It restores drawing state and reuses its upload texture. This also
makes `GrabImage` agree with `DrawPixmap` coordinates. To draw a pixmap as part
of the transformed scene, use `LoadImage(pixmap)` and ordinary image drawing.

`ClearImage` clears the entire selected CPU frame (or all frames for -1).
A render image is fully cleared regardless of its saved clip/presentation;
both the previous target's state and the cleared image's saved view survive.
Only -1 or valid frame indices are accepted. CPU write locks/clears require
DYNAMICIMAGE, while `CreateImage` includes that flag automatically. Render-image
CPU write locks are rejected; use drawing, ClearImage and explicit readback.

## Intentional differences

- Default blending is ALPHABLEND, not BRL's MASKBLEND. SDL Renderer
  provides MASKBLEND through its GPU/Metal shader path; other SDL renderer
  implementations currently reject it. OpenGL, D3D9 and D3D11 support it.
  SDL Renderer still rejects mipmaps.
  Use the capability queries rather than relying on a silent substitution.
- Image storage, atlas views, native frames and context ownership are new. Code
  accessing BRL's `frames`, `pixmaps`, sequence counters or driver internals needs
  porting; it is not covered by the familiar-function API promise.
- Images retain CPU pixels and cache distinct textures per context. Render images
  belong to their first context and cannot be sampled while selected for drawing.
- CPU pixmaps contain straight alpha; render images internally use premultiplied
  alpha. Readback returns straight alpha. Some blends require representation
  conversion, with an explicit cost described in the main README.
- Filtered animation cells are repacked with borders. Their internal source
  coordinates need not match the original sheet. Texture identity is stable
  across ordinary pixel edits rather than being recreated for every unlock.
- Text measurement and rendering share multiline layouts; shaped glyph counts
  need not match character counts. New layout/font APIs are not BRL internals.

## Collision coverage

The familiar collision API is now implemented: `ImagesCollide`, `ImagesCollide2`,
  `ResetCollisions`, `CollideImage`, `CollideRect` and all `COLLISION_LAYER_*`
  constants. See [collision semantics](collisions.md) for the pixel-centre rule,
  layer snapshots and explicit render-image capture.

## Still missing

- The historical collision implementation helpers `SetCollisions2DTransform`,
  `DotProduct`, `ClockwisePoly`, `RenderPolys`, `CollideSpans`, `QuadsCollide`,
  `CreateQuad`, `CollideQuad` and `TQuad` are not mirrored.
- Re-enabling D3D7 ([disabled experimental implementation](d3d7.md)),
  a dedicated SDL GPU backend, native widget attachment
  and packed-atlas mipmaps. OpenGL, D3D9 and D3D11 support MASKBLEND and mipmapped
  images/render targets; Direct3D mipmaps depend on device capabilities. See the
  [D3D9 guide](d3d9.md) for its remaining platform and windowing limits.

Collision layers and transformed atlas masks now have dedicated CPU/render
tests. The OpenGL backend also exercises the same
core/driver separation. This audit does not establish complete
behavioural parity across BRL's differing historical backends.

## Evidence

`tests/api_coverage.bmx` compiles and exercises the missing Double/color overloads,
checks physical pixel transfers under a transformed and clipped virtual view,
checks state restoration, automatic render-image settings, and full render-image
clears with a saved clip. `tests/integration.bmx` covers the broader drawing and
resource contracts. The API test passed in debug/release with SDL's software
renderer and in release with macOS Metal; the broader debug integration test also
passed. Read the main README for the remaining platform validation limits.
