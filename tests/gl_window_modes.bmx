SuperStrict
Framework Max2D.GLMax2D
Import BRL.StandardIO
?osx
Import "gl_borderless.m"
Extern "C"
 Function test_gl_capture_presentation()
 Function test_gl_presentation_restored:Int()
End Extern
?win32
Import "gl_borderless.c"
?linux
Import "gl_borderless_linux.c"
Extern "C"
 Function test_gl_capture_hints()
 Function test_gl_hints_restored:Int()
End Extern
?osx Or win32 Or linux
Extern "C"
 Function test_gl_borderless_covers_screen:Int()
End Extern
?
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Try
 Local canvas:TMax2DGraphics=TMax2DGraphics(Graphics(320,240,0,0))
 Check(canvas<>Null,"Window creation")
?osx
 test_gl_capture_presentation()
?
?linux
 Print "Linux EWMH borderless capability: "+Max2DSupportsBorderlessFullscreen()
?
 GraphicsPosition(100,120)
 Local native:TGLGraphics=TGLGraphics(canvas.context.graphics)
 Local original:Byte Ptr=native._context
?linux
 test_gl_capture_hints()
?
 Local target:TRenderImage=CreateRenderImage(8,8)
 SetRenderImage(target);SetClsColor(0,255,0);Cls;SetRenderImage(Null)
 SetVirtualResolution(320,240,VIRTUAL_LETTERBOX)

 If Max2DSupportsBorderlessFullscreen() Then
  For Local pass:Int=0 Until 3
   SetBorderlessFullscreen(True)
   SetBorderlessFullscreen(True) ' Idempotent: do not overwrite the saved window.
   Check(GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN,"Borderless mode")
   Check(GraphicsDepth()=0 And GraphicsHertz()=0,"Borderless display settings")
?osx Or win32 Or linux
   Check(test_gl_borderless_covers_screen(),"Borderless window covers current monitor")
?
   Check(native._context=original,"Native context retained")
   SetClsColor(16,32,64);Cls
   Local pw:Int=NativeResolutionWidth(),ph:Int=NativeResolutionHeight()
   Local viewport:Int[4];glGetIntegerv(GL_VIEWPORT,viewport)
   Check(viewport[2]=pw And viewport[3]=ph,"Fullscreen viewport follows drawable")
   Check((GrabPixmap(pw/2,ph/2,1,1).ReadPixel(0,0)&$ffffff)=$102040,"Fullscreen drawing")
   Local vx:Float,vy:Float
   WindowToVirtual(GraphicsWidth()/2.0,GraphicsHeight()/2.0,vx,vy)
   Check(Abs(vx-160)<0.5 And Abs(vy-120)<0.5,"Fullscreen virtual input: "+vx+", "+vy+" window "+GraphicsWidth()+"x"+GraphicsHeight()+" drawable "+pw+"x"+ph)
   Local wx:Float,wy:Float
   VirtualToWindow(160,120,wx,wy)
   WindowToVirtual(wx,wy,vx,vy)
   Check(Abs(vx-160)<0.001 And Abs(vy-120)<0.001,"Virtual coordinate round trip")
   Local rejected:Int
   Try
    GraphicsResize(200,100)
   Catch error:Object
    rejected=True
   End Try
   Check(rejected And GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN,"Reject resize while borderless")
   rejected=False
   Try
    GraphicsPosition(10,10)
   Catch error:Object
    rejected=True
   End Try
   Check(rejected And GetWindowMode()=MAX2D_BORDERLESS_FULLSCREEN,"Reject positioning while borderless")
   SetRenderImage(target)
   Check((GrabPixmap(0,0,1,1).ReadPixel(0,0)&$ffffff)=$00ff00,"Render image retained")
   SetRenderImage(Null)
   Flip(0)
   If pass=1 Then
    SetFullscreen(False) ' Generic return to windowed also leaves borderless.
   Else
    SetBorderlessFullscreen(False)
   End If
   SetBorderlessFullscreen(False)
   Local w:Int,h:Int,d:Int,hz:Int,f:Long,x:Int,y:Int
   canvas.GetSettings(w,h,d,hz,f,x,y)
   Check(GetWindowMode()=MAX2D_WINDOWED,"Windowed mode")
?linux
   Check(test_gl_hints_restored(),"Original X11 sizing hints restored")
?
?osx
   Check(test_gl_presentation_restored(),"Application presentation restored")
?
   Check(w=320 And h=240 And x=100 And y=120,"Window size and position restored")
   Check(GraphicsWidth()=320 And GraphicsHeight()=240,"Cached dimensions restored")
   Cls;Flip(0)
  Next
 Else
  Local rejected:Int
  Try
   SetBorderlessFullscreen(True)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And GetWindowMode()=MAX2D_WINDOWED,"Unsupported borderless is rejected")
 End If
 Local rejected:Int
 Try
  SetFullscreen(True,123,157)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And GraphicsWidth()=320,"Unavailable exclusive mode preserves window")
 If Max2DSupportsBorderlessFullscreen() Then SetBorderlessFullscreen(True)
 EndGraphics() ' Closing while borderless must release application presentation state.
?osx
 Check(test_gl_presentation_restored(),"Closing restores application presentation")
?
 Print "Max2D OpenGL borderless tests passed"
Catch error:Object
 EndGraphics()
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
