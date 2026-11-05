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

' Erase stored colour and alpha together, then draw the result normally.
Local erase:Int = CreateBlendMode(BLEND_ZERO, BLEND_ONE_MINUS_SRC_ALPHA, BLEND_OP_ADD, ..
	BLEND_ZERO, BLEND_ONE_MINUS_SRC_ALPHA)

Graphics 720, 440
Local supported:Int = Max2DSupportsBlend(erase)
Local card:TRenderImage = CreateRenderImage(320, 240)
Local mask:TImage = CreateImage(128, 128, 1, DYNAMICIMAGE | FILTEREDIMAGE)
Local pixels:TPixmap = LockImage(mask)
For Local y:Int = 0 Until 128
	For Local x:Int = 0 Until 128
		Local distance:Float = Sqr((x - 63.5) ^ 2 + (y - 63.5) ^ 2)
		Local alpha:Int = Int(Max(0.0, Min(1.0, (60 - distance) / 12)) * 255)
		pixels.WritePixel(x, y, (alpha Shl 24) | $ffffff)
	Next
Next
UnlockImage(mask)

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	' This scope restores the window, blend, colour and opacity together.
	PushMax2DState()
	SetRenderImage(card)
	SetClsColor(30, 140, 210, 1)
	Cls
	SetBlend(ALPHABLEND)
	SetColor(255, 255, 255)
	DrawText "A transparent hole", 30, 24
	If supported Then
		SetBlend(erase)
		DrawImage mask, MouseX() - 200 - 64, MouseY() - 120 - 64
	End If
	PopMax2DState()

	SetClsColor(24, 28, 38)
	Cls
	SetBlend(SOLIDBLEND)
	For Local y:Int = 0 Until 240 Step 20
		For Local x:Int = 0 Until 320 Step 20
			Local shade:Int = 75 + ((x / 20 + y / 20) Mod 2) * 70
			SetColor(shade, shade, shade)
			DrawRect 200 + x, 120 + y, 20, 20
		Next
	Next
	SetColor(255, 255, 255)
	SetBlend(ALPHABLEND)
	DrawImage card, 200, 120
	DrawText "Move the pointer over the blue card. Escape exits.", 20, 30
	If Not supported Then DrawText "This backend does not support the erase blend.", 20, 60
	Flip
Wend
EndGraphics
