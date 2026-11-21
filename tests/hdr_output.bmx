SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
Import BRL.StandardIO

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
Try
	For Local lifetime:Int = 0 Until 2
		Graphics(64, 32)
		Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(TMax2DGraphics.Current().context)
		Print "Driver: "+SDLGPUMax2DDriverName()+" HDR format: "+context.SupportsHDROutput()+" headroom: "+context.HDRHeadroom()+" SDR white: "+context.SDRWhiteLevel()
		Check(Not context.HDROutput(), "new context defaults to SDR")
		Local sdrFormat:Int = context.WindowOverlayFormat()
		Local values:Float[] = [4.0, 2.0, 0.5, 1.0]
		Local bytes:Byte[] = New Byte[16]
		MemCopy(bytes, values, 16)
		Local source:TImage = LoadImage(TTextureData.Create([TTextureLevel.Create(1, 1, PF_RGBA32F, bytes)]), 0)
		If context.SupportsHDROutput() Then
			For Local compact:Int = 0 Until 2
				SetSDLGPUMax2DCompactSprites(compact)
				context.SetHDROutput(True)
				Check(context.HDROutput(), "HDR selected")
				Check(context.WindowOverlayFormat() <> sdrFormat, "window format changed")
				Local physicalWidth:Int, physicalHeight:Int
				Check(m2d_gpu_output(context.native, Varptr physicalWidth, Varptr physicalHeight), "physical window size")
				Local capture:Float[] = New Float[physicalWidth*physicalHeight*4]
				Cls
				SetBlend(SOLIDBLEND)
				DrawImage(source, 0, 0)
				DrawImageEffect(source, CreateSaturationEffect(), 1, 0)
				context.Flush()
				Check(m2d_gpu_read_float(context.native, Null, capture), "HDR window readback")
				For Local x:Int = 0 Until 2
					For Local c:Int = 0 Until 4
						Check(Abs(capture[(x*physicalWidth/64)*4+c]-values[c]) < 0.01, "unclipped HDR window value")
					Next
				Next
				Flip(0)
				Check(context.HDROutput(), "unsynchronised flip preserves HDR")
				Flip(1)
				Check(context.HDROutput(), "synchronised flip preserves HDR")
				TMax2DGraphics.Current().Resize(80, 40)
				Cls
				DrawImage(source, 0, 0)
				context.Flush()
				Check(m2d_gpu_output(context.native, Varptr physicalWidth, Varptr physicalHeight), "resized physical extent")
				capture = New Float[physicalWidth*physicalHeight*4]
				Check(m2d_gpu_read_float(context.native, Null, capture), "resized HDR readback")
				Check(Abs(capture[0]-4) < 0.01, "resize preserves HDR storage")
				TMax2DGraphics.Current().Resize(64, 32)
				Local target:TRenderImage = CreateRenderImage(8, 8)
				SetRenderImage(target)
				Local rejected:Int
				Try
					context.SetHDROutput(False)
				Catch error:Object
					rejected = True
				End Try
				Check(rejected And context.HDROutput(), "render target mode change rejected")
				SetRenderImage(Null)
				context.SetHDROutput(False)
				Check(Not context.HDROutput() And context.WindowOverlayFormat() = sdrFormat, "SDR restored")
				Cls
				DrawImage(source, 0, 0)
				Local pixel:Int = GrabPixmap(0, 0, 1, 1).ReadPixel(0, 0)
				Check(((pixel Shr 16) & 255) = 255, "SDR readback works and clips highlights")
				Flip
			Next
		Else
			Local rejected:Int
			Try
				context.SetHDROutput(True)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected And Not context.HDROutput(), "unsupported HDR request preserves SDR")
			Cls
			Flip
		End If
		EndGraphics
	Next
	Print "hdr_output passed"
Catch error:Object
	Print error.ToString()
	EndGraphics
	EndWithCode(1)
End Try
