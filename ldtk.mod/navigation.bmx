Rem
bbdoc: An exported neighbouring level. Multiple neighbours can share a direction; no connectivity is inferred.
about: direction retains LDtk's n/s/e/w, diagonal, overlap (o) and depth (< or >) codes. Unknown future codes are preserved.
End Rem
Type TLDTKNeighbour
	Field direction:String,levelIID:String
	Method Level:TLDTKLevelInfo(project:TLDTKProject)
		If project Then Return project.LevelByIID(levelIID)
	End Method
End Type

Rem
bbdoc: The exported world, level, layer and entity IIDs of an entity reference.
End Rem
Type TLDTKEntityReference
	Field worldIID:String,levelIID:String,layerIID:String,entityIID:String
	Rem
	bbdoc: Finds matching level metadata without loading the level. Returns Null for unknown levels or a different world IID.
	End Rem
	Method Level:TLDTKLevelInfo(project:TLDTKProject)
		If Not project Then Return Null
		Local info:TLDTKLevelInfo=project.LevelByIID(levelIID)
		If info And info.worldIID=worldIID Then Return info
	End Method
End Type

Rem
bbdoc: An explicit registry of loaded levels from one project. No method loads files or resolves references by entity name.
about: Register keeps a strong map reference until Unregister or Clear. Unresolved references return Null. The registry does not retain or cache resolved entity references.
End Rem
Type TLDTKLevelRegistry
	Private
	Field _project:TLDTKProject
	Field _maps:TTreeMap<String,TLDTKMap>=New TTreeMap<String,TLDTKMap>
	Public
	Function Create:TLDTKLevelRegistry(project:TLDTKProject)
		If Not project Then Throw "Max2D.LDTK: a registry requires a project"
		Local registry:TLDTKLevelRegistry=New TLDTKLevelRegistry
		registry._project=project
		Return registry
	End Function
	Method Register(map:TLDTKMap)
		If Not _project Or Not map Or Not map.level Then Throw "Max2D.LDTK: invalid registry or map"
		If _project.LevelByIID(map.level.iid)<>map.level Then Throw "Max2D.LDTK: registry maps must be loaded from the same project instance"
		Local current:TLDTKMap=LoadedLevel(map.level.iid)
		If current And current<>map Then Throw "Max2D.LDTK: unregister the previous instance of this level before registering its replacement"
		_maps.Put(map.level.iid,map)
	End Method
	Method Unregister(levelIID:String)
		_maps.Remove(levelIID)
	End Method
	Method Clear()
		_maps.Clear()
	End Method
	Method LoadedLevel:TLDTKMap(levelIID:String)
		Local map:TLDTKMap
		_maps.TryGetValue(levelIID,map)
		Return map
	End Method
	Method Resolve:TLDTKEntity(reference:TLDTKEntityReference)
		If Not reference Or Not reference.Level(_project) Then Return Null
		Local map:TLDTKMap=LoadedLevel(reference.levelIID)
		If Not map Then Return Null
		Local entity:TLDTKEntity=map.Entity(reference.entityIID)
		If entity And entity.layer.iid=reference.layerIID Then Return entity
	End Method
End Type
