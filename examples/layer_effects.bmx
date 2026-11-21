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

Const layerWidth:Int = 240
Const layerHeight:Int = 160

AppTitle = "Max2D layer masks and cutouts"
Graphics(720, 400)

Local supported:Int = Max2DSupportsRenderImage(layerWidth, layerHeight, 0) And Max2DSupportsLayerAlpha()
Local layer:TRenderImage
Local mask:TImage

If supported Then
	layer = CreateRenderImage(layerWidth, layerHeight, 0)
	mask = CreateImage(layerWidth, layerHeight, 1, DYNAMICIMAGE)
	Local pixels:TPixmap = LockImage(mask)
	For Local y:Int = 0 Until layerHeight
		For Local x:Int = 0 Until layerWidth
			Local dx:Float = (x - layerWidth / 2.0) / (layerWidth / 2.0)
			Local dy:Float = (y - layerHeight / 2.0) / (layerHeight / 2.0)
			Local coverage:Float = Min(1.0, Max(0.0, (1.0 - Sqr(dx * dx + dy * dy)) * 5.0))
			pixels.WritePixel(x, y, (Int(coverage * 255) Shl 24) | $ffffff)
		Next
	Next
	UnlockImage(mask)
End If

Local opacity:Float = 0.8
Local inverse:Int
Local inverseSupported:Int = Max2DSupportsLayerInverseAlpha()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_SPACE) And inverseSupported Then inverse = Not inverse
	If KeyDown(KEY_UP) Then opacity = Min(1.0, opacity + 0.01)
	If KeyDown(KEY_DOWN) Then opacity = Max(0.0, opacity - 0.01)

	SetClsColor(24, 29, 39)
	Cls
	SetColor(255, 255, 255)
	DrawText("Hard clip: nested viewports", 38, 36)
	Using
		Local clip:TMax2DStateScope = ScopedMax2DState()
	Do
		IntersectViewport(38, 80, layerWidth, layerHeight)
		IntersectViewport(70, 105, 175, 110)
		SetColor(80, 170, 225)
		DrawOval(20, 55, 275, 220)
		SetColor(255, 200, 85)
		DrawRect(55, 130, 230, 45)
	End Using

	If supported Then
		SetRenderImage(layer)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetColor(80, 170, 225)
		DrawOval(0, 0, layerWidth, layerHeight)
		SetColor(255, 200, 85)
		DrawRect(25, 50, 190, 60)
		If inverse Then
			ApplyLayerInverseAlphaMask(mask)
		Else
			ApplyLayerAlphaMask(mask)
		End If
		ApplyLayerOpacity(opacity)
		SetRenderImage(Null)

		SetColor(255, 255, 255)
		SetAlpha(1)
		Local label:String = "Soft mask + group opacity"
		If inverse Then label = "Inverse mask: soft cutout"
		DrawText(label, 370, 36)
		DrawImage(layer, 370, 80)
		DrawText("Up/Down: " + Int(opacity * 100) + "%", 370, 265)
		If inverseSupported Then DrawText("Space: normal/inverse mask", 370, 290)
	Else
		SetColor(255, 255, 255)
		DrawText("Layer alpha unavailable on this backend", 370, 100)
	End If
	Flip
Wend

EndGraphics
