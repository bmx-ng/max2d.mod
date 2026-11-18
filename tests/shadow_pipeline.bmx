SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Effects
Import BRL.StandardIO
Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
Try
	Local shadow:TMax2DShadow = CreateShadow(4)
	Local weights:Int[] = [1, 8, 28, 56, 70, 56, 28, 8, 1]
	For Local lifetime:Int = 0 Until 2
		Graphics(64, 64)
		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		If Not Max2DSupportsImageEffect(CreateColorizeEffect()) Then
			shadow.Prepare(17, 17, 0)
			Local unsupported:TRenderImage = CreateRenderImage(17, 17)
			Local rejected:Int
			Try
				shadow.Update(unsupported)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected And canvas.renderImage = Null, "unsupported shadow restores window")
			shadow.Release()
			EndGraphics
			Exit
		End If
		shadow.SetRadius(4)
		shadow.Prepare(17, 17, 0, PF_RGBA32F)
		Local source:TRenderImage = CreateRenderImage(17, 17, 0, PF_RGBA32F)
		SetRenderImage(source)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetBlend(SOLIDBLEND)
		SetColor(255, 0, 0)
		SetAlpha(0.5)
		DrawRect(8, 8, 1, 1)
		Local sourceBefore:TTextureData = ReadRenderTextureData(source)
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			SetColor(20, 40, 60)
			SetAlpha(0.25)
			SetOrigin(3, 4)
			Local result:TRenderImage = shadow.Update(source)
			Check(canvas.renderImage = source, "target restored")
			Local r:Int, g:Int, b:Int
			GetColor(r, g, b)
			Check(r = 20 And g = 40 And b = 60 And GetAlpha() = 0.25, "tint and opacity restored")
			Local pixels:TTextureData = ReadRenderTextureData(result)
			Local p:Float Ptr = Float Ptr(pixels.Level().Data())
			For Local y:Int = 0 Until 17
				For Local x:Int = 0 Until 17
					Local expected:Float
					If x >= 4 And x <= 12 And y >= 4 And y <= 12 Then expected = Float(weights[x-4]*weights[y-4])/131072
					Local i:Int = (y*17+x)*4
					Check(Abs(p[i+3]-expected) < 0.00001, "shadow alpha matches independent kernel")
					If expected > 0 Then Check(Abs(p[i]-1) < 0.00001 And Abs(p[i+1]-1) < 0.00001 And Abs(p[i+2]-1) < 0.00001, "shadow ignores source RGB")
				Next
			Next
			ResetMax2DStats()
			shadow.Update(source)
			Local stats:TMax2DStats = CaptureMax2DStats()
			Check(stats.submissions = 3 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "full resolution steady-state cost")
			shadow.Prepare(17, 17, 0, PF_RGBA32F)
			Check(shadow.Result() = result, "identical prepare retains result")
			shadow.SetRadius(100)
			Local rejected:Int
			Try
				shadow.Update(source)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected And shadow.Result() = result, "invalid radius preserves cache")
			shadow.SetRadius(4)
		Next
		SetOrigin(0, 0)
		Local sourceAfter:TTextureData = ReadRenderTextureData(source)
		Local before:Float Ptr = Float Ptr(sourceBefore.Level().Data()), after:Float Ptr = Float Ptr(sourceAfter.Level().Data())
		For Local i:Int = 0 Until 17*17*4
			Check(before[i] = after[i], "source pixels preserved")
		Next
		shadow.SetRadius(8)
		shadow.Prepare(17, 17, 2, PF_RGBA32F)
		Local rejected:Int
		Try
			shadow.Result()
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "layout change invalidates cache")
		shadow.Update(source)
		ResetMax2DStats()
		shadow.Update(source)
		Local stats:TMax2DStats = CaptureMax2DStats()
		Check(stats.submissions = 6 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "reduced steady-state cost")
		ResetMax2DStats()
		shadow.Result()
		stats = CaptureMax2DStats()
		Check(stats.submissions = 0, "cached result performs no draws")
		' Colour, opacity and offset are ordinary draws of the same cached white mask.
		SetRenderImage(Null)
		SetClsColor(0, 0, 0)
		Cls
		SetBlend(ALPHABLEND)
		SetColor(0, 0, 255)
		SetAlpha(0.5)
		DrawImage(shadow.Result(), 10, 10)
		Local nw:Int = NativeResolutionWidth(), nh:Int = NativeResolutionHeight()
		Local windowPixels:TPixmap = GrabPixmap(0, 0, nw, nh)
		Local pixel:Int = windowPixels.ReadPixel(18*nw/64, 18*nh/64)
		Check((pixel & $ffff00) = 0 And (pixel & 255) > 0, "cached shadow accepts tint opacity and offset")
		EndGraphics
	Next
	shadow.Release()
	shadow.Release()
	Print "shadow_pipeline passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
