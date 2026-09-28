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
Try
 Graphics(160,120,0,0)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target)
 SetClsColor(0,0,0);Cls()
 TranslateCoordinates(10,12);ScaleCoordinates(2,3)
 SetColor(255,0,0);DrawRect(2,2,3,2)
 Check(Pixel(14,18)=$ff0000 And Pixel(19,23)=$ff0000 And Pixel(20,23)=0,"Group transforms position and extent in parent order")
 Local transform:TMax2DDrawTransform=CaptureDrawTransform(2,2)
 Local x:Float,y:Float
 transform.LocalToVirtual(1,1,x,y)
 Check(x=16 And y=21,"Picking includes group transform")
 Check(transform.VirtualToLocal(x,y,x,y) And Abs(x-1)<0.001 And Abs(y-1)<0.001,"Group picking inverse")
 Local shape:TCollisionShape=TCollisionShape.Rect(2,2,3,2,TMax2DGraphics.Current().state)
 Check(shape.Solid(15,19) And Not shape.Solid(20,19),"Collisions include parent coordinates")
 PushMax2DState()
 RotateCoordinates(90);TranslateCoordinates(2,0)
 transform=CaptureDrawTransform(0,0)
 transform.LocalToVirtual(1,0,x,y)
 Check(Abs(x-10)<0.001 And Abs(y-21)<0.001,"Nested rotation and translation composition")
 PopMax2DState()
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  ResetCoordinates();SetColor(0,255,0)
  SetViewport(5,5,20,20);IntersectViewport(15,10,20,20)
  DrawRect(0,0,64,64)
 End Using
 Check(Pixel(15,10)=$00ff00 And Pixel(24,24)=$00ff00 And Pixel(25,24)=0 And Pixel(14,10)=0,"Nested clip intersection")
 transform=CaptureDrawTransform(0,0);transform.LocalToVirtual(1,1,x,y)
 Check(x=12 And y=15,"Using restores coordinate matrix")
 Local vx:Int,vy:Int,vw:Int,vh:Int
 GetViewport(vx,vy,vw,vh)
 Check(vx=0 And vy=0 And vw=64 And vh=64,"Using restores viewport")
 PushMax2DState()
 IntersectViewport(70,70,10,10);IntersectViewport(0,0,64,64)
 GetViewport(vx,vy,vw,vh);Check(vw=0 And vh=0,"Empty clip cannot be reopened by intersection")
 ResetCoordinates();SetColor(255,255,255);DrawRect(0,0,64,64)
 PopMax2DState()
 Check(Pixel(1,1)=0,"Empty clip draws nothing")
 Local rejected:Int
 Try
  IntersectViewport(0,0,-1,1)
 Catch e:Object
  rejected=True
 End Try
 Check(rejected,"Negative clip rejected")
 Local camera:TCamera2D=New TCamera2D
 camera.x=10;camera.y=12;camera.zoom=2
 SetCamera(camera)
 transform=CaptureDrawTransform(1,1);transform.LocalToVirtual(0,0,x,y)
 Check(x=4 And y=6,"Camera follows parent coordinates")
 shape=TCollisionShape.Rect(2,2,3,2,TMax2DGraphics.Current().state)
 Check(shape.Solid(15,19),"Camera remains outside collisions")
 Cls();SetColor(0,0,255);DrawRect(1,1,2,2)
 Check(Pixel(4,6)=$0000ff And Pixel(11,17)=$0000ff,"Camera and group rendered together")
 SetCamera(Null);ResetCoordinates();Cls()
 Local image:TImage=CreateImage(2,2,1,0)
 ClearImage(image,New SColor8(255,255,255,255));SetColor(255,255,255)
 TranslateCoordinates(32,32);RotateCoordinates(33);ScaleCoordinates(2,3)
 TileImage(image)
 Check(Pixel(0,0)=$ffffff And Pixel(63,63)=$ffffff And Pixel(0,63)=$ffffff And Pixel(63,0)=$ffffff,"Tiles cover inverse group bounds")
 ScaleCoordinates(0,1);TileImage(image)
 transform=CaptureDrawTransform(0,0)
 Check(Not transform.VirtualToLocal(0,0,x,y),"Collapsed group has no inverse and tiling terminates")
 ResetCoordinates();Cls();TranslateCoordinates(10,10)
 Local pixmap:TPixmap=CreatePixmap(1,1,PF_RGBA8888);pixmap.WritePixel(0,0,$ffff0000)
 DrawPixmap(pixmap,1,1)
 Check(Pixel(1,1)=$ff0000 And Pixel(11,11)=0,"DrawPixmap retains native pixel semantics")
 EndGraphics()
 Print "Max2D nested drawing state tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
