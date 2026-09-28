Rem
bbdoc: A movable image attached to a tile layer. x/y are its map-local ground-contact point.
about: The default artwork anchor is bottom-centre. GroundDepth layers interleave sprites with tiles; Grid layers draw sprites after their tiles in insertion order.
End Rem
Type TTileSprite
	Field image:TImage
	Field x:Float,y:Float,anchorX:Float,anchorY:Float
	Field frame:Int,animated:Int,visible:Int=True
	Field flip:ETileFlip
	Field depthOffset:Float,sortOrder:Int
	Method Validate()
		If Not image Then Throw "Max2D tilemap: sprite image is null"
		image.CheckIndex(frame)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(anchorX) Or IsInf(anchorX) Or IsNan(anchorY) Or IsInf(anchorY) Or IsNan(depthOffset) Or IsInf(depthOffset) Then Throw "Max2D tilemap: invalid sprite position or depth"
		ValidateTileFlip(flip)
	End Method
End Type

Struct STileDrawItem
	Field image:TImage
	Field frame:Int,x:Float,y:Float
	Field width:Float,height:Float,fillMode:ETileFillMode
	Field flip:ETileFlip
	Field depth:Double,sortX:Double
	Field order:Int,sequence:Int
End Struct

' Retained scratch storage: sorting creates no objects per item after growth.
Type TTileDrawQueue
	Field items:STileDrawItem[]
	Field count:Int
	Method Add(image:TImage,frame:Int,x:Float,y:Float,flip:ETileFlip,depth:Double,sortX:Double,order:Int,width:Float=0,height:Float=0,fillMode:ETileFillMode=ETileFillMode.Stretch)
		If IsNan(depth) Or IsInf(depth) Or IsNan(sortX) Or IsInf(sortX) Then Throw "Max2D tilemap: invalid sorting key"
		If count=items.Length Then items=items[..Max(32,items.Length*2)]
		Local item:STileDrawItem
		item.width=width; item.height=height; item.fillMode=fillMode
		item.image=image; item.frame=frame; item.x=x; item.y=y; item.flip=flip
		item.depth=depth; item.sortX=sortX; item.order=order; item.sequence=count
		items[count]=item; count:+1
	End Method
	Method Clear()
		For Local i:Int=0 Until count
			items[i].image=Null
		Next
		count=0
	End Method
	Function After:Int(a:STileDrawItem,b:STileDrawItem)
		If a.depth<>b.depth Then Return a.depth>b.depth
		If a.order<>b.order Then Return a.order>b.order
		If a.sortX<>b.sortX Then Return a.sortX>b.sortX
		Return a.sequence>b.sequence
	End Function
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
