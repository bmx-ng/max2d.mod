SuperStrict
Framework Max2D.SDL3GPUMax2D

AppTitle = "Max2D HDR display output"
Graphics(900, 440)
Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(TMax2DGraphics.Current().context)
Local supported:Int = context.SupportsHDROutput()
If supported Then context.SetHDROutput(True)
Local patches:TImage
Local previousWhite:Float = -1
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_SPACE) And supported Then context.SetHDROutput(Not context.HDROutput())
	Local white:Float = 1
	If context.HDROutput() Then white = context.SDRWhiteLevel()
	If white <> previousWhite Then
		Local values:Float[] = New Float[4*4]
		For Local x:Int = 0 Until 4
			Local level:Float = [1.0, 1.5, 2.0, 4.0][x]*white
			values[x*4] = level; values[x*4+1] = level; values[x*4+2] = level; values[x*4+3] = 1
		Next
		Local bytes:Byte[] = New Byte[values.Length*4]
		MemCopy(bytes, values, Size_T(bytes.Length))
		patches = LoadImage(TTextureData.Create([TTextureLevel.Create(4, 1, PF_RGBA32F, bytes)]), 0)
		previousWhite = white
	End If
	SetClsColor(0, 0, 0)
	Cls
	SetColor(255, 255, 255)
	Local mode:String = "SDR: highlights clipped to normal white"
	If context.HDROutput() Then mode = "HDR: extended linear output"
	DrawText(mode, 30, 25)
	DrawText("Driver: "+SDLGPUMax2DDriverName()+" | Display headroom: "+context.HDRHeadroom()+"x", 30, 55)
	DrawText("Output white level: "+white+" | HDR format supported: "+supported, 30, 80)
	SetBlend(SOLIDBLEND)
	SetScale(180, 90)
	DrawImage(patches, 50, 150)
	SetScale(1, 1)
	SetBlend(ALPHABLEND)
	DrawText("Normal white", 50, 260)
	DrawText("1.5x white", 230, 260)
	DrawText("2x white", 410, 260)
	DrawText("4x white", 590, 260)
	DrawText("Space: toggle HDR / SDR | Escape: close", 30, 320)
	If context.HDRHeadroom() <= 1 Then
		DrawText("The OS currently reports no extra HDR brightness on this display.", 30, 355)
	Else
		DrawText("HDR highlights should exceed normal white, up to the display's limit.", 30, 355)
	End If
	DrawText("HDR screen captures may be tone mapped and cannot prove display brightness.", 30, 385)
	Flip
Wend
EndGraphics
