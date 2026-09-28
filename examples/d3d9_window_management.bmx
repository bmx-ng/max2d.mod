SuperStrict
Framework Max2D.D3D9Max2D

Graphics(800, 480)
SetVirtualResolution(800, 480, VIRTUAL_LETTERBOX)
Local small:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	PollSystem()
	If GetWindowMode()=MAX2D_WINDOWED Then
		If KeyHit(KEY_F5) Then
			small=Not small
			If small Then GraphicsResize(640,384) Else GraphicsResize(800,480)
		End If
		If KeyHit(KEY_F6) Then GraphicsPosition(100,100)
	End If
	If KeyHit(KEY_F10) Then SetBorderlessFullscreen(GetWindowMode() <> MAX2D_BORDERLESS_FULLSCREEN)
	SetClsColor(24, 32, 48)
	Cls()
	SetColor(0, 180, 255)
	DrawRect(80, 120, 160, 100)
	' Capture scene coordinates before switching to the native-resolution overlay.
	Local mouseX:Float=VirtualMouseX(),mouseY:Float=VirtualMouseY()
	PushMax2DState()
	SetNativeResolution()
	SetColor(255, 255, 255)
	DrawText("F5 640x384 / 800x480 | F6 move | F10 borderless | Esc exits", 24, 24)
	DrawText("Window: " + GraphicsWidth() + " x " + GraphicsHeight() + " | Mode: " + GetWindowMode(), 24, 52)
	DrawText("Virtual mouse: " + mouseX + ", " + mouseY, 24, NativeResolutionHeight()-28)
	PopMax2DState()
	Flip(1)
Wend
EndGraphics()
