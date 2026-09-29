SuperStrict
Rem
bbdoc: Optional Tiled XML/JSON import into native Max2D tilemaps.
End Rem
Module Max2D.Tiled
ModuleInfo "Version: 0.10"
ModuleInfo "License: zlib/libpng"
Import Max2D.TileMap
Import Text.XML
Import Text.JSON
Import Archive.ZLib
Import BRL.Base64
Import BRL.FileSystem
Import BRL.PNGLoader
Import "inflate.c"

Extern "C"
	Function max2d_tiled_inflate:Int(source:Byte Ptr,sourceSize:Int,dest:Byte Ptr,destSize:Int,gzip:Int)
End Extern

Include "compression.bmx"
Include "project.bmx"
Include "json.bmx"
Include "reader.bmx"
Include "templates.bmx"

Rem
bbdoc: Tiled map metadata alongside an ordinary native tilemap. Isometric origin adjustment is included in layer offsets.
End Rem
Type TTiledMap Extends TTileMap

	Rem
	bbdoc: Source map width in cells; chunked infinite maps may report zero.
	End Rem
	Field width:Int

	Rem
	bbdoc: Source map height in cells; chunked infinite maps may report zero.
	End Rem
	Field height:Int

	Rem
	bbdoc: Whether the source map uses unbounded chunked tile layers.
	End Rem
	Field infinite:Int

	Rem
	bbdoc: Tiled orientation name, such as orthogonal, isometric or hexagonal.
	End Rem
	Field orientation:String

	Rem
	bbdoc: Editor-defined custom class name.
	End Rem
	Field className:String

	Rem
	bbdoc: Background colour string retained from the editor document.
	End Rem
	Field backgroundColor:String

	Rem
	bbdoc: Row and column traversal order for rectangular grids.
	End Rem
	Field renderOrder:ETileRenderOrder=ETileRenderOrder.RightDown

	Rem
	bbdoc: Horizontal origin adjustment applied to imported isometric layers.
	End Rem
	Field originX:Double

	Rem
	bbdoc: Logical source filename used to resolve relative resources.
	End Rem
	Field sourcePath:String

	Rem
	bbdoc: Shared texture atlas containing artwork or glyph images.
	End Rem
	Field atlas:TTextureAtlas

	Rem
	bbdoc: Imported tileset metadata in source order.
	End Rem
	Field importedTilesets:TTiledTileset[]=New TTiledTileset[0]

	Rem
	bbdoc: Editor layer metadata in native drawing order.
	End Rem
	Field importedLayers:TTiledLayerInfo[]=New TTiledLayerInfo[0]
End Type

Rem
bbdoc: Imported tileset metadata and mappings from local IDs to native tiles and image views.
End Rem
Type TTiledTileset

	Rem
	bbdoc: Name used to identify this entry.
	End Rem
	Field name:String

	Rem
	bbdoc: Editor-defined custom class name.
	End Rem
	Field className:String

	Rem
	bbdoc: Logical source filename used to resolve relative resources.
	End Rem
	Field sourcePath:String

	Rem
	bbdoc: Tileset alignment used to place tile objects relative to their anchors.
	End Rem
	Field objectAlignment:String

	Rem
	bbdoc: Whether artwork stretches or preserves its aspect ratio inside its drawing box.
	End Rem
	Field fillMode:String

	Rem
	bbdoc: Tiled tile render-size mode retained from the tileset.
	End Rem
	Field renderSize:String

	Rem
	bbdoc: Horizontal drawing or presentation offset.
	End Rem
	Field offsetX:Float

	Rem
	bbdoc: Vertical drawing or presentation offset.
	End Rem
	Field offsetY:Float

	Rem
	bbdoc: First global tile identifier assigned to this tileset in the map.
	End Rem
	Field firstGID:Int

	Rem
	bbdoc: Mutable application properties associated with this item.
	End Rem
	Field properties:TTileProperties=New TTileProperties

	Rem
	bbdoc: Mapping from tileset-local IDs to native tile IDs.
	End Rem
	Field ids:TTreeMap<Int,Int>=New TTreeMap<Int,Int>

	Rem
	bbdoc: Image views indexed by tileset-local ID.
	End Rem
	Field images:TTreeMap<Int,TImage>=New TTreeMap<Int,TImage>

	Rem
	bbdoc: Mapping from local tile IDs to imported custom class names.
	End Rem
	Field classes:TTreeMap<Int,String>=New TTreeMap<Int,String>

	Rem
	bbdoc: Returns the native tile ID corresponding to a Tiled tileset-local ID.
	param: Zero-based tile identifier within the imported tileset.
	End Rem
	Method NativeID:Int(localID:Int)
		Local id:Int
		ids.TryGetValue(localID,id)
		Return id
	End Method

