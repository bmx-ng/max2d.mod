SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
?win32
Import "d3d11_display.cpp"
Extern "C"
 Function m2d11_test_size(window:Byte Ptr,width:Int Var,height:Int Var)
End Extern
?
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function CheckMapping()
	Local context:TMax2DContext=TMax2DGraphics.Current().context
 Local iw:Int,ih:Int,vx:Float,vy:Float
 context.NativeInputSize(iw,ih)
 WindowToVirtual(iw/2.0,ih/2.0,vx,vy)
 Check(Abs(vx-160)<0.01 And Abs(vy-120)<0.01,"Virtual mouse mapping")
End Function
Try
 Check(Graphics(640,480)<>Null,"Create window")
 Check(Max2DSupportsFullscreen() And Max2DSupportsBorderlessFullscreen(),"Capabilities")
 Check(GetWindowMode()=MAX2D_WINDOWED,"Initial window mode")
	Local context:TMax2DContext=TMax2DGraphics.Current().context
?max2d_sdlgpu
	Local device:Byte Ptr=TSDLGPUMax2DContext(context).native
?Not max2d_sdlgpu
	Local renderer:Byte Ptr=TSDLRenderContext(context).renderer.rendererPtr
?
 Local scale:Float=TSDLGraphics(context.graphics)._context.WindowScale()
 Local rawWidth:Int,rawHeight:Int
 context.NativeInputSize(rawWidth,rawHeight)
 Check(rawWidth=Int(Floor(640*scale+0.5)) And rawHeight=Int(Floor(480*scale+0.5)),"Initial logical window size")
 Print "Window 640x480 logical, SDL client "+rawWidth+"x"+rawHeight+", scale "+scale
?win32
 Local physicalWidth:Int,physicalHeight:Int
 m2d11_test_size(TSDLGraphics(context.graphics)._context.window.GetHandle(),physicalWidth,physicalHeight)
 Check(physicalWidth=rawWidth And physicalHeight=rawHeight,"DPI-aware SDL physical client size")
?
 GraphicsResize(320,240)
 Check(GraphicsWidth()=320 And GraphicsHeight()=240,"Logical resize settings")
 context.NativeInputSize(rawWidth,rawHeight)
 Check(rawWidth=Int(Floor(320*scale+0.5)) And rawHeight=Int(Floor(240*scale+0.5)),"Logical resize native extent")
 PollSystem()
 Check(GraphicsWidth()=320 And GraphicsHeight()=240,"Resize events do not rescale the window twice")
 GraphicsResize(640,480)
 Local pw:Int,ph:Int
 context.NativeOutputSize(pw,ph)
 Local image:TRenderImage=CreateRenderImage(16,16)
 SetRenderImage(image);SetClsColor(0,255,0);Cls
 Local rejected:Int
 Try
  SetBorderlessFullscreen(True)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And GetWindowMode()=MAX2D_WINDOWED,"Window target required")
 SetRenderImage(Null)
 SetVirtualResolution(320,240,VIRTUAL_LETTERBOX)
 Local modes:TGraphicsMode[]=GraphicsModes()
 Local mode:TGraphicsMode
 For Local candidate:TGraphicsMode=EachIn modes
  If candidate.width>=640 And candidate.width<=1920 And candidate.height>=480 Then mode=candidate;Exit
 Next
 Check(mode<>Null,"Exclusive mode available")
 For Local pass:Int=0 Until 2
  SetBorderlessFullscreen(True)
  Check(GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN And GraphicsDepth()=0,"Borderless state")
  Local bw:Int=GraphicsWidth(),bh:Int=GraphicsHeight(),bx:Int=GraphicsX(),by:Int=GraphicsY()
  rejected=False
  Try
   GraphicsResize(13,17)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And GraphicsWidth()=bw And GraphicsHeight()=bh,"Rejected resize preserves cache")
  rejected=False
  Try
   GraphicsPosition(bx+50,by+50)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And GraphicsX()=bx And GraphicsY()=by,"Rejected position preserves cache")
  CheckMapping()
  PollSystem()
  CheckMapping()
  rejected=False
  Try
   SetFullscreen(True,13,17)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN,"Invalid mode preserves borderless")
  SetFullscreen(True,mode.width,mode.height,mode.hertz)
  Check(GetWindowMode()=MAX2D_FULLSCREEN And GraphicsDepth()>0,"Exclusive state")
  CheckMapping()
  SetBorderlessFullscreen(False)
  Check(GetWindowMode()=MAX2D_FULLSCREEN,"Disabling borderless leaves exclusive unchanged")
  If pass Then
   SetBorderlessFullscreen(True)
   Check(GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN,"Exclusive to borderless")
   SetBorderlessFullscreen(False)
  Else
   SetFullscreen(False)
  End If
  PollSystem()
  Check(GetWindowMode()=MAX2D_WINDOWED And GraphicsWidth()=640 And GraphicsHeight()=480,"Restored window and cache")
  Local rw:Int,rh:Int
  context.NativeOutputSize(rw,rh)
  Check(rw=pw And rh=ph,"Original drawable size")
  CheckMapping()
?max2d_sdlgpu
		Check(TSDLGPUMax2DContext(context).native=device,"GPU context retained")
?Not max2d_sdlgpu
		Check(TSDLRenderContext(context).renderer.rendererPtr=renderer,"Renderer retained")
?
  SetClsColor(0,0,0);Cls;SetColor(255,255,255);SetBlend(SOLIDBLEND);DrawImage(image,0,0)
  Check((GrabPixmap(1,1,1,1).ReadPixel(0,0)&$ffffff)=$00ff00,"Render image retained")
  Flip(0)
 Next
 EndGraphics()
 Print "Max2D SDL3 shared fullscreen tests passed"
Catch error:Object
 EndGraphics()
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
