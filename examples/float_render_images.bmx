SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.GLMax2D
?

AppTitle="Max2D floating-point render images"
Graphics(900,540,0)
SetVirtualResolution(900,540,VIRTUAL_LETTERBOX)

Local format:Int=PF_RGBA16F
If Not Max2DSupportsRenderImage(256,256,FILTEREDIMAGE,format) Then format=PF_RGBA32F
If Not Max2DSupportsRenderImage(256,256,FILTEREDIMAGE,format) Then
	EndGraphics()
	Throw "This backend/device does not support floating-point render images"
End If

Local pixels:TPixmap=CreatePixmap(128,128,PF_RGBA8888)
For Local y:Int=0 Until 128
	For Local x:Int=0 Until 128
		Local dx:Float=(x-63.5)/64
		Local dy:Float=(y-63.5)/64
		Local strength:Float=Max(0.0,1.0-Sqr(dx*dx+dy*dy))
		Local alpha:Int=Int(strength*strength*255)
		pixels.WritePixel(x,y,(alpha Shl 24)|$ffffff)
	Next
Next
Local glow:TImage=LoadImage(pixels,FILTEREDIMAGE)
Local ordinary:TRenderImage=CreateRenderImage(256,256,FILTEREDIMAGE)
Local floating:TRenderImage=CreateRenderImage(256,256,FILTEREDIMAGE,format)
BuildLights(ordinary,glow)
BuildLights(floating,glow)

' Read once for the demonstration; drawing the textures does not need CPU readback.
Local snapshot:TTextureData=ReadRenderTextureData(floating)
Local channels:Float Ptr=Float Ptr(snapshot.Level().Data())
Local peak:Float
For Local i:Int=0 Until 256*256*4 Step 4
	peak=Max(peak,Max(channels[i],Max(channels[i+1],channels[i+2])))
Next
Local exposure:Float=0.25

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyDown(KEY_LEFT) Then exposure=Max(0.05,exposure-0.005)
	If KeyDown(KEY_RIGHT) Then exposure=Min(1.0,exposure+0.005)
	SetRenderImage(Null)
	SetClsColor(20,24,36)
	Cls()
	SetBlend(SOLIDBLEND)
	Local tint:Int=Int(exposure*255)
	SetColor(tint,tint,tint)
	DrawImage(ordinary,100,150)
	DrawImage(floating,544,150)
	SetColor(255,255,255)
	SetBlend(ALPHABLEND)
	DrawText("The same additive lights, stored at different precision",24,24)
	DrawText("RGBA8: highlights clipped while drawing",60,105)
	DrawText("Floating point: highlights retained",510,105)
	DrawText("Left/Right: exposure   Escape: exit",24,455)
	DrawText("Exposure: "+exposure+"   Stored float peak: "+peak,24,485)
	Flip()
Wend
EndGraphics()

Function BuildLights(target:TRenderImage,glow:TImage)
	SetRenderImage(target)
	SetClsColor(0,0,0,1)
	Cls()
	SetBlend(LIGHTBLEND)
	For Local pass:Int=0 Until 6
		SetColor(255,90,30)
		DrawImage(glow,40,45)
		SetColor(30,100,255)
		DrawImage(glow,95,65)
		SetColor(80,255,130)
		DrawImage(glow,65,115)
	Next
	SetColor(255,255,255)
	SetRenderImage(Null)
End Function
