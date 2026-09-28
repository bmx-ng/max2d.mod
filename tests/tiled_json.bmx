SuperStrict
Framework Max2D.Tiled
Import BRL.StandardIO
Import BRL.IO
Import BRL.RamStream
Incbin "data/tiled/json-csv.tmj"
Incbin "data/tiled/tiles/basic.tsj"
Incbin "data/tiled/sheet.png"
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
' Deliberately has no seek/size support and returns short reads.
Type TForwardStream Extends TStream
	Field source:TStream
	Method Read:Long(buffer:Byte Ptr,count:Long) Override
		Return source.Read(buffer,Min(count,7:Long))
	End Method
	Method Eof:Int() Override
		Return source.Eof()
	End Method
End Type
Try
	Local path:String=RealPath(AppArgs[1])
	For Local name:String=EachIn ["csv","raw","zlib","gzip"]
		Local map:TTiledMap=TTiledMap(LoadTileMap(path+"/json-"+name+".tmj",0))
		Check(map.layers[0].CellCount()=4,"JSON tile count: "+name)
		Check(map.layers[0].CellFlip(1,1)=(ETileFlip.Horizontal|ETileFlip.Vertical),"Unsigned JSON GIDs: "+name)
		Check(map.layers[0].Property(0,0,"large").AsLong()=5000000000:Long,"Integer properties")
		Check(map.layers[0].Property(0,0,"label").AsString()="Hello & world","String properties")
		Check(map.importedTilesets[0].properties.GetString("asset")=RealPath(path+"/sheet.png"),"Relative TSJ property")
		Check(map.tileset.tiles[map.importedTilesets[0].NativeID(1)].image.AnimationDuration()=300,"JSON animation")
	Next
	Local map:TTiledMap=LoadTiledMap(path+"/json-infinite.tmj",0)
	Check(map.layers[0].CellCount()=3 And map.layers[0].Cell(-33,-32)>0,"JSON infinite chunks")
	map=LoadTiledMap(path+"/json-groups.tmj",0)
	Check(map.layers[0].offsetX=7 And map.layers[0].opacity=0.25 And Not map.layers[0].visible,"JSON group state")
	map=LoadTiledMap(path+"/json-collections.tmj",0)
	Check(map.layers[0].Cell(1,0)=map.importedTilesets[1].NativeID(5),"JSON image collections")
	map=LoadTiledMap(path+"/json-iso.tmj",0)
	Check(map.grid.Layout()=ETileLayout.Isometric And map.layers[0].offsetX=1,"JSON isometric origin")
	map=LoadTiledMap(path+"/json-objects.tmj",0)
	Check(map.ObjectByID(4).shape=ETileObjectShape.Polygon And map.ObjectByID(4).points.Length=6,"JSON polygon geometry")
	Check(map.ObjectByID(5).shape=ETileObjectShape.Polyline And Not map.ObjectByID(7).visible,"JSON polyline and visibility")
	map=LoadTiledMap(path+"/json-template-reference.tmx",0)
	Check(map.ObjectByID(1).tile>0 And map.ObjectByID(1).flip=ETileFlip.Horizontal,"XML map referencing JSON tile template and TSJ")
	map=LoadTiledMap(path+"/json-templates.tmj",0)
	Check(map.ObjectByID(1).properties.GetClass("stats").GetLong("health")=50,"JSON class override")
	Check(map.ObjectByID(1).properties.GetClass("stats").GetClass("combat").GetLong("damage")=3,"Nested JSON members")
	Check(map.ObjectByID(2).properties.GetClass("stats").GetLong("health")=100,"Independent template values")
	Check(map.ObjectByID(2).properties.GetLong("large")=9007199254740993:Long,"Lossless 64-bit JSON integer")
	Check(map.ObjectByID(2).properties.GetString("asset")=RealPath(path+"/templates/guard.wav"),"JSON template relative file")
	Check(map.ObjectByID(3).tile>0,"JSON map referencing XML tile template")
	Check(map.ObjectByID(4).tile>0 And map.importedTilesets.Length=2,"JSON template-only TSJ remapping")
	map=LoadTiledMap("incbin::data/tiled/json-csv.tmj",0)
	Check(map.layers[0].CellCount()=4,"JSON embedded resources")
	Local file:TStream=ReadStream(path+"/json-csv.tmj")
	Try
		Local stream:TForwardStream=New TForwardStream
		stream.source=file
		map=LoadTiledMap(stream,0,path+"/hint-without-extension")
		Check(map.layers[0].CellCount()=4 And file.Pos()>0,"Content detection on non-seekable caller stream")
	Finally
		file.Close()
	End Try
	MaxIO.Init()
	Try
		Check(MaxIO.Mount(path+"/json.zip"),"Mount JSON archive")
		map=LoadTiledMap("json-csv.tmj",0)
		Check(map.layers[0].CellCount()=4,"JSON ZIP resource loading")
		Check(MaxIO.Unmount(path+"/json.zip"),"JSON resources close after load")
	Finally
		MaxIO.DeInit()
	End Try
	For Local name:String=EachIn ["negative","overflow","fraction"]
		Local rejected:Int
		Try
			LoadTiledMap(path+"/json-bad-"+name+".tmj",0)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Reject invalid JSON GID: "+name)
	Next
	file=ReadStream(path+"/json-duplicate.tmj")
	Try
		Local rejected:Int
		Try
			LoadTiledMap(file,0)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected And file.Pos()>0,"Duplicate keys rejected without closing caller stream")
	Finally
		file.Close()
	End Try
	Print "Tiled JSON tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
