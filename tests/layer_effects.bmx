SuperStrict

?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
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

Function CheckPixel(pixmap:TPixmap, x:Int, y:Int, red:Int, green:Int, blue:Int, alpha:Int)
	Local value:Int = pixmap.ReadPixel(x, y)
	Check(Abs(((value Shr 16) & 255) - red) <= 3, "red channel at " + x + "," + y)
	Check(Abs(((value Shr 8) & 255) - green) <= 3, "green channel at " + x + "," + y)
	Check(Abs((value & 255) - blue) <= 3, "blue channel at " + x + "," + y)
	Check(Abs(((value Shr 24) & 255) - alpha) <= 3, "alpha channel at " + x + "," + y)
End Function

Try
	Local graphics:TGraphics = Graphics(32, 32, 0, 0)
	Check(graphics <> Null, "graphics creation failed")
	Check(TMax2DGraphics(graphics) <> Null, "Max2D graphics driver selected")
	Local canRender:Int = Max2DSupportsRenderImage(8, 8, 0)
	Local canAlpha:Int = Max2DSupportsLayerAlpha()
	If canRender And Not canAlpha Then
		Local unsupportedLayer:TRenderImage = CreateRenderImage(8, 8, 0)
		SetRenderImage(unsupportedLayer)
		Local rejected:Int
		Try
			ApplyLayerOpacity(0.5)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected And TMax2DGraphics.Current().renderImage = unsupportedLayer, "unsupported operation rejected without changing target")
		SetRenderImage(Null)
	End If
	If Not canRender Or Not canAlpha Then
		Print "SKIP layer effects: backend lacks required render target or blend mode"
		EndGraphics
		Print "layer_effects passed"
		End
	End If

	Local layer:TRenderImage = CreateRenderImage(8, 8, 0)
	Local mask:TImage = CreateImage(8, 8, 1, DYNAMICIMAGE)
	Local pixels:TPixmap = LockImage(mask)
	pixels.ClearPixels($00000000)
	For Local y:Int = 0 Until 8
		For Local x:Int = 0 Until 4
			pixels.WritePixel(x, y, $80ffffff)
		Next
	Next
	UnlockImage(mask)

	SetRenderImage(layer)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(200, 100, 50)
	ResetMax2DStats()
	For Local i:Int = 0 Until 100
		DrawRect(0, 0, 8, 8)
	Next
	Local baseline:TMax2DStats = CaptureMax2DStats()
	Check(baseline.submissions = 1 And baseline.readbacks = 0, "plain drawing stays in one batch without readback")
	SetColor(10, 20, 30)
	SetAlpha(0.25)
	ResetMax2DStats()
	ApplyLayerAlphaMask(mask)
	Local masked:TMax2DStats = CaptureMax2DStats()
	Check(masked.submissions = 1 And masked.readbacks = 0, "mask uses one draw without readback")
	Local red:Int, green:Int, blue:Int
	GetColor(red, green, blue)
	Check(red = 10 And green = 20 And blue = 30, "layer effect restores drawing colour")
	Check(Abs(GetAlpha() - 0.25) < 0.001, "layer effect restores opacity")

	pixels = ReadRenderImage(layer)
	CheckPixel(pixels, 1, 1, 200, 100, 50, 128)
	CheckPixel(pixels, 6, 1, 0, 0, 0, 0)

	ResetMax2DStats()
	ApplyLayerOpacity(0.5)
	Local faded:TMax2DStats = CaptureMax2DStats()
	Check(faded.submissions = 1 And faded.textureCreations = 0 And faded.textureUpdates = 0 And faded.readbacks = 0, "opacity pass reuses resources")
	pixels = ReadRenderImage(layer)
	CheckPixel(pixels, 1, 1, 200, 100, 50, 64)

	Local rejected:Int
	Try
		ApplyLayerAlphaMask(layer)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected, "feedback hazard rejected")

	SetRenderImage(Null)
	EndGraphics
	Print "baseline batches=" + baseline.submissions + ", mask batches=" + masked.submissions + ", opacity batches=" + faded.submissions
	Print "layer_effects passed"
Catch error:Object
	Print "FAILED: " + error.ToString()
	EndWithCode(1)
End Try
