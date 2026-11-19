SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects

AppTitle="Max2D texture-driven effects"
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
Local pixels:Float[]=New Float[128*128*4]
For Local y:Int=0 Until 128
	For Local x:Int=0 Until 128
		Local i:Int=(y*128+x)*4
		pixels[i]=Float(0.5+0.22*Sin(x*9+y*3)+0.16*Sin(y*13-x*5)+0.1*Sin(x*27+y*21))
		pixels[i+1]=Float(0.5+0.3*Sin(y*7+x*4))
		pixels[i+2]=0
		pixels[i+3]=1
	Next
Next
Local bytes:Byte[]=New Byte[pixels.Length*4]
MemCopy(bytes,pixels,Size_T(bytes.Length))
Local map:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(128,128,PF_RGBA32F,bytes)]),FILTEREDIMAGE)
Local displacement:TMax2DShaderEffect=CreateDisplacementEffect(map)
Local dissolve:TMax2DShaderEffect=CreateDissolveEffect(map)
displacement.SetEdgeMode(MAX2D_EDGE_REPEAT)
Local paused:Int, manual:Int, progress:Float=0.5, strength:Float=0.06, time:Float
Local previous:Int=MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int=MilliSecs(), elapsed:Int=now-previous
	previous=now
	If KeyHit(KEY_SPACE) Then paused=Not paused
	If Not paused Then time:+Float(Min(elapsed,100))*0.04
	If KeyHit(KEY_A) Then manual=Not manual
	If KeyHit(KEY_RIGHT) Then manual=True; progress=Float(Min(1,progress+0.05))
	If KeyHit(KEY_LEFT) Then manual=True; progress=Float(Max(0,progress-0.05))
	If KeyHit(KEY_UP) Then strength=Float(Min(0.3,strength+0.01))
	If KeyHit(KEY_DOWN) Then strength=Float(Max(0,strength-0.01))
	If Not manual Then progress=Float(0.5+0.5*Sin(time))
	displacement.SetFloat4("amount",strength,Float(strength*Sin(time*2)),0,0)
	dissolve.SetFloat("progress",progress)
	SetClsColor(16,20,30); Cls
	SetColor(255,255,255); SetBlend(ALPHABLEND)
	DrawText("Original",35,25); DrawText("Texture displacement",370,25); DrawText("Dissolve + glowing edge",705,25)
	DrawImage(source,35,60)
	DrawImageEffect(source,displacement,370,60)
	DrawImageEffect(source,dissolve,705,60)
	DrawText("Space: pause   A: automatic dissolve   Left/right: dissolve   Up/down: distortion",35,430)
	DrawText("Dissolve: "+progress+"   Distortion: "+strength,35,458)
	DrawText("Both effects use the same map; source colour and alpha remain independent.",35,490)
	Flip
Wend
EndGraphics
