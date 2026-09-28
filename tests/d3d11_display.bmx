SuperStrict
Framework Max2D.D3D11Max2D
Import BRL.StandardIO
Import "d3d11_display.cpp"
Extern "C"
 Function m2d11_test_dpi_aware:Int()
 Function m2d11_test_size(window:Byte Ptr,width:Int Var,height:Int Var)
 Function m2d11_test_borderless:Int(window:Byte Ptr)
 Function m2d11_test_desktop:Int(window:Byte Ptr,width:Int Var,height:Int Var,hertz:Int Var)
 Function m2d11_test_focus:Int(window:Byte Ptr)
End Extern
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function EnterFullscreen(window:TD3D11Graphics,mode:TGraphicsMode)
 For Local attempt:Int=0 Until 100
  Local activated:Int=m2d11_test_focus(window._hwnd);PollSystem()
  If attempt=0 Then Print "Entry focus acquired: "+activated
  Try
   SetFullscreen(True,mode.width,mode.height,mode.hertz)
   Return
  Catch error:Object
   Local message:String=error.ToString().ToLower()
   If Not message.Contains("0x887a0022") And Not message.Contains("0x887a0025") Then Throw error
   If attempt=99 Then Throw error
  End Try
  Delay(20)
 Next
End Function
Try
 If AppArgs.Length>1 And AppArgs[1]="aware" Then Check(m2d11_test_dpi_aware(),"Set test process DPI awareness")
 Local displays:TD3D11Display[]=D3D11Displays()
 Check(displays.Length>0,"Attached DXGI displays")
 Local modes:TGraphicsMode[]=GraphicsModes()
 Check(modes.Length>0,"Primary fullscreen modes")
 Print "Displays: "+displays.Length+", modes: "+modes.Length
 Local mode:TGraphicsMode=modes[0]
 For Local candidate:TGraphicsMode=EachIn modes
  If candidate.width=displays[0].width And candidate.height=displays[0].height Then mode=candidate;Exit
 Next
 Check(Graphics(320,240,0,0)<>Null,"Window creation")
 Check(Max2DSupportsFullscreen() And Max2DSupportsBorderlessFullscreen(),"Shared fullscreen capabilities")
 Check(GetWindowMode()=MAX2D_WINDOWED,"Initial shared window mode")
 Local context:TD3D11Max2DContext=TD3D11Max2DContext(TMax2DGraphics.selected.context)
 Local window:TD3D11Graphics=TD3D11Graphics(context.graphics)
 m2d11_test_focus(window._hwnd);PollSystem()
 Print "Initial: "+GraphicsWidth()+"x"+GraphicsHeight()+", native "+NativeResolutionWidth()+"x"+NativeResolutionHeight()
 Local image:TRenderImage=CreateRenderImage(8,8)
 SetRenderImage(image);SetClsColor(0,255,0);Cls;SetRenderImage(Null)
 Local physicalWidth:Int,physicalHeight:Int
 m2d11_test_size(window._hwnd,physicalWidth,physicalHeight)
 Check(physicalWidth=640 And physicalHeight=480 Or bmx_d3d11_window_dpi(window._hwnd)<>192,"200 percent DPI initial physical size")
 Local generation:Int=window.generation
 Local desktopWidth:Int,desktopHeight:Int,desktopHertz:Int
 Check(m2d11_test_desktop(window._hwnd,desktopWidth,desktopHeight,desktopHertz),"Desktop mode query")
 For Local pass:Int=0 Until 2
  SetBorderlessFullscreen(True)
  Check(GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN And window._borderless And GraphicsDepth()=0 And m2d11_test_borderless(window._hwnd),"Borderless covers monitor without chrome")
  Local dw:Int,dh:Int,hz:Int
  Check(m2d11_test_desktop(window._hwnd,dw,dh,hz),"Borderless desktop mode query")
  Check(dw=desktopWidth And dh=desktopHeight And hz=desktopHertz,"Borderless preserves desktop mode")
  SetClsColor(0,0,0);Cls;SetColor(255,255,255);SetBlend(SOLIDBLEND);DrawImage(image,0,0)
  Check((GrabPixmap(0,0,1,1).ReadPixel(0,0)&$ffffff)=$00ff00,"Render image survives borderless switch")
  Local biw:Int,bih:Int,bvx:Float,bvy:Float
  context.NativeInputSize(biw,bih)
  WindowToVirtual(biw/2.0,bih/2.0,bvx,bvy)
  Check(Abs(bvx-GraphicsWidth()/2.0)<0.01 And Abs(bvy-GraphicsHeight()/2.0)<0.01,"Borderless mouse mapping")
  ShowWindow(window._hwnd,SW_MINIMIZE);PollSystem()
  Check(Not window.Ready(),"Minimized borderless skips presentation")
  ShowWindow(window._hwnd,SW_RESTORE);m2d11_test_focus(window._hwnd);PollSystem()
  Check(window.Ready() And m2d11_test_borderless(window._hwnd),"Borderless restores after minimize")
  Local rejectedBorderlessResize:Int
  Local bw:Int=GraphicsWidth(),bh:Int=GraphicsHeight()
  Try
   GraphicsResize(100,100)
  Catch error:Object
   rejectedBorderlessResize=True
  End Try
  Check(rejectedBorderlessResize And GraphicsWidth()=bw And GraphicsHeight()=bh,"Borderless rejects resize without changing settings")
  SetBorderlessFullscreen(False)
  Check(GraphicsWidth()=320 And GraphicsHeight()=240,"Borderless restores drawable size")
  If pass=0 Then SetBorderlessFullscreen(True)

  EnterFullscreen(window,mode)
  Local fullWidth:Int,fullHeight:Int
  m2d11_test_size(window._hwnd,fullWidth,fullHeight)
  Print "Fullscreen requested "+mode.width+"x"+mode.height+", graphics "+GraphicsWidth()+"x"+GraphicsHeight()
  Check(GetWindowMode()=MAX2D_FULLSCREEN And GraphicsDepth()=32 And GraphicsWidth()=mode.width And GraphicsHeight()=mode.height,"Fullscreen settings")
  Local invalidResize:Int
  Try
   GraphicsResize(13,17)
  Catch error:Object
   invalidResize=True
  End Try
  Check(invalidResize And GraphicsWidth()=mode.width And GraphicsHeight()=mode.height,"Rejected resize restores cached dimensions")
  SetClsColor(0,0,0);Cls;SetColor(255,255,255);SetBlend(SOLIDBLEND);DrawImage(image,0,0)
  Check((GrabPixmap(0,0,1,1).ReadPixel(0,0)&$ffffff)=$00ff00,"Render image survives fullscreen switch")
  Flip(0)
  Check(window.generation=generation,"Switching does not replace device")
