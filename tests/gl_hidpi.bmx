SuperStrict
Framework Max2D.GLMax2D
Import BRL.StandardIO
?osx
Import "gl_hidpi_mode.m"
Extern "C"
 Function max2d_test_gl_lowdpi()
End Extern
?
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Try
 Local g:TGraphics=Graphics(640,480,0,0)
?osx
 If AppArgs.Length>1 And AppArgs[1]="lowdpi" Then max2d_test_gl_lowdpi()
?
 SetVirtualResolution(320,180,VIRTUAL_LETTERBOX)
 SetVirtualBarColor(12,12,16)
 SetClsColor(24,32,48);Cls
 Local w:Int=NativeResolutionWidth(),h:Int=NativeResolutionHeight()
 Print "GL window=640x480 drawable="+w+"x"+h
 Check(w>=640 And h>=480,"Valid backing dimensions")
 If AppArgs.Length>1 And AppArgs[1]="lowdpi" Then Check(w=640 And h=480,"One-pixel-per-point drawable required")
 ' Optional argument makes a Retina run fail if the test only exercises 1x.
 If AppArgs.Length>1 And AppArgs[1]="retina" Then Check(w>640,"Retina drawable required")
 Local scale:Float=Min(w/320.0,h/180.0)
 Local left:Int=Int((w-320*scale)/2),top:Int=Int((h-180*scale)/2)
 SetColor(80,180,240);DrawRect(20,20,80,50)
 Local mapping:TMax2DInputMapping=CaptureWindowInput()
 Local vx:Float,vy:Float
 Check(mapping.WindowToVirtual(160,150,vx,vy),"Window input lands in scene")
 Check(Abs(vx-80)<0.01 And Abs(vy-45)<0.01,"Input uses window points and drawable scale")
 Local viewport:Int[4]
 glGetIntegerv(GL_VIEWPORT,viewport)
 Check(viewport[2]=w And viewport[3]=h,"GL viewport spans drawable")
 Local p:TPixmap=GrabPixmap(0,0,w,h)
 Check((p.ReadPixel(w-1,top+1)&$ffffff)=$182030,"Scene fills right edge of drawable")
 Check((p.ReadPixel(w/2,top-1)&$ffffff)=$0c0c10,"Centred top bar")
 Check((p.ReadPixel(w/2,h-top)&$ffffff)=$0c0c10,"Centred bottom bar")
 Check((p.ReadPixel(left+Int(30*scale),top+Int(30*scale))&$ffffff)=$50b4f0,"Rectangle scaled and positioned")
 PushMax2DState();SetNativeResolution()
 SetColor(255,0,255);DrawRect(w-8,0,8,8)
 p=GrabPixmap(w-4,2,1,1)
 Check((p.ReadPixel(0,0)&$ffffff)=$ff00ff,"Native overlay reaches top-right backing pixels")
 PopMax2DState()
 Local target:TRenderImage=CreateRenderImage(32,16,0)
 SetRenderImage(target);SetClsColor(0,255,0);Cls
 Check(NativeResolutionWidth()=32 And NativeResolutionHeight()=16,"Targets retain pixel dimensions")
 SetRenderImage(Null);Cls
 Check(NativeResolutionWidth()=w And NativeResolutionHeight()=h,"Window backing size restored after target")
 Flip(0);EndGraphics()
 Print "Max2D OpenGL HiDPI tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
