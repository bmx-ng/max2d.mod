Type TTileDefinition
	Field collisions:TTileObject[]=New TTileObject[0]
	Field properties:TTileProperties=New TTileProperties
	Field image:TImage
	Field frame:Int,animated:Int
	Field drawWidth:Float,drawHeight:Float
	Field fillMode:ETileFillMode
	Field offsetX:Float,offsetY:Float
	Field depthOffset:Float,sortOrder:Int
End Type

Rem
bbdoc: Shared artwork definitions. Tile ID zero denotes an empty cell.
about: Artwork is positioned relative to the cell bounding-box origin; image handles are ignored. Treat registered artwork fields as read-only; use Properties and SetDepth for metadata and depth changes.
End Rem
Type TTileSet
	Field tiles:TTileDefinition[]=New TTileDefinition[1]
	Method Add:Int(image:TImage,frame:Int=0,offsetX:Float=0,offsetY:Float=0)
		If Not image Then Throw "Max2D tilemap: tile image is null"
		image.CheckIndex(frame)
		If IsNan(offsetX) Or IsInf(offsetX) Or IsNan(offsetY) Or IsInf(offsetY) Then Throw "Max2D tilemap: invalid artwork offset"
		Local tile:TTileDefinition=New TTileDefinition
		tile.image=image; tile.drawWidth=image.width; tile.drawHeight=image.height; tile.frame=frame; tile.offsetX=offsetX; tile.offsetY=offsetY
		Local id:Int=tiles.Length
		tiles=tiles[..id+1]; tiles[id]=tile
		Return id
	End Method
	Rem
	bbdoc: Sets the displayed tile canvas. Aspect-fit artwork is centred within it; offsets remain in map units.
	End Rem
	Method SetSize(tile:Int,width:Float,height:Float,fillMode:ETileFillMode=ETileFillMode.Stretch)
		If tile<=0 Or tile>=tiles.Length Then Throw "Max2D tilemap: tile ID out of range"
		If IsNan(width) Or IsInf(width) Or IsNan(height) Or IsInf(height) Or width<=0 Or height<=0 Then Throw "Max2D tilemap: invalid tile size"
		If fillMode<>ETileFillMode.Stretch And fillMode<>ETileFillMode.PreserveAspectFit Then Throw "Max2D tilemap: invalid fill mode"
		tiles[tile].drawWidth=width; tiles[tile].drawHeight=height; tiles[tile].fillMode=fillMode
	End Method
	Method Properties:TTileProperties(tile:Int)
		If tile<=0 Or tile>=tiles.Length Then Throw "Max2D tilemap: tile ID out of range"
		Return tiles[tile].properties
	End Method
	Method AddAnimation:Int(image:TImage,offsetX:Float=0,offsetY:Float=0)
		If Not image Then Throw "Max2D tilemap: tile image is null"
		image.AnimationDuration()
		Local id:Int=Add(image,0,offsetX,offsetY)
		tiles[id].animated=True
		Return id
	End Method
	Rem
	bbdoc: Sets depth relative to the cell bottom, plus an explicit tie-break order.
	End Rem
	Method SetDepth(tile:Int,offset:Float=0,order:Int=0)
		If tile<=0 Or tile>=tiles.Length Then Throw "Max2D tilemap: tile ID out of range"
		If IsNan(offset) Or IsInf(offset) Then Throw "Max2D tilemap: invalid depth offset"
		tiles[tile].depthOffset=offset; tiles[tile].sortOrder=order
	End Method

End Type

Type TTileChunk
	Field cells:Int[]=New Int[TILE_CHUNK_SIZE*TILE_CHUNK_SIZE]
	Field flips:ETileFlip[]=New ETileFlip[TILE_CHUNK_SIZE*TILE_CHUNK_SIZE]
	Field count:Int
	Field properties:TTreeMap<Int,TTileProperties>
End Type

