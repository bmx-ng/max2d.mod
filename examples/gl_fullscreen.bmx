SuperStrict
Framework Max2D.GLMax2D

Graphics(800, 480)
' Query modes for the display containing this window.
Local mode:TGraphicsMode
For Local candidate:TGraphicsMode=EachIn GraphicsModes()
	If candidate.width>=640 And candidate.height>=480 Then
		If Not mode Then mode=candidate
		If candidate.width=1280 And candidate.height=720 Then mode=candidate;Exit
	End If
Next
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
	If KeyHit(KEY_F11) Then
		Try
			If GetWindowMode()=MAX2D_FULLSCREEN Then
				SetFullscreen(False)
			Else If mode Then
				SetFullscreen(True,mode.width,mode.height,mode.hertz)
			Else
				Notify("No exclusive display mode is available")
			End If
		Catch error:Object
			Notify(error.ToString())
		End Try
	End If
	SetClsColor(24, 32, 48)
	Cls()
	SetColor(0, 180, 255)
	DrawRect(80, 120, 160, 100)
	' Capture scene coordinates before switching to the native-resolution overlay.
	Local mouseX:Float=VirtualMouseX(),mouseY:Float=VirtualMouseY()
	PushMax2DState()
	SetNativeResolution()
	SetColor(255, 255, 255)
	DrawText("F5 resize | F6 move | F10 borderless | F11 exclusive | Esc exits", 24, 24)
	If mode Then DrawText("Exclusive: " + mode.width + " x " + mode.height + " @ " + mode.hertz + " Hz",24,80)
	DrawText("Window: " + GraphicsWidth() + " x " + GraphicsHeight() + " | Mode: " + GetWindowMode(), 24, 52)
	DrawText("Virtual mouse: " + mouseX + ", " + mouseY, 24, NativeResolutionHeight()-28)
	PopMax2DState()
	Flip(1)
Wend
EndGraphics()
