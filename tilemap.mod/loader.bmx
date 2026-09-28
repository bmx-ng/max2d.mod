Rem
bbdoc: Optional format loaders register on construction. Import a provider such as Max2D.Tiled.
End Rem
Type TTileMapLoader Abstract
	Global loaders:TTileMapLoader
	Field nextLoader:TTileMapLoader
	Method New()
		nextLoader=loaders; loaders=Self
	End Method
	Method CanLoad:Int(path:String) Abstract
	Method Load:TTileMap(source:Object,flags:Int,sourcePath:String) Abstract
End Type

Rem
bbdoc: Loads a tilemap using an imported provider. Throws on missing support or invalid input.
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
