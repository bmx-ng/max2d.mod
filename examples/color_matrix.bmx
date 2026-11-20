SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle = "Max2D packaged colour effects"
Graphics(940,420)
Local source:TRenderImage = CreateRenderImage(280,260,FILTEREDIMAGE)
SetRenderImage(source)
SetClsColor(0,0,0,0)
Cls
SetColor(60,150,235)
DrawOval(15,20,150,150)
SetColor(245,165,55)
DrawRect(140,75,120,130)
SetColor(240,70,125)
DrawOval(55,120,110,110)
SetColor(255,255,255)
SetScale(3,3)
DrawText("Max2D",45,225)
SetScale(1,1)
SetRenderImage(Null)
Local grade:TMax2DShaderEffect = CreateColorMatrixEffect()
Local sepia:TMax2DShaderEffect = CreateColorMatrixEffect()
sepia.SetFloat4("row0",0.393,0.769,0.189,0)
sepia.SetFloat4("row1",0.349,0.686,0.168,0)
sepia.SetFloat4("row2",0.272,0.534,0.131,0)
Local contrast:Float = 1.3, brightness:Float = 0.05
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_LEFT) Then contrast = Float(Max(0,contrast-0.1))
	If KeyHit(KEY_RIGHT) Then contrast :+ 0.1
	If KeyHit(KEY_UP) Then brightness :+ 0.05
	If KeyHit(KEY_DOWN) Then brightness :- 0.05
	If KeyHit(KEY_SPACE) Then contrast=1; brightness=0
	grade.SetFloat4("row0",contrast,0,0,0)
	grade.SetFloat4("row1",0,contrast,0,0)
	grade.SetFloat4("row2",0,0,contrast,0)
	Local bias:Float = 0.5*(1-contrast)+brightness
	grade.SetFloat4("bias",bias,bias,bias,0)
	SetClsColor(25,29,38)
	Cls
	SetColor(255,255,255)
	SetBlend(ALPHABLEND)
	DrawText("Original",30,25)
	DrawText("Contrast + brightness",330,25)
	DrawText("Sepia matrix",630,25)
	DrawImage(source,30,55)
	DrawImageEffect(source,grade,330,55)
	DrawImageEffect(source,sepia,630,55)
	DrawText("Left/right: contrast   Up/down: brightness   Space: reset   Esc: exit",30,345)
	DrawText("Contrast: "+contrast+"   Brightness: "+brightness,30,370)
	Flip
Wend
EndGraphics
