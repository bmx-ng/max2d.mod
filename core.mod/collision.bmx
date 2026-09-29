' Collision samples are unit-grid pixel centres in virtual/world coordinates.
' Cached masks are immutable: layer entries retain the mask from insertion time.

Rem
bbdoc: Clears all layers when passed to ResetCollisions; zero does not select every layer for collision queries.
End Rem
Const COLLISION_LAYER_ALL:Int=0

Rem
bbdoc: Bit mask selecting collision layer 1.
End Rem
Const COLLISION_LAYER_1:Int=$00000001

Rem
bbdoc: Bit mask selecting collision layer 2.
End Rem
Const COLLISION_LAYER_2:Int=$00000002

Rem
bbdoc: Bit mask selecting collision layer 3.
End Rem
Const COLLISION_LAYER_3:Int=$00000004

Rem
bbdoc: Bit mask selecting collision layer 4.
End Rem
Const COLLISION_LAYER_4:Int=$00000008

Rem
bbdoc: Bit mask selecting collision layer 5.
End Rem
Const COLLISION_LAYER_5:Int=$00000010

Rem
bbdoc: Bit mask selecting collision layer 6.
End Rem
Const COLLISION_LAYER_6:Int=$00000020

Rem
bbdoc: Bit mask selecting collision layer 7.
End Rem
Const COLLISION_LAYER_7:Int=$00000040

Rem
bbdoc: Bit mask selecting collision layer 8.
End Rem
Const COLLISION_LAYER_8:Int=$00000080

Rem
bbdoc: Bit mask selecting collision layer 9.
End Rem
Const COLLISION_LAYER_9:Int=$00000100

Rem
bbdoc: Bit mask selecting collision layer 10.
End Rem
Const COLLISION_LAYER_10:Int=$00000200

Rem
bbdoc: Bit mask selecting collision layer 11.
End Rem
Const COLLISION_LAYER_11:Int=$00000400

Rem
bbdoc: Bit mask selecting collision layer 12.
End Rem
Const COLLISION_LAYER_12:Int=$00000800

Rem
bbdoc: Bit mask selecting collision layer 13.
End Rem
Const COLLISION_LAYER_13:Int=$00001000

Rem
bbdoc: Bit mask selecting collision layer 14.
End Rem
Const COLLISION_LAYER_14:Int=$00002000

Rem
bbdoc: Bit mask selecting collision layer 15.
End Rem
Const COLLISION_LAYER_15:Int=$00004000

Rem
bbdoc: Bit mask selecting collision layer 16.
End Rem
Const COLLISION_LAYER_16:Int=$00008000

Rem
bbdoc: Bit mask selecting collision layer 17.
End Rem
Const COLLISION_LAYER_17:Int=$00010000

Rem
bbdoc: Bit mask selecting collision layer 18.
End Rem
Const COLLISION_LAYER_18:Int=$00020000

Rem
bbdoc: Bit mask selecting collision layer 19.
End Rem
Const COLLISION_LAYER_19:Int=$00040000

Rem
bbdoc: Bit mask selecting collision layer 20.
End Rem
Const COLLISION_LAYER_20:Int=$00080000

Rem
bbdoc: Bit mask selecting collision layer 21.
End Rem
Const COLLISION_LAYER_21:Int=$00100000

Rem
bbdoc: Bit mask selecting collision layer 22.
End Rem
Const COLLISION_LAYER_22:Int=$00200000

Rem
bbdoc: Bit mask selecting collision layer 23.
End Rem
Const COLLISION_LAYER_23:Int=$00400000

Rem
bbdoc: Bit mask selecting collision layer 24.
End Rem
Const COLLISION_LAYER_24:Int=$00800000

Rem
bbdoc: Bit mask selecting collision layer 25.
End Rem
Const COLLISION_LAYER_25:Int=$01000000

Rem
bbdoc: Bit mask selecting collision layer 26.
End Rem
Const COLLISION_LAYER_26:Int=$02000000

