Rem
bbdoc: LDtk entity artwork, drawn independently of its gameplay rectangle.
about: Set visible=False to replace the editor artwork with game visuals. mode is the exported LDtk tileRenderMode name. The entity object's transform, opacity and visibility apply to both placement and rendering.
End Rem
Type TLDTKEntityArtwork Extends TTileObjectArtwork
	Field image:TImage,mode:String
	Field pivotX:Float,pivotY:Float,opacity:Float=1
	Field left:Int,right:Int,top:Int,bottom:Int
	Method ValidateNineSlice(width:Float,height:Float)
		If left<0 Or right<0 Or top<0 Or bottom<0 Or Long(left)+right>=image.width Or Long(top)+bottom>=image.height Then Throw "Max2D.LDTK: nine-slice borders must leave a positive source centre"
		If width<left+right Or height<top+bottom Then Throw "Max2D.LDTK: nine-slice entity is smaller than its borders"
	End Method
	Method Draw(canvas:TMax2DGraphics,width:Float,height:Float,elapsed:Long) Override
		If Not image Or Not visible Or opacity=0 Or width<=0 Or height<=0 Then Return
		If Not (opacity>=0 And opacity<=1 And pivotX>=0 And pivotX<=1 And pivotY>=0 And pivotY<=1) Then Throw "Max2D.LDTK: invalid entity artwork properties"
		Local alpha:Float=canvas.state.alpha
		canvas.state.alpha:*opacity
		Try
			Local iw:Float=image.width,ih:Float=image.height
			Local sx:Float,sy:Float,sw:Float=iw,sh:Float=ih,dw:Float=iw,dh:Float=ih
			Select mode
				Case "Stretch"
					dw=width; dh=height
				Case "FitInside"
					Local scale:Float=Min(width/iw,height/ih)
					dw=iw*scale; dh=ih*scale
				Case "Cover"
					Local scale:Float=Max(width/iw,height/ih)
					sw=Min(iw,width/scale); sh=Min(ih,height/scale)
					sx=(iw-sw)*pivotX; sy=(ih-sh)*pivotY; dw=width; dh=height
				Case "FullSizeCropped"
					sw=Min(iw,width); sh=Min(ih,height)
					sx=(iw-sw)*pivotX; sy=(ih-sh)*pivotY; dw=sw; dh=sh
				Case "FullSizeUncropped"
				Case "Repeat"
					TLDTKImageDrawing.DrawRepeated(canvas,image,0,0,width,height,0,0,iw,ih,iw,ih)
					Return
				Case "NineSlice"
					ValidateNineSlice(width,height)
					' Corners remain full size; edges and centre repeat, matching LDtk.
					For Local row:Int=0 Until 3
						Local dy:Float,dh:Float,sy:Float,sh:Float
						Select row
							Case 0; dy=0; dh=top; sy=0; sh=top
							Case 1; dy=top; dh=height-top-bottom; sy=top; sh=ih-top-bottom
							Case 2; dy=height-bottom; dh=bottom; sy=ih-bottom; sh=bottom
						End Select
						For Local column:Int=0 Until 3
							Local dx:Float,dw:Float,sx:Float,sw:Float
							Select column
								Case 0; dx=0; dw=left; sx=0; sw=left
								Case 1; dx=left; dw=width-left-right; sx=left; sw=iw-left-right
								Case 2; dx=width-right; dw=right; sx=iw-right; sw=right
							End Select
							TLDTKImageDrawing.DrawRepeated(canvas,image,dx,dy,dw,dh,sx,sy,sw,sh,sw,sh)
						Next
					Next
					Return
				Default
					Throw "Max2D.LDTK: unsupported entity artwork mode: "+mode
			End Select
			canvas.DrawImageRegion(image,(width-dw)*pivotX,(height-dh)*pivotY,dw,dh,sx,sy,sw,sh,0,0)
		Finally
			canvas.state.alpha=alpha
		End Try
	End Method
End Type

Private
Type TLDTKImageDrawing
	' Clip the pattern to its destination and visit only tiles intersecting the view.
	' Source and destination sizes stay separate so fractional background crops survive.
	Function DrawRepeated:Int(canvas:TMax2DGraphics,image:TImage,x:Double,y:Double,width:Double,height:Double,sx:Double,sy:Double,sw:Double,sh:Double,tw:Double,th:Double,pivotX:Double=0,pivotY:Double=0)
		If width<=0 Or height<=0 Or sw<=0 Or sh<=0 Or tw<=0 Or th<=0 Then Return 0
		' The sum detects NaN/infinity without allocating a validation array per draw.
		Local check:Double=x+y+width+height+sx+sy+sw+sh+tw+th+pivotX+pivotY
		If IsNan(check) Or IsInf(check) Then Throw "Max2D.LDTK: invalid repeated image geometry"
		Local vl:Double,vt:Double,vr:Double,vb:Double
		If Not TileLayerViewBounds(canvas,vl,vt,vr,vb) Then Return 0
		vl=Max(x,vl); vt=Max(y,vt); vr=Min(x+width,vr); vb=Min(y+height,vb)
		If vr<=vl Or vb<=vt Then Return 0
		Local startX:Double=(width-tw)*pivotX,startY:Double=(height-th)*pivotY
		startX:-Ceil(startX/tw)*tw; startY:-Ceil(startY/th)*th
		startX:+x; startY:+y
		Local c0:Double=Max(0,Floor((vl-startX)/tw)),c1:Double=Ceil((vr-startX)/tw)-1
		Local r0:Double=Max(0,Floor((vt-startY)/th)),r1:Double=Ceil((vb-startY)/th)-1
		If c1>2147483646 Or r1>2147483646 Or (c1-c0+1)*(r1-r0+1)>1048576 Then Throw "Max2D.LDTK: too many visible repeated image tiles"
		Local count:Int
		For Local row:Int=Int(r0) To Int(r1)
			Local py:Double=startY+row*th,t:Double=Max(y,py),b:Double=Min(y+height,py+th)
			For Local column:Int=Int(c0) To Int(c1)
				Local px:Double=startX+column*tw,l:Double=Max(x,px),r:Double=Min(x+width,px+tw)
				If r<=l Or b<=t Then Continue
				canvas.DrawImageRegion(image,Float(l),Float(t),Float(r-l),Float(b-t),Float(sx+(l-px)*sw/tw),Float(sy+(t-py)*sh/th),Float((r-l)*sw/tw),Float((b-t)*sh/th),0,0)
				count:+1
			Next
		Next
		Return count
	End Function
End Type
Public
