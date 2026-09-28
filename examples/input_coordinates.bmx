SuperStrict
Framework Max2D.SDL3RenderMax2D

AppTitle="Max2D input coordinates"

Graphics 900,640,0

SetVirtualResolution(320,180,VIRTUAL_INTEGER)
SetVirtualBarColor(8,12,20)
Local angle:Float=25

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	PollSystem()
	If KeyDown(KEY_LEFT) Then angle:-1
	If KeyDown(KEY_RIGHT) Then angle:+1
	SetClsColor(24,32,48)
	Cls()

	Local mx:Float,my:Float,lx:Float,ly:Float
	Local inside:Int=GetVirtualMouse(mx,my,True)

	PushMax2DState()
	SetRotation(angle)
	SetHandle(40,20)
	Local shape:TMax2DDrawTransform=CaptureDrawTransform(160,90)
	Local hovered:Int=inside And shape.VirtualToLocal(mx,my,lx,ly)
	hovered=hovered And lx>=0 And ly>=0 And lx<80 And ly<40
	If hovered Then SetColor(80,220,140) Else SetColor(240,160,60)
	DrawRect(160,90,80,40)
	PopMax2DState()

	PushMax2DState()
	SetNativeResolution()
	SetColor(255,255,255)
	DrawText("Hover over the rotated rectangle. Left/Right rotate it.",16,16)
	DrawText("Bars are excluded from scene input. Escape exits.",16,36)
	If hovered Then DrawText("Inside the rectangle",16,56)
	PopMax2DState()

	Flip()
Wend
EndGraphics()