Rem
bbdoc: Bit mask selecting collision layer 27.
End Rem
Const COLLISION_LAYER_27:Int=$04000000

Rem
bbdoc: Bit mask selecting collision layer 28.
End Rem
Const COLLISION_LAYER_28:Int=$08000000

Rem
bbdoc: Bit mask selecting collision layer 29.
End Rem
Const COLLISION_LAYER_29:Int=$10000000

Rem
bbdoc: Bit mask selecting collision layer 30.
End Rem
Const COLLISION_LAYER_30:Int=$20000000

Rem
bbdoc: Bit mask selecting collision layer 31.
End Rem
Const COLLISION_LAYER_31:Int=$40000000

Rem
bbdoc: Bit mask selecting collision layer 32.
End Rem
Const COLLISION_LAYER_32:Int=$80000000

Rem
bbdoc: Cached opaque-pixel bit mask used by CPU image collision tests.
End Rem
Type TCollisionMask

	Rem
	bbdoc: Width of the source pixel mask.
	End Rem
	Field width:Int

	Rem
	bbdoc: Height of the source pixel mask.
	End Rem
	Field height:Int

	Rem
	bbdoc: Revision used to track cached or uploaded source data.
	End Rem
	Field version:Long

	Rem
	bbdoc: Opaque-pixel mask indexed in row-major order.
	End Rem
	Field bits:Byte[]

	Rem
	bbdoc: Builds or retrieves the collision mask for the current source pixels.
	param: Source data or object to read.
	End Rem
	Function ForSource:TCollisionMask(source:TImageSource)
		If source.renderTarget Then Throw "Max2D: render-image collisions require an explicit CreateCollisionImage snapshot"
		If source.locked And source.writing Then Throw "Max2D: unlock the image before collision testing"
		If source.collisionMask And source.collisionMask.version=source.version Then Return source.collisionMask
		Local mask:TCollisionMask=New TCollisionMask
		mask.width=source.width
		mask.height=source.height
		mask.version=source.version
		Local count:Long=Long(mask.width)*mask.height
		If (count+7)/8>$7fffffff Then Throw "Max2D: collision mask is too large"
		mask.bits=New Byte[Int((count+7)/8)]
		Local pixels:TPixmap=source.ReadPixels()
		Local stride:Int=BytesPerPixel[pixels.format]
		Local alphaOffset:Int=stride-1
		For Local y:Int=0 Until mask.height
			Local row:Byte Ptr=pixels.PixelPtr(0,y)
			For Local x:Int=0 Until mask.width
				If row[x*stride+alphaOffset]>=128 Then
					Local index:Long=Long(y)*mask.width+x
					mask.bits[Int(index Shr 3)]:|1 Shl Int(index&7)
				End If
			Next
		Next
		source.collisionMask=mask
		Return mask
	End Function

	Rem
	bbdoc: Reports whether a source pixel participates in collisions.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Solid:Int(x:Int,y:Int)
		Local index:Long=Long(y)*width+x
		Return (bits[Int(index Shr 3)] & (1 Shl Int(index&7)))<>0
	End Method

End Type

