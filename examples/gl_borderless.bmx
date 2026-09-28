SuperStrict
Framework Max2D.GLMax2D

Graphics(800, 480)
SetVirtualResolution(800, 480, VIRTUAL_LETTERBOX)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	PollSystem()
	If KeyHit(KEY_F10) Then SetBorderlessFullscreen(GetWindowMode() <> MAX2D_BORDERLESS_FULLSCREEN)
	SetClsColor(24, 32, 48)
	Cls()
	SetColor(0, 180, 255)
	DrawRect(80, 120, 160, 100)
	SetColor(255, 255, 255)
	DrawText("F10 borderless / Escape exits", 24, 24)
	DrawText("Window mode: " + GetWindowMode(), 24, 52)
	DrawText("Virtual mouse: " + VirtualMouseX() + ", " + VirtualMouseY(), 24, 396)
	Flip(1)
Wend
EndGraphics()
