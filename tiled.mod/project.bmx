
Rem
bbdoc: A project member declaration. Treat schema definitions as read-only after loading.
End Rem
Type TTiledMember

	Rem
	bbdoc: Name used to identify this entry.
	End Rem
	Field name:String

	Rem
	bbdoc: Original document's property or field type name.
	End Rem
	Field valueType:String

	Rem
	bbdoc: Named custom class or enum assigned to a Tiled property.
	End Rem
	Field propertyType:String

	Rem
	bbdoc: Default JSON value declared for a custom class member.
	End Rem
	Field defaultValue:TJSON
End Type

Rem
bbdoc: Named Tiled custom class with its declared property members.
End Rem
Type TTiledClass

	Rem
	bbdoc: Identifier associated with this object or definition.
	End Rem
	Field id:Int

	Rem
	bbdoc: Name used to identify this entry.
	End Rem
	Field name:String

	Rem
	bbdoc: Colour span or imported colour metadata associated with this item.
	End Rem
	Field color:String

	Rem
	bbdoc: Tiled object kinds for which the custom class is available.
	End Rem
	Field useAs:String[]

	Rem
	bbdoc: Declared members of the imported custom class.
	End Rem
	Field members:TTiledMember[]

	Rem
	bbdoc: Internal lookup of declared class members by name.
	End Rem
	Field _memberLookup:TTreeMap<String,TTiledMember>=New TTreeMap<String,TTiledMember>
End Type

Rem
bbdoc: An enum schema. Values remain strings or integers in native properties.
about: For integer enums a value is a zero-based index, or a bitmask when valuesAsFlags is True. String flags remain comma-separated labels.
End Rem
Type TTiledEnum

	Rem
	bbdoc: Identifier associated with this object or definition.
	End Rem
	Field id:Int

	Rem
	bbdoc: Name used to identify this entry.
	End Rem
	Field name:String

	Rem
	bbdoc: Tiled enum storage representation, such as string or integer.
	End Rem
	Field storageType:String

	Rem
	bbdoc: Whether enum values can be combined as flags.
	End Rem
	Field valuesAsFlags:Int

	Rem
	bbdoc: Declared enum labels in their source order.
	End Rem
	Field values:String[]
End Type

