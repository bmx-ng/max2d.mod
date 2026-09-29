' Import-time XML expansion. Cached templates are immutable and freed after loading.

Rem
bbdoc: Helpers for loading and expanding Tiled object templates.
End Rem
Type TTiledTemplates

	Rem
	bbdoc: Copies template XML into a target node while enforcing import limits.
	param: Importer state used for resource lookup and allocation limits.
	param: Source data or object to read.
	param: Destination XML node to populate.
	param: Current template-nesting depth, checked against import limits.
	End Rem
	Function CopyInto(reader:TTiledReader,source:TxmlNode,target:TxmlNode,depth:Int=0)
		reader.templateNodes:+1
		If depth>256 Or reader.templateNodes>1048576 Then Throw "template expansion limit exceeded"
		For Local i:Int=0 Until source.getAttributeCount()
			Local name:String,value:String=source.getAttributeByIndex(i,name)
			target.setAttribute(name,value)
		Next
		Local child:TxmlNode=TxmlNode(source.getFirstChild()),hasElements:Int
		While child
			If child.getName() Then
				CopyInto(reader,child,target.addChild(child.getName()),depth+1)
				hasElements=True
			End If
			child=child.nextSibling()
		Wend
		If Not hasElements And source.getContent() Then target.setContent(source.getContent())
	End Function

	Rem
	bbdoc: Creates a bounded deep copy of an XML node for template expansion.
	param: Importer state used for resource lookup and allocation limits.
	param: Source data or object to read.
	End Rem
	Function Clone:TxmlNode(reader:TTiledReader,source:TxmlNode)
		Local result:TxmlNode=TxmlNode.newNode(source.getName())
		Try
			CopyInto(reader,source,result)
			Return result
		Catch error:Object
			result.Free()
			Throw error
		End Try
	End Function

	Rem
	bbdoc: Resolves file-valued template properties relative to the template directory.
	param: Source document node to inspect.
	param: Owning document directory or URL used to resolve relative paths.
	param: Current document-nesting depth, checked against import limits.
	End Rem
	Function NormalizeFiles(node:TxmlNode,base:String,depth:Int=0)
		If depth>256 Then Throw "template properties nested too deeply"
		If node.getName()="property" And TTiledReader.Attr(node,"type")="file" Then
			Local value:String=TTiledReader.Attr(node,"value",node.getContent())
			If value Then node.setAttribute("value",TTiledReader.Resolve(base,value))
		End If
		Local child:TxmlNode=TxmlNode(node.getFirstChild())
		While child
			If child.getName() Then NormalizeFiles(child,base,depth+1)
			child=child.nextSibling()
		Wend
	End Function

	Rem
	bbdoc: Merges template and instance properties into a target XML node.
	param: Importer state used for resource lookup and allocation limits.
	param: Destination XML node to populate.
	param: Source data or object to read.
	param: Current property-nesting depth, checked against import limits.
	End Rem
	Function MergeProperties(reader:TTiledReader,target:TxmlNode,source:TxmlNode,depth:Int=0)
		If depth>64 Then Throw "class properties nested too deeply"
		Local overrides:TxmlNode=TTiledReader.Child(source,"properties")
		If Not overrides Then Return
		Local properties:TxmlNode=TTiledReader.Child(target,"properties")
		If Not properties Then properties=target.addChild("properties")
		Local node:TxmlNode=TxmlNode(overrides.getFirstChild())
		While node
			If node.getName()="property" Then
				Local name:String=TTiledReader.Attr(node,"name"),existing:TxmlNode=TxmlNode(properties.getFirstChild())
				While existing
					If existing.getName()="property" And TTiledReader.Attr(existing,"name")=name Then Exit
					existing=existing.nextSibling()
				Wend
				If existing And TTiledReader.Attr(existing,"type")="class" And TTiledReader.Attr(node,"type")="class" And TTiledReader.Attr(existing,"propertytype")=TTiledReader.Attr(node,"propertytype") Then
					MergeProperties(reader,existing,node,depth+1)
				Else
					If existing Then existing.Free()
					CopyInto(reader,node,properties.addChild("property"))
				End If
			End If
			node=node.nextSibling()
		Wend
	End Function

	Rem
	bbdoc: Expands an object's template and applies its instance overrides.
	param: Importer state used for resource lookup and allocation limits.
	param: Source document node to inspect.
	param: Owning document directory or URL used to resolve relative paths.
	param: Current template-nesting depth, checked against import limits.
	End Rem
	Function ExpandObject:TxmlNode(reader:TTiledReader,node:TxmlNode,base:String,depth:Int)
		If depth>32 Then Throw "object templates nested too deeply"
		Local own:TxmlNode=Clone(reader,node),result:TxmlNode
		Try
			NormalizeFiles(own,base)
			If Not own.hasAttribute("template") Then
				result=own; own=Null
				Return result
			End If
			Local template:TxmlNode=ReadTemplate(reader,TTiledReader.Resolve(base,TTiledReader.Attr(own,"template")),depth+1)
			result=Clone(reader,template)
			' Geometry overrides replace the inherited shape as a whole.
			Local overridesShape:Int=own.hasAttribute("gid")
			For Local shape:String=EachIn ["ellipse","point","polygon","polyline","text"]
				If TTiledReader.Child(own,shape) Then overridesShape=True
			Next
			If overridesShape Then
				result.unsetAttribute("gid")
				For Local shape:String=EachIn ["ellipse","point","polygon","polyline","text"]
					Local child:TxmlNode=TTiledReader.Child(result,shape)
					If child Then child.Free()
				Next
			End If
			If own.hasAttribute("type") Or own.hasAttribute("class") Then result.unsetAttribute("type"); result.unsetAttribute("class")
			For Local i:Int=0 Until own.getAttributeCount()
				Local name:String,value:String=own.getAttributeByIndex(i,name)
				If name<>"template" Then result.setAttribute(name,value)
			Next
			MergeProperties(reader,result,own)
			Local child:TxmlNode=TxmlNode(own.getFirstChild())
			While child
				If child.getName() And child.getName()<>"properties" Then CopyInto(reader,child,result.addChild(child.getName()))
				child=child.nextSibling()
			Wend
			Return result
		Catch error:Object
			If result Then result.Free()
			Throw error
		Finally
			If own Then own.Free()
		End Try
	End Function

	Rem
	bbdoc: Loads and caches a template while rejecting cyclic references.
	param: Importer state used for resource lookup and allocation limits.
	param: Resource filename or filesystem URL.
	param: Current template-nesting depth, checked against import limits.
	End Rem
	Function ReadTemplate:TxmlNode(reader:TTiledReader,path:String,depth:Int)
		Local cached:TxmlNode
		If reader.templates.TryGetValue(path,cached) Then Return cached
		Local active:Int
		If reader.loadingTemplates.TryGetValue(path,active) Then Throw "cyclic object template: "+path
		If reader.templates.Count()>=4096 Then Throw "too many object templates"
		reader.loadingTemplates.Put(path,1)
		Local doc:TxmlDoc,copy:TxmlNode,result:TxmlNode
		Try
			doc=TTiledDocument.Read(path,"template",reader.project)
			If Not doc Then Throw "cannot parse object template"
			Local root:TxmlNode=doc.getRootElement()
			If Not root Or root.getName()<>"template" Then Throw "expected an XML object template"
			Local objectNode:TxmlNode=TTiledReader.Child(root,"object")
			If Not objectNode Then Throw "template has no object"
			copy=Clone(reader,objectNode)
			If copy.hasAttribute("gid") Then
				Local reference:TxmlNode=TTiledReader.Child(root,"tileset")
				If Not reference Or Not reference.hasAttribute("source") Then Throw "tile template requires an external tileset"
				Local set:TTiledTileset=FindTileset(reader,TTiledReader.Resolve(ExtractDir(path),TTiledReader.Attr(reference,"source")))
				Local first:Long=TTiledReader.Number(reference,"firstgid",1,1,$0fffffff)
				Local gid:Long=TTiledReader.BoundedInteger(TTiledReader.Attr(copy,"gid"),1,4294967295:Long),localID:Long=(gid & $0fffffff)-first
				If localID<0 Or localID>$0fffffff Or Not set.NativeID(Int(localID)) Then Throw "unknown template tile ID"
				copy.setAttribute("gid",String((gid & $f0000000:Long) | (Long(set.firstGID)+localID)))
			End If
			result=ExpandObject(reader,copy,ExtractDir(path),depth)
			' A placement owns its identity and coordinates, even when the template saved them.
			For Local name:String=EachIn ["id","x","y","template"]
				result.unsetAttribute(name)
			Next
			reader.templates.Put(path,result)
			Return result
		Catch error:Object
			If result Then result.Free()
			Throw "template "+path+": "+error.ToString()
		Finally
			reader.loadingTemplates.Remove(path)
			If copy Then copy.Free()
			If doc Then doc.Free()
		End Try
	End Function

	Rem
	bbdoc: Finds the map tileset matching an external tileset path.
	param: Importer state used for resource lookup and allocation limits.
	param: Resource filename or filesystem URL.
	End Rem
	Function FindTileset:TTiledTileset(reader:TTiledReader,path:String)
		Local nextGID:Long=1
		For Local set:TTiledTileset=EachIn reader.map.importedTilesets
			If set.sourcePath=path Then Return set
			nextGID=Max(nextGID,Long(set.firstGID)+1)
			For Local id:Int=EachIn set.ids.Keys()
				nextGID=Max(nextGID,Long(set.firstGID)+id+1)
			Next
		Next
		If nextGID>$0fffffff Then Throw "template tileset GID range exhausted"
		Local reference:TxmlNode=TxmlNode.newNode("tileset")
		Try
			reference.setAttribute("source",path); reference.setAttribute("firstgid",String(nextGID))
			reader.ReadTileset(reference,"")
			Return reader.map.importedTilesets[reader.map.importedTilesets.Length-1]
		Finally
			reference.Free()
		End Try
	End Function

End Type
