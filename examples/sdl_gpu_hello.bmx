SuperStrict
Framework Max2D.SDL3GPUMax2D

Graphics 640,480,0
SetVirtualResolution(320,180,VIRTUAL_LETTERBOX)
SetVirtualBarColor(12,12,16)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	SetClsColor(24,32,48)
	Cls()
	SetColor(80,180,240)
	DrawRect(20,20,80,50)
	SetColor(255,255,255)
	DrawText("Hello World",20,90)
	PushMax2DState()
	SetNativeResolution()
	DrawText("SDL GPU: "+SDLGPUMax2DDriverName()+" - Escape to exit",12,12)
	PopMax2DState()
	Flip()
Wend
EndGraphics()
