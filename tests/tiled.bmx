SuperStrict
Framework Max2D.Tiled
Import BRL.StandardIO
Import BRL.IO
Import BRL.RamStream
Incbin "data/tiled/csv.tmx"
Incbin "data/tiled/tiles/basic.tsx"
Incbin "data/tiled/sheet.png"
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Try
	If AppArgs.Length<2 Then Throw "Pass the tests/data/tiled directory"
	Local path:String=AppArgs[1]
	Local orderNames:String[]=["right-down","right-up","left-down","left-up"]
	Local orders:ETileRenderOrder[]=[ETileRenderOrder.RightDown,ETileRenderOrder.RightUp,ETileRenderOrder.LeftDown,ETileRenderOrder.LeftUp]
	For Local extension:String=EachIn ["tmx","tmj"]
		For Local i:Int=0 Until orders.Length
			Local ordered:TTiledMap=LoadTiledMap(path+"/order-"+orderNames[i]+"."+extension,0)
			Check(ordered.renderOrder=orders[i] And ordered.layers[0].renderOrder=orders[i],"Imported render order in nested group: "+extension+" "+orderNames[i])
		Next
	Next
	For Local file:String=EachIn ["csv","xml","raw","zlib","gzip"]
		Local map:TTiledMap=TTiledMap(LoadTileMap(path+"/"+file+".tmx",0))
		Check(map<>Null And map.layers.Length=1,"Registered loader and layer")
		Local layer:TTileLayer=map.layers[0]
		Check(layer.CellCount()=4,"Decoded cell count: "+file)
		Check(layer.CellFlip(1,0)=ETileFlip.Horizontal And layer.CellFlip(0,1)=ETileFlip.Vertical And layer.CellFlip(1,1)=(ETileFlip.Horizontal|ETileFlip.Vertical),"Unsigned GIDs and flips: "+file)
		Check(layer.Property(0,0,"solid").AsBool() And layer.Property(0,0,"large").AsLong()=5000000000:Long,"Tile properties")
		Check(layer.Property(0,0,"label").AsString()="Hello & world","XML text/entities")
		Check(layer.Property(0,0,"cost").AsDouble()=1.25,"Floating property")
		Check(map.importedTilesets[0].properties.GetString("asset")=RealPath(path+"/sheet.png"),"TSX-relative file property")
		Local image:TImage=map.tileset.tiles[map.importedTilesets[0].NativeID(1)].image
		Check(image.AnimationDuration()=300 And image.FrameAtTime(100)=1,"Animation timing")
	Next
	Local map:TTiledMap=TTiledMap(LoadTileMap(path+"/groups.tmx"))
	Check(map.properties.GetLong("level")=7 And map.importedLayers[0].properties.GetString("group")="yes","Map and group properties")
	Check(map.layers[0].offsetX=7 And map.layers[0].offsetY=10 And map.layers[0].opacity=0.25 And Not map.layers[0].visible,"Inherited group state")
	Check(map.importedLayers[2].parent=map.importedLayers[1],"Group parent metadata")
	map=TTiledMap(LoadTileMap(path+"/infinite.tmx"))
	Check(map.infinite And map.layers[0].CellCount()=3 And map.layers[0].Cell(-33,-32)>0 And map.layers[0].Cell(32,33)>0,"Infinite chunks with negative coordinates")
	map=TTiledMap(LoadTileMap(path+"/collections.tmx"))
	Check(map.layers[0].Cell(1,0)=map.importedTilesets[1].NativeID(5),"Multiple tilesets and sparse local IDs")
	Local tile:TTileDefinition=map.tileset.tiles[map.layers[0].Cell(1,0)]
	Check(tile.offsetY=-2 And tile.image.width=7,"Oversized image bottom-left alignment")
	map=TTiledMap(LoadTileMap(path+"/iso.tmx"))
	Check(map.grid.Layout()=ETileLayout.Isometric And map.layers[0].offsetX=1,"Tiled isometric origin")
	For Local axis:String=EachIn ["x","y"]
		For Local stagger:String=EachIn ["odd","even"]
			For Local kind:String=EachIn ["hexagonal","staggered"]
				map=TTiledMap(LoadTileMap(path+"/"+kind+"-"+axis+"-"+stagger+".tmx"))
				Check(map.grid.IsHex()=(kind="hexagonal"),"Layout kind")
				Check((map.grid.StaggerAxis()=ETileAxis.X)=(axis="x"),"Stagger axis")
				Check((map.grid.Stagger()=ETileStagger.Odd)=(stagger="odd"),"Stagger parity")
			Next
		Next
	Next
	map=TTiledMap(LoadTileMap(path+"/hex-transforms.tmx"))
	For Local i:Int=0 Until 16
		Check(Int(map.layers[0].CellFlip(i,0))=((i Mod 4) | ((i/4) Shl 3)),"Hex rotation/reflection flag mapping")
	Next
	map=TTiledMap(LoadTileMap(path+"/diagonal.tmx"))
	Check(map.layers[0].CellFlip(0,0)=ETileFlip.Diagonal,"Imported diagonal flag")
	map=TTiledMap(LoadTileMap(path+"/reserved-bit.tmx"))
	Check(map.layers[0].CellCount()=1,"Nonhex reserved rotation flag cleared")
	For Local file:String=EachIn ["bad-count","bad-gid","bad-size","bad-base64","bad-tint"]
		Local rejected:Int
		Try
			LoadTileMap(path+"/"+file+".tmx")
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Reject invalid or unsupported data: "+file)
	Next
	Check(TTiledReader.Integer("-9223372036854775808")=Long($8000000000000000),"64-bit minimum property")
	Local stream:TStream=ReadStream(path+"/csv.tmx")
	Try
		map=TTiledMap(LoadTileMap(stream,0,path+"/csv.tmx"))
		Check(map.layers[0].CellCount()=4,"Caller-owned stream with relative external resources")
		stream.Seek(0)
		Check(stream.Pos()=0,"Loader leaves caller stream open")
	Finally
		stream.Close()
	End Try
	stream=ReadStream(path+"/bad-count.tmx")
	Try
		Local failed:Int
		Try
			LoadTiledMap(stream,0,path+"/bad-count.tmx")
		Catch error:Object
			failed=True
		End Try
		stream.Seek(0)
		Check(failed And stream.Pos()=0,"Caller stream remains open after failure")
	Finally
		stream.Close()
	End Try
	map=TTiledMap(LoadTileMap("incbin::data/tiled/csv.tmx",0))
	Check(map.layers[0].CellCount()=4,"Stream URLs preserve namespace for TSX and images")
	Local forward:TForwardTileStream=New TForwardTileStream
	forward.SetStream(ReadStream("incbin::data/tiled/csv.tmx"))
	Try
		map=LoadTiledMap(forward,0,"incbin::data/tiled/csv.tmx")
		Check(map.layers[0].CellCount()=4,"Nonseekable input stream")
	Finally
		forward.Close()
	End Try
	MaxIO.Init()
	Try
		Check(MaxIO.Mount(path+"/bundle.zip"),"Mount fixture ZIP")
		map=TTiledMap(LoadTileMap("maps/csv.tmx",0))
		Check(map.layers[0].CellCount()=4,"TMX, TSX and images loaded through BRL.IO ZIP")
		Check(map.importedTilesets[0].properties.GetString("asset")="/maps/sheet.png","Virtual file property path")
		Check(MaxIO.Unmount(path+"/bundle.zip"),"Loader closes owned archive streams")
	Finally
		MaxIO.DeInit()
	End Try
	Print "Tiled loading tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try

Type TForwardTileStream Extends TStreamWrapper
	Method Seek:Long(pos:Long,whence:Int=SEEK_SET_) Override
		Throw "Forward-only stream cannot seek"
	End Method
End Type
