SuperStrict
Framework Max2D.Tiled
Import BRL.StandardIO
Import BRL.IO
Import BRL.RamStream
Incbin "data/tiled/project/game.tiled-project"
Incbin "data/tiled/project/maps/main.tmj"
Incbin "data/tiled/project/tiles.tsj"
Incbin "data/tiled/project/templates/enemy.json"
Incbin "data/tiled/sheet.png"
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Type TForwardProjectStream Extends TStream
	Field source:TStream
	Method Read:Long(buffer:Byte Ptr,count:Long) Override
		Return source.Read(buffer,Min(count,5:Long))
	End Method
	Method Eof:Int() Override
		Return source.Eof()
	End Method
End Type
Try
	Local path:String=RealPath(AppArgs[1])+"/project"
	Local project:TTiledProject=TTiledProject.Load(path+"/game.tiled-project")
	Check(project.ClassType("Enemy").members.Length=6 And project.ClassType("Enemy").useAs.Length=6,"Class definitions")
	Local flags:TTiledEnum=project.EnumType("Ability")
	Check(flags.valuesAsFlags And flags.storageType="int" And flags.values[2]="Fly","Enum flag definition")
	Check(project.EnumType("Tags").valuesAsFlags And project.EnumType("Mode").storageType="string","String enum definitions")
	Local defaults:TTileProperties=project.ClassDefaults("Enemy")
	Check(defaults.GetClass("stats").GetClass("combat").GetLong("damage")=3,"Forward references and nested defaults")
	Check(defaults.GetClass("stats").GetString("sound")=RealPath(path+"/audio/default.wav"),"Project-relative default file")
	defaults.GetClass("stats").SetDouble("speed",99)
	Check(project.ClassDefaults("Enemy").GetClass("stats").GetDouble("speed")=2.5,"Independent default snapshots")
	For Local extension:String=EachIn ["tmj","tmx"]
		Local map:TTiledMap=project.LoadMap(path+"/maps/main."+extension,0)
		Check(map.properties.GetString("title")="Schema world","Map class defaults")
		Check(map.importedLayers[0].properties.GetBool("solid") And map.layers[0].properties.GetBool("solid"),"Group and layer class defaults")
		Check(map.importedTilesets[0].properties.GetString("category")="Actors","Tileset class defaults")
		Local tileDefaults:TTileProperties=map.tileset.Properties(map.importedTilesets[0].NativeID(0))
		Check(tileDefaults.GetLong("health")=80 And tileDefaults.GetBool("enabled") And tileDefaults.GetClass("stats").GetClass("combat").GetLong("damage")=7,"Tile class defaults and serialized overrides")
		Local one:TTileObject=map.ObjectByID(1),two:TTileObject=map.ObjectByID(2),three:TTileObject=map.ObjectByID(3),four:TTileObject=map.ObjectByID(4)
		Check(one.properties.GetLong("health")=0 And two.properties.GetLong("health")=60 And three.properties.GetLong("health")=80 And four.properties.GetLong("health")=100,"Instance > template > tile > schema precedence")
		Check(Not one.properties.GetBool("enabled") And one.properties.GetString("tag")="","False and empty overrides")
		Local stats:TTileProperties=one.properties.GetClass("stats")
		Check(stats.Get("combat").ClassName()="Combat" And stats.GetClass("combat").GetLong("damage")=9 And stats.GetClass("combat").GetDouble("range")=4,"Nested types and partial override merging")
		Check(stats.GetString("sound")=RealPath(path+"/maps/instance.wav"),"Map-relative nested file override")
		Check(two.properties.GetClass("stats").GetString("sound")=RealPath(path+"/templates/template.wav"),"Template-relative nested file override")
		Check(stats.Get("sound").ValueType()="file" And stats.Get("target").ValueType()="object" And map.ObjectByID(Int(stats.GetLong("target")))=two,"Recovered nested file and object types")
		Check(three.properties.GetClass("stats").GetClass("combat").GetLong("damage")=7,"Tile partial nested override")
		Check(map.ObjectByID(5).properties.GetClass("stats").GetClass("combat").GetDouble("range")=4,"Template nested members survive partial instance override")
		Check(two.properties.Get("mode").CustomType()="Mode" And two.properties.Get("flags").CustomType()="Ability","Schema enum metadata")
		If extension="tmj" Then
			Check(one.properties.GetLong("flags")=5 And one.properties.Get("flags").CustomType()="Ability","Integer enum bitmask preserved")
			Check(one.properties.GetString("labels")="a,b" And one.properties.Get("labels").CustomType()="Tags","String enum flags preserved")
			Check(stats.GetString("mode")="Chase" And stats.Get("mode").CustomType()="Mode","Nested JSON enum metadata")
		End If
		stats.GetClass("combat").SetLong("damage",99)
		Check(two.properties.GetClass("stats").GetClass("combat").GetLong("damage")=7 And tileDefaults.GetClass("stats").GetClass("combat").GetLong("damage")=7 And project.ClassDefaults("Enemy").GetClass("stats").GetClass("combat").GetLong("damage")=3,"Independent instances, tile defaults and project cache")
	Next
	Local plain:TTiledMap=LoadTiledMap(path+"/maps/main.tmj",0)
	Check(Not plain.properties.Contains("title") And Not plain.ObjectByID(4).properties.Contains("health"),"Schema remains optional and never global")
	Local file:TStream=ReadStream(path+"/game.tiled-project")
	Try
		Local forward:TForwardProjectStream=New TForwardProjectStream
		forward.source=file
		project=TTiledProject.Load(forward,path+"/game.tiled-project")
		Check(file.Pos()>0 And project.ClassDefaults("Stats").GetString("sound")=RealPath(path+"/audio/default.wav"),"Forward-only caller stream remains open")
	Finally
		file.Close()
	End Try
	project=TTiledProject.Load("incbin::data/tiled/project/game.tiled-project")
	plain=project.LoadMap("incbin::data/tiled/project/maps/main.tmj",0)
	Check(plain.ObjectByID(4).properties.GetClass("stats").GetString("sound")="incbin::data/tiled/project/audio/default.wav","Embedded project and resource graph")
	MaxIO.Init()
	Try
		Check(MaxIO.Mount(path+"/project.zip"),"Mount schema ZIP")
		project=TTiledProject.Load("project/game.tiled-project")
		plain=project.LoadMap("project/maps/main.tmj",0)
		Check(plain.ObjectByID(2).properties.GetLong("health")=60,"Project, templates and maps from ZIP")
		Check(MaxIO.Unmount(path+"/project.zip"),"Project resource streams are closed")
	Finally
		MaxIO.DeInit()
	End Try
	For Local name:String=EachIn ["cycle","missing","duplicate","bad-storage"]
		Local rejected:Int
		file=ReadStream(path+"/"+name+".tiled-project")
		Try
			Try
				TTiledProject.Load(file,path+"/"+name+".tiled-project")
			Catch error:Object
				rejected=True
			End Try
			Check(rejected And file.Pos()>0,"Reject invalid schema and keep caller stream: "+name)
		Finally
			file.Close()
		End Try
	Next
	Print "Tiled project tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
