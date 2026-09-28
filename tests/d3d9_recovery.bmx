SuperStrict
Framework Max2D.D3D9Max2D
Import BRL.StandardIO

' Build with -ud d3d9_recovery_test. Injection only changes device status and
' a reset result; successful recovery still calls the real D3D9 Reset.
Global losses:Int
Global resets:Int
Function Lost(obj:Object)
 losses:+1
End Function
Function ResetDone(obj:Object)
 resets:+1
End Function
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Try
 Graphics 64,64,0,0
 UseDX9RenderLagFix=True
 Local context:TD3D9Max2DContext=TD3D9Max2DContext(TMax2DGraphics.selected.context)
 Local g:TD3D9Graphics=TD3D9Graphics(context.graphics)
 g.AddDeviceLostCallback(Lost,Null)
 g.AddDeviceResetCallback(ResetDone,Null)
 Local mipFlags:Int
 If Max2DSupportsImageFlags(MIPMAPPEDIMAGE) Then mipFlags=MIPMAPPEDIMAGE
 Local image:TImage=CreateImage(3,2,1,DYNAMICIMAGE|mipFlags)
 Local p:TPixmap=LockImage(image)
 p.ClearPixels($ffff0000)
 UnlockImage(image)
 SetBlend(SOLIDBLEND)
 DrawImage(image,0,0)
 Check(Pixel(0,0)=$ff0000,"Initial image")
 Local target:TRenderImage=CreateRenderImage(8,8,mipFlags)
 SetRenderImage(target);SetClsColor(255,0,255,1);Cls
 SetRenderImage(Null)
 D3D9TestStatus=D3DERR_DEVICELOST
 p=LockImage(image);p.ClearPixels($ff00ff00);UnlockImage(image)
 Cls;DrawImage(image,0,0);Flip(0)
 Local fresh:TImage=CreateImage(2,2,1,DYNAMICIMAGE|mipFlags)
 p=LockImage(fresh);p.ClearPixels($ff0000ff);UnlockImage(fresh)
 DrawImage(fresh,4,0);Flip(0)
 Check(losses=0 And resets=0,"Do not reset while device remains lost")
 Local rejected:Int
 Try
  GrabPixmap(0,0,1,1)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"Unavailable readback rejected")
 D3D9TestStatus=D3DERR_DEVICENOTRESET
 D3D9TestResetLost=True
 Flip(0);Flip(0)
 Check(losses=1 And resets=0,"Transient reset failure retries without repeated lost callbacks")
 p=LockImage(image);p.ClearPixels($ff00ffff);UnlockImage(image)
 Cls;DrawImage(image,0,0);Flip(0)
 Check(losses=1 And resets=0,"Edits during failed reset stay deferred")
 D3D9TestStatus=D3D_OK
 D3D9TestResetLost=False
 Flip(0)
 Check(losses=1 And resets=1,"Pending reset completed once")
 Check(ReadRenderImage(target).ReadPixel(0,0)=0,"Default-pool target recreated transparent")
 SetRenderImage(target);SetClsColor(255,0,255,1);Cls
 SetRenderImage(Null);DrawImage(target,8,0)
 Check(Pixel(8,0)=$ff00ff,"Recovered target can be rendered and sampled")
 Cls;DrawImage(image,0,0);DrawImage(fresh,4,0)
 Check(Pixel(0,0)=$00ffff,"Latest lost-period update retained")
 Check(Pixel(4,0)=$0000ff,"Lost-period creation retained")
 ShowWindow(g._hwnd,SW_MINIMIZE)
 PollSystem()
 Check(Not context.Ready(),"Minimized window unavailable")
 p=LockImage(image);p.ClearPixels($ffffff00);UnlockImage(image)
 Cls;DrawImage(image,0,0);Flip(0)
 ShowWindow(g._hwnd,SW_RESTORE)
 For Local attempt:Int=0 Until 100
  PollSystem()
  If context.Ready() Then Exit
  Flip(0)
  Delay(10)
 Next
 Check(context.Ready(),"Restored window available")
 Cls;DrawImage(image,0,0)
 Check(Pixel(0,0)=$ffff00,"Minimized-period edit retained")
 D3D9TestStatus=D3DERR_DRIVERINTERNALERROR
 rejected=False
 Try
  Cls()
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"Fatal device failures are not silently retried")
 D3D9TestStatus=D3DERR_DEVICELOST
 DrawImage(image,0,0)
 EndGraphics()
 D3D9TestStatus=D3D_OK
 Graphics 64,64,0,0
 DrawImage(image,0,0)
 Check(Pixel(0,0)=$ffff00,"Close while lost and reopen")
 EndGraphics()
 Print "Max2D D3D9 recovery tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
