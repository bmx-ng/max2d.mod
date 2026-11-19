SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects

AppTitle="Max2D soft texture masks"
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
		Local dx:Float=Float(x-120)/120, dy:Float=Float(y-120)/120
		Local coverage:Float=Float(Max(0,Min(1,(1-Sqr(dx*dx+dy*dy))*3)))
		coverage=coverage*coverage*(3-2*coverage)
		Local i:Int=(y*240+x)*4
		pixels[i]=1; pixels[i+1]=1; pixels[i+2]=1; pixels[i+3]=coverage
	Next
Next
Local bytes:Byte[]=New Byte[pixels.Length*4]
MemCopy(bytes,pixels,Size_T(bytes.Length))
Local gradient:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(240,240,PF_RGBA32F,bytes)]),FILTEREDIMAGE)
Local maskLayer:TRenderImage=CreateRenderImage(300,340,FILTEREDIMAGE,PF_RGBA16F)
Local reveal:TMax2DShaderEffect=CreateTextureMaskEffect(maskLayer)
Local inverse:TMax2DShaderEffect=CreateTextureMaskEffect(maskLayer,True)
Local paused:Int, preview:Int, time:Float
Local previous:Int=MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int=MilliSecs(), elapsed:Int=now-previous
	previous=now
	If KeyHit(KEY_SPACE) Then paused=Not paused
	If KeyHit(KEY_M) Then preview=Not preview
	If Not paused Then time:+Float(Min(elapsed,100))*0.04
	SetRenderImage(maskLayer)
	SetClsColor(0,0,0,0); Cls
	SetColor(255,255,255); SetAlpha(1); SetBlend(SOLIDBLEND)
	DrawImage(gradient,Float(30+55*Sin(time)),Float(50+65*Cos(time*0.7)))
	SetRenderImage(Null)
	SetClsColor(16,20,30); Cls
	SetBlend(ALPHABLEND)
	DrawText("Original",35,25)
	If preview Then DrawText("Mask preview",370,25) Else DrawText("Soft reveal",370,25)
	DrawText("Inverted mask",705,25)
	DrawImage(source,35,60)
	If preview Then DrawImage(maskLayer,370,60) Else DrawImageEffect(source,reveal,370,60)
	DrawImageEffect(source,inverse,705,60)
	DrawText("Space: pause   M: preview the mask",35,430)
	DrawText("A shared moving mask reveals one image and hides the same area in the other.",35,468)
	Flip
Wend
EndGraphics
