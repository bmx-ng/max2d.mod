Rem
bbdoc: Optional artwork drawn in an object's local coordinates without changing its query geometry.
about: The map applies object/layer transforms, tint and opacity before Draw. Implementations must restore any drawing state they change.
End Rem
Type TTileObjectArtwork Abstract
	Field visible:Int=True
	Method Draw(canvas:TMax2DGraphics,width:Float,height:Float,elapsed:Long) Abstract
End Type

Enum ETileObjectShape
	Rectangle
	Ellipse
	Point
	Polygon
	Polyline
End Enum

Struct STilePoint
	Field x:Double,y:Double
End Struct

Rem
bbdoc: Named geometry in layer-local coordinates, or image-local coordinates for tile collisions.
about: The affine matrix maps shape-local coordinates to its parent. Rotation is clockwise in degrees. Tile artwork and text are drawn automatically; other shapes are gameplay data.
End Rem
Type TTileObject
	Field id:Int,name:String,className:String
	Field properties:TTileProperties=New TTileProperties
	Field shape:ETileObjectShape=ETileObjectShape.Rectangle
	Field visible:Int=True
	Field opacity:Float=1
	Field x:Double,y:Double,width:Double,height:Double
	Field xx:Double=1,xy:Double,yx:Double,yy:Double=1
	Field points:STilePoint[]
	' Optional tile artwork. Width/height describe the displayed rectangle.
	Field tileProperties:TTileProperties
	Method Property:TTileProperty(name:String)
		Local value:TTileProperty=properties.Get(name)
		If Not value And tileProperties Then value=tileProperties.Get(name)
		Return value
	End Method
	Field artwork:TTileObjectArtwork
	Field text:TTileText
	Field fillMode:ETileFillMode
	Field tile:Int,flip:ETileFlip
	Field sortY:Double
	Method SetRotation(degrees:Double)
		xx=Cos(degrees); xy=-Sin(degrees); yx=Sin(degrees); yy=Cos(degrees)
	End Method
	Method Instance:STileObjectInstance(offsetX:Double=0,offsetY:Double=0)
		Local result:STileObjectInstance
		result.source=Self; result.x=x+offsetX; result.y=y+offsetY
		result.xx=xx; result.xy=xy; result.yx=yx; result.yy=yy
		If tile Then
			Local t:STileImageTransform=TileImageTransform(Float(width),Float(height),flip)
			result.x:+xx*t.tx+xy*t.ty; result.y:+yx*t.tx+yy*t.ty
			result.xx=xx*t.xx+xy*t.yx; result.xy=xx*t.xy+xy*t.yy
			result.yx=yx*t.xx+yy*t.yx; result.yy=yx*t.xy+yy*t.yy
		End If
		Return result
	End Method
	Method Validate()
		For Local value:Double=EachIn [x,y,width,height,xx,xy,yx,yy,sortY]
			If IsNan(value) Or IsInf(value) Then Throw "Max2D tilemap: invalid object geometry"
		Next
		If Not (opacity>=0 And opacity<=1) Then Throw "Max2D tilemap: invalid object opacity"
		ValidateTileFlip(flip)
		If width<0 Or height<0 Then Throw "Max2D tilemap: negative object dimensions"
		If shape=ETileObjectShape.Polygon And points.Length<3 Then Throw "Max2D tilemap: polygon requires three points"
		If shape=ETileObjectShape.Polyline And points.Length<2 Then Throw "Max2D tilemap: polyline requires two points"
		For Local p:STilePoint=EachIn points
			If IsNan(p.x) Or IsInf(p.x) Or IsNan(p.y) Or IsInf(p.y) Then Throw "Max2D tilemap: invalid object point"
		Next
	End Method
End Type

