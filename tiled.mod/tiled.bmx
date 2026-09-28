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
	Field width:Int,height:Int,infinite:Int
	Field orientation:String,className:String,backgroundColor:String
	Field renderOrder:ETileRenderOrder=ETileRenderOrder.RightDown
	Field originX:Double
	Field sourcePath:String
	Field atlas:TTextureAtlas
	Field importedTilesets:TTiledTileset[]=New TTiledTileset[0]
	Field importedLayers:TTiledLayerInfo[]=New TTiledLayerInfo[0]
End Type

Type TTiledTileset
	Field name:String,className:String,sourcePath:String
	Field objectAlignment:String,fillMode:String,renderSize:String
	Field offsetX:Float,offsetY:Float
	Field firstGID:Int
	Field properties:TTileProperties=New TTileProperties
	Field ids:TTreeMap<Int,Int>=New TTreeMap<Int,Int>
	Field images:TTreeMap<Int,TImage>=New TTreeMap<Int,TImage>
	Field classes:TTreeMap<Int,String>=New TTreeMap<Int,String>
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
	Field id:Int,name:String,className:String
	Field parent:TTiledLayerInfo
	Field kind:String
	Field layer:TTileLayer
	Field properties:TTileProperties=New TTileProperties
End Type

Type TTiledMapLoader Extends TTileMapLoader
	Method CanLoad:Int(path:String) Override
		Local extension:String=ExtractExt(path).ToLower()
		Return extension="tmx" Or extension="tmj" Or extension="json"
	End Method
	Method Load:TTileMap(source:Object,flags:Int,sourcePath:String) Override
		Return LoadTiledMap(source,flags,sourcePath)
	End Method
End Type

Global _max2dTiledLoader:TTiledMapLoader=New TTiledMapLoader

Rem
bbdoc: Loads Tiled XML or JSON from a path, stream URL or caller-owned TStream.
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
	Method Resolve:TImageFont(family:String,pixelSize:Int,bold:Int,italic:Int,kerning:Int) Abstract
End Type
