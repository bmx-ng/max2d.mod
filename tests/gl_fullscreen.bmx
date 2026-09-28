SuperStrict
Framework Max2D.GLMax2D
Import BRL.StandardIO
?osx
Import "gl_fullscreen.m"
?win32
Import "gl_fullscreen.cpp"
?
Extern "C"
 Function test_gl_focus:Int()
 Function test_gl_desktop:Int(w:Int Var,h:Int Var,hz:Int Var)
 Function test_gl_save_desktop()
 Function test_gl_restored:Int()
 Function test_gl_minimize()
 Function test_gl_restore()
End Extern
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Focus()
 For Local i:Int=0 Until 50
  If test_gl_focus() Then Return
  PollSystem();Delay(20)
 Next
 Throw "Cannot focus test window"
End Function
Try
 Local canvas:TMax2DGraphics=TMax2DGraphics(Graphics(320,240,0,0))
 Local g:TGLGraphics=TGLGraphics(canvas.context.graphics)
 Local original:Byte Ptr=g._context
 GraphicsPosition(100,120)
 Focus()
 test_gl_save_desktop()
 Check(Max2DSupportsFullscreen(),"Exclusive capability")
 Local mode:TGraphicsMode
 For Local candidate:TGraphicsMode=EachIn GraphicsModes()
  If candidate.width>=1280 And candidate.height>=720 Then
   If Not mode Then mode=candidate
   If candidate.width=1280 And candidate.height=720 Then mode=candidate;Exit
  End If
 Next
 Check(mode<>Null,"Enumerated mode")
 Print "Exclusive mode: "+mode.width+"x"+mode.height+" @ "+mode.hertz
 Local texture:Int
 glGenTextures(1,Varptr texture);glBindTexture(GL_TEXTURE_2D,texture)
 Local target:TRenderImage=CreateRenderImage(8,8)
 SetRenderImage(target);SetClsColor(80,160,240,0.5);Cls
 Local before:UInt=GrabPixmap(0,0,1,1).ReadPixel(0,0)
 SetRenderImage(Null)
 SetVirtualResolution(320,240,VIRTUAL_LETTERBOX)
 Local rejected:Int
 Try
  SetFullscreen(True,123,157)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And GetWindowMode()=MAX2D_WINDOWED And GraphicsWidth()=320,"Reject unavailable mode")
 For Local pass:Int=0 Until 3
  If pass=1 Then SetBorderlessFullscreen(True)
  Focus()
  SetFullscreen(True,mode.width,mode.height,mode.hertz)
  SetFullscreen(True,mode.width,mode.height,mode.hertz)
  Check(GetWindowMode()=MAX2D_FULLSCREEN And GraphicsWidth()=mode.width And GraphicsHeight()=mode.height,"Exclusive settings")
  Local dw:Int,dh:Int,rate:Int
  Check(test_gl_desktop(dw,dh,rate),"Actual display mode query")
  Check(dw=mode.width And dh=mode.height And (Not mode.hertz Or rate=mode.hertz),"Actual display mode")
  Check(g._context=original And glIsTexture(texture),"GL context and texture retained")
  SetClsColor(16,32,64);Cls
  Local pw:Int=NativeResolutionWidth(),ph:Int=NativeResolutionHeight()
  Check((GrabPixmap(pw/2,ph/2,1,1).ReadPixel(0,0)&$ffffff)=$102040,"Exclusive rendering")
  Local cw:Int,ch:Int,vx:Float,vy:Float
  g.ClientSize(cw,ch)
  WindowToVirtual(cw/2.0,ch/2.0,vx,vy)
  Check(Abs(vx-160)<0.5 And Abs(vy-120)<0.5,"Exclusive mouse mapping")
  SetRenderImage(target)
  Check(GrabPixmap(0,0,1,1).ReadPixel(0,0)=before,"Target retained")
  SetRenderImage(Null);Flip(0)
  If pass=2 Then SetBorderlessFullscreen(True)
  SetFullscreen(False)
  Check(test_gl_restored(),"Desktop and presentation restored")
  Local w:Int,h:Int,d:Int,hz:Int,flags:Long,x:Int,y:Int
  canvas.GetSettings(w,h,d,hz,flags,x,y)
  Check(w=320 And h=240 And x=100 And y=120 And GetWindowMode()=MAX2D_WINDOWED,"Window geometry restored")
  Cls;Flip(0)
 Next
 Focus();SetFullscreen(True,mode.width,mode.height,mode.hertz)
 test_gl_minimize()
 For Local i:Int=0 Until 100
  PollSystem()
  If test_gl_restored() Then Exit
  Delay(20)
 Next
 Check(GetWindowMode()=MAX2D_FULLSCREEN,"Suspended exclusive mode reported")
 Check(test_gl_restored(),"Focus loss releases display")
 test_gl_restore();Focus();PollSystem()
 Cls;Flip(0)
 Local dw:Int,dh:Int,rate:Int
 Check(test_gl_desktop(dw,dh,rate) And dw=mode.width And dh=mode.height,"Focus resumes display mode")
 Check(g._context=original And glIsTexture(texture),"Context survives focus loss")
 SetRenderImage(target)
 Check(GrabPixmap(0,0,1,1).ReadPixel(0,0)=before,"Target survives focus loss")
 SetRenderImage(Null)
 glDeleteTextures(1,Varptr texture)
 EndGraphics()
 Check(test_gl_restored(),"Exclusive close restores display")
 Print "OpenGL exclusive fullscreen tests passed"
Catch error:Object
 EndGraphics()
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
