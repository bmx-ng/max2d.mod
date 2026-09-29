
Rem
bbdoc: A movable image attached to a tile layer. x/y are its map-local ground-contact point.
about: The default artwork anchor is bottom-centre. GroundDepth layers interleave sprites with tiles; Grid layers draw sprites after their tiles in insertion order.
End Rem
Type TTileSprite

	Rem
	bbdoc: Image or animation supplying this object's artwork.
	End Rem
	Field image:TImage

	Rem
	bbdoc: Horizontal sprite anchor position in layer-local map units.
	End Rem
	Field x:Float

	Rem
	bbdoc: Vertical sprite anchor position in layer-local map units.
	End Rem
	Field y:Float

	Rem
	bbdoc: Horizontal artwork anchor in image units; defaults to the image centre.
	End Rem
	Field anchorX:Float

	Rem
	bbdoc: Vertical artwork anchor in image units; defaults to the image bottom.
	End Rem
	Field anchorY:Float

	Rem
	bbdoc: Zero-based image frame selected when animation is disabled.
	End Rem
	Field frame:Int

	Rem
	bbdoc: Whether the frame is chosen from elapsed time and image frame durations.
	End Rem
	Field animated:Int

	Rem
	bbdoc: Whether this artwork, object or layer participates in drawing.
	End Rem
	Field visible:Int=True

	Rem
	bbdoc: Reflection and rotation flags applied to tile artwork.
	End Rem
	Field flip:ETileFlip

	Rem
	bbdoc: Offset added to the artwork's ground-depth sorting coordinate.
	End Rem
	Field depthOffset:Float

	Rem
	bbdoc: Explicit tie-break order for artwork at the same depth.
	End Rem
	Field sortOrder:Int

	Rem
	bbdoc: Checks object settings and throws when a value is invalid.
	End Rem
	Method Validate()
		If Not image Then Throw "Max2D tilemap: sprite image is null"
		image.CheckIndex(frame)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(anchorX) Or IsInf(anchorX) Or IsNan(anchorY) Or IsInf(anchorY) Or IsNan(depthOffset) Or IsInf(depthOffset) Then Throw "Max2D tilemap: invalid sprite position or depth"
		ValidateTileFlip(flip)
	End Method

End Type

Rem
bbdoc: One tile or sprite queued with its stable drawing-order keys.
End Rem
Struct STileDrawItem

	Rem
	bbdoc: Image or animation supplying this object's artwork.
	End Rem
	Field image:TImage

	Rem
	bbdoc: Zero-based image frame selected when animation is disabled.
	End Rem
	Field frame:Int

	Rem
	bbdoc: Horizontal position in the coordinate space described by the containing type.
	End Rem
	Field x:Float

	Rem
	bbdoc: Vertical position in the coordinate space described by the containing type.
	End Rem
	Field y:Float

	Rem
	bbdoc: Logical width of this object or region.
	End Rem
	Field width:Float

	Rem
	bbdoc: Logical height of this object or region.
	End Rem
	Field height:Float

	Rem
	bbdoc: Whether artwork stretches or preserves its aspect ratio inside its drawing box.
	End Rem
	Field fillMode:ETileFillMode

	Rem
	bbdoc: Reflection and rotation flags applied to tile artwork.
	End Rem
	Field flip:ETileFlip

	Rem
	bbdoc: Ground-depth sorting key.
	End Rem
	Field depth:Double

	Rem
	bbdoc: Horizontal tie-break coordinate for equal-depth artwork.
	End Rem
	Field sortX:Double

	Rem
	bbdoc: Explicit drawing-order tie-break key.
	End Rem
	Field order:Int

	Rem
	bbdoc: Insertion sequence used to keep equal-key drawing order stable.
	End Rem
	Field sequence:Int
End Struct

' Retained scratch storage: sorting creates no objects per item after growth.

