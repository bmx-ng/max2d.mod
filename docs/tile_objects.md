# Map objects and collision geometry

Use map objects for spawn points, triggers, paths, labels and freely placed scenery.
Create them directly with `Max2D.TileMap`, or draw them in Tiled and import them.

## Objects and layers

Each `TTileLayer` has an `objects:TTileObject[]` array and `AddObject(object)`.
A layer may contain tiles, objects, or both. Tiled object layers become ordinary
native layers in document order, with no populated cells. Existing `layers`
iteration therefore includes them. `TTiledLayerInfo.kind` distinguishes `layer`,
`objectgroup` and `group`; groups still have a Null native layer.

Objects retain `id`, `name`, `className`, `visible` and `properties`.
`opacity` defaults to 1 and multiplies the caller/layer alpha when drawing tile
artwork or text. Values must be in 0..1; opacity does not affect geometry queries. Their `shape`
is a rectangle, ellipse, point, polygon or polyline. Polygon/polyline `points`
are local coordinates; rectangle/ellipse dimensions are `width` and `height`.

The matrix `xx,xy,yx,yy` and translation `x,y` map shape-local points into the
parent coordinate system. `SetRotation(degrees)` replaces the matrix with a
clockwise rotation. A tileset collision object's parent is the untrimmed image;
a map object's parent is its layer. Imported isometric objects already include
projection: replacing their matrix with `SetRotation` would remove that projection.

`object.Instance(layer.offsetX,layer.offsetY)` returns an `STileObjectInstance`
with a complete map-local transform. Its `TransformPoint`, `Bounds` and
`ContainsPoint` methods work without graphics, a camera or a physics engine.

```blitzmax
For Local layer:TTileLayer = EachIn map.layers
	Local spawn:TTileObject = layer.ObjectByID(37)
	If Not spawn Then Continue
	Local pose:STileObjectInstance = spawn.Instance(layer.offsetX, layer.offsetY)
	Local spawnX:Double, spawnY:Double
	pose.TransformPoint(0, 0, spawnX, spawnY)
	' Create the player at spawnX, spawnY.
Next
```

`map.ObjectByID` and `layer.ObjectByID` return the first matching object, or Null.
Tiled rejects duplicate nonzero IDs across map object layers; collision IDs are
local to each tile and are not included in map lookup. Object-valued properties
remain integer IDs, so forward references can be resolved after loading.
`object.Property(name)` checks instance properties, then tile-definition defaults
for tile objects. `object.properties` holds instance/template values and independent structured
class defaults inherited from the tile; scalar tile defaults remain a fallback.

## Querying objects

```blitzmax
Local hits:TTileObjectQueryResult = New TTileObjectQueryResult

' Reuse hits on subsequent calls. Coordinates are map-local, including layer offsets.
layer.QueryObjectsAtPoint(mouseMapX, mouseMapY, 3, hits)
For Local i:Int = 0 Until hits.count
	Local hit:STileObjectInstance = hits.items[i]
	Print hit.source.name
Next

layer.QueryObjects(viewX, viewY, viewWidth, viewHeight, hits)
```

- Point queries test the actual geometry, including concave polygons and affine
  ellipses. Points and polylines use the supplied tolerance in map units. Polygon
  and rectangle boundaries are included; degenerate ellipses and singular area
  transforms do not contain points.
- Region queries return **bounding-box candidates**, including touching edges.
  They do not claim precise shape/rectangle intersection or physics contacts.
- Queries include invisible objects and layers; visibility controls drawing,
  not whether a trigger or collision exists. Filter visibility yourself if needed.
- Results follow source object order, not visual depth order. Only
  `items[0 Until count]` are valid. `Clear` releases active object references;
  capacity is retained for reuse. Instances reference source geometry and snapshot
  its transform; rerun queries after changing geometry or positions.
- Object queries scan that layer's objects. There is no persistent spatial index.

