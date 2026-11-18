SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects

AppTitle = "Max2D effects gallery"
Graphics(1000, 620)
Const w:Int = 240, h:Int = 220
Local names:String[] = ["Original", "Saturation", "Outline", "Blur", "Alpha mask", "Inverse mask", "Soft shadow", "Inner shadow", "HDR bloom (SDR presentation)"]
Local source:TRenderImage = CreateRenderImage(w, h, FILTEREDIMAGE)
Local parts:TRenderImage[] = New TRenderImage[3]
Local inner:TMax2DInnerShadow = CreateInnerShadow(8, 4, 4)
Local individual:TMax2DInnerShadow[] = New TMax2DInnerShadow[3]
Local shadow:TMax2DShadow = CreateShadow(8)
Local buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
Local blur:TMax2DScaledBlur = CreateScaledBlur(8)
Local saturation:TMax2DSaturationEffect = CreateSaturationEffect(0)
Local outline:TMax2DOutlineEffect = CreateOutlineEffect(3)
Local bloom:TMax2DBloom = CreateBloom(1, 8)
Local tone:TMax2DLinearOutputEffect = CreateLinearOutputEffect()
Local copies:TMax2DImageEffect[] = New TMax2DImageEffect[0]
For Local i:Int = 0 Until 3
	parts[i] = CreateRenderImage(w,h)
	SetRenderImage(parts[i])
	SetClsColor(0,0,0,0)
	Cls
	Select i
		Case 0
			SetColor(70,150,220)
			DrawOval(25,25,100,100)
		Case 1
			SetColor(245,175,65)
			DrawRect(130,25,90,100)
		Case 2
			SetColor(255,255,255)
			SetScale(4,4)
			DrawText("Max2D",25,150)
			SetScale(1,1)
	End Select
Next
SetRenderImage(source)
SetClsColor(0,0,0,0)
Cls
SetColor(255,255,255)
For Local part:TRenderImage = EachIn parts
	DrawImage(part,0,0)
Next
SetRenderImage(Null)
buffers.Prepare(w,h,3,2)
Local mask:TImage = CreateImage(w,h,1,DYNAMICIMAGE)
Local p:TPixmap = LockImage(mask)
For Local y:Int = 0 Until h
	For Local x:Int = 0 Until w
		Local dx:Float = x-120, dy:Float = y-100
		Local a:Float = Float(Max(0,Min(1,(100-Sqr(dx*dx+dy*dy))/20)))
		p.WritePixel(x,y,(Int(a*255) Shl 24) | $ffffff)
	Next
Next
UnlockImage(mask)
For Local i:Int = 1 To 2
	buffers.ApplyChain(source,i,copies)
	SetRenderImage(buffers.Image(i))
	If i = 1 Then ApplyLayerAlphaMask(mask) Else ApplyLayerInverseAlphaMask(mask)
Next
SetRenderImage(Null)
shadow.Prepare(w,h,2)
inner.Prepare(w,h,2)
For Local i:Int = 0 Until 3
	individual[i] = CreateInnerShadow(8,4,4)
	individual[i].Prepare(w,h,2)
Next
' Convert once, then add HDR energy to the bright artwork for the bloom panel.
Local linear:TTextureData = SRGBPixmapToLinearTextureData(ReadRenderImage(source))
Local values:Float Ptr = Float Ptr(linear.Level().Data())
For Local i:Int = 0 Until w*h
	If Max(values[i*4],Max(values[i*4+1],values[i*4+2])) > 0.7 Then
		For Local c:Int = 0 Until 3
			values[i*4+c] :* 5
		Next
	End If
Next
Local hdr:TRenderImage = CreateRenderImage(w,h,FILTEREDIMAGE,PF_RGBA16F)
Local uploaded:TImage = LoadImage(linear,0)
SetRenderImage(hdr)
SetClsColor(0,0,0,1)
Cls
SetBlend(ALPHABLEND)
DrawImage(uploaded,0,0)
SetRenderImage(Null)
SetBlend(ALPHABLEND)
bloom.Prepare(w,h,2)
Local selected:Int = 7, grouped:Int, dirty:Int = True, radius:Float = 8
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	For Local i:Int = 0 To 8
		If KeyHit(KEY_0+i) Then selected = i
	Next
	If KeyHit(KEY_G) Then grouped = Not grouped
	If KeyHit(KEY_LEFT) Then
		radius = Float(Max(0,radius-2)); dirty = True
	End If
	If KeyHit(KEY_RIGHT) Then
		radius = Float(Min(16,radius+2)); dirty = True
	End If
	If dirty Then
		blur.SetRadius(radius)
		buffers.ApplyBlur(source,0,blur)
		shadow.SetRadius(radius); shadow.Update(source)
		inner.SetRadius(radius); inner.Update(source)
		For Local i:Int = 0 Until 3
			individual[i].SetRadius(radius); individual[i].Update(parts[i])
		Next
		bloom.SetRadius(radius); bloom.Update(hdr)
		dirty = False
	End If
	SetClsColor(225,230,240)
	Cls
	SetColor(30,40,60)
	DrawText("Max2D effects gallery",30,25)
	DrawText("0 Original  1 Saturation  2 Outline  3 Blur  4 Mask",30,65)
	DrawText("5 Inverse mask  6 Shadow  7 Inner shadow  8 Bloom",30,90)
	DrawText("Source",90,145)
	DrawText(names[selected],520,145)
	SetColor(255,255,255)
	If selected = 8 Then
		DrawImageEffect(hdr,tone,70,190)
	Else
		DrawImage(source,70,190)
	End If
	Select selected
		Case 0
			DrawImage(source,520,190)
		Case 1
			DrawImageEffect(source,saturation,520,190)
		Case 2
			SetColor(110,50,180)
			DrawImageEffect(source,outline,520,190)
			SetColor(255,255,255)
			DrawImage(source,520,190)
		Case 3,4,5
			DrawImage(buffers.Image(selected-3),520,190)
		Case 6
			SetColor(0,0,0); SetAlpha(0.6)
			DrawImage(shadow.Result(),530,200)
			SetColor(255,255,255); SetAlpha(1)
			DrawImage(source,520,190)
		Case 7
			DrawImage(source,520,190)
			SetColor(0,0,0); SetAlpha(0.6)
			If grouped Then
				DrawImage(inner.Result(),520,190)
			Else
				For Local effect:TMax2DInnerShadow = EachIn individual
					DrawImage(effect.Result(),520,190)
				Next
			End If
		Case 8
			DrawImageEffect(bloom.Result(),tone,520,190)
	End Select
	SetAlpha(1)
	SetColor(30,40,60)
	DrawText("Left/Right: blur radius "+Int(radius)+" | Escape: exit",30,465)
	If selected = 7 Then
		Local grouping:String = "Independent shapes: neighbours do not alter each other's shadow."
		If grouped Then grouping = "Combined group: nearby shapes influence the shared blurred alpha."
		DrawText(grouping,30,500)
		DrawText("G: switch independent/group inner shadows",30,525)
	Else If selected = 8 Then
		DrawText("Linear HDR source and bloom, tone mapped to this SDR window.",30,500)
	Else
		DrawText("Effects operate on the combined source layer.",30,500)
	End If
	Flip
Wend
SetRenderImage(Null)
buffers.Release(); shadow.Release(); inner.Release(); bloom.Release()
For Local effect:TMax2DInnerShadow = EachIn individual
	effect.Release()
Next
EndGraphics
