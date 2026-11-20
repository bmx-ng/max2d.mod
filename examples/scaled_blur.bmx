SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle = "Max2D scaled blur comparison"
Graphics(1000, 460)
Local source:TRenderImage
Local outputs:TRenderImage[3]
Local work:TRenderImage[3]
Local pyramids:TRenderImage[][3]
Local blur:TMax2DScaledBlur = CreateScaledBlur(4)
Local supported:Int = Max2DSupportsImageEffect(CreateBlurEffect()) And Max2DSupportsRenderImage(128, 128, FILTEREDIMAGE)
Local wide:Int = True, dirty:Int = True
If supported Then
	source = CreateRenderImage(128, 128, FILTEREDIMAGE)
	For Local count:Int = 0 To 2
		outputs[count] = CreateRenderImage(128, 128, FILTEREDIMAGE)
		pyramids[count] = New TRenderImage[count]
		Local size:Int = 128
		For Local i:Int = 0 Until count
			size :/ 2
			pyramids[count][i] = CreateRenderImage(UInt(size), UInt(size), FILTEREDIMAGE)
		Next
		work[count] = CreateRenderImage(UInt(size), UInt(size), FILTEREDIMAGE)
	Next
	SetRenderImage(source)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(245, 100, 55)
	DrawOval(28, 28, 60, 60)
	SetColor(70, 170, 240)
	DrawRect(65, 50, 35, 45)
	SetColor(255, 230, 80)
	For Local x:Int = 32 To 96 Step 4
		DrawRect(x, 20, 1, 10)
	Next
	SetRenderImage(Null)
End If
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_SPACE) Then
		wide = Not wide
		dirty = True
	End If
	If supported And dirty Then
		For Local count:Int = 0 To 2
			Local radius:Float = 4
			If wide Then radius = 4 Shl count
			blur.SetRadius(radius)
			blur.Apply(source, outputs[count], pyramids[count], work[count])
		Next
		dirty = False
	End If
	SetClsColor(24, 29, 39)
	Cls
	SetColor(255, 255, 255)
	Local label:String = "Same radius: compare reduction quality"
	If wide Then label = "Wider radius at lower resolution"
	DrawText(label, 25, 20)
	If supported Then
		For Local count:Int = 0 To 2
			Local x:Int = 25 + count*325
			Local radius:Int = 4
			If wide Then radius = 4 Shl count
			Local passes:Int = 2
			If count Then passes = count+3
			DrawText((128 Shr count) + " x " + (128 Shr count) + " | radius " + radius, x, 65)
			DrawText(passes + " draws per rebuild", x, 90)
			SetScale(2.25, 2.25)
			DrawImage(outputs[count], x, 120)
			SetScale(1, 1)
		Next
	Else
		DrawText("Required blur shader is unavailable.", 25, 100)
	End If
	DrawText("Space: equal / wider radii. Escape: exit. Cached outputs: one draw each.", 25, 430)
	Flip
Wend
EndGraphics
