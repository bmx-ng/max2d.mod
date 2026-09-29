
Rem
bbdoc: Immutable grid geometry. Cell coordinates use integer columns and rows.
about: Cell (0,0) has its bounding-box origin at (0,0), except for the configured stagger. No graphics context is needed.
End Rem
Type TTileGrid
	Private
	Field _layout:ETileLayout
	Field _axis:ETileAxis=ETileAxis.Y
	Field _stagger:ETileStagger
	Field _width:Double,_height:Double,_side:Double
	Public

	Rem
	bbdoc: Creates a rectangular grid with the given cell width and height in local pixels.
	param: Cell bounding-box width in map units.
	param: Cell bounding-box height in map units.
	End Rem
	Function Rectangular:TTileGrid(width:Double,height:Double)
		Return Create(ETileLayout.Rectangular,width,height,ETileStagger.Odd,0)
	End Function

	Rem
	bbdoc: Creates a pointy-top or flat-top hex grid. Stagger selects which rows or columns are offset; sideLength controls the hex proportions.
	param: Cell bounding-box width in map units.
	param: Cell bounding-box height in map units.
	param: ETileLayout.PointyHex or ETileLayout.FlatHex.
	param: Parity of the rows or columns receiving the stagger offset.
	param: Hexagon side length along the stagger axis; -1 chooses the default proportion.
	End Rem
	Function Hexagonal:TTileGrid(width:Double,height:Double,layout:ETileLayout=ETileLayout.PointyHex,stagger:ETileStagger=ETileStagger.Odd,sideLength:Double=-1)
		If layout<>ETileLayout.PointyHex And layout<>ETileLayout.FlatHex Then Throw "Max2D tilemap: expected a hex layout"
		If sideLength=-1 Then
			If layout=ETileLayout.PointyHex Then sideLength=height/2 Else sideLength=width/2
		End If
		Return Create(layout,width,height,stagger,sideLength)
	End Function

	Rem
	bbdoc: Creates a diamond isometric grid with the supplied cell dimensions.
	param: Cell bounding-box width in map units.
	param: Cell bounding-box height in map units.
	End Rem
	Function Isometric:TTileGrid(width:Double,height:Double)
		Return Create(ETileLayout.Isometric,width,height,ETileStagger.Odd,0)
	End Function

	Rem
	bbdoc: Creates an offset diamond grid with the supplied stagger axis and parity.
	param: Cell bounding-box width in map units.
	param: Cell bounding-box height in map units.
	param: Axis whose rows or columns are staggered.
	param: Parity of the rows or columns receiving the stagger offset.
	End Rem
	Function StaggeredIsometric:TTileGrid(width:Double,height:Double,axis:ETileAxis=ETileAxis.Y,stagger:ETileStagger=ETileStagger.Odd)
		If axis<>ETileAxis.X And axis<>ETileAxis.Y Then Throw "Max2D tilemap: invalid stagger axis"
		Local grid:TTileGrid=Create(ETileLayout.StaggeredIsometric,width,height,stagger,0)
		grid._axis=axis
		Return grid
	End Function

	Private
	Function Create:TTileGrid(layout:ETileLayout,width:Double,height:Double,stagger:ETileStagger,side:Double)
		If Not (width>0 And width<=65536 And height>0 And height<=65536) Then Throw "Max2D tilemap: invalid tile dimensions"
		If stagger<>ETileStagger.Odd And stagger<>ETileStagger.Even Then Throw "Max2D tilemap: invalid stagger"
		If layout=ETileLayout.PointyHex Or layout=ETileLayout.FlatHex Then
			Local extent:Double=width
			If layout=ETileLayout.PointyHex Then extent=height
			If Not (side>0 And side<extent) Then Throw "Max2D tilemap: hex side must be between zero and its axis dimension"
		End If
		Local grid:TTileGrid=New TTileGrid
		grid._layout=layout; grid._stagger=stagger
		grid._width=width; grid._height=height; grid._side=side
		Return grid
	End Function

	Public

	Rem
	bbdoc: Returns the cell layout used by this grid.
	End Rem
	Method Layout:ETileLayout()
		Return _layout
	End Method

	Rem
	bbdoc: Reports whether this grid uses hexagonal cells.
	End Rem
	Method IsHex:Int()
		Return _layout=ETileLayout.PointyHex Or _layout=ETileLayout.FlatHex
	End Method

	Rem
	bbdoc: Reports whether this grid uses ordinary or staggered isometric diamonds.
	End Rem
	Method IsDiamond:Int()
		Return _layout=ETileLayout.Isometric Or _layout=ETileLayout.StaggeredIsometric
	End Method

	Rem
	bbdoc: Returns the axis whose rows or columns are staggered.
	End Rem
	Method StaggerAxis:ETileAxis()
		If _layout=ETileLayout.FlatHex Then Return ETileAxis.X
		Return _axis
	End Method

	Rem
	bbdoc: Reports whether columns carry the half-cell stagger.
	End Rem
	Method ColumnStaggered:Int()
		Return _layout=ETileLayout.FlatHex Or (_layout=ETileLayout.StaggeredIsometric And _axis=ETileAxis.X)
	End Method

	Rem
	bbdoc: Reports whether rows carry the half-cell stagger.
	End Rem
	Method RowStaggered:Int()
		Return _layout=ETileLayout.PointyHex Or (_layout=ETileLayout.StaggeredIsometric And _axis=ETileAxis.Y)
	End Method

	Rem
	bbdoc: Returns whether odd or even rows or columns are shifted.
	End Rem
	Method Stagger:ETileStagger()
		Return _stagger
	End Method

	Rem
	bbdoc: Returns the cell bounding-box width in map units.
	End Rem
	Method TileWidth:Double()
		Return _width
	End Method

	Rem
	bbdoc: Returns the cell bounding-box height in map units.
	End Rem
	Method TileHeight:Double()
		Return _height
	End Method

	Rem
	bbdoc: Returns the parallel side length of a hexagonal cell.
	End Rem
	Method SideLength:Double()
		Return _side
	End Method

	Rem
	bbdoc: Returns the horizontal spacing between neighbouring cell origins.
	End Rem
	Method StepX:Double()
		If ColumnStaggered() Or _layout=ETileLayout.Isometric Then Return (_width+_side)/2
		Return _width
	End Method

	Rem
	bbdoc: Returns the vertical spacing between neighbouring cell origins.
	End Rem
	Method StepY:Double()
		If RowStaggered() Or _layout=ETileLayout.Isometric Then Return (_height+_side)/2
		Return _height
	End Method

	Rem
	bbdoc: Reports whether a row or column index receives the configured stagger offset.
	param: Zero-based index.
	End Rem
	Method Shifted:Int(index:Int)
		Return (index & 1)=Int(_stagger)
	End Method

	Rem
	bbdoc: Rejects cell coordinates outside the supported safe range.
	param: Integer grid column.
	param: Integer grid row.
	End Rem
	Function CheckCell(column:Int,row:Int)
		If column < -TILE_COORDINATE_LIMIT Or column>TILE_COORDINATE_LIMIT Or row < -TILE_COORDINATE_LIMIT Or row>TILE_COORDINATE_LIMIT Then Throw "Max2D tilemap: cell coordinate out of range"
	End Function

	Rem
	bbdoc: Tests positive-area overlap between a cell polygon and a local rectangle. Touching edges are excluded.
	param: Integer grid column.
	param: Integer grid row.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
	Method OverlapsRectangle:Int(column:Int,row:Int,x:Double,y:Double,width:Double,height:Double)
		CheckCell(column,row)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(width) Or IsInf(width) Or IsNan(height) Or IsInf(height) Or width<0 Or height<0 Then Throw "Max2D tilemap: invalid query rectangle"
		If width=0 Or height=0 Then Return False
		Local ox:Double,oy:Double
		CellOrigin(column,row,ox,oy)
		' Work relative to the cell origin to retain precision for distant cells.
		x:-ox; y:-oy
		If x>=_width Or y>=_height Or x+width<=0 Or y+height<=0 Then Return False
		For Local i:Int=0 Until CornerCount()
			Local ax:Double,ay:Double,bx:Double,by:Double
			CellCorner(column,row,i,ax,ay); CellCorner(column,row,(i+1) Mod CornerCount(),bx,by)
			ax:-ox; ay:-oy; bx:-ox; by:-oy
			' Clockwise polygon: rectangle must extend inside every edge half-plane.
			Local nx:Double=ay-by,ny:Double=bx-ax
			Local px:Double=x,py:Double=y
			If nx>0 Then px:+width
			If ny>0 Then py:+height
			If nx*(px-ax)+ny*(py-ay)<=0 Then Return False
		Next
		Return True
	End Method

	Rem
	bbdoc: Writes the top-left of a cell bounding box in grid-local pixels.
	param: Integer grid column.
	param: Integer grid row.
	param: Receives horizontal coordinate.
	param: Receives vertical coordinate.
	End Rem
	Method CellOrigin(column:Int,row:Int,x:Double Var,y:Double Var)
		CheckCell(column,row)
		If _layout=ETileLayout.Isometric Then
			x=(Double(column)-row)*_width/2; y=(Double(column)+row)*_height/2
			Return
		End If
		x=column*StepX(); y=row*StepY()
		If RowStaggered() And Shifted(row) Then x:+_width/2
		If ColumnStaggered() And Shifted(column) Then y:+_height/2
	End Method

	Rem
	bbdoc: Writes a cell centre in grid-local pixels.
	param: Integer grid column.
	param: Integer grid row.
	param: Receives horizontal coordinate.
	param: Receives vertical coordinate.
	End Rem
	Method CellCenter(column:Int,row:Int,x:Double Var,y:Double Var)
		CellOrigin(column,row,x,y)
		x:+_width/2; y:+_height/2
	End Method

	Rem
	bbdoc: Returns the number of polygon corners in a cell.
	End Rem
	Method CornerCount:Int()
		If Not IsHex() Then Return 4
		Return 6
	End Method

	Rem
	bbdoc: Writes a cell corner without allocating. Corners follow clockwise order in screen coordinates.
	param: Integer grid column.
	param: Integer grid row.
	param: Zero-based cell polygon corner index.
	param: Receives horizontal coordinate.
	param: Receives vertical coordinate.
	End Rem
	Method CellCorner(column:Int,row:Int,corner:Int,x:Double Var,y:Double Var)
		If corner<0 Or corner>=CornerCount() Then Throw "Max2D tilemap: corner index out of range"
		CellOrigin(column,row,x,y)
		If _layout=ETileLayout.Rectangular Then
			If corner=1 Or corner=2 Then x:+_width
			If corner>=2 Then y:+_height
		Else If IsDiamond() Then
			Select corner
				Case 0; x:+_width/2
				Case 1; x:+_width; y:+_height/2
				Case 2; x:+_width/2; y:+_height
				Case 3; y:+_height/2
			End Select
		Else If _layout=ETileLayout.PointyHex Then
			Select corner
				Case 0; x:+_width/2
				Case 1; x:+_width; y:+(_height-_side)/2
				Case 2; x:+_width; y:+(_height+_side)/2
				Case 3; x:+_width/2; y:+_height
				Case 4; y:+(_height+_side)/2
				Case 5; y:+(_height-_side)/2
			End Select
		Else
			Select corner
				Case 0; x:+(_width-_side)/2
				Case 1; x:+(_width+_side)/2
				Case 2; x:+_width; y:+_height/2
				Case 3; x:+(_width+_side)/2; y:+_height
				Case 4; x:+(_width-_side)/2; y:+_height
				Case 5; y:+_height/2
			End Select
		End If
	End Method

	Rem
	bbdoc: Tests whether a map-space point lies inside a particular cell polygon.
	param: Integer grid column.
	param: Integer grid row.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Contains:Int(column:Int,row:Int,x:Double,y:Double)
		Local ox:Double,oy:Double
		CellOrigin(column,row,ox,oy)
		x:-ox; y:-oy
		If x<0 Or y<0 Or x>_width Or y>_height Then Return False
		If _layout=ETileLayout.Rectangular Then Return x<_width And y<_height
		If IsDiamond() Then Return Abs(x-_width/2)/(_width/2)+Abs(y-_height/2)/(_height/2)<=1
		If _layout=ETileLayout.PointyHex Then
			Local cap:Double=(_height-_side)/2
			Return Abs(x-_width/2)<=_width/2*Min(1.0,Min(y,_height-y)/cap)
		Else
			Local cap:Double=(_width-_side)/2
			Return Abs(y-_height/2)<=_height/2*Min(1.0,Min(x,_width-x)/cap)
		End If
	End Method

	Rem
	bbdoc: Finds the geometric cell, whether or not it is populated. Returns False outside the supported coordinate range.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Receives integer grid column.
	param: Receives integer grid row.
	about: Shared polygon edges choose the lowest row, then column. Coordinates are map-local; use TTileMap.Pick for current drawing and camera transforms.
	End Rem
	Method LocalToCell:Int(x:Double,y:Double,column:Int Var,row:Int Var)
		column=0; row=0
		Local cx:Double=Floor(x/StepX()),cy:Double=Floor(y/StepY())
		If _layout=ETileLayout.Isometric Then
			cx=Floor(x/_width+y/_height-1); cy=Floor(y/_height-x/_width)
		End If
		If Not (cx>=-TILE_COORDINATE_LIMIT-2 And cx<=TILE_COORDINATE_LIMIT+2 And cy>=-TILE_COORDINATE_LIMIT-2 And cy<=TILE_COORDINATE_LIMIT+2) Then Return False
		If _layout=ETileLayout.Rectangular Then
			If Abs(cx)>TILE_COORDINATE_LIMIT Or Abs(cy)>TILE_COORDINATE_LIMIT Then Return False
			column=Int(cx); row=Int(cy); Return True
		End If
		For Local r:Int=Max(-TILE_COORDINATE_LIMIT,Int(cy)-1) To Min(TILE_COORDINATE_LIMIT,Int(cy)+1)
			For Local c:Int=Max(-TILE_COORDINATE_LIMIT,Int(cx)-1) To Min(TILE_COORDINATE_LIMIT,Int(cx)+1)
				If Contains(c,r,x,y) Then column=c; row=r; Return True
			Next
		Next
		Return False
	End Method

	Rem
	bbdoc: Converts offset column/row coordinates to axial q/r coordinates. Hex grids only.
	param: Integer grid column.
	param: Integer grid row.
	param: Receives axial or cube q coordinate.
	param: Receives axial or cube r coordinate.
	End Rem
	Method ToAxial(column:Int,row:Int,q:Int Var,r:Int Var)
		CheckCell(column,row)
		If Not IsHex() Then Throw "Max2D tilemap: axial coordinates require hexagons"
		Local sign:Int=-1
		If _stagger=ETileStagger.Even Then sign=1
		q=column; r=row
		If _layout=ETileLayout.PointyHex Then q:-(row+sign*(row & 1))/2 Else r:-(column+sign*(column & 1))/2
	End Method

	Rem
	bbdoc: Converts axial q/r coordinates to offset column/row coordinates. Hex grids only.
	param: Axial or cube q coordinate.
	param: Axial or cube r coordinate.
	param: Receives integer grid column.
	param: Receives integer grid row.
	End Rem
	Method FromAxial(q:Int,r:Int,column:Int Var,row:Int Var)
		If Not IsHex() Then Throw "Max2D tilemap: axial coordinates require hexagons"
		Local sign:Int=-1
		If _stagger=ETileStagger.Even Then sign=1
		Local c:Long=q,rr:Long=r
		If _layout=ETileLayout.PointyHex Then c:+(Long(r)+sign*(r & 1))/2 Else rr:+(Long(q)+sign*(q & 1))/2
		If Abs(c)>TILE_COORDINATE_LIMIT Or Abs(rr)>TILE_COORDINATE_LIMIT Then Throw "Max2D tilemap: axial coordinate out of range"
		column=Int(c); row=Int(rr)
	End Method

	Rem
	bbdoc: Converts a hex cell to cube coordinates satisfying q+r+s=0.
	param: Integer grid column.
	param: Integer grid row.
	param: Receives axial or cube q coordinate.
	param: Receives axial or cube r coordinate.
	param: Receives cube s coordinate, with q+r+s equal to zero.
	End Rem
	Method ToCube(column:Int,row:Int,q:Int Var,r:Int Var,s:Int Var)
		ToAxial(column,row,q,r)
		s=-q-r
	End Method

	Rem
	bbdoc: Converts valid cube coordinates to a hex cell; q+r+s must be zero.
	param: Axial or cube q coordinate.
	param: Axial or cube r coordinate.
	param: Cube s coordinate, with q+r+s equal to zero.
	param: Receives integer grid column.
	param: Receives integer grid row.
	End Rem
	Method FromCube(q:Int,r:Int,s:Int,column:Int Var,row:Int Var)
		If Long(q)+r+s<>0 Then Throw "Max2D tilemap: cube coordinates must sum to zero"
		FromAxial(q,r,column,row)
	End Method

	Rem
	bbdoc: Returns the number of edge neighbours: six for hex grids, four otherwise.
	End Rem
	Method NeighbourCount:Int()
		If Not IsHex() Then Return 4
		Return 6
	End Method

	Rem
	bbdoc: Writes the adjacent cell in direction 0 until NeighbourCount(). The result may be empty or outside your game board.
	param: Integer grid column.
	param: Integer grid row.
	param: Zero-based neighbour direction as described by the grid layout.
	param: Receives column of the neighbouring cell.
	param: Receives row of the neighbouring cell.
	End Rem
	Method Neighbour(column:Int,row:Int,direction:Int,nextColumn:Int Var,nextRow:Int Var)
		If direction<0 Or direction>=NeighbourCount() Then Throw "Max2D tilemap: neighbour direction out of range"
		If Not IsHex() Then
			ToSquare(column,row,nextColumn,nextRow)
			Select direction
				Case 0; nextColumn:+1
				Case 1; nextRow:+1
				Case 2; nextColumn:-1
				Case 3; nextRow:-1
			End Select
			FromSquare(nextColumn,nextRow,nextColumn,nextRow)
			Return
		End If
		Local q:Int,r:Int
		ToAxial(column,row,q,r)
		Select direction
			Case 0; q:+1
			Case 1; q:+1; r:-1
			Case 2; r:-1
			Case 3; q:-1
			Case 4; q:-1; r:+1
			Case 5; r:+1
		End Select
		FromAxial(q,r,nextColumn,nextRow)
	End Method

	Rem
	bbdoc: Returns grid distance between cells, ignoring terrain, occupancy and obstacles.
	param: Integer grid column.
	param: Integer grid row.
	param: Column of the second cell.
	param: Row of the second cell.
	End Rem
	Method Distance:Int(column:Int,row:Int,otherColumn:Int,otherRow:Int)
		CheckCell(column,row); CheckCell(otherColumn,otherRow)
		If Not IsHex() Then
			ToSquare(column,row,column,row); ToSquare(otherColumn,otherRow,otherColumn,otherRow)
			Return Abs(column-otherColumn)+Abs(row-otherRow)
		End If
		Local q:Int,r:Int,oq:Int,orr:Int
		ToAxial(column,row,q,r); ToAxial(otherColumn,otherRow,oq,orr)
		q:-oq; r:-orr
		Return Max(Abs(q),Max(Abs(r),Abs(q+r)))
	End Method

	Rem
	bbdoc: Allocates cells within a grid distance, or only at that distance when ring=True. Does not consider obstacles.
	param: Integer grid column.
	param: Integer grid row.
	param: Nonnegative distance from the centre cell in grid steps.
	param: True to return only cells at the radius; False includes the interior.
	End Rem
	Method Range:STileCell[](column:Int,row:Int,radius:Int,ring:Int=False)
		CheckCell(column,row)
		If radius<0 Or radius>1024 Then Throw "Max2D tilemap: range radius must be 0..1024"
		Local capacity:Int=1+3*radius*(radius+1)
		If Not IsHex() Then capacity=1+2*radius*(radius+1)
		If ring And radius>0 Then capacity=NeighbourCount()*radius
		Local result:STileCell[]=New STileCell[capacity]
		Local q:Int=column,r:Int=row,count:Int
		If IsHex() Then ToAxial(column,row,q,r) Else ToSquare(column,row,q,r)
		For Local dr:Int=-radius To radius
			For Local dq:Int=-radius To radius
				Local distance:Int=Abs(dq)+Abs(dr)
				If IsHex() Then distance=Max(Abs(dq),Max(Abs(dr),Abs(dq+dr)))
				If distance>radius Or (ring And distance<>radius) Then Continue
				Local c:Int=q+dq,rr:Int=r+dr
				If IsHex() Then FromAxial(c,rr,c,rr) Else FromSquare(c,rr,c,rr)
				result[count].column=c; result[count].row=rr; count:+1
			Next
		Next
		Return result
	End Method

	' Bounds for cell origins, not artwork. Renderer expands for artwork first.

	Rem
	bbdoc: Converts map-space bounds to a conservative range of cell origins.
	param: Left boundary of the region.
	param: Inclusive top of the visible band in paragraph-local coordinates.
	param: Right boundary of the region.
	param: Exclusive bottom of the visible band in paragraph-local coordinates.
	param: Receives lowest candidate column.
	param: Receives lowest candidate row.
	param: Receives highest candidate column.
	param: Receives highest candidate row.
	End Rem
	Method OriginBounds(left:Double,top:Double,right:Double,bottom:Double,c0:Double Var,r0:Double Var,c1:Double Var,r1:Double Var)
		If _layout=ETileLayout.Isometric Then
			c0=Floor(left/_width+top/_height)-1; c1=Ceil(right/_width+bottom/_height)+1
			r0=Floor(top/_height-right/_width)-1; r1=Ceil(bottom/_height-left/_width)+1
		Else
			c0=Floor((left-_width/2)/StepX())-1; c1=Ceil(right/StepX())+1
			r0=Floor((top-_height/2)/StepY())-1; r1=Ceil(bottom/StepY())+1
		End If
	End Method

	Private
	Method ToSquare(column:Int,row:Int,a:Int Var,b:Int Var)
		CheckCell(column,row)
		a=column; b=row
		If _layout<>ETileLayout.StaggeredIsometric Then Return
		Local sign:Int=-1
		If _stagger=ETileStagger.Even Then sign=1
		If _axis=ETileAxis.Y Then
			a=column-(row+sign*(row & 1))/2; b=a+row
		Else
			a=row-(column+sign*(column & 1))/2; b=a+column
		End If
	End Method

	Method FromSquare(a:Int,b:Int,column:Int Var,row:Int Var)
		Local c:Long=a,r:Long=b,sign:Int=-1
		If _stagger=ETileStagger.Even Then sign=1
		If _layout=ETileLayout.StaggeredIsometric Then
			If _axis=ETileAxis.Y Then
				r=Long(b)-a; c=Long(a)+(r+sign*(r & 1))/2
			Else
				c=Long(b)-a; r=Long(a)+(c+sign*(c & 1))/2
			End If
		End If
		If Abs(c)>TILE_COORDINATE_LIMIT Or Abs(r)>TILE_COORDINATE_LIMIT Then Throw "Max2D tilemap: cell coordinate out of range"
		column=Int(c); row=Int(r)
	End Method

End Type
