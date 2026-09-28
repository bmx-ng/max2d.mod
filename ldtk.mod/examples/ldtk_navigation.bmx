SuperStrict
Framework Max2D.LDTK
Import BRL.StandardIO

' Console example: inspect a project and explicitly choose which levels to load.
' Arguments: project.ldtk [level identifier or IID] [another level to load ...]
Try
	Local path:String=AppDir+"/maps/AutoLayers_1_basic.ldtk"
	If AppArgs.Length>1 Then path=AppArgs[1]
	Local project:TLDTKProject=TLDTKProject.Load(path)
	For Local info:TLDTKLevelInfo=EachIn project.levels
		Print info.identifier+" ["+info.iid+"] in world "+info.worldIID
		For Local neighbour:TLDTKNeighbour=EachIn info.neighbours
			Local target:TLDTKLevelInfo=neighbour.Level(project)
			Local label:String=neighbour.levelIID+" (not in this project)"
			If target Then label=target.identifier+" ["+target.iid+"]"
			Print "  "+neighbour.direction+" -> "+label
		Next
	Next

	Local registry:TLDTKLevelRegistry=TLDTKLevelRegistry.Create(project)
	Local selected:String[]
	If AppArgs.Length>2 Then selected=AppArgs[2..]
	If Not selected.Length Then selected=[project.levels[0].iid]
	For Local selector:String=EachIn selected
		Local info:TLDTKLevelInfo=project.Level(selector)
		If Not info Then Throw "Unknown level: "+selector
		If Not registry.LoadedLevel(info.iid) Then registry.Register(project.LoadLevel(info.iid,0,False))
	Next

	For Local selector:String=EachIn selected
		Local map:TLDTKMap=registry.LoadedLevel(project.Level(selector).iid)
		Print "Loaded: "+map.level.identifier
		For Local field:TLDTKField=EachIn map.fields
			DescribeField(field,registry,"  ")
		Next
		For Local entity:TLDTKEntity=EachIn map.entities
			Print "  Entity: "+entity.identifier+" ["+entity.iid+"]"
			For Local field:TLDTKField=EachIn entity.fields
				DescribeField(field,registry,"    ")
			Next
		Next
	Next
	registry.Clear()
Catch error:Object
	Print error.ToString()
	EndWithCode(1)
End Try

Function DescribeField(field:TLDTKField,registry:TLDTKLevelRegistry,prefix:String)
	If field.IsNull() Then
		Print prefix+field.name+" = null"
	Else If field.valueType.StartsWith("Array<") Then
		Print prefix+field.name+" ("+field.Count()+" items)"
		For Local i:Int=0 Until field.Count()
			DescribeField(field.Item(i),registry,prefix+"  ")
		Next
	Else
		Select field.valueType
			Case "Point"
				Local point:TLDTKPoint=field.AsPoint()
				Print prefix+field.name+" = cell "+point.column+", "+point.row
			Case "Tile"
				Local tile:TLDTKTileReference=field.AsTile()
				Print prefix+field.name+" = tileset "+tile.tilesetUID+", source "+tile.x+", "+tile.y+", "+tile.width+" x "+tile.height
			Case "EntityRef"
				Local reference:TLDTKEntityReference=field.AsEntityReference()
				Local target:TLDTKEntity=registry.Resolve(reference)
				Local label:String="unresolved (not loaded or no matching entity)"
				If target Then label=target.identifier
				Print prefix+field.name+" -> "+reference.levelIID+" / "+reference.entityIID+": "+label
			Default
				If TJSONString(field.value) Then
					Print prefix+field.name+" = "+field.AsString()
				Else If TJSONInteger(field.value) Then
					Print prefix+field.name+" = "+field.AsInt()
				Else If TJSONReal(field.value) Then
					Print prefix+field.name+" = "+field.AsFloat()
				Else If TJSONBool(field.value) Then
					Print prefix+field.name+" = "+field.AsBool()
				End If
		End Select
	End If
End Function
