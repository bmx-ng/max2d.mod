SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?Not max2d_gl And Not max2d_d3d11 And Not max2d_d3d9
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle = "Max2D reusable soft shadows"
Graphics(900, 520)
Local shadow:TMax2DShadow = CreateShadow(12)
Local source:TRenderImage = CreateRenderImage(240, 220)
Local supported:Int = Max2DSupportsImageEffect(CreateColorizeEffect()) And Max2DSupportsImageEffect(CreateBlurEffect())
If supported Then
	shadow.Prepare(240, 220, 2)
	SetRenderImage(source)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(70, 150, 220)
	DrawOval(40, 36, 110, 110)
	SetColor(245, 175, 65)
	DrawRect(100, 100, 95, 70)
	SetColor(255, 255, 255)
	DrawText("Max2D", 62, 85)
	SetRenderImage(Null)
	shadow.Update(source)
End If
Local opacity:Float = 0.6, offset:Float = 14
Local coloured:Int, visible:Int = True, dirty:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_LEFT) Then
		shadow.SetRadius(Float(Max(0, shadow.GetRadius()-2)))
		dirty = True
	End If
	If KeyHit(KEY_RIGHT) Then
		shadow.SetRadius(Float(Min(16, shadow.GetRadius()+2)))
		dirty = True
	End If
	If KeyHit(KEY_UP) Then opacity = Float(Min(1, opacity+0.1))
	If KeyHit(KEY_DOWN) Then opacity = Float(Max(0, opacity-0.1))
	If KeyHit(KEY_O) Then offset = Float((offset+7) Mod 35)
	If KeyHit(KEY_C) Then coloured = Not coloured
	If KeyHit(KEY_SPACE) Then visible = Not visible
	If dirty And supported Then
		shadow.Update(source)
		dirty = False
	End If
	SetClsColor(225, 230, 240)
	Cls
	SetColor(30, 40, 60)
	DrawText("Reusable soft shadows", 30, 25)
	DrawText("Original", 90, 85)
	DrawText("Cached shadow + source", 480, 85)
	If supported Then
		SetColor(255, 255, 255)
		SetAlpha(1)
		DrawImage(source, 70, 125)
		If visible Then
			SetColor(0, 0, 0)
			If coloured Then SetColor(95, 40, 190)
			SetAlpha(opacity)
			DrawImage(shadow.Result(), 470+offset, 125+offset)
		End If
		SetColor(255, 255, 255)
		SetAlpha(1)
		DrawImage(source, 470, 125)
	Else
		DrawText("This backend does not support the required effects.", 30, 160)
	End If
	SetColor(30, 40, 60)
	DrawText("Left/Right: radius | Up/Down: opacity | O: offset | C: colour", 30, 410)
	DrawText("Space: shadow on/off | Escape: exit", 30, 435)
	DrawText("Radius: "+shadow.GetRadius()+" | Opacity: "+opacity+" | Offset: "+offset, 30, 470)
	Flip
Wend
shadow.Release()
EndGraphics
