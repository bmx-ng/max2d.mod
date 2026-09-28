# Drawing guide

Practical details for drawing, input mapping, images, atlases and fonts. Start
with the [README](../README.md) for installation and backend selection.

## Capabilities and rendering statistics

Query blend modes, image flags, texture storage formats, texture limits and render-image support on the
active context. Capture or reset rendering counters to measure your drawing.
See the [developer guide](rendering-diagnostics.md) and
[example](../examples/rendering_diagnostics.bmx).

## Fixed virtual resolution and native text

`SetVirtualResolution(320,180,VIRTUAL_LETTERBOX)` preserves aspect ratio and
centres the scene. `Cls` paints unused output space with the virtual bar color
(black by default). The two-argument call retains stretching. Mapping is
recalculated at `Cls`, graphics selection and resize notifications.

`VIRTUAL_INTEGER` uses the largest whole-number scale that fits. When the output
is smaller than the virtual scene, it falls back to fractional fitting rather
than cropping. Use `SetVirtualBarColor(r,g,b)` to style the bars; the state stack
saves their color along with the view. Both modes work on render images as well
as the window. SDL viewport offsets stay in physical pixels at every scale.

`GraphicsResize` and `GraphicsPosition` request changes to the SDL window.
Native event notifications update the view without issuing another resize or
move request. Window managers may apply requests asynchronously.

```blitzmax
SetVirtualResolution(320,180,VIRTUAL_LETTERBOX)
Cls()
DrawImage(player,100,50)
PushMax2DState()
SetNativeResolution()
DrawText("Native-resolution overlay",16,16)
PopMax2DState()
```

Native coordinates are output pixels, including on high-DPI displays. The state
stack restores drawing state, font, target and viewport. Native mode covers the
whole output, including bars; it does not reset your origin or transform.
`VirtualToNative`, `NativeToVirtual` and `WindowToVirtual` expose coordinate
mapping. Mouse helpers account for window-to-output scaling and letterboxing;
positions in bars are intentionally outside the virtual scene.

Virtual resolution changes coordinates, not rasterization resolution. For an
intentionally pixelated scene, draw into a low-resolution render image, then
scale that image with nearest filtering before drawing native text. For crisp
scalable text, use `LoadScalableImageFont` (below): its raster resolution follows
the current output and drawing transform. Enlarging the built-in bitmap font
still enlarges its pixels. In native mode one logical unit is one output pixel;
it does not preserve the physical size of a window-coordinate UI automatically.

## Input and local hit testing

`GetVirtualMouse(x,y)` returns coordinates and a Boolean indicating whether the
pointer is inside the scene. It excludes letterbox bars and uses half-open
bounds (left/top included, right/bottom excluded). Coordinates outside the scene
remain available without clamping. Pass `True` as the third argument to also
respect `SetViewport` clipping. Clipping does not change the coordinate origin.
`VirtualMouseInside()` provides the same Boolean without output coordinates.
`WindowToVirtual` also returns this Boolean; existing callers can ignore it.

`VirtualToWindow` is the inverse conversion, useful for cursor placement.
Mouse speed conversion scales deltas without applying positional offsets.
Window-to-output pixel scaling is included for high-DPI displays. An unavailable
or zero-sized output produces an invalid mapping, False and zero coordinates.

`CaptureWindowInput()` retains the current window mapping. Capture once after
setting up your scene to reuse it for multiple hit tests or during a native
UI overlay. A snapshot does not track later resize/view changes: capture again
for the next frame. Window input always refers to the window view, even when a
render image is selected. Mapping a render image displayed somewhere in a scene
requires additionally reversing the transform used to draw that image.

For local hit testing, capture the transform at the same position and drawing
state as the draw call:

```blitzmax
Local mx:Float,my:Float,lx:Float,ly:Float
Local inside:Int=GetVirtualMouse(mx,my,True)
SetRotation(25)
SetHandle(40,20)
Local shape:TMax2DDrawTransform=CaptureDrawTransform(160,90)
Local hit:Int=inside And shape.VirtualToLocal(mx,my,lx,ly)
hit=hit And lx>=0 And ly>=0 And lx<80 And ly<40
DrawRect(160,90,80,40)
```

