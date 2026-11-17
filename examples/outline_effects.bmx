SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects

AppTitle = "Max2D alpha outlines"
Graphics(1000, 430)
Local outline:TMax2DOutlineEffect = CreateOutlineEffect(2)
Local colour:TMax2DColorizeEffect = CreateColorizeEffect(90, 220, 255)
Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(outline), TMax2DImageEffect(colour)]
Local supported:Int = Max2DSupportsImageEffect(outline) And Max2DSupportsRenderImage(120, 100, FILTEREDIMAGE)
Local source:TRenderImage, mask:TRenderImage, result:TRenderImage
Local dirty:Int = True, warm:Int
If supported Then
	source = CreateRenderImage(120, 100, FILTEREDIMAGE)
	mask = CreateRenderImage(120, 100, FILTEREDIMAGE)
	result = CreateRenderImage(120, 100, FILTEREDIMAGE)
	SetRenderImage(source)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(245, 100, 55)
	DrawOval(14, 14, 62, 68)
	SetColor(70, 150, 240)
	DrawRect(50, 38, 52, 44)
	SetColor(255, 225, 75)
	DrawRect(42, 24, 28, 28)
	SetRenderImage(Null)
End If
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local change:Int
	If KeyHit(KEY_LEFT) Then change = -1
	If KeyHit(KEY_RIGHT) Then change = 1
	If change Then
		outline.SetRadius(Max(0, Min(4, outline.GetRadius()+change)))
		dirty = True
	End If
	If KeyHit(KEY_SPACE) Then
		warm = Not warm
		If warm Then colour.SetColor(255, 100, 180) Else colour.SetColor(90, 220, 255)
		dirty = True
	End If
	If supported And dirty Then
		ApplyLayerEffects(source, result, chain, mask)
		dirty = False
	End If
	SetClsColor(24, 29, 39)
	Cls
	SetColor(255, 255, 255)
	DrawText("Alpha outline | Radius: "+outline.GetRadius()+" source pixels", 25, 25)
	If supported Then
		DrawText("Original", 25, 75)
		DrawText("Outline mask", 350, 75)
		DrawText("Coloured outline + original", 675, 75)
		SetScale(2.4, 2.4)
		DrawImage(source, 25, 110)
		DrawImage(mask, 350, 110)
		DrawImage(result, 675, 110)
		DrawImage(source, 675, 110)
		SetScale(1, 1)
	Else
		DrawText("The required outline shader or render images are unavailable.", 25, 110)
	End If
	DrawText("Arrows: radius 0-4. Space: outline colour. Escape: exit. Outputs are cached.", 25, 390)
	Flip
Wend
EndGraphics
