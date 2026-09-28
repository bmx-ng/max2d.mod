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

Enum ETileLayout
	Rectangular
	PointyHex
	FlatHex
	Isometric
	StaggeredIsometric
End Enum

Enum ETileAxis
	X
	Y
End Enum

Rem
bbdoc: Row-by-row traversal for rectangular layers using Grid sorting.
End Rem
Enum ETileRenderOrder
	RightDown
	RightUp
	LeftDown
	LeftUp
End Enum

Enum ETileFillMode
	Stretch
	PreserveAspectFit
End Enum

Enum ETileSort
	Grid
	GroundDepth
End Enum

Enum ETileStagger
	Even = 0
	Odd = 1
End Enum

Enum ETileFlip Flags
	None = 0
	Horizontal = 1
	Vertical = 2
	Diagonal = 4
	Rotate60 = 8
	Rotate120 = 16
End Enum

Struct STileCell
	Field column:Int,row:Int
End Struct

' Bounds keep arithmetic safe; visible drawing still has Float pixel precision.
Const TILE_COORDINATE_LIMIT:Int=1000000
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
