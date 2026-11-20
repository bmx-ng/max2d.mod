# Max2D

A 2D drawing framework for BlitzMax NG, with familiar functions such as
`DrawImage`, `DrawText`, `DrawRect` and `Flip` across OpenGL, Direct3D and SDL3
backends.

Use it for sprites and animation, cameras, render-to-texture, scalable text,
texture atlases and tile-based games. The shared drawing API handles batching,
drawing state, virtual resolution and input-coordinate conversion, so you can
choose a backend without rewriting your scene code.

- [Get started](#get-started)
- [Choose a backend](#choose-a-backend)
- [What you can build](#what-you-can-build)
- [Optional modules](#optional-modules)
- [Moving from BRL.Max2D](#moving-from-brlmax2d)
- [Capabilities and limitations](#capabilities-and-limitations)
- [Examples and documentation](#examples-and-documentation)

[Custom shader packages](docs/shader-packages.md) provide typed parameters,
colour matrices, waves, ripples, displacement, dissolve and transformed/shared
texture masks on SDL GPU, OpenGL and native Direct3D9/Direct3D11.

Native Direct3D effects are available through `Max2D.D3D11Effects` and
`Max2D.D3D9Effects`: colour effects, blur, outlines, bloom, reusable shadows and shader-package ABI 1–4.
Both native backends support float composition when the device supports the format.
See the [D3D11](docs/d3d11.md#optional-image-effects) and
[D3D9](docs/d3d9.md#optional-image-effects) guides for requirements and current limits.

The SDL3 GPU backend also offers opt-in [HDR display output](docs/hdr-output.md),
with a live HDR/SDR comparison in `examples/hdr_output.bmx`.
`examples/hdr_scene.bmx` adds sRGB artwork conversion and linear bloom with
HDR output or sRGB-encoded SDR tone mapping.
[Reusable effect buffers](docs/effect-buffers.md) manage retained intermediate
images and blur pyramids for these operations. [Reusable bloom](docs/bloom.md)
combines extraction, blur and composition behind an explicit cached-result API.
[Inverse layer masks](docs/effects-and-masking.md#inverse-masks-and-cutouts) add
soft cutouts with one ordinary draw and no shader package.
[Reusable soft shadows](docs/shadows.md) cache alpha silhouettes with draw-time
colour, opacity and offset. [Inner shadows](docs/inner-shadows.md) add cached
recessed shading inside shapes and text.

Explore the [effects gallery](docs/effects-gallery.md) for side-by-side examples
and explicit independent/group shadow comparisons.

## Get started

Use a **bcc2-based BlitzMax NG SDK** with up-to-date BRL, Pub, Text and Math
modules. In particular, the core uses `BRL.PixelFormat`, `BRL.TextureData`,
`Text.Boundaries`, `Text.Bidi` and `Math.Polygon`. The native Unicode providers
are optional; see [text and fonts](#text-and-fonts).

From the SDK directory, install this repository as `mod/max2d.mod`:

```sh
git clone https://github.com/bmx-ng/max2d.mod.git mod/max2d.mod
```

For either SDL3 backend, also install
[SDL3](https://github.com/bmx-ng/sdl3.mod) as `mod/sdl3.mod` and follow its platform
setup instructions. SDL3 is built from bundled sources; no separate SDL library
is required. Linux SDL3 builds need BMK2 4.04 or newer.

Save this as `hello.bmx` in your SDK directory:

```blitzmax
SuperStrict

Framework Max2D.GLMax2D

Graphics 800, 450
SetClsColor 24, 28, 38

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls

	SetColor 55, 170, 240
	DrawRect 40, 40, 160, 100

	SetColor 255, 255, 255
	DrawText "Hello from Max2D!", 40, 170

	Flip
Wend

EndGraphics
```

Build and run it in your IDE, or build it from the SDK directory:

```sh
./bin/bmk makeapp -r -t gui hello.bmx
```

On Windows:

```powershell
.\bin\bmk.exe makeapp -r -t gui hello.bmx
```

Run the executable or application bundle generated beside the source file.
Press Escape or close the window to quit. The built-in font needs no asset files.
Import an image or font loader when you start loading your own assets—for example,
`BRL.PNGLoader` for PNG images or `BRL.FreeTypeFont` for ordinary outline fonts.

## Choose a backend

Select one backend with the application's `Framework` line. Each imports
`Max2D.Core`, which provides the common drawing API.

| Framework | Use it for |
| --- | --- |
| `Max2D.GLMax2D` | Desktop OpenGL through BRL.GLGraphics on macOS, Windows and Linux/X11. Requires OpenGL 2.1, GLSL 1.20 and framebuffer-object support. |
| `Max2D.SDL3RenderMax2D` | SDL's renderer API on macOS, Windows and Linux, with SDL choosing an available rendering driver. |
| `Max2D.SDL3GPUMax2D` | Direct use of SDL's GPU API through Metal, Vulkan or Direct3D 12, subject to platform and device support. |
| `Max2D.D3D9Max2D` | Native Direct3D9 rendering on Windows. |
| `Max2D.D3D11Max2D` | Native Direct3D11 rendering on Windows. |

The two SDL3 backends are separate implementations. Selecting a renderer called
`gpu` within SDL_Renderer still uses `Max2D.SDL3RenderMax2D`; it does not switch to
the direct GPU backend. See [the SDL GPU guide](docs/sdl-gpu.md) for choosing between
them and checking device availability.

Backend guides: [OpenGL](docs/opengl-backend.md), [D3D9](docs/d3d9.md),
[D3D11](docs/d3d11.md), [SDL GPU](docs/sdl-gpu.md).

## What you can build

### Scenes, cameras and UI

- Draw shapes, images, animation frames and text with ordered batching.
- Pan, zoom and rotate with `TCamera2D`; convert window, virtual and world
  coordinates for mouse picking.
- Use `SetVirtualResolution(320, 180, VIRTUAL_LETTERBOX)` for a fixed canvas with
  aspect-preserving bars, or `VIRTUAL_INTEGER` for whole-number scaling when it fits.
- Draw native-resolution overlays independently of a virtual scene.
- Save and restore drawing state manually with `PushMax2DState`/`PopMax2DState`,
  or automatically with `ScopedMax2DState()` in a `Using` block.
- Switch between windowed, borderless and exclusive fullscreen where supported.

Virtual resolution changes drawing coordinates. To render a deliberately
low-resolution scene, draw into a small render image and scale it up. Camera and
mouse conversions account for display scaling and letterbox bars.

See [cameras](docs/cameras.md), [drawing state](docs/drawing-state.md),
[window modes](docs/window-modes.md) and [virtual resolution and input](docs/drawing-guide.md).

### Images, textures and atlases

Load images from existing pixmap loaders, draw into render images, update dynamic
images, and share texture storage between sprite views. Alpha-mask collisions
support animation, atlas regions and transformed images.

Build atlases at runtime or with the included [atlas builder](tools/atlas_builder.bmx).
Trim transparent borders while retaining sprite size and drawing position; save
PNG/JSON atlas packages with names, handles, animation frames and timing.

For explicit GPU storage, use `BRL.TextureData` to supply mip levels, single-channel
coverage, floating-point pixels or BC1/BC3 compressed data on supported backends.
Import `Image.DDS` to load supported DDS files without expanding their compressed
blocks into pixmaps. Ordinary `TPixmap` image loading remains available.

See [images and atlases](docs/drawing-guide.md), [atlas packages](docs/atlas-format.md),
[collisions](docs/collisions.md), [texture data](docs/texture-data.md),
[mipmaps](docs/mipmaps.md) and [compressed textures](docs/compressed-textures.md).

### Text and fonts

Use `DrawText` for simple labels, or prepare reusable paragraph layouts with
wrapping, alignment, font/colour spans and backgrounds. Optional interaction
geometry supports caret placement, hit testing and selection in scrollable text.
A selection controller handles character, word and line selection, including drag.

Import `Max2D.RichText` to prepare inline tags such as `[b]bold[/b]`,
`[color=#FFD060]gold[/color]` and `[style=heading]Title[/style]`. Parse content once,
resolve it using registered fonts and styles, and reuse the ordinary text layout
cache. See [inline rich text](docs/rich-text.md) and the
[interactive example](examples/rich_text.bmx).

Import `Max2D.ScalableFont` for FreeType/HarfBuzz text that selects an appropriate
glyph raster size for the current display scale and drawing transform. Load the
actual font faces you need; automatic font fallback is not provided.

International text features are added by import:

- `Text.Unibreak` supplies Unicode line, word and grapheme boundaries.
- `Text.SheenBidi` supplies bidirectional analysis for mixed-direction text.

Without those providers, the core retains its basic layout behaviour and does not
link their native libraries. Fonts are supplied by your application.

See [text layout and interaction](docs/text-layout.md) and
[font loading and caches](docs/drawing-guide.md#fonts).

### Tile-based games

Create editable maps in code without an external editor, or load Tiled and LDtk
projects through optional modules. The native tilemap API includes orthogonal,
isometric, staggered isometric and pointy/flat hex layouts.

Use camera-aware picking, visible-area rendering, animated tiles, properties,
region queries and ground-depth sorting. Hex helpers provide coordinate
conversion, neighbours, distances, ranges and rings.

Start with the [tilemap guide](docs/tilemaps.md) or the asset-free
[hex-board example](examples/hex_board.bmx). Editor guides:
[Tiled](docs/tiled.md) and [LDtk](docs/ldtk.md).

## Optional modules

Import these when your application needs them. Their dependencies are separate
from the basic drawing API.

| Module | Adds |
| --- | --- |
| `Max2D.D3D11Effects` / `Max2D.D3D9Effects` | Built-in and packaged image effects for the native Windows renderers; D3D9 effects require shader 3.0. |
| `Max2D.ShaderEffects` | Shared shader-package assets, parameters and factories. Imported by `SDL3GPUEffects` and `GLEffects`; use a renderer provider to draw. |
| `Max2D.Atlas` | Batch atlas construction using `BRL.RectPacker`. Runtime atlas allocation is already in Core. |
| `Max2D.AtlasIO` | PNG/JSON atlas packages; uses `Image.PNG` and `Text.JSON`. |
| `Max2D.RichText` | Optional inline markup, named styles and registered font variants over the paragraph API. |
| `Max2D.ScalableFont` | Scalable, shaped text using `Text.HBFreeTypeFont`. |
| `Max2D.VirtualJoystick` | Safe-area-aware floating or fixed onscreen stick and action buttons for touch games. |
| `Max2D.TileMap` | Native editable tilemaps, rendering, picking and geometry queries. |
| `Max2D.Tiled` | Tiled XML/JSON maps, tilesets and templates; uses Text.XML, Text.JSON and Archive.ZLib. |
| `Max2D.TiledZstd` | Optional zstd decoding for Tiled maps; uses Archive.Zstd. |
| `Max2D.LDTK` | LDtk projects, levels, tiles, IntGrid, entities and backgrounds; uses Text.JSON. |

The virtual joystick renders at native window resolution, independently of the
game's virtual scene, and can use otherwise empty presentation bars. See the
[virtual joystick guide](docs/virtual-joystick.md) and
[example](examples/virtual_joystick.bmx).

## Moving from BRL.Max2D

The familiar drawing functions are retained, but `Max2D.Core` has its own image,
font, context and driver types. **Use one Max2D namespace in an application:** do
not import `BRL.Max2D` alongside it, including indirectly through helper modules.

Start by changing the framework import, then check any code that accesses
low-level image frames, implements a custom driver or assumes a particular
relationship between window coordinates and drawable pixels. Existing image
loaders can still provide `TPixmap` data.

See the [API compatibility guide](docs/brl-api-coverage.md) for supported calls and
intentional differences. The [ported SDK samples](docs/sample-compatibility.md)
show practical migration examples, including Oldskool2, viewport clipping,
snowfall and background image loading.

## Capabilities and limitations

Query the active context before relying on optional features:
`Max2DSupportsBlend`, `Max2DSupportsImageFlags`, `Max2DTextureDataSupport`,
`Max2DSupportsFullscreen` and `Max2DSupportsBorderlessFullscreen`.
Use `Max2DStats` to inspect rendering counters and diagnose batching, upload and
readback costs. See [capabilities and statistics](docs/rendering-diagnostics.md).

Some choices affect which backend or asset workflow you need:

- SDL3 Renderer does not support mipmaps. Its `MASKBLEND` support depends on the
  selected renderer and the available masking path; see [SDL3 masking](docs/sdl3-maskblend.md).
- Packed atlases do not support mipmaps or rotated packing.
- Scalable fonts do not provide automatic fallback, colour glyphs or vertical layout.
- Attaching graphics to an existing native widget is not supported.
- `Max2D.D3D7Max2D` remains disabled pending hardware validation; D3D9 is the
  supported Direct3D minimum.

Rendering belongs on the main rendering thread. Draw order is preserved, but
queued work may be flushed by target changes, uploads or readbacks. Images loaded
from CPU data can be used across contexts; render images belong to the context
that created them. Do not sample a render image while it is the active target.
See [resource and rendering rules](docs/drawing-guide.md#resource-and-rendering-contract).

The [backend capability matrix and validation notes](docs/stabilisation.md)
describe tested configurations and platform-specific limits.

## Examples and documentation

Build examples from your SDK directory, for example:

```sh
./bin/bmk makeapp -r -t gui mod/max2d.mod/examples/camera.bmx
```

| Example | Explore |
| --- | --- |
| [gl_hello.bmx](examples/gl_hello.bmx) | OpenGL drawing with virtual and native coordinates. |
| [sdl_gpu_hello.bmx](examples/sdl_gpu_hello.bmx) | The direct SDL GPU backend. |
| [camera.bmx](examples/camera.bmx) | A moving, rotating view and minimap. |
| [drawing_state.bmx](examples/drawing_state.bmx) | Nested transforms, clips and state restoration. |
| [presentation.bmx](examples/presentation.bmx) | Letterboxing, integer scaling and mouse mapping. |
| [paragraph.bmx](examples/paragraph.bmx) | Retained text layout. |
| [paragraph_bidi.bmx](examples/paragraph_bidi.bmx) | Mixed-direction text, scrolling and selection. |
| [atlas_animation.bmx](examples/atlas_animation.bmx) | Trimming and timed animation. |
| [hex_board.bmx](examples/hex_board.bmx) | An interactive hex grid without external assets. |
| [rendering_diagnostics.bmx](examples/rendering_diagnostics.bmx) | Capabilities and rendering statistics. |

Some examples require a font path, an asset directory or SDL3; see their source
headers and linked guides. Additional map viewers are provided in
[tiled.mod/examples](tiled.mod/examples) and [ldtk.mod/examples](ldtk.mod/examples).

For more detail, read the [drawing guide](docs/drawing-guide.md), browse
[topic guides](docs), or use the module's bbdoc API documentation. Maintainers can
find regression commands in [stabilisation](docs/stabilisation.md) and performance
measurements in [benchmarks](benchmarks/README.md).

## Licence

Max2D uses the [zlib/libpng licence](LICENSE). See [NOTICE.md](NOTICE.md) for
third-party code and example asset credits.

## MaxGUI canvases

On macOS, Windows and Linux/X11, `Max2D.SDL3RenderMax2D` and `Max2D.SDL3GPUMax2D` support drawing into MaxGUI canvases when you
also import `SDL3.SDL3MaxGUI`. MaxGUI keeps its native controls, input and event
loop. See the [SDL3 canvas guide](https://github.com/bmx-ng/sdl3.mod/blob/master/docs/maxgui.md)
and `sdl3.mod/sdl3maxgui.mod/examples/canvas.bmx` in your SDK. This requires
BRL.System 1.31. On Linux, launch with `GDK_BACKEND=x11`; XWayland is supported,
while native Wayland canvas attachment remains future work.

### Custom blending

Use `SetBlend(SUBTRACTBLEND)` to darken the destination by the source colour
multiplied by its alpha. Use `CreateBlendMode(...)` for custom colour and alpha
factors and operations; its return value works with the ordinary `SetBlend`,
`GetBlend` and drawing-state functions. Check `Max2DSupportsBlend` after opening
graphics, because available combinations depend on the backend and device.

See [Blending: recipes and backend support](docs/blending.md),
[the blend gallery](examples/custom_blending.bmx) and
[blending into a transparent image](examples/blend_render_image.bmx).

### Effects and group masks

Import the optional `Max2D.Effects` module to multiply an explicit render-image
layer by a soft alpha mask or group opacity. Check `Max2DSupportsLayerAlpha()`
and render-image support before use. Rectangular group clips already use
`IntersectViewport` inside a drawing-state scope and need no render image.
See [effects and masking](docs/effects-and-masking.md) and the
[runnable example](examples/layer_effects.bmx).

For native SDL GPU colour effects, import `Max2D.SDL3GPUEffects` and use
`CreateSaturationEffect` with `DrawImageEffect`. The shader preserves alpha and
accepts a cached masked layer. Each call submits one image, without an intermediate
surface. `DrawImageEffectBatch` batches repeated copies from a reusable x,y
positions array. See the [interactive saturation example](examples/image_effects.bmx).

`CreateBlurEffect` supplies a small single-axis blur for premultiplied render
images. Use horizontal and vertical passes with retained scratch/output images;
see the [two-pass blur example](examples/blur_effects.bmx) and the radius, padding
and storage details in [effects and masking](docs/effects-and-masking.md).

`ApplyLayerEffects` chains these effects across an explicit destination and one
reusable scratch image. It restores drawing state and each image's viewport;
see the [combined blur and colour example](examples/layer_effect_chain.bmx).

`CreateColorizeEffect` replaces source RGB while preserving alpha. Combine it
with blur for cached silhouettes, soft shadows and coloured glows; see the
[shadow/glow example](examples/colorize_effects.bmx).

`CreateScaledBlur` adds wider approximate blurs using retained half-size levels.
Its `Apply` method downsamples, blurs and enlarges while preserving drawing state.
See the [resolution comparison](examples/scaled_blur.bmx) and
[storage, quality and pass costs](docs/effects-and-masking.md#wider-blur-with-retained-reduction-levels).

`CreateOutlineEffect` builds a separate outer-border mask from a render layer's
alpha. Tint it directly or chain it with `CreateColorizeEffect`; see the
[interactive outline example](examples/outline_effects.bmx).

`CreateBrightPassEffect` extracts highlights above a luminance threshold. Feed
that layer into `CreateScaledBlur` and add the cached glow over the original
with `LIGHTBLEND`; see the [interactive bloom example](examples/bloom_effects.bmx).

`CreateToneMapEffect` maps floating-point HDR layers to display range with exposure,
per-channel Reinhard mapping and configurable gamma. The
[HDR bloom example](examples/hdr_bloom.bmx) compares clipped input, tone mapping,
and bloom accumulated before tone mapping.

The [colour-matrix example](examples/color_matrix.bmx) shows contrast, brightness
and sepia packages; add `-ud max2d_gl` to use OpenGL.

The [combined distortion example](examples/graded_distortion.bmx) demonstrates
waves and colour grading in one draw (also with `-ud max2d_gl`); see [shader packages](docs/shader-packages.md).

The [two-texture example](examples/two_texture_effects.bmx) shares a procedural
map between displacement and a dissolve with an optional HDR edge glow.

The [soft-mask example](examples/texture_masks.bmx) demonstrates reusable normal
and inverted texture masks, including a preview of the moving mask.

The [map-transform example](examples/texture_transforms.bmx) demonstrates
independent map scrolling, scale, rotation and a mouse-controlled soft mask.

The [shared-map comparison](examples/shared_texture_mapping.bmx) keeps one mask
aligned across independently rotating sprites.

The [threshold-mask comparison](examples/threshold_masks.bmx) demonstrates hard
and soft texture-driven reveals with adjustable transition width and inversion.

For the current implementation status, deliberate limits and validation gaps,
see the [effects checkpoint](docs/effects-and-masking.md#current-checkpoint-2026-11-20).
The [effects gallery](docs/effects-gallery.md) now has two pages: cached layer
composition and custom shader/map effects. Build it with `-ud max2d_gl` for the
complete OpenGL gallery.

OpenGL has an optional `Max2D.GLEffects` provider for saturation, colourize,
outlines, blur, bloom extraction, tone mapping, linear output and ABI 1–4 shader
packages. It supports
batches, layer chains, retained buffers, reusable bloom and cached soft/inner shadows. Build the blur,
scaled-blur, colourize, outline, layer-chain, bloom and HDR-bloom examples with
`-ud max2d_gl`. Float HDR rendering is supported; HDR window presentation remains
a separate SDL GPU feature. See the [OpenGL comparison](examples/gl_effects.bmx)
and [support details](docs/effects-and-masking.md#basic-opengl-image-effects).
