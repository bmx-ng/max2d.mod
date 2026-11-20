SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle="Max2D distortion and colour"
Graphics(1040,500)
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
Local wave:TMax2DShaderEffect=CreateDistortionEffect()
Local ripple:TMax2DShaderEffect=CreateGradedDistortionEffect()
Local preset:Int=1
Local grades:String[]=["Natural","Monochrome","Warm","Cool"]
Local edge:Int=MAX2D_EDGE_REPEAT, paused:Int, strength:Float=0.035, frequency:Float=28, time:Float
Local previous:Int=MilliSecs()
Local names:String[]=["Transparent","Clamp","Repeat"]
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int=MilliSecs(), elapsed:Int=now-previous
	previous=now
	If KeyHit(KEY_SPACE) Then paused=Not paused
	If Not paused Then time:+Float(Min(elapsed,100))*0.002
	If KeyHit(KEY_G) Then preset=(preset+1) Mod 4
	Select preset
		Case 0
			ripple.SetFloat4("grade",1,1,1,0); ripple.SetFloat4("gradeTint",1,1,1,1)
		Case 1
			ripple.SetFloat4("grade",0,1,1.2,0); ripple.SetFloat4("gradeTint",1,1,1,1)
		Case 2
			ripple.SetFloat4("grade",0.8,1.1,1.1,0); ripple.SetFloat4("gradeTint",1,0.8,0.55,1)
		Case 3
			ripple.SetFloat4("grade",0.7,1.1,1.15,0); ripple.SetFloat4("gradeTint",0.55,0.85,1,1)
	End Select
	If KeyHit(KEY_E) Then edge=(edge+1) Mod 3
	If KeyHit(KEY_UP) Then strength=Float(Min(0.2,strength+0.005))
	If KeyHit(KEY_DOWN) Then strength=Float(Max(0,strength-0.005))
	If KeyHit(KEY_RIGHT) Then frequency:+2
	If KeyHit(KEY_LEFT) Then frequency=Float(Max(0,frequency-2))
	wave.SetFloat("time",time); ripple.SetFloat("time",time)
	wave.SetFloat("strength",strength); ripple.SetFloat("strength",strength)
	wave.SetFloat("frequency",frequency); ripple.SetFloat("frequency",frequency)
	wave.SetEdgeMode(edge); ripple.SetEdgeMode(edge)
	SetClsColor(16,20,30); Cls
	SetColor(255,255,255); SetBlend(ALPHABLEND)
	DrawText("Original",35,25); DrawText("Distortion",370,25); DrawText("Distortion + "+grades[preset],705,25)
	DrawImage(source,35,60)
	DrawImageEffect(source,wave,370,60)
	DrawImageEffect(source,ripple,705,60)
	DrawText("G: colour   Space: pause   E: edges   Up/down: strength   Left/right: frequency",35,430)
	DrawText("Edges: "+names[edge]+"   Strength: "+strength+"   Frequency: "+frequency,35,458)
	Flip
Wend
EndGraphics
