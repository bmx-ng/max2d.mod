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

Function CheckExtract(p:TPixmap, input:TPixmap, threshold:Float, offset:Int = 0, tr:Float = 1, tg:Float = 1, tb:Float = 1, opacity:Float = 1)
	For Local y:Int = 0 Until 2
		For Local x:Int = 0 Until 8
			Local value:Int = input.ReadPixel(x, y)
			Local r:Float = ((value Shr 16) & 255)*tr, g:Float = ((value Shr 8) & 255)*tg, b:Float = (value & 255)*tb
			Local luminance:Float = (r*0.2126+g*0.7152+b*0.0722)/255
			Local weight:Float
			If luminance > 0 Then weight = Max(0.0, luminance-threshold)/luminance
			Local a:Float = ((value Shr 24) & 255)*opacity*weight
			Local pixel:Int = p.ReadPixel(x+offset, y), actualAlpha:Int = (pixel Shr 24) & 255
			Check(Abs(actualAlpha-a) <= 2, "extraction alpha at "+x+","+y+" actual="+actualAlpha+" expected="+a)
			' Compare premultiplied energy to avoid magnifying 8-bit low-alpha rounding.
			Check(Abs(((pixel Shr 16) & 255)*actualAlpha/255.0-r*a/255.0) <= 2 And Abs(((pixel Shr 8) & 255)*actualAlpha/255.0-g*a/255.0) <= 2 And Abs((pixel & 255)*actualAlpha/255.0-b*a/255.0) <= 2, "extraction colour energy")
		Next
	Next
End Function

Try
	Local bright:TMax2DBrightPassEffect = CreateBrightPassEffect(0.5)
	Local rejected:Int
	Try
		bright.SetThreshold(-1)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And bright.GetThreshold() = 0.5, "threshold validation")
	For Local lifetime:Int = 0 Until 2
		Check(Graphics(80, 60, 0, 0) <> Null, "graphics creation")
		If Not Max2DSupportsImageEffect(bright) Then
?max2d_sdlgpu
			Throw "bright pass unavailable: "+SDL_GetError()
?max2d_gl Or max2d_d3d11 Or max2d_d3d9
			Throw "Native effect unavailable"
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d11 And Not max2d_d3d9
			EndGraphics
			Print "bloom_effects passed: unsupported provider reported"
			End
?
		End If
?max2d_sdlgpu
		Print "bloom_effects driver="+SDLGPUMax2DDriverName()
