# Using LDtk levels

Import `Max2D.LDTK` to load [LDtk](https://ldtk.io/) projects with a Max2D backend.
The module reads `.ldtk` projects directly; exporting a Tiled map is not required.
It does not import `Max2D.Tiled` or its XML/compression dependencies.

## Load a level

For a project containing one level:

```blitzmax
SuperStrict
Framework Max2D.SDL3RenderMax2D
Import Max2D.LDTK

Graphics 960, 640
Local map:TLDTKMap = LoadLDTKMap(AppDir + "/maps/game.ldtk")
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls()
	map.Draw()
	Flip()
Wend
EndGraphics()
```

`LoadTileMap("game.ldtk")` also works because the import registers the `.ldtk`
format. Files named `.json` require `LoadLDTKMap` or `TLDTKProject.Load`; the generic
loader does not claim every JSON file.

For multiple levels, load the project and choose a level by identifier or IID:

```blitzmax
Local project:TLDTKProject = TLDTKProject.Load("maps/game.ldtk")
For Local level:TLDTKLevelInfo = EachIn project.levels
	Print level.identifier + " / " + level.iid
Next
Local map:TLDTKMap = project.LoadLevel("Dungeon_Entrance", 0)
```

Omitting the selector on a multi-level project throws an error. If different worlds
contain levels with the same identifier, select by IID. Both the traditional root
`levels` array and multi-world projects are supported. `.ldtkl` files saved separately
are read through their owning project, which supplies tileset and layer definitions.

`TLDTKProject.Load` parses metadata; `LoadLevel` loads the chosen level and its images.
Each call creates a new native map. Retain loaded maps you want to revisit, or keep
the project and load them on demand. Flags default to `FILTEREDIMAGE`; pass `0`
for unfiltered pixel artwork. PNG is included; import other image decoders as needed.

`map.level` provides `identifier`, `iid`, `worldIID`, `uid`, pixel `width`/`height`,
`worldX`, `worldY` and `worldDepth`. World positions are metadata, not automatic draw
offsets: draw a single level at `(0,0)`, or place levels yourself using `Draw(x,y)`.
LDtk uses sentinel positions for some linear world layouts. `backgroundColor` is
also metadata; your application chooses its clear colour.

## Level neighbours and explicit loading

`project.Level("name-or-IID")` looks up metadata without reading an external level
or loading images. Unknown selectors return Null; ambiguous names throw. For IDs
from exported references, use `project.LevelByIID(iid)` to avoid interpreting an
unknown IID as a name.

Each `TLDTKLevelInfo.neighbours` entry contains `direction` and `levelIID`:

```blitzmax
Local room:TLDTKLevelInfo = project.Level("Entrance")
For Local neighbour:TLDTKNeighbour = EachIn room.neighbours
	Local nextRoom:TLDTKLevelInfo = neighbour.Level(project)
	If neighbour.direction = "e" And nextRoom Then
		' Offer an east exit, or load nextRoom.iid when the player reaches it.
	End If
Next
```

Entries preserve the exported order. Several neighbours may share a direction.
Codes include `n/s/e/w`, `nw/ne/sw/se`, `o` for overlap at the same depth, and
`<`/`>` for lower/higher depth. Unknown future codes are retained. These are LDtk's
exported relationships, not an inferred navigation graph or a guarantee that a
player can travel between rooms. Missing target metadata returns Null. The importer
does not open neighbouring levels automatically.

## Layers and tile artwork

```blitzmax
Local terrain:TLDTKLayer = map.Layer("Terrain")
If terrain Then terrain.layer.visible = False
```

`map.Layer` accepts a layer identifier or IID and returns Null when missing.
`importedLayers` lists the imported layers in **bottom-to-top drawing order**.
Each has a native `layer:TTileLayer`, its own `grid:TTileGrid`, grid `width`/`height`,
`kind`, `identifier` and `iid`. Different layer grid sizes are supported.

Regular tile layers and exported auto-layer tiles retain their source rectangles,
pixel positions, horizontal/vertical flips, opacity and stacking order. Automatic
tile rules are not executed at runtime: save your project in LDtk to update their
exported results.

Artwork is stored as ordered **native tile objects** in `layer.objects`. This
preserves overlapping tiles and positions between grid cells. Consequently:

- `layer.Cell()` and cell-region queries do not return imported LDtk artwork.
- Use object queries for artwork rectangles, or IntGrid for gameplay cells.
- `object.tile` indexes the shared native tileset, not LDtk's source tile IDs.
- Layer visibility, opacity and offsets apply normally. Each tile's `opacity`
  multiplies the layer and caller alpha.
- Cameras, virtual resolution, render targets and native object queries work as
  they do for other `TTileMap` objects.

The object renderer scans the layer's objects. This initial importer does not
provide chunk streaming or a spatial index for large LDtk worlds. Load the levels
you need rather than loading an entire world merely to display one room.

## Background images and parallax

Level backgrounds in `Unscaled`, `Contain`, `Cover` and `CoverDirty` modes are
loaded from the project-relative image path and drawn before the layers. The
exported `__bgPos` crop, scale and position are used directly, including fractional
source coordinates. `Repeat` tiles the cropped image inside the level rectangle,
aligned by `bgPivotX/Y`. Partial tiles at the edges are cropped. Only repeats
intersecting the current view are submitted, including under a camera or transform.

`map.background` is Null when there is no background image. Otherwise it provides
`image`, `visible`, the destination `x/y/width/height` and the source rectangle
`sourceX/sourceY/sourceWidth/sourceHeight`. For repeating backgrounds, `width/height`
are one repeat’s displayed size; `repeat` and `pivotX/Y` control its pattern inside
`map.level.width/height`. Set `visible=False` if your game draws
its own backdrop. Backgrounds follow the caller's drawing state, camera and render
target. They are decorative and do not appear in object or cell queries.

LDtk parallax is applied to imported layers, including its optional automatic
scaling. LDtk's zero parallax factor means ordinary camera movement; the native
`layer.parallaxX/Y` values are `1 - exportedFactor`. When `parallaxScaling` is
true, the uniform `layer.drawScale` is `Max(0.01, 1 - exportedFactorX)`, matching
LDtk (the horizontal factor determines scale for both axes). Without automatic
scaling, scrolling is anchored at the centre of the layer's grid bounds.

`MouseCell`, `Pick` and `VirtualToLayer` undo both the visual offset and scale.
The layer grid, IntGrid and entity rectangles remain in their original coordinates;
physics and region queries do not change when the camera moves. For your own
overlays, get `map.LayerDrawOffset(layer, x, y)` and draw a local point at
`(x + localX * layer.drawScale, y + localY * layer.drawScale)` under the same camera.
Pass matching map position arguments if you use `map.Draw(x,y)`.

The LDtk importer uses LDtk's layer-relative anchoring; `map.parallaxOriginX/Y`
is used by ordinary native/Tiled layers, not imported LDtk layers.

## IntGrid and mouse selection

IntGrid is retained as gameplay data; it does not draw coloured editor cells or
create collision shapes automatically. Auto-generated tiles on the same layer
are drawn normally.

```blitzmax
Local collision:TLDTKLayer = map.Layer("Collision")
Local column:Int, row:Int
If collision And map.MouseCell(column, row, 0, 0, collision.layer) Then
	Local value:Int = collision.IntValue(column, row)
	' Your game decides which values block movement, cause damage, etc.
End If
```

`IntValue` returns zero outside the layer, for an empty cell, or when the layer has
no IntGrid data. `intGrid` is the row-major array; `intGridDefinitions` retains
LDtk's JSON value definitions, including optional identifiers and colours.
Definitions are not necessarily ordered by their numeric value.

Pass the layer to `MouseCell` or `Pick` so the map uses that layer's grid size and
offset. Without a layer it uses the project's default grid size. Keep the same
camera and map x/y active for picking and drawing. `TLDTKLayer.grid` provides
coordinate conversion, neighbours and geometry helpers for that layer.

For object point queries, use `map.VirtualToLayer` and add the native layer offset
before calling `layer.QueryObjectsAtPoint`, as described in the
[native object guide](tile_objects.md).

## Entities and fields

Entities become native rectangles using their exported dimensions, pivot and
layer offset. Their exported `__tile`, when present, supplies the artwork; this
also handles images chosen through entity fields. Artwork is drawn in exported
entity order and follows object/layer visibility, opacity, tint and transforms.
LDtk's `tileOpacity` multiplies the caller, layer and object alpha.

`entity.artwork` references the same `TLDTKEntityArtwork` as `entity.object.artwork`.
Its sizing does **not** change the entity rectangle used by native queries:

| LDtk mode | Display behaviour |
| --- | --- |
| `Stretch` | Fill the entity rectangle, scaling each axis independently |
| `FitInside` | Fit proportionally, aligned at the entity pivot |
| `Cover` | Fill proportionally and crop around the pivot |
| `FullSizeCropped` | Keep source size and crop to the entity bounds at the pivot |
| `FullSizeUncropped` | Keep source size; artwork can extend beyond gameplay bounds |
| `Repeat` | Repeat from the entity rectangle's top-left, cropping partial edge tiles |
| `NineSlice` | Preserve corners; repeat edges and centre using top/right/bottom/left borders |

Nine-slice borders must leave a positive source centre, and the entity must be at
least as large as the opposing border sums. Invalid layouts throw an error.
Zero-width borders are supported.

To replace editor artwork with your own game visuals:

```blitzmax
Local spawn:TLDTKEntity = map.Entity("your-entity-iid")
If spawn And spawn.artwork Then spawn.artwork.visible = False
```

This leaves the native object visible and queryable. Moving/resizing
`entity.object` moves/resizes its artwork on the next draw. The initial imported
object x/y already account for the entity pivot. When changing dimensions yourself,
adjust x/y too if you want its pivot to stay at the same world position.

To skip artwork loading entirely, use `project.LoadLevel("LevelName", flags, False)`
or `LoadLDTKMap(source, "LevelName", flags, sourcePath, False)`. Entity metadata and
query rectangles are still loaded, while entity image resources are not requested.
Tile layers and level backgrounds load normally.

### Built-in editor icons

An LDtk project can name an embedded atlas such as `LdtkIcons` without containing
its pixels. Max2D does not bundle that atlas. Supply the corresponding image before
loading a level, using the usual file/stream APIs:

```blitzmax
Local project:TLDTKProject = TLDTKProject.Load("maps/game.ldtk")
project.SetEmbeddedAtlas("LdtkIcons", LoadPixmap("art/my-ldtk-icons.png"))
Local map:TLDTKMap = project.LoadLevel("Dungeon_Entrance", 0)
```

The pixels must have the same layout as the exported source rectangles. This also
works for tile layers that reference the supplied atlas. An unresolved atlas or
missing external image produces a load error. Use metadata-only entity loading
when the icons are just editor markers and your game supplies its own visuals.

### Entity data

```blitzmax
For Local entity:TLDTKEntity = EachIn map.entities
	If entity.identifier <> "PlayerStart" Then Continue
	Local shape:TTileObject = entity.object
	Local bounds:STileObjectInstance = shape.Instance(entity.layer.layer.offsetX, entity.layer.layer.offsetY)
	' bounds describes the entity rectangle in map-local coordinates.
Next
```

`map.Entity(iid)` looks up an entity in the loaded level. `object.id` is a local
synthetic ID; use the LDtk IID for persistent references. Level/entity fields have
two representations:

| Access | Contents |
| --- | --- |
| `map.properties` / `entity.object.properties` | Scalar strings, numbers and booleans; `FilePath` values resolved relative to the project |
| `map.fields` / `entity.fields` | Every exported field, including arrays, null, points, tile references and entity references |

Each `TLDTKField` exposes `name`, `valueType` and `value:TJSON`. The JSON value is
preserved as exported; an entity reference remains structured reference metadata,
not a live game object. Resolve it against explicitly registered loaded maps as
shown below. Null or structured fields are absent from the scalar property bag.

The project, level and entity `data` objects expose their source JSON for settings
not yet given convenience APIs. Treat these objects and field JSON as read-only;
store mutable game state separately. Editing native properties does not rewrite
the project file.

## Typed fields and entity references

Both maps and entities offer `GetField(name)`, returning Null when the field is
absent. Existing `fields` arrays and raw JSON remain available.

| Accessor | Result |
| --- | --- |
| `IsNull()` | Whether the exported value is null |
| `AsString()` | String, colour, enum or FilePath text as exported |
| `AsInt()` | Integer as a BlitzMax `Long`, preserving its range |
| `AsFloat()` | Number as `Double`, accepting JSON integers too |
| `AsBool()` | Boolean |
| `AsPoint()` | `TLDTKPoint` with grid `column` and `row` |
| `AsTile()` | `TLDTKTileReference` with `tilesetUID`, `x/y/width/height` |
| `AsEntityReference()` | `TLDTKEntityReference` with world/level/layer/entity IIDs |
| `Count()` / `Item(index)` | Array length and one element, exposed through the same accessors |

Structured accessors return Null for null values. Wrong types, malformed structured
values and out-of-range array indices throw. Scalar nulls require an `IsNull()` check.
A point uses grid coordinates: convert it through the appropriate layer grid and
apply the layer offset for nominal map coordinates. Tile references describe source
rectangles; reading one does not load an image. `AsString()` leaves FilePath values
unchanged; the native scalar property bag provides the resolved path.

```blitzmax
Local route:TLDTKField = entity.GetField("PatrolRoute")
If route And Not route.IsNull() Then
	For Local i:Int = 0 Until route.Count()
		Local point:TLDTKPoint = route.Item(i).AsPoint()
		If Not point Then Continue
		Local x:Double, y:Double
		entity.layer.grid.CellCenter(point.column, point.row, x, y)
		x :+ entity.layer.layer.offsetX
		y :+ entity.layer.layer.offsetY
		' Store this patrol destination in your game's movement data.
	Next
End If
```

Conversions are lazy and cached. Repeated `Item`, `AsPoint`, `AsTile` and
`AsEntityReference` calls reuse their objects; unrequested fields are not converted.
Treat the field JSON and returned typed objects as read-only. Retain game state
separately. The first `Item` call allocates a reference array for the field's length;
element wrappers are allocated only for requested indices.

### Resolving a linked entity

A registry belongs to one parsed project. Register only the maps you have chosen
to load from that project instance:

```blitzmax
Local loaded:TLDTKLevelRegistry = TLDTKLevelRegistry.Create(project)
Local room:TLDTKMap = project.LoadLevel("Entrance")
loaded.Register(room)

Local switchEntity:TLDTKEntity = room.Entity("your-switch-iid")
Local field:TLDTKField = switchEntity.GetField("Target")
If field Then
	Local reference:TLDTKEntityReference = field.AsEntityReference()
	Local target:TLDTKEntity = loaded.Resolve(reference)
	If target Then
		' Connect the switch to your game object for this entity.
	End If
End If
```

`Resolve` returns Null for a null reference, an unloaded level, or mismatched
world/layer/entity IDs. It never reads files. `reference.Level(project)` can find
the target's metadata before it is loaded; `loaded.LoadedLevel(reference.levelIID)`
checks whether its map is registered. Your game can then explicitly call
`project.LoadLevel(reference.levelIID)` and `loaded.Register(map)`.

The registry holds strong map references. Call `Unregister(levelIID)` when unloading
or `Clear()` to release all entries. Registering the same map again is harmless;
unregister an old instance before replacing it with a newly loaded one. Resolution
is checked each time, so unregistering a map cannot leave a cached resolved entity
inside the registry. Entity references your own game retained remain your
responsibility when unloading.

Try the [console navigation example](../ldtk.mod/examples/README.md#navigation-and-field-inspection)
with your own project to inspect neighbours, structured fields and loaded references.

## Streams, ZIP archives and external resources

```blitzmax
Using
	Local stream:TStream = ReadStream("maps/game.ldtk")
Do
	Local project:TLDTKProject = TLDTKProject.Load(stream, "maps/game.ldtk")
	Local map:TLDTKMap = project.LoadLevel("Dungeon_Entrance")
End Using
```

All entry points accept paths, stream URLs or caller-owned streams. Streams are
read from their current position without seeking, and caller streams remain open
on success and failure. Supply a logical project filename when using a stream:
external levels, tilesheets and file fields resolve relative to the **project**,
including when a `.ldtkl` file lives in a subdirectory.

Resources use the standard stream APIs, including `BRL.IO` mounts and `incbin::`.
Import `BRL.RamStream` for embedded assets and include all required resource files.
Keep an archive mounted until you have loaded every level you need from it. Images
are loaded eagerly per map; already loaded maps do not retain open asset streams.

## Using exported tilesheets

The editor can refer to an Aseprite document or another format your game does not
decode. Export a PNG with the same dimensions and tile positions, then supply its
pixels before loading levels:

```blitzmax
Local project:TLDTKProject = TLDTKProject.Load("maps/game.ldtk")
project.SetTilesetPixmap(73, LoadPixmap("art/terrain.png"))
Local map:TLDTKMap = project.LoadLevel("Entrance")
```

The number is the LDtk tileset **UID**, not its position in the definitions array
or a native Max2D tile ID. Find it in the project's tileset definition or a typed
Tile field. The supplied pixels take precedence over both the external image path
and an embedded atlas for that tileset. Unknown UIDs and null pixmaps throw.

The project JSON remains unchanged. Already-loaded maps retain their existing
artwork; the replacement applies to subsequent loads. A caller-owned pixmap is
retained by the project, and each loaded map copies the required artwork into its
atlas. You can use `LoadPixmap(stream)` or your own image decoder to prepare the
pixels. This API does not add an Aseprite decoder or watch the editor file for changes.

## Current limits

The importer supports regular tiles, exported auto-layers, IntGrid CSV,
entity rectangles/fields, embedded and external levels, multiple worlds,
background placement/repetition, entity artwork and layer parallax.

- Non-normal layer blending is rejected. Editor shape fills, labels and field
  overlays are not drawn; entity tile artwork is supported.
- Embedded atlases require caller-supplied pixels; external tilesets require an image path.
- Old pre-CSV IntGrid data requires resaving with a current LDtk version.
- There is no runtime auto-tiling rule evaluator, collision response or project writer.
- Loading is bounded to 65,536 levels per project; a loaded level accepts up to
  4,096 layers, 16,777,216 layer cells, 65,536 artwork definitions, 1,048,576
  tile/entity instances, 65,536 entities and 1,048,576 fields. Native image limits apply.
- Each repeated image region is limited to 1,048,576 visible tiles per draw. Extreme
  zoom-out beyond that limit throws an error rather than doing unbounded work.

Errors include project/level context. The importer uses the
[LDtk 1.5.3 JSON format](https://ldtk.io/json/) as its reference; it does not claim
support for every editor setting or every historical export version.

Try the [bundled upstream example and viewer](../ldtk.mod/examples/README.md).