Rem
bbdoc: An immutable-by-convention collision shape captured in world coordinates before the camera.
about: Constructors capture geometry and alpha; subsequent image/state edits do not change the shape.
End Rem
Type TCollisionShape

	Rem
	bbdoc: Immutable opaque-pixel mask captured for the shape.
	End Rem
	Field mask:TCollisionMask

	Rem
	bbdoc: Horizontal origin of the image region within its shared source.
	End Rem
	Field sourceX:Int

	Rem
	bbdoc: Vertical origin of the image region within its shared source.
	End Rem
	Field sourceY:Int

	Rem
	bbdoc: Whether the collision shape uses trimmed image storage.
	End Rem
	Field trimmed:Int

	Rem
	bbdoc: Stored-pixel horizontal offset within the logical image.
	End Rem
	Field trimX:Int

	Rem
	bbdoc: Stored-pixel vertical offset within the logical image.
	End Rem
	Field trimY:Int

	Rem
	bbdoc: Width of the stored collision image region.
	End Rem
	Field trimWidth:Int

	Rem
	bbdoc: Height of the stored collision image region.
	End Rem
	Field trimHeight:Int

	Rem
	bbdoc: Logical width of this object or region.
	End Rem
	Field width:Double

	Rem
	bbdoc: Logical height of this object or region.
	End Rem
	Field height:Double

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
	bbdoc: Horizontal affine translation.
	End Rem
	Field tx:Double

	Rem
	bbdoc: Vertical affine translation.
	End Rem
	Field ty:Double

	Rem
	bbdoc: Inverse-transform coefficient mapping world x to local x.
	End Rem
	Field ax:Double

	Rem
	bbdoc: Inverse-transform coefficient mapping world y to local x.
	End Rem
	Field ay:Double

	Rem
	bbdoc: Inverse-transform coefficient mapping world x to local y.
	End Rem
	Field bx:Double

	Rem
	bbdoc: Inverse-transform coefficient mapping world y to local y.
	End Rem
	Field by:Double

	Rem
	bbdoc: Minimum horizontal bound.
	End Rem
	Field minX:Double

	Rem
	bbdoc: Minimum vertical bound.
	End Rem
	Field minY:Double

	Rem
	bbdoc: Maximum horizontal bound.
	End Rem
	Field maxX:Double

	Rem
	bbdoc: Maximum vertical bound.
	End Rem
	Field maxY:Double

	Rem
	bbdoc: Whether this result contains a usable mapping or source range.
	End Rem
	Field valid:Int

	Rem
	bbdoc: Creates a transformed collision shape from an image frame.
	param: Image to operate on.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Zero-based image frame index.
	param: Transform state to capture, or Null for identity object settings.
	End Rem
	Function Image:TCollisionShape(image:TImage,x:Double,y:Double,frame:Int=0,state:TMax2DState=Null)
		If Not image Then Throw "Max2D: collision image is null"
		image.CheckIndex(frame)
		Local shape:TCollisionShape=New TCollisionShape
		shape.mask=TCollisionMask.ForSource(image.sources[frame])
		shape.sourceX=image.sourceX[frame]
		shape.sourceY=image.sourceY[frame]
		Local trim:TImageTrim=image.Trim(frame)
		If trim Then
			If trim.width=0 Or trim.height=0 Then Return shape
			shape.trimmed=True
			shape.trimX=trim.x
			shape.trimY=trim.y
			shape.trimWidth=trim.width
			shape.trimHeight=trim.height
		End If
		' Keep the original affine transform, including its rounding at pixel edges.
		' Only the integer mask lookup changes when pixels are packed elsewhere.
		shape.Init(x,y,image.width,image.height,image.handle_x,image.handle_y,state)
		Return shape
	End Function

	Rem
	bbdoc: Creates a transformed rectangular collision shape.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	param: Transform state to capture, or Null for identity object settings.
	End Rem
	Function Rect:TCollisionShape(x:Double,y:Double,w:Double,h:Double,state:TMax2DState=Null)
		Local shape:TCollisionShape=New TCollisionShape
		' BRL collision rectangles ignore the primitive drawing handle.
		shape.Init(x,y,w,h,0,0,state)
		Return shape
	End Function

	Rem
	bbdoc: Initializes a shape's transform and world-space bounds.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	param: Horizontal local handle offset.
	param: Vertical local handle offset.
	param: Drawing state to inspect or apply.
	End Rem
	Method Init(x:Double,y:Double,w:Double,h:Double,hx:Double,hy:Double,state:TMax2DState)
		If Not state Then state=New TMax2DState
		width=w
		height=h
		xx=state.ix
		xy=state.iy
		yx=state.jx
		yy=state.jy
		tx=x+state.originX-hx*xx-hy*xy
		ty=y+state.originY-hx*yx-hy*yy
		Local ox:Double=xx,oy:Double=xy,px:Double=yx,py:Double=yy,otx:Double=tx,oty:Double=ty
		xx=state.coordXX*ox+state.coordXY*px
		xy=state.coordXX*oy+state.coordXY*py
		yx=state.coordYX*ox+state.coordYY*px
		yy=state.coordYX*oy+state.coordYY*py
		tx=state.coordXX*otx+state.coordXY*oty+state.coordTX
		ty=state.coordYX*otx+state.coordYY*oty+state.coordTY
		Local determinant:Double=xx*yy-xy*yx
		If w<=0 Or h<=0 Or determinant=0 Then Return
		ax=yy/determinant
		ay=-xy/determinant
		bx=-yx/determinant
		by=xx/determinant
		minX=Min(Min(tx,tx+w*xx),Min(tx+h*xy,tx+w*xx+h*xy))
		maxX=Max(Max(tx,tx+w*xx),Max(tx+h*xy,tx+w*xx+h*xy))
		minY=Min(Min(ty,ty+w*yx),Min(ty+h*yy,ty+w*yx+h*yy))
		maxY=Max(Max(ty,ty+w*yx),Max(ty+h*yy,ty+w*yx+h*yy))
		' Bounds keep grid indices representable and reject NaN/infinite transforms.
		If Not (minX>=-2147483647.0 And minY>=-2147483647.0 And maxX<=2147483646.0 And maxY<=2147483646.0) Then Throw "Max2D: collision coordinates outside supported range"
		valid=True
	End Method

	Rem
	bbdoc: Tests whether a world point lies on an opaque part of the shape.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Solid:Int(x:Double,y:Double)
		If Not valid Then Return False
		Local u:Double=(x-tx)*ax+(y-ty)*ay,v:Double=(x-tx)*bx+(y-ty)*by
		If u<0 Or v<0 Or u>=width Or v>=height Then Return False
		If Not mask Then Return True
		Local px:Int=Int(Floor(u)),py:Int=Int(Floor(v))
		If trimmed Then
			px:-trimX
			py:-trimY
			If px<0 Or py<0 Or px>=trimWidth Or py>=trimHeight Then Return False
		End If
		Return mask.Solid(sourceX+px,sourceY+py)
	End Method

	' Intersect the row with the inverse transform's two local coordinate slabs.
	' This avoids scanning the full bounding box of a narrow rotated shape.

	Rem
	bbdoc: Finds a shape's horizontal intersection interval at a world-space row.
	param: Vertical coordinate.
	param: Receives left boundary of the region.
	param: Receives right boundary of the region.
	End Rem
	Method Row:Int(y:Double,left:Double Var,right:Double Var)
		If Not Slab(ax,(y-ty)*ay-tx*ax,width,left,right) Then Return False
		Return Slab(bx,(y-ty)*by-tx*bx,height,left,right)
	End Method

	Rem
	bbdoc: Clips an intersection interval against one axis of the local shape.
	param: Change in local axis position per world-space x step.
	param: Local axis position when world-space x is zero.
	param: Size of the local shape along this axis.
	param: Receives left boundary of the region.
	param: Receives right boundary of the region.
	End Rem
	Function Slab:Int(a:Double,b:Double,extent:Double,left:Double Var,right:Double Var)
		If a=0 Then Return b>=0 And b<extent
		Local first:Double=-b/a,last:Double=(extent-b)/a
		left=Max(left,Min(first,last))
		right=Min(right,Max(first,last))
		Return left<right
	End Function

	Rem
	bbdoc: Tests this shape against another using transformed opaque pixels.
	param: Other shape to test for overlap.
	End Rem
	Method Intersects:Int(other:TCollisionShape)
		If Not other Or Not valid Or Not other.valid Then Return False
		Local left:Double=Max(minX,other.minX),right:Double=Min(maxX,other.maxX)
		Local top:Double=Max(minY,other.minY),bottom:Double=Min(maxY,other.maxY)
		If left>=right Or top>=bottom Then Return False
		' Include boundary candidates; Solid applies the exact half-open local bounds,
		' including reflected transforms whose high world edge can be inclusive.
		For Local y:Int=Int(Ceil(top-0.5)) To Int(Floor(bottom-0.5))
			Local l:Double=left,r:Double=right,cy:Double=Double(y)+0.5
			If Not Row(cy,l,r) Or Not other.Row(cy,l,r) Then Continue
			For Local x:Int=Int(Ceil(l-0.5)) To Int(Floor(r-0.5))
				Local cx:Double=Double(x)+0.5
				If Solid(cx,cy) And other.Solid(cx,cy) Then Return True
			Next
		Next
		Return False
	End Method

