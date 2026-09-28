SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.LDTK
Import BRL.StandardIO

' Optional compatibility sweep over an external checkout of LDtk's sample directory.
' Arguments: sample directory, optional LdtkIcons PNG, optional NuclearBlaze PNG, optional capture directory.
If AppArgs.Length<2 Then
	Print "Usage: ldtk_upstream sample-directory [icons.png] [NuclearBlaze.png] [capture-directory]"
	EndWithCode(1)
End If
Local root:String=AppArgs[1],icons:TPixmap,nuclear:TPixmap
If AppArgs.Length>2 Then icons=LoadPixmap(AppArgs[2])
If AppArgs.Length>3 Then nuclear=LoadPixmap(AppArgs[3])
Local captures:String
If AppArgs.Length>4 Then captures=AppArgs[4]
Graphics 256,192
Local target:TRenderImage=CreateRenderImage(256,192,0)
SetRenderImage(target)
Local projects:Int,levels:Int,failed:Int,fields:Int,references:Int,unresolved:Int
For Local name:String=EachIn LoadDir(root)
	If ExtractExt(name).ToLower()<>"ldtk" Then Continue
	projects:+1
	Try
		Local project:TLDTKProject=TLDTKProject.Load(root+"/"+name)
		If icons Then project.SetEmbeddedAtlas("LdtkIcons",icons)
		If nuclear And name="WorldMap_Free_layout.ldtk" Then project.SetTilesetPixmap(73,nuclear)
		Local registry:TLDTKLevelRegistry=TLDTKLevelRegistry.Create(project)
		For Local info:TLDTKLevelInfo=EachIn project.levels
			Try
				Local map:TLDTKMap=project.LoadLevel(info.iid,0)
				registry.Register(map)
				PushMax2DState()
				Try
					ScaleCoordinates(Min(256.0/info.width,192.0/info.height),Min(256.0/info.width,192.0/info.height))
					SetClsColor(20,20,20); Cls(); map.Draw()
					Local capture:TPixmap=GrabPixmap(0,0,256,192)
					If captures Then SavePixmapPNG(capture,captures+"/"+StripExt(name)+"_"+info.uid+".png")
				Finally
					PopMax2DState()
				End Try
				levels:+1
				Print "PASS "+name+" / "+info.identifier
			Catch error:Object
				failed:+1
				Print "FAIL "+name+" / "+info.identifier+": "+error.ToString()
			End Try
		Next
		For Local info:TLDTKLevelInfo=EachIn project.levels
			Local map:TLDTKMap=registry.LoadedLevel(info.iid)
			If Not map Then Continue
			For Local field:TLDTKField=EachIn map.fields
				InspectField(field,registry,fields,references,unresolved)
			Next
			For Local entity:TLDTKEntity=EachIn map.entities
				For Local field:TLDTKField=EachIn entity.fields
					InspectField(field,registry,fields,references,unresolved)
				Next
			Next
		Next
	Catch error:Object
		failed:+1
		Print "FAIL "+name+": "+error.ToString()
	End Try
Next
SetRenderImage(Null); EndGraphics()
Print projects+" projects; "+levels+" rendered levels; "+fields+" field values; "+references+" entity references; "+unresolved+" unresolved; "+failed+" failures"
If failed Or unresolved Or Not projects Then EndWithCode(1)
Print "LDtk upstream compatibility checks passed"

Function InspectField(field:TLDTKField,registry:TLDTKLevelRegistry,fields:Int Var,references:Int Var,unresolved:Int Var)
	fields:+1
	If field.IsNull() Then Return
	If field.valueType.StartsWith("Array<") Then
		For Local i:Int=0 Until field.Count()
			InspectField(field.Item(i),registry,fields,references,unresolved)
		Next
		Return
	End If
	Select field.valueType
		Case "Point"; field.AsPoint()
		Case "Tile"; field.AsTile()
		Case "EntityRef"
			references:+1
			If Not registry.Resolve(field.AsEntityReference()) Then unresolved:+1
		Default
			If TJSONString(field.value) Then
				field.AsString()
			Else If TJSONInteger(field.value) Then
				field.AsInt()
			Else If TJSONReal(field.value) Then
				field.AsFloat()
			Else If TJSONBool(field.value) Then
				field.AsBool()
			End If
	End Select
End Function
