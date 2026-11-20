SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?Not max2d_gl And Not max2d_d3d11 And Not max2d_d3d9
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle = "Max2D brightness extraction and bloom"
Graphics(1000, 430)
Local bright:TMax2DBrightPassEffect = CreateBrightPassEffect(0.55)
Local blur:TMax2DScaledBlur = CreateScaledBlur(12)
Local extraction:TMax2DImageEffect[] = [TMax2DImageEffect(bright)]
Local supported:Int = Max2DSupportsImageEffect(bright) And Max2DSupportsImageEffect(CreateBlurEffect()) And Max2DSupportsRenderImage(160, 128, FILTEREDIMAGE)
Local source:TRenderImage, highlights:TRenderImage, glow:TRenderImage, scratch:TRenderImage
Local levels:TRenderImage[]
Local dirty:Int = True, enabled:Int = True
If supported Then
	source = CreateRenderImage(160, 128, FILTEREDIMAGE)
	highlights = CreateRenderImage(160, 128, FILTEREDIMAGE)
	glow = CreateRenderImage(160, 128, FILTEREDIMAGE)
	levels = [CreateRenderImage(80, 64, FILTEREDIMAGE), CreateRenderImage(40, 32, FILTEREDIMAGE)]
	scratch = CreateRenderImage(40, 32, FILTEREDIMAGE)
	SetRenderImage(source)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(65, 85, 120)
	DrawRect(24, 40, 112, 64)
	SetColor(255, 240, 145)
	DrawOval(36, 28, 28, 28)
	SetColor(180, 240, 255)
	DrawRect(88, 31, 32, 13)
	SetColor(255, 255, 255)
	DrawRect(76, 62, 5, 29)
	DrawRect(64, 74, 29, 5)
	SetColor(120, 70, 90)
	DrawRect(38, 78, 13, 13)
	SetRenderImage(Null)
End If
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local change:Float
	If KeyHit(KEY_LEFT) Then change = -0.05
	If KeyHit(KEY_RIGHT) Then change = 0.05
	If change Then
		bright.SetThreshold(Float(Max(0.0, Min(1.0, bright.GetThreshold()+change))))
		dirty = True
	End If
	change = 0
	If KeyHit(KEY_DOWN) Then change = -4
	If KeyHit(KEY_UP) Then change = 4
	If change Then
		blur.SetRadius(Float(Max(4.0, Min(16.0, blur.GetRadius()+change))))
		dirty = True
	End If
	If KeyHit(KEY_SPACE) Then enabled = Not enabled
	If supported And dirty Then
		ApplyLayerEffects(source, highlights, extraction)
		blur.Apply(highlights, glow, levels, scratch)
		dirty = False
	End If
	SetClsColor(18, 22, 30)
	Cls
	SetColor(255, 255, 255)
	DrawText("Bloom | Threshold: "+bright.GetThreshold()+" | Blur radius: "+blur.GetRadius(), 25, 25)
	If supported Then
		DrawText("Original", 25, 75)
		DrawText("Extracted highlights", 350, 75)
		Local label:String = "Bloom enabled"
		If Not enabled Then label = "Bloom disabled"
		DrawText(label, 675, 75)
		SetScale(1.8, 1.8)
		SetBlend(ALPHABLEND)
		DrawImage(source, 25, 115)
		DrawImage(highlights, 350, 115)
		DrawImage(source, 675, 115)
		If enabled Then
			SetBlend(LIGHTBLEND)
			DrawImage(glow, 675, 115)
			SetBlend(ALPHABLEND)
		End If
		SetScale(1, 1)
	Else
		DrawText("The required shaders or render images are unavailable.", 25, 115)
	End If
	DrawText("Left/right: threshold. Up/down: radius. Space: bloom on/off. Escape: exit.", 25, 375)
	DrawText("Extracted and blurred layers are cached until settings change.", 25, 400)
	Flip
Wend
EndGraphics