Rem
bbdoc: A shape reference and its complete map-local transform. No geometry is copied.
about: Region results use conservative axis-aligned bounds, including touching edges. ContainsPoint tests the actual shape; tolerance is in map units for points and polylines only. Visibility does not affect queries.
End Rem
Struct STileObjectInstance
	Field source:TTileObject
	Field layer:TTileLayer
	Field column:Int,row:Int
	Field x:Double,y:Double,xx:Double,xy:Double,yx:Double,yy:Double
	Method TransformPoint(px:Double,py:Double,ox:Double Var,oy:Double Var)
		ox=x+xx*px+xy*py; oy=y+yx*px+yy*py
	End Method
	Method Bounds(left:Double Var,top:Double Var,right:Double Var,bottom:Double Var)
		left=x; right=x; top=y; bottom=y
		If source.shape=ETileObjectShape.Point Then Return
		If source.shape=ETileObjectShape.Ellipse Then
			Local cx:Double,cy:Double,rx:Double=source.width/2,ry:Double=source.height/2
			TransformPoint(rx,ry,cx,cy)
			Local ex:Double=Sqr((xx*rx)^2+(xy*ry)^2),ey:Double=Sqr((yx*rx)^2+(yy*ry)^2)
			left=cx-ex; right=cx+ex; top=cy-ey; bottom=cy+ey
			Return
		End If
		Local count:Int=4
		If source.shape=ETileObjectShape.Polygon Or source.shape=ETileObjectShape.Polyline Then count=source.points.Length
		For Local i:Int=0 Until count
			Local px:Double,py:Double,ox:Double,oy:Double
			If source.shape=ETileObjectShape.Rectangle Then
				If i=1 Or i=2 Then px=source.width
				If i>=2 Then py=source.height
			Else
				px=source.points[i].x; py=source.points[i].y
			End If
			TransformPoint(px,py,ox,oy)
			If i=0 Then left=ox; right=ox; top=oy; bottom=oy
			left=Min(left,ox); right=Max(right,ox); top=Min(top,oy); bottom=Max(bottom,oy)
		Next
	End Method
	Method ContainsPoint:Int(px:Double,py:Double,tolerance:Double=0)
		If tolerance<0 Or IsNan(tolerance) Or IsInf(tolerance) Then Throw "Max2D tilemap: invalid picking tolerance"
		If IsNan(px) Or IsInf(px) Or IsNan(py) Or IsInf(py) Then Return False
		If source.shape=ETileObjectShape.Point Then Return (px-x)^2+(py-y)^2<=tolerance^2
		If source.shape=ETileObjectShape.Polyline Then
			For Local i:Int=1 Until source.points.Length
				Local ax:Double,ay:Double,bx:Double,by:Double
				TransformPoint(source.points[i-1].x,source.points[i-1].y,ax,ay)
				TransformPoint(source.points[i].x,source.points[i].y,bx,by)
				If TileSegmentDistanceSquared(px,py,ax,ay,bx,by)<=tolerance^2 Then Return True
			Next
			Return False
		End If
		Local determinant:Double=xx*yy-xy*yx
		If determinant=0 Then Return False
		Local dx:Double=px-x,dy:Double=py-y
		px=(yy*dx-xy*dy)/determinant; py=(-yx*dx+xx*dy)/determinant
		Select source.shape
			Case ETileObjectShape.Rectangle
				Return px>=0 And py>=0 And px<=source.width And py<=source.height
			Case ETileObjectShape.Ellipse
				If source.width=0 Or source.height=0 Then Return False
				Return (2*px/source.width-1)^2+(2*py/source.height-1)^2<=1
			Case ETileObjectShape.Polygon
				Local inside:Int,j:Int=source.points.Length-1
				For Local i:Int=0 Until source.points.Length
					Local a:STilePoint=source.points[i],b:STilePoint=source.points[j]
					If TileSegmentDistanceSquared(px,py,a.x,a.y,b.x,b.y)<=1e-18 Then Return True
					If (a.y>py)<>(b.y>py) Then
						If px<(b.x-a.x)*(py-a.y)/(b.y-a.y)+a.x Then inside=Not inside
					End If
					j=i
				Next
				Return inside
		End Select
		Return False
	End Method
End Struct

Function TileSegmentDistanceSquared:Double(px:Double,py:Double,ax:Double,ay:Double,bx:Double,by:Double)
	Local dx:Double=bx-ax,dy:Double=by-ay,length:Double=dx*dx+dy*dy,t:Double
	If length>0 Then t=Max(0.0,Min(1.0,((px-ax)*dx+(py-ay)*dy)/length))
	Return (px-ax-t*dx)^2+(py-ay-t*dy)^2
End Function

Type TTileObjectQueryResult
	Field items:STileObjectInstance[]
	Field count:Int
	Field cells:TTileQueryResult=New TTileQueryResult
	Method Clear()
		For Local i:Int=0 Until count
			items[i].source=Null; items[i].layer=Null
		Next
		count=0
	End Method
	Method Add(item:STileObjectInstance)
		If count=items.Length Then items=items[..Max(16,count*2)]
		items[count]=item; count:+1
	End Method
End Type

Function CheckTileObjectRegion(x:Double,y:Double,width:Double,height:Double)
	If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or Not (width>=0) Or Not (height>=0) Or IsInf(x+width) Or IsInf(y+height) Then Throw "Max2D tilemap: invalid object query rectangle"
End Function

Function TileObjectOverlaps:Int(item:STileObjectInstance,x:Double,y:Double,width:Double,height:Double)
	Local left:Double,top:Double,right:Double,bottom:Double
	item.Bounds(left,top,right,bottom)
	Return right>=x And bottom>=y And left<=x+width And top<=y+height
End Function