This accounts for origin, draw position, handle, rotation, scaling, reflection
and affine shear. `LocalToVirtual` provides the forward conversion. A collapsed
transform (zero determinant) cannot be inverted: it returns False and zero
coordinates. `CaptureImageTransform(image,x,y)` uses the image's own handle,
matching `DrawImage`; primitive/text handles are separate. Destination resizing
in `DrawImageRect` and subimage drawing needs an additional conversion if you
want coordinates in original source pixels. These are coordinate helpers, not
pixel-perfect collision or line-stroke hit tests.

## Cameras and scoped drawing state

`TCamera2D` adds world position, virtual offset, zoom and rotation above the
existing object transforms. Apply it with `SetCamera(camera)`; use
`SetCamera(Null)` for an untransformed overlay. `WorldToWindow`, `WindowToWorld`
and `GetWorldMouse` include the camera and existing DPI/letterbox mapping.
Manual Push/Pop preserves camera state; `ScopedMax2DState()` provides the same
restoration through `ICloseable` and a `Using` block.

See [camera semantics, input and scopes](cameras.md) and
`examples/camera.bmx` for a moving/rotating main view with a minimap.

## Owned texture data

`BRL.TextureData` provides a companion to `TPixmap` for explicit texture bytes,
row pitches and mip levels. Convert a pixmap without changing its format:

```blitzmax
Local data:TTextureData=TTextureData.FromPixmap(pixmap)
Local image:TImage=LoadImage(data,FILTEREDIMAGE)
Local editable:TPixmap=data.ToPixmap()
```

`LoadImage`, `LoadAnimImage` and `TImage.FromTextureData` accept this data. The
image path accepts `PF_RGBA8888`, `PF_A8`, `PF_RGBA16F`, `PF_RGBA32F`,
`PF_BC1_RGBA` or `PF_BC3_RGBA`
(subject to backend support), snapshots the bytes, and retains texture storage
independently of `TPixmap`. Views and drawing work normally. Uncompressed byte formats support
alpha collisions and read locks that return pixmap copies. Write locks,
`DYNAMICIMAGE` and pixel replacement are rejected. Use the existing pixmap path
when you need editable images or conversion from another format.

OpenGL and D3D11 accept **supplied mip chains**, including floating-point and
single-channel coverage levels. Multiple levels enable mip sampling automatically;
partial chains clamp sampling to their last supplied level. No levels are generated
or overwritten. Use `Max2DTextureDataSupport(data,flags)` to check the complete
request before loading. See [supplied mipmaps](texture-data.md) for an example
and alpha guidance. Native SDL GPU accepts supplied RGBA8888, A8, RGBA16F, RGBA32F, BC1 and BC3 chains,
and can also generate mipmaps automatically for RGBA8888/A8 and RGBA8 render images.
See its [mipmap example](../examples/sdl_gpu_mipmaps.bmx).
SDL3 Renderer and D3D9 currently reject supplied chains.

A single uncompressed byte-format level with `MIPMAPPEDIMAGE` still requests automatic generation
where supported. Floating-point textures currently have no pixmap read locks,
collision masks or automatic mipmap generation. OpenGL, D3D11 and native SDL GPU also support
[floating-point render images](float-render-images.md) on capable devices. Values
outside 0–1 survive sampling and colour modulation, but ordinary render targets
and windows still limit the final output range. BC1 and BC3 data stays compressed in GPU storage on supported OpenGL,
D3D11 and native SDL GPU devices. See [compressed textures](compressed-textures.md) for block
layout, capability checks and limitations. Import `Image.DDS` to enable direct
DDS file/stream loading while retaining compressed data and mip levels. Existing pixmap-based applications need no changes.
Use `data.ConvertToPixmap(options)` for explicit exposure, tone mapping and
linear/sRGB conversion into RGBA8. See the [conversion example](../examples/texture_conversion.bmx).
Existing `ToPixmap()` behavior is unchanged. See BRL.TextureData's README for
conversion policies, ownership, raw buffers and mip validation.