End Type

Rem
bbdoc: A collision shape and caller identifier stored in a collision layer.
End Rem
Type TCollisionEntry

	Rem
	bbdoc: Geometry or collision shape represented by this object.
	End Rem
	Field shape:TCollisionShape

	Rem
	bbdoc: Identifier associated with this object or definition.
	End Rem
	Field id:Object
End Type

Rem
bbdoc: Independent collision layers for a scene or simulation.
End Rem
Type TCollisionWorld

	Rem
	bbdoc: Layers owned by this map or collision world.
	End Rem
	Field layers:TList[32]

	Rem
	bbdoc: Clears selected collision layers, or all layers when the mask is zero.
	param: Bit mask of collision layers; zero selects all layers for reset.
	End Rem
	Method Reset(mask:Int=0)
		For Local i:Int=0 Until 32
			If mask=0 Or (mask & (1 Shl i)) Then layers[i]=Null
		Next
	End Method

	Rem
	bbdoc: Queries selected collision layers and optionally inserts the shape into other layers.
	param: Transformed collision shape to test or register.
	param: Bit mask of collision layers to query.
	param: Bit mask of collision layers into which the shape is inserted.
	param: Caller identifier attached to the object or shape.
	End Rem
	Method Collide:Object[](shape:TCollisionShape,collidemask:Int,writemask:Int,id:Object=Null)
		If Not shape Then Throw "Max2D: collision shape is null"
		Local hits:TList=New TList
		For Local i:Int=0 Until 32
			If Not (collidemask & (1 Shl i)) Or Not layers[i] Then Continue
			For Local entry:TCollisionEntry=EachIn layers[i]
				If shape.Intersects(entry.shape) Then hits.AddLast(entry)
			Next
		Next
		If writemask And shape.valid Then
			Local entry:TCollisionEntry=New TCollisionEntry
			entry.shape=shape
			entry.id=id
			For Local i:Int=0 Until 32
				If Not (writemask & (1 Shl i)) Then Continue
				If Not layers[i] Then layers[i]=New TList
				layers[i].AddFirst(entry)
			Next
		End If
		If hits.IsEmpty() Then Return Null
		Local result:Object[]=New Object[hits.Count()],index:Int
		For Local entry:TCollisionEntry=EachIn hits
			result[index]=entry.id
			index:+1
		Next
		Return result
	End Method

