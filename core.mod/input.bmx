
Rem
bbdoc: A snapshot of the window-to-scene mapping, independent of subsequent drawing state changes.
about: Capture before switching to native overlays. Window input always maps to the window view, even while drawing into a render image.
End Rem
Type TMax2DInputMapping

	Rem
	bbdoc: Whether this result contains a usable mapping or source range.
	End Rem
	Field valid:Int

	Rem
	bbdoc: Width of the captured window input coordinate range.
	End Rem
	Field windowWidth:Int

	Rem
	bbdoc: Height of the captured window input coordinate range.
	End Rem
	Field windowHeight:Int

	Rem
	bbdoc: Destination width in native pixels.
	End Rem
	Field pixelWidth:Int

	Rem
	bbdoc: Destination height in native pixels.
	End Rem
	Field pixelHeight:Int

	Rem
	bbdoc: Horizontal scale factor.
	End Rem
	Field scaleX:Float

	Rem
	bbdoc: Vertical scale factor.
	End Rem
	Field scaleY:Float

	Rem
	bbdoc: Horizontal native-pixel offset of the captured scene.
	End Rem
	Field offsetX:Int

	Rem
	bbdoc: Vertical native-pixel offset of the captured scene.
	End Rem
	Field offsetY:Int

	Rem
	bbdoc: Captured displayed scene width in native pixels.
	End Rem
	Field viewWidth:Int

	Rem
	bbdoc: Captured displayed scene height in native pixels.
	End Rem
	Field viewHeight:Int

	Rem
	bbdoc: Horizontal start of the captured scene-relative pixel viewport.
	End Rem
	Field clipX:Int

	Rem
	bbdoc: Vertical start of the captured scene-relative pixel viewport.
	End Rem
	Field clipY:Int

	Rem
	bbdoc: Captured viewport width in native pixels.
	End Rem
	Field clipWidth:Int

	Rem
	bbdoc: Captured viewport height in native pixels.
	End Rem
	Field clipHeight:Int

	Rem
	bbdoc: Captures a virtual view and window/input dimensions for later coordinate conversion.
	param: Virtual dimensions, presentation and clipping settings.
	param: Width of the window's input coordinate range.
	param: Height of the window's input coordinate range.
	param: Width of the drawable surface in native pixels.
	param: Height of the drawable surface in native pixels.
	End Rem
 Function Create:TMax2DInputMapping(view:TMax2DView,windowWidth:Int,windowHeight:Int,pixelWidth:Int,pixelHeight:Int)
  Local result:TMax2DInputMapping=New TMax2DInputMapping
  result.windowWidth=windowWidth; result.windowHeight=windowHeight
  result.pixelWidth=pixelWidth; result.pixelHeight=pixelHeight
  If windowWidth<=0 Or windowHeight<=0 Or pixelWidth<=0 Or pixelHeight<=0 Then Return result
  If Not view Or view.width<=0 Or view.height<=0 Then Return result
  view.MapOutput(pixelWidth,pixelHeight,result.scaleX,result.scaleY,result.offsetX,result.offsetY,result.viewWidth,result.viewHeight)
  If result.scaleX<=0 Or result.scaleY<=0 Then Return result
  result.clipX=Floor(view.x*result.scaleX); result.clipY=Floor(view.y*result.scaleY)
  If view.w>0 Then result.clipWidth=Ceil((view.x+view.w)*result.scaleX)-result.clipX
  If view.h>0 Then result.clipHeight=Ceil((view.y+view.h)*result.scaleY)-result.clipY
  If view.fullClip Then
   result.clipX=0; result.clipY=0; result.clipWidth=result.viewWidth; result.clipHeight=result.viewHeight
  End If
  result.valid=True
  Return result
 End Function

 Rem
 bbdoc: Converts a window point and returns whether it lies inside the scene (and optionally the clipping viewport).
	param: Horizontal window input coordinate.
	param: Vertical window input coordinate.
	param: Receives horizontal virtual coordinate.
	param: Receives vertical virtual coordinate.
	param: Whether to require the point to be inside the clipping viewport as well as the scene.
 about: Outside points are converted without clamping. Invalid mappings return False and zero coordinates.
 End Rem
 Method WindowToVirtual:Int(x:Float,y:Float,virtualX:Float Var,virtualY:Float Var,checkViewport:Int=False)
  virtualX=0; virtualY=0
  If Not valid Then Return False
  Local px:Float=x*pixelWidth/windowWidth-offsetX,py:Float=y*pixelHeight/windowHeight-offsetY
  virtualX=px/scaleX; virtualY=py/scaleY
  If x<0 Or y<0 Or x>=windowWidth Or y>=windowHeight Then Return False
  If px<0 Or py<0 Or px>=viewWidth Or py>=viewHeight Then Return False
  If checkViewport Then
   If px<clipX Or py<clipY Or px>=clipX+clipWidth Or py>=clipY+clipHeight Then Return False
  End If
  Return True
 End Method

 Rem
 bbdoc: Converts a virtual point to window coordinates. Returns False only if this mapping is invalid.
	param: Horizontal virtual screen coordinate.
	param: Vertical virtual screen coordinate.
	param: Receives horizontal window input coordinate.
	param: Receives vertical window input coordinate.
 End Rem
 Method VirtualToWindow:Int(x:Float,y:Float,windowX:Float Var,windowY:Float Var)
  windowX=0; windowY=0
  If Not valid Then Return False
  windowX=(offsetX+x*scaleX)*windowWidth/pixelWidth
  windowY=(offsetY+y*scaleY)*windowHeight/pixelHeight
  Return True
 End Method

	Rem
	bbdoc: Converts a window-space movement vector into virtual units.
	param: Horizontal displacement.
	param: Vertical displacement.
	param: Receives horizontal displacement in virtual units.
	param: Receives vertical displacement in virtual units.
	End Rem
 Method WindowDeltaToVirtual:Int(dx:Float,dy:Float,virtualDX:Float Var,virtualDY:Float Var)
  virtualDX=0; virtualDY=0
  If Not valid Then Return False
  virtualDX=dx*pixelWidth/windowWidth/scaleX
  virtualDY=dy*pixelHeight/windowHeight/scaleY
  Return True
 End Method

