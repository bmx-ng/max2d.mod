SuperStrict

Framework Max2D.SDL3RenderMax2D
Import Max2D.VirtualJoystick

Graphics 960, 540, 0
SetVirtualResolution(480, 270, VIRTUAL_LETTERBOX)
SetVirtualBarColor 8, 12, 20

Local controls:TVirtualJoystick = TVirtualJoystick.Create(2)
controls.SetButtonLayout VIRTUAL_BUTTON_LAYOUT_DIAGONAL
Local playerX:Float = 240
Local playerY:Float = 135
Local previous:Int = MilliSecs()
Local colour:Int

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int = MilliSecs()
	Local elapsed:Float = Min(0.1, Float(now - previous) / 1000.0)
	previous = now

	playerX :+ controls.X() * 150 * elapsed
	playerY :+ controls.Y() * 150 * elapsed
	playerX = Max(12.0, Min(468.0, playerX))
	playerY = Max(12.0, Min(258.0, playerY))
	If controls.ButtonHit(0) Then colour = Not colour

	Cls
	SetColor 32, 43, 60
	For Local x:Int = 0 Until 480 Step 30
		DrawLine x, 0, x, 270
	Next
	For Local y:Int = 0 Until 270 Step 30
		DrawLine 0, y, 480, y
	Next
	If colour Then SetColor 245, 166, 35 Else SetColor 55, 170, 240
	DrawOval playerX - 12, playerY - 12, 24, 24
	SetColor 255, 255, 255
	DrawText "Move with the stick; press the gold button", 12, 12

	controls.Render()
	Flip
Wend

controls.Free()
EndGraphics
