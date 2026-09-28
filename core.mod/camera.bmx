Rem
bbdoc: A camera mapping world coordinates into the current virtual drawing surface.
about: The world position x,y appears at offsetX,offsetY. Zoom is positive; positive rotation turns the camera clockwise (the world counterclockwise). SetCamera takes a snapshot.
End Rem
Type TCamera2D
 Field x:Float,y:Float
 Field offsetX:Float,offsetY:Float
 Field zoom:Float=1,rotation:Float
 Method Validate()
  If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(offsetX) Or IsInf(offsetX) Or IsNan(offsetY) Or IsInf(offsetY) Or IsNan(rotation) Or IsInf(rotation) Or IsNan(zoom) Or IsInf(zoom) Or zoom<=0 Then Throw "Max2D: camera values must be finite and zoom positive"
 End Method
 Method Copy:TCamera2D()
  Local result:TCamera2D=New TCamera2D
  result.x=x; result.y=y; result.offsetX=offsetX; result.offsetY=offsetY
  result.zoom=zoom; result.rotation=rotation
  Return result
 End Method
 Rem
 bbdoc: Changes zoom while keeping the world point at the supplied virtual coordinate stationary.
 about: This edits the camera object; call SetCamera again to apply it. Invalid inputs leave the camera unchanged.
 End Rem
 Method ZoomAt(newZoom:Float,viewX:Float,viewY:Float)
  Validate()
  If IsNan(viewX) Or IsInf(viewX) Or IsNan(viewY) Or IsInf(viewY) Then Throw "Max2D: camera anchor must be finite"
  Local candidate:TCamera2D=Copy()
  candidate.zoom=newZoom
  candidate.Validate()
  Local beforeX:Float,beforeY:Float,afterX:Float,afterY:Float
  VirtualToWorld(viewX,viewY,beforeX,beforeY)
  candidate.VirtualToWorld(viewX,viewY,afterX,afterY)
  candidate.x:+beforeX-afterX; candidate.y:+beforeY-afterY
  candidate.Validate()
  x=candidate.x; y=candidate.y; zoom=candidate.zoom
 End Method
 Rem
 bbdoc: Returns the world-space corners of a virtual rectangle as eight xy values, ordered top-left, top-right, bottom-right, bottom-left.
 about: The rectangle can describe the full view or a clipped viewport. No window or render target is required.
 End Rem
 Method WorldCorners:Float[](viewX:Float,viewY:Float,width:Float,height:Float)
  Validate()
  If IsNan(viewX) Or IsInf(viewX) Or IsNan(viewY) Or IsInf(viewY) Or IsNan(width) Or IsInf(width) Or IsNan(height) Or IsInf(height) Or width<0 Or height<0 Then Throw "Max2D: camera rectangle must be finite with nonnegative dimensions"
  Local result:Float[]=[viewX,viewY,viewX+width,viewY,viewX+width,viewY+height,viewX,viewY+height]
  For Local i:Int=0 Until 8 Step 2
   VirtualToWorld(result[i],result[i+1],result[i],result[i+1])
  Next
  Return result
 End Method
 Method WorldToVirtual(worldX:Float,worldY:Float,viewX:Float Var,viewY:Float Var)
  Validate()
  Local c:Double=Cos(rotation),s:Double=Sin(rotation)
  Local dx:Double=Double(worldX)-x,dy:Double=Double(worldY)-y
  viewX=Float(offsetX+zoom*(c*dx+s*dy))
  viewY=Float(offsetY+zoom*(-s*dx+c*dy))
 End Method
 Method VirtualToWorld(viewX:Float,viewY:Float,worldX:Float Var,worldY:Float Var)
  Validate()
  Local c:Double=Cos(rotation),s:Double=Sin(rotation)
  Local dx:Double=(Double(viewX)-offsetX)/zoom,dy:Double=(Double(viewY)-offsetY)/zoom
  worldX=Float(x+c*dx-s*dy); worldY=Float(y+s*dx+c*dy)
 End Method
End Type

Rem
bbdoc: A snapshot combining a camera with the window's input and presentation mapping.
End Rem
Type TMax2DCameraInput
 Field mapping:TMax2DInputMapping
 Field camera:TCamera2D
 Method WindowToWorld:Int(x:Float,y:Float,worldX:Float Var,worldY:Float Var,checkViewport:Int=False)
  Local vx:Float,vy:Float
  Local inside:Int=mapping.WindowToVirtual(x,y,vx,vy,checkViewport)
  If Not mapping.valid Then
   worldX=0; worldY=0
   Return False
  End If
  camera.VirtualToWorld(vx,vy,worldX,worldY)
  Return inside
 End Method
 Method WorldToWindow:Int(x:Float,y:Float,windowX:Float Var,windowY:Float Var)
  Local vx:Float,vy:Float
  camera.WorldToVirtual(x,y,vx,vy)
  Return mapping.VirtualToWindow(vx,vy,windowX,windowY)
 End Method
End Type

Rem
bbdoc: Restores the owning canvas's drawing state when closed, including from a Using block.
about: Close is idempotent. Closing an outer scope unwinds any still-open inner saves. No finalizer performs graphics work.
End Rem
Type TMax2DStateScope Implements ICloseable
 Field canvas:TMax2DGraphics
 Field entry:TMax2DSavedState
 Method Close()
  If Not canvas Then Return
  Local owner:TMax2DGraphics=canvas
  canvas=Null
  If owner.context.closed Or Not entry.active Then
   entry=Null
   Return
  End If
  Local previous:TMax2DGraphics=TMax2DGraphics.selected
  Try
   If previous And previous<>owner Then previous.context.Flush()
   owner.context.Activate()
   While Not owner.saved.IsEmpty()
    Local item:TMax2DSavedState=TMax2DSavedState(owner.saved.RemoveLast())
    item.active=False
    If item=entry Then Exit
   Wend
   owner.RestoreState(entry)
  Finally
   entry=Null
   If previous And previous<>owner And Not previous.context.closed Then previous.context.Activate()
  End Try
 End Method
End Type
