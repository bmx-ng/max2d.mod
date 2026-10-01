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
| `Max2D.Atlas` | Batch atlas construction using `BRL.RectPacker`. Runtime atlas allocation is already in Core. |
| `Max2D.AtlasIO` | PNG/JSON atlas packages; uses `Image.PNG` and `Text.JSON`. |
| `Max2D.RichText` | Optional inline markup, named styles and registered font variants over the paragraph API. |
| `Max2D.ScalableFont` | Scalable, shaped text using `Text.HBFreeTypeFont`. |
| `Max2D.TileMap` | Native editable tilemaps, rendering, picking and geometry queries. |
| `Max2D.Tiled` | Tiled XML/JSON maps, tilesets and templates; uses Text.XML, Text.JSON and Archive.ZLib. |
| `Max2D.TiledZstd` | Optional zstd decoding for Tiled maps; uses Archive.Zstd. |
| `Max2D.LDTK` | LDtk projects, levels, tiles, IntGrid, entities and backgrounds; uses Text.JSON. |

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

On macOS, `Max2D.SDL3RenderMax2D` and `Max2D.SDL3GPUMax2D` support drawing into MaxGUI canvases when you
also import `SDL3.SDL3MaxGUI`. MaxGUI keeps its native controls, input and event
loop. See the [SDL3 canvas guide](https://github.com/bmx-ng/sdl3.mod/blob/master/docs/maxgui.md)
and `sdl3.mod/sdl3maxgui.mod/examples/canvas.bmx` in your SDK. This requires
BRL.System 1.31; Windows and Linux attachment support remain future work.
