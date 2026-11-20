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

AppTitle = "Max2D blur - two explicit passes"
Graphics(960, 410)

Local horizontal:TMax2DBlurEffect = CreateBlurEffect(4)
Local vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)
Local supported:Int = Max2DSupportsImageEffect(horizontal) And Max2DSupportsRenderImage(120, 100, FILTEREDIMAGE)
Local source:TRenderImage, scratch:TRenderImage, result:TRenderImage
Local dirty:Int = True

If supported Then
	source = CreateRenderImage(120, 100, FILTEREDIMAGE)
	scratch = CreateRenderImage(120, 100, FILTEREDIMAGE)
	result = CreateRenderImage(120, 100, FILTEREDIMAGE)
	Local scope:TMax2DStateScope = ScopedMax2DState()
	Try
		SetRenderImage(source)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetColor(245, 100, 55)
		DrawOval(12, 12, 72, 72)
		SetColor(70, 170, 240)
		DrawRect(48, 35, 58, 48)
		SetColor(255, 215, 75)
		DrawRect(38, 24, 30, 34)
	Finally
		scope.Close()
	End Try
End If

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local change:Float
	If KeyHit(KEY_LEFT) Then change = -0.5
	If KeyHit(KEY_RIGHT) Then change = 0.5
	If change Then
		horizontal.SetRadius(Float(Max(0.0, Min(4.0, horizontal.GetRadius() + change))))
		vertical.SetRadius(horizontal.GetRadius())
		dirty = True
	End If
	If supported And dirty Then
		' Reuse both outputs and rebuild only when the source or radius changes.
		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			SetColor(255, 255, 255)
			SetAlpha(1)
			SetBlend(SOLIDBLEND)
			SetRenderImage(scratch)
			DrawImageEffect(source, horizontal, 0, 0)
			SetRenderImage(result)
			DrawImageEffect(scratch, vertical, 0, 0)
		Finally
			scope.Close()
		End Try
		dirty = False
	End If
	SetClsColor(24, 29, 39)
	Cls
	SetColor(255, 255, 255)
	DrawText("Blur radius: " + horizontal.GetRadius() + " source pixels", 25, 25)
	If supported Then
		DrawText("Original", 25, 75)
		DrawText("Horizontal pass", 340, 75)
		DrawText("Then vertical pass", 655, 75)
		SetScale(2.4, 2.4)
		DrawImage(source, 20, 105)
		DrawImage(scratch, 335, 105)
		DrawImage(result, 650, 105)
		SetScale(1, 1)
	Else
		DrawText("This device does not support the required blur shader and render images.", 25, 105)
	End If
	DrawText("Left / Right adjusts radius. Escape exits. Outputs are cached until changed.", 25, 375)
	Flip
Wend

EndGraphics
