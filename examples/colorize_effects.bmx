SuperStrict

Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects

AppTitle = "Max2D silhouettes, shadows and glow"
Graphics(960, 410)

Local colour:TMax2DColorizeEffect = CreateColorizeEffect(70, 200, 255)
Local horizontal:TMax2DBlurEffect = CreateBlurEffect(4)
Local vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)
Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(colour), TMax2DImageEffect(horizontal), TMax2DImageEffect(vertical)]
Local supported:Int = Max2DSupportsImageEffect(colour) And Max2DSupportsImageEffect(horizontal) And Max2DSupportsRenderImage(120, 100, FILTEREDIMAGE)
Local source:TRenderImage, scratch:TRenderImage, shadow:TRenderImage, glow:TRenderImage
Local dirty:Int = True
Local warm:Int
If supported Then
	source = CreateRenderImage(120, 100, FILTEREDIMAGE)
	scratch = CreateRenderImage(120, 100, FILTEREDIMAGE)
	shadow = CreateRenderImage(120, 100, FILTEREDIMAGE)
	glow = CreateRenderImage(120, 100, FILTEREDIMAGE)
	Local scope:TMax2DStateScope = ScopedMax2DState()
	Try
		SetRenderImage(source)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetColor(245, 100, 55)
		DrawOval(12, 12, 72, 72)
		SetColor(70, 170, 240)
		DrawRect(48, 35, 58, 48)
		SetColor(255, 215, 75)
		DrawRect(38, 24, 30, 34)
	Finally
		scope.Close()
	End Try
End If

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local change:Float
	If KeyHit(KEY_LEFT) Then change = -0.5
	If KeyHit(KEY_RIGHT) Then change = 0.5
	If change Then
		horizontal.SetRadius(Float(Max(0.0, Min(4.0, horizontal.GetRadius() + change))))
		vertical.SetRadius(horizontal.GetRadius())
		dirty = True
	End If
	If KeyHit(KEY_SPACE) Then
		warm = Not warm
		dirty = True
	End If
	If supported And dirty Then
		colour.SetColor(0, 0, 0)
		ApplyLayerEffects(source, shadow, chain, scratch)
		If warm Then
			colour.SetColor(255, 100, 45)
		Else
			colour.SetColor(70, 200, 255)
		End If
		ApplyLayerEffects(source, glow, chain, scratch)
		dirty = False
	End If
	SetClsColor(44, 49, 59)
	Cls
	SetColor(255, 255, 255)
	DrawText("Silhouettes + two-pass blur | Radius: " + horizontal.GetRadius(), 25, 25)
	If supported Then
		DrawText("Original", 25, 75)
		DrawText("Soft offset shadow", 340, 75)
		DrawText("Coloured glow", 655, 75)
		SetScale(2.4, 2.4)
		SetBlend(ALPHABLEND)
		DrawImage(source, 20, 105)
		SetAlpha(0.8)
		DrawImage(shadow, 347, 117)
		SetAlpha(1)
		DrawImage(source, 335, 105)
		SetBlend(LIGHTBLEND)
		DrawImage(glow, 650, 105)
		SetBlend(ALPHABLEND)
		DrawImage(source, 650, 105)
		SetScale(1, 1)
	Else
		DrawText("This device does not support the required shaders and render images.", 25, 105)
	End If
	DrawText("Arrows: radius. Space: cool / warm glow. Escape: exit. Outputs are cached.", 25, 375)
	Flip
Wend
EndGraphics
