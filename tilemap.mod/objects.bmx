
Rem
bbdoc: Optional artwork drawn in an object's local coordinates without changing its query geometry.
about: The map applies object/layer transforms, tint and opacity before Draw. Implementations must restore any drawing state they change.
End Rem
Type TTileObjectArtwork Abstract

	Rem
	bbdoc: Whether this artwork, object or layer participates in drawing.
	End Rem
	Field visible:Int=True

	Rem
	bbdoc: Draws custom object artwork at the supplied logical size and animation time.
	param: Drawing canvas whose state and rendering context are used.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Elapsed animation time in milliseconds; negative values are treated as zero.
	End Rem
	Method Draw(canvas:TMax2DGraphics,width:Float,height:Float,elapsed:Long) Abstract
End Type

Rem
bbdoc: Geometry used for a tilemap object or tile collision shape.
End Rem
Enum ETileObjectShape

	Rem
	bbdoc: Rectangular object geometry.
	End Rem
	Rectangle

	Rem
	bbdoc: Ellipse inscribed in the object's dimensions.
	End Rem
	Ellipse

	Rem
	bbdoc: A point object, picked using the caller's tolerance.
	End Rem
	Point

	Rem
	bbdoc: Closed polygon defined by object-local points.
	End Rem
	Polygon

	Rem
	bbdoc: Open line segments defined by object-local points.
	End Rem
	Polyline
End Enum

Rem
bbdoc: A two-dimensional point in map or object-local coordinates.
End Rem
Struct STilePoint

	Rem
	bbdoc: Horizontal position in the coordinate space described by the containing type.
	End Rem
	Field x:Double

	Rem
	bbdoc: Vertical position in the coordinate space described by the containing type.
	End Rem
	Field y:Double
End Struct

Rem
bbdoc: Named geometry in layer-local coordinates, or image-local coordinates for tile collisions.
about: The affine matrix maps shape-local coordinates to its parent. Rotation is clockwise in degrees. Tile artwork and text are drawn automatically; other shapes are gameplay data.
End Rem
Type TTileObject

	Rem
	bbdoc: Identifier associated with this object or definition.
	End Rem
	Field id:Int

	Rem
	bbdoc: Name used to identify this entry.
	End Rem
	Field name:String

	Rem
	bbdoc: Editor-defined custom class name.
	End Rem
	Field className:String

	Rem
	bbdoc: Mutable application properties associated with this item.
	End Rem
	Field properties:TTileProperties=New TTileProperties

	Rem
	bbdoc: Geometric shape used for bounds and point queries.
	End Rem
	Field shape:ETileObjectShape=ETileObjectShape.Rectangle

	Rem
	bbdoc: Whether this artwork, object or layer participates in drawing.
	End Rem
	Field visible:Int=True

	Rem
	bbdoc: Opacity multiplier from 0.0 to 1.0.
	End Rem
	Field opacity:Float=1

	Rem
	bbdoc: Horizontal object origin in its parent layer or tile-image coordinates.
	End Rem
	Field x:Double

	Rem
	bbdoc: Vertical object origin in its parent layer or tile-image coordinates.
	End Rem
	Field y:Double

	Rem
	bbdoc: Object width in local map units.
	End Rem
	Field width:Double

	Rem
	bbdoc: Object height in local map units.
	End Rem
	Field height:Double

	Rem
	bbdoc: Affine coefficient mapping input x to output x.
	End Rem
	Field xx:Double=1

	Rem
	bbdoc: Affine coefficient mapping input y to output x.
	End Rem
	Field xy:Double

	Rem
	bbdoc: Affine coefficient mapping input x to output y.
	End Rem
	Field yx:Double

	Rem
	bbdoc: Affine coefficient mapping input y to output y.
	End Rem
	Field yy:Double=1

	Rem
	bbdoc: Object-local polygon or polyline vertices.
	End Rem
	Field points:STilePoint[]
	' Optional tile artwork. Width/height describe the displayed rectangle.

	Rem
	bbdoc: Properties inherited from a referenced tile definition.
	End Rem
	Field tileProperties:TTileProperties

	Rem
	bbdoc: Returns a named object property, or Null when absent.
	param: Name used to register or look up the item.
	End Rem
	Method Property:TTileProperty(name:String)
		Local value:TTileProperty=properties.Get(name)
		If Not value And tileProperties Then value=tileProperties.Get(name)
		Return value
	End Method

	Rem
	bbdoc: Optional custom entity artwork or cached artwork definitions.
	End Rem
	Field artwork:TTileObjectArtwork

	Rem
	bbdoc: Optional text content and styling drawn within the object rectangle.
	End Rem
	Field text:TTileText

	Rem
	bbdoc: Whether artwork stretches or preserves its aspect ratio inside its drawing box.
	End Rem
	Field fillMode:ETileFillMode

	Rem
	bbdoc: Native tile identifier; zero means no tile artwork.
	End Rem
	Field tile:Int

	Rem
	bbdoc: Reflection and rotation flags applied to tile artwork.
	End Rem
	Field flip:ETileFlip

	Rem
	bbdoc: Ground-depth coordinate used for object drawing order.
	End Rem
	Field sortY:Double

	Rem
	bbdoc: Sets the object rotation in degrees.
	param: Object rotation in degrees.
	End Rem
	Method SetRotation(degrees:Double)
		xx=Cos(degrees); xy=-Sin(degrees); yx=Sin(degrees); yy=Cos(degrees)
	End Method

	Rem
	bbdoc: Creates a positioned instance of this object with additional map offsets.
	param: Horizontal placement offset in map units.
	param: Vertical placement offset in map units.
	End Rem
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

	Rem
	bbdoc: Checks object settings and throws when a value is invalid.
	End Rem
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

	Rem
	bbdoc: Shared source object whose geometry and properties this instance exposes.
	End Rem
	Field source:TTileObject

	Rem
	bbdoc: Native or imported layer containing this object.
	End Rem
	Field layer:TTileLayer

	Rem
	bbdoc: Integer cell column.
	End Rem
	Field column:Int

	Rem
	bbdoc: Integer cell row.
	End Rem
	Field row:Int

	Rem
	bbdoc: Horizontal map-space translation of the object instance.
	End Rem
	Field x:Double

	Rem
	bbdoc: Vertical map-space translation of the object instance.
	End Rem
	Field y:Double

	Rem
	bbdoc: Affine coefficient mapping input x to output x.
	End Rem
	Field xx:Double

	Rem
	bbdoc: Affine coefficient mapping input y to output x.
	End Rem
	Field xy:Double

	Rem
	bbdoc: Affine coefficient mapping input x to output y.
	End Rem
	Field yx:Double

	Rem
	bbdoc: Affine coefficient mapping input y to output y.
	End Rem
	Field yy:Double

	Rem
	bbdoc: Transforms an object-local point into map coordinates.
	param: Horizontal point coordinate.
	param: Vertical point coordinate.
	param: Receives horizontal offset.
	param: Receives vertical offset.
	End Rem
	Method TransformPoint(px:Double,py:Double,ox:Double Var,oy:Double Var)
		ox=x+xx*px+xy*py; oy=y+yx*px+yy*py
	End Method

	Rem
	bbdoc: Gets the map-space axis-aligned bounds of an object instance.
	param: Receives left boundary of the region.
	param: Receives inclusive top of the visible band in paragraph-local coordinates.
	param: Receives right boundary of the region.
	param: Receives exclusive bottom of the visible band in paragraph-local coordinates.
	End Rem
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

	Rem
	bbdoc: Tests a map-space point against the transformed object geometry.
	param: Horizontal point coordinate.
	param: Vertical point coordinate.
	param: Nonnegative point-picking tolerance in map units.
	End Rem
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

