
Rem
bbdoc: Optional format loaders register on construction. Import a provider such as Max2D.Tiled.
End Rem
Type TTileMapLoader Abstract

	Rem
	bbdoc: Head of the registered tilemap-loader chain.
	End Rem
	Global loaders:TTileMapLoader

	Rem
	bbdoc: Next loader in the registered provider chain.
	End Rem
	Field nextLoader:TTileMapLoader

	Rem
	bbdoc: Registers this loader for generic LoadTileMap calls.
	End Rem
	Method New()
		nextLoader=loaders; loaders=Self
	End Method

	Rem
	bbdoc: Reports whether this loader recognizes a source filename or extension.
	param: Resource filename or filesystem URL.
	End Rem
	Method CanLoad:Int(path:String) Abstract

	Rem
	bbdoc: Loads a supported source as a native tilemap.
	param: Filename, stream URL or caller-owned readable stream.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Logical source filename used to resolve relative resources for stream input.
	End Rem
	Method Load:TTileMap(source:Object,flags:Int,sourcePath:String) Abstract
End Type

Rem
bbdoc: Loads a tilemap using an imported provider. Throws on missing support or invalid input.
param: Filename, stream URL or caller-owned readable stream.
param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
param: Logical source filename used to resolve relative resources for stream input.
about: source accepts a path/stream URL or TStream. Streams require sourcePath for format selection and relative resources. Caller streams stay open. flags applies to imported images.
End Rem
Function LoadTileMap:TTileMap(source:Object,flags:Int=FILTEREDIMAGE,sourcePath:String="")
	Local path:String=sourcePath
	If Not path Then path=String(source)
	If Not path Then Throw "Max2D tilemap: a stream requires a sourcePath hint, or use a format-specific loader"
	Local loader:TTileMapLoader=TTileMapLoader.loaders
	While loader
		If loader.CanLoad(path) Then Return loader.Load(source,flags,path)
		loader=loader.nextLoader
	Wend
	Throw "Max2D tilemap: no loader for "+path
End Function
