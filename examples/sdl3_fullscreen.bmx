SuperStrict
Framework Max2D.SDL3RenderMax2D

Graphics(800, 480)
SetVirtualResolution(800, 480, VIRTUAL_LETTERBOX)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_F10) Then SetBorderlessFullscreen(GetWindowMode() <> MAX2D_BORDERLESS_FULLSCREEN)
	If KeyHit(KEY_F11) Then
		Try
			SetFullscreen(GetWindowMode() <> MAX2D_FULLSCREEN, 1280, 720)
		Catch error:Object
			Notify(error.ToString())
		End Try
	End If
	SetClsColor(24, 32, 48)
	Cls()
	SetColor(0, 180, 255)
	DrawRect(80, 120, 160, 100)
	SetColor(255, 255, 255)
	DrawText("F10 borderless / F11 exclusive 1280x720 / Escape exits", 24, 24)
	DrawText("Window mode: " + GetWindowMode(), 24, 52)
	DrawText("Virtual mouse: " + VirtualMouseX() + ", " + VirtualMouseY(), 24, 396)
	Flip(1)
Wend
EndGraphics()
