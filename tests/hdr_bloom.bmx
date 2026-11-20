SuperStrict

?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?

Import Max2D.Effects
Import BRL.StandardIO

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
Function Channel:Float(data:TTextureData, x:Int, y:Int, channel:Int)
	Local value:Float
	MemCopy(Varptr value, data.Level().Data()+y*data.Level().Pitch()+x*16+channel*4, 4)
	Return value
End Function
Function Mapped:Float(value:Float, exposure:Float, gamma:Float)
	Local scaled:Double = Max(0.0, Double(value))*exposure
	Local mapped:Double = scaled/(1+scaled)
	If mapped = 0 Then Return 0
	Return Float(Exp(Log(mapped)/gamma))
End Function
Function CheckTone(p:TPixmap, values:Float[], exposure:Float, gamma:Float, offset:Int = 0, tint:Float = 1, opacity:Float = 1)
	For Local x:Int = 0 Until 5
		Local pixel:Int = p.ReadPixel(x+offset, 0), alpha:Int = (pixel Shr 24) & 255
		Local expectedAlpha:Float = values[x*4+3]*opacity*255
		Check(Abs(alpha-expectedAlpha) <= 1, "tone map preserves alpha")
		For Local c:Int = 0 Until 3
			Local expected:Float = Mapped(values[x*4+c]*tint, exposure, gamma)*expectedAlpha
			Local actual:Float = ((pixel Shr (16-c*8)) & 255)*alpha/255.0
			Check(Abs(actual-expected) <= 2, "tone map energy at "+x+" channel "+c+" actual="+actual+" expected="+expected)
		Next
	Next
End Function
Try
	Local tone:TMax2DToneMapEffect = CreateToneMapEffect()
	Local rejected:Int
	Try
		tone.SetGamma(0)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And tone.GetGamma() = 1, "invalid gamma rejected")
	rejected = False
	Try
		tone.SetExposure(-1)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And tone.GetExposure() = 1, "invalid exposure rejected")
	Local values:Float[] = [3.0, 1.0, 0.25, 1.0, 8.0, 2.0, 0.5, 0.5, 0.0, -1.0, 0.0, 0.25, 0.1, 0.5, 1.0, 1.0, 1000.0, 1000.0, 1000.0, 0.125]
	Local bytes:Byte[] = New Byte[80]
	MemCopy(bytes, values, 80)
	Local texture:TTextureData = TTextureData.Create([TTextureLevel.Create(5, 1, PF_RGBA32F, bytes)])
	For Local lifetime:Int = 0 Until 2
		Check(Graphics(80, 60, 0, 0) <> Null, "graphics creation")
		If Not Max2DSupportsImageEffect(tone) Then
?max2d_sdlgpu
			Throw "tone mapping unavailable: "+SDL_GetError()
?max2d_gl Or max2d_d3d11 Or max2d_d3d9
			Throw "OpenGL effect unavailable"
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d11 And Not max2d_d3d9
			EndGraphics
			Print "hdr_bloom passed: unsupported provider reported"
			End
?
		End If
?max2d_sdlgpu
		Print "hdr_bloom driver="+SDLGPUMax2DDriverName()
