SuperStrict
Framework Max2D.D3D11Max2D
Import BRL.StandardIO
' Build with -ud d3d11_recovery_test. Only failure detection is injected;
' recovery destroys and replaces the real hardware device and swap chain.
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 Print "PASS: "+message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Try
 Check(Graphics(80,64,0,0)<>Null,"Create window")
 Local c:TD3D11Max2DContext=TD3D11Max2DContext(TMax2DGraphics.selected.context)
 Local g:TD3D11Graphics=TD3D11Graphics(c.graphics)
 Local hwnd:Byte Ptr=g._hwnd
 Local image:TImage=CreateImage(4,4,1,DYNAMICIMAGE|FILTEREDIMAGE|MIPMAPPEDIMAGE)
 Local p:TPixmap=LockImage(image);p.ClearPixels($ffff0000);UnlockImage(image)
 SetBlend(SOLIDBLEND);DrawImage(image,0,0)
 Check(Pixel(0,0)=$ff0000,"Initial texture")
	Local coveragePixels:TPixmap=CreatePixmap(4,4,PF_A8)
	coveragePixels.ClearPixels($80ffffff)
	Local coverage:TImage=TImage.FromPixmap(coveragePixels,DYNAMICIMAGE|FILTEREDIMAGE,PF_A8)
	DrawImage(coverage,20,0)
	FlushMax2D()
	Check(coverage.Frame().pixelFormat=PF_A8,"Initial native coverage texture")
	Local raw:TImage=LoadImage(TTextureData.FromPixmap(coveragePixels),FILTEREDIMAGE)
	DrawImage(raw,30,0)
	FlushMax2D()
 Local frame:TImageFrame=image.Frame()
 Local target:TRenderImage=CreateRenderImage(8,8,FILTEREDIMAGE|MIPMAPPEDIMAGE)
 SetRenderImage(target);SetClsColor(255,0,255,1);Cls
 SetViewport(2,2,3,3)
 Local generation:Int=g.generation
 D3D11TestRemoved=True
 SetColor(0,255,0);DrawRect(0,0,8,8)
 p=ReadRenderImage(target)
 Check(g.generation=generation+1 And g._hwnd=hwnd,"Replacement preserves window")
 Check(p.ReadPixel(0,0)=0 And p.ReadPixel(2,2)=$ff00ff00,"Target recreated transparent and viewport restored")
 SetRenderImage(Null);SetColor(255,255,255);SetClsColor(0,0,0);Cls
 DrawImageRect(image,0,0,1,1)
 Check(Pixel(0,0)=$ff0000 And image.Frame()=frame,"Ordinary image and mipmaps restored in same logical frame")
	SetBlend(ALPHABLEND)
	DrawImage(coverage,20,0)
	Check(Abs((Pixel(20,0)&255)-128)<=1 And coverage.Frame().pixelFormat=PF_A8,"Coverage texture restored with native format")
	DrawImage(raw,30,0)
	Check(Abs((Pixel(30,0)&255)-128)<=1,"Texture-data image restored after device replacement")
	SetBlend(SOLIDBLEND)
 DrawImage(target,10,0)
 Check(Pixel(12,2)=$00ff00,"Recovered target sampling")

 ' Edits after a failed replacement must be retained for a later successful retry.
 D3D11TestRemoved=True;D3D11TestRecreateFailure=True
 Local rejected:Int
 Try
  Cls()
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And g.native=Null,"Failed replacement is explicit and releases old device")
 p=LockImage(image);p.ClearPixels($ff00ffff);UnlockImage(image)
	Local coverageEdit:TPixmap=LockImage(coverage)
	coverageEdit.ClearPixels($40ffffff)
	UnlockImage(coverage)
 D3D11TestRecreateFailure=False
 Cls;DrawImageRect(image,0,0,1,1)
 Check(Pixel(0,0)=$00ffff,"Latest CPU edit restored after retry")
	SetBlend(ALPHABLEND)
	DrawImage(coverage,20,0)
	Check(Abs((Pixel(20,0)&255)-64)<=1,"Latest coverage edit restored after failed replacement")
	SetBlend(SOLIDBLEND)
 Check(ReadRenderImage(target).ReadPixel(2,2)=0,"Render image contents lost on device replacement")

 generation=g.generation
	D3D11TestCoverageFallback=True
	Check(Max2DTextureFormatSupport(PF_A8)=ETextureFormatSupport.Converted,"Query reports coverage fallback")
 D3D11TestPresentRemoved=True
 Flip(0)
 Check(g.generation=generation+1,"Removal during presentation recovers")
 Cls;DrawImage(image,0,0)
 Check(Pixel(0,0)=$00ffff,"Rendering resumes after presentation loss")
	SetBlend(ALPHABLEND)
	DrawImage(coverage,20,0)
	Check(Abs((Pixel(20,0)&255)-64)<=1 And coverage.Frame().pixelFormat=PF_RGBA8888,"Coverage restores through RGBA fallback")
	D3D11TestCoverageFallback=False
	Check(Max2DTextureFormatSupport(PF_A8)=ETextureFormatSupport.Native,"Query reports restored native support")
	SetBlend(SOLIDBLEND)

 generation=g.generation
 SetRenderImage(target);SetViewport(0,0,8,8)
 SetColor(255,0,0);DrawRect(0,0,8,8)
 D3D11TestOperationRemoved=True
 FlushMax2D()
 Check(g.generation=generation+1,"Removal reported by draw recovers")
 Check(ReadRenderImage(target).ReadPixel(0,0)=0,"Interrupted target draw requires redraw")
 D3D11TestOperationRemoved=True;rejected=False
 Try
  ReadRenderImage(target)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And g.generation=generation+2,"Readback interrupted by replacement is explicit")
 SetRenderImage(Null);SetColor(255,255,255)
	Cls()
	SetBlend(ALPHABLEND)
	DrawImage(coverage,20,0)
	Check(Abs((Pixel(20,0)&255)-64)<=1 And coverage.Frame().pixelFormat=PF_A8,"Coverage returns to native storage after replacement")
	SetBlend(SOLIDBLEND)
 ShowWindow(hwnd,SW_MINIMIZE);PollSystem()
 D3D11TestRemoved=True
 SetRenderImage(target);SetViewport(0,0,8,8);SetClsColor(20,40,60,1);Cls
 Check((ReadRenderImage(target).ReadPixel(0,0)&$ffffff)=$14283c,"Offscreen recovery while minimized")
 SetRenderImage(Null)
 ShowWindow(hwnd,SW_RESTORE);PollSystem()
 GraphicsResize(96,72)
 Cls;DrawImageRect(image,0,0,1,1)
 Check(Pixel(0,0)=$00ffff,"Resize after recovery")

 DrawImage(image,0,0)
 D3D11TestRemoved=True;D3D11TestRecreateFailure=True
 EndGraphics()
 D3D11TestRemoved=False;D3D11TestRecreateFailure=False
 Check(Graphics(64,64,0,0)<>Null,"Reopen after close while removed")
 DrawImage(image,0,0)
 Check(Pixel(0,0)=$00ffff,"CPU image survives close and reopen")
 EndGraphics()
 Print "Max2D D3D11 recovery tests passed"
Catch error:Object
 EndGraphics()
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
