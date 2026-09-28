SuperStrict
Framework Max2D.D3D11Max2D

If Not Graphics(640, 480, 0) Then Throw "D3D11 graphics creation failed"
SetVirtualResolution(320, 180, VIRTUAL_LETTERBOX)
SetClsColor(24, 32, 48)

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	PollSystem()
	Cls()
	SetColor(0, 180, 230)
	DrawRect(20, 20, 80, 50)
	SetColor(255, 255, 255)
	DrawText("Hello Direct3D11", 20, 90)
	PushMax2DState()
	SetNativeResolution()
	DrawText("Max2D.D3D11Max2D - Escape to exit", 12, 12)
	PopMax2DState()
	Flip(1)
Wend

EndGraphics()
