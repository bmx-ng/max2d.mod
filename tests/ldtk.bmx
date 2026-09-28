SuperStrict
Framework Max2D.LDTK
Import BRL.StandardIO
Import BRL.IO
Import BRL.RamStream
Incbin "data/ldtk/external.ldtk"
Incbin "data/ldtk/levels/first.ldtkl"
Incbin "data/ldtk/tiles.png"

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Try
	Local path:String=RealPath(AppArgs[1])
	For Local name:String=EachIn ["single","external","worlds"]
		Local map:TLDTKMap=TLDTKMap(LoadTileMap(path+"/"+name+".ldtk",0))
		Check(map.level.identifier="First" And map.level.worldX=64 And map.level.worldY=-32 And map.level.worldDepth=2,"Level metadata")
		Check(map.properties.GetLong("difficulty")=3 And map.layers.Length=5,"Fields and layers")
		Check(map.layers[0].name="Tiles" And map.layers[4].name="Hidden" And Not map.layers[4].visible,"Bottom-to-top native layer order")
		Local layer:TLDTKLayer=map.Layer("Tiles")
		Check(layer.layer.objects.Length=3 And layer.layer.objects[1].opacity=0.5,"Stacked tiles retain order and alpha")
		Check(layer.layer.objects[2].flip=(ETileFlip.Horizontal|ETileFlip.Vertical),"Tile reflections")
		Check(map.Layer("Logic").IntValue(0,0)=1 And map.Layer("Logic").IntValue(0,1)=2 And map.Layer("Logic").IntValue(-1,0)=0,"IntGrid data")
		Check(map.Layer("Logic").grid.TileWidth()=4 And map.Layer("Entities").grid.TileWidth()=8,"Independent layer grids")
		Local entity:TLDTKEntity=map.Entity("player")
		Check(entity.object.x=6 And entity.object.y=5 And entity.object.width=4 And entity.object.height=6,"Entity pivot")
		Check(entity.object.properties.GetLong("hp")=12 And entity.object.properties.GetDouble("speed")=4 And entity.object.properties.GetBool("alive"),"Scalar fields")
		Check(entity.object.properties.GetString("asset")=RealPath(path+"/sounds/step.wav"),"External level fields resolve beside project")
		Check(entity.fields.Length=7 And TJSONArray(entity.fields[5].value).Size()=2 And TJSONNull(entity.fields[6].value)<>Null,"Structured, array and null fields retained")
		Check(entity.layer.layer.QueryObjectsAtPoint(8,8).count=1,"Native geometry query with layer offset")
	Next
	Local visuals:TLDTKMap=LoadLDTKMap(path+"/visuals.ldtk","",0)
	Check(visuals.background.sourceX=0.5 And visuals.background.width=12 And visuals.background.height=4,"Fractional background crop and scaling")
	Check(visuals.Layer("Scaled").layer.drawScale=0.5 And visuals.Layer("Unscaled").layer.drawScale=1,"LDtk scaling convention")
	Check(visuals.Layer("Scaled").layer.offsetX=2,"Parallax preserves nominal offsets")
	Local artMap:TLDTKMap=LoadLDTKMap(path+"/entity-art.ldtk","",0)
	Check(artMap.entities.Length=7 And artMap.Entity("Cover").artwork.mode="Cover","Entity artwork modes")
	Local uncropped:TLDTKEntity=artMap.Entity("FullSizeUncropped")
	Check(uncropped.object.width=2 And uncropped.object.x=44 And uncropped.object.tile=0,"Artwork leaves gameplay bounds unchanged")
	Check(uncropped.layer.layer.QueryObjectsAtPoint(42,3).count=0,"Uncropped art does not expand object queries")
	Check(LoadLDTKMap(path+"/embedded-art.ldtk","",0,"",False).Entity("Stretch").artwork=Null,"Metadata-only loading skips image resolution")
	Local embedded:TLDTKProject=TLDTKProject.Load(path+"/embedded-art.ldtk")
	embedded.SetEmbeddedAtlas("TestIcons",LoadPixmap(path+"/tiles.png"))
	Check(embedded.LoadLevel("",0).Entity("Stretch").artwork<>Null,"Caller-supplied embedded atlas")
	Local project:TLDTKProject=TLDTKProject.Load(path+"/multi.ldtk")
	Check(project.levels.Length=2 And project.LoadLevel("Second").level.iid="level-second","Select named level")
	Local rejected:Int
	Try
		project.LoadLevel()
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Multi-level selection must be explicit")
	Local stream:TStream=ReadStream(path+"/external.ldtk")
	Try
		Local forward:TForwardLDTKStream=New TForwardLDTKStream
		forward.SetStream(stream)
		Check(LoadLDTKMap(forward,"",0,path+"/external.ldtk").layers.Length=5 And stream.Pos()>0,"Forward-only caller stream remains open")
	Finally
		stream.Close()
	End Try
	Check(LoadLDTKMap("incbin::data/ldtk/external.ldtk").entities.Length=1,"Embedded project, external level and tilesheet")
	MaxIO.Init()
	Try
		Check(MaxIO.Mount(path+"/project.zip"),"Mount LDtk ZIP")
		Check(LoadLDTKMap("maps/external.ldtk").Layer("Logic").IntValue(1,1)=1,"ZIP resources")
		Check(LoadLDTKMap("maps/visuals.ldtk").background.sourceX=0.5,"ZIP background resource and fractional crop")
		Check(LoadLDTKMap("maps/entity-art.ldtk").entities[0].artwork<>Null,"ZIP entity artwork")
		Check(LoadLDTKMap("maps/repeat-background.ldtk").background.repeat,"ZIP repeating background")
		Check(MaxIO.Unmount(path+"/project.zip"),"Importer closes owned resources")
	Finally
		MaxIO.DeInit()
	End Try
	For Local name:String=EachIn ["bad-intgrid","bad-source","bad-opacity","bad-type","bad-parallax","bad-bg","bad-crop","bad-entity-mode","bad-entity-source","bad-nine-slice","embedded-art"]
		rejected=False
		stream=ReadStream(path+"/"+name+".ldtk")
		Try
			LoadLDTKMap(stream,"",0,path+"/"+name+".ldtk")
		Catch error:Object
			rejected=error.ToString().Contains("Max2D.LDTK:")
		End Try
		Check(stream.Pos()>0,"Failure leaves caller stream open")
		stream.Close()
		Check(rejected,"Reject "+name)
	Next
	Local overrideProject:TLDTKProject=TLDTKProject.Load(path+"/external.ldtk")
	Local tilesets:TJSONArray=TJSONArray(TJSONObject(overrideProject.data.Get("defs")).Get("tilesets"))
	TJSONObject(tilesets.Get(0)).Set("relPath","not-present.aseprite")
	overrideProject.SetTilesetPixmap(1,LoadPixmap(path+"/tiles.png"))
	Check(overrideProject.LoadLevel("",0).Layer("Tiles").layer.objects.Length=3,"Replacement tileset pixels bypass unavailable decoder/path")
	Check(TJSONObject(tilesets.Get(0)).GetString("relPath")="not-present.aseprite","Supplying pixels does not rewrite project paths")
	rejected=False
	Try
		overrideProject.SetTilesetPixmap(999,LoadPixmap(path+"/tiles.png"))
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Unknown replacement tileset UID rejected")
	CheckLDTKNavigation(path)
	Print "LDtk importer tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try

Type TForwardLDTKStream Extends TStreamWrapper
	Method Seek:Long(pos:Long,whence:Int=SEEK_SET_) Override
		Throw "Cannot seek"
	End Method
End Type

Include "ldtk_navigation_checks.bmx"