Rem
bbdoc: Sparse tile layer, divided into 32 by 32 chunks. Negative columns and rows are supported.
End Rem
Type TTileLayer
	Field image:TImage,repeatX:Int,repeatY:Int
	Field tintRed:Float=1,tintGreen:Float=1,tintBlue:Float=1,tintAlpha:Float=1
	Field parallaxX:Double=1,parallaxY:Double=1
	' Visual scale only; gameplay geometry remains in nominal layer coordinates.
	Field drawScale:Double=1
	Field objects:TTileObject[]=New TTileObject[0]
	Field objectTopDown:Int=True
	Method AddObject(item:TTileObject)
		If Not item Then Throw "Max2D tilemap: null object"
		item.Validate()
		If item.tile<0 Or item.tile>=_tiles.tiles.Length Then Throw "Max2D tilemap: invalid object tile"
		objects=objects[..objects.Length+1]; objects[objects.Length-1]=item
	End Method
	Method ObjectByID:TTileObject(id:Int)
		For Local item:TTileObject=EachIn objects
			If item.id=id Then Return item
		Next
	End Method
	Method QueryObjects:TTileObjectQueryResult(x:Double,y:Double,width:Double,height:Double,result:TTileObjectQueryResult=Null)
		CheckTileObjectRegion(x,y,width,height)
		If Not result Then result=New TTileObjectQueryResult
		result.Clear()
		For Local obj:TTileObject=EachIn objects
			Local item:STileObjectInstance=obj.Instance(offsetX,offsetY)
			item.layer=Self
			If TileObjectOverlaps(item,x,y,width,height) Then result.Add(item)
		Next
		Return result
	End Method
	Method QueryObjectsAtPoint:TTileObjectQueryResult(x:Double,y:Double,tolerance:Double=0,result:TTileObjectQueryResult=Null)
		If Not (tolerance>=0) Or IsInf(tolerance) Then Throw "Max2D tilemap: invalid picking tolerance"
		CheckTileObjectRegion(x,y,0,0)
		If Not result Then result=New TTileObjectQueryResult
		result.Clear()
		For Local obj:TTileObject=EachIn objects
			Local item:STileObjectInstance=obj.Instance(offsetX,offsetY)
			item.layer=Self
			If item.ContainsPoint(x,y,tolerance) Then result.Add(item)
		Next
		Return result
	End Method
	Field properties:TTileProperties=New TTileProperties
	Field name:String
	Field sortMode:ETileSort=ETileSort.Grid
	Field renderOrder:ETileRenderOrder=ETileRenderOrder.RightDown
	Field sprites:TTileSprite[]=New TTileSprite[0]
	Field visible:Int=True
	Field opacity:Float=1
	Field offsetX:Float,offsetY:Float
	Private
	Field _tiles:TTileSet
	Field _chunks:TTreeMap<Long,TTileChunk>=New TTreeMap<Long,TTileChunk>
	Field _count:Int
	Field _left:Int,_top:Int,_right:Int,_bottom:Int
	Public
	Function Create:TTileLayer(tileset:TTileSet,name:String="")
		If Not tileset Then Throw "Max2D tilemap: tileset is required"
		Local layer:TTileLayer=New TTileLayer
		layer._tiles=tileset; layer.name=name
		Return layer
	End Function
	Rem
	bbdoc: Returns conservative inclusive cell bounds, or False for an empty layer. Removing cells may leave wider bounds until Clear.
	End Rem
	Method Bounds:Int(left:Int Var,top:Int Var,right:Int Var,bottom:Int Var)
		left=_left; top=_top; right=_right; bottom=_bottom
		Return _count>0
	End Method
	Function ChunkCoordinate:Int(cell:Int)
		Return Int(Floor(Double(cell)/TILE_CHUNK_SIZE))
	End Function
	Function ChunkKey:Long(column:Int,row:Int)
		Return (Long(column) Shl 32) | Long(UInt(row))
	End Function
	Method Chunk:TTileChunk(column:Int,row:Int)
		Local chunk:TTileChunk
		_chunks.TryGetValue(ChunkKey(column,row),chunk)
		Return chunk
	End Method
	Method Cell:Int(column:Int,row:Int)
		TTileGrid.CheckCell(column,row)
		Local cx:Int=ChunkCoordinate(column),cy:Int=ChunkCoordinate(row)
		Local chunk:TTileChunk=Chunk(cx,cy)
		If Not chunk Then Return 0
		Return chunk.cells[(row-cy*TILE_CHUNK_SIZE)*TILE_CHUNK_SIZE+column-cx*TILE_CHUNK_SIZE]
	End Method
	Method CellFlip:ETileFlip(column:Int,row:Int)
		TTileGrid.CheckCell(column,row)
		Local cx:Int=ChunkCoordinate(column),cy:Int=ChunkCoordinate(row)
		Local chunk:TTileChunk=Chunk(cx,cy)
		If Not chunk Then Return ETileFlip.None
		Return chunk.flips[(row-cy*TILE_CHUNK_SIZE)*TILE_CHUNK_SIZE+column-cx*TILE_CHUNK_SIZE]
	End Method
	Method SetCell(column:Int,row:Int,tile:Int,flip:ETileFlip=ETileFlip.None)
		TTileGrid.CheckCell(column,row)
		If Not _tiles Or tile<0 Or tile>=_tiles.tiles.Length Then Throw "Max2D tilemap: tile ID out of range"
		ValidateTileFlip(flip)
		Local cx:Int=ChunkCoordinate(column),cy:Int=ChunkCoordinate(row)
		Local chunk:TTileChunk=Chunk(cx,cy)
		If Not chunk Then
			If tile=0 Then Return
			chunk=New TTileChunk; _chunks.Put(ChunkKey(cx,cy),chunk)
		End If
		Local index:Int=(row-cy*TILE_CHUNK_SIZE)*TILE_CHUNK_SIZE+column-cx*TILE_CHUNK_SIZE
		Local change:Int=Int(tile<>0)-Int(chunk.cells[index]<>0)
		If tile And _count=0 Then _left=column; _right=column; _top=row; _bottom=row
		If tile Then
			_left=Min(_left,column); _right=Max(_right,column)
			_top=Min(_top,row); _bottom=Max(_bottom,row)
		End If
		If tile=0 Then flip=ETileFlip.None
		If tile<>chunk.cells[index] And chunk.properties Then chunk.properties.Remove(index)
		chunk.cells[index]=tile; chunk.flips[index]=flip
		chunk.count:+change; _count:+change
		If chunk.count=0 Then _chunks.Remove(ChunkKey(cx,cy))
	End Method
	Rem
	bbdoc: Returns optional per-cell overrides. Creating overrides requires an occupied cell.
	End Rem
	Method CellProperties:TTileProperties(column:Int,row:Int,create:Int=False)
		Local id:Int=Cell(column,row)
		If Not id Then
			If create Then Throw "Max2D tilemap: properties require an occupied cell"
			Return Null
		End If
		Local cx:Int=ChunkCoordinate(column),cy:Int=ChunkCoordinate(row)
		Local chunk:TTileChunk=Chunk(cx,cy)
		Local index:Int=(row-cy*TILE_CHUNK_SIZE)*TILE_CHUNK_SIZE+column-cx*TILE_CHUNK_SIZE
		Local result:TTileProperties
		If chunk.properties Then chunk.properties.TryGetValue(index,result)
		If Not result And create Then
			result=New TTileProperties
			If Not chunk.properties Then chunk.properties=New TTreeMap<Int,TTileProperties>
			chunk.properties.Put(index,result)
		End If
		Return result
	End Method
	Rem
	bbdoc: Resolves a cell override first, then the shared tile definition. Missing properties return Null.
	End Rem
	Method Property:TTileProperty(column:Int,row:Int,name:String)
		Local properties:TTileProperties=CellProperties(column,row)
		Local value:TTileProperty
		If properties Then value=properties.Get(name)
		If value Then Return value
		Local id:Int=Cell(column,row)
		If id Then Return _tiles.Properties(id).Get(name)
		Return Null
	End Method
	Rem
	bbdoc: Collects occupied cells within inclusive integer bounds. Reuses and clears result when supplied.
	End Rem
	Method QueryCells:TTileQueryResult(left:Int,top:Int,right:Int,bottom:Int,result:TTileQueryResult=Null)
		TTileGrid.CheckCell(left,top); TTileGrid.CheckCell(right,bottom)
		If Not result Then result=New TTileQueryResult
		result.Clear()
		If left>right Or top>bottom Or Not _count Then Return result
		left=Max(left,_left); top=Max(top,_top); right=Min(right,_right); bottom=Min(bottom,_bottom)
		If left>right Or top>bottom Then Return result
		Local cx0:Int=ChunkCoordinate(left),cy0:Int=ChunkCoordinate(top),cx1:Int=ChunkCoordinate(right),cy1:Int=ChunkCoordinate(bottom)
		If Long(cx1-cx0+1)*(cy1-cy0+1)>_chunks.Count() Then
			For Local node:IMapNode<Long,TTileChunk>=EachIn _chunks
				Local key:Long=node.GetKey(),cx:Int=Int(key Shr 32),cy:Int=Int(key)
				If cx<cx0 Or cx>cx1 Or cy<cy0 Or cy>cy1 Then Continue
				CollectChunk(node.GetValue(),cx,cy,left,top,right,bottom,result)
			Next
		Else
			For Local cx:Int=cx0 To cx1
				For Local cy:Int=cy0 To cy1
					Local chunk:TTileChunk=Chunk(cx,cy)
					If chunk Then CollectChunk(chunk,cx,cy,left,top,right,bottom,result)
				Next
			Next
		End If
		Return result
	End Method
	Private
	Method CollectChunk(chunk:TTileChunk,cx:Int,cy:Int,left:Int,top:Int,right:Int,bottom:Int,result:TTileQueryResult)
		Local x:Int=cx*TILE_CHUNK_SIZE,y:Int=cy*TILE_CHUNK_SIZE
		For Local row:Int=Max(top,y) To Min(bottom,y+TILE_CHUNK_SIZE-1)
			For Local column:Int=Max(left,x) To Min(right,x+TILE_CHUNK_SIZE-1)
				Local index:Int=(row-y)*TILE_CHUNK_SIZE+column-x
				If chunk.cells[index] Then result.Add(column,row,chunk.cells[index],chunk.flips[index])
			Next
		Next
	End Method
	Public
	Method AddSprite:TTileSprite(image:TImage,x:Float=0,y:Float=0)
		If Not image Then Throw "Max2D tilemap: sprite image is null"
		Local sprite:TTileSprite=New TTileSprite
		sprite.image=image; sprite.x=x; sprite.y=y
		sprite.anchorX=image.width/2.0; sprite.anchorY=image.height
		sprites=sprites[..sprites.Length+1]; sprites[sprites.Length-1]=sprite
		Return sprite
	End Method
	Method RemoveSprite:Int(sprite:TTileSprite)
		For Local i:Int=0 Until sprites.Length
			If sprites[i]<>sprite Then Continue
			For Local j:Int=i+1 Until sprites.Length
				sprites[j-1]=sprites[j]
			Next
			sprites=sprites[..sprites.Length-1]
			Return True
		Next
		Return False
	End Method
	Method ClearSprites()
		sprites=New TTileSprite[0]
	End Method

	Method Clear()
		_chunks.Clear(); _count=0
	End Method
	Method TileSet:TTileSet()
		Return _tiles
	End Method
	Method CellCount:Int()
		Return _count
	End Method
	Method ChunkCount:Int()
		Return _chunks.Count()
	End Method
