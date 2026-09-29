' Normalize JSON structure into the importer's shared document model.
' Tile arrays become bounded binary payloads, never one XML node per cell.

Rem
bbdoc: Reads Tiled XML or JSON through a common XML document representation.
End Rem
Type TTiledDocument

	Rem
	bbdoc: Loads a Tiled document and converts JSON input to the importer's XML representation.
	param: Filename, stream URL or caller-owned readable stream.
	param: Imported type or document kind to select.
	param: Owning project and its imported definitions.
	End Rem
	Function Read:TxmlDoc(source:Object,kind:String,project:TTiledProject=Null)
		Local stream:TStream=TStream(source),owned:Int
		If Not stream Then
			stream=ReadStream(source); owned=True
		End If
		If Not stream Then Throw "cannot open Tiled document: "+String(source)
		Try
			Local input:TTiledPrefixStream=Prefix(stream)
			If input.first<>123 Then Return TxmlDoc.parseFile(input)
			Local json:TJSONObject=ParseJSON(input)
			If json.Get("type") And json.GetString("type")<>kind Then Throw "expected JSON "+kind
			Local doc:TxmlDoc=TxmlDoc.newDoc("1.0")
			Try
				Local root:TxmlNode=TxmlNode.newNode(kind)
				doc.setRootElement(root)
				Local adapter:TTiledJSON=New TTiledJSON
				adapter.project=project
				adapter.Convert(json,root)
				Return doc
			Catch failure:Object
				doc.Free()
				Throw failure
			End Try
		Finally
			If owned Then stream.Close()
		End Try
	End Function

	Rem
	bbdoc: Wraps a stream so a consumed format-detection prefix remains readable.
	param: Readable stream; ownership remains with the caller unless stated otherwise.
	End Rem
	Function Prefix:TTiledPrefixStream(stream:TStream)
		Local input:TTiledPrefixStream=New TTiledPrefixStream
		input.stream=stream
		Local first:Byte
		Repeat
			If stream.Read(Varptr first,1)<>1 Then Throw "empty Tiled document"
		Until first<>9 And first<>10 And first<>13 And first<>32
		If first=$ef Then
			Local bom:Byte[2]
			stream.ReadBytes(bom,2)
			If bom[0]<>$bb Or bom[1]<>$bf Then Throw "invalid UTF-8 BOM"
			Repeat
				If stream.Read(Varptr first,1)<>1 Then Throw "empty Tiled document"
			Until first<>9 And first<>10 And first<>13 And first<>32
		End If
		input.first=first; input.pending=True
		Return input
	End Function

	Rem
	bbdoc: Parses a JSON object from a stream.
	param: Readable stream; ownership remains with the caller unless stated otherwise.
	End Rem
	Function ParseJSON:TJSONObject(stream:TStream)
		Local error:TJSONError
		Local json:TJSONObject=TJSONObject(TJSON.Load(stream,JSON_REJECT_DUPLICATES,error))
		If Not json Then
			If error Then Throw "invalid Tiled JSON at line "+error.line+": "+error.Text
			Throw "expected Tiled JSON object"
		End If
		Return json
	End Function

	Rem
	bbdoc: Reads a JSON object document from a file, stream URL or caller-owned stream.
	param: Filename, stream URL or caller-owned readable stream.
	End Rem
	Function ReadJSON:TJSONObject(source:Object)
		Local stream:TStream=TStream(source),owned:Int
		If Not stream Then stream=ReadStream(source); owned=True
		If Not stream Then Throw "cannot open Tiled JSON: "+String(source)
		Try
			Return ParseJSON(Prefix(stream))
		Finally
			If owned Then stream.Close()
		End Try
	End Function

End Type

' Single-byte lookahead works with caller-owned, non-seekable streams too.

Rem
bbdoc: Stream adapter that replays bytes consumed during input format detection.
End Rem
Type TTiledPrefixStream Extends TStream

	Rem
	bbdoc: Underlying caller-owned input stream.
	End Rem
	Field stream:TStream

	Rem
	bbdoc: Byte consumed during format detection and replayed on the first read.
	End Rem
	Field first:Byte

	Rem
	bbdoc: Whether the saved prefix byte still needs to be read.
	End Rem
	Field pending:Int

	Rem
	bbdoc: Reads saved prefix bytes followed by bytes from the underlying stream.
	param: Writable destination memory for the requested bytes.
	param: Number of items to process.
	End Rem
	Method Read:Long(buffer:Byte Ptr,count:Long) Override
		If count<=0 Then Return 0
		If pending Then
			buffer[0]=first; pending=False
			Return 1
		End If
		Return stream.Read(buffer,count)
	End Method

	Rem
	bbdoc: Reports whether the prefix and underlying stream have both reached their end.
	End Rem
	Method Eof:Int() Override
		Return Not pending And stream.Eof()
	End Method

