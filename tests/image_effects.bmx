SuperStrict

?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
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

Function Pixel(pixels:TPixmap, x:Int, red:Int, green:Int, blue:Int, alpha:Int, message:String)
	Local value:Int = pixels.ReadPixel(x, 1)
	Check(Abs(((value Shr 16) & 255) - red) <= 3 And Abs(((value Shr 8) & 255) - green) <= 3 And Abs((value & 255) - blue) <= 3 And Abs(((value Shr 24) & 255) - alpha) <= 2, message)
End Function

Try
	Local effect:TMax2DSaturationEffect = CreateSaturationEffect(0)
	Local rejected:Int
	Try
		effect.SetAmount(-1)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And effect.GetAmount() = 0, "invalid parameter leaves previous value")

	For Local lifetime:Int = 0 Until 2
		Check(Graphics(64, 32, 0, 0) <> Null, "graphics creation failed")
?max2d_sdlgpu
		Print "image_effects driver=" + SDLGPUMax2DDriverName()
?
		Local image:TImage = CreateImage(4, 4, 1, DYNAMICIMAGE)
		Local pixels:TPixmap = LockImage(image)
		pixels.ClearPixels($80c86432)
		UnlockImage(image)
		If Not Max2DSupportsImageEffect(effect) Then
?max2d_sdlgpu
			Throw "SDL GPU saturation effect unavailable: " + SDL_GetError()
?Not max2d_sdlgpu
			rejected = False
			Try
				DrawImageEffect(image, effect, 0, 0)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected, "unsupported shader effect rejected")
			EndGraphics
			Print "image_effects passed: unsupported provider rejected"
			End
?
		End If

		Local source:TRenderImage = CreateRenderImage(4, 4, 0)
		SetRenderImage(source)
		SetClsColor(0, 0, 0, 0)
		Cls
		DrawImage(image, 0, 0)
		Local target:TRenderImage = CreateRenderImage(24, 8, 0)
		SetRenderImage(target)

		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			SetBlend(ALPHABLEND)
			SetColor(255, 255, 255)
			SetAlpha(1)
			Cls
			effect.SetAmount(0)
			Check(Max2DSupportsImageEffect(effect), "current submission path supported")
			DrawImageEffect(image, effect, 0, 0)
			effect.SetAmount(1)
			DrawImageEffect(image, effect, 4, 0)
			DrawImage(image, 8, 0)
			effect.SetAmount(0)
			DrawImageEffect(source, effect, 12, 0)
			Local blend:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA)
			SetBlend(blend)
			DrawImageEffect(source, effect, 16, 0)
			pixels = ReadRenderImage(target)
			Pixel(pixels, 1, 118, 118, 118, 128, "grayscale captured before parameter mutation")
			Pixel(pixels, 5, 200, 100, 50, 128, "identity saturation")
			Pixel(pixels, 9, 200, 100, 50, 128, "ordinary draw after effect")
			Pixel(pixels, 13, 118, 118, 118, 128, "premultiplied source")
			Pixel(pixels, 17, 118, 118, 118, 128, "custom blend receives straight shader colour")
			Check(GetBlend() = blend And GetAlpha() = 1, "drawing state retained")

			ResetMax2DStats()
			DrawImageEffect(image, effect, 0, 4)
			Local stats:TMax2DStats = CaptureMax2DStats()
			Check(stats.submissions = 1 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "warmed effect is one draw without texture allocation, upload or readback")

			rejected = False
			Try
				DrawImageEffect(target, effect, 0, 0)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected, "target feedback rejected")
			rejected = False
			Try
				DrawImageEffect(image, effect, 0, 0, 999)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected, "invalid frame rejected")
			DrawImage(image, 20, 0)
			pixels = ReadRenderImage(target)
			Pixel(pixels, 21, 200, 100, 50, 128, "failed effect leaves ordinary rendering usable")

			Cls
			SetBlend(ALPHABLEND)
			DrawImage(image, 8, 0)
			DrawImageEffectBatch(image, effect, [Float(0), Float(0), Float(4), Float(0)])
			effect.SetAmount(1)
			DrawImage(image, 12, 0)
			pixels = ReadRenderImage(target)
			Pixel(pixels, 1, 118, 118, 118, 128, "first batch position")
			Pixel(pixels, 5, 118, 118, 118, 128, "second batch position and parameter snapshot")
			Pixel(pixels, 9, 200, 100, 50, 128, "ordinary draw before batch")
			Pixel(pixels, 13, 200, 100, 50, 128, "ordinary draw after batch")
			Local positions:Float[200]
			ResetMax2DStats()
			DrawImageEffectBatch(image, effect, positions)
			stats = CaptureMax2DStats()
			Check(stats.submissions = 1 And stats.vertices = 600 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "100 effect sprites share one warmed submission")
			ResetMax2DStats()
			DrawImageEffectBatch(image, effect, New Float[0])
			rejected = False
			Try
				DrawImageEffectBatch(image, effect, New Float[3])
			Catch error:Object
				rejected = True
			End Try
			Check(rejected And CaptureMax2DStats().submissions = 0, "empty and malformed batches submit nothing")
?max2d_sdlgpu
			Local stride:Int = 48
			If compact Then stride = 16
			Local capacity:Int = TMax2DGraphics.Current().context.batch.Length / stride
			positions = New Float[(capacity + 1) * 2]
			positions[capacity * 2] = 20
			effect.SetAmount(0)
			Cls
			ResetMax2DStats()
			DrawImageEffectBatch(image, effect, positions)
			stats = CaptureMax2DStats()
			Check(stats.submissions = 2 And stats.vertices = (capacity + 1) * 6, "effect batch splits at buffer capacity")
			pixels = ReadRenderImage(target)
			Pixel(pixels, 21, 118, 118, 118, 128, "effect survives buffer-capacity flush")
?
		Next
		SetRenderImage(Null)
		EndGraphics
	Next
	Print "image_effects passed"
Catch error:Object
	Print "FAILED: " + error.ToString()
	EndWithCode(1)
End Try