For parallax layers, use `map.VirtualToLayer` and add the nominal layer offset
before querying; see [Tiled layer effects](tiled.md#image-layers-tint-and-parallax).
With only a camera active and default parallax, `GetWorldMouse` supplies suitable map coordinates for a
map drawn at `(0,0)`. For additional map translation/object transforms, invert the
same full drawing transform before querying. Queries do not implicitly read
current graphics state.

## Tile collision geometry

Each `TTileDefinition.collisions` contains shape objects in its image coordinates.
`map.CellCollision(layer,column,row,index)` returns an instance in map coordinates,
including the cell position, artwork offset, layer offset, diagonal flips and
hexagonal rotations. The source objects are shared; no transformed point arrays
are allocated per cell.

```blitzmax
Local candidates:TTileObjectQueryResult = New TTileObjectQueryResult
map.QueryTileCollisions(layer, playerX, playerY, playerWidth, playerHeight, candidates)
For Local i:Int = 0 Until candidates.count
	Local shape:STileObjectInstance = candidates.items[i]
	' shape.column / shape.row identify the cell.
	' Read shape.source.properties for material, damage, one-way flags, etc.
	' Feed the shape to the game's collision or movement logic.
Next
```

This is a broad-phase query: the game supplies its own precise collision test and
response. `ContainsPoint` provides exact point picking of the returned shapes.
Shapes extending outside their cell are included. Queries inspect collision
extents across tile definitions, then query the sparse cells in that region.
The output retains candidate-cell storage as well as result capacity. Collision
geometry stays fixed across animation frames; it does not switch to each frame's
separate tile definition. Shapes are neither synthesized from opaque pixels nor
inferred from the cell boundary. A tile without shapes has no collision geometry.

`QueryTileCollisions` covers populated grid cells. Collision shapes attached to
freely positioned tile objects are not automatically expanded by this query;
object picking uses their displayed image rectangle.

## Rendering and ordering

`map.Draw()` draws tile objects using their image, dimensions, transform, flip,
animation and visibility. Objects with `text:TTileText` draw retained, clipped text.
Other objects are data; they are not drawn as part
of the scene. The example viewer draws their outlines explicitly for inspection.

Layers retain document order. In a native mixed layer, tile and text objects draw after
tiles and existing sprites. `objectTopDown=True` sorts tile and text objects by `sortY`,
with stable source-order ties; False uses insertion order. Tiled imports `sortY`
from the projected object anchor. If moving native objects, update `sortY` to the
appropriate ground position. Objects without artwork or text are excluded from drawing/sorting.
The object renderer currently scans visible tile/text objects rather than maintaining
a spatial index. Drawn tile objects contribute to `drawnSprites`; text objects to `drawnTexts`.
See [tile sizing and text](tile_sizing_text.md) for fitting, fonts and caching.

`TTileLayer.Clear()` clears cells and their properties; use `layer.objects=[]` to
remove objects. The two lifecycles are deliberately independent.

## Tiled support and remaining limits

Supported: object groups, inherited group offsets/opacity/visibility, names,
classes, properties, IDs, point/rectangle/ellipse/polygon/polyline shapes, object
rotation, standard-isometric projection, tile objects with alignment, size, flips,
animation, and tile property/class inheritance. Tile collision groups use the
same geometry model and preserve object metadata.

Still rejected explicitly: tile/text objects within collision groups, isometric
**tileset collision grids**, and nonzero legacy object-layer x/y coordinates. Ordinary isometric map
objects are supported. Non-normal layer blend modes remain unsupported.
Optional [project class-schema defaults](tiled_projects.md) are supported.
[XML templates and serialized structured properties](tiled_templates.md) are supported. Maximums are 65,536 objects per import, 65,536 point tokens per
shape, and 1,048,576 geometry points across the import.

See [Tiled loading](tiled.md) and the upstream
[TMX specification](https://doc.mapeditor.org/en/stable/reference/tmx-map-format/).

### Visual layer scale

`layer.drawScale` defaults to 1 and must be positive and finite. It scales drawing
around the layer's visual origin; `Pick`, `MouseCell` and `VirtualToLayer` account
for it. Object/cell geometry and region queries retain nominal coordinates, just
as they do with parallax. This lets editor importers represent depth scaling
without changing gameplay geometry.

### Artwork independent of object bounds

`TTileObject.artwork` can hold a `TTileObjectArtwork` implementation. Its `Draw`
method receives the object's nominal width/height and elapsed time, with the
object and layer transforms, tint and opacity already applied. It can draw outside
those bounds without changing object queries. Restore any drawing state you change.
`artwork.visible=False` hides the artwork while retaining the gameplay object.
Text takes precedence when present; otherwise visible custom artwork takes
precedence over a tile image. The statistics count it as one drawn sprite object,
even when its implementation submits several image pieces.

The LDtk importer uses this for entity sizing, cropped artwork and nine-slice
images. Ordinary tile objects keep their existing drawing path.
