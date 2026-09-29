SuperStrict
Rem
bbdoc: Create, draw and interact with rectangular, hexagonal and isometric tilemaps.
about: Build maps directly in code using shared tile artwork, editable layers and application properties. Grid helpers provide picking, neighbours, distances and ranges. No map editor is required. Import Max2D.Tiled or Max2D.LDTK separately to load maps made in those editors.
End Rem
Module Max2D.TileMap
ModuleInfo "Version: 0.15"
ModuleInfo "License: zlib/libpng"
Import Max2D.Core
Import Collections.TreeMap

Rem
bbdoc: Cell geometry supported by native tile grids.
End Rem
Enum ETileLayout

	Rem
	bbdoc: Axis-aligned rectangular cells, also called an orthogonal grid.
	End Rem
	Rectangular

	Rem
	bbdoc: Hexagonal cells with a top and bottom vertex.
	End Rem
	PointyHex

	Rem
	bbdoc: Hexagonal cells with flat top and bottom edges.
	End Rem
	FlatHex

	Rem
	bbdoc: Diamond cells on an isometric grid.
	End Rem
	Isometric

	Rem
	bbdoc: Diamond cells arranged in staggered rows or columns.
	End Rem
	StaggeredIsometric
End Enum

Rem
bbdoc: Axis along which rows or columns receive stagger offsets.
End Rem
Enum ETileAxis

	Rem
	bbdoc: Staggers columns along the horizontal grid axis.
	End Rem
	X

	Rem
	bbdoc: Staggers rows along the vertical grid axis.
	End Rem
	Y
End Enum

Rem
bbdoc: Row-by-row traversal for rectangular layers using Grid sorting.
End Rem
Enum ETileRenderOrder

	Rem
	bbdoc: Visits columns left to right and rows top to bottom.
	End Rem
	RightDown

	Rem
	bbdoc: Visits columns left to right and rows bottom to top.
	End Rem
	RightUp

	Rem
	bbdoc: Visits columns right to left and rows top to bottom.
	End Rem
	LeftDown

	Rem
	bbdoc: Visits columns right to left and rows bottom to top.
	End Rem
	LeftUp
End Enum

Rem
bbdoc: How artwork is fitted into a tile or object rectangle.
End Rem
Enum ETileFillMode

	Rem
	bbdoc: Scales artwork independently on each axis to fill its box.
	End Rem
	Stretch

	Rem
	bbdoc: Fits artwork inside its box while preserving its aspect ratio.
	End Rem
	PreserveAspectFit
End Enum

Rem
bbdoc: Drawing-order strategy for tiles and free-positioned sprites.
End Rem
Enum ETileSort

	Rem
	bbdoc: Draws cells in grid traversal order.
	End Rem
	Grid

	Rem
	bbdoc: Sorts tiles and sprites by their ground depth and tie-break values.
	End Rem
	GroundDepth
End Enum

Rem
bbdoc: Parity of the rows or columns shifted in an offset grid.
End Rem
Enum ETileStagger

	Rem
	bbdoc: Shifts even-numbered rows or columns.
	End Rem
	Even = 0

	Rem
	bbdoc: Shifts odd-numbered rows or columns.
	End Rem
	Odd = 1
End Enum

Rem
bbdoc: Tile reflection and hexagonal rotation flags.
End Rem
Enum ETileFlip Flags

	Rem
	bbdoc: No reflection or rotation.
	End Rem
	None = 0

	Rem
	bbdoc: Reflects the tile horizontally.
	End Rem
	Horizontal = 1

	Rem
	bbdoc: Reflects the tile vertically.
	End Rem
	Vertical = 2

	Rem
	bbdoc: Exchanges the tile's axes for diagonal reflection.
	End Rem
	Diagonal = 4

	Rem
	bbdoc: Adds a 60-degree tile rotation for hexagonal artwork.
	End Rem
	Rotate60 = 8

	Rem
	bbdoc: Adds a 120-degree tile rotation for hexagonal artwork.
	End Rem
	Rotate120 = 16
End Enum

Rem
bbdoc: Integer column and row identifying one grid cell.
End Rem
Struct STileCell

	Rem
	bbdoc: Integer cell column.
	End Rem
	Field column:Int

	Rem
	bbdoc: Integer cell row.
	End Rem
	Field row:Int
End Struct

' Bounds keep arithmetic safe; visible drawing still has Float pixel precision.

Rem
bbdoc: Largest supported absolute cell coordinate, used to keep grid arithmetic safe.
End Rem
Const TILE_COORDINATE_LIMIT:Int=1000000

Rem
bbdoc: Width and height in cells of each sparse layer-storage chunk.
End Rem
Const TILE_CHUNK_SIZE:Int=32

Include "properties.bmx"
Include "queries.bmx"
Include "grid.bmx"
Include "transform.bmx"
Include "sorting.bmx"
Include "text.bmx"
Include "objects.bmx"
Include "map.bmx"

Include "loader.bmx"