End Type

Rem
bbdoc: An affine transform captured for a particular draw position and handle.
about: Local coordinates are before handle subtraction. Inversion handles rotation, scale, reflection and shear; collapsed transforms return False.
End Rem
Type TMax2DDrawTransform

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
	bbdoc: Captures the complete affine transform for a draw position and local handle.
	param: Drawing state to inspect or apply.
	param: Horizontal position at which the object will be drawn.
	param: Vertical position at which the object will be drawn.
	param: Horizontal handle offset in local coordinates.
	param: Vertical handle offset in local coordinates.
	End Rem
 Function Create:TMax2DDrawTransform(state:TMax2DState,drawX:Float,drawY:Float,handleX:Float,handleY:Float)
  Local result:TMax2DDrawTransform=New TMax2DDrawTransform
  result.xx=state.ix; result.xy=state.iy; result.yx=state.jx; result.yy=state.jy
  result.tx=drawX+Double(state.originX)-handleX*result.xx-handleY*result.xy
  result.ty=drawY+Double(state.originY)-handleX*result.yx-handleY*result.yy
  Local xx:Double=result.xx,xy:Double=result.xy,yx:Double=result.yx,yy:Double=result.yy,tx:Double=result.tx,ty:Double=result.ty
  result.xx=state.coordXX*xx+state.coordXY*yx; result.xy=state.coordXX*xy+state.coordXY*yy
  result.yx=state.coordYX*xx+state.coordYY*yx; result.yy=state.coordYX*xy+state.coordYY*yy
  result.tx=state.coordXX*tx+state.coordXY*ty+state.coordTX
  result.ty=state.coordYX*tx+state.coordYY*ty+state.coordTY
  xx=result.xx;xy=result.xy;yx=result.yx;yy=result.yy;tx=result.tx;ty=result.ty
  result.xx=state.cameraXX*xx+state.cameraXY*yx; result.xy=state.cameraXX*xy+state.cameraXY*yy
  result.yx=state.cameraYX*xx+state.cameraYY*yx; result.yy=state.cameraYX*xy+state.cameraYY*yy
  result.tx=state.cameraXX*tx+state.cameraXY*ty+state.cameraTX
  result.ty=state.cameraYX*tx+state.cameraYY*ty+state.cameraTY
  Return result
 End Function

	Rem
	bbdoc: Transforms local drawing coordinates into virtual screen coordinates.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Receives horizontal virtual coordinate.
	param: Receives vertical virtual coordinate.
	End Rem
 Method LocalToVirtual(x:Float,y:Float,virtualX:Float Var,virtualY:Float Var)
  virtualX=Float(x*xx+y*xy+tx); virtualY=Float(x*yx+y*yy+ty)
 End Method

	Rem
	bbdoc: Inverts the captured drawing transform, returning False for a collapsed transform.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Receives horizontal local drawing coordinate.
	param: Receives vertical local drawing coordinate.
	End Rem
 Method VirtualToLocal:Int(x:Float,y:Float,localX:Float Var,localY:Float Var)
  localX=0; localY=0
  Local determinant:Double=xx*yy-xy*yx
  If determinant=0 Then Return False
  Local px:Double=Double(x)-tx,py:Double=Double(y)-ty
  localX=Float((px*yy-py*xy)/determinant)
  localY=Float((py*xx-px*yx)/determinant)
  Return True
 End Method

End Type
