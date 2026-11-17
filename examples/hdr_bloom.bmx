SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects

AppTitle = "Max2D HDR bloom and tone mapping"
Graphics(1000, 430)
Local tone:TMax2DToneMapEffect = CreateToneMapEffect(1, 2.2)
Local bright:TMax2DBrightPassEffect = CreateBrightPassEffect(1.5)
Local blur:TMax2DScaledBlur = CreateScaledBlur(12)
Local extraction:TMax2DImageEffect[] = [TMax2DImageEffect(bright)]
Local supported:Int = Max2DSupportsImageEffect(tone) And Max2DSupportsImageEffect(bright) And Max2DSupportsImageEffect(CreateBlurEffect()) And Max2DSupportsRenderImage(160, 128, FILTEREDIMAGE, PF_RGBA16F) And Max2DTextureFormatSupport(PF_RGBA32F, 0) <> ETextureFormatSupport.Unsupported
Local source:TRenderImage, highlights:TRenderImage, glow:TRenderImage, composite:TRenderImage, scratch:TRenderImage
Local levels:TRenderImage[]
Local dirty:Int = True, enabled:Int = True
If supported Then
	source = CreateRenderImage(160, 128, FILTEREDIMAGE, PF_RGBA16F)
	highlights = CreateRenderImage(160, 128, FILTEREDIMAGE, PF_RGBA16F)
	glow = CreateRenderImage(160, 128, FILTEREDIMAGE, PF_RGBA16F)
	composite = CreateRenderImage(160, 128, FILTEREDIMAGE, PF_RGBA16F)
	levels = [CreateRenderImage(80, 64, FILTEREDIMAGE, PF_RGBA16F), CreateRenderImage(40, 32, FILTEREDIMAGE, PF_RGBA16F)]
	scratch = CreateRenderImage(40, 32, FILTEREDIMAGE, PF_RGBA16F)
	' Synthetic linear HDR content, uploaded once. Alpha is one throughout.
	Local values:Float[] = New Float[160*128*4]
	For Local y:Int = 0 Until 128
		For Local x:Int = 0 Until 160
			Local r:Float, g:Float, b:Float
			If x >= 24 And x < 136 And y >= 40 And y < 104 Then
				r = 0.06; g = 0.1; b = 0.18
			End If
			If (x-50)*(x-50)+(y-42)*(y-42) < 14*14 Then
				r = 4; g = 3; b = 1
			End If
			If x >= 88 And x < 120 And y >= 31 And y < 44 Then
				r = 1; g = 3; b = 5
			End If
			If (x >= 76 And x < 81 And y >= 62 And y < 91) Or (x >= 64 And x < 93 And y >= 74 And y < 79) Then
				r = 8; g = 8; b = 8
			End If
			If x >= 38 And x < 51 And y >= 78 And y < 91 Then
				r = 0.2; g = 0.08; b = 0.11
			End If
			Local index:Int = (y*160+x)*4
			values[index] = r; values[index+1] = g; values[index+2] = b; values[index+3] = 1
		Next
	Next
	Local bytes:Byte[] = New Byte[values.Length*4]
	MemCopy(bytes, values, Size_T(bytes.Length))
	Local image:TImage = LoadImage(TTextureData.Create([TTextureLevel.Create(160, 128, PF_RGBA32F, bytes)]), 0)
	SetRenderImage(source)
	SetBlend(SOLIDBLEND)
	DrawImage(image, 0, 0)
	SetRenderImage(Null)
	SetBlend(ALPHABLEND)
End If
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local change:Float
	If KeyHit(KEY_LEFT) Then change = -0.25
	If KeyHit(KEY_RIGHT) Then change = 0.25
	If change Then
		bright.SetThreshold(Float(Max(0.0, Min(4.0, bright.GetThreshold()+change))))
		dirty = True
	End If
	change = 0
	If KeyHit(KEY_DOWN) Then change = -0.25
	If KeyHit(KEY_UP) Then change = 0.25
	If change Then tone.SetExposure(Float(Max(0.25, Min(4.0, tone.GetExposure()+change))))
	If KeyHit(KEY_SPACE) Then enabled = Not enabled
	If supported And dirty Then
		ApplyLayerEffects(source, highlights, extraction)
		blur.Apply(highlights, glow, levels, scratch)
		SetRenderImage(composite)
		SetBlend(SOLIDBLEND)
		DrawImage(source, 0, 0)
		SetBlend(LIGHTBLEND)
		DrawImage(glow, 0, 0)
		SetRenderImage(Null)
		SetBlend(ALPHABLEND)
		dirty = False
	End If
	SetClsColor(18, 22, 30)
	Cls
	SetColor(255, 255, 255)
	DrawText("HDR bloom | Threshold: "+bright.GetThreshold()+" | Exposure: "+tone.GetExposure()+" | Gamma: 2.2", 25, 25)
	If supported Then
		DrawText("Clipped HDR (no mapping)", 25, 75)
		DrawText("Tone mapped", 350, 75)
		Local label:String = "HDR bloom + tone mapping"
		If Not enabled Then label = "Bloom disabled"
		DrawText(label, 675, 75)
		SetScale(1.8, 1.8)
		DrawImage(source, 25, 115)
		DrawImageEffect(source, tone, 350, 115)
		If enabled Then
			DrawImageEffect(composite, tone, 675, 115)
		Else
			DrawImageEffect(source, tone, 675, 115)
		End If
		SetScale(1, 1)
	Else
		DrawText("Required floating-point images or shaders are unavailable.", 25, 115)
	End If
	DrawText("Left/right: threshold. Up/down: exposure. Space: bloom on/off. Escape: exit.", 25, 375)
	DrawText("HDR layers are cached. Exposure changes only the final display draw.", 25, 400)
	Flip
Wend
EndGraphics
