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

' Hold Up/Down to change opacity. Escape or the window close button exits.
' Custom modes are reusable Int values; create and check them once.
Local names:String[] = ["Alpha", "Subtract", "Add", "Multiply", "Screen", "Minimum", "Maximum"]
Local modes:Int[] = [ALPHABLEND, SUBTRACTBLEND, ..
	CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE, BLEND_OP_ADD, BLEND_ZERO, BLEND_ONE), ..
	CreateBlendMode(BLEND_DST_COLOR, BLEND_ZERO, BLEND_OP_ADD, BLEND_ZERO, BLEND_ONE), ..
	CreateBlendMode(BLEND_ONE, BLEND_ONE_MINUS_SRC_COLOR, BLEND_OP_ADD, BLEND_ZERO, BLEND_ONE), ..
	CreateBlendMode(BLEND_ONE, BLEND_ONE, BLEND_OP_MIN, BLEND_ZERO, BLEND_ONE), ..
	CreateBlendMode(BLEND_ONE, BLEND_ONE, BLEND_OP_MAX, BLEND_ZERO, BLEND_ONE)]
Local supported:Int[] = New Int[modes.Length]

Graphics 980, 380
For Local i:Int = 0 Until modes.Length
	supported[i] = Max2DSupportsBlend(modes[i])
Next

Local opacity:Float = 0.6
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyDown(KEY_UP) Then opacity = Min(1.0, opacity + 0.01)
	If KeyDown(KEY_DOWN) Then opacity = Max(0.0, opacity - 0.01)

	SetClsColor(24, 28, 38)
	Cls
	SetBlend(ALPHABLEND)
	SetAlpha(1)
	SetColor(255, 255, 255)
	DrawText "Custom blending - Up/Down adjusts opacity: " + Int(opacity * 100) + "%", 20, 20
	DrawText "Multiply, screen and min/max here deliberately ignore source opacity.", 20, 44

	For Local i:Int = 0 Until modes.Length
		Local x:Int = 20 + i * 137
		SetBlend(ALPHABLEND)
		SetAlpha(1)
		SetColor(255, 255, 255)
		DrawText names[i], x, 86
		SetColor(130, 160, 200)
		DrawRect x, 116, 120, 170
		SetColor(220, 100, 60)
		DrawRect x, 116, 60, 170

		If supported[i] Then
			PushMax2DState()
			SetBlend(modes[i])
			SetColor(160, 200, 100)
			SetAlpha(opacity)
			DrawOval x + 10, 146, 100, 100
			PopMax2DState()
		Else
			SetColor(255, 255, 255)
			DrawText "Unavailable", x, 300
		End If
	Next
	Flip
Wend
EndGraphics