## Single-channel glyph coverage

The built-in font and `Max2D.ScalableFont` store glyph coverage in `PF_A8`
atlas pages: one byte per pixel instead of four. Drawing colour supplies the
RGB colour; the stored byte controls opacity. Coloured bitmap fonts retain
their colour atlas path.

You can also opt into coverage images and atlases:

```blitzmax
Local image:TImage=TImage.FromPixmap(pixels,FILTEREDIMAGE,PF_A8)
Local atlas:TTextureAtlas=TTextureAtlas.Create(512,FILTEREDIMAGE,1,PF_A8)
```

These calls discard input colour. Ordinary images and atlases still default to
`PF_RGBA8888`. Image locks expose the chosen CPU format, including locks on
trimmed images. Atlas padding, updates and alpha collision masks work with both.

OpenGL stores non-mipmapped coverage images in alpha-only textures. D3D11 uses
`R8_UNORM` when the device supports sampling that format. Their shaders supply
white RGB and use the stored channel as opacity. SDL3 Renderer and D3D9 expand the changed
region to RGBA for upload; their GPU textures remain four-channel. D3D11 also
falls back to RGBA if native coverage is unavailable. Automatically mipmapped
coverage images use RGBA storage in OpenGL and D3D11.
The native SDL GPU backend retains single-channel storage for ordinary and
automatically mipmapped coverage images. Render targets remain RGBA.

D3D11 keeps the original coverage pixels for device restoration, rechecks support
on a replacement device, and can switch between native and fallback storage.
Restoration may require uploading the entire retained source.

A 512 × 512 CPU coverage page holds 256 KiB of pixels, compared with 1 MiB for
RGBA. The native OpenGL and D3D11 paths also reduce texture payload and upload bytes;
the native SDL GPU path does too. This does not reduce glyph geometry, draw calls
or framebuffer blending work.

## Native atlases

A `TImage` is a view of shared image storage. Atlas regions work with ordinary
`DrawImage`, handles, transforms and image-region drawing. Consecutive draws from
the same page and blend mode batch together without changing painter's order.

```blitzmax
Local atlas:TTextureAtlas=TTextureAtlas.Create(1024,FILTEREDIMAGE)
Local player:TImage=atlas.AddPixmap(playerPixels,"player")
Local enemy:TImage=atlas.AddPixmap(enemyPixels,"enemy")
DrawImage(atlas.GetImage("player"),10,20)
```

The runtime allocator appends stable regions to pages without moving earlier
regions. Borders are extruded to prevent bilinear filtering across adjacent
sprites. New pixels update the existing texture; existing views retain their
coordinates. Oversized runtime entries receive their own page. There is no
individual deletion, eviction, rotation or mipmap support yet.
Use `atlas.UpdatePixmap(name,pixmap)` to replace a named region's content with
pixels of the same dimensions. Existing views and native textures remain valid.
For atlases created with `DYNAMICIMAGE`, ordinary write locks also work. Unlocking
any region or subview refreshes affected extruded borders and includes them in
the texture upload. A page must be unlocked before inserting or updating entries.
Queued draws retain their previous texture contents until the next upload.

Filtered `LoadAnimImage` cells are packed into padded pages automatically; the
nearest-filtered path can share the original sheet directly. Dynamic animation
edits refresh padding too. Repacking changes the internal coordinates and may
use multiple pages, without changing the public frame indices.

For batch construction, import `Max2D.Atlas`, create `TAtlasBuilder`, call
`Add(pixmap,name)` for each input, then `Build()`. It uses BRL.RectPacker, padding
and edge extrusion, allows multiple pages, and checks that every input was
placed. Inputs larger than the configured page size are rejected. This is also
used by the command-line atlas tool below. Rotation is disabled so views remain
ordinary rectangles.

