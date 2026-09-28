Rem
bbdoc: Affine artwork transform relative to the original canvas top-left.
about: Diagonal exchanges axes with bottom-left anchoring. Rotation flags combine to 60/120/180 degrees clockwise about the canvas centre, after source-axis flips.
End Rem
Struct STileImageTransform
	Field xx:Float,xy:Float,yx:Float,yy:Float,tx:Float,ty:Float
End Struct

Function ValidateTileFlip(flip:ETileFlip)
	If Int(flip) & ~31 Then Throw "Max2D tilemap: unsupported tile transformation"
	If (flip & ETileFlip.Diagonal)<>ETileFlip.None And (flip & (ETileFlip.Rotate60|ETileFlip.Rotate120))<>ETileFlip.None Then Throw "Max2D tilemap: diagonal and rotation flags cannot be combined"
End Function

Function TileImageTransform:STileImageTransform(width:Float,height:Float,flip:ETileFlip)
	ValidateTileFlip(flip)
	Local t:STileImageTransform
	Local sx:Float=1,sy:Float=1
	If (flip & ETileFlip.Horizontal)<>ETileFlip.None Then sx=-1
	If (flip & ETileFlip.Vertical)<>ETileFlip.None Then sy=-1
	Local cx:Float=width/2,cy:Float=height/2
	If (flip & ETileFlip.Diagonal)<>ETileFlip.None Then
		t.xy=sx; t.yx=sy
		cx=height/2; cy=height-width/2
	Else
		Local rotation:Int
		If (flip & ETileFlip.Rotate60)<>ETileFlip.None Then rotation:+60
		If (flip & ETileFlip.Rotate120)<>ETileFlip.None Then rotation:+120
		Local c:Float=1,s:Float
		Select rotation
			Case 60; c=0.5; s=0.8660254037844386
			Case 120; c=-0.5; s=0.8660254037844386
			Case 180; c=-1
		End Select
		t.xx=c*sx; t.xy=-s*sy; t.yx=s*sx; t.yy=c*sy
	End If
	t.tx=cx-t.xx*width/2-t.xy*height/2
	t.ty=cy-t.yx*width/2-t.yy*height/2
	Return t
End Function

Function TileImageBounds(width:Float,height:Float,flip:ETileFlip,left:Float Var,top:Float Var,right:Float Var,bottom:Float Var)
	If (Int(flip) & ~3)=0 Then
		left=0; top=0; right=width; bottom=height
		Return
	End If
	Local t:STileImageTransform=TileImageTransform(width,height,flip)
	Local x:Float=t.xx*width,y:Float=t.xy*height
	left=t.tx+Min(0.0,x)+Min(0.0,y); right=t.tx+Max(0.0,x)+Max(0.0,y)
	x=t.yx*width; y=t.yy*height
	top=t.ty+Min(0.0,x)+Min(0.0,y); bottom=t.ty+Max(0.0,x)+Max(0.0,y)
End Function

' Image-to-display-box mapping, shared by drawing and collision geometry.
Function TileImageFit(width:Float,height:Float,boxWidth:Float,boxHeight:Float,mode:ETileFillMode,sx:Float Var,sy:Float Var,px:Float Var,py:Float Var)
	sx=boxWidth/width; sy=boxHeight/height
	If mode=ETileFillMode.PreserveAspectFit Then
		sx=Min(sx,sy); sy=sx
	Else If mode<>ETileFillMode.Stretch Then
		Throw "Max2D tilemap: invalid fill mode"
	End If
	px=(boxWidth-width*sx)/2; py=(boxHeight-height*sy)/2
End Function
