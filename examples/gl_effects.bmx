SuperStrict
Framework Max2D.GLMax2D
Import Max2D.GLEffects

AppTitle="Max2D OpenGL image effects"
Graphics(1040,510)
Local source:TRenderImage=CreateRenderImage(240,200,FILTEREDIMAGE)
SetRenderImage(source)
SetClsColor(0,0,0,0); Cls
SetColor(50,140,230); DrawOval(15,15,110,110)
SetColor(245,170,60); SetAlpha(0.6); DrawRect(110,30,115,110)
SetColor(255,255,255); SetAlpha(1); SetScale(4,4); DrawText("Max2D",20,155); SetScale(1,1)
SetRenderImage(Null)
Local grey:TMax2DSaturationEffect=CreateSaturationEffect(0)
Local saturation:TMax2DSaturationEffect=CreateSaturationEffect(1.5)
Local colour:TMax2DColorizeEffect=CreateColorizeEffect(220,90,170)
Local amount:Float=1.5, palette:Int
Local positions:Float[200]
For Local i:Int=0 Until 100
	positions[i*2]=25+(i Mod 25)*40
	positions[i*2+1]=325+(i/25)*30
Next
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_LEFT) Then amount=Max(0,amount-0.1)
	If KeyHit(KEY_RIGHT) Then amount=Min(3,amount+0.1)
	If KeyHit(KEY_SPACE) Then
		palette=1-palette
		If palette Then colour.SetColor(60,200,170) Else colour.SetColor(220,90,170)
	End If
	saturation.SetAmount(amount)
	SetClsColor(25,30,42); Cls
	SetColor(255,255,255)
	DrawText("Original",20,25); DrawText("Grayscale",280,25)
	DrawText("Saturation: "+amount,540,25); DrawText("Colourize",800,25)
	DrawImage(source,20,70)
	DrawImageEffect(source,grey,280,70)
	DrawImageEffect(source,saturation,540,70)
	DrawImageEffect(source,colour,800,70)
	SetScale(0.12,0.12)
	ResetMax2DStats()
	DrawImageEffectBatch(source,colour,positions)
	Local stats:TMax2DStats=CaptureMax2DStats()
	SetScale(1,1)
	DrawText("100 colourized sprites: "+stats.submissions+" submission(s)",20,290)
	DrawText("Left/Right: saturation   Space: silhouette colour   Escape: exit",20,465)
	Flip
Wend
EndGraphics
