SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle = "Max2D image effects"
Graphics(940, 550)

Local grayscale:TMax2DSaturationEffect = CreateSaturationEffect(0)
Local adjustable:TMax2DSaturationEffect = CreateSaturationEffect(1.5)
Local supported:Int = Max2DSupportsImageEffect(grayscale) And Max2DSupportsLayerAlpha() And Max2DSupportsRenderImage(240, 160, 0)
Local positions:Float[200]
For Local i:Int = 0 Until 100
	positions[i * 2] = 35 + (i Mod 20) * 43
	positions[i * 2 + 1] = 355 + (i / 20) * 27
Next
Local layer:TRenderImage

If supported Then
	' The static group and its soft mask are built once and reused every frame.
	layer = CreateRenderImage(240, 160, 0)
	Local mask:TImage = CreateImage(240, 160, 1, DYNAMICIMAGE)
	Local pixels:TPixmap = LockImage(mask)
	For Local y:Int = 0 Until 160
		For Local x:Int = 0 Until 240
			Local dx:Float = (x - 119.5) / 120
			Local dy:Float = (y - 79.5) / 80
			Local alpha:Int = Int(255 * Min(1.0, Max(0.0, (1 - Sqr(dx * dx + dy * dy)) * 6)))
			pixels.WritePixel(x, y, (alpha Shl 24) | $ffffff)
		Next
	Next
	UnlockImage(mask)
	SetRenderImage(layer)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(65, 150, 210)
	DrawRect(0, 0, 240, 160)
	SetColor(235, 105, 65)
	DrawOval(0, 0, 155, 155)
	SetColor(245, 200, 75)
	DrawRect(90, 45, 150, 65)
	ApplyLayerAlphaMask(mask)
	SetRenderImage(Null)
	SetColor(255, 255, 255)
End If

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_LEFT) Then adjustable.SetAmount(Float(Max(0.0, adjustable.GetAmount() - 0.1)))
	If KeyHit(KEY_RIGHT) Then adjustable.SetAmount(Float(Min(3.0, adjustable.GetAmount() + 0.1)))
	SetClsColor(24, 29, 39)
	Cls
	SetColor(255, 255, 255)
	DrawText("One cached masked layer, three colour treatments", 35, 28)
	If supported Then
		DrawText("Original", 35, 75)
		DrawImage(layer, 35, 110)
		DrawText("Grayscale", 345, 75)
		DrawImageEffect(layer, grayscale, 345, 110)
		DrawText("Saturation: " + Int(adjustable.GetAmount() * 100) + "%", 655, 75)
		DrawImageEffect(layer, adjustable, 655, 110)
		FlushMax2D()
		ResetMax2DStats()
		SetScale(0.1, 0.1)
		DrawImageEffectBatch(layer, adjustable, positions)
		Local batches:Long = CaptureMax2DStats().submissions
		SetScale(1, 1)
		DrawText("100 miniatures: " + batches + " effect batch", 35, 315)
		DrawText("Left / Right adjusts saturation. Escape exits.", 35, 510)
	Else
		DrawText("This device does not support the required shader and layer operations.", 35, 110)
	End If
	Flip
Wend

EndGraphics
