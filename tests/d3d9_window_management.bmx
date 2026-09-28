SuperStrict
Framework Max2D.D3D9Max2D
Import BRL.StandardIO
Import "d3d9_borderless.c"
Extern "C"
 Function test_d9_covers:Int(hwnd:Byte Ptr)
End Extern
Global losses:Int,resets:Int
Function Lost(obj:Object)
 losses:+1
End Function
Function ResetDone(obj:Object)
 resets:+1
End Function
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function CheckNativeText:TPixmap(reference:TPixmap=Null)
 PushMax2DState()
 SetNativeResolution()
 SetClsColor(0,0,0);Cls
 SetColor(255,255,255)
 DrawText("Native text 012345",24,24)
 Local actual:TPixmap=GrabPixmap(24,24,200,16)
 PopMax2DState()
 If reference Then
  For Local y:Int=0 Until actual.height
   For Local x:Int=0 Until actual.width
    Check(actual.ReadPixel(x,y)=reference.ReadPixel(x,y),"Native text pixels retained across window changes")
   Next
  Next
 End If
 Return actual
End Function
Try
 Local canvas:TMax2DGraphics=TMax2DGraphics(Graphics(320,240,0,0))
 Local g:TD3D9Graphics=TD3D9Graphics(canvas.context.graphics)
 Local w:Int,h:Int,d:Int,hz:Int,f:Long,x:Int,y:Int
 canvas.GetSettings(w,h,d,hz,f,x,y)
 Local originalX:Int=x,originalY:Int=y
 g.AddDeviceLostCallback(Lost,Null);g.AddDeviceResetCallback(ResetDone,Null)
 Local target:TRenderImage=CreateRenderImage(16,16,FILTEREDIMAGE|MIPMAPPEDIMAGE)
 SetRenderImage(target);SetClsColor(80,160,240,0.5);Cls
 Local before:UInt=GrabPixmap(0,0,1,1).ReadPixel(0,0)
 SetRenderImage(Null)
 Local pixmap:TPixmap=CreatePixmap(8,8,PF_RGBA8888);pixmap.ClearPixels($ffff0000)
 Local image:TImage=LoadImage(pixmap)
 SetVirtualResolution(320,240,VIRTUAL_LETTERBOX)
 Local textReference:TPixmap=CheckNativeText()
 Check(D3D9Max2DDriver().CanResize(),"Resize capability")
 For Local pass:Int=0 Until 3
  Local width:Int=400,height:Int=300
  If pass=1 Then width=640;height=480
  If pass=2 Then width=320;height=240
  GraphicsResize(width,height)
  GraphicsResize(width,height) ' Same size does not reset the device.
  originalX=80+pass*20;originalY=100+pass*20
  GraphicsPosition(originalX,originalY)
  canvas.GetSettings(w,h,d,hz,f,x,y)
  Check(w=width And h=height And x=originalX And y=originalY,"Resized geometry")
  Check(GraphicsWidth()=width And GraphicsHeight()=height,"Resized cached dimensions")
  SetRenderImage(target)
  Check(GrabPixmap(0,0,1,1).ReadPixel(0,0)=before,"Resize preserves render image")
  SetRenderImage(Null)
  SetClsColor(24,48,72);Cls
  Check((GrabPixmap(width-1,height-1,1,1).ReadPixel(0,0)&$ffffff)=$183048,"Backbuffer covers resized window")
  CheckNativeText(textReference)
  SetRenderImage(target);SetClsColor(80+pass*20,160,240,0.5);Cls
  before=GrabPixmap(0,0,1,1).ReadPixel(0,0)
  SetRenderImage(Null)
  SetBorderlessFullscreen(True);SetBorderlessFullscreen(True)
  Check(GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN And test_d9_covers(g._hwnd),"Monitor coverage")
  Check(GraphicsDepth()=0 And GraphicsHertz()=0,"Display settings")
  Local savedW:Int=GraphicsWidth(),savedH:Int=GraphicsHeight(),rejected:Int
  Try
   GraphicsResize(200,100)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And GraphicsWidth()=savedW And GraphicsHeight()=savedH,"Rejected resize refreshes cached settings")
  rejected=False
  Try
   GraphicsPosition(10,10)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And test_d9_covers(g._hwnd),"Reject borderless movement")
  Local vx:Float,vy:Float,wx:Float,wy:Float
  VirtualToWindow(160,120,wx,wy);WindowToVirtual(wx,wy,vx,vy)
  Check(Abs(vx-160)<0.001 And Abs(vy-120)<0.001,"Virtual input round trip")
  SetClsColor(16,32,64);Cls
  Check((GrabPixmap(NativeResolutionWidth()/2,NativeResolutionHeight()/2,1,1).ReadPixel(0,0)&$ffffff)=$102040,"Fullscreen backbuffer")
  CheckNativeText(textReference)
  SetRenderImage(target)
  Check(GrabPixmap(0,0,1,1).ReadPixel(0,0)=before,"Render image contents retained")
  SetRenderImage(Null)
  DrawImage(image,0,0);DrawImage(target,32,32);Flip(1)
  If pass=1 Then SetFullscreen(False) Else SetBorderlessFullscreen(False)
  canvas.GetSettings(w,h,d,hz,f,x,y)
  Check(GetWindowMode()=MAX2D_WINDOWED And w=width And h=height And x=originalX And y=originalY,"Window restored")
  Check(losses=(pass+1)*3 And resets=losses,"Existing reset callbacks once per transition")
  SetRenderImage(target)
  Check(GrabPixmap(0,0,1,1).ReadPixel(0,0)=before,"Return preserves target")
  SetRenderImage(Null)
  Cls;DrawImage(image,10,10)
  Check((GrabPixmap(Int(11*width/320.0),Int(11*height/240.0),1,1).ReadPixel(0,0)&$ffffff)=$ff0000,"Managed texture retained")
  Flip(1)
  CheckNativeText(textReference)
 Next
 SetBorderlessFullscreen(True)
 EndGraphics()
 Print "D3D9 window-management tests passed"
Catch error:Object
 EndGraphics()
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
