' Loader limits bound allocations before decoding layer payloads.

Rem
bbdoc: Maximum decoded tile-cell count allowed during one Tiled import.
End Rem
Const TILED_MAX_CELLS:Int=16777216

Rem
bbdoc: Maximum tile-definition count accepted by the Tiled importer.
End Rem
Const TILED_MAX_TILES:Int=65536

Rem
bbdoc: Importer state for resolving Tiled resources and constructing a native tilemap.
End Rem
Type TTiledReader

	Rem
	bbdoc: Owning project and its definitions.
	End Rem
	Field project:TTiledProject

	Rem
	bbdoc: Optional application resolver for imported text-object fonts.
	End Rem
	Field fontResolver:TTiledFontResolver

	Rem
	bbdoc: Number of imported text characters counted against allocation limits.
	End Rem
	Field textCharacters:Int

	Rem
	bbdoc: Number of imported property values counted against allocation limits.
	End Rem
	Field propertiesRead:Int

	Rem
	bbdoc: Number of expanded template nodes counted against allocation limits.
	End Rem
	Field templateNodes:Int

	Rem
	bbdoc: Cached template documents indexed by resolved path.
	End Rem
	Field templates:TTreeMap<String,TxmlNode>=New TTreeMap<String,TxmlNode>

	Rem
	bbdoc: Templates currently being expanded, used to detect cyclic references.
	End Rem
	Field loadingTemplates:TTreeMap<String,Int>=New TTreeMap<String,Int>

	Rem
	bbdoc: Image creation flags used for imported artwork.
	End Rem
	Field imageFlags:Int

	Rem
	bbdoc: Native map being populated by the importer.
	End Rem
	Field map:TTiledMap

	Rem
	bbdoc: Number of decoded tile cells counted against allocation limits.
	End Rem
	Field cellsRead:Long

	Rem
	bbdoc: Number of imported objects counted against allocation limits.
	End Rem
	Field objectsRead:Int

	Rem
	bbdoc: Number of imported polygon points counted against allocation limits.
	End Rem
	Field pointsRead:Int

	Rem
	bbdoc: Object identifiers already encountered, used to reject duplicates.
	End Rem
	Field objectIDs:TTreeMap<Int,Int>=New TTreeMap<Int,Int>

	Rem
	bbdoc: Loads and validates a Tiled map and its referenced resources.
	param: Filename, stream URL or caller-owned readable stream.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Logical source filename used to resolve relative resources for stream input.
	End Rem
	Method Read:TTiledMap(source:Object,flags:Int,sourcePath:String="")
		imageFlags=flags
		Local path:String=sourcePath
		If Not path Then path=String(source)
		Local doc:TxmlDoc=TTiledDocument.Read(source,"map",project)
		If Not doc Then Throw "Max2D.Tiled: cannot parse "+path
		Try
			Local root:TxmlNode=doc.getRootElement()
			If Not root Or root.getName()<>"map" Then Throw "expected a TMX map"
			map=New TTiledMap
			If path Then map.sourcePath=NormalizePath(path)
			map.width=Number(root,"width",0,0,TILE_COORDINATE_LIMIT)
			map.height=Number(root,"height",0,0,TILE_COORDINATE_LIMIT)
			map.infinite=Number(root,"infinite",0,0,1)
			map.orientation=Attr(root,"orientation")
			map.className=Attr(root,"class")
			map.backgroundColor=Attr(root,"backgroundcolor")
			map.parallaxOriginX=Decimal(root,"parallaxoriginx",0); map.parallaxOriginY=Decimal(root,"parallaxoriginy",0)
			Local tw:Int=Number(root,"tilewidth",0,1,65536),th:Int=Number(root,"tileheight",0,1,65536)
			Local axis:ETileAxis=ETileAxis.Y,stagger:ETileStagger=ETileStagger.Odd
			If map.orientation="hexagonal" Or map.orientation="staggered" Then
				Select Attr(root,"staggeraxis")
					Case "x"; axis=ETileAxis.X
					Case "y"; axis=ETileAxis.Y
					Default; Throw "invalid staggeraxis"
				End Select
				Select Attr(root,"staggerindex")
					Case "even"; stagger=ETileStagger.Even
					Case "odd"; stagger=ETileStagger.Odd
					Default; Throw "invalid staggerindex"
				End Select
			End If
			Select map.orientation
				Case "orthogonal"
					map.grid=TTileGrid.Rectangular(tw,th)
					Select Attr(root,"renderorder","right-down")
						Case "right-down"; map.renderOrder=ETileRenderOrder.RightDown
						Case "right-up"; map.renderOrder=ETileRenderOrder.RightUp
						Case "left-down"; map.renderOrder=ETileRenderOrder.LeftDown
						Case "left-up"; map.renderOrder=ETileRenderOrder.LeftUp
						Default; Throw "invalid orthogonal render order"
					End Select
				Case "isometric"
					map.grid=TTileGrid.Isometric(tw,th)
					map.originX=(Double(map.height)-1)*tw/2
				Case "staggered"
					map.grid=TTileGrid.StaggeredIsometric(tw,th,axis,stagger)
				Case "hexagonal"
					Local layout:ETileLayout=ETileLayout.PointyHex
					If axis=ETileAxis.X Then layout=ETileLayout.FlatHex
					map.grid=TTileGrid.Hexagonal(tw,th,layout,stagger,Number(root,"hexsidelength",0,1,65535))
				Default; Throw "unsupported orientation: "+map.orientation
			End Select
			map.tileset=New TTileSet
			map.atlas=TTextureAtlas.Create(1024,flags)
			ReadProperties(root,map.properties,ExtractDir(map.sourcePath))
			Local child:TxmlNode=TxmlNode(root.getFirstChild())
			While child
				If child.getName()="tileset" Then ReadTileset(child,ExtractDir(map.sourcePath))
				child=child.nextSibling()
			Wend
			ReadLayers(root,Null,map.originX,0,1,True,0)
			If project Then ResolveProject()
			Return map
		Catch error:Object
			Throw "Max2D.Tiled: "+path+": "+error.ToString()
		Finally
			For Local template:TxmlNode=EachIn templates.Values()
				template.Free()
			Next
			templates.Clear()
			doc.Free()
		End Try
	End Method

	Rem
	bbdoc: Applies project class metadata to imported map, layer, tile and object properties.
	End Rem
	Method ResolveProject()
		map.properties=project.Apply(map.className,map.properties)
		For Local info:TTiledLayerInfo=EachIn map.importedLayers
			info.properties=project.Apply(info.className,info.properties)
			If info.layer Then
				info.layer.properties=info.properties
				For Local obj:TTileObject=EachIn info.layer.objects
					Local inherited:TTileProperties=New TTileProperties
					If obj.tileProperties Then inherited=obj.tileProperties.Copy()
					inherited.Overlay(obj.properties)
					obj.properties=project.Apply(obj.className,inherited)
				Next
			End If
		Next
		' Keep raw tile defaults until every placed object has inherited them.
		For Local set:TTiledTileset=EachIn map.importedTilesets
			set.properties=project.Apply(set.className,set.properties)
			For Local localID:Int=EachIn set.ids.Keys()
				Local tile:TTileDefinition=map.tileset.tiles[set.NativeID(localID)],className:String
				set.classes.TryGetValue(localID,className)
				For Local obj:TTileObject=EachIn tile.collisions
					obj.properties=project.Apply(obj.className,obj.properties)
				Next
				tile.properties=project.Apply(className,tile.properties)
			Next
		Next
	End Method

	Rem
	bbdoc: Imports an embedded or external Tiled tileset definition.
	param: Imported reference to resolve.
	param: Owning document directory or URL used to resolve relative paths.
	End Rem
	Method ReadTileset(reference:TxmlNode,base:String)
		Local first:Int=Number(reference,"firstgid",0,1,$0fffffff)
		If map.importedTilesets.Length Then
			If first<=map.importedTilesets[map.importedTilesets.Length-1].firstGID Then Throw "tilesets must have increasing firstgid values"
		End If
		Local root:TxmlNode=reference,doc:TxmlDoc,path:String
		Try
			If reference.hasAttribute("source") Then
				path=Resolve(base,Attr(reference,"source"))
				doc=TTiledDocument.Read(path,"tileset",project)
				If Not doc Then Throw "cannot parse tileset: "+path
				root=doc.getRootElement(); base=ExtractDir(path)
				If Not root Or root.getName()<>"tileset" Then Throw "expected a TSX tileset: "+path
			End If
			Local set:TTiledTileset=New TTiledTileset
			set.firstGID=first; set.sourcePath=path; set.name=Attr(root,"name"); set.className=Attr(root,"class")
			set.objectAlignment=Attr(root,"objectalignment","unspecified"); set.fillMode=Attr(root,"fillmode","stretch")
			set.renderSize=Attr(root,"tilerendersize","tile")
			If set.renderSize<>"tile" And set.renderSize<>"grid" Then Throw "invalid tile render size"
			If set.fillMode<>"stretch" And set.fillMode<>"preserve-aspect-fit" Then Throw "invalid tileset fill mode"
			ReadProperties(root,set.properties,base)
			Local off:TxmlNode=Child(root,"tileoffset"),ox:Float,oy:Float
			If off Then ox=Decimal(off,"x",0); oy=Decimal(off,"y",0)
			set.offsetX=ox; set.offsetY=oy
			Local sheet:TxmlNode=Child(root,"image")
			If sheet Then
				Local pixels:TPixmap=ReadImage(sheet,base)
				Local w:Int=Number(root,"tilewidth",0,1,65536),h:Int=Number(root,"tileheight",0,1,65536)
				Local spacing:Int=Number(root,"spacing",0,0,65536),margin:Int=Number(root,"margin",0,0,65536)
				Local cols:Int=(pixels.width-margin*2+spacing)/(w+spacing),rows:Int=(pixels.height-margin*2+spacing)/(h+spacing)
				If cols<=0 Or rows<=0 Then Throw "tileset image is smaller than its tile layout"
				If root.hasAttribute("columns") And Number(root,"columns",0,1,TILED_MAX_TILES)<>cols Then Throw "tileset columns do not match image layout"
				Local count:Int=Number(root,"tilecount",cols*rows,1,TILED_MAX_TILES)
				If Long(count)>Long(cols)*rows Then Throw "tilecount exceeds tileset image"
				For Local id:Int=0 Until count
					AddTile(set,id,pixels.Window(margin+(id Mod cols)*(w+spacing),margin+(id/cols)*(h+spacing),w,h),ox,oy)
				Next
			End If
			Local tile:TxmlNode=TxmlNode(root.getFirstChild())
			While tile
				If tile.getName()="tile" Then
					Local id:Int=Number(tile,"id",-1,0,$0fffffff)
					Local picture:TxmlNode=Child(tile,"image")
					If picture Then
						If sheet Then Throw "mixed sheet and per-tile images are not supported"
						Local pixels:TPixmap=ReadImage(picture,base)
						Local sx:Int=Number(tile,"x",0,0,pixels.width-1),sy:Int=Number(tile,"y",0,0,pixels.height-1)
						Local sw:Int=Number(tile,"width",pixels.width,1,pixels.width-sx),sh:Int=Number(tile,"height",pixels.height,1,pixels.height-sy)
						AddTile(set,id,pixels.Window(sx,sy,sw,sh),ox,oy)
					End If
					Local native:Int=set.NativeID(id)
					If Not native Then Throw "tile definition has no image: "+id
					ReadProperties(tile,map.tileset.Properties(native),base)
					set.classes.Put(id,Attr(tile,"type",Attr(tile,"class")))
					Local collision:TxmlNode=Child(tile,"objectgroup")
					If collision Then
						Local gridNode:TxmlNode=Child(root,"grid")
						If gridNode And Attr(gridNode,"orientation")="isometric" Then Throw "isometric tileset collision grids are not supported yet"
						map.tileset.tiles[native].collisions=ReadObjects(collision,base,True)
					End If
				End If
				tile=tile.nextSibling()
			Wend
			' Read animation after all single-frame images are available.
			tile=TxmlNode(root.getFirstChild())
			While tile
				If tile.getName()="tile" Then
					Local animation:TxmlNode=Child(tile,"animation")
					If animation Then
						Local frames:TImage[]=New TImage[0],durations:Int[]=New Int[0]
						Local frame:TxmlNode=TxmlNode(animation.getFirstChild())
						While frame
							If frame.getName()="frame" Then
								Local image:TImage
								set.images.TryGetValue(Number(frame,"tileid",-1,0,$0fffffff),image)
								If Not image Then Throw "animation references a missing tile"
								frames=frames[..frames.Length+1]; frames[frames.Length-1]=image
								durations=durations[..durations.Length+1]; durations[durations.Length-1]=Number(frame,"duration",0,1,2147483647)
							End If
							frame=frame.nextSibling()
						Wend
						Local id:Int=set.NativeID(Number(tile,"id",-1,0,$0fffffff))
						Local image:TImage=TImage.Animation(frames,durations)
						Local definition:TTileDefinition=map.tileset.tiles[id]
						definition.image=image; definition.animated=True
						ConfigureSize(set,id,image,ox,oy)
					End If
				End If
				tile=tile.nextSibling()
			Wend
			map.importedTilesets=map.importedTilesets[..map.importedTilesets.Length+1]
			map.importedTilesets[map.importedTilesets.Length-1]=set
		Finally
			If doc Then doc.Free()
		End Try
	End Method

	Rem
	bbdoc: Packs source pixels and records the native ID for a Tiled tile.
	param: Imported tileset receiving native tile metadata.
	param: Caller identifier attached to the object or shape.
	param: Source pixel data.
	param: Horizontal offset.
	param: Vertical offset.
	End Rem
	Method AddTile(set:TTiledTileset,id:Int,pixels:TPixmap,ox:Float,oy:Float)
		If map.tileset.tiles.Length>TILED_MAX_TILES Then Throw "too many tile definitions"
		If set.NativeID(id) Then Throw "duplicate tile image: "+id
		If Long(set.firstGID)+id>$0fffffff Then Throw "tile GID exceeds supported range"
		Local image:TImage=map.atlas.AddPixmap(pixels)
		Local x:Float=ox
		Local native:Int=map.tileset.Add(image,0,x,Float(map.grid.TileHeight()-image.height)+oy)
		ConfigureSize(set,native,image,ox,oy)
		set.ids.Put(id,native); set.images.Put(id,image)
	End Method

	Rem
	bbdoc: Applies tileset drawing size, offsets and aspect-fit settings to a native tile.
	param: Imported tileset receiving native tile metadata.
	param: Caller identifier attached to the object or shape.
	param: Image to operate on.
	param: Horizontal offset.
	param: Vertical offset.
	End Rem
	Method ConfigureSize(set:TTiledTileset,id:Int,image:TImage,ox:Float,oy:Float)
		If set.renderSize="grid" Then
			Local mode:ETileFillMode=ETileFillMode.Stretch
			If set.fillMode="preserve-aspect-fit" Then mode=ETileFillMode.PreserveAspectFit
			map.tileset.SetSize(id,Float(map.grid.TileWidth()),Float(map.grid.TileHeight()),mode)
			Local sx:Float,sy:Float,px:Float,py:Float
			TileImageFit(image.width,image.height,Float(map.grid.TileWidth()),Float(map.grid.TileHeight()),mode,sx,sy,px,py)
			map.tileset.tiles[id].offsetX=ox*sx; map.tileset.tiles[id].offsetY=oy*sy
		Else
			map.tileset.SetSize(id,image.width,image.height)
			map.tileset.tiles[id].offsetX=ox
			map.tileset.tiles[id].offsetY=Float(map.grid.TileHeight()-image.height)+oy
		End If
	End Method

	Rem
	bbdoc: Imports layers recursively while combining group offsets, opacity, visibility and tint.
	param: Root element or heap index from which processing begins.
	param: Parent document node or imported group.
	param: Horizontal offset.
	param: Vertical offset.
	param: Opacity multiplier from 0.0 to 1.0.
	param: Inherited group visibility.
	param: Current group-nesting depth, checked against import limits.
	param: Horizontal layer parallax factor.
	param: Vertical layer parallax factor.
	param: Red multiplier from 0.0 to 1.0.
	param: Green multiplier from 0.0 to 1.0.
	param: Blue multiplier from 0.0 to 1.0.
	param: Combined layer tint opacity multiplier.
	End Rem
	Method ReadLayers(root:TxmlNode,parent:TTiledLayerInfo,ox:Double,oy:Double,opacity:Float,visible:Int,depth:Int,parallaxX:Double=1,parallaxY:Double=1,red:Float=1,green:Float=1,blue:Float=1,tintAlpha:Float=1)
		If depth>64 Then Throw "layer groups nested too deeply"
		Local node:TxmlNode=TxmlNode(root.getFirstChild())
		While node
			Local kind:String=node.getName()
			If kind="group" Or kind="layer" Or kind="objectgroup" Or kind="imagelayer" Then
				Local tr:Float=red,tg:Float=green,tb:Float=blue,ta:Float=tintAlpha
				ReadTint(Attr(node,"tintcolor","#ffffffff"),tr,tg,tb,ta)
				Local px:Double=parallaxX*Decimal(node,"parallaxx",1),py:Double=parallaxY*Decimal(node,"parallaxy",1)
				If IsInf(px) Or IsInf(py) Then Throw "parallax factor overflow"
				If Attr(node,"mode","normal")<>"normal" Then Throw "layer blend modes are not supported yet"
				Local info:TTiledLayerInfo=New TTiledLayerInfo
				info.kind=kind
				info.id=Number(node,"id",0,0,2147483647); info.name=Attr(node,"name"); info.className=Attr(node,"class"); info.parent=parent
				ReadProperties(node,info.properties,ExtractDir(map.sourcePath))
				map.importedLayers=map.importedLayers[..map.importedLayers.Length+1]; map.importedLayers[map.importedLayers.Length-1]=info
				Local x:Double=ox+Decimal(node,"offsetx",0),y:Double=oy+Decimal(node,"offsety",0)
				Local alpha:Double=Decimal(node,"opacity",1)
				If alpha<0 Or alpha>1 Then Throw "layer opacity out of range"
				alpha:*opacity
				Local shown:Int=visible And Number(node,"visible",1,0,1)
				If kind="group" Then
					If Number(node,"x",0) Or Number(node,"y",0) Then Throw "nonzero legacy group coordinates are not supported"
					ReadLayers(node,info,x,y,Float(alpha),shown,depth+1,px,py,tr,tg,tb,ta)
				Else
					Local layer:TTileLayer=map.AddLayer(info.name)
					info.layer=layer; layer.properties=info.properties
					layer.renderOrder=map.renderOrder
					layer.parallaxX=px; layer.parallaxY=py
					layer.tintRed=tr; layer.tintGreen=tg; layer.tintBlue=tb; layer.tintAlpha=ta
					layer.offsetX=Float(x); layer.offsetY=Float(y); layer.opacity=Float(alpha); layer.visible=shown
					If IsInf(layer.offsetX) Or IsInf(layer.offsetY) Then Throw "layer offset exceeds native precision"
					If kind="imagelayer" Then
						layer.offsetX:+Float(Decimal(node,"x",0)-map.originX); layer.offsetY:+Float(Decimal(node,"y",0))
						layer.repeatX=Number(node,"repeatx",0,0,1); layer.repeatY=Number(node,"repeaty",0,0,1)
						Local picture:TxmlNode=Child(node,"image")
						If picture Then
							layer.image=LoadImage(ReadImage(picture,ExtractDir(map.sourcePath)),imageFlags)
							If Not layer.image Then Throw "cannot create layer image"
						End If
					Else If kind="objectgroup" Then
						If Number(node,"x",0) Or Number(node,"y",0) Then Throw "nonzero legacy object layer coordinates are not supported"
						Local order:String=Attr(node,"draworder","topdown")
						If order<>"topdown" And order<>"index" Then Throw "invalid object draw order"
						layer.objectTopDown=order="topdown"
						layer.objects=ReadObjects(node,ExtractDir(map.sourcePath),False)
						' Object positions already include Tiled's isometric screen origin.
						layer.offsetX:-Float(map.originX)
					Else
						Local data:TxmlNode=Child(node,"data")
						If Not data Then Throw "tile layer has no data"
						Local encoding:String=Attr(data,"encoding"),compression:String=Attr(data,"compression")
						Local cx:Int=Number(node,"x",0,-TILE_COORDINATE_LIMIT,TILE_COORDINATE_LIMIT),cy:Int=Number(node,"y",0,-TILE_COORDINATE_LIMIT,TILE_COORDINATE_LIMIT)
						If map.infinite Then
							Local chunk:TxmlNode=TxmlNode(data.getFirstChild())
							While chunk
								If chunk.getName()="chunk" Then
									ReadCells(layer,chunk,Number(chunk,"x",0,-TILE_COORDINATE_LIMIT,TILE_COORDINATE_LIMIT)+cx,Number(chunk,"y",0,-TILE_COORDINATE_LIMIT,TILE_COORDINATE_LIMIT)+cy,Number(chunk,"width",0,1,TILED_MAX_CELLS),Number(chunk,"height",0,1,TILED_MAX_CELLS),encoding,compression)
								End If
								chunk=chunk.nextSibling()
							Wend
						Else
							If Child(data,"chunk") Then Throw "chunks require an infinite map"
							ReadCells(layer,data,cx,cy,Number(node,"width",map.width,1,TILED_MAX_CELLS),Number(node,"height",map.height,1,TILED_MAX_CELLS),encoding,compression)
						End If
					End If
				End If
			End If
			node=node.nextSibling()
		Wend
	End Method

	Rem
	bbdoc: Decodes a layer rectangle and populates tile IDs and transformation flags.
	param: Layer to inspect or draw; Null uses the map's default grid where supported.
	param: Source document node to inspect.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	param: Tiled layer encoding, such as csv or base64.
	param: Tiled compression name, such as zlib, gzip or zstd.
	End Rem
	Method ReadCells(layer:TTileLayer,node:TxmlNode,x:Int,y:Int,w:Int,h:Int,encoding:String,compression:String)
		Local total:Long=Long(w)*h
		cellsRead:+total
		If total>TILED_MAX_CELLS Or cellsRead>TILED_MAX_CELLS Then Throw "map exceeds tile data limit"
		TTileGrid.CheckCell(x,y)
		If Long(x)+w-1>TILE_COORDINATE_LIMIT Or Long(y)+h-1>TILE_COORDINATE_LIMIT Then Throw "tile data exceeds coordinate limits"
		Local count:Int=Int(total),gids:Long[]=New Long[count]
		Select encoding
			Case ""
				If compression Then Throw "compression requires base64"
				Local tile:TxmlNode=TxmlNode(node.getFirstChild()),i:Int
				While tile
					If tile.getName()="tile" Then
						If i>=count Then Throw "too many tile IDs"
						gids[i]=BoundedInteger(Attr(tile,"gid","0"),0,4294967295:Long); i:+1
					End If
					tile=tile.nextSibling()
				Wend
				If i<>count Then Throw "wrong tile ID count"
			Case "csv"
				If compression Then Throw "compression requires base64"
				Local values:String[]=node.getContent().Trim().Split(",")
				If values.Length<>count Then Throw "wrong CSV tile ID count"
				For Local i:Int=0 Until count
					gids[i]=BoundedInteger(values[i].Trim(),0,4294967295:Long)
				Next
			Case "base64"
				Local text:String=node.getContent().Replace("~r","").Replace("~n","").Replace("~t","").Replace(" ","")
				ValidateBase64(text)
				Local bytes:Byte[]=TBase64.Decode(text)
				If compression Then
					bytes=DecodeTiledData(compression,bytes,count*4)
				End If
				If bytes.Length<>count*4 Then Throw "wrong decoded tile data size"
				For Local i:Int=0 Until count
					Local p:Int=i*4
					gids[i]=Long(bytes[p]) | (Long(bytes[p+1]) Shl 8) | (Long(bytes[p+2]) Shl 16) | (Long(bytes[p+3]) Shl 24)
				Next
			Default; Throw "unsupported tile encoding: "+encoding
		End Select
		For Local i:Int=0 Until count
			Local gid:Long=gids[i]
			If Not (gid & $0fffffff) Then Continue
			Local flip:ETileFlip,id:Int=ResolveGID(gid,flip)
			layer.SetCell(x+i Mod w,y+i/w,id,flip)
		Next
	End Method

	Rem
	bbdoc: Resolves a Tiled global tile ID and extracts its transformation flags.
	param: Tiled global tile ID, including encoded flip and rotation bits.
	param: Receives tile reflection and rotation flags.
	End Rem
	Method ResolveGID:Int(gid:Long,flip:ETileFlip Var)
		Local raw:Int=Int(gid & $0fffffff),id:Int
		For Local j:Int=map.importedTilesets.Length-1 To 0 Step -1
			Local set:TTiledTileset=map.importedTilesets[j]
			If raw>=set.firstGID Then id=set.NativeID(raw-set.firstGID); Exit
		Next
		If Not id Then Throw "unknown tile GID: "+raw
		flip=ETileFlip.None
		If gid & $80000000:Long Then flip:|ETileFlip.Horizontal
		If gid & $40000000 Then flip:|ETileFlip.Vertical
		If map.grid.IsHex() Then
			If gid & $20000000 Then flip:|ETileFlip.Rotate60
			If gid & $10000000 Then flip:|ETileFlip.Rotate120
		Else
			If gid & $20000000 Then flip:|ETileFlip.Diagonal
		End If
		Return id
	End Method

	Rem
	bbdoc: Imports object geometry, text, templates and tile references.
	param: Root element or heap index from which processing begins.
	param: Owning document directory or URL used to resolve relative paths.
	param: Whether imported objects describe tile-local collision geometry.
	End Rem
	Method ReadObjects:TTileObject[](root:TxmlNode,base:String,collision:Int)
		Local items:TTileObject[]=New TTileObject[16],count:Int
		Local node:TxmlNode=TxmlNode(root.getFirstChild())
		While node
			If node.getName()="object" Then
				objectsRead:+1
				If objectsRead>65536 Then Throw "too many objects"
				Local original:TxmlNode=node,expanded:TxmlNode
				Try
					If node.hasAttribute("template") Then expanded=TTiledTemplates.ExpandObject(Self,node,base,0); node=expanded
					Local textNode:TxmlNode=Child(node,"text")
					Local obj:TTileObject=New TTileObject
					obj.id=Number(node,"id",0,0,2147483647)
					If Not collision And obj.id Then
						Local exists:Int
						If objectIDs.TryGetValue(obj.id,exists) Then Throw "duplicate object ID"
						objectIDs.Put(obj.id,1)
					End If
					obj.name=Attr(node,"name"); obj.className=Attr(node,"type",Attr(node,"class"))
					obj.visible=Number(node,"visible",1,0,1)
					obj.x=Decimal(node,"x",0); obj.y=Decimal(node,"y",0)
					obj.width=Decimal(node,"width",0); obj.height=Decimal(node,"height",0)
					obj.SetRotation(Decimal(node,"rotation",0))
					ReadProperties(node,obj.properties,base)
					Local polygon:TxmlNode=Child(node,"polygon"),line:TxmlNode=Child(node,"polyline")
					Local ellipse:TxmlNode=Child(node,"ellipse"),point:TxmlNode=Child(node,"point")
					If Int(polygon<>Null)+Int(line<>Null)+Int(ellipse<>Null)+Int(point<>Null)+Int(node.hasAttribute("gid"))+Int(textNode<>Null)>1 Then Throw "multiple object shapes"
					If polygon Or line Then
						obj.shape=ETileObjectShape.Polygon
						If line Then obj.shape=ETileObjectShape.Polyline; polygon=line
						Local coords:String=Attr(polygon,"points").Replace("~t"," ").Replace("~n"," ").Replace("~r"," ")
						Local tokens:String[]=coords.Split(" "),n:Int
						If tokens.Length>65536 Or pointsRead+tokens.Length>1048576 Then Throw "too many object points"
						obj.points=New STilePoint[tokens.Length]
						For Local token:String=EachIn tokens
							If Not token Then Continue
							Local pair:String[]=token.Split(",")
							If pair.Length<>2 Then Throw "invalid object point"
							obj.points[n].x=Real(pair[0]); obj.points[n].y=Real(pair[1]); n:+1
						Next
						obj.points=obj.points[..n]; pointsRead:+n
					Else If ellipse Then
						obj.shape=ETileObjectShape.Ellipse
					Else If point Then
						obj.shape=ETileObjectShape.Point
					End If
					If textNode Then
						If collision Then Throw "text is not collision geometry"
						obj.text=ReadText(textNode)
						obj.text.Prepare(Float(obj.width),Float(obj.height))
					End If
					Local isometric:Int=Not collision And map.orientation="isometric"
					If isometric Then
						Local px:Double=obj.x,py:Double=obj.y,ratio:Double=map.grid.TileWidth()/(2*map.grid.TileHeight())
						obj.x=(px-py)*ratio+Double(map.height)*map.grid.TileWidth()/2
						obj.y=(px+py)/2
						If Not node.hasAttribute("gid") And Not textNode Then
							' Project shape geometry, then rotate in screen space about the object origin.
							Local c:Double=obj.xx,sn:Double=obj.yx
							obj.xx=c*ratio-sn/2; obj.xy=-c*ratio-sn/2
							obj.yx=sn*ratio+c/2; obj.yy=-sn*ratio+c/2
						End If
					End If
					obj.sortY=obj.y
					If node.hasAttribute("gid") Then
						If collision Then Throw "tile objects inside collision groups are not supported"
						Local gid:Long=BoundedInteger(Attr(node,"gid"),1,4294967295:Long)
						obj.tile=ResolveGID(gid,obj.flip)
						Local tile:TTileDefinition=map.tileset.tiles[obj.tile],set:TTiledTileset
						For Local candidate:TTiledTileset=EachIn map.importedTilesets
							If candidate.firstGID<=Int(gid & $0fffffff) Then set=candidate
						Next
						If set.fillMode="preserve-aspect-fit" Then obj.fillMode=ETileFillMode.PreserveAspectFit
						If Not node.hasAttribute("width") Then obj.width=tile.image.width
						If Not node.hasAttribute("height") Then obj.height=tile.image.height
						obj.tileProperties=tile.properties
						obj.properties.InheritClasses(tile.properties)
						If Not obj.className Then set.classes.TryGetValue(Int(gid & $0fffffff)-set.firstGID,obj.className)
						Local alignment:String=set.objectAlignment,ax:Double,ay:Double
						If alignment="unspecified" Then
							alignment="bottomleft"
							If isometric Then alignment="bottom"
						End If
						Select alignment
							Case "topleft"; ax=0; ay=0
							Case "top"; ax=0.5; ay=0
							Case "topright"; ax=1; ay=0
							Case "left"; ax=0; ay=0.5
							Case "center"; ax=0.5; ay=0.5
							Case "right"; ax=1; ay=0.5
							Case "bottomleft"; ax=0; ay=1
							Case "bottom"; ax=0.5; ay=1
							Case "bottomright"; ax=1; ay=1
							Default; Throw "invalid tile object alignment"
						End Select
						Local sx:Float,sy:Float,px:Float,py:Float
						TileImageFit(tile.image.width,tile.image.height,Float(obj.width),Float(obj.height),obj.fillMode,sx,sy,px,py)
						Local dx:Double=-ax*obj.width+set.offsetX*sx
						Local dy:Double=-ay*obj.height+set.offsetY*sy
						obj.x:+obj.xx*dx+obj.xy*dy; obj.y:+obj.yx*dx+obj.yy*dy
					End If
					If collision Then obj.x:+Decimal(root,"offsetx",0); obj.y:+Decimal(root,"offsety",0)
					obj.Validate()
					If count=items.Length Then items=items[..count*2]
					items[count]=obj; count:+1
				Finally
					node=original
					If expanded Then expanded.Free()
				End Try
			End If
			node=node.nextSibling()
		Wend
		Return items[..count]
	End Method

	Rem
	bbdoc: Imports a Tiled text object's content, font request and alignment.
	param: Source document node to inspect.
	End Rem
	Method ReadText:TTileText(node:TxmlNode)
		Local value:TTileText=New TTileText
		value.text=node.getContent(); textCharacters:+value.text.Length
		If textCharacters>1048576 Then Throw "too much map text"
		value.fontFamily=Attr(node,"fontfamily","sans-serif"); value.pixelSize=Number(node,"pixelsize",16,1,4096)
		value.bold=Number(node,"bold",0,0,1); value.italic=Number(node,"italic",0,0,1)
		value.underline=Number(node,"underline",0,0,1); value.strikeout=Number(node,"strikeout",0,0,1)
		value.kerning=Number(node,"kerning",1,0,1); value.wrap=Number(node,"wrap",0,0,1)
		Select Attr(node,"halign","left")
			Case "left"
			Case "center"; value.alignment=TEXT_ALIGN_CENTER
			Case "right"; value.alignment=TEXT_ALIGN_RIGHT
			Case "justify"; value.justify=True
			Default; Throw "invalid text horizontal alignment"
		End Select
		Select Attr(node,"valign","top")
			Case "top"
			Case "center"; value.verticalAlignment=TEXT_ALIGN_MIDDLE
			Case "bottom"; value.verticalAlignment=TEXT_ALIGN_BOTTOM
			Default; Throw "invalid text vertical alignment"
		End Select
		Local r:Float=1,g:Float=1,b:Float=1,a:Float=1
		ReadTint(Attr(node,"color","#000000"),r,g,b,a)
		value.red=Int(r*255+0.5); value.green=Int(g*255+0.5); value.blue=Int(b*255+0.5); value.alpha=a
		If fontResolver Then value.font=fontResolver.Resolve(value.fontFamily,value.pixelSize,value.bold,value.italic,value.kerning)
		Return value
	End Method

	Rem
	bbdoc: Parses a Tiled colour into normalized red, green, blue and alpha components.
	param: Tiled colour string in #RRGGBB or #AARRGGBB form.
	param: Receives red multiplier from 0.0 to 1.0.
	param: Receives green multiplier from 0.0 to 1.0.
	param: Receives blue multiplier from 0.0 to 1.0.
	param: Receives alpha multiplier from 0.0 to 1.0.
	End Rem
	Function ReadTint(color:String,red:Float Var,green:Float Var,blue:Float Var,alpha:Float Var)
		If Not color.StartsWith("#") Or (color.Length<>7 And color.Length<>9) Then Throw "invalid layer tint"
		color=color[1..].ToLower()
		For Local i:Int=0 Until color.Length
			If "0123456789abcdef".Find(color[i..i+1])<0 Then Throw "invalid layer tint"
		Next
		Local value:Long=Long("$"+color)
		red:*Float((value Shr 16)&255)/255; green:*Float((value Shr 8)&255)/255; blue:*Float(value&255)/255
		If color.Length=8 Then alpha:*Float((value Shr 24)&255)/255
	End Function

	Rem
	bbdoc: Imports typed properties and resolves file paths relative to their document.
	param: Root element or heap index from which processing begins.
	param: Property collection to populate or merge.
	param: Owning document directory or URL used to resolve relative paths.
	param: Current property-nesting depth, checked against import limits.
	End Rem
	Method ReadProperties(root:TxmlNode,properties:TTileProperties,base:String,depth:Int=0)
		If depth>64 Then Throw "class properties nested too deeply"
		Local parent:TxmlNode=Child(root,"properties")
		If Not parent Then Return
		Local node:TxmlNode=TxmlNode(parent.getFirstChild())
		While node
			If node.getName()="property" Then
				propertiesRead:+1
				If propertiesRead>1048576 Then Throw "too many properties"
				Local name:String=Attr(node,"name"),value:String=Attr(node,"value",node.getContent())
				Select Attr(node,"type","string")
					Case "class"
						If Not node.hasAttribute("propertytype") Then Throw "class property requires propertytype"
						Local members:TTileProperties=New TTileProperties
						ReadProperties(node,members,base,depth+1)
						properties.SetClass(name,Attr(node,"propertytype"),members)
					Case "string","color"; properties.SetString(name,value)
					Case "file"
						If value Then value=Resolve(base,value)
						properties.SetString(name,value)
					Case "int","object"; properties.SetLong(name,Integer(value))
					Case "float"; properties.SetDouble(name,Real(value))
					Case "bool"
						If value<>"true" And value<>"false" And value<>"1" And value<>"0" Then Throw "invalid Boolean property"
						properties.SetBool(name,value="true" Or value="1")
					Default; Throw "unsupported property type: "+Attr(node,"type")
				End Select
				properties.SetValue(name,properties.Get(name).WithMetadata(Attr(node,"type","string"),Attr(node,"propertytype")))
			End If
			node=node.nextSibling()
		Wend
	End Method

	Rem
	bbdoc: Loads image pixels referenced by a Tiled image element.
	param: Source document node to inspect.
	param: Owning document directory or URL used to resolve relative paths.
	End Rem
	Function ReadImage:TPixmap(node:TxmlNode,base:String)
		Local path:String=Resolve(base,Attr(node,"source"))
		Local pixels:TPixmap=LoadPixmap(path)
		If Not pixels Then Throw "cannot load image: "+path
		pixels=pixels.Convert(PF_RGBA8888)
		Local trans:String=Attr(node,"trans")
		If trans Then
			If trans.StartsWith("#") Then trans=trans[1..]
			If trans.Length<>6 Then Throw "invalid image transparent colour"
			For Local i:Int=0 Until trans.Length
				If "0123456789abcdef".Find(trans[i..i+1].ToLower())<0 Then Throw "invalid image transparent colour"
			Next
			Local color:Int=Int("$"+trans)
			For Local y:Int=0 Until pixels.height
				For Local x:Int=0 Until pixels.width
					If (pixels.ReadPixel(x,y)&$ffffff)=color Then pixels.WritePixel(x,y,0)
				Next
			Next
		End If
		Return pixels
	End Function

	Rem
	bbdoc: Resolves an image, template or tileset path relative to its owning document.
	param: Owning document directory or URL used to resolve relative paths.
	param: Resource filename or filesystem URL.
	End Rem
	Function Resolve:String(base:String,path:String)
		If Not path Then Throw "empty resource path"
		path=path.Replace("\","/")
		If path.Find("::")>=0 Then Return NormalizePath(path)
		If Not path.StartsWith("/") And Not (path.Length>1 And path[1]=58) And base Then path=base+"/"+path
		Return NormalizePath(path)
	End Function

	Rem
	bbdoc: Normalizes path separators and relative components for resource lookup.
	param: Resource filename or filesystem URL.
	End Rem
	Function NormalizePath:String(path:String)
		path=path.Replace("\","/")
		Local separator:Int=path.Find("::")
		If separator<0 Then Return RealPath(path)
		' Keep the stream-factory namespace; resolve dot segments within it.
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

	Rem
	bbdoc: Returns the first child XML element with the requested name.
	param: Parent document node or imported group.
	param: Name used to register or look up the item.
	End Rem
	Function Child:TxmlNode(parent:TxmlNode,name:String)
		Local node:TxmlNode=TxmlNode(parent.getFirstChild())
		While node
			If node.getName()=name Then Return node
			node=node.nextSibling()
		Wend
	End Function

	Rem
	bbdoc: Gets an XML attribute or returns the supplied fallback.
	param: Source document node to inspect.
	param: Name used to register or look up the item.
	param: Value to return when the requested item is absent.
	End Rem
	Function Attr:String(node:TxmlNode,name:String,fallback:String="")
		If node.hasAttribute(name) Then Return node.getAttribute(name)
		Return fallback
	End Function

	Rem
	bbdoc: Parses a bounded integer XML attribute or returns the supplied fallback.
	param: Source document node to inspect.
	param: Name used to register or look up the item.
	param: Value to return when the requested item is absent.
	param: Smallest permitted numeric value, inclusive.
	param: Largest permitted numeric value, inclusive.
	End Rem
	Function Number:Int(node:TxmlNode,name:String,fallback:Int=0,minimum:Int=-2147483647,maximum:Int=2147483647)
		Return Int(BoundedInteger(Attr(node,name,String(fallback)),minimum,maximum))
	End Function

	Rem
	bbdoc: Parses a finite floating-point XML attribute or returns the supplied fallback.
	param: Source document node to inspect.
	param: Name used to register or look up the item.
	param: Value to return when the requested item is absent.
	End Rem
	Function Decimal:Double(node:TxmlNode,name:String,fallback:Double)
		Return Real(Attr(node,name,String(fallback)))
	End Function

	Rem
	bbdoc: Parses a signed decimal integer, rejecting invalid input.
	param: Value to read, convert or store.
	End Rem
	Function Integer:Long(value:String)
		value=value.Trim()
		Local negative:Int=value.StartsWith("-"),digits:String=value
		If negative Or value.StartsWith("+") Then digits=value[1..]
		If Not digits Then Throw "invalid integer: "+value
		For Local i:Int=0 Until digits.Length
			If digits[i]<48 Or digits[i]>57 Then Throw "invalid integer: "+value
		Next
		While digits.Length>1 And digits[0]=48
			digits=digits[1..]
		Wend
		Local limit:String="9223372036854775807"
		If negative Then limit="9223372036854775808"
		If digits.Length>19 Or (digits.Length=19 And digits>limit) Then Throw "integer overflow"
		Local result:Long=Long(value)
		Return result
	End Function

	Rem
	bbdoc: Parses a signed decimal integer and checks its allowed range.
	param: Value to read, convert or store.
	param: Smallest permitted numeric value, inclusive.
	param: Largest permitted numeric value, inclusive.
	End Rem
	Function BoundedInteger:Long(value:String,minimum:Long,maximum:Long)
		Local result:Long=Integer(value)
		If result<minimum Or result>maximum Then Throw "integer out of range: "+value
		Return result
	End Function

	Rem
	bbdoc: Parses a finite floating-point value, rejecting invalid input.
	param: Value to read, convert or store.
	End Rem
	Function Real:Double(value:String)
		value=value.Trim().ToLower()
		Local digits:Int,dot:Int,exponent:Int
		For Local i:Int=0 Until value.Length
			Local c:Int=value[i]
			If c>=48 And c<=57 Then
				digits:+1
			Else If (c=43 Or c=45) And (i=0 Or value[i-1]=101) Then
				Continue
			Else If c=46 And Not dot And Not exponent Then
				dot=True
			Else If c=101 And Not exponent And digits Then
				exponent=True; digits=0
			Else
				Throw "invalid number: "+value
			End If
		Next
		If Not digits Then Throw "invalid number: "+value
		Local result:Double=Double(value)
		If IsNan(result) Or IsInf(result) Then Throw "non-finite number"
		Return result
	End Function

	Rem
	bbdoc: Rejects malformed base64 text before allocating a decoded layer payload.
	param: Value to read, convert or store.
	End Rem
	Function ValidateBase64(value:String)
		If value.Length Mod 4 Then Throw "invalid base64 length"
		Local padding:Int
		For Local i:Int=0 Until value.Length
			If value[i]=61 Then
				padding:+1
				If padding>2 Or i<value.Length-2 Then Throw "invalid base64 padding"
			Else
				If padding Or "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".Find(value[i..i+1])<0 Then Throw "invalid base64 data"
			End If
		Next
	End Function

End Type
