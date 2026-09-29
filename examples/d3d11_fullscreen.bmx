SuperStrict
Framework Max2D.D3D11Max2D

Local displays:TD3D11Display[] = D3D11Displays()
If Not displays.Length Then Throw "No DXGI displays found"
' Choose the display before Graphics. -1 uses the window's initial monitor.
D3D11GraphicsDriver().display = 0
Local modes:TGraphicsMode[] = displays[0].modes
If Not modes.Length Then Throw "No fullscreen modes found"
Local mode:TGraphicsMode = modes[0]
For Local candidate:TGraphicsMode = EachIn modes
	If candidate.width = displays[0].width And candidate.height = displays[0].height Then
		mode = candidate
		Exit
	End If
Next

If Not Graphics(800, 480, 0) Then Throw "Could not create D3D11 graphics"
SetVirtualResolution(800, 480, VIRTUAL_LETTERBOX)
Local fullscreen:Int
Local borderless:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_F11) Then
		fullscreen = Not fullscreen
		borderless = False
		SetFullscreen(fullscreen, mode.width, mode.height, mode.hertz)
	End If
	If KeyHit(KEY_F10) Then
		borderless = Not borderless
		SetBorderlessFullscreen(borderless)
		fullscreen = False
	End If
	SetClsColor(24, 32, 48)
	Cls()
	SetColor(0, 180, 255)
	DrawRect(80, 120, 160, 100)
	SetColor(255, 255, 255)
	DrawText("D3D11 - F10 borderless / F11 exclusive fullscreen", 24, 24)
	DrawText("Escape exits and restores the desktop", 24, 52)
	DrawText("Display: " + displays[0].name, 24, 340)
	DrawText("Mode: " + mode.width + " x " + mode.height + " @ " + mode.hertz + " Hz", 24, 368)
	DrawText("Virtual mouse: " + VirtualMouseX() + ", " + VirtualMouseY(), 24, 396)
	Flip(1)
Wend
EndGraphics()
