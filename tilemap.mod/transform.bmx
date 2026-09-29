
Rem
bbdoc: Affine artwork transform relative to the original canvas top-left.
about: Diagonal exchanges axes with bottom-left anchoring. Rotation flags combine to 60/120/180 degrees clockwise about the canvas centre, after source-axis flips.
End Rem
Struct STileImageTransform

	Rem
	bbdoc: Affine coefficient mapping input x to output x.
	End Rem
	Field xx:Float

	Rem
	bbdoc: Affine coefficient mapping input y to output x.
	End Rem
	Field xy:Float

	Rem
	bbdoc: Affine coefficient mapping input x to output y.
	End Rem
	Field yx:Float

	Rem
	bbdoc: Affine coefficient mapping input y to output y.
	End Rem
	Field yy:Float

	Rem
	bbdoc: Horizontal affine translation.
	End Rem
	Field tx:Float

	Rem
	bbdoc: Vertical affine translation.
	End Rem
	Field ty:Float
End Struct

Rem
bbdoc: Rejects unsupported combinations of tile transformation flags.
param: Tile reflection and rotation flags.
End Rem
Function ValidateTileFlip(flip:ETileFlip)
	If Int(flip) & ~31 Then Throw "Max2D tilemap: unsupported tile transformation"
	If (flip & ETileFlip.Diagonal)<>ETileFlip.None And (flip & (ETileFlip.Rotate60|ETileFlip.Rotate120))<>ETileFlip.None Then Throw "Max2D tilemap: diagonal and rotation flags cannot be combined"
End Function

Rem
bbdoc: Builds the affine transform for reflected or rotated tile artwork.
param: Width of the rectangle or drawing surface.
param: Height of the rectangle or drawing surface.
param: Tile reflection and rotation flags.
End Rem
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

Rem
bbdoc: Gets the bounding rectangle of transformed tile artwork.
param: Width of the rectangle or drawing surface.
param: Height of the rectangle or drawing surface.
param: Tile reflection and rotation flags.
param: Receives left boundary of the region.
param: Receives inclusive top of the visible band in paragraph-local coordinates.
param: Receives right boundary of the region.
param: Receives exclusive bottom of the visible band in paragraph-local coordinates.
End Rem
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

Rem
bbdoc: Calculates scale and centring offsets for artwork fitted into a destination box.
param: Width of the rectangle or drawing surface.
param: Height of the rectangle or drawing surface.
param: Destination box width in logical drawing units.
param: Destination box height in logical drawing units.
param: Stretch or PreserveAspectFit artwork placement.
param: Receives horizontal artwork scale factor.
param: Receives vertical artwork scale factor.
param: Receives horizontal centring offset within the destination box.
param: Receives vertical centring offset within the destination box.
End Rem
Function TileImageFit(width:Float,height:Float,boxWidth:Float,boxHeight:Float,mode:ETileFillMode,sx:Float Var,sy:Float Var,px:Float Var,py:Float Var)
	sx=boxWidth/width; sy=boxHeight/height
	If mode=ETileFillMode.PreserveAspectFit Then
		sx=Min(sx,sy); sy=sx
	Else If mode<>ETileFillMode.Stretch Then
		Throw "Max2D tilemap: invalid fill mode"
	End If
	px=(boxWidth-width*sx)/2; py=(boxHeight-height*sy)/2
End Function
