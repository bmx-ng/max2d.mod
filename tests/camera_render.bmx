SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Function EarlyReturn:Int()
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetCamera(Null);SetColor(1,2,3)
  Return 17
 End Using
End Function
Try
 Local graphics:TGraphics=Graphics(160,120,0,0)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target)
 SetClsColor(0,0,0);Cls()
 Local camera:TCamera2D=New TCamera2D
 camera.x=100;camera.y=100;camera.offsetX=32;camera.offsetY=32;camera.zoom=2
 SetCamera(camera)
 camera.zoom=9
 Check(GetCamera().zoom=2,"Camera application snapshots caller values")
 Local copy:TCamera2D=GetCamera();copy.zoom=7
 Check(GetCamera().zoom=2,"GetCamera returns a detached copy")
 SetColor(255,0,0);DrawRect(102,104,2,3)
 Check(Pixel(37,41)=$ff0000 And Pixel(35,41)=0,"Camera transforms positions and dimensions")
 camera.zoom=2;camera.rotation=90;SetCamera(camera);Cls()
 SetColor(0,255,0);DrawRect(100,100,2,2)
 Check(Pixel(33,29)=$00ff00 And Pixel(33,33)=0,"Camera rotation sign and pivot")
 Local transform:TMax2DDrawTransform=CaptureDrawTransform(100,100)
 Local x:Float,y:Float
 transform.LocalToVirtual(1,1,x,y)
 Check(Abs(x-34)<0.001 And Abs(y-30)<0.001,"Captured transform includes camera")
 transform.VirtualToLocal(x,y,x,y)
 Check(Abs(x-1)<0.001 And Abs(y-1)<0.001,"Captured camera transform inverse")
 camera.rotation=0;SetCamera(camera)
 camera.ZoomAt(4,36,40);SetCamera(camera)
 Cls();SetColor(255,0,0);DrawRect(102,104,2,2)
 Check(Pixel(36,40)=$ff0000 And Pixel(43,47)=$ff0000 And Pixel(44,47)=0,"Anchored zoom keeps the point and changes image scale")
 camera.x=100;camera.y=100;camera.zoom=2;SetCamera(camera)
 Cls();SetColor(255,0,0);DrawRect(100,100,2,2)
 camera.x=104;SetCamera(camera);SetColor(0,255,0);DrawRect(100,100,2,2)
 Check(Pixel(33,33)=$ff0000 And Pixel(25,33)=$00ff00,"Queued draws retain their applied camera")
 camera.x=100;SetCamera(camera)
 Local image:TImage=CreateImage(2,2,1,0)
 ClearImage(image,New SColor8(255,255,255,255))
 Cls();SetColor(255,255,255);DrawImage(image,100,100)
 Check(Pixel(35,35)=$ffffff And Pixel(36,35)=0,"Image camera extent")
 Local imageTransform:TMax2DDrawTransform=CaptureImageTransform(image,100,100)
 imageTransform.LocalToVirtual(1,1,x,y)
 Check(x=34 And y=34,"Image transform camera composition")
 Cls();DrawLine(100,100,104,100)
 Check(Pixel(35,33)=$ffffff,"Line uses camera")
 Cls();DrawOval(100,100,4,4)
 Check(Pixel(36,36)=$ffffff,"Oval uses camera")
 Cls();Plot(100,100)
 Check(Pixel(33,33)=$ffffff,"Plot uses camera")
 Cls();DrawText("A",100,100)
 Local pixels:TPixmap=ReadRenderImage(target),found:Int
 For Local py:Int=32 Until 64
  For Local px:Int=32 Until 48
   If (pixels.ReadPixel(px,py)&$ffffff)<>0 Then found=True
  Next
 Next
 Check(found,"Bitmap text uses camera")
 Cls();SetViewport(34,34,2,2);Cls();DrawRect(90,90,30,30)
 Check(Pixel(34,34)=$ffffff And Pixel(33,34)=0,"Viewport stays in virtual coordinates")
 SetViewport(0,0,64,64)
 Local pixmap:TPixmap=CreatePixmap(1,1,PF_RGBA8888);pixmap.ClearPixels($ff0000ff)
 DrawPixmap(pixmap,1,1)
 Check(Pixel(1,1)=$0000ff And GetCamera().zoom=2,"Physical transfers ignore and preserve camera")
 Check(ImagesCollide(image,100,100,0,image,101,101,0),"Camera does not move collision geometry")
 Cls();camera.rotation=37;SetCamera(camera);TileImage(image)
 pixels=ReadRenderImage(target)
 For Local py:Int=1 Until 63
  For Local px:Int=1 Until 63
   Check((pixels.ReadPixel(px,py)&$ffffff)=$ffffff,"Rotated tiling covers the viewport")
  Next
 Next
 PushMax2DState();SetCamera(Null);PopMax2DState()
 Check(GetCamera().rotation=37,"Manual state restores camera")
 Check(EarlyReturn()=17 And GetCamera().rotation=37,"Using restores state on Return")
 While True
  Using
   Local scope:TMax2DStateScope=ScopedMax2DState()
  Do
   SetCamera(Null)
   Exit
  End Using
 Wend
 Check(GetCamera().rotation=37,"Using restores state on loop Exit")
 Local caught:Int
 Try
  Using
   Local scope:TMax2DStateScope=ScopedMax2DState()
  Do
   SetCamera(Null);SetRenderImage(Null);SetVirtualResolution(13,17)
   Throw "body"
  End Using
 Catch error:String
  caught=error="body"
 End Try
 Check(caught And GetCamera().rotation=37 And TMax2DGraphics.Current().renderImage=target,"Using restores target and camera after exception")
 Local outer:TMax2DStateScope=ScopedMax2DState()
 SetColor(255,0,0)
 Local inner:TMax2DStateScope=ScopedMax2DState()
 SetCamera(Null);PushMax2DState();SetColor(0,255,0)
 outer.Close();inner.Close();outer.Close()
 Check(GetCamera().rotation=37 And TMax2DGraphics.Current().saved.IsEmpty(),"Outer scope unwinds nested saves once")
 Local guarded:TMax2DStateScope=ScopedMax2DState(),rejected:Int
 Try
  PopMax2DState()
 Catch e:Object
  rejected=True
 End Try
 guarded.Close()
 Check(rejected,"Manual pop cannot consume a scope-owned save")
 SetRenderImage(Null);SetVirtualResolution(160,90,VIRTUAL_LETTERBOX)
 camera.rotation=0;camera.offsetX=80;camera.offsetY=45;SetCamera(camera)
 Local input:TMax2DCameraInput=CaptureCameraInput()
 Check(WorldToWindow(100,100,x,y),"World to window conversion")
 SetCamera(Null)
 Check(input.WindowToWorld(x,y,x,y) And Abs(x-100)<0.001 And Abs(y-100)<0.001,"Input snapshot survives overlay")
 Check(Not input.WindowToWorld(0,0,x,y),"Camera input rejects bars")
 SetRenderImage(target);SetCamera(camera)
 rejected=False
 Try
  CaptureCameraInput()
 Catch e:Object
  rejected=True
 End Try
 Check(rejected,"Offscreen window-input ambiguity rejected")
 SetRenderImage(Null)
?Not max2d_d3d9 And Not max2d_d3d11
 Local other:TGraphics=CreateGraphics(80,60,0,0,0,-1,-1)
 SetGraphics(graphics)
 Local owned:TMax2DStateScope=ScopedMax2DState()
 SetCamera(Null)
 SetGraphics(other);SetColor(0,0,255)
 owned.Close()
 Check(TMax2DGraphics.Current()=other,"Scope preserves current canvas selection")
 Check(GetCamera()=Null,"Scope leaves other canvas camera alone")
 SetGraphics(graphics)
 Check(GetCamera().x=100,"Scope restores its owner")
 CloseGraphics(other)
?
 Local closing:TMax2DStateScope=ScopedMax2DState()
 EndGraphics();closing.Close();closing.Close()
 Print "Max2D camera rendering and scope tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
