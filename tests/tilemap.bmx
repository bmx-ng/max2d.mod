SuperStrict
Framework Max2D.TileMap
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Try
	Local grids:TTileGrid[]=[TTileGrid.Rectangular(37,29), ..
		TTileGrid.Hexagonal(64,72,ETileLayout.PointyHex,ETileStagger.Odd), ..
		TTileGrid.Hexagonal(64,72,ETileLayout.PointyHex,ETileStagger.Even,17), ..
		TTileGrid.Hexagonal(72,64,ETileLayout.FlatHex,ETileStagger.Odd), ..
		TTileGrid.Hexagonal(72,64,ETileLayout.FlatHex,ETileStagger.Even,17), ..
		TTileGrid.Isometric(64,32), ..
		TTileGrid.StaggeredIsometric(64,32,ETileAxis.X,ETileStagger.Odd), ..
		TTileGrid.StaggeredIsometric(64,32,ETileAxis.X,ETileStagger.Even), ..
		TTileGrid.StaggeredIsometric(64,32,ETileAxis.Y,ETileStagger.Odd), ..
		TTileGrid.StaggeredIsometric(64,32,ETileAxis.Y,ETileStagger.Even)]
	For Local grid:TTileGrid=EachIn grids
		For Local row:Int=-8 To 8
			For Local column:Int=-8 To 8
				Local x:Double,y:Double,c:Int,r:Int
				grid.CellOrigin(column,row,x,y)
				Local c0:Double,r0:Double,c1:Double,r1:Double
				grid.OriginBounds(x-1,y-1,x+1,y+1,c0,r0,c1,r1)
				Check(column>=c0 And column<=c1 And row>=r0 And row<=r1,"Origin culling bounds")
				grid.CellCenter(column,row,x,y)
				Check(grid.LocalToCell(x,y,c,r) And c=column And r=row,"Cell centre round trip")
				For Local corner:Int=0 Until grid.CornerCount()
					Local cx:Double,cy:Double
					grid.CellCorner(column,row,corner,cx,cy)
					' Interior points near corners must belong to this cell.
					Check(grid.LocalToCell(x+(cx-x)*0.99,y+(cy-y)*0.99,c,r) And c=column And r=row,"Corner picking")
				Next
				For Local direction:Int=0 Until grid.NeighbourCount()
					grid.Neighbour(column,row,direction,c,r)
					Check(grid.Distance(column,row,c,r)=1,"Neighbour distance")
					Local backC:Int,backR:Int
					grid.Neighbour(c,r,(direction+grid.NeighbourCount()/2) Mod grid.NeighbourCount(),backC,backR)
					Check(backC=column And backR=row,"Opposite neighbour")
				Next
				If grid.IsHex() Then
					Local q:Int,ar:Int,s:Int
					grid.ToCube(column,row,q,ar,s)
					Check(q+ar+s=0,"Cube sum")
					grid.FromCube(q,ar,s,c,r)
					Check(c=column And r=row,"Offset/cube round trip")
				End If
			Next
		Next
		For Local y:Int=-180 To 180 Step 3
			For Local x:Int=-180 To 180 Step 3
				Local c:Int,r:Int
				Check(grid.LocalToCell(x+0.25,y+0.25,c,r),"No gaps in tiling")
				Check(grid.Contains(c,r,x+0.25,y+0.25),"Picked cell contains point")
			Next
		Next
		Local cells:STileCell[]=grid.Range(-2,-3,3)
		Local expected:Int=37
		If Not grid.IsHex() Then expected=25
		Check(cells.Length=expected,"Range cell count")
		For Local i:Int=0 Until cells.Length
			Check(grid.Distance(-2,-3,cells[i].column,cells[i].row)<=3,"Range distance")
			For Local j:Int=0 Until i
				Check(cells[i].column<>cells[j].column Or cells[i].row<>cells[j].row,"Unique range cells")
			Next
		Next
		cells=grid.Range(-2,-3,3,True)
		Check(cells.Length=grid.NeighbourCount()*3,"Ring cell count")
		For Local cell:STileCell=EachIn cells
			Check(grid.Distance(-2,-3,cell.column,cell.row)=3,"Ring distance")
		Next
	Next
	Local queue:TTileDrawQueue=New TTileDrawQueue
	For Local i:Int=0 Until 127
		queue.Add(Null,0,0,0,ETileFlip.None,(i*37) Mod 9,(i*13) Mod 5,i Mod 3)
	Next
	queue.Sort()
	For Local i:Int=1 Until queue.count
		Check(Not TTileDrawQueue.After(queue.items[i-1],queue.items[i]),"Depth ordering including stable ties")
	Next
	queue.Clear()
	For Local i:Int=0 Until 40
		queue.Add(Null,0,0,0,ETileFlip.None,0,0,0)
	Next
	queue.Sort()
	For Local i:Int=0 Until queue.count
		Check(queue.items[i].sequence=i,"Equal depth retains insertion order")
	Next
	Local pixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
	pixels.ClearPixels($ffffffff)
	Local tiles:TTileSet=New TTileSet
	Local id:Int=tiles.Add(TImage.FromPixmap(pixels))
	Local map:TTileMap=TTileMap.Create(grids[0],tiles)
	Local layer:TTileLayer=map.AddLayer("ground")
	For Local c:Int=-33 To 33
		layer.SetCell(c,-c,id,ETileFlip.Horizontal)
	Next
	Check(layer.CellCount()=67,"Sparse cell count")
	For Local c:Int=-33 To 33
		Check(layer.Cell(c,-c)=id And layer.CellFlip(c,-c)=ETileFlip.Horizontal,"Negative chunk addressing")
		Check(layer.Cell(c,-c+1)=0,"Empty neighbour")
	Next
	For Local c:Int=-33 To 33
		layer.SetCell(c,-c,0)
	Next
	Check(layer.CellCount()=0 And layer.ChunkCount()=0,"Empty chunks reclaimed")
	layer.SetCell(-1000000,1000000,id)
	Check(layer.Cell(-1000000,1000000)=id And layer.ChunkCount()=1,"Distant sparse cell")
	layer.Clear()
	Check(layer.CellCount()=0 And layer.ChunkCount()=0,"Clear layer")
	Local props:TTileProperties=tiles.Properties(id)
	props.SetBool("solid",True)
	props.SetLong("cost",5000000000:Long)
	props.SetDouble("friction",0.75)
	props.SetString("terrain","stone")
	Check(props.GetLong("cost")=5000000000:Long And props.GetDouble("friction")=0.75,"Typed numeric properties")
	Check(props.GetString("missing","default")="default" And Not props.Contains("missing"),"Missing property fallback")
	Check(Not props.Contains("Solid"),"Property names are case sensitive")
	layer.SetCell(-32,-33,id)
	Check(layer.CellProperties(-32,-33)=Null,"No override allocation on read")
	Check(layer.Property(-32,-33,"solid").AsBool(),"Shared property inheritance")
	Local overrides:TTileProperties=layer.CellProperties(-32,-33,True)
	overrides.SetBool("solid",False)
	Check(Not layer.Property(-32,-33,"solid").AsBool() And props.GetBool("solid"),"False overrides shared True without changing definition")
	overrides.Remove("solid")
	Check(layer.Property(-32,-33,"solid").AsBool(),"Removing override restores inheritance")
	overrides.SetString("name","door")
	layer.SetCell(-32,-33,id,ETileFlip.Vertical)
	Check(layer.Property(-32,-33,"name").AsString()="door","Same tile retains overrides")
	Local other:Int=tiles.Add(TImage.FromPixmap(pixels))
	layer.SetCell(-32,-33,other)
	Check(layer.CellProperties(-32,-33)=Null,"Replacing tile clears overrides")
	layer.CellProperties(-32,-33,True).SetBool("open",True)
	layer.SetCell(-32,-33,0)
	Check(layer.Property(-32,-33,"open")=Null And layer.ChunkCount()=0,"Erasing tile clears overrides")
	Local mismatch:Int
	Try
		props.GetString("solid")
	Catch error:Object
		mismatch=True
	End Try
	Check(mismatch,"Wrong property type rejected")
	Local result:TTileQueryResult=New TTileQueryResult
	For Local grid:TTileGrid=EachIn grids
		map=TTileMap.Create(grid,tiles); layer=map.AddLayer()
		layer.offsetX=17.25; layer.offsetY=-29.5; layer.visible=False
		For Local row:Int=-3 To 3
			For Local column:Int=-3 To 3
				layer.SetCell(column,row,id,ETileFlip.Horizontal)
			Next
		Next
		Check(layer.QueryCells(-1,-2,1,2,result)=result And result.count=15,"Inclusive cell range and reusable result")
		For Local i:Int=0 Until result.count
			Check(result.cells[i].tile=id And result.cells[i].flip=ETileFlip.Horizontal,"Query tile and flip snapshot")
		Next
		For Local row:Int=-2 To 2
			For Local column:Int=-2 To 2
				Local x:Double,y:Double
				grid.CellCenter(column,row,x,y)
				map.QueryRegion(layer,x+layer.offsetX-0.01,y+layer.offsetY-0.01,0.02,0.02,result)
				Check(result.count=1 And result.cells[0].column=column And result.cells[0].row=row,"Polygon query at cell centre across layouts and offsets")
			Next
		Next
		map.QueryRegion(layer,-10000,-10000,20000,20000,result)
		Check(result.count=49,"Large region includes all cells")
		map.QueryRegion(layer,0,0,0,10,result)
		Check(result.count=0,"Zero area clears reused result")
		map.QueryRegion(layer,1.0e20,1.0e20,100,100,result)
		Check(result.count=0,"Distant region clips before integer conversion")
		Local edgeX:Double,edgeY:Double
		grid.CellOrigin(0,0,edgeX,edgeY)
		Check(Not grid.OverlapsRectangle(0,0,edgeX+grid.TileWidth(),edgeY,1,1),"Touching cell bounding edge excluded")
		If grid.Layout()<>ETileLayout.Rectangular Then
			Local ox:Double,oy:Double
			grid.CellOrigin(0,0,ox,oy)
			Check(Not grid.OverlapsRectangle(0,0,ox,oy,0.01,0.01),"Empty polygon bounding-box corner excluded")
		End If
	Next
	layer.Clear()
	layer.SetCell(-1000000,-1000000,id); layer.SetCell(1000000,1000000,id)
	layer.QueryCells(-1000000,-1000000,1000000,1000000,result)
	Check(result.count=2,"Huge sparse query visits occupied chunks")
	layer.QueryCells(-1000000,-1000000,-999999,-999999,result)
	Check(result.count=1 And result.cells[0].column=-1000000,"Small sparse query")
	layer.QueryCells(1,1,0,0,result)
	Check(result.count=0,"Inverted cell bounds return empty")
	Local diamond:TTileGrid=TTileGrid.Isometric(64,32)
	Check(Not diamond.OverlapsRectangle(0,0,0,0,16,8),"Diagonal corner touch excluded")
	Check(diamond.OverlapsRectangle(0,0,0,0,16.01,8),"Small positive diagonal overlap included")
	Check(diamond.OverlapsRectangle(0,0,-1,15,66,2),"Crossing strip overlaps without containing polygon vertices")
	Local invalidRegion:Int
	Try
		map.QueryRegion(layer,0,0,-1,1,result)
	Catch error:Object
		invalidRegion=True
	End Try
	Check(invalidRegion,"Negative rectangle size rejected")
	Local rejected:Int
	Try
		TTileGrid.Hexagonal(32,32,ETileLayout.FlatHex,ETileStagger.Odd,32)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Degenerate hex rejected")
	Print "Max2D tilemap geometry and storage tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