End Type

Rem
bbdoc: Layered tilemap sharing a grid and tileset. Rendering uses the current Max2D backend, camera and drawing state.
about: Draw does not advance a clock: pass elapsed milliseconds explicitly. Draw and Pick use matching map position arguments. Layer offsets are map-local.
End Rem
Type TTileMap
	Field parallaxOriginX:Double,parallaxOriginY:Double
	Rem
	bbdoc: Returns the visual layer offset for the active viewport and drawing transform.
	about: Physics/region queries remain in nominal map coordinates. x/y must match the map's Draw call.
	End Rem
	Method LayerDrawOffset(layer:TTileLayer,ox:Double Var,oy:Double Var,x:Float=0,y:Float=0)
		Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
		Local transform:TMax2DDrawTransform=TMax2DDrawTransform.Create(canvas.state,x,y,0,0)
		LayerOffsetForView(layer,transform,canvas.context.view,ox,oy)
	End Method
	Method LayerOffsetForView(layer:TTileLayer,transform:TMax2DDrawTransform,view:TMax2DView,ox:Double Var,oy:Double Var)
		ox=layer.offsetX; oy=layer.offsetY
		If layer.parallaxX=1 And layer.parallaxY=1 Then Return
		If IsNan(layer.parallaxX) Or IsInf(layer.parallaxX) Or IsNan(layer.parallaxY) Or IsInf(layer.parallaxY) Or IsNan(parallaxOriginX) Or IsInf(parallaxOriginX) Or IsNan(parallaxOriginY) Or IsInf(parallaxOriginY) Then Throw "Max2D tilemap: invalid parallax settings"
		Local cx:Float,cy:Float
		If Not transform.VirtualToLocal(view.x+view.w/2.0,view.y+view.h/2.0,cx,cy) Then Return
		ox:+(Double(cx)-parallaxOriginX)*(1-layer.parallaxX)
		oy:+(Double(cy)-parallaxOriginY)*(1-layer.parallaxY)
		If IsNan(ox) Or IsInf(ox) Or IsNan(oy) Or IsInf(oy) Then Throw "Max2D tilemap: parallax offset overflow"
	End Method
	Rem
	bbdoc: Converts a virtual-surface point into layer-local coordinates, including parallax.
	End Rem
	Method VirtualToLayer:Int(layer:TTileLayer,virtualX:Float,virtualY:Float,localX:Float Var,localY:Float Var,x:Float=0,y:Float=0,checkViewport:Int=True)
		localX=0; localY=0
		If Not layer Or layer.TileSet()<>tileset Then Throw "Max2D tilemap: incompatible layer"
		Local canvas:TMax2DGraphics=TMax2DGraphics.Current(),view:TMax2DView=canvas.context.view
		If IsNan(virtualX) Or IsInf(virtualX) Or IsNan(virtualY) Or IsInf(virtualY) Then Return False
		If checkViewport And (virtualX<view.x Or virtualY<view.y Or virtualX>=view.x+view.w Or virtualY>=view.y+view.h) Then Return False
		Local transform:TMax2DDrawTransform=TMax2DDrawTransform.Create(canvas.state,x,y,0,0),ox:Double,oy:Double
		If Not transform.VirtualToLocal(virtualX,virtualY,localX,localY) Then Return False
		LayerOffsetForView(layer,transform,view,ox,oy)
		If Not (layer.drawScale>0) Or IsInf(layer.drawScale) Then Throw "Max2D tilemap: invalid layer drawing scale"
		localX=Float((localX-ox)/layer.drawScale); localY=Float((localY-oy)/layer.drawScale)
		Return True
	End Method
	Method ObjectByID:TTileObject(id:Int)
		For Local layer:TTileLayer=EachIn layers
			Local item:TTileObject=layer.ObjectByID(id)
			If item Then Return item
		Next
	End Method
	Method CellCollision:STileObjectInstance(layer:TTileLayer,column:Int,row:Int,index:Int)
		If Not layer Or layer.TileSet()<>tileset Then Throw "Max2D tilemap: incompatible collision layer"
		Local id:Int=layer.Cell(column,row)
		If Not id Or index<0 Or index>=tileset.tiles[id].collisions.Length Then Throw "Max2D tilemap: collision index out of range"
		Local tile:TTileDefinition=tileset.tiles[id],obj:TTileObject=tile.collisions[index]
		Local t:STileImageTransform=TileImageTransform(tile.drawWidth,tile.drawHeight,layer.CellFlip(column,row))
		Local sx:Float,sy:Float,px:Float,py:Float
		TileImageFit(tile.image.width,tile.image.height,tile.drawWidth,tile.drawHeight,tile.fillMode,sx,sy,px,py)
		Local item:STileObjectInstance=obj.Instance(),cx:Double,cy:Double
		grid.CellOrigin(column,row,cx,cy)
		item.x=cx+layer.offsetX+tile.offsetX+t.tx+t.xx*(px+sx*obj.x)+t.xy*(py+sy*obj.y)
		item.y=cy+layer.offsetY+tile.offsetY+t.ty+t.yx*(px+sx*obj.x)+t.yy*(py+sy*obj.y)
		item.xx=t.xx*sx*obj.xx+t.xy*sy*obj.yx; item.xy=t.xx*sx*obj.xy+t.xy*sy*obj.yy
		item.yx=t.yx*sx*obj.xx+t.yy*sy*obj.yx; item.yy=t.yx*sx*obj.xy+t.yy*sy*obj.yy
		item.layer=layer; item.column=column; item.row=row
		Return item
	End Method
	Rem
	bbdoc: Returns tile collision shapes whose map-local bounds touch the query rectangle.
	about: Results are broad-phase candidates, not physics contacts. Collision geometry is static across animation frames. Output and candidate-cell storage can be reused. Includes invisible layers/shapes.
	End Rem
	Method QueryTileCollisions:TTileObjectQueryResult(layer:TTileLayer,x:Double,y:Double,width:Double,height:Double,result:TTileObjectQueryResult=Null)
		If Not layer Or layer.TileSet()<>tileset Then Throw "Max2D tilemap: incompatible collision layer"
		CheckTileObjectRegion(x,y,width,height)
		If Not result Then result=New TTileObjectQueryResult
		result.Clear()
		Local minX:Double,minY:Double,maxX:Double,maxY:Double,found:Int
		For Local id:Int=1 Until tileset.tiles.Length
			Local tile:TTileDefinition=tileset.tiles[id]
			For Local obj:TTileObject=EachIn tile.collisions
				Local item:STileObjectInstance=obj.Instance(),l:Double,t:Double,r:Double,b:Double
				item.Bounds(l,t,r,b)
				Local sx:Float,sy:Float,px:Float,py:Float
				TileImageFit(tile.image.width,tile.image.height,tile.drawWidth,tile.drawHeight,tile.fillMode,sx,sy,px,py)
				l=px+l*sx; r=px+r*sx; t=py+t*sy; b=py+b*sy
				Local w:Double=tile.drawWidth,h:Double=tile.drawHeight
				Local radius:Double=Sqr(Max(Abs(l-w/2),Abs(r-w/2))^2+Max(Abs(t-h/2),Abs(b-h/2))^2)
				' Covers source-axis flips, diagonal anchoring and all hex rotations.
				minX=Min(minX,tile.offsetX+Min(w/2,h/2)-radius)
				maxX=Max(maxX,tile.offsetX+Max(w/2,h/2)+radius)
				minY=Min(minY,tile.offsetY+Min(h/2,h-w/2)-radius)
				maxY=Max(maxY,tile.offsetY+Max(h/2,h-w/2)+radius)
				found=True
			Next
		Next
		If Not found Then Return result
		Local c0:Double,r0:Double,c1:Double,r1:Double
		grid.OriginBounds(x-layer.offsetX-maxX,y-layer.offsetY-maxY,x+width-layer.offsetX-minX,y+height-layer.offsetY-minY,c0,r0,c1,r1)
		c0=Max(-Double(TILE_COORDINATE_LIMIT),c0); r0=Max(-Double(TILE_COORDINATE_LIMIT),r0)
		c1=Min(Double(TILE_COORDINATE_LIMIT),c1); r1=Min(Double(TILE_COORDINATE_LIMIT),r1)
		If c0>c1 Or r0>r1 Then Return result
		layer.QueryCells(Int(Floor(c0)),Int(Floor(r0)),Int(Ceil(c1)),Int(Ceil(r1)),result.cells)
		For Local i:Int=0 Until result.cells.count
			Local cell:STileQueryCell=result.cells.cells[i]
			For Local j:Int=0 Until tileset.tiles[cell.tile].collisions.Length
				Local item:STileObjectInstance=CellCollision(layer,cell.column,cell.row,j)
				If TileObjectOverlaps(item,x,y,width,height) Then result.Add(item)
			Next
		Next
		Return result
	End Method
	Field properties:TTileProperties=New TTileProperties
	Field grid:TTileGrid
	Field tileset:TTileSet
	Field layers:TTileLayer[]=New TTileLayer[0]
	Field drawnTexts:Int,drawnImages:Int,drawnTiles:Int,drawnSprites:Int,sortedItems:Int,visitedCells:Int,chunkLookups:Int
	Private
	Field _frames:Int[]
	Field _queue:TTileDrawQueue=New TTileDrawQueue
	Field _sorting:Int
	Public
	Function Create:TTileMap(grid:TTileGrid,tileset:TTileSet)
		If Not grid Or Not tileset Then Throw "Max2D tilemap: grid and tileset are required"
		Local map:TTileMap=New TTileMap
		map.grid=grid; map.tileset=tileset
		Return map
	End Function
	Method AddLayer:TTileLayer(name:String="")
		Local layer:TTileLayer=TTileLayer.Create(tileset,name)
		layers=layers[..layers.Length+1]; layers[layers.Length-1]=layer
		Return layer
	End Method
	Rem
	bbdoc: Finds a cell from virtual drawing-surface coordinates using the current camera and transforms.
	about: This is geometric picking, not sprite alpha picking. It does not require a populated or visible cell. Set checkViewport to reject points outside the viewport.
	End Rem
	Method Pick:Int(virtualX:Float,virtualY:Float,column:Int Var,row:Int Var,x:Float=0,y:Float=0,layer:TTileLayer=Null,checkViewport:Int=True)
		column=0; row=0
		If IsNan(virtualX) Or IsInf(virtualX) Or IsNan(virtualY) Or IsInf(virtualY) Then Return False
		If checkViewport Then
			Local vx:Int,vy:Int,vw:Int,vh:Int
			GetViewport(vx,vy,vw,vh)
			If virtualX<vx Or virtualY<vy Or virtualX>=Double(vx)+vw Or virtualY>=Double(vy)+vh Then Return False
		End If
		Local transform:TMax2DDrawTransform=TMax2DDrawTransform.Create(TMax2DGraphics.Current().state,x,y,0,0)
		Local px:Float,py:Float
		If Not transform.VirtualToLocal(virtualX,virtualY,px,py) Then Return False
		If layer Then
			Local ox:Double,oy:Double
			LayerOffsetForView(layer,transform,TMax2DGraphics.Current().context.view,ox,oy)
			If Not (layer.drawScale>0) Or IsInf(layer.drawScale) Then Throw "Max2D tilemap: invalid layer drawing scale"
			px=Float((px-ox)/layer.drawScale); py=Float((py-oy)/layer.drawScale)
		End If
		Return grid.LocalToCell(px,py,column,row)
	End Method
	Method MouseCell:Int(column:Int Var,row:Int Var,x:Float=0,y:Float=0,layer:TTileLayer=Null)
		Local vx:Float,vy:Float
		column=0; row=0
		If Not GetVirtualMouse(vx,vy,True) Then Return False
		Return Pick(vx,vy,column,row,x,y,layer)
	End Method
	Rem
	bbdoc: Finds occupied cell polygons overlapping a map-local rectangle, including layer offsets.
	about: Positive-area overlap is required; touching edges do not count. Ignores camera, visibility, artwork and sprites.
	End Rem
	Method QueryRegion:TTileQueryResult(layer:TTileLayer,x:Double,y:Double,width:Double,height:Double,result:TTileQueryResult=Null)
		If Not layer Or layer.TileSet()<>tileset Then Throw "Max2D tilemap: incompatible query layer"
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(width) Or IsInf(width) Or IsNan(height) Or IsInf(height) Or width<0 Or height<0 Then Throw "Max2D tilemap: invalid query rectangle"
		If IsNan(layer.offsetX) Or IsInf(layer.offsetX) Or IsNan(layer.offsetY) Or IsInf(layer.offsetY) Then Throw "Max2D tilemap: invalid layer offset"
		If Not result Then result=New TTileQueryResult
		result.Clear()
		If width=0 Or height=0 Then Return result
		x:-layer.offsetX; y:-layer.offsetY
		Local right:Double=x+width,bottom:Double=y+height
		If IsInf(right) Or IsInf(bottom) Then Throw "Max2D tilemap: query rectangle overflow"
		Local c0:Double,r0:Double,c1:Double,r1:Double
		grid.OriginBounds(x-grid.TileWidth(),y-grid.TileHeight(),right,bottom,c0,r0,c1,r1)
		c0=Max(-Double(TILE_COORDINATE_LIMIT),c0); r0=Max(-Double(TILE_COORDINATE_LIMIT),r0)
		c1=Min(Double(TILE_COORDINATE_LIMIT),c1); r1=Min(Double(TILE_COORDINATE_LIMIT),r1)
		If c0>c1 Or r0>r1 Then Return result
		layer.QueryCells(Int(c0),Int(r0),Int(c1),Int(r1),result)
		Local count:Int
		For Local i:Int=0 Until result.count
			Local cell:STileQueryCell=result.cells[i]
			If grid.OverlapsRectangle(cell.column,cell.row,x,y,width,height) Then
				result.cells[count]=cell; count:+1
			End If
		Next
		result.count=count
		Return result
	End Method
	Method Draw(x:Float=0,y:Float=0,elapsed:Long=0)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then Throw "Max2D tilemap: invalid map position"
		drawnTexts=0; drawnImages=0; drawnTiles=0; drawnSprites=0; sortedItems=0; visitedCells=0; chunkLookups=0
		If _frames.Length<>tileset.tiles.Length Then _frames=New Int[tileset.tiles.Length]
		Local minX:Float,minY:Float,maxX:Float,maxY:Float
		For Local id:Int=1 Until tileset.tiles.Length
			Local tile:TTileDefinition=tileset.tiles[id]
			_frames[id]=tile.frame
			If tile.animated Then _frames[id]=tile.image.FrameAtTime(elapsed)
			' Conservative envelope for all supported transforms, including oversized artwork.
			Local w:Float=tile.drawWidth,h:Float=tile.drawHeight,radius:Float=Sqr(w*w+h*h)/2
			minX=Min(minX,tile.offsetX+Min(0.0,w/2-radius))
			minY=Min(minY,tile.offsetY+Min(h-w,h/2-radius))
			maxX=Max(maxX,tile.offsetX+Max(h,w/2+radius))
			maxY=Max(maxY,tile.offsetY+h/2+radius)
		Next
		Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
		PushMax2DState()
		Try
			' Apply the caller's object transform to the whole map, including spacing.
			Local state:TMax2DState=canvas.state
			TransformCoordinates(state.ix,state.iy,state.jx,state.jy,x+state.originX,y+state.originY)
			SetOrigin(0,0); SetHandle(0,0); SetTransform()
			Local mapTransform:TMax2DDrawTransform=TMax2DDrawTransform.Create(canvas.state,0,0,0,0)
			For Local layer:TTileLayer=EachIn layers
				If Not layer.visible Or (layer.CellCount()=0 And layer.sprites.Length=0 And layer.objects.Length=0 And Not layer.image) Or layer.opacity=0 Then Continue
				If Not (layer.opacity>=0 And layer.opacity<=1) Or IsNan(layer.offsetX) Or IsInf(layer.offsetX) Or IsNan(layer.offsetY) Or IsInf(layer.offsetY) Then Throw "Max2D tilemap: invalid layer properties"
				If layer.sortMode<>ETileSort.Grid And layer.sortMode<>ETileSort.GroundDepth Then Throw "Max2D tilemap: invalid sorting mode"
				PushMax2DState()
				Try
					Local ox:Double,oy:Double
					LayerOffsetForView(layer,mapTransform,canvas.context.view,ox,oy)
					If Not (layer.drawScale>0) Or IsInf(layer.drawScale) Then Throw "Max2D tilemap: invalid layer drawing scale"
					TransformCoordinates(Float(layer.drawScale),0,0,Float(layer.drawScale),Float(ox),Float(oy))
					If Not (layer.tintRed>=0 And layer.tintRed<=1 And layer.tintGreen>=0 And layer.tintGreen<=1 And layer.tintBlue>=0 And layer.tintBlue<=1 And layer.tintAlpha>=0 And layer.tintAlpha<=1) Then Throw "Max2D tilemap: invalid layer tint"
					SetAlpha(canvas.state.alpha*layer.opacity*layer.tintAlpha)
					canvas.state.red=Int(canvas.state.red*layer.tintRed+0.5)
					canvas.state.green=Int(canvas.state.green*layer.tintGreen+0.5)
					canvas.state.blue=Int(canvas.state.blue*layer.tintBlue+0.5)
					DrawLayerImage(canvas,layer)
					DrawLayer(canvas,layer,minX,minY,maxX,maxY,elapsed)
					DrawObjects(canvas,layer,elapsed)
				Finally
					PopMax2DState()
				End Try
			Next
		Finally
			PopMax2DState()
		End Try
	End Method
	Private
	Field _objectOrder:Int[],_objectScratch:Int[]
	Method DrawObjects(canvas:TMax2DGraphics,layer:TTileLayer,elapsed:Long)
		Local count:Int
		For Local i:Int=0 Until layer.objects.Length
			Local obj:TTileObject=layer.objects[i]
			If Not obj.visible Or obj.opacity=0 Or (Not obj.tile And Not obj.text And (Not obj.artwork Or Not obj.artwork.visible)) Or obj.width=0 Or obj.height=0 Then Continue
			If count=_objectOrder.Length Then
				_objectOrder=_objectOrder[..Max(16,count*2)]; _objectScratch=_objectScratch[.._objectOrder.Length]
			End If
			_objectOrder[count]=i; count:+1
		Next
		If count=0 Then Return
		If layer.objectTopDown Then
			Local run:Int=1
			While run<count
				For Local start:Int=0 Until count Step run*2
					Local mid:Int=Min(start+run,count),finish:Int=Min(start+run*2,count),a:Int=start,b:Int=mid
					For Local pos:Int=start Until finish
						If a<mid And (b>=finish Or layer.objects[_objectOrder[a]].sortY<=layer.objects[_objectOrder[b]].sortY) Then
							_objectScratch[pos]=_objectOrder[a]; a:+1
						Else
							_objectScratch[pos]=_objectOrder[b]; b:+1
						End If
					Next
				Next
				Local swap:Int[]=_objectOrder; _objectOrder=_objectScratch; _objectScratch=swap
				run:*2
			Wend
		End If
		For Local i:Int=0 Until count
			Local obj:TTileObject=layer.objects[_objectOrder[i]]
			If Not obj.visible Or obj.opacity=0 Or (Not obj.tile And Not obj.text And (Not obj.artwork Or Not obj.artwork.visible)) Or obj.width=0 Or obj.height=0 Then Continue
			PushMax2DState()
			Try
				If Not (obj.opacity>=0 And obj.opacity<=1) Then Throw "Max2D tilemap: invalid object opacity"
				SetAlpha(canvas.state.alpha*obj.opacity)
				Local item:STileObjectInstance=obj.Instance()
				TransformCoordinates(Float(item.xx),Float(item.xy),Float(item.yx),Float(item.yy),Float(item.x),Float(item.y))
				If obj.text Then
					obj.text.Draw(canvas,Float(obj.width),Float(obj.height))
					drawnTexts:+1
				Else If obj.artwork And obj.artwork.visible Then
					obj.artwork.Draw(canvas,Float(obj.width),Float(obj.height),elapsed)
					drawnSprites:+1
				Else
					Local tile:TTileDefinition=tileset.tiles[obj.tile]
					TTileDrawQueue.DrawImage(canvas,tile.image,_frames[obj.tile],0,0,ETileFlip.None,Float(obj.width),Float(obj.height),obj.fillMode)
					drawnSprites:+1
				End If
			Finally
				PopMax2DState()
			End Try
		Next
	End Method
	Method DrawLayerImage(canvas:TMax2DGraphics,layer:TTileLayer)
		If Not layer.image Then Return
		Local left:Double,top:Double,right:Double,bottom:Double
		If Not TileLayerViewBounds(canvas,left,top,right,bottom) Then Return
		Local w:Double=layer.image.width,h:Double=layer.image.height
		If w<=0 Or h<=0 Then Return
		Local x0:Double,y0:Double,x1:Double,y1:Double
		If layer.repeatX Then x0=Floor(left/w); x1=Ceil(right/w)-1
		If layer.repeatY Then y0=Floor(top/h); y1=Ceil(bottom/h)-1
		If x1<x0 Or y1<y0 Then Return
		If (x1-x0+1)*(y1-y0+1)>1048576 Or Abs(x0)>2147483646 Or Abs(x1)>2147483646 Or Abs(y0)>2147483646 Or Abs(y1)>2147483646 Then Throw "Max2D tilemap: image repetition exceeds drawing limit"
		For Local row:Int=Int(y0) To Int(y1)
			For Local column:Int=Int(x0) To Int(x1)
				Local px:Double=column*w,py:Double=row*h
				If px+w<=left Or py+h<=top Or px>=right Or py>=bottom Then Continue
				canvas.DrawImageRegion(layer.image,Float(px),Float(py),Float(w),Float(h),0,0,Float(w),Float(h),0,0,0)
				drawnImages:+1
			Next
		Next
	End Method

	Method DrawLayer(canvas:TMax2DGraphics,layer:TTileLayer,minArtX:Float,minArtY:Float,maxArtX:Float,maxArtY:Float,elapsedTime:Long)
		Local left:Double,top:Double,right:Double,bottom:Double
		If Not TileLayerViewBounds(canvas,left,top,right,bottom) Then Return
		_sorting=layer.sortMode=ETileSort.GroundDepth Or grid.Layout()=ETileLayout.Isometric
		Try
			DrawTiles(canvas,layer,minArtX,minArtY,maxArtX,maxArtY,left,top,right,bottom)
			If layer.sortMode=ETileSort.Grid Then
				FlushQueue(canvas)
				_sorting=False
			End If
			For Local sprite:TTileSprite=EachIn layer.sprites
				If Not sprite.visible Then Continue
				sprite.Validate()
				Local px:Float=sprite.x-sprite.anchorX,py:Float=sprite.y-sprite.anchorY
				Local artLeft:Float,artTop:Float,artRight:Float,artBottom:Float
				TileImageBounds(sprite.image.width,sprite.image.height,sprite.flip,artLeft,artTop,artRight,artBottom)
				If px+artRight<left Or py+artBottom<top Or px+artLeft>right Or py+artTop>bottom Then Continue
				Local frame:Int=sprite.frame
				If sprite.animated Then frame=sprite.image.FrameAtTime(elapsedTime)
				Submit(canvas,sprite.image,frame,px,py,sprite.flip,sprite.y+Double(sprite.depthOffset),sprite.x,sprite.sortOrder)
				drawnSprites:+1
			Next
			FlushQueue(canvas)
		Finally
			_queue.Clear()
		End Try
	End Method
	Method DrawTiles(canvas:TMax2DGraphics,layer:TTileLayer,minArtX:Float,minArtY:Float,maxArtX:Float,maxArtY:Float,left:Double,top:Double,right:Double,bottom:Double)
		' Conservative bounds include oversized artwork and staggered origins.
		Local boundLeft:Int,boundTop:Int,boundRight:Int,boundBottom:Int
		If Not layer.Bounds(boundLeft,boundTop,boundRight,boundBottom) Then Return
		Local firstColumn:Double,lastColumn:Double,firstRow:Double,lastRow:Double
		grid.OriginBounds(left-maxArtX,top-maxArtY,right-minArtX,bottom-minArtY,firstColumn,firstRow,lastColumn,lastRow)
		firstColumn=Max(Double(boundLeft),firstColumn); lastColumn=Min(Double(boundRight),lastColumn)
		firstRow=Max(Double(boundTop),firstRow); lastRow=Min(Double(boundBottom),lastRow)
		If Not (firstColumn<=lastColumn And firstRow<=lastRow) Then Return
		Local c0:Int=Int(firstColumn),c1:Int=Int(lastColumn),r0:Int=Int(firstRow),r1:Int=Int(lastRow)
		Local columnStep:Int=1,rowStep:Int=1
		If layer.sortMode=ETileSort.Grid And grid.Layout()=ETileLayout.Rectangular Then
			Select layer.renderOrder
				Case ETileRenderOrder.RightDown
				Case ETileRenderOrder.RightUp; rowStep=-1
				Case ETileRenderOrder.LeftDown; columnStep=-1
				Case ETileRenderOrder.LeftUp; columnStep=-1; rowStep=-1
				Default; Throw "Max2D tilemap: invalid render order"
			End Select
		End If
		Local rowStart:Int=r0
		If rowStep<0 Then rowStart=r1
		For Local rowIndex:Int=0 To r1-r0
			Local row:Int=rowStart+rowIndex*rowStep
			Local passes:Int=1
			If grid.ColumnStaggered() Then passes=2
			For Local pass:Int=0 Until passes
				Local cx:Int=TTileLayer.ChunkCoordinate(c0),last:Int=TTileLayer.ChunkCoordinate(c1)
				Local cy:Int=TTileLayer.ChunkCoordinate(row)
				If columnStep<0 Then cx=TTileLayer.ChunkCoordinate(c1); last=TTileLayer.ChunkCoordinate(c0)
				For Local chunkIndex:Int=0 To Abs(last-cx)
					Local chunkX:Int=cx+chunkIndex*columnStep
					chunkLookups:+1
					Local chunk:TTileChunk=layer.Chunk(chunkX,cy)
					If Not chunk Then Continue
					Local start:Int=Max(c0,chunkX*TILE_CHUNK_SIZE),finish:Int=Min(c1,(chunkX+1)*TILE_CHUNK_SIZE-1)
					If columnStep<0 Then
						Local swap:Int=start; start=finish; finish=swap
					End If
					For Local columnIndex:Int=0 To Abs(finish-start)
						Local column:Int=start+columnIndex*columnStep
						If passes=2 And grid.Shifted(column)<>pass Then Continue
						visitedCells:+1
						Local index:Int=(row-cy*TILE_CHUNK_SIZE)*TILE_CHUNK_SIZE+column-chunkX*TILE_CHUNK_SIZE
						Local id:Int=chunk.cells[index]
						If id=0 Then Continue
						Local tile:TTileDefinition=tileset.tiles[id]
						Local px:Double,py:Double
						grid.CellOrigin(column,row,px,py)
						Local depth:Double=py+grid.TileHeight(),sortX:Double=px+grid.TileWidth()/2
						Local order:Int
						If layer.sortMode=ETileSort.GroundDepth Then depth:+tile.depthOffset; order=tile.sortOrder
						px:+tile.offsetX; py:+tile.offsetY
						Local artLeft:Float,artTop:Float,artRight:Float,artBottom:Float
						TileImageBounds(tile.drawWidth,tile.drawHeight,chunk.flips[index],artLeft,artTop,artRight,artBottom)
						If px+artRight<left Or py+artBottom<top Or px+artLeft>right Or py+artTop>bottom Then Continue
						Submit(canvas,tile.image,_frames[id],Float(px),Float(py),chunk.flips[index],depth,sortX,order,tile.drawWidth,tile.drawHeight,tile.fillMode)
						drawnTiles:+1
					Next
				Next
			Next
		Next
	End Method
	Method Submit(canvas:TMax2DGraphics,image:TImage,frame:Int,x:Float,y:Float,flip:ETileFlip,depth:Double,sortX:Double,order:Int,width:Float=0,height:Float=0,fillMode:ETileFillMode=ETileFillMode.Stretch)
		If _sorting Then
			_queue.Add(image,frame,x,y,flip,depth,sortX,order,width,height,fillMode)
		Else
			TTileDrawQueue.DrawImage(canvas,image,frame,x,y,flip,width,height,fillMode)
		End If
	End Method
	Method FlushQueue(canvas:TMax2DGraphics)
		sortedItems:+_queue.count
		_queue.Sort()
		For Local i:Int=0 Until _queue.count
			Local item:STileDrawItem=_queue.items[i]
			TTileDrawQueue.DrawImage(canvas,item.image,item.frame,item.x,item.y,item.flip,item.width,item.height,item.fillMode)
		Next
		_queue.Clear()
	End Method

End Type

Function TileLayerViewBounds:Int(canvas:TMax2DGraphics,left:Double Var,top:Double Var,right:Double Var,bottom:Double Var)
	Local view:TMax2DView=canvas.context.view
	If view.w<=0 Or view.h<=0 Then Return False
	Local transform:TMax2DDrawTransform=TMax2DDrawTransform.Create(canvas.state,0,0,0,0)
	For Local i:Int=0 Until 4
		Local vx:Float=view.x,vy:Float=view.y,px:Float,py:Float
		If i=1 Or i=2 Then vx:+view.w
		If i>=2 Then vy:+view.h
		If Not transform.VirtualToLocal(vx,vy,px,py) Then Return False
		If i=0 Then
			left=px; right=px; top=py; bottom=py
		Else
			left=Min(left,Double(px)); right=Max(right,Double(px))
			top=Min(top,Double(py)); bottom=Max(bottom,Double(py))
		End If
	Next
	Return True
End Function