?
		Local image:TImage = CreateImage(8, 2, 1, DYNAMICIMAGE)
		Local input:TPixmap = LockImage(image)
		Local colours:Int[] = [$000000, $404040, $808080, $c0c0c0, $ffffff, $ff0000, $00ff00, $0000ff]
		For Local x:Int = 0 Until 8
			input.WritePixel(x, 0, $ff000000 | colours[x])
			input.WritePixel(x, 1, $80000000 | colours[x])
		Next
		Local reference:TPixmap = input.Copy()
		UnlockImage(image)
		Local source:TRenderImage = CreateRenderImage(8, 2, 0)
		Local target:TRenderImage = CreateRenderImage(20, 2, 0)
		SetRenderImage(source)
		SetBlend(SOLIDBLEND)
		DrawImage(image, 0, 0)
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			SetRenderImage(target)
			SetBlend(SOLIDBLEND)
			SetColor(255, 255, 255)
			SetAlpha(1)
			Local thresholds:Float[] = [0.0, 0.25, 0.5, 1.0, 2.0]
			For Local threshold:Float = EachIn thresholds
				bright.SetThreshold(threshold)
				DrawImageEffect(image, bright, 0, 0)
				DrawImageEffect(source, bright, 10, 0)
				Local pixels:TPixmap = ReadRenderImage(target)
				CheckExtract(pixels, reference, threshold)
				CheckExtract(pixels, reference, threshold, 10)
			Next
			bright.SetThreshold(0)
			DrawImageEffect(source, bright, 0, 0)
			bright.SetThreshold(0.5)
			DrawImageEffect(source, bright, 10, 0)
			Local pixels:TPixmap = ReadRenderImage(target)
			CheckExtract(pixels, reference, 0)
			CheckExtract(pixels, reference, 0.5, 10)
			Local positions:Float[] = [0.0, 0.0, 10.0, 0.0]
			ResetMax2DStats()
			DrawImageEffectBatch(source, bright, positions)
			Local stats:TMax2DStats = CaptureMax2DStats()
			Check(stats.submissions = 1 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "batched extraction reuses storage")
			pixels = ReadRenderImage(target)
			CheckExtract(pixels, reference, 0.5)
			CheckExtract(pixels, reference, 0.5, 10)
			SetClsColor(0, 0, 0, 0)
			Cls
			Local blend:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA)
			SetBlend(blend)
			SetColor(128, 255, 64)
			SetAlpha(0.5)
			bright.SetThreshold(0.2)
			DrawImageEffect(source, bright, 0, 0)
			CheckExtract(ReadRenderImage(target), reference, 0.2, 0, 128/255.0, 1, 64/255.0, 0.5)
			Check(GetBlend() = blend And GetAlpha() = 0.5, "extraction retains drawing state")
			SetColor(255, 255, 255)
			SetAlpha(1)
			SetBlend(SOLIDBLEND)
			DrawImage(source, 10, 0)
			pixels = ReadRenderImage(target)
			Check(((pixels.ReadPixel(0+10, 0) Shr 24) & 255) = 255, "ordinary black remains opaque after effect")

			Local scene:TRenderImage = CreateRenderImage(32, 32, FILTEREDIMAGE)
			Local highlights:TRenderImage = CreateRenderImage(32, 32, FILTEREDIMAGE)
			Local glow:TRenderImage = CreateRenderImage(32, 32, FILTEREDIMAGE)
			Local levels:TRenderImage[] = [CreateRenderImage(16, 16, FILTEREDIMAGE), CreateRenderImage(8, 8, FILTEREDIMAGE)]
			Local scratch:TRenderImage = CreateRenderImage(8, 8, FILTEREDIMAGE)
			Local composite:TRenderImage = CreateRenderImage(32, 32, 0)
			SetRenderImage(scene)
			SetClsColor(0, 0, 0, 0)
			Cls
			DrawRect(12, 12, 8, 8)
			bright.SetThreshold(0.5)
			Local extraction:TMax2DImageEffect[] = [TMax2DImageEffect(bright)]
			Local blur:TMax2DScaledBlur = CreateScaledBlur(8)
			ApplyLayerEffects(scene, highlights, extraction)
			blur.Apply(highlights, glow, levels, scratch)
			ResetMax2DStats()
			ApplyLayerEffects(scene, highlights, extraction)
			blur.Apply(highlights, glow, levels, scratch)
			stats = CaptureMax2DStats()
			Check(stats.submissions = 6 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "bloom rebuild uses extraction plus five blur passes")
			Local bloomPixels:TPixmap = ReadRenderImage(glow)
			Check(((bloomPixels.ReadPixel(11, 16) Shr 24) & 255) > 0, "bloom extends outside bright source")
			SetRenderImage(composite)
			SetClsColor(16, 24, 32, 1)
			Cls
			SetBlend(ALPHABLEND)
			DrawImage(scene, 0, 0)
			Local before:TPixmap = ReadRenderImage(composite)
			SetBlend(LIGHTBLEND)
			DrawImage(glow, 0, 0)
			pixels = ReadRenderImage(composite)
			For Local y:Int = 0 Until 32
				For Local x:Int = 0 Until 32
					Local a:Int = (bloomPixels.ReadPixel(x, y) Shr 24) & 255
					For Local shift:Int = 0 To 16 Step 8
						Local expected:Float = Min(255.0, ((before.ReadPixel(x, y) Shr shift) & 255) + ((bloomPixels.ReadPixel(x, y) Shr shift) & 255)*a/255.0)
						Check(Abs(((pixels.ReadPixel(x, y) Shr shift) & 255)-expected) <= 2, "additive bloom applies energy once")
					Next
				Next
			Next
		Next
		SetRenderImage(Null)
		EndGraphics
	Next
	Print "bloom_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