End Type

Rem
bbdoc: Converts supported Tiled JSON structures into XML nodes for the shared importer.
End Rem
Type TTiledJSON

	Rem
	bbdoc: Owning project and its definitions.
	End Rem
	Field project:TTiledProject

	Rem
	bbdoc: Number of converted document nodes counted against import limits.
	End Rem
	Field nodes:Int

	Rem
	bbdoc: Number of tile cells converted, checked against import limits.
	End Rem
	Field cells:Long

	Rem
	bbdoc: Copies a Tiled JSON object's supported members into an XML node.
	param: Source data or object to read.
	param: Destination XML node to populate.
	param: Current document-nesting depth, checked against import limits.
	End Rem
	Method Convert(source:TJSONObject,target:TxmlNode,depth:Int=0)
		If Not source Then Throw "expected JSON object"
		If source.Get("data") And source.Get("chunks") Then Throw "JSON layer cannot contain both data and chunks"
		nodes:+1
		If depth>128 Or nodes>1048576 Then Throw "JSON structure limit exceeded"
		For Local value:TJSON=EachIn source
			Local key:String=value.key
			Select key
				Case "layers","tilesets","tiles","objects","animation"
					Local parent:TxmlNode=target
					If key="animation" Then parent=target.addChild("animation")
					For Local entry:TJSON=EachIn ArrayValue(value)
						Local item:TJSONObject=ObjectValue(entry),name:String
						Select key
							Case "layers"
								name=item.GetString("type")
								If name="tilelayer" Then name="layer"
								If name<>"layer" And name<>"objectgroup" And name<>"imagelayer" And name<>"group" Then Throw "unsupported JSON layer type: "+name
							Case "tilesets"; name="tileset"
							Case "tiles"; name="tile"
							Case "objects"; name="object"
							Case "animation"; name="frame"
						End Select
						Convert(item,parent.addChild(name),depth+1)
					Next
				Case "properties"
					Local properties:TxmlNode=target.addChild("properties")
					For Local entry:TJSON=EachIn ArrayValue(value)
						Local item:TJSONObject=ObjectValue(entry)
						Property(properties,item.GetString("name"),item.Get("value"),item.GetString("type"),item.GetString("propertytype"),depth+1)
					Next
				Case "image"
					Local image:TxmlNode=target.addChild("image")
					image.setAttribute("source",Scalar(value))
					If source.Get("transparentcolor") Then image.setAttribute("trans",Scalar(source.Get("transparentcolor")))
				Case "imagewidth","imageheight","transparentcolor","encoding","compression"
					' Image dimensions come from the decoded image; encoding belongs on data.
				Case "data","chunks"
					Local data:TxmlNode=target.addChild("data")
					If key="data" Then
						Payload(value,data,data,source)
					Else
						For Local entry:TJSON=EachIn ArrayValue(value)
							Local item:TJSONObject=ObjectValue(entry),chunk:TxmlNode=data.addChild("chunk")
							For Local attr:String=EachIn ["x","y","width","height"]
								chunk.setAttribute(attr,Scalar(item.Get(attr)))
							Next
							Payload(item.Get("data"),chunk,data,source)
						Next
					End If
				Case "polygon","polyline"
					Local points:TJSONArray=ArrayValue(value)
					If points.Size()>65536 Then Throw "too many polygon points"
					Local strings:String[]=New String[points.Size()]
					For Local i:Int=0 Until strings.Length
						Local point:TJSONObject=ObjectValue(points.Get(i))
						strings[i]=Scalar(point.Get("x"))+","+Scalar(point.Get("y"))
					Next
					target.addChild(key).setAttribute("points"," ".Join(strings))
				Case "ellipse","point"
					If Not TJSONBool(value) Then Throw "expected JSON boolean: "+key
					If TJSONBool(value).isTrue Then target.addChild(key)
				Case "text"
					If target.getName()="text" Then
						target.setContent(Scalar(value))
					Else
						Convert(ObjectValue(value),target.addChild(key),depth+1)
					End If
				Case "objectgroup","object","tileset","tileoffset","grid"
					Convert(ObjectValue(value),target.addChild(key),depth+1)
				Case "type"
					If target.getName()="object" Or target.getName()="tile" Then target.setAttribute(key,Scalar(value))
				Default
					' Editor-only compound metadata is not part of the native runtime model.
					If Not TJSONObject(value) And Not TJSONArray(value) Then target.setAttribute(key,Scalar(value))
			End Select
		Next
	End Method

	Rem
	bbdoc: Converts tile-layer data to the shared importer's XML representation.
	param: Value to read, convert or store.
	param: Destination XML node to populate.
	param: Parent document node or imported group.
	param: Source JSON layer metadata.
	End Rem
	Method Payload(value:TJSON,target:TxmlNode,parent:TxmlNode,layer:TJSONObject)
		If TJSONArray(value) Then
			If layer.GetString("compression") Or (layer.GetString("encoding") And layer.GetString("encoding")<>"csv") Then Throw "invalid JSON array encoding"
			Local array:TJSONArray=TJSONArray(value),count:Int=array.Size()
			cells:+count
			If cells>TILED_MAX_CELLS Then Throw "JSON tile data limit exceeded"
			Local bytes:Byte[]=New Byte[count*4]
			For Local i:Int=0 Until count
				Local integer:TJSONInteger=TJSONInteger(array.Get(i))
				If Not integer Then Throw "tile ID must be a JSON integer"
				Local gid:Long=integer.Value()
				If gid<0 Or gid>4294967295:Long Then Throw "tile ID out of range"
				For Local b:Int=0 Until 4
					bytes[i*4+b]=Byte(gid Shr (b*8))
				Next
			Next
			parent.setAttribute("encoding","base64")
			target.setContent(TBase64.Encode(bytes))
		Else
			If Not TJSONString(value) Or layer.GetString("encoding")<>"base64" Then Throw "expected base64 JSON tile data"
			parent.setAttribute("encoding","base64")
			parent.setAttribute("compression",layer.GetString("compression"))
			target.setContent(TJSONString(value).Value())
		End If
	End Method

	Rem
	bbdoc: Converts a JSON property and its type metadata into an XML property node.
	param: Parent document node or imported group.
	param: Name used to register or look up the item.
	param: Value to read, convert or store.
	param: Imported type or document kind to select.
	param: Name of the imported custom class.
	param: Current property-nesting depth, checked against import limits.
	End Rem
	Method Property(parent:TxmlNode,name:String,value:TJSON,kind:String="",className:String="",depth:Int=0)
		nodes:+1
		If depth>64 Or nodes>1048576 Then Throw "JSON property limit exceeded"
		If Not kind Then
			If TJSONObject(value) Then
				kind="class"
			Else If TJSONBool(value) Then
				kind="bool"
			Else If TJSONInteger(value) Then
				kind="int"
			Else If TJSONReal(value) Then
				kind="float"
			Else
				kind="string"
			End If
		End If
		Local node:TxmlNode=parent.addChild("property")
		node.setAttribute("name",name); node.setAttribute("type",kind)
		If className Then node.setAttribute("propertytype",className)
		If kind="class" Then
			node.setAttribute("propertytype",className)
			Local members:TxmlNode=node.addChild("properties")
			For Local member:TJSON=EachIn ObjectValue(value)
				Local definition:TTiledMember
				If project Then definition=project.Member(className,member.key)
				If definition Then
					Property(members,member.key,member,definition.valueType,definition.propertyType,depth+1)
				Else
					Property(members,member.key,member,"","",depth+1)
				End If
			Next
		Else
			node.setAttribute("value",Scalar(value))
		End If
	End Method

	Rem
	bbdoc: Converts a supported JSON scalar to its XML attribute representation.
	param: Value to read, convert or store.
	End Rem
	Function Scalar:String(value:TJSON)
		If TJSONString(value) Then Return TJSONString(value).Value()
		If TJSONInteger(value) Then Return String(TJSONInteger(value).Value())
		If TJSONReal(value) Then Return value.SaveString(JSON_ENCODE_ANY)
		If TJSONBool(value) Then Return String(TJSONBool(value).isTrue)
		Throw "expected scalar JSON value"
	End Function

	Rem
	bbdoc: Requires a JSON object value, throwing for an incompatible value.
	param: Value to read, convert or store.
	End Rem
	Function ObjectValue:TJSONObject(value:TJSON)
		If Not TJSONObject(value) Then Throw "expected JSON object"
		Return TJSONObject(value)
	End Function

	Rem
	bbdoc: Requires a JSON array value, throwing for an incompatible value.
	param: Value to read, convert or store.
	End Rem
	Function ArrayValue:TJSONArray(value:TJSON)
		If Not TJSONArray(value) Then Throw "expected JSON array"
		Return TJSONArray(value)
	End Function

End Type
