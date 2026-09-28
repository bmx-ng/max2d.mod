SuperStrict
Framework Max2D.D3D11Max2D
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Try
 Check(Graphics(200,150,0,0)<>Null,"Create window")
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local window:TD3D11Graphics=TD3D11Graphics(canvas.context.graphics)
 Local image:TImage=CreateImage(1,1,1,DYNAMICIMAGE)
 Local p:TPixmap=LockImage(image)
 p.WritePixel(0,0,$ffff0000);UnlockImage(image)
 SetBlend(SOLIDBLEND);DrawImage(image,10,10)
 Check(Pixel(10,10)=$ff0000,"Initial image")
 GraphicsResize(240,160)
 Check(NativeResolutionWidth()=240 And NativeResolutionHeight()=160,"Resized output")
 SetClsColor(0,0,0);Cls;DrawImage(image,200,140)
 Check(Pixel(200,140)=$ff0000,"Texture survives swap-chain resize")
 SetVirtualResolution(80,80,VIRTUAL_LETTERBOX)
 SetVirtualBarColor(0,0,255);SetClsColor(0,255,0);Cls
 Check(Pixel(0,80)=$0000ff And Pixel(239,80)=$0000ff,"Letterbox bars after resize")
 Check(Pixel(40,0)=$00ff00 And Pixel(199,159)=$00ff00,"Letterbox content edges")

 ShowWindow(window._hwnd,SW_MINIMIZE)
 PollSystem()
 Check(Not window.Ready(),"Minimized state")
 p=LockImage(image);p.WritePixel(0,0,$ff00ffff);UnlockImage(image)
 DrawImage(image,1,1);FlushMax2D()
 Local rejected:Int
 Try
  GrabPixmap(0,0,1,1)
 Catch e:Object
  rejected=True
 End Try
 Check(rejected,"Minimized readback rejection")
 Local offscreen:TRenderImage=CreateRenderImage(7,5,0)
 SetRenderImage(offscreen)
 SetClsColor(0,0,0,0);Cls
 SetColor(255,255,255);SetBlend(SOLIDBLEND);DrawImage(image,2,3)
 Local captured:TPixmap=ReadRenderImage(offscreen)
 Check(captured.ReadPixel(2,3)=$ff00ffff,"Offscreen rendering while minimized")
 Check(captured.ReadPixel(0,0)=0,"Transparent offscreen background")
 SetRenderImage(Null)
 ShowWindow(window._hwnd,SW_RESTORE)
 PollSystem()
 Check(window.Ready(),"Restored state")
 SetVirtualResolution(240,160);SetClsColor(0,0,0);Cls;DrawImage(image,10,10)
 Check(Pixel(10,10)=$00ffff,"Image edit made while minimized survives")
 SetNativeResolution()
 For Local size:Int=0 Until 3
  GraphicsResize(240+size*20,160+size*10)
  Cls;DrawImage(image,10,10)
  Check(Pixel(10,10)=$00ffff,"Repeated resize releases all backbuffer references")
  Flip(size Mod 2)
 Next
 EndGraphics()
 Print "Max2D D3D11 window lifecycle tests passed"
Catch e:Object
 EndGraphics()
 Print "FAILED: "+e.ToString()
 EndWithCode(1)
End Try