?d3d11_recovery_test
  D3D11TestRemoved=True
  Cls()
  Check(window.generation=generation+1 And GraphicsDepth()=32,"Fullscreen device replacement")
  generation=window.generation
  SetRenderImage(image);SetClsColor(0,255,0);Cls;SetRenderImage(Null)
?
  ShowWindow(window._hwnd,SW_MINIMIZE);PollSystem()
  Check(Not window.Ready(),"Minimized fullscreen skips presentation")
  ShowWindow(window._hwnd,SW_RESTORE);m2d11_test_focus(window._hwnd);PollSystem()
  Local ready:Int
  For Local attempt:Int=0 Until 100
   If window.Ready() Then ready=True;Exit
   Delay(10);PollSystem()
  Next
  Check(ready,"Fullscreen available after restore")
  Cls;Flip(0)
  If pass=1 Then
   SetBorderlessFullscreen(True)
   Check(GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN And window._borderless And GraphicsDepth()=0 And m2d11_test_borderless(window._hwnd),"Exclusive to borderless")
   Check(m2d11_test_desktop(window._hwnd,dw,dh,hz),"Restored desktop query")
   Check(dw=desktopWidth And dh=desktopHeight And hz=desktopHertz,"Exclusive to borderless restores desktop mode")
?d3d11_recovery_test
   D3D11TestRemoved=True
   Cls()
   Check(window.generation=generation+1 And window._borderless And m2d11_test_borderless(window._hwnd),"Borderless recovery")
   generation=window.generation
   SetRenderImage(image);SetClsColor(0,255,0);Cls;SetRenderImage(Null)
?
   SetBorderlessFullscreen(False)
  Else
   SetFullscreen(False)
  End If
  Local restoredWidth:Int,restoredHeight:Int
  m2d11_test_size(window._hwnd,restoredWidth,restoredHeight)
  Print "Restored: "+GraphicsWidth()+"x"+GraphicsHeight()+", depth "+GraphicsDepth()
  Check(GraphicsDepth()=0 And GraphicsWidth()=320 And GraphicsHeight()=240,"Window geometry restored")
  Check(window.generation=generation,"Switching does not replace device")
  Check(restoredWidth=physicalWidth And restoredHeight=physicalHeight,"Physical window size restored")
  SetClsColor(0,0,0);Cls;SetColor(255,255,255);DrawImage(image,300,200)
  Check((GrabPixmap(300,200,1,1).ReadPixel(0,0)&$ffffff)=$00ff00,"Original drawing resolution retained")
  Local inputWidth:Int,inputHeight:Int,vx:Float,vy:Float
  context.NativeInputSize(inputWidth,inputHeight)
  WindowToVirtual(inputWidth/2.0,inputHeight/2.0,vx,vy)
  Check(Abs(vx-160)<0.01 And Abs(vy-120)<0.01,"Mouse mapping retains original virtual coordinates")
 Next
 Local rejected:Int
 Try
  SetFullscreen(True,13,17,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And GraphicsDepth()=0,"Unsupported mode rejected without leaving windowed mode")
 m2d11_test_focus(window._hwnd)
 EndGraphics()
 Check(Graphics(mode.width,mode.height,32,mode.hertz)<>Null,"Conventional fullscreen Graphics: "+String.FromUTF8String(bmx_d3d11_error()))
 Cls;Flip(0);EndGraphics()
 Print "Max2D D3D11 display/fullscreen tests passed"
Catch error:Object
 EndGraphics()
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
