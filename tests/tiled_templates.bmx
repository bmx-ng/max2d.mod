SuperStrict
Framework Max2D.Tiled
Import BRL.StandardIO
Import BRL.IO
Import BRL.RamStream
Incbin "data/tiled/template-auto.tmx"
Incbin "data/tiled/templates/tile.tx"
Incbin "data/tiled/tiles/basic.tsx"
Incbin "data/tiled/sheet.png"
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Try
	Local path:String=RealPath(AppArgs[1]).Replace("\","/")
	Local map:TTiledMap=LoadTiledMap(path+"/template-map.tmx",0)
	Local first:TTileObject=map.ObjectByID(1),second:TTileObject=map.ObjectByID(2)
	Check(first.name="Guard" And first.className="Enemy" And first.width=8 And first.height=4 And first.visible,"Template attributes and instance overrides")
	Check(first.x=10 And first.y=20 And Abs(first.yx-1)<0.00001 And Not second.visible,"Placement, inherited rotation and visibility")
	Check(map.ObjectByID(3).x=0 And map.ObjectByID(3).y=0 And Not map.ObjectByID(999),"Template identity and coordinates do not leak")
	Local stats:TTileProperty=first.Property("stats")
	Check(stats.Kind()=ETilePropertyType.ClassValue And stats.ClassName()="EnemyStats","Structured class metadata")
	Local members:TTileProperties=stats.AsClass(),combat:TTileProperties=members.GetClass("combat")
	Check(members.GetDouble("speed")=2.5 And combat.GetLong("health")=50 And combat.GetLong("damage")=3,"Nested overrides retain unspecified template members")
	Check(members.GetString("sound")=RealPath(path+"/instance.wav"),"Instance file property base")
	Check(second.properties.GetClass("stats").GetString("sound")=RealPath(path+"/templates/guard.wav"),"Template file property base")
	Check(first.Property("label").AsString()="Keep & protect" And map.ObjectByID(Int(first.Property("target").AsLong()))=second,"Text content and object references")
	combat.SetLong("health",99)
	Check(second.properties.GetClass("stats").GetClass("combat").GetLong("health")=25,"Template instances own nested member storage")
	Local copied:TTileProperties=first.properties.Copy()
	copied.GetClass("stats").GetClass("combat").SetLong("health",1)
	Check(combat.GetLong("health")=99,"Native properties deep copy")
	Local stored:TTileProperties=New TTileProperties
	stored.SetClass("snapshot","EnemyStats",members)
	combat.SetLong("health",77)
	Check(stored.GetClass("snapshot").GetClass("combat").GetLong("health")=99,"SetClass snapshots its input")
	Local tile:TTileObject=map.ObjectByID(4)
	Check(tile.tile=map.importedTilesets[0].NativeID(0) And tile.flip=ETileFlip.Horizontal And map.importedTilesets.Length=1,"Template GID remapping and existing TSX reuse")
	map=LoadTiledMap(path+"/template-auto.tmx",0)
	Check(map.importedTilesets.Length=1 And map.layers[0].objects.Length=2 And map.ObjectByID(1).tile=1,"Template-only external tileset loaded once")
	map=LoadTiledMap("incbin::data/tiled/template-auto.tmx",0)
	Check(map.ObjectByID(2).tile=1,"Template and TSX through embedded stream namespace")
	Local stream:TStream=ReadStream(path+"/template-map.tmx")
	Try
		map=LoadTiledMap(stream,0,path+"/template-map.tmx")
		Check(stream.Pos()>0 And map.ObjectByID(1).name="Guard","Caller-owned stream remains open")
	Finally
		stream.Close()
	End Try
	MaxIO.Init()
	Try
		Check(MaxIO.Mount(path+"/templates.zip"),"Mount template archive")
		map=LoadTiledMap("maps/template-map.tmx",0)
		Check(map.ObjectByID(1).properties.GetClass("stats").GetClass("combat").GetLong("health")=50,"Templates and nested properties through BRL.IO ZIP")
		Check(MaxIO.Unmount(path+"/templates.zip"),"Template streams close after import")
	Finally
		MaxIO.DeInit()
	End Try
	map=LoadTiledMap(path+"/class-tile.tmx",0)
	members=map.ObjectByID(1).properties.GetClass("stats")
	Check(members.GetLong("health")=50 And members.GetDouble("speed")=2.5,"Tile class defaults merged with object overrides")
	members.SetDouble("speed",7)
	Check(map.ObjectByID(2).properties.GetClass("stats").GetDouble("speed")=2.5 And map.tileset.Properties(1).GetClass("stats").GetDouble("speed")=2.5,"Tile class defaults are isolated per object")
	For Local name:String=EachIn ["template-cycle","bad-class","object-template"]
		Local rejected:Int
		Try
			LoadTiledMap(path+"/"+name+".tmx",0)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Reject invalid template/class input: "+name)
	Next
	Print "Tiled template tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
