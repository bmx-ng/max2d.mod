# Using Tiled maps

Use `Max2D.Tiled` to load maps made in [Tiled](https://www.mapeditor.org/)
and draw them with any Max2D backend. It reads XML (`.tmx`, `.tsx`) and JSON
(`.tmj`, `.tsj`, `.json`). Loaded maps use the ordinary `TTileMap` API, so you
can edit cells, pick tiles, read properties and query collision shapes in your game.

## Load and draw a map

Save a map as `maps/level.tmj` beside your executable, with its tilesets and images
at the relative paths saved by Tiled. This is a complete application:

```blitzmax
SuperStrict
Framework Max2D.SDL3RenderMax2D
Import Max2D.Tiled

Graphics 960, 640
SetVirtualResolution(960, 640, VIRTUAL_LETTERBOX)

Local map:TTileMap = LoadTileMap(AppDir + "/maps/level.tmj")
Local started:Int = MilliSecs()

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls()
	map.Draw(0, 0, Long(MilliSecs() - started))
	Flip()
Wend
EndGraphics()
```

Load the map once, before the drawing loop. The third `Draw` argument is elapsed
animation time in milliseconds. Omit it to draw animations at time zero.
Change the `Framework` line to select another backend.

`Draw` uses the current camera, viewport, render target, colour and blend state,
and restores the caller's drawing state afterwards. The map's background colour
is metadata: set your own clear colour with `SetClsColor`.

For a ready-made viewer with maps and artwork, build
[tiled_examples.bmx](../tiled.mod/examples/tiled_examples.bmx). See the
[example instructions](../tiled.mod/examples/README.md) for controls and asset licences.

## Choose the loader you need

| Entry point | Use it when |
| --- | --- |
| `LoadTileMap(source, flags, sourcePath)` | You want a native map and automatic format selection. |
| `LoadTiledMap(source, flags, sourcePath, project, fontResolver)` | You need Tiled metadata, project defaults or a text font resolver. |
| `project.LoadMap(source, flags, sourcePath, fontResolver)` | Several maps share a loaded `.tiled-project`. |

Optional arguments default to `FILTEREDIMAGE`, an empty source path, and Null
project/font resolver. Pass `0` for unfiltered pixel artwork. Atlas packing does
not support mipmap image flags. PNG loading is included; import other image
decoders if your tilesets use other formats.

`LoadTiledMap` returns `TTiledMap`, which extends `TTileMap`. You can also cast
the result of `LoadTileMap` when you know the source is Tiled.

### Project defaults and text fonts

Use a project when your maps rely on custom class defaults or enum declarations:

```blitzmax
Local project:TTiledProject = TTiledProject.Load("maps/game.tiled-project")
Local map:TTiledMap = project.LoadMap("maps/level.tmj")
```

Projects are never discovered automatically. See [project properties](tiled_projects.md)
for defaults, overrides and JSON member types.

Text objects draw with a scaled bitmap font unless you supply a `TTiledFontResolver`.
For production text, map Tiled's font requests to fonts shipped with your game;
see [text objects and fonts](tile_sizing_text.md#tiled-font-mapping).

### Optional zstd compression

Add this import if you export zstd-compressed layers:

```blitzmax
Import Max2D.TiledZstd
```

It imports `Max2D.Tiled` and registers a decoder using `Archive.Zstd`.
Without it, a zstd map fails to load with an error naming the missing module.
The base Tiled module does not add a zstd dependency. Uncompressed, zlib and gzip
layer data work with `Max2D.Tiled` alone.

## Streams and packaged assets

All loading entry points accept a filename, stream URL or caller-owned `TStream`.
When passing a stream, supply its logical filename so relative tileset, template
and image references can be resolved:

```blitzmax
Using
	Local stream:TStream = ReadStream("maps/level.tmx")
Do
	Local map:TTileMap = LoadTileMap(stream, FILTEREDIMAGE, "maps/level.tmx")
End Using
```

`LoadTileMap` also uses the filename extension to select a provider.
`LoadTiledMap` detects XML/JSON content directly; without a path hint it resolves
relative references from the current directory. Streams are read from their
current position without seeking. Caller-owned streams stay open even if loading
fails; streams opened by the loader are closed automatically.

To read maps and all their dependencies from a ZIP, mount it through `BRL.IO`:

```blitzmax
Import BRL.IO
Import Max2D.Tiled

MaxIO.Init()
MaxIO.Mount("game-assets.zip")
Local map:TTileMap = LoadTileMap("maps/level.tmx")
```

Your application manages mounting and IO shutdown. Images load eagerly, so the
archive can be unmounted after loading. `incbin::` URLs also work; import
`BRL.RamStream` and embed the map's dependencies as well as the map itself.

Keep relative paths intact when packaging assets. File properties resolve beside
the document that supplied them: a TSX property is relative to its TSX, a template
default to its template, and a project default to its project. File properties
are resolved strings; the loader does not open those files for you.

## Find layers, tiles and gameplay data

Tiled groups become a flat list of native layers in drawing order. Their offsets,
visibility, opacity, tint and parallax are applied to their children. An object
layer or image layer is also present in `map.layers`; do not assume every layer
contains cells.

Use `TTiledMap.importedLayers` to find a layer by name or source kind:

```blitzmax
Local map:TTiledMap = LoadTiledMap("maps/level.tmj")
Local ground:TTileLayer
For Local info:TTiledLayerInfo = EachIn map.importedLayers
	If info.kind = "layer" And info.name = "Ground" Then
		ground = info.layer
		Exit
	End If
Next
```

Groups have a Null `info.layer`. Their `parent` links and properties remain
available in the metadata; group properties are not inherited by children.

Native tile IDs differ from Tiled global IDs. Read `layer.Cell(column,row)` to
get a native ID, or use `map.importedTilesets[index].NativeID(localID)` to resolve
a tileset-local ID. Zero means empty or missing. Use
`layer.Property(column,row,name)` to read cell overrides with shared tile defaults.
See [properties and cell queries](tilemaps.md#tile-properties).

Objects retain names, classes, IDs and properties. Use `map.ObjectByID(id)` to
resolve object-reference properties after loading. Shapes supply geometry for
your triggers, picking and collision handling; they do not run gameplay logic or
provide collision response. See [objects and collision queries](tile_objects.md)
and [templates and structured properties](tiled_templates.md).

Other useful metadata on `TTiledMap` includes `width`, `height`, `infinite`,
`orientation`, `className`, `backgroundColor` and `sourcePath`. Each imported
tileset retains its name, source path, first GID, properties and tile classes.

## Mouse picking and map coordinates

Call `map.MouseCell(column,row,0,0,layer)` while the same camera and transforms
used for drawing are active. Pass the layer so its offset and parallax are included.
If you draw at a nonzero map position, pass that same x/y to `MouseCell`.

```blitzmax
Local column:Int, row:Int
If ground And map.MouseCell(column, row, 0, 0, ground) Then
	Local tileID:Int = ground.Cell(column, row)
	' tileID = 0 means the mouse is over an empty cell.
End If
```

Picking uses cell geometry, not the opaque pixels of oversized artwork. It also
accounts for virtual resolution and rejects the letterbox bars.

Tiled's standard-isometric origin is already included in imported layer offsets.
Do not add a second correction when drawing or querying the map.

## Image layers, tint and parallax

These features live in `Max2D.TileMap` and can also be configured directly:

```blitzmax
Local backdrop:TTileLayer = map.AddLayer("Background")
backdrop.image = LoadImage("sky.png")
backdrop.repeatX = True
backdrop.parallaxX = 0.5
backdrop.tintRed = 0.8
```

`image` draws at the layer origin, ignoring image handles; `repeatX` and `repeatY`
repeat it across the visible region. Images use the loader's requested image flags
and retain their natural dimensions. Native mixed layers draw the image first,
then cells/sprites, then tile and text objects. `drawnImages` reports image copies submitted.
Only copies intersecting the inverse-transformed viewport bounds are submitted;
the normal viewport clips them. A limit of 1,048,576 copies per layer prevents
unbounded work at extreme zoom levels. Empty image layers are accepted.

`tintRed`, `tintGreen`, `tintBlue` and `tintAlpha` are multipliers in 0..1. Tint
multiplies the caller's drawing colour/alpha and layer opacity, affecting cells,
sprites, tile objects, text objects and images. Nested Tiled group tints multiply together.
The caller's drawing state is restored after drawing.

`parallaxX/Y` default to 1. A factor of 0 keeps the layer stationary during camera
translation; 0.5 scrolls at half speed, and negative factors reverse direction.
Group factors multiply. `map.parallaxOriginX/Y` defines the reference point.
Matching Tiled, the offset is `(viewportCentreInMap - parallaxOrigin) * (1-factor)`.
The inverse full drawing transform supplies the viewport centre, so this also
works with cameras, map translation, zoom, rotation and render-image viewports.
Zoom and rotation still affect stationary layers; factor 0 is not a screen UI mode.

`Pick`/`MouseCell` account for the displayed layer's parallax. For object picking,
convert the mouse to layer coordinates and then to nominal map coordinates:

```blitzmax
Local vx:Float, vy:Float, lx:Float, ly:Float
If GetVirtualMouse(vx, vy, True) And map.VirtualToLayer(layer, vx, vy, lx, ly) Then
	layer.QueryObjectsAtPoint(lx + layer.offsetX, ly + layer.offsetY, 0, hits)
End If
```

`VirtualToLayer` and `LayerDrawOffset` accept the same optional map x/y as `Draw`.
For debug outlines, use the latter's visual offset instead of the nominal layer
offset. Physics/region queries remain independent of camera and parallax and use
nominal map coordinates. The example viewer demonstrates both conversions.

## Supported map features

| Area | Supported |
| --- | --- |
| Layouts | Orthogonal, isometric, staggered-isometric and hexagonal; both stagger axes and odd/even layouts |
| Storage | Finite maps and infinite chunks, including negative coordinates |
| Tilesets | Inline/external tilesets, sheets, image collections, sparse IDs, margins, spacing, colour keys and image subrectangles |
| Drawing | Four orthogonal drawing orders, flips, diagonal transformations, hex rotations, offsets, animation and tile sizing |
| Layers | Tile, image, object and nested group layers; visibility, opacity, tint, parallax and repeating images |
| Objects | Points, rectangles, ellipses, polygons, polylines, tile objects, text and external templates |
| Properties | Scalars, object/file references, nested class values and optional project class/enum definitions |
| Tile data | XML tile lists, CSV, JSON arrays and base64; zlib/gzip and optional zstd |

See [tile sizing and text](tile_sizing_text.md) for stretch/aspect-fit artwork and
text formatting. Non-square diagonal flips preserve the original bottom-left
anchor, so a flipped tile may extend above its original drawing rectangle.

## JSON documents

XML and JSON maps, tilesets and templates can reference each other. Current
array-based tiles and properties are supported; older dictionary-based encodings
are not. Integer properties retain signed 64-bit values, and tile IDs retain
all transformation bits.

Supply a [project schema](tiled_projects.md) if you need types/defaults for nested
JSON class members. Without one, nested values use their JSON types: file paths
are plain strings, object references are plain integers, and nested class names
are unavailable. Explicit top-level file and object properties work normally.

## Rectangular tile draw order

The loader preserves `right-down`, `right-up`, `left-down` and `left-up` on each
native layer. Change `layer.renderOrder` after loading if needed. This applies to
rectangular layers with Grid sorting; GroundDepth sorting takes precedence.
See the [native draw-order guide](tilemaps.md#rectangular-tile-draw-order).

## Limitations and loading errors

Loading throws an error with source-path context for malformed data, missing
resources and known unsupported runtime features. Compressed output must match
the declared cell count exactly; corrupt input and trailing garbage are rejected.

The following need special attention when authoring maps:

- **Layer blend modes:** only normal blending is supported.
- **Collision grids:** isometric tileset collision grids are unsupported. Ordinary
  isometric map objects work. Tile/text objects cannot be collision shapes.
- **Animation:** frames in one animation must share source dimensions. Collision
  shapes belong to the animated tile and do not change with each frame.
- **Tilesets:** a single tileset cannot mix a sheet with per-tile images.
- **Legacy files:** nonzero legacy group/object-layer x/y coordinates and old JSON
  dictionary encodings are unsupported. Use current Tiled exports.
- **Text:** fonts and line breaks may differ from Tiled/Qt; supply matching fonts
  when appearance matters.
- **Editor data:** Wang sets, selection data and other editor-only information
  are ignored. Project scripts and editor commands are not executed.

One import is limited to 16,777,216 cells, 65,536 tile definitions and 64 nested
groups. Native coordinate/image limits also apply. Object, template, text and
project-specific limits are documented in their linked guides.

## More examples and reference

- [Bundled Tiled maps and viewer](../tiled.mod/examples/README.md)
- [Native grids, cameras, properties and region queries](tilemaps.md)
- [Objects and collision geometry](tile_objects.md)
- [Templates and structured properties](tiled_templates.md)
- [Project defaults and enums](tiled_projects.md)
- [Tile sizing and text](tile_sizing_text.md)
- [Maintainer checks and codec extensions](../tests/README.md)

Format reference: [TMX](https://doc.mapeditor.org/en/stable/reference/tmx-map-format/)
and [JSON](https://doc.mapeditor.org/en/stable/reference/json-map-format/).