### Trimming and animation

Trimming is opt-in: set `builder.trimTransparent=True` before `Build()`, or call
`atlas.AddPixmap(pixels,name,True)` for a runtime insertion. Image width, height,
handles and source rectangles stay in the original canvas coordinates. Drawing,
sub-images, cameras and collisions account for each frame's packed offset.
Fully transparent frames retain their logical size but draw no geometry.
Filtered entries retain a one-pixel transparent fringe before extrusion.

```blitzmax
Local builder:TAtlasBuilder=New TAtlasBuilder
builder.trimTransparent=True
builder.AddAnimation("walk",[firstPixels,secondPixels,thirdPixels],[100,100,250])
Local atlas:TTextureAtlas=builder.Build()
Local walk:TImage=atlas.GetImage("walk")
SetImageHandle(walk,ImageWidth(walk)/2,ImageHeight(walk)/2)
DrawImage(walk,100,100,walk.FrameAtTime(elapsedMilliseconds))
```

`AddAnimation` copies the pixels and timings. Frames must share a logical canvas;
packing may place them on different pages. Durations are positive milliseconds.
`TTextureAtlas.AddAnimation(name,frames,durations)` can also assemble existing
single-frame atlas images. Their dimensions, flags and handles must match.
`TImage.Animation` performs the same assembly without atlas membership checks.
Those lower-level methods accept zero timing to mean unspecified.

`image.frameDuration` holds the durations, `AnimationDuration()` returns their
sum as a `Long`, and `FrameAtTime(elapsed,loop=True)` selects a frame without
allocating. It clamps negative elapsed time to zero; with looping disabled it
holds the last frame. Timing helpers require every duration to be positive.
Nothing advances automatically, so pause, speed and playback clocks remain
under application control. Existing manual frame selection still works.

Read locks of trimmed images reconstruct the original canvas, with discarded
pixels transparent black. Write locks stage that canvas and apply it on unlock;
opaque pixels outside the retained footprint are rejected without changing the
atlas. The failed unlock releases the lock. Repack to enlarge the footprint.
`atlas.UpdatePixmap(name,pixels,frame=0)` follows the same rule. Untrimmed locks
remain direct pixel windows. Whole-page edits should preserve allocation bounds.

Trimming is for alpha-aware sprites. `SOLIDBLEND` and `SHADEBLEND` can use RGB even
where alpha is zero, so trimming is not appearance-preserving for those modes.
Discarded transparent RGB data is not retained. Atlases still do not support
mipmaps or rotated packing.

See `examples/atlas_animation.bmx`: the original and trimmed versions animate
side by side. Supply a **new directory** as its first argument to save and reload
the package before displaying it.

## Atlas asset workflow

Import `Max2D.AtlasIO` for `SaveTextureAtlas(atlas,directory)` and
`LoadTextureAtlas(directory)`. No graphics context is required to build or load
packages; textures are uploaded when images are drawn. IO dependencies stay out
of `Max2D.Core` and the renderer module.

Packages contain PNG pages and a versioned `atlas.json` manifest. Named regions,
original canvas sizes, trim offsets, animation frames and millisecond durations,
image handles, filtering flags and editable border metadata survive loading.
Saving requires a **new output directory**; existing assets are never silently
overwritten. See [the format specification](atlas-format.md) for validation,
pixel budgets, and current limitations.

Build the command-line tool from the BlitzMax installation directory:

```sh
./bin/bmk makeapp -r -o /tmp/atlas_builder mod/max2d.mod/tools/atlas_builder.bmx
/tmp/atlas_builder --size 1024 --padding 2 assets/packed player.png enemy.png
```

Inputs currently must be PNG. Names are filenames without extensions; duplicates
are rejected. `--nearest` disables texture filtering; `--trim` removes transparent
borders while keeping logical sprite dimensions. Page size defaults to 1024,
padding to 1, and filtering to linear. Packing may produce multiple pages.

