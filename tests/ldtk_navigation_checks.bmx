Function CheckLDTKNavigation(path:String)
	Local project:TLDTKProject=TLDTKProject.Load(path+"/navigation.ldtk")
	Check(project.Level("start").identifier="Start" And project.LevelByIID("unknown")=Null,"Metadata-only lookup")
	Check(project.Level("absent").externalPath.EndsWith("not-loaded.ldtkl"),"Metadata does not open external levels")
	Local rejected:Int
	Try
		project.Level("Room")
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Duplicate names across worlds require IID")
	Local info:TLDTKLevelInfo=project.Level("Start")
	Check(info.neighbours.Length=6 And info.neighbours[0].direction="e" And info.neighbours[1].direction="e","Multiple neighbours in one direction retained")
	Check(info.neighbours[2].direction="nw" And info.neighbours[3].direction="o" And info.neighbours[4].direction="<" And info.neighbours[5].direction=">","Diagonal/overlap/depth codes retained")
	Check(info.neighbours[0].Level(project)=project.LevelByIID("room"),"Neighbour metadata lookup")
	Local map:TLDTKMap=project.LoadLevel("start",0,False),entity:TLDTKEntity=map.Entity("player")
	Check(map.GetField("spawn").AsPoint().column=4 And entity.GetField("missing")=Null,"Level/entity field lookup")
	Check(entity.GetField("count").AsInt()=9223372036854775807:Long And entity.GetField("enabled").AsBool() And entity.GetField("speed").AsFloat()=4 And entity.GetField("name").AsString()="Door","Scalar accessors retain numeric range")
	Local route:TLDTKField=entity.GetField("route")
	Check(route.Count()=3 And route.Item(0).AsPoint().row=3 And route.Item(1).IsNull() And route.Item(1).AsPoint()=Null,"Point array with null element")
	Check(route.Item(0)=route.Item(0) And route.Item(0).AsPoint()=route.Item(0).AsPoint(),"Array items and structured conversions are cached")
	Check(entity.GetField("empty").Count()=0 And entity.GetField("labels").Item(1).AsString()="closed","Empty and scalar arrays")
	Local tile:TLDTKTileReference=entity.GetField("icon").AsTile()
	Check(tile.tilesetUID=1 And tile.x=2 And tile.width=2 And tile=entity.GetField("icon").AsTile(),"Tile metadata is cached without loading artwork")
	Local reference:TLDTKEntityReference=entity.GetField("target").AsEntityReference()
	Check(reference.Level(project)=project.LevelByIID("room") And entity.GetField("targets").Item(1).AsEntityReference()=Null,"Reference metadata and nullable arrays")
	Local registry:TLDTKLevelRegistry=TLDTKLevelRegistry.Create(project)
	registry.Register(map); registry.Register(map)
	Check(registry.Resolve(reference)=Null And registry.LoadedLevel("room")=Null,"Registry does not load referenced level")
	Local room:TLDTKMap=project.LoadLevel(reference.levelIID,0,False)
	registry.Register(room)
	Check(registry.Resolve(reference)=room.Entity("player") And registry.Resolve(reference)<>entity,"Resolution honours level IID despite matching entity IID")
	reference.layerIID="wrong"
	Check(registry.Resolve(reference)=Null,"Wrong layer IID does not resolve")
	reference.layerIID="layer-room"; reference.worldIID="wrong"
	Check(registry.Resolve(reference)=Null,"Wrong world IID does not resolve")
	reference.worldIID="world-a"
	registry.Unregister("room")
	Check(registry.Resolve(reference)=Null,"Unregistered maps no longer resolve")
	registry.Register(room); registry.Clear()
	Check(registry.LoadedLevel("start")=Null And registry.Resolve(reference)=Null,"Clear releases registered maps")
	Local bad:TLDTKField=New TLDTKField
	bad.name="badPoint"; bad.valueType="Point"
	Local badValue:TJSONObject=New TJSONObject.Create()
	badValue.Set("cx","wrong"); badValue.Set("cy",0); bad.value=badValue
	For Local failure:Int=0 Until 6
		rejected=False
		Try
			Select failure
				Case 0; route.Item(3)
				Case 1; route.Item(0).AsTile()
				Case 2; bad.AsPoint()
				Case 3; entity.GetField("enabled").AsInt()
				Case 4; registry.Register(TLDTKProject.Load(path+"/navigation.ldtk").LoadLevel("start",0,False))
				Case 5; registry.Register(map); registry.Register(project.LoadLevel("start",0,False))
			End Select
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Invalid typed access or foreign registry map rejected: "+failure)
	Next
End Function
