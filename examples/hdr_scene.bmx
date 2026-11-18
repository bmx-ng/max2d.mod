SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects

AppTitle = "Max2D linear artwork and HDR bloom"
Graphics(1000, 540)
Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(TMax2DGraphics.Current().context)
Local hdrSupported:Int = context.SupportsHDROutput()
If hdrSupported And context.HDRHeadroom() > 1 Then context.SetHDROutput(True)
Local tone:TMax2DLinearOutputEffect = CreateLinearOutputEffect(context.HDROutput())
Local bright:TMax2DBrightPassEffect = CreateBrightPassEffect(1.5)
Local blur:TMax2DScaledBlur = CreateScaledBlur(12)
Local extraction:TMax2DImageEffect[] = [TMax2DImageEffect(bright)]
Local supported:Int = Max2DSupportsImageEffect(tone) And Max2DSupportsImageEffect(bright) And Max2DSupportsImageEffect(CreateBlurEffect()) And Max2DSupportsRenderImage(160, 128, FILTEREDIMAGE, PF_RGBA16F) And Max2DTextureFormatSupport(PF_RGBA32F, 0) <> ETextureFormatSupport.Unsupported
Local source:TRenderImage, highlights:TRenderImage, glow:TRenderImage, composite:TRenderImage
Local buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
Local dirty:Int = True, enabled:Int = True
If supported Then
	source = CreateRenderImage(160, 128, FILTEREDIMAGE, PF_RGBA16F)
	buffers.Prepare(160, 128, 3, 2, PF_RGBA16F)
	highlights = buffers.Image(0)
	glow = buffers.Image(1)
	composite = buffers.Image(2)
	' Ordinary sRGB artwork is decoded once before filtering or composition.
	Local artwork:TPixmap = CreatePixmap(160, 128, PF_RGBA8888)
	For Local y:Int = 0 Until 128
		For Local x:Int = 0 Until 160
			Local pixel:Int = $ff26344c
			If y > 95 And x > 12 And x < 148 Then
				pixel = $ff4080b0
				If (x/12+y/12) Mod 2 Then pixel = $ffc08050
			End If
			artwork.WritePixel(x, y, pixel)
		Next
	Next
	Local linear:TTextureData = SRGBPixmapToLinearTextureData(artwork)
	Local decoded:Float Ptr = Float Ptr(linear.Level().Data())
	' Add emitters with energy above white to the decoded artwork.
	Local values:Float[] = New Float[160*128*4]
	For Local y:Int = 0 Until 128
		For Local x:Int = 0 Until 160
			Local offset:Int = (y*160+x)*4
			Local r:Float = decoded[offset], g:Float = decoded[offset+1], b:Float = decoded[offset+2]
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
	If KeyHit(KEY_H) And hdrSupported Then context.SetHDROutput(Not context.HDROutput())
	tone.SetHDR(context.HDROutput())
	tone.SetWhiteLevel(context.SDRWhiteLevel())
	If supported And dirty Then
		buffers.ApplyChain(source, 0, extraction)
		buffers.ApplyBlur(highlights, 1, blur)
		SetRenderImage(composite)
		SetBlend(SOLIDBLEND)
		DrawImage(source, 0, 0)
		SetBlend(LIGHTBLEND)
		DrawImage(glow, 0, 0)
		SetRenderImage(Null)
		SetBlend(ALPHABLEND)
		dirty = False
	End If
	SetClsColor(0, 0, 0)
	Cls
	SetColor(255, 255, 255)
	Local mode:String = "SDR tone mapping + sRGB encoding"
	If context.HDROutput() Then mode = "HDR display output"
	DrawText(mode+" | Headroom: "+context.HDRHeadroom()+"x", 25, 25)
	DrawText("Linear artwork + emitters", 25, 75)
	Local bloomLabel:String = "With bloom"
	If Not enabled Then bloomLabel = "Bloom disabled"
	DrawText(bloomLabel, 525, 75)
	If supported Then
		SetBlend(SOLIDBLEND)
		SetScale(2.7, 2.7)
		DrawImageEffect(source, tone, 25, 110)
		If enabled Then
			DrawImageEffect(composite, tone, 525, 110)
		Else
			DrawImageEffect(source, tone, 525, 110)
		End If
		SetScale(1, 1)
		SetBlend(ALPHABLEND)
	Else
		DrawText("Required floating-point images or shaders are unavailable.", 25, 115)
	End If
	DrawText("H: HDR/SDR | Space: bloom | Arrows: threshold/exposure | Escape: exit", 25, 475)
	DrawText("Threshold: "+bright.GetThreshold()+" | Exposure: "+tone.GetExposure(), 25, 505)
	Flip
Wend
buffers.Release()
EndGraphics