Rem
bbdoc: Returns squared distance from a point to the nearest point on a line segment.
param: Horizontal point coordinate.
param: Vertical point coordinate.
param: Horizontal coordinate of the first line-segment endpoint.
param: Vertical coordinate of the first line-segment endpoint.
param: Horizontal coordinate of the second line-segment endpoint.
param: Vertical coordinate of the second line-segment endpoint.
End Rem
Function TileSegmentDistanceSquared:Double(px:Double,py:Double,ax:Double,ay:Double,bx:Double,by:Double)
	Local dx:Double=bx-ax,dy:Double=by-ay,length:Double=dx*dx+dy*dy,t:Double
	If length>0 Then t=Max(0.0,Min(1.0,((px-ax)*dx+(py-ay)*dy)/length))
	Return (px-ax-t*dx)^2+(py-ay-t*dy)^2
End Function

Rem
bbdoc: Reusable collection of positioned objects returned by region or point queries.
End Rem
Type TTileObjectQueryResult

	Rem
	bbdoc: Reusable positioned-object storage; only entries below count are populated.
	End Rem
	Field items:STileObjectInstance[]

	Rem
	bbdoc: Number of populated entries; backing storage may have extra capacity.
	End Rem
	Field count:Int

	Rem
	bbdoc: Reusable candidate-cell buffer used by tile-collision queries.
	End Rem
	Field cells:TTileQueryResult=New TTileQueryResult

	Rem
	bbdoc: Clears query results while retaining reusable storage.
	End Rem
	Method Clear()
		For Local i:Int=0 Until count
			items[i].source=Null; items[i].layer=Null
		Next
		count=0
	End Method

	Rem
	bbdoc: Appends a positioned object to this query result.
	param: Object or draw item to append or test.
	End Rem
	Method Add(item:STileObjectInstance)
		If count=items.Length Then items=items[..Max(16,count*2)]
		items[count]=item; count:+1
	End Method

End Type

Rem
bbdoc: Checks finite coordinates and nonnegative dimensions for an object query rectangle.
param: Horizontal coordinate.
param: Vertical coordinate.
param: Width of the rectangle or drawing surface.
param: Height of the rectangle or drawing surface.
End Rem
Function CheckTileObjectRegion(x:Double,y:Double,width:Double,height:Double)
	If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or Not (width>=0) Or Not (height>=0) Or IsInf(x+width) Or IsInf(y+height) Then Throw "Max2D tilemap: invalid object query rectangle"
End Function

Rem
bbdoc: Tests whether an object's bounds overlap a map-space rectangle.
param: Object or draw item to append or test.
param: Horizontal coordinate.
param: Vertical coordinate.
param: Width of the rectangle or drawing surface.
param: Height of the rectangle or drawing surface.
End Rem
Function TileObjectOverlaps:Int(item:STileObjectInstance,x:Double,y:Double,width:Double,height:Double)
	Local left:Double,top:Double,right:Double,bottom:Double
	item.Bounds(left,top,right,bottom)
	Return right>=x And bottom>=y And left<=x+width And top<=y+height
End Function