```blitzmax
Import Max2D.AtlasIO
Local atlas:TTextureAtlas=LoadTextureAtlas("assets/packed")
DrawImage(atlas.GetImage("player"),100,100)
```

The package loader rejects malformed metadata, unsupported versions, overlapping
padding regions, and page dimensions inconsistent with the PNG headers. Runtime
insertions into loaded atlases start on a new page, preserving existing views.
`UpdatePixmap` and dynamic write locks retain their border-refresh behaviour.

## Native tilemaps

Create maps directly in code, generate terrain procedurally, or build your own
editor using the same APIs. External map tools are optional. Start with the
[hex-board guide](hex_board.md) and its
[asset-free example](../examples/hex_board.bmx) for a strategy-game foundation.

Import `Max2D.TileMap` for rectangular grids and pointy/flat hex grids with odd/even
staggering, plus standard and staggered isometric diamond grids. It provides
sparse editable layers, atlas-backed static and animated
tiles, flips, visible-area rendering and picking through the current camera and
coordinate transforms. Geometry queries also work without a graphics context.

Hex helpers include offset/axial/cube conversion, neighbours, distances, ranges
and rings. Artwork can extend beyond its cell; trimmed images retain alignment.
Optional ground-depth sorting interleaves movable sprites with scenery tiles
using their ground-contact points. The module does not import editor-format libraries.

