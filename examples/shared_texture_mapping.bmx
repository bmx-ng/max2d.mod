SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle="Max2D shared texture mapping"
Graphics(1040,500)
Local tile:TRenderImage=CreateRenderImage(72,72,FILTEREDIMAGE,PF_RGBA16F)
SetRenderImage(tile); SetClsColor(0,0,0,0); Cls
SetColor(255,255,255); DrawRect(2,2,68,68)
SetColor(60,75,100); DrawRect(8,8,56,56)
SetColor(255,255,255); DrawOval(16,16,40,40)
SetColor(60,75,100); DrawOval(23,23,26,26)
SetRenderImage(Null)
SetImageHandle(tile,36,36)
Local pixels:Float[]=New Float[128*128*4]
For Local y:Int=0 Until 128
	For Local x:Int=0 Until 128
		Local dx:Float=Float(x-64)/64,dy:Float=Float(y-64)/64
		Local a:Float=Float(Max(0,Min(1,(1-Sqr(dx*dx+dy*dy))*4)))
		a=a*a*(3-2*a)
		Local i:Int=(y*128+x)*4
		pixels[i]=1; pixels[i+1]=1; pixels[i+2]=1; pixels[i+3]=a
	Next
Next
Local bytes:Byte[]=New Byte[pixels.Length*4]
MemCopy(bytes,pixels,Size_T(bytes.Length))
Local map:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(128,128,PF_RGBA32F,bytes)]),FILTEREDIMAGE)
SetImageHandle(map,64,64)
Local effect:TMax2DShaderEffect=CreateTextureMaskEffect(map)
Local paused:Int,followMouse:Int,time:Float
Local previous:Int=MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int=MilliSecs(),elapsed:Int=now-previous
	previous=now
	If KeyHit(KEY_SPACE) Then paused=Not paused
	If KeyHit(KEY_M) Then followMouse=Not followMouse
	If Not paused Then time:+Float(Min(elapsed,100))*0.001
	SetTransform(); SetColor(255,255,255); SetBlend(ALPHABLEND)
	SetClsColor(16,20,30); Cls
	DrawText("Original sprites",35,25)
	DrawText("Each sprite has its own mask",370,25)
	DrawText("One shared mask",705,25)
	Local mx:Float=Float(855+55*Sin(time*35)),my:Float=Float(225+65*Cos(time*28))
	If followMouse Then mx=MouseX(); my=MouseY()
	SetTransform(Float(time*15),1.8,1.4)
	Local placement:TMax2DDrawTransform=CaptureImageTransform(map,mx,my)
	For Local panel:Int=0 Until 3
		For Local row:Int=0 Until 3
			For Local col:Int=0 Until 3
				Local x:Float=85+panel*335+col*100,y:Float=110+row*100
				SetTransform(Float(time*30+(row*3+col)*20),1,1)
				SetColor(255-row*65,150+col*45,120+row*65)
				If panel=0 Then
					DrawImage(tile,x,y)
				Else
					If panel=1 Then effect.SetTextureTransform() Else effect.SetTextureMapping(placement,tile,x,y)
					DrawImageEffect(tile,effect,x,y)
				End If
			Next
		Next
	Next
	SetTransform(); SetColor(255,255,255)
	DrawText("Space: pause   M: move the shared mask with the mouse",35,425)
	DrawText("The shared mask stays aligned while individual sprites rotate beneath it.",35,460)
	Flip
Wend
EndGraphics
