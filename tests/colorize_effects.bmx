SuperStrict

?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Effects
Import BRL.StandardIO

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function

Function Pixel(p:TPixmap, x:Int, y:Int, r:Int, g:Int, b:Int, a:Int)
	Local value:Int = p.ReadPixel(x, y)
	Check(Abs(((value Shr 24) & 255) - a) <= 1, "alpha at " + x + "," + y)
	If a Then Check(Abs(((value Shr 16) & 255) - r) <= 4 And Abs(((value Shr 8) & 255) - g) <= 4 And Abs((value & 255) - b) <= 4, "RGB at " + x + "," + y + " actual=" + ((value Shr 16) & 255) + "," + ((value Shr 8) & 255) + "," + (value & 255) + " expected=" + r + "," + g + "," + b)
End Function

Try
	Local effect:TMax2DColorizeEffect = CreateColorizeEffect(40, 160, 240)
	Local rejected:Int
	Try
		effect.SetColor(80, -1, 40)
	Catch error:Object
		rejected = True
	End Try
	Local r:Int, g:Int, b:Int
	effect.GetColor(r, g, b)
	Check(rejected And r = 40 And g = 160 And b = 240, "atomic colour validation")
	For Local lifetime:Int = 0 Until 2
		Check(Graphics(64, 64, 0, 0) <> Null, "graphics creation")
		If Not Max2DSupportsImageEffect(effect) Then
?max2d_sdlgpu
			Throw "native colourize unavailable: " + SDL_GetError()
?max2d_gl
			Throw "OpenGL effect provider unavailable"
?Not max2d_sdlgpu And Not max2d_gl
			EndGraphics
			Print "colorize_effects passed: unsupported provider reported"
			End
?
		End If
?max2d_sdlgpu
		Print "colorize_effects driver=" + SDLGPUMax2DDriverName()
?
		Local image:TImage = CreateImage(17, 17, 1, DYNAMICIMAGE)
		Local p:TPixmap = LockImage(image)
		p.ClearPixels($0000ff00)
		p.WritePixel(8, 8, $80ff0000)
		p.WritePixel(9, 8, $800000ff)
		UnlockImage(image)
		Local source:TRenderImage = CreateRenderImage(17, 17, FILTEREDIMAGE)
		Local result:TRenderImage = CreateRenderImage(40, 20, 0)
		Local output:TRenderImage = CreateRenderImage(17, 17, 0)
		Local scratch:TRenderImage = CreateRenderImage(17, 17, 0)
		SetRenderImage(source)
		SetBlend(SOLIDBLEND)
		DrawImage(image, 0, 0)
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			SetRenderImage(result)
			SetColor(255, 255, 255)
			SetAlpha(1)
			effect.SetColor(40, 160, 240)
			DrawImageEffect(image, effect, 0, 0)
			DrawImageEffect(source, effect, 20, 0)
			p = ReadRenderImage(result)
			Pixel(p, 8, 8, 40, 160, 240, 128)
			Pixel(p, 9, 8, 40, 160, 240, 128)
			Pixel(p, 28, 8, 40, 160, 240, 128)
			Pixel(p, 0, 0, 0, 0, 0, 0)
			SetColor(128, 255, 255)
			SetAlpha(0.5)
			DrawImageEffect(source, effect, 0, 0)
			effect.SetColor(240, 80, 40)
			DrawImageEffect(source, effect, 20, 0)
			p = ReadRenderImage(result)
			Pixel(p, 8, 8, 20, 160, 240, 64)
			Pixel(p, 28, 8, 120, 80, 40, 64)
			SetColor(255, 255, 255)
			SetAlpha(1)
			Local positions:Float[] = [0.0, 0.0, 20.0, 0.0]
			ResetMax2DStats()
			DrawImageEffectBatch(source, effect, positions)
			Local stats:TMax2DStats = CaptureMax2DStats()
			Check(stats.submissions = 1 And stats.textureCreations = 0 And stats.readbacks = 0, "colour batch uses one submission")
			p = ReadRenderImage(result)
			Pixel(p, 8, 8, 240, 80, 40, 128)
			Pixel(p, 28, 8, 240, 80, 40, 128)
			SetClsColor(0, 0, 0, 0)
			Cls
			Local blend:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA)
			SetBlend(blend)
			DrawImageEffect(source, effect, 0, 0)
			DrawImage(source, 20, 0)
			p = ReadRenderImage(result)
			Pixel(p, 8, 8, 240, 80, 40, 128)
			Pixel(p, 28, 8, 255, 0, 0, 128)
			Check(GetBlend() = blend And GetAlpha() = 1, "effect preserves drawing state")
			SetBlend(SOLIDBLEND)
			effect.SetColor(255, 0, 255)
			Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(effect), TMax2DImageEffect(CreateBlurEffect(4)), TMax2DImageEffect(CreateBlurEffect(4, False))]
?max2d_gl
			' A mixed chain must reject the unsupported blur before writing output.
			SetRenderImage(output); SetClsColor(0,255,0,1); Cls
			rejected=False
			Try
				ApplyLayerEffects(source,output,chain,scratch)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"OpenGL blur remains unsupported")
			p=ReadRenderImage(output)
			Pixel(p,8,8,0,255,0,255)
			ApplyLayerEffects(source,output,[TMax2DImageEffect(effect)])
			p=ReadRenderImage(output)
			Pixel(p,8,8,255,0,255,128)
?Not max2d_gl
			ApplyLayerEffects(source, output, chain, scratch)
			p = ReadRenderImage(output)
			Pixel(p, 8, 8, 255, 0, 255, 17)
?
		Next
		SetRenderImage(Null)
		EndGraphics
	Next
	Print "colorize_effects passed"
Catch error:Object
	Print "FAILED: " + error.ToString()
	EndWithCode(1)
End Try
