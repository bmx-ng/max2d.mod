SuperStrict
Framework Max2D.SDL3GPUMax2D
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Try
	Local graphics:TGraphics=Graphics(80,60,0,0)
	Check(graphics<>Null,"Create graphics")
	Local context:TMax2DContext=TMax2DGraphics.Current().context
	Local pixels:TPixmap=CreatePixmap(2,2,PF_RGBA8888)
	pixels.ClearPixels($ffff0000)
	Local image:TImage=LoadImage(pixels,0)
	Local target:TRenderImage=CreateRenderImage(8,8,0)
	SetRenderImage(target)
	SetBlend(SOLIDBLEND)
	' Exceed the native queue's vertex limit; earlier draws must survive its flush.
	For Local i:Int=0 Until 45000
		DrawImage(image,0,0)
	Next
	SetColor(0,255,0)
	DrawRect(4,4,2,2)
	FlushMax2D()
	Local oldFrame:TImageFrame=image.Frame()
	image.ReleaseFrames()
	GCCollect()
	FlushMax2D()
	Check(oldFrame.closed,"Deferred source release drained")
	Local result:TPixmap=ReadRenderImage(target)
	Check(result.ReadPixel(0,0)=$ffff0000,"Queued source survives release and queue growth")
	Check(result.ReadPixel(4,4)=$ff00ff00,"Drawing after queue rollover preserves order")
	Check(image.Frame()<>oldFrame,"Released image can recreate its texture")
	SetRenderImage(Null)
	SetNativeResolution()
	SetColor(255,255,255)
	For Local pass:Int=0 Until 4
		DrawImage(target,0,0)
		FlushMax2D()
		GraphicsResize(80+pass*7,60+pass*5)
		PollSystem()
		Cls()
		DrawImage(target,0,0)
		Check((GrabPixmap(0,0,1,1).ReadPixel(0,0)&$ffffff)=$ff0000,"Resize preserves render-image contents")
		Flip(pass Mod 2)
	Next
	' Destroy a queued source target while another target remains selected.
	Local destination:TRenderImage=CreateRenderImage(8,8,0)
	SetRenderImage(destination)
	DrawImage(target,0,0)
	FlushMax2D()
	target.ReleaseFrames()
	FlushMax2D()
	Check(ReadRenderImage(destination).ReadPixel(4,4)=$ff00ff00,"Queued target sampling survives source release")
	SetRenderImage(Null)
	EndGraphics()
	Check(context.frames.IsEmpty(),"Closing drains frame ownership registry")
	Print "Max2D SDL GPU lifetime tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