Rem
bbdoc: Explicit, reusable Tiled project schemas. No project is installed globally.
End Rem
Type TTiledProject

	Rem
	bbdoc: Logical source filename used to resolve relative resources.
	End Rem
	Field sourcePath:String
	Private
	Field classes:TTreeMap<String,TTiledClass>=New TTreeMap<String,TTiledClass>
	Field enums:TTreeMap<String,TTiledEnum>=New TTreeMap<String,TTiledEnum>
	Field defaults:TTreeMap<String,TTileProperties>=New TTreeMap<String,TTileProperties>
	Field loading:TTreeMap<String,Int>=New TTreeMap<String,Int>
	Field work:Int
	Public

	Rem
	bbdoc: Loads a .tiled-project from a path, stream URL or caller-owned stream.
	param: Filename, stream URL or caller-owned readable stream.
	param: Logical source filename used to resolve relative resources for stream input.
	about: sourcePath gives the logical project filename for stream-relative file defaults. Caller streams remain open.
	End Rem
	Function Load:TTiledProject(source:Object,sourcePath:String="")
		Local project:TTiledProject=New TTiledProject
		If Not sourcePath Then sourcePath=String(source)
		If sourcePath Then project.sourcePath=TTiledReader.NormalizePath(sourcePath)
		Try
			Local root:TJSONObject=TTiledDocument.ReadJSON(source)
			Local types:TJSON=root.Get("propertyTypes")
			If Not types Then Return project
			Local array:TJSONArray=TTiledJSON.ArrayValue(types)
			If array.Size()>4096 Then Throw "too many project types"
			Local ids:TTreeMap<Int,Int>=New TTreeMap<Int,Int>,membersRead:Int
			For Local entry:TJSON=EachIn array
				Local value:TJSONObject=TTiledJSON.ObjectValue(entry)
				Local name:String=value.GetString("name"),kind:String=value.GetString("type")
				If Not name Then Throw "project type requires a name"
				If project.ClassType(name) Or project.EnumType(name) Then Throw "duplicate project type: "+name
				Local id:Int=Int(TTiledReader.BoundedInteger(TTiledJSON.Scalar(value.Get("id")),1,2147483647)),existing:Int
				If ids.TryGetValue(id,existing) Then Throw "duplicate project type ID"
				ids.Put(id,1)
				Select kind
					Case "class"
						Local definition:TTiledClass=New TTiledClass
						definition.id=id; definition.name=name; definition.color=value.GetString("color")
						If value.Get("useAs") Then definition.useAs=Strings(value.Get("useAs"))
						Local entries:TJSONArray=TTiledJSON.ArrayValue(value.Get("members"))
						membersRead:+entries.Size()
						If membersRead>65536 Then Throw "too many project members"
						definition.members=New TTiledMember[entries.Size()]
						Local names:TTreeMap<String,Int>=New TTreeMap<String,Int>
						For Local i:Int=0 Until entries.Size()
							Local raw:TJSONObject=TTiledJSON.ObjectValue(entries.Get(i)),member:TTiledMember=New TTiledMember
							member.name=raw.GetString("name"); member.valueType=raw.GetString("type"); member.propertyType=raw.GetString("propertyType")
							member.defaultValue=raw.Get("value")
							If Not member.name Or Not member.defaultValue Then Throw "project member requires name and value"
							If names.TryGetValue(member.name,existing) Then Throw "duplicate class member: "+member.name
							names.Put(member.name,1)
							definition.members[i]=member
							definition._memberLookup.Put(member.name,member)
						Next
						project.classes.Put(name,definition)
					Case "enum",""
						Local definition:TTiledEnum=New TTiledEnum
						definition.id=id; definition.name=name; definition.storageType=value.GetString("storageType")
						If definition.storageType<>"string" And definition.storageType<>"int" Then Throw "invalid enum storage type"
						If value.Get("valuesAsFlags") And Not TJSONBool(value.Get("valuesAsFlags")) Then Throw "enum flags must be Boolean"
						definition.valuesAsFlags=value.GetBool("valuesAsFlags"); definition.values=Strings(value.Get("values"))
						If definition.values.Length>65536 Or (definition.valuesAsFlags And definition.values.Length>31) Then Throw "too many enum values"
						project.enums.Put(name,definition)
					Default; Throw "unsupported project type: "+kind
				End Select
			Next
			' Resolve only after every declaration is known; forward references are valid.
			For Local definition:TTiledClass=EachIn project.classes.Values()
				For Local member:TTiledMember=EachIn definition.members
					Select member.valueType
						Case "class"
							If Not project.ClassType(member.propertyType) Then Throw "unknown member class: "+member.propertyType
						Case "string","int","float","bool","color","file","object"
							If member.propertyType Then
								Local enumeration:TTiledEnum=project.EnumType(member.propertyType)
								If Not enumeration Or enumeration.storageType<>member.valueType Then Throw "unknown or mismatched member enum: "+member.propertyType
							End If
						Default; Throw "unsupported project member type: "+member.valueType
					End Select
				Next
			Next
			For Local name:String=EachIn project.classes.Keys()
				project.CachedDefaults(name,0)
			Next
			project.work=0
			Return project
		Catch error:Object
			Throw "Max2D.Tiled project "+sourcePath+": "+error.ToString()
		End Try
	End Function

	Rem
	bbdoc: Returns a named project class definition, or Null when absent.
	param: Name used to register or look up the item.
	End Rem
	Method ClassType:TTiledClass(name:String)
		Local result:TTiledClass
		classes.TryGetValue(name,result)
		Return result
	End Method

	Rem
	bbdoc: Returns a named project enum definition, or Null when absent.
	param: Name used to register or look up the item.
	End Rem
	Method EnumType:TTiledEnum(name:String)
		Local result:TTiledEnum
		enums.TryGetValue(name,result)
		Return result
	End Method

	Rem
	bbdoc: Returns a named member of a project class, or Null when absent.
	param: Name of the imported custom class.
	param: Name used to register or look up the item.
	End Rem
	Method Member:TTiledMember(className:String,name:String)
		Local definition:TTiledClass=ClassType(className)
		Local member:TTiledMember
		If definition Then definition._memberLookup.TryGetValue(name,member)
		Return member
	End Method

	Rem
	bbdoc: Returns an independent snapshot of resolved class defaults, or an empty collection for an unknown class.
	param: Name used to register or look up the item.
	End Rem
	Method ClassDefaults:TTileProperties(name:String)
		Return CachedDefaults(name,0).Copy()
	End Method

	Rem
	bbdoc: Loads a Tiled map using this project's classes and enum definitions.
	param: Filename, stream URL or caller-owned readable stream.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Logical source filename used to resolve relative resources for stream input.
	param: Optional application font resolver for imported text objects.
	End Rem
	Method LoadMap:TTiledMap(source:Object,flags:Int=FILTEREDIMAGE,sourcePath:String="",fontResolver:TTiledFontResolver=Null)
		Return LoadTiledMap(source,flags,sourcePath,Self,fontResolver)
	End Method

	' Import helpers. Resolution happens only while loading, never while drawing.

	Rem
	bbdoc: Resets counters used to bound recursive project-property expansion.
	End Rem
	Method BeginImport()
		work=0
	End Method

	Rem
	bbdoc: Merges class defaults with instance properties, including nested class values.
	param: Name of the imported custom class.
	param: Property collection to populate or merge.
	param: Current nested-class depth, checked against import limits.
	End Rem
	Method Apply:TTileProperties(className:String,properties:TTileProperties,depth:Int=0)
		If depth>64 Then Throw "project defaults nested too deeply"
		Local result:TTileProperties=CachedDefaults(className,depth).Copy()
		result.Overlay(properties)
		For Local name:String=EachIn result.Names()
			work:+1
			If work>1048576 Then Throw "project property expansion limit exceeded"
			Local property:TTileProperty=result.Get(name)
			If property.Kind()=ETilePropertyType.ClassValue Then
				Local members:TTileProperties=Apply(property.ClassName(),property.AsClass(),depth+1)
				result.SetValue(name,TTileProperty.FromClass(property.ClassName(),members).WithMetadata(property.ValueType(),property.CustomType()))
			End If
		Next
		Return result
	End Method

	Private
	Method CachedDefaults:TTileProperties(name:String,depth:Int)
		Local result:TTileProperties
		If defaults.TryGetValue(name,result) Then Return result
		Local definition:TTiledClass=ClassType(name)
		If Not definition Then Return New TTileProperties
		Local active:Int
		If loading.TryGetValue(name,active) Then Throw "cyclic project class: "+name
		If depth>64 Then Throw "project defaults nested too deeply"
		loading.Put(name,1)
		Local root:TxmlNode=TxmlNode.newNode("defaults")
		Try
			Local parent:TxmlNode=root.addChild("properties"),adapter:TTiledJSON=New TTiledJSON
			adapter.project=Self
			For Local member:TTiledMember=EachIn definition.members
				adapter.Property(parent,member.name,member.defaultValue,member.valueType,member.propertyType)
			Next
			Local raw:TTileProperties=New TTileProperties
			New TTiledReader.ReadProperties(root,raw,ExtractDir(sourcePath))
			result=Apply("",raw,depth+1)
			defaults.Put(name,result)
			Return result
		Finally
			root.Free(); loading.Remove(name)
		End Try
	End Method

	Function Strings:String[](value:TJSON)
		Local array:TJSONArray=TTiledJSON.ArrayValue(value)
		If array.Size()>65536 Then Throw "too many project strings"
		Local result:String[]=New String[array.Size()]
		For Local i:Int=0 Until result.Length
			Local item:TJSONString=TJSONString(array.Get(i))
			If Not item Then Throw "expected project string"
			result[i]=item.Value()
		Next
		Return result
	End Function

End Type
