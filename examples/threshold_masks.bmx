SuperStrict
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle="Max2D threshold masks"
Graphics(1040,540)
Local source:TRenderImage=CreateRenderImage(300,340,FILTEREDIMAGE,PF_RGBA16F)
SetRenderImage(source)
SetClsColor(0,0,0,0); Cls
For Local y:Int=0 Until 340 Step 20
	For Local x:Int=0 Until 300 Step 20
		If (x/20+y/20) Mod 2 Then SetColor(35,90,130) Else SetColor(20,45,70)
		DrawRect(x,y,20,20)
	Next
Next
SetColor(255,180,65); DrawOval(45,45,210,210)
SetColor(25,40,60); DrawOval(65,65,170,170)
SetColor(100,220,240); DrawRect(135,25,30,250)
SetColor(245,90,140); DrawRect(25,135,250,30)
SetColor(255,255,255); SetScale(4,4); DrawText("Max2D",30,285); SetScale(1,1)
SetRenderImage(Null)
Local pixels:Float[]=New Float[240*240*4]
For Local y:Int=0 Until 240
	For Local x:Int=0 Until 240
		Local value:Float=0.5+0.22*Sin(x*3+y*1.1)+0.17*Cos(y*4-x*0.7)+0.1*Sin(x*8+y*6)
		Local i:Int=(y*240+x)*4
		pixels[i]=value; pixels[i+1]=value; pixels[i+2]=value; pixels[i+3]=1
	Next
Next
Local bytes:Byte[]=New Byte[pixels.Length*4]
MemCopy(bytes,pixels,Size_T(bytes.Length))
Local map:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(240,240,PF_RGBA32F,bytes)]),FILTEREDIMAGE)
Local hard:TMax2DShaderEffect=CreateThresholdMaskEffect(map)
Local soft:TMax2DShaderEffect=CreateThresholdMaskEffect(map)
hard.SetFloat4("channels",1,0,0,0); soft.SetFloat4("channels",1,0,0,0)
Local paused:Int, inverted:Int, time:Float, feather:Float=0.2
Local previous:Int=MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int=MilliSecs(), elapsed:Int=now-previous
	previous=now
	If KeyHit(KEY_SPACE) Then paused=Not paused
	If KeyHit(KEY_I) Then inverted=Not inverted
	If KeyDown(KEY_UP) Then feather=Min(0.8,feather+Float(elapsed)*0.0003)
	If KeyDown(KEY_DOWN) Then feather=Max(0.02,feather-Float(elapsed)*0.0003)
	If Not paused Then time:+Float(Min(elapsed,100))*0.035
	Local progress:Float=0.5-0.5*Cos(time)
	Local cut:Float=progress*1.002-0.001
	hard.SetFloat4("range",cut,cut,0,0)
	Local low:Float=progress*(1+feather)-feather
	soft.SetFloat4("range",low,low+feather,0,0)
	hard.SetFloat("invert",inverted); soft.SetFloat("invert",inverted)
	SetClsColor(16,20,30); Cls
	SetBlend(ALPHABLEND); SetColor(255,255,255)
	DrawText("Threshold map",35,25); DrawText("Hard cut",370,25); DrawText("Soft transition",705,25)
	SetScale(1.25,Float(340.0/240)); DrawImage(map,35,60); SetScale(1,1)
	DrawImageEffect(source,hard,370,60); DrawImageEffect(source,soft,705,60)
	DrawText("Space: pause   I: invert   Up/Down: transition width",35,430)
	DrawText("Width: "+feather+"   Progress: "+progress,35,468)
	Flip
Wend
EndGraphics
