SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects

AppTitle = "Max2D effects gallery"
Graphics(1000, 620)
Const w:Int = 240, h:Int = 220
Local names:String[] = ["Original", "Saturation", "Outline", "Blur", "Alpha mask", "Inverse mask", ..
	"Soft shadow", "Inner shadow", "HDR bloom (SDR presentation)", "Colour matrix", ..
	"Wave distortion", "Distortion + grading", "Displacement map", "Glowing dissolve", ..
	"Texture mask", "Moving texture mask", "Shared map across tiles", "Soft threshold mask"]
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
Local grade:TMax2DShaderEffect = CreateColorMatrixEffect()
grade.SetFloat4("row0",0.393,0.769,0.189,0)
grade.SetFloat4("row1",0.349,0.686,0.168,0)
grade.SetFloat4("row2",0.272,0.534,0.131,0)
Local wave:TMax2DShaderEffect = CreateDistortionEffect(0.04,22)
Local graded:TMax2DShaderEffect = CreateGradedDistortionEffect(0.04,22)
graded.SetFloat4("grade",0.25,1,1,0)
Local noisePixels:Float[] = New Float[w*h*4]
For Local y:Int = 0 Until h
	For Local x:Int = 0 Until w
		Local i:Int = (y*w+x)*4
		noisePixels[i] = 0.5+0.25*Sin(x*3+y)+0.2*Cos(y*4-x)
		noisePixels[i+1] = 0.5+0.4*Sin(y*3-x*2)
		noisePixels[i+2] = 0
		noisePixels[i+3] = 1
	Next
Next
Local noiseBytes:Byte[] = New Byte[noisePixels.Length*4]
MemCopy(noiseBytes,noisePixels,Size_T(noiseBytes.Length))
Local noise:TImage = LoadImage(TTextureData.Create([TTextureLevel.Create(w,h,PF_RGBA32F,noiseBytes)]),FILTEREDIMAGE)
Local displacement:TMax2DShaderEffect = CreateDisplacementEffect(noise,0.08,0.08)
Local dissolve:TMax2DShaderEffect = CreateDissolveEffect(noise)
Local textureMask:TMax2DShaderEffect = CreateTextureMaskEffect(mask)
Local movingMask:TMax2DShaderEffect = CreateTextureMaskEffect(mask)
Local sharedMask:TMax2DShaderEffect = CreateTextureMaskEffect(mask)
Local threshold:TMax2DShaderEffect = CreateThresholdMaskEffect(noise)
threshold.SetFloat4("channels",1,0,0,0)
Local tiles:TImage[] = New TImage[4]
For Local i:Int = 0 Until 4
	tiles[i] = CreateImageView(source,(i Mod 2)*(w/2),(i/2)*(h/2),w/2,h/2)
	SetImageHandle(tiles[i],w/4,h/4)
Next
Local selected:Int = 7, page:Int, grouped:Int, dirty:Int = True, radius:Float = 8
Local paused:Int, time:Float, previous:Int = MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int = MilliSecs(), elapsed:Int = now-previous
	previous = now
	If KeyHit(KEY_TAB) Then
		page = 1-page
		selected = page*9
	End If
	For Local i:Int = 0 To 8
		If KeyHit(KEY_0+i) Then selected = page*9+i
	Next
	If KeyHit(KEY_SPACE) Then paused = Not paused
	If Not paused Then time :+ Float(Min(elapsed,100))*0.001
	wave.SetFloat("time",time); graded.SetFloat("time",time)
	Local progress:Float = 0.5-0.5*Cos(time*45)
	dissolve.SetFloat("progress",progress)
	Local low:Float = progress*1.2-0.2
	threshold.SetFloat4("range",low,low+0.2,0,0)
	movingMask.SetTextureTransform(Float(0.2*Sin(time*50)),Float(0.1*Cos(time*40)),0.8,0.8,time*20)
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
	If page = 0 Then
		DrawText("0 Original  1 Saturation  2 Outline  3 Blur  4 Mask",30,65)
		DrawText("5 Inverse mask  6 Shadow  7 Inner shadow  8 Bloom",30,90)
	Else
		DrawText("0 Colour matrix  1 Waves  2 Graded waves  3 Displacement",30,65)
		DrawText("4 Dissolve  5 Texture mask  6 Moving mask  7 Shared map  8 Threshold",30,90)
	End If
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
		Case 9
			DrawImageEffect(source,grade,520,190)
		Case 10
			DrawImageEffect(source,wave,520,190)
		Case 11
			DrawImageEffect(source,graded,520,190)
		Case 12
			DrawImageEffect(source,displacement,520,190)
		Case 13
			DrawImageEffect(source,dissolve,520,190)
		Case 14
			DrawImageEffect(source,textureMask,520,190)
		Case 15
			DrawImageEffect(source,movingMask,520,190)
		Case 16
			Local placement:TMax2DDrawTransform = CaptureImageTransform(mask,520,190)
			For Local i:Int = 0 Until 4
				Local x:Float = 520+w/4+(i Mod 2)*(w/2)
				Local y:Float = 190+h/4+(i/2)*(h/2)
				SetRotation(Float(18*Sin(time*50+i*90)))
				sharedMask.SetTextureMapping(placement,tiles[i],x,y)
				DrawImageEffect(tiles[i],sharedMask,x,y)
			Next
			SetRotation(0)
		Case 17
			DrawImageEffect(source,threshold,520,190)
	End Select
	SetAlpha(1)
	SetColor(30,40,60)
	DrawText("Tab: switch pages ("+(page+1)+"/2)   0-8: select   Space: pause animation",30,440)
	DrawText("Left/Right: blur radius "+Int(radius)+" | Escape: exit",30,465)
	If selected = 7 Then
		Local grouping:String = "Independent shapes: neighbours do not alter each other's shadow."
		If grouped Then grouping = "Combined group: nearby shapes influence the shared blurred alpha."
		DrawText(grouping,30,500)
		DrawText("G: switch independent/group inner shadows",30,525)
	Else If selected = 8 Then
		DrawText("Linear HDR source and bloom, tone mapped to this SDR window.",30,500)
	Else If selected = 16 Then
		DrawText("One stationary mask spans four independently rotating source tiles.",30,500)
	Else If selected >= 9 Then
		DrawText("Reusable shader packages; maps and parameters are retained between frames.",30,500)
		If selected = 13 Then DrawText("The bright edge clips in this SDR window; use float layers for HDR.",30,525)
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
