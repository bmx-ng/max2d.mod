SuperStrict
Framework Max2D.SDL3RenderMax2D

Graphics 960,720,0
SetVirtualResolution(320,180,VIRTUAL_LETTERBOX)
Local atlas:TTextureAtlas=TTextureAtlas.Create(64,0)
Local pixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
pixels.ClearPixels($ffff8000)
Local sprite:TImage=atlas.AddPixmap(pixels,"square")
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	SetClsColor(24,32,48)
	Cls()
	SetColor(255,255,255)
	DrawImageRect(sprite,100,50,32,32)

	PushMax2DState()
	SetNativeResolution()
	DrawText("Native pixel text over a 320 x 180 scene",16,16)
	PopMax2DState()

	Flip()
Wend
EndGraphics()