End Type

Private
Global _max2dCollisionWorld:TCollisionWorld=New TCollisionWorld
Function CollisionState:TMax2DState()
	Local canvas:TMax2DGraphics=TMax2DGraphics.selected
	If canvas And Not canvas.context.closed Then Return canvas.state
	Return New TMax2DState
End Function

Public

Rem
bbdoc: Clears selected collision layers; zero clears all 32 layers.
param: Bit mask of collision layers; zero selects all layers for reset.
End Rem
Function ResetCollisions(mask:Int=0)
	_max2dCollisionWorld.Reset(mask)
End Function

Rem
bbdoc: Tests an image against collision layers and optionally registers it for later queries.
param: Image to operate on.
param: Horizontal coordinate.
param: Vertical coordinate.
param: Zero-based image frame index.
param: Bit mask of collision layers to query.
param: Bit mask of collision layers into which the shape is inserted.
param: Caller identifier attached to the object or shape.
End Rem
Function CollideImage:Object[](image:TImage,x:Double,y:Double,frame:Int,collidemask:Int,writemask:Int,id:Object=Null)
	Return _max2dCollisionWorld.Collide(TCollisionShape.Image(image,x,y,frame,CollisionState()),collidemask,writemask,id)
End Function

Rem
bbdoc: Tests a rectangle against collision layers and optionally registers it for later queries.
param: Horizontal coordinate.
param: Vertical coordinate.
param: Width of the pixel rectangle.
param: Height of the pixel rectangle.
param: Bit mask of collision layers to query.
param: Bit mask of collision layers into which the shape is inserted.
param: Caller identifier attached to the object or shape.
End Rem
Function CollideRect:Object[](x:Double,y:Double,w:Double,h:Double,collidemask:Int,writemask:Int,id:Object=Null)
	Return _max2dCollisionWorld.Collide(TCollisionShape.Rect(x,y,w,h,CollisionState()),collidemask,writemask,id)