Rem
bbdoc: Reusable queue for sorting tile and sprite artwork before drawing.
End Rem
Type TTileDrawQueue

	Rem
	bbdoc: Reusable draw-item storage; only entries below count are populated.
	End Rem
	Field items:STileDrawItem[]

	Rem
	bbdoc: Number of populated entries; backing storage may have extra capacity.
	End Rem
	Field count:Int

	Rem
	bbdoc: Queues artwork and its placement, sizing and sort keys.
	param: Image to operate on.
	param: Zero-based image frame index.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Tile reflection and rotation flags.
	param: Ground-depth sorting coordinate.
	param: Horizontal tie-break coordinate for equal-depth artwork.
	param: Stable drawing-order tie-break value.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Whether artwork stretches to the box or preserves its aspect ratio.
	End Rem
	Method Add(image:TImage,frame:Int,x:Float,y:Float,flip:ETileFlip,depth:Double,sortX:Double,order:Int,width:Float=0,height:Float=0,fillMode:ETileFillMode=ETileFillMode.Stretch)
		If IsNan(depth) Or IsInf(depth) Or IsNan(sortX) Or IsInf(sortX) Then Throw "Max2D tilemap: invalid sorting key"
		If count=items.Length Then items=items[..Max(32,items.Length*2)]
		Local item:STileDrawItem
		item.width=width; item.height=height; item.fillMode=fillMode
		item.image=image; item.frame=frame; item.x=x; item.y=y; item.flip=flip
		item.depth=depth; item.sortX=sortX; item.order=order; item.sequence=count
		items[count]=item; count:+1
	End Method

	Rem
	bbdoc: Clears queued drawing items while retaining storage.
	End Rem
	Method Clear()
		For Local i:Int=0 Until count
			items[i].image=Null
		Next
		count=0
	End Method

	Rem
	bbdoc: Compares two drawing items by depth and stable tie-breaking keys.
	param: First drawing item to compare.
	param: Second drawing item to compare.
	End Rem
	Function After:Int(a:STileDrawItem,b:STileDrawItem)
		If a.depth<>b.depth Then Return a.depth>b.depth
		If a.order<>b.order Then Return a.order>b.order
		If a.sortX<>b.sortX Then Return a.sortX>b.sortX
		Return a.sequence>b.sequence
	End Function

	Rem
	bbdoc: Sorts queued artwork by ground depth and stable tie-breaking keys.
	End Rem
	Method Sort()
		' Heap sort with insertion sequence as the final key gives stable ties.
		For Local root:Int=count/2-1 To 0 Step -1
			Sift(root,count)
		Next
		For Local finish:Int=count-1 To 1 Step -1
			Local item:STileDrawItem=items[0]
			items[0]=items[finish]; items[finish]=item
			Sift(0,finish)
		Next
	End Method

	Rem
	bbdoc: Restores the heap ordering used by the drawing queue's in-place sort.
	param: Root element or heap index from which processing begins.
	param: Maximum number of cached entries or range of items to process.
	End Rem
	Method Sift(root:Int,limit:Int)
		While root<limit/2
			Local child:Int=root*2+1
			If child+1<limit And After(items[child+1],items[child]) Then child:+1
			If Not After(items[child],items[root]) Then Exit
			Local item:STileDrawItem=items[root]
			items[root]=items[child]; items[child]=item
			root=child
		Wend
	End Method

	Rem
	bbdoc: Draws tile artwork with flip flags and optional fitting, without using the image handle.
	param: Drawing canvas whose state and rendering context are used.
	param: Image to operate on.
	param: Zero-based image frame index.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	param: Tile reflection and rotation flags.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Whether artwork stretches to the box or preserves its aspect ratio.
	End Rem
	Function DrawImage(canvas:TMax2DGraphics,image:TImage,frame:Int,x:Float,y:Float,flip:ETileFlip,width:Float=0,height:Float=0,fillMode:ETileFillMode=ETileFillMode.Stretch)
		If width=0 Then width=image.width
		If height=0 Then height=image.height
		Local sx:Float,sy:Float,px:Float,py:Float
		TileImageFit(image.width,image.height,width,height,fillMode,sx,sy,px,py)
		Local artWidth:Float=image.width*sx,artHeight:Float=image.height*sy
		If (Int(flip) & ~3)=0 Then
			x:+px; y:+py
			If (flip & ETileFlip.Horizontal)<>ETileFlip.None Then x:+artWidth; artWidth=-artWidth
			If (flip & ETileFlip.Vertical)<>ETileFlip.None Then y:+artHeight; artHeight=-artHeight
			canvas.DrawImageRegion(image,x,y,artWidth,artHeight,0,0,image.width,image.height,0,0,frame)
			Return
		End If
		Local t:STileImageTransform=TileImageTransform(width,height,flip)
		Local state:TMax2DState=canvas.state
		Local ix:Float=state.ix,iy:Float=state.iy,jx:Float=state.jx,jy:Float=state.jy
		' Compose the artwork transform without allocating a drawing-state snapshot.
		state.ix=ix*t.xx+iy*t.yx; state.iy=ix*t.xy+iy*t.yy
		state.jx=jx*t.xx+jy*t.yx; state.jy=jx*t.xy+jy*t.yy
		Try
			Local tx:Float=t.tx+t.xx*px+t.xy*py,ty:Float=t.ty+t.yx*px+t.yy*py
			canvas.DrawImageRegion(image,x+ix*tx+iy*ty,y+jx*tx+jy*ty,artWidth,artHeight,0,0,image.width,image.height,0,0,frame)
		Finally
			state.ix=ix; state.iy=iy; state.jx=jx; state.jy=jy
		End Try
	End Function

End Type
