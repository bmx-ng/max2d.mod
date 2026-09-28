SuperStrict
Framework Max2D.D3D9Max2D
Import BRL.StandardIO
Import "d3d9_borderless.c"
Import "d3d9_fullscreen.cpp"
Extern "C"
 Function test_d9_covers:Int(hwnd:Byte Ptr)
 Function m2d9_test_dpi_aware:Int()
 Function m2d9_test_position(hwnd:Byte Ptr,x:Int Var,y:Int Var)
 Function m2d9_test_size(hwnd:Byte Ptr,width:Int Var,height:Int Var)
 Function m2d9_test_focus:Int(hwnd:Byte Ptr)
 Function m2d9_test_desktop:Int(hwnd:Byte Ptr,width:Int Var,height:Int Var,hertz:Int Var)
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
Try
 If AppArgs.Length>1 And AppArgs[1]="aware" Then Check(m2d9_test_dpi_aware(),"Start DPI aware")
 Local canvas:TMax2DGraphics=TMax2DGraphics(Graphics(320,240,0,0))
 Local g:TD3D9Graphics=TD3D9Graphics(canvas.context.graphics)
 Local w:Int,h:Int,d:Int,hz:Int,f:Long,x:Int,y:Int
 canvas.GetSettings(w,h,d,hz,f,x,y)
 Local originalX:Int=x,originalY:Int=y
 Local physicalW:Int,physicalH:Int
 m2d9_test_size(g._hwnd,physicalW,physicalH)
 Local originalPhysicalW:Int=physicalW,originalPhysicalH:Int=physicalH
 m2d9_test_position(g._hwnd,originalX,originalY)
 g.AddDeviceLostCallback(Lost,Null);g.AddDeviceResetCallback(ResetDone,Null)
 Local target:TRenderImage=CreateRenderImage(16,16,FILTEREDIMAGE|MIPMAPPEDIMAGE)
 SetRenderImage(target);SetClsColor(80,160,240,0.5);Cls
 Local before:UInt=GrabPixmap(0,0,1,1).ReadPixel(0,0)
 SetRenderImage(Null)
 Local pixmap:TPixmap=CreatePixmap(8,8,PF_RGBA8888);pixmap.ClearPixels($ffff0000)
 Local image:TImage=LoadImage(pixmap)
 SetVirtualResolution(320,240,VIRTUAL_LETTERBOX)
 Check(Max2DSupportsFullscreen(),"Exclusive capability")
 Local mode:TGraphicsMode
 For Local candidate:TGraphicsMode=EachIn GraphicsModes()
  If candidate.width>=640 And candidate.height>=480 Then
   If Not mode Then mode=candidate
   If candidate.width=1280 And candidate.height=720 Then mode=candidate;Exit
  End If
 Next
 Check(mode<>Null,"Enumerated exclusive mode")
 Local desktopW:Int,desktopH:Int,desktopHz:Int
 Check(m2d9_test_desktop(g._hwnd,desktopW,desktopH,desktopHz),"Initial desktop mode")
 Local rejected:Int
 Try
  SetFullscreen(True,123,157)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And GetWindowMode()=MAX2D_WINDOWED And GraphicsWidth()=320,"Unavailable mode rejected before mutation")
 Check(m2d9_test_focus(g._hwnd),"Foreground test window")
 For Local pass:Int=0 Until 3
  SetRenderImage(target);SetClsColor(80+pass*20,160,240,0.5);Cls
  before=GrabPixmap(0,0,1,1).ReadPixel(0,0)
  SetRenderImage(Null)
  If pass=1 Then SetBorderlessFullscreen(True)
  Check(m2d9_test_focus(g._hwnd),"Foreground before exclusive")
  SetFullscreen(True,mode.width,mode.height,mode.hertz)
  SetFullscreen(True,mode.width,mode.height,mode.hertz)
  Check(GetWindowMode()=MAX2D_FULLSCREEN,"Exclusive mode")
  Local actualW:Int,actualH:Int,actualHz:Int
  Check(m2d9_test_desktop(g._hwnd,actualW,actualH,actualHz),"Exclusive desktop query")
  Check(actualW=mode.width And actualH=mode.height And actualHz=mode.hertz,"Actual display mode changed")
  Check(GraphicsDepth()=32 And GraphicsHertz()=mode.hertz,"Display settings")
  Local cw:Int,ch:Int
  g.ClientSize(cw,ch)
  Local mx:Float,my:Float
  WindowToVirtual(cw/2.0,ch/2.0,mx,my)
  Check(Abs(mx-160)<0.5 And Abs(my-120)<0.5,"Exclusive client mouse coordinates")
  Local vx:Float,vy:Float,wx:Float,wy:Float
  VirtualToWindow(160,120,wx,wy);WindowToVirtual(wx,wy,vx,vy)
  Check(Abs(vx-160)<0.001 And Abs(vy-120)<0.001,"Virtual input round trip")
  SetClsColor(16,32,64);Cls
  Check((GrabPixmap(NativeResolutionWidth()/2,NativeResolutionHeight()/2,1,1).ReadPixel(0,0)&$ffffff)=$102040,"Fullscreen backbuffer")
  SetRenderImage(target)
  Check(GrabPixmap(0,0,1,1).ReadPixel(0,0)=before,"Render image contents retained")
  SetRenderImage(Null)
  DrawImage(image,0,0);DrawImage(target,32,32);Flip(1)
  If pass=2 Then
   SetBorderlessFullscreen(True)
   Check(GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN And test_d9_covers(g._hwnd),"Exclusive to borderless")
  End If
  SetFullscreen(False)
  Check(m2d9_test_desktop(g._hwnd,actualW,actualH,actualHz),"Restored desktop query")
  Check(actualW=desktopW And actualH=desktopH And actualHz=desktopHz,"Desktop mode restored")
  canvas.GetSettings(w,h,d,hz,f,x,y)
  m2d9_test_size(g._hwnd,physicalW,physicalH)
  m2d9_test_position(g._hwnd,x,y)
  Check(physicalW=originalPhysicalW And physicalH=originalPhysicalH,"Physical client size restored")
  Check(GetWindowMode()=MAX2D_WINDOWED And w=320 And h=240 And x=originalX And y=originalY,"Window restored pass "+pass+": "+w+"x"+h+" at "+x+","+y+" expected "+originalX+","+originalY+" mode "+GetWindowMode())
  Check(losses=resets,"Reset callbacks balanced")
  SetRenderImage(target)
  Check(GrabPixmap(0,0,1,1).ReadPixel(0,0)=before,"Return preserves target")
  SetRenderImage(Null)
  Cls;DrawImage(image,10,10)
  Check((GrabPixmap(11,11,1,1).ReadPixel(0,0)&$ffffff)=$ff0000,"Managed texture retained")
  Flip(1)
 Next
 GraphicsResize(400,300)
 m2d9_test_size(g._hwnd,physicalW,physicalH)
 Check(GraphicsWidth()=400 And GraphicsHeight()=300 And physicalW=originalPhysicalW*400/320 And physicalH=originalPhysicalH*300/240,"Resize after DPI-awareness change")
 Check(m2d9_test_focus(g._hwnd),"Foreground before close test")
 SetFullscreen(True,mode.width,mode.height,mode.hertz)
 ShowWindow(g._hwnd,SW_MINIMIZE);PollSystem();Flip(1)
 Check(GetWindowMode()=MAX2D_FULLSCREEN,"Minimized exclusive retains requested mode")
 ShowWindow(g._hwnd,SW_RESTORE)
 Check(m2d9_test_focus(g._hwnd),"Restore foreground")
 Local deadline:Int=MilliSecs()+5000
 Repeat
  PollSystem();Flip(1)
  If TD3D9Max2DContext(canvas.context).Ready() Then Exit
  Delay(10)
 Until MilliSecs()>deadline
 Check(TD3D9Max2DContext(canvas.context).Ready(),"Recovery after minimize/restore")
 SetClsColor(16,32,64);Cls
 Check((GrabPixmap(mode.width/2,mode.height/2,1,1).ReadPixel(0,0)&$ffffff)=$102040,"Drawing after focus recovery")
 EndGraphics()
 Local closedW:Int,closedH:Int,closedHz:Int
 Check(m2d9_test_desktop(Null,closedW,closedH,closedHz),"Desktop after exclusive close")
 Check(closedW=desktopW And closedH=desktopH And closedHz=desktopHz,"Closing restores desktop")
 canvas=TMax2DGraphics(Graphics(320,240,0,0))
 g=TD3D9Graphics(canvas.context.graphics)
 m2d9_test_size(g._hwnd,physicalW,physicalH)
 Check(GraphicsWidth()=320 And GraphicsHeight()=240 And physicalW=originalPhysicalW And physicalH=originalPhysicalH,"New window respects changed process DPI awareness")
 EndGraphics()
 Print "D3D9 exclusive fullscreen tests passed"
Catch error:Object
 EndGraphics()
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