End Function

Rem
bbdoc: Tests two image frames for overlap using their handles and opaque pixels.
param: First image to test.
param: Horizontal coordinate of the first endpoint or rectangle's opposite corner.
param: Vertical coordinate of the first endpoint or rectangle's opposite corner.
param: Zero-based frame index in the first image.
param: Second image to test.
param: Horizontal coordinate of the second endpoint.
param: Vertical coordinate of the second endpoint.
param: Zero-based frame index in the second image.
End Rem
Function ImagesCollide:Int(image1:TImage,x1:Double,y1:Double,frame1:Int,image2:TImage,x2:Double,y2:Double,frame2:Int)
	Local state:TMax2DState=CollisionState()
	Return TCollisionShape.Image(image1,x1,y1,frame1,state).Intersects(TCollisionShape.Image(image2,x2,y2,frame2,state))
End Function

Rem
bbdoc: Tests two image frames for overlap with independent rotation and scale.
param: First image to test.
param: Horizontal coordinate of the first endpoint or rectangle's opposite corner.
param: Vertical coordinate of the first endpoint or rectangle's opposite corner.
param: Zero-based frame index in the first image.
param: Rotation of the first image in degrees.
param: Horizontal scale of the first image.
param: Vertical scale of the first image.
param: Second image to test.
param: Horizontal coordinate of the second endpoint.
param: Vertical coordinate of the second endpoint.
param: Zero-based frame index in the second image.
param: Rotation of the second image in degrees.
param: Horizontal scale of the second image.
param: Vertical scale of the second image.
End Rem
Function ImagesCollide2:Int(image1:TImage,x1:Double,y1:Double,frame1:Int,rot1:Double,scalex1:Double,scaley1:Double,image2:TImage,x2:Double,y2:Double,frame2:Int,rot2:Double,scalex2:Double,scaley2:Double)
	Local first:TMax2DState=CollisionState().Copy(),second:TMax2DState=first.Copy()
	first.rotation=Float(rot1)
	first.scaleX=Float(scalex1)
	first.scaleY=Float(scaley1)
	first.Transform()
	second.rotation=Float(rot2)
	second.scaleX=Float(scalex2)
	second.scaleY=Float(scaley2)
	second.Transform()
	Return TCollisionShape.Image(image1,x1,y1,frame1,first).Intersects(TCollisionShape.Image(image2,x2,y2,frame2,second))
End Function

Rem
bbdoc: Creates an independent CPU image for collision testing, explicitly reading back render images.
param: Image to operate on.
param: Zero-based image frame index.
about: The snapshot retains the selected frame's handle. Call again to capture subsequent changes.
End Rem
Function CreateCollisionImage:TImage(image:TImage,frame:Int=0)
	If Not image Then Throw "Max2D: collision image is null"
	Local pixmap:TPixmap=image.Lock(frame,True,False)
	Local result:TImage
	Try
		result=TImage.FromPixmap(pixmap,0)
	Catch error:Object
		image.Unlock(frame)
		Throw error
	End Try
	image.Unlock(frame)
	result.handle_x=image.handle_x
	result.handle_y=image.handle_y
	Return result
End Function
