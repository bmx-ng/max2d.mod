SuperStrict
Framework Max2D.SDL3RenderMax2D

' Renderer choice applies to windows created afterwards. An environment
' SDL_RENDER_DRIVER override takes priority; always query the active context.
SetSDLRenderMax2DRenderer("gpu")
Graphics 640,360

Local supported:Int = Max2DSupportsBlend(MASKBLEND)
Local status:String = "MASKBLEND unavailable"
If supported Then status = "MASKBLEND available"
Local pixels:TPixmap = CreatePixmap(64,64,PF_RGBA8888)
For Local y:Int = 0 Until 64
	For Local x:Int = 0 Until 64
		pixels.WritePixel(x,y,((x*255/63) Shl 24) | $00c0ff)
	Next
Next
Local gradient:TImage = LoadImage(pixels,FILTEREDIMAGE)

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	SetClsColor(32,32,32)
	Cls
	SetColor(255,255,255)
	SetBlend(ALPHABLEND)
	DrawText SDLRenderMax2DRendererName() + ": " + status,20,20
	DrawText "ALPHABLEND",40,70
	DrawImageRect gradient,40,100,240,180
	If supported Then
		DrawText "MASKBLEND",340,70
		SetBlend(MASKBLEND)
		DrawImageRect gradient,340,100,240,180
	End If
	SetBlend(ALPHABLEND)
	DrawText "Escape to exit",20,320
	Flip
Wend
EndGraphics()
