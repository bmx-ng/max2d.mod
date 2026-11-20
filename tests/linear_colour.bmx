SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_sdlgpu And Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Effects
Import BRL.StandardIO

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
Function Decode:Double(value:Double)
	If value <= 0.04045 Then Return value/12.92
	Return Exp(Log((value+0.055)/1.055)*2.4)
End Function
Function Encode:Double(value:Double)
	If value <= 0.0031308 Then Return value*12.92
	Return 1.055*Exp(Log(value)/2.4)-0.055
End Function
Try
	Local artwork:TPixmap = CreatePixmap(256, 2, PF_RGBA8888)
	For Local x:Int = 0 Until 256
		artwork.WritePixel(x, 0, $ff000000 | (x Shl 16) | (x Shl 8) | x)
		artwork.WritePixel(x, 1, (x Shl 24) | $00804020)
	Next
	Local texture:TTextureData = SRGBPixmapToLinearTextureData(artwork)
	Local values:Float Ptr = Float Ptr(texture.Level().Data())
	For Local x:Int = 0 Until 256
		Check(Abs(values[x*4]-Decode(x/255.0)) < 0.000001, "sRGB ramp decode")
		Check(Abs(values[(256+x)*4+3]-x/255.0) < 0.000001, "linear coverage preserved")
		Check(Abs(values[(256+x)*4]-Decode(128/255.0)) < 0.000001, "straight RGB preserved at every alpha")
	Next
	Check(artwork.ReadPixel(128, 0) = $ff808080, "source unchanged")
	Local output:TMax2DLinearOutputEffect = CreateLinearOutputEffect()
	Local rejected:Int
	Try
		output.SetWhiteLevel(0)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And output.GetWhiteLevel() = 1, "invalid white level rejected atomically")
	For Local lifetime:Int = 0 Until 2
		Graphics(300, 80)
?max2d_gl
		Check(Max2DSupportsImageEffect(output), "OpenGL linear output required")
?
		If Not Max2DSupportsImageEffect(output) Then
			Print "linear output shader unsupported; CPU conversion passed"
			EndGraphics
			Exit
		End If
		Local source:TImage = LoadImage(texture, 0)
		Local target:TRenderImage = CreateRenderImage(256, 2, 0, PF_RGBA32F)
		Local premultiplied:TRenderImage = CreateRenderImage(256, 2, 0, PF_RGBA32F)
		SetRenderImage(premultiplied)
		SetBlend(SOLIDBLEND)
		DrawImage(source, 0, 0)
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			For Local hdr:Int = 0 Until 2
				output.SetHDR(hdr)
				output.SetExposure(4)
				output.SetWhiteLevel(1.5)
				SetRenderImage(target)
				SetBlend(SOLIDBLEND)
				DrawImageEffect(premultiplied, output, 0, 0)
				Local result:TTextureData = ReadRenderTextureData(target)
				Local pixels:Float Ptr = Float Ptr(result.Level().Data())
				For Local x:Int = 0 Until 256
					Local linear:Double = Decode(x/255.0)*4
					Local expected:Double = linear*1.5
					If Not hdr Then expected = Encode(linear/(1+linear))
					Check(Abs(pixels[x*4]-expected) < 0.00002, "display transfer ramp")
					Check(Abs(pixels[(256+x)*4+3]-x/255.0) < 0.000001, "output preserves alpha")
					Local colour:Double = Decode(128/255.0)*4
					If hdr Then colour :* 1.5 Else colour = Encode(colour/(1+colour))
					If x > 0 Then Check(Abs(pixels[(256+x)*4]-colour) < 0.00002, "unpremultiply before nonlinear output")
				Next
			Next
		Next
		SetRenderImage(target)
		output.SetHDR(False)
		output.SetExposure(1)
		DrawImageEffectBatch(source, output, [0.0, 0.0])
		ResetMax2DStats()
		DrawImageEffectBatch(source, output, [0.0, 0.0, 0.0, 0.0])
		Local stats:TMax2DStats = CaptureMax2DStats()
		Check(stats.submissions = 1 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "warmed output batch cost")
		Local pair:TPixmap = CreatePixmap(2, 1, PF_RGBA8888)
		pair.WritePixel(0, 0, $ff000000)
		pair.WritePixel(1, 0, $ffffffff)
		Local filtered:TImage = LoadImage(SRGBPixmapToLinearTextureData(pair), FILTEREDIMAGE)
		SetScale(0.5, 1)
		DrawImageEffect(filtered, output, 0, 0)
		SetScale(1, 1)
		Local midpoint:TTextureData = ReadRenderTextureData(target)
		Local sample:Float Ptr = Float Ptr(midpoint.Level().Data())
		Check(Abs(sample[0]-Encode(0.5/1.5)) < 0.00002, "filtering averages linear light before output mapping")
		SetRenderImage(Null)
		EndGraphics
	Next
	Print "linear_colour passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