End Type

Rem
bbdoc: Source layer/group metadata in document order. Groups have a Null layer and their children refer to parent.
End Rem
Type TTiledLayerInfo

	Rem
	bbdoc: Identifier associated with this object or definition.
	End Rem
	Field id:Int

	Rem
	bbdoc: Name used to identify this entry.
	End Rem
	Field name:String

	Rem
	bbdoc: Editor-defined custom class name.
	End Rem
	Field className:String

	Rem
	bbdoc: Imported group layer containing this layer, or Null at the map root.
	End Rem
	Field parent:TTiledLayerInfo

	Rem
	bbdoc: Imported layer or definition kind.
	End Rem
	Field kind:String

	Rem
	bbdoc: Native or imported layer containing this object.
	End Rem
	Field layer:TTileLayer

	Rem
	bbdoc: Mutable application properties associated with this item.
	End Rem
	Field properties:TTileProperties=New TTileProperties
End Type

Rem
bbdoc: Registered adapter for loading Tiled maps through LoadTileMap.
End Rem
Type TTiledMapLoader Extends TTileMapLoader

	Rem
	bbdoc: Reports whether this loader recognizes a source filename or extension.
	param: Resource filename or filesystem URL.
	End Rem
	Method CanLoad:Int(path:String) Override
		Local extension:String=ExtractExt(path).ToLower()
		Return extension="tmx" Or extension="tmj" Or extension="json"
	End Method

	Rem
	bbdoc: Loads a Tiled source through the generic tilemap-loader interface.
	param: Filename, stream URL or caller-owned readable stream.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Logical source filename used to resolve relative resources for stream input.
	End Rem
	Method Load:TTileMap(source:Object,flags:Int,sourcePath:String) Override
		Return LoadTiledMap(source,flags,sourcePath)
	End Method

End Type

Rem
bbdoc: Module-owned loader registration for Tiled map files.
End Rem
Global _max2dTiledLoader:TTiledMapLoader=New TTiledMapLoader

Rem
bbdoc: Loads Tiled XML or JSON from a path, stream URL or caller-owned TStream.
param: Filename, stream URL or caller-owned readable stream.
param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
param: Logical source filename used to resolve relative resources for stream input.
param: Owning project and its imported definitions.
param: Optional application font resolver for imported text objects.
about: sourcePath is the logical filename used to resolve relative resources when loading a stream. Without it resources resolve from the current directory. Caller streams remain open on success and failure.
End Rem
Function LoadTiledMap:TTiledMap(source:Object,flags:Int=FILTEREDIMAGE,sourcePath:String="",project:TTiledProject=Null,fontResolver:TTiledFontResolver=Null)
	Local reader:TTiledReader=New TTiledReader
	reader.project=project; reader.fontResolver=fontResolver
	If project Then project.BeginImport()
	Return reader.Read(source,flags,sourcePath)
End Function

Rem
bbdoc: Application font mapping for Tiled text objects. Return a face at pixelSize, with the requested style/kerning, or Null to use the built-in fallback.
End Rem
Type TTiledFontResolver Abstract

	Rem
	bbdoc: Resolves an application's font for a Tiled text object, or returns Null for fallback.
	param: Requested font family name.
	param: Requested logical font size in pixels.
	param: Whether a bold face is requested.
	param: Whether an italic face is requested.
	param: Whether pair kerning should be enabled.
	End Rem
	Method Resolve:TImageFont(family:String,pixelSize:Int,bold:Int,italic:Int,kerning:Int) Abstract
End Type