Tilemaps also provide typed shared tile properties, sparse per-cell overrides and
reusable cell-range/polygon-region queries. See [tilemap properties and queries](tilemaps.md#tile-properties).

Tiles support independent display sizing with stretch or aspect-fit artwork.
Object layers can draw cached text with font mapping, wrapping, alignment and
local clipping. See [tile sizing and text](tile_sizing_text.md) and
`examples/tile_sizing_text.bmx`.

Import `Max2D.Tiled` to load TMX/TSX and TMJ/TSJ maps from paths, streams or mounted archives.
Add `Import Max2D.TiledZstd` for optional zstd-compressed maps.
See [Tiled loading](tiled.md) and `examples/tiled_viewer.bmx`.
For LDtk projects, import `Max2D.LDTK`; see the [LDtk guide](ldtk.md) and
[upstream example viewer](../ldtk.mod/examples/README.md).

See [tilemap APIs and semantics](tilemaps.md) and `examples/tilemap.bmx` for
an interactive world with layout switching, painting, selection and camera controls.

## Fonts

Fonts use the same atlas storage. Glyph images are cached by glyph index; layout
results contain occurrence-specific positions and advances. Measurement and
rendering use the same layout. `CreateTextLayout` exposes reusable layouts;
each font caches up to 128 recently used text strings. Hits refresh their place
in the cache. `font.SetLayoutCacheLimit(n)` changes the limit (zero disables it),
and `font.ClearLayoutCache()` frees cached layouts without invalidating layouts
held by the application or flushing the glyph atlas.

`DrawTextLayout(layout,x,y)` draws a retained layout with the current state.
`TextWidth` remains advance-based; `TextBounds` reports untransformed glyph bitmap
bounds, including negative bearings and overhangs. These are bitmap rectangle
bounds, not a scan of nontransparent pixels. Layouts expose floating-point
`width`/`height` and `boundsX`/`boundsY`/`boundsWidth`/`boundsHeight`.
Shaped output is iterated by its actual glyph count, rather than assuming one
glyph per input character.
A font loader supporting the requested shaping flags is required.

The initial runtime allocator favors stable placement over maximum packing
density. Font atlases grow as glyphs are used; there is no eviction or SDF/MSDF
renderer. Layout objects retain their glyph images. These internals deliberately
differ from BRL.Max2D's image-frame internals.

### Scalable fonts and DPI

```blitzmax
Import Max2D.ScalableFont
Local font:TScalableImageFont=LoadScalableImageFont("assets/NotoSans-Regular.ttf",18)
If Not font Then Throw "Could not load font"
SetImageFont(font)
DrawText("office AV x́",10,10)
```

The optional module depends on the existing `Text.HBFreeTypeFont` and
`BRL.FreeTypeFont` modules. It uses their native FreeType/HarfBuzz entry points
with its own shaping-to-layout and glyph-raster paths. Existing BRL modules are
not modified. Importing the dependency also registers its ordinary BRL font
loader; use **LoadScalableImageFont** to select the new implementation explicitly.
The result works with the familiar `SetImageFont`, `DrawText`, measurement and
retained-layout APIs. Built-in and legacy image fonts keep their existing
fixed-resolution behaviour.

Size is in logical units and may be fractional. Shaping and line metrics are
computed at that size, independently of graphics state. Glyphs are rasterized
again at the resolution required for drawing, including virtual-to-output
scaling, high-DPI output and transforms. Rotation with anisotropic scaling,
reflection and shear use the maximum magnification of the full transform.
Density rounds up to an integer and is capped at 8x by default. Logical text
width, height, positions and cached layout identity do not change with DPI.
`TextBounds` remains based on the logical-size glyph bitmaps; hinting at another
raster size can change actual pixel coverage slightly.

HarfBuzz glyph indices and fractional advances/offsets are retained, including
zero-advance combining marks. The raster path handles grayscale and monochrome
outlines with a transparent border. Load the actual bold/italic font face;
synthetic BOLDFONT/ITALICFONT styles are rejected. Rendering is antialiased.
Missing characters use the face's missing-glyph image; there is no font fallback.
OpenType defaults (including ordinary kerning/ligatures) remain active, with the
existing feature flags available to enable additional features.

Direct font layouts shape each line as one run with guessed direction/script.
Prepared paragraphs add wrapping, font/colour spans and optional interaction;
import `Text.SheenBidi` for mixed-direction/script runs. See the paragraph guide
below for optional providers and lazy caret geometry. Color glyphs and vertical
text are not supported. Font input can be
a filename, bank, or stream accepted by `LoadBank`; a private copy of the bytes
supports later raster-size creation without reopening the file. Outline fonts
are the intended input. No font files are bundled.

Cache controls:

- `font.SetLayoutCacheLimit(n)` and `ClearLayoutCache()` manage retained strings.
- `font.SetRasterCacheLimit(n)` retains at most n additional resolutions (default
  3), plus the 1x raster used for logical bounds. Eviction is least recently used.
- `font.SetMaxRasterDensity(n)` changes the resolution cap (1–16) and clears
  higher-resolution caches. Magnification beyond the cap enlarges those pixels.
- `font.ClearRasterCache()` drops higher-resolution caches.
- `font.ClearGlyphCache()` also clears the logical glyph and layout caches.
  Application-held layouts remain drawable and rebuild raster glyphs on demand.
- `RasterCacheCount()` and `RasterPageCount()` expose retained resolutions/pages.

These controls bound the number of raster resolutions, not total bytes. Glyph
atlases within a retained resolution grow as characters are used. Held layouts
retain their logical glyph images, so a cache clear cannot reclaim those until
the application releases the layouts. Native frame releases follow the usual
render-thread queue; garbage collection reclaims CPU storage and font faces.

## Resource and rendering contract

- CPU images own their pixels; each rendering context caches its own texture.
- Write locks require `DYNAMICIMAGE`; unlock marks changed pixels. Updates flush
  prior draws and reuse texture resources. Drawing a write-locked image fails.
- Render images belong to one context. Sampling the active target is rejected.
- Native destruction happens on the rendering thread when the context drains
  pending releases or closes, not inside image finalizers. Rendering APIs are
  for the main rendering thread.
- Draw order is preserved. Geometry is batched across adjacent compatible draws;
  target changes, uploads and readbacks flush pending work.
- CPU pixmaps contain straight alpha. Render targets contain premultiplied alpha;
  compositing and readback convert appropriately. SDL SOLID/SHADE operations can
  require cached alternate representations, including GPU readback for targets.
  The OpenGL backend performs these conversions in its fragment shader.
- `GrabPixmap` reads physical pixels of the current target independently of its
  drawing viewport. `DrawPixmap` uses the same physical pixel coordinates at
  1:1 scale, ignoring clipping, tint, transform and virtual presentation while
  preserving drawing state and reusing its upload texture.
- `Max2DStats` counts core frame creation, updates, uploaded pixels, submissions,
  vertices, requested readbacks and mipmap generations. It does not count backend
  conversion caches, masking helper textures or GPU-generated mip pixels.
- `ALPHABLEND` is the initial default. SOLID, ALPHA, LIGHT and SHADE are supported.
  OpenGL, native SDL GPU, D3D9 and D3D11 support `MASKBLEND` and `MIPMAPPEDIMAGE` (Direct3D mipmaps are
  capability checked). SDL Renderer
  supports `MASKBLEND` with the GPU/Metal shader path, depending on the active
  context, and rejects mipmaps. See [SDL3 masking](sdl3-maskblend.md). Color-key loading is separate from alpha-test blending.

## Image collisions

`ImagesCollide`, `ImagesCollide2`, `CollideImage`, `CollideRect`, `ResetCollisions`
and all 32 `COLLISION_LAYER_*` constants are implemented in the shared core.
Packed alpha masks support atlas views, animation and affine transforms; CPU
image edits invalidate the cache. Layer entries retain their insertion snapshot.
Render images require an explicit `CreateCollisionImage` snapshot, avoiding
hidden GPU readback. Pairwise calls preserve layer 32.

See [collision semantics and examples](collisions.md), including the
pixel-centre rule, alpha threshold, renderer edge differences and layer lifetime.
Try `examples/collisions.bmx` for a rotating ring with pixel-mask mouse collisions.

## Mipmaps

OpenGL, native SDL GPU and capable D3D9/D3D11 devices support `FILTEREDIMAGE|MIPMAPPEDIMAGE` for trilinear minification, including
editable images and render targets. Chains regenerate lazily after changes;
`Max2DStats().mipmapGenerations` counts generation requests. Mipmapped
animation frames have independent textures; packed atlases remain unsupported.
SDL3 Renderer continues to reject the mipmap flag.

See [mipmap behaviour and limitations](mipmaps.md) and try
`examples/mipmaps.bmx` for an OpenGL minification comparison.
For Windows D3D9, see [D3D9 mipmaps](d3d9.md#mipmaps) and
`examples/d3d9_mipmaps.bmx`. For D3D11, see [D3D11 mipmaps](d3d11.md#mipmaps)
and `examples/d3d11_mipmaps.bmx`. Native SDL GPU has the equivalent
[comparison example](../examples/sdl_gpu_mipmaps.bmx).

## Runtime fullscreen switching

The backends expose `SetFullscreen`, `SetBorderlessFullscreen`, `GetWindowMode`,
`Max2DSupportsFullscreen` and `Max2DSupportsBorderlessFullscreen` through Max2D.Core.
See [window modes](window-modes.md) for semantics, support and examples.

## Nested drawing state

Parent coordinate transforms and intersecting viewport clips support reusable
drawing routines with manual or scoped restoration. See [drawing state](drawing-state.md)
and [the example](../examples/drawing_state.bmx).

## Paragraph text

Prepare reusable text, wrap it to a width and draw retained lines with left,
centre or right alignment. See [text layout](text-layout.md) and the
[interactive paragraph example](../examples/paragraph.bmx) for caching and scope.

`Text.Unibreak` optionally supplies Unicode boundaries; `Text.SheenBidi`
optionally supplies bidirectional analysis. Without the bidi provider, no native
bidi library is linked and no bidi maps are built. `ETextDirection.Disabled`
also bypasses it per paragraph. See [the bidi interaction example](../examples/paragraph_bidi.bmx)
for mixed Arabic, Hebrew and Latin text, styled fonts, scrolling and selection.

Map objects and collision-shape queries are described in
[the object geometry guide](tile_objects.md). The Tiled example viewer
includes the upstream Orthogonal Outside map with object inspection.
