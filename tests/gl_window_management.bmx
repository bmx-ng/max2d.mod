SuperStrict
Framework Max2D.GLMax2D
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Try
 Local canvas:TMax2DGraphics=TMax2DGraphics(Graphics(320,240,0,0))
 Check(canvas<>Null,"Window creation")
 Check(GLMax2DDriver().CanResize(),"Resize capability")
 Local backend:TGLGraphics=TGLGraphics(canvas.context.graphics)
 Local original:Byte Ptr=backend._context
 Local texture:Int
 glGenTextures(1,Varptr texture);glBindTexture(GL_TEXTURE_2D,texture)
 Local target:TRenderImage=CreateRenderImage(16,16)
 SetRenderImage(target);SetClsColor(0,255,0);Cls;SetRenderImage(Null)
 SetVirtualResolution(320,240,VIRTUAL_LETTERBOX)
 Local widths:Int[]=[400,240,320],heights:Int[]=[300,180,240]
 For Local pass:Int=0 Until 3
  Local width:Int=widths[pass],height:Int=heights[pass]
  GraphicsResize(width,height)
  GraphicsPosition(100+pass*10,120+pass*10)
  PollSystem()
  Local w:Int,h:Int,d:Int,hz:Int,flags:Long,x:Int,y:Int
  canvas.GetSettings(w,h,d,hz,flags,x,y)
  Check(w=width And h=height And GraphicsWidth()=width And GraphicsHeight()=height,"Resize reporting")
  Check(x=100+pass*10 And y=120+pass*10,"Client-area position reporting")
  Check(backend._context=original And glIsTexture(texture),"Context and texture retained")
  SetClsColor(16,32,64);Cls
  Local pw:Int=NativeResolutionWidth(),ph:Int=NativeResolutionHeight()
  Local viewport:Int[4];glGetIntegerv(GL_VIEWPORT,viewport)
  Check(viewport[2]=pw And viewport[3]=ph,"Viewport follows drawable size")
  Check((GrabPixmap(pw/2,ph/2,1,1).ReadPixel(0,0)&$ffffff)=$102040,"Drawing after resize")
  PushMax2DState()
  SetNativeResolution()
  SetColor(255,0,0);DrawRect(8,8,8,8)
  Check((GrabPixmap(11,11,1,1).ReadPixel(0,0)&$ffffff)=$ff0000,"Top-left drawing after resize")
  SetColor(0,0,255);DrawRect(pw-16,ph-16,8,8)
  Check((GrabPixmap(pw-12,ph-12,1,1).ReadPixel(0,0)&$ffffff)=$0000ff,"Bottom-right drawing after resize")
  PopMax2DState()
  Local vx:Float,vy:Float
  WindowToVirtual(width/2.0,height/2.0,vx,vy)
  Check(Abs(vx-160)<0.01 And Abs(vy-120)<0.01,"Virtual resolution and input mapping retained")
  SetRenderImage(target)
  Check((GrabPixmap(0,0,1,1).ReadPixel(0,0)&$ffffff)=$00ff00,"Render image retained")
  SetRenderImage(Null)
  Flip(0)
 Next
 glDeleteTextures(1,Varptr texture)
 EndGraphics()
 Print "Max2D OpenGL window-management tests passed"
Catch error:Object
 EndGraphics()
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
