Type TLDTKReader
	Field map:TLDTKMap,project:TLDTKProject
	Field images:TTreeMap<Int,TPixmap>=New TTreeMap<Int,TPixmap>
	Field artwork:TTreeMap<String,Int>=New TTreeMap<String,Int>
	Field cells:Long,objectCount:Int,fieldCount:Int
	Field entityArtwork:Int

	Method Read:TLDTKMap(project:TLDTKProject,info:TLDTKLevelInfo,flags:Int,entityArtwork:Int)
		Self.project=project; Self.entityArtwork=entityArtwork
		Try
			Local level:TJSONObject=info.data
			If info.externalPath Then
				level=Document(info.externalPath)
				If Text(level,"iid")<>info.iid Then Throw "external level IID does not match project: "+info.externalPath
			End If
			If Not TJSONArray(level.Get("layerInstances")) Then Throw "missing layerInstances; load the owning project for external levels"
			map=New TLDTKMap
			map.level=info; map.sourcePath=project.sourcePath
			map.grid=TTileGrid.Rectangular(Integer(project.data,"defaultGridSize",16,1,65536),Integer(project.data,"defaultGridSize",16,1,65536))
			map.tileset=New TTileSet; map.atlas=TTextureAtlas.Create(1024,flags)
			map.backgroundColor=Text(level,"__bgColor",Text(project.data,"defaultLevelBgColor","#000000"))
			map.fields=Fields(level,map.properties)
			ReadBackground(level,flags)
			Local layers:TJSONArray=Array(level,"layerInstances")
			If layers.Size()>4096 Then Throw "too many layers"
			' LDtk lists the top layer first; native maps draw the bottom layer first.
			For Local index:Int=layers.Size()-1 To 0 Step -1
				ReadLayer(ObjectValue(layers.Get(index)))
			Next
			Return map
		Catch error:Object
			Throw "Max2D.LDTK: "+project.sourcePath+" / "+info.identifier+": "+error.ToString()
		End Try
	End Method

	Method ReadBackground(level:TJSONObject,flags:Int)
		Local path:String=Text(level,"bgRelPath")
		If Not path Then Return
		Local placement:TJSONObject=ObjectValue(level.Get("__bgPos"))
		Local crop:TJSONArray=Array(placement,"cropRect"),scale:TJSONArray=Array(placement,"scale"),position:TJSONArray=Array(placement,"topLeftPx")
		If crop.Size()<>4 Or scale.Size()<>2 Or position.Size()<>2 Then Throw "invalid background placement"
		Local bg:TLDTKBackground=New TLDTKBackground
		bg.image=LoadImage(Resolve(ExtractDir(project.sourcePath),path),flags)
		If Not bg.image Then Throw "cannot load background image: "+path
		bg.sourceX=Float(Numeric(crop.Get(0),0)); bg.sourceY=Float(Numeric(crop.Get(1),0))
		bg.sourceWidth=Float(Numeric(crop.Get(2),0.000001)); bg.sourceHeight=Float(Numeric(crop.Get(3),0.000001))
		If Double(bg.sourceX)+bg.sourceWidth>bg.image.width Or Double(bg.sourceY)+bg.sourceHeight>bg.image.height Then Throw "background crop exceeds image"
		bg.width=Float(bg.sourceWidth*Numeric(scale.Get(0),0.000001,1000000))
		bg.height=Float(bg.sourceHeight*Numeric(scale.Get(1),0.000001,1000000))
		bg.x=Float(IntValue(position.Get(0))); bg.y=Float(IntValue(position.Get(1)))
		bg.repeat=Text(level,"bgPos")="Repeat"
		bg.pivotX=Float(Number(level,"bgPivotX",0.5,0,1)); bg.pivotY=Float(Number(level,"bgPivotY",0.5,0,1))
		map.background=bg
	End Method

	Method ReadLayer(node:TJSONObject)
		Local info:TLDTKLayer=New TLDTKLayer
		info.identifier=Text(node,"__identifier"); info.iid=Text(node,"iid"); info.kind=Text(node,"__type")
		If Not info.identifier Or Not info.iid Then Throw "layer requires identifier and iid"
		For Local existing:TLDTKLayer=EachIn map.importedLayers
			If existing.iid=info.iid Then Throw "duplicate layer IID"
		Next
		Select info.kind
			Case "Tiles","AutoLayer","IntGrid","Entities"
			Default; Throw "unsupported layer type: "+info.kind
		End Select
		Local size:Int=Integer(node,"__gridSize",0,1,65536)
		info.grid=TTileGrid.Rectangular(size,size)
		info.width=Integer(node,"__cWid",0,0,1000000); info.height=Integer(node,"__cHei",0,0,1000000)
		cells:+Long(info.width)*info.height
		If cells>16777216 Then Throw "too many layer cells"
		Local definition:TJSONObject=Definition("layers",Integer(node,"layerDefUid",-1))
		Local parallaxX:Double=Number(definition,"parallaxFactorX",0,-1,1),parallaxY:Double=Number(definition,"parallaxFactorY",0,-1,1)
		info.parallaxScaling=Boolean(definition,"parallaxScaling",True)
		If Text(definition,"blendMode","Normal")<>"Normal" Then Throw "non-normal layer blend mode is not supported"
		info.intGridDefinitions=Array(definition,"intGridValues")
		Local layer:TTileLayer=map.AddLayer(info.identifier); info.layer=layer
		layer.objectTopDown=False
		layer.parallaxX=1-parallaxX; layer.parallaxY=1-parallaxY
		If info.parallaxScaling Then layer.drawScale=Max(0.01,1-parallaxX)
		map._layerInfo.Insert(layer,info)
		layer.visible=Boolean(node,"visible",True); layer.opacity=Float(Number(node,"__opacity",1,0,1))
		layer.offsetX=Integer(node,"__pxTotalOffsetX",0); layer.offsetY=Integer(node,"__pxTotalOffsetY",0)
		map.importedLayers=map.importedLayers[..map.importedLayers.Length+1]; map.importedLayers[map.importedLayers.Length-1]=info
		Local csv:TJSONArray=Array(node,"intGridCsv")
		If csv.Size() Then
			If csv.Size()<>Long(info.width)*info.height Or info.kind<>"IntGrid" Then Throw "incorrect IntGrid size or layer type"
			info.intGrid=New Int[csv.Size()]
			For Local i:Int=0 Until csv.Size()
				info.intGrid[i]=IntValue(csv.Get(i),0,2147483647)
			Next
		Else If Array(node,"intGrid").Size() Then
			Throw "legacy IntGrid encoding is not supported; resave with current LDtk"
		End If
		ReadTiles(info,Array(node,"autoLayerTiles"),node)
		ReadTiles(info,Array(node,"gridTiles"),node)
		Local entities:TJSONArray=Array(node,"entityInstances")
		For Local i:Int=0 Until entities.Size()
			ReadEntity(info,ObjectValue(entities.Get(i)))
		Next
	End Method

	Method Definition:TJSONObject(kind:String,uid:Int)
		Local defs:TJSONArray=Array(ObjectValue(project.data.Get("defs")),kind)
		For Local i:Int=0 Until defs.Size()
			Local node:TJSONObject=ObjectValue(defs.Get(i))
			If Integer(node,"uid",-2)=uid Then Return node
		Next
		Throw "missing "+kind+" definition: "+uid
	End Method

	Method ReadTiles(info:TLDTKLayer,tiles:TJSONArray,layer:TJSONObject)
		If Not tiles.Size() Then Return
		Local uid:Int=Integer(layer,"__tilesetDefUid",-1)
		Local definition:TJSONObject=Definition("tilesets",uid)
		Local size:Int=Integer(definition,"tileGridSize",0,1,65536)
		Local pixels:TPixmap=TilesetPixels(uid)
		If Long(objectCount)+tiles.Size()>1048576 Then Throw "too many tile/entity instances"
		Local objects:TTileObject[]=New TTileObject[info.layer.objects.Length+tiles.Size()]
		For Local i:Int=0 Until info.layer.objects.Length
			objects[i]=info.layer.objects[i]
		Next
		Local start:Int=info.layer.objects.Length
		For Local i:Int=0 Until tiles.Size()
			Local tile:TJSONObject=ObjectValue(tiles.Get(i)),src:TJSONArray=Array(tile,"src"),px:TJSONArray=Array(tile,"px")
			If src.Size()<>2 Or px.Size()<>2 Then Throw "tile src and px require two coordinates"
			Local sx:Int=IntValue(src.Get(0),0,pixels.width),sy:Int=IntValue(src.Get(1),0,pixels.height)
			If Long(sx)+size>pixels.width Or Long(sy)+size>pixels.height Then Throw "tile source rectangle exceeds tileset"
			Local id:Int=AddArtwork(uid,sx,sy,size,size)
			Local obj:TTileObject=New TTileObject
			obj.tile=id; obj.x=IntValue(px.Get(0)); obj.y=IntValue(px.Get(1)); obj.width=size; obj.height=size
			Local bits:Int=Integer(tile,"f",0,0,3)
			If bits & 1 Then obj.flip:|ETileFlip.Horizontal
			If bits & 2 Then obj.flip:|ETileFlip.Vertical
			obj.opacity=Float(Number(tile,"a",1,0,1))
			objects[start+i]=obj; objectCount:+1
		Next
		info.layer.objects=objects
	End Method

	Method TilesetPixels:TPixmap(uid:Int)
		Local pixels:TPixmap
		If images.TryGetValue(uid,pixels) Then Return pixels
		If project.tilesetPixmaps.TryGetValue(uid,pixels) Then
			images.Put(uid,pixels)
			Return pixels
		End If
		Local definition:TJSONObject=Definition("tilesets",uid),embedded:String=Text(definition,"embedAtlas")
		If embedded Then
			If Not project.embeddedAtlases.TryGetValue(embedded,pixels) Then Throw "supply embedded atlas '"+embedded+"' with TLDTKProject.SetEmbeddedAtlas, or load with entityArtwork=False for metadata only"
		Else
			Local path:String=Resolve(ExtractDir(project.sourcePath),Text(definition,"relPath"))
			pixels=LoadPixmap(path)
			If Not pixels Then Throw "cannot load tileset image: "+path+"; import its image decoder or supply pixels with TLDTKProject.SetTilesetPixmap("+uid+", pixels)"
		End If
		images.Put(uid,pixels)
		Return pixels
	End Method
	Method AddArtwork:Int(uid:Int,sx:Int,sy:Int,width:Int,height:Int)
		Local pixels:TPixmap=TilesetPixels(uid)
		If sx<0 Or sy<0 Or width<=0 Or height<=0 Or Long(sx)+width>pixels.width Or Long(sy)+height>pixels.height Then Throw "artwork source rectangle exceeds tileset"
		Local key:String=uid+":"+sx+":"+sy+":"+width+":"+height,id:Int
		If Not artwork.TryGetValue(key,id) Then
			If map.tileset.tiles.Length>65536 Then Throw "too many tile definitions"
			Local cut:TPixmap=CreatePixmap(width,height,pixels.format)
			cut.Paste(pixels.Window(sx,sy,width,height),0,0)
			id=map.tileset.Add(map.atlas.AddPixmap(cut)); artwork.Put(key,id)
		End If
		Return id
	End Method

	Method ReadEntity(info:TLDTKLayer,node:TJSONObject)
		objectCount:+1
		If objectCount>1048576 Or map.entities.Length>=65536 Then Throw "too many tile/entity instances"
		Local entity:TLDTKEntity=New TLDTKEntity
		entity.identifier=Text(node,"__identifier"); entity.iid=Text(node,"iid"); entity.data=node; entity.layer=info
		If Not entity.iid Or map.Entity(entity.iid) Then Throw "missing or duplicate entity IID"
		Local obj:TTileObject=New TTileObject; entity.object=obj
		obj.id=map.entities.Length+1; obj.name=entity.identifier; obj.className=entity.identifier
		obj.width=Integer(node,"width",0,0,1000000); obj.height=Integer(node,"height",0,0,1000000)
		Local px:TJSONArray=Array(node,"px"),pivot:TJSONArray=Array(node,"__pivot")
		If px.Size()<>2 Or pivot.Size()<>2 Then Throw "entity px and pivot require two coordinates"
		obj.x=IntValue(px.Get(0))-obj.width*Numeric(pivot.Get(0),0,1)
		obj.y=IntValue(px.Get(1))-obj.height*Numeric(pivot.Get(1),0,1)
		entity.fields=Fields(node,obj.properties)
		If entityArtwork And node.Get("__tile") And Not TJSONNull(node.Get("__tile")) Then
			Local rect:TJSONObject=ObjectValue(node.Get("__tile")),definition:TJSONObject=Definition("entities",Integer(node,"defUid",-1))
			Local art:TLDTKEntityArtwork=New TLDTKEntityArtwork
			Local id:Int=AddArtwork(Integer(rect,"tilesetUid",-1),Integer(rect,"x",-1,0),Integer(rect,"y",-1,0),Integer(rect,"w",0,1,65536),Integer(rect,"h",0,1,65536))
			art.image=map.tileset.tiles[id].image
			art.mode=Text(definition,"tileRenderMode","FitInside")
			Select art.mode
				Case "Stretch","FitInside","Cover","Repeat","FullSizeCropped","FullSizeUncropped","NineSlice"
				Default; Throw "unsupported entity tile render mode: "+art.mode
			End Select
			art.pivotX=Float(Numeric(pivot.Get(0),0,1)); art.pivotY=Float(Numeric(pivot.Get(1),0,1))
			art.opacity=Float(Number(definition,"tileOpacity",1,0,1))
			If art.mode="NineSlice" Then
				Local borders:TJSONArray=Array(definition,"nineSliceBorders")
				If borders.Size()<>4 Then Throw "nine-slice requires top/right/bottom/left borders"
				art.top=IntValue(borders.Get(0),0); art.right=IntValue(borders.Get(1),0)
				art.bottom=IntValue(borders.Get(2),0); art.left=IntValue(borders.Get(3),0)
				art.ValidateNineSlice(Float(obj.width),Float(obj.height))
			End If
			entity.artwork=art; obj.artwork=art
		End If
		info.layer.AddObject(obj)
		map.entities=map.entities[..map.entities.Length+1]; map.entities[map.entities.Length-1]=entity
	End Method

	Method Fields:TLDTKField[](node:TJSONObject,properties:TTileProperties)
		Local values:TJSONArray=Array(node,"fieldInstances")
		fieldCount:+values.Size()
		If fieldCount>1048576 Then Throw "too many fields"
		Local fields:TLDTKField[]=New TLDTKField[values.Size()],names:TTreeMap<String,Int>=New TTreeMap<String,Int>
		For Local i:Int=0 Until values.Size()
			Local source:TJSONObject=ObjectValue(values.Get(i)),field:TLDTKField=New TLDTKField
			field.name=Text(source,"__identifier"); field.valueType=Text(source,"__type"); field.value=source.Get("__value")
			If Not field.name Or names.ContainsKey(field.name) Then Throw "missing or duplicate field identifier"
			names.Put(field.name,1); fields[i]=field
			If Not field.value Or TJSONNull(field.value) Then Continue
			If TJSONString(field.value) Then
				Local value:String=TJSONString(field.value).Value()
				If field.valueType="FilePath" And value Then value=Resolve(ExtractDir(project.sourcePath),value)
				properties.SetString(field.name,value)
			Else If TJSONInteger(field.value) Then
				If field.valueType="Float" Then properties.SetDouble(field.name,Double(TJSONInteger(field.value).Value())) Else properties.SetLong(field.name,TJSONInteger(field.value).Value())
			Else If TJSONReal(field.value) Then
				properties.SetDouble(field.name,TJSONReal(field.value).Value())
			Else If TJSONBool(field.value) Then
				properties.SetBool(field.name,TJSONBool(field.value).isTrue)
			End If
		Next
		Return fields
	End Method

	Function Document:TJSONObject(source:Object)
		Local stream:TStream=TStream(source),owned:Int
		If Not stream Then stream=ReadStream(source); owned=True
		If Not stream Then Throw "cannot open project/level: "+String(source)
		Try
			Local error:TJSONError,result:TJSONObject=TJSONObject(TJSON.Load(stream,JSON_REJECT_DUPLICATES,error))
			If Not result Then
				If error Then Throw "invalid JSON at line "+error.line+": "+error.Text
				Throw "expected a JSON object"
			End If
			Return result
		Finally
			If owned Then stream.Close()
		End Try
	End Function
	Function ObjectValue:TJSONObject(value:TJSON)
		Local result:TJSONObject=TJSONObject(value)
		If Not result Then Throw "expected a JSON object"
		Return result
	End Function
	Function Array:TJSONArray(node:TJSONObject,name:String)
		Local value:TJSON=node.Get(name)
		If Not value Or TJSONNull(value) Then Return New TJSONArray.Create()
		Local result:TJSONArray=TJSONArray(value)
		If Not result Then Throw "expected array: "+name
		Return result
	End Function
	Function Text:String(node:TJSONObject,name:String,fallback:String="")
		Local value:TJSON=node.Get(name)
		If Not value Or TJSONNull(value) Then Return fallback
		If Not TJSONString(value) Then Throw "expected string: "+name
		Return TJSONString(value).Value()
	End Function
	Function IntValue:Int(value:TJSON,minimum:Long=-1000000000,maximum:Long=1000000000)
		If Not TJSONInteger(value) Then Throw "expected integer"
		Local result:Long=TJSONInteger(value).Value()
		If result<minimum Or result>maximum Then Throw "integer out of range"
		Return Int(result)
	End Function
	Function Integer:Int(node:TJSONObject,name:String,fallback:Int,minimum:Long=-1000000000,maximum:Long=1000000000)
		Local value:TJSON=node.Get(name)
		If Not value Or TJSONNull(value) Then
			If fallback<minimum Or fallback>maximum Then Throw "missing integer: "+name
			Return fallback
		End If
		Return IntValue(value,minimum,maximum)
	End Function
	Function Numeric:Double(value:TJSON,minimum:Double=-1.0e9,maximum:Double=1.0e9)
		Local result:Double
		If TJSONInteger(value) Then
			result=Double(TJSONInteger(value).Value())
		Else If TJSONReal(value) Then
			result=TJSONReal(value).Value()
		Else
			Throw "expected number"
		End If
		If Not (result>=minimum And result<=maximum) Then Throw "number out of range"
		Return result
	End Function
	Function Number:Double(node:TJSONObject,name:String,fallback:Double,minimum:Double=-1.0e9,maximum:Double=1.0e9)
		Local value:TJSON=node.Get(name)
		If Not value Or TJSONNull(value) Then Return fallback
		Return Numeric(value,minimum,maximum)
	End Function
	Function Boolean:Int(node:TJSONObject,name:String,fallback:Int)
		Local value:TJSON=node.Get(name)
		If Not value Then Return fallback
		If Not TJSONBool(value) Then Throw "expected boolean: "+name
		Return TJSONBool(value).isTrue
	End Function
	Function Resolve:String(base:String,path:String)
		If Not path Then Throw "empty resource path (embedded/internal tilesets are not supported)"
		path=path.Replace("\","/")
		If path.Find("::")>=0 Then Return NormalizePath(path)
		If Not path.StartsWith("/") And Not (path.Length>1 And path[1]=58) And base Then path=base+"/"+path
		Return NormalizePath(path)
	End Function
	Function NormalizePath:String(path:String)
		path=path.Replace("\","/")
		Local separator:Int=path.Find("::")
		If separator<0 Then Return RealPath(path)
		Local prefix:String=path[..separator+2],parts:String[]=path[separator+2..].Split("/")
		Local stack:String[]=New String[parts.Length],count:Int
		For Local part:String=EachIn parts
			If Not part Or part="." Then Continue
			If part=".." Then
				If Not count Then Throw "resource escapes stream namespace root"
				count:-1
			Else
				stack[count]=part; count:+1
			End If
		Next
		Return prefix+"/".Join(stack[..count])
	End Function
End Type