?
		Local image:TImage = LoadImage(texture, 0)
		Local output:TRenderImage = CreateRenderImage(12, 1, 0)
		For Local format:Int = PF_RGBA16F To PF_RGBA32F
			Check(Max2DSupportsRenderImage(32, 32, FILTEREDIMAGE, format), "floating-point target support required")
			Local source:TRenderImage = CreateRenderImage(5, 1, 0, format)
			Local extracted:TRenderImage = CreateRenderImage(5, 1, 0, format)
			SetRenderImage(source)
			SetColor(255, 255, 255)
			SetAlpha(1)
			SetBlend(SOLIDBLEND)
			DrawImage(image, 0, 0)
			For Local compact:Int = 0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				SetRenderImage(output)
				SetBlend(SOLIDBLEND)
				Local exposures:Float[] = [0.0, 0.5, 1.0, 4.0]
				Local gammas:Float[] = [1.0, 2.2]
				For Local exposure:Float = EachIn exposures
					For Local gamma:Float = EachIn gammas
						tone.SetExposure(exposure)
						tone.SetGamma(gamma)
						DrawImageEffect(image, tone, 0, 0)
						DrawImageEffect(source, tone, 6, 0)
						Local p:TPixmap = ReadRenderImage(output)
						CheckTone(p, values, exposure, gamma)
						CheckTone(p, values, exposure, gamma, 6)
					Next
				Next
				tone.SetExposure(0)
				tone.SetGamma(1)
				DrawImageEffect(source, tone, 0, 0)
				tone.SetExposure(1)
				DrawImageEffect(source, tone, 6, 0)
				Local p:TPixmap = ReadRenderImage(output)
				CheckTone(p, values, 0, 1)
				CheckTone(p, values, 1, 1, 6)
				Local positions:Float[] = [0.0, 0.0, 6.0, 0.0]
				ResetMax2DStats()
				DrawImageEffectBatch(source, tone, positions)
				Local stats:TMax2DStats = CaptureMax2DStats()
				Check(stats.submissions = 1 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "tone batch cost")
				p = ReadRenderImage(output)
				CheckTone(p, values, 1, 1)
				CheckTone(p, values, 1, 1, 6)
				SetClsColor(0, 0, 0, 0)
				Cls
				SetBlend(CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA))
				SetColor(128, 128, 128)
				SetAlpha(0.5)
				tone.SetGamma(2.2)
				DrawImageEffect(source, tone, 0, 0)
				CheckTone(ReadRenderImage(output), values, 1, 2.2, 0, 128/255.0, 0.5)
				SetColor(255, 255, 255)
				SetAlpha(1)
				SetBlend(SOLIDBLEND)
				Local bright:TMax2DBrightPassEffect = CreateBrightPassEffect(1.5)
				SetRenderImage(extracted)
				DrawImageEffect(source, bright, 0, 0)
				Local data:TTextureData = ReadRenderTextureData(extracted)
				Local lum:Float = 8*0.2126+2*0.7152+0.5*0.0722
				Check(Abs(Channel(data, 1, 0, 0)-8) < 0.02, "bright pass retains HDR colour")
				Check(Abs(Channel(data, 1, 0, 3)-0.5*(lum-1.5)/lum) < 0.002, "HDR threshold alpha")
				tone.SetGamma(1)
				DrawImageEffect(source, tone, 0, 0)
				data = ReadRenderTextureData(extracted)
				Check(Abs(Channel(data, 0, 0, 0)-0.75) < 0.002, "float tone-map output")
				DrawImage(source, 0, 0)
				Check(Abs(Channel(ReadRenderTextureData(extracted), 0, 0, 0)-3) < 0.002, "ordinary HDR draw after tone map")

				Local scene:TRenderImage = CreateRenderImage(32, 32, FILTEREDIMAGE, format)
				Local highlights:TRenderImage = CreateRenderImage(32, 32, FILTEREDIMAGE, format)
				Local glow:TRenderImage = CreateRenderImage(32, 32, FILTEREDIMAGE, format)
				Local composite:TRenderImage = CreateRenderImage(32, 32, FILTEREDIMAGE, format)
				Local display:TRenderImage = CreateRenderImage(32, 32, 0)
				Local levels:TRenderImage[] = [CreateRenderImage(16, 16, FILTEREDIMAGE, format), CreateRenderImage(8, 8, FILTEREDIMAGE, format)]
				Local scratch:TRenderImage = CreateRenderImage(8, 8, FILTEREDIMAGE, format)
				SetRenderImage(scene)
				SetClsColor(0, 0, 0, 1)
				Cls
				DrawSubImageRect(image, 12, 12, 8, 8, 0, 0, 1, 1)
				bright.SetThreshold(1)
				Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(bright)]
				Local blur:TMax2DScaledBlur = CreateScaledBlur(8)
				ApplyLayerEffects(scene, highlights, chain)
				blur.Apply(highlights, glow, levels, scratch)
				SetRenderImage(composite)
				SetBlend(SOLIDBLEND)
				DrawImage(scene, 0, 0)
				SetBlend(LIGHTBLEND)
				DrawImage(glow, 0, 0)
				data = ReadRenderTextureData(composite)
				Check(Channel(data, 16, 16, 0) > 3, "HDR bloom accumulates above white")
				Check(Channel(data, 11, 16, 0) > 0, "HDR halo extends beyond source")
				Check(Abs(Channel(data, 11, 16, 3)-1) < 0.002, "opaque composite retains halo coverage")
				SetRenderImage(display)
				SetBlend(SOLIDBLEND)
				tone.SetExposure(1)
				tone.SetGamma(2.2)
				DrawImageEffect(composite, tone, 0, 0)
				ResetMax2DStats()
				ApplyLayerEffects(scene, highlights, chain)
				blur.Apply(highlights, glow, levels, scratch)
				SetRenderImage(composite)
				SetBlend(SOLIDBLEND)
				DrawImage(scene, 0, 0)
				SetBlend(LIGHTBLEND)
				DrawImage(glow, 0, 0)
				SetRenderImage(display)
				SetBlend(SOLIDBLEND)
				DrawImageEffect(composite, tone, 0, 0)
				stats = CaptureMax2DStats()
				Check(stats.submissions = 9 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "warmed HDR rebuild and mapped display cost")
				p = ReadRenderImage(display)
				For Local y:Int = 0 Until 32
					For Local x:Int = 0 Until 32
						For Local c:Int = 0 Until 3
							Local expected:Float = Mapped(Channel(data, x, y, c), 1, 2.2)*255
							Check(Abs(((p.ReadPixel(x, y) Shr (16-c*8)) & 255)-expected) <= 2, "HDR bloom display reference")
						Next
					Next
				Next
			Next
		Next
		SetRenderImage(Null)
		EndGraphics
	Next
	Print "hdr_bloom passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
