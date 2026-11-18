SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Effects
Import BRL.StandardIO
Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
Function Alpha:Float(x:Int, y:Int)
	If x < 8 Or x > 23 Or y < 8 Or y > 23 Then Return 0
	If x >= 14 And x <= 17 And y >= 14 And y <= 17 Then Return 0
	If x < 16 Then Return 1
	Return 0.5
End Function
Function Sample:Float(values:Float[], x:Float, y:Float)
	Local ix:Int = Int(Floor(x)), iy:Int = Int(Floor(y))
	Local fx:Float = x-ix, fy:Float = y-iy, result:Float
	For Local dy:Int = 0 Until 2
		For Local dx:Int = 0 Until 2
			Local xx:Int = ix+dx, yy:Int = iy+dy
			If xx < 0 Or xx >= 32 Or yy < 0 Or yy >= 32 Then Continue
			Local wx:Float = 1-fx, wy:Float = 1-fy
			If dx Then wx = fx
			If dy Then wy = fy
			result :+ values[yy*32+xx]*wx*wy
		Next
	Next
	Return result
End Function
Try
	Local shadow:TMax2DInnerShadow = CreateInnerShadow(4, 0, 0)
	Local weights:Int[] = [1,8,28,56,70,56,28,8,1]
	Local offsets:Float[] = [Float(0),0,3,-2,-3,2,1.5,-0.5,40,40]
	For Local lifetime:Int = 0 Until 2
		Graphics(64, 64)
		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		If Not Max2DSupportsImageEffect(CreateColorizeEffect()) Or Not Max2DSupportsLayerInverseAlpha() Then
			shadow.Prepare(32, 32, 2)
			Local source:TRenderImage = CreateRenderImage(32, 32)
			Local rejected:Int
			Try
				shadow.Update(source)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected And canvas.renderImage = Null, "unsupported inner shadow restores target")
			shadow.Release()
			EndGraphics
			Print "inner shadow unsupported"
			Exit
		End If
		shadow.SetRadius(4)
		shadow.Prepare(32, 32, 0, PF_RGBA32F)
		Local source:TRenderImage = CreateRenderImage(32, 32, 0, PF_RGBA32F)
		SetRenderImage(source)
		SetBlend(SOLIDBLEND)
		For Local y:Int = 0 Until 32
			For Local x:Int = 0 Until 32
				SetColor(220, 70, 20)
				SetAlpha(Alpha(x,y))
				DrawRect(x,y,1,1)
			Next
		Next
		SetImageHandle(source, 3, 5)
		Local before:TTextureData = ReadRenderTextureData(source)
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			For Local radius:Int = 0 To 4 Step 4
				shadow.SetRadius(radius)
				Local reference:Float[] = New Float[32*32]
				For Local y:Int = 0 Until 32
					For Local x:Int = 0 Until 32
						If radius = 0 Then
							reference[y*32+x] = Alpha(x,y)
						Else
							For Local dy:Int = -4 To 4
								For Local dx:Int = -4 To 4
									reference[y*32+x] :+ Alpha(x+dx,y+dy)*Float(weights[dx+4]*weights[dy+4])/65536
								Next
							Next
						End If
					Next
				Next
				For Local o:Int = 0 Until offsets.Length Step 2
					shadow.SetOffset(offsets[o],offsets[o+1])
					SetOrigin(9, 7)
					SetColor(10, 20, 30)
					SetAlpha(0.2)
					SetScale(2, 3)
					SetViewport(1, 2, 3, 4)
					Local result:TRenderImage = shadow.Update(source)
					Check(canvas.renderImage = source And Abs(GetAlpha()-0.2) < 0.001, "target and opacity restored")
					Local pixels:TTextureData = ReadRenderTextureData(result)
					Local p:Float Ptr = Float Ptr(pixels.Level().Data())
					For Local y:Int = 0 Until 32
						For Local x:Int = 0 Until 32
							Local expected:Float = Alpha(x,y)*(1-Sample(reference,x-offsets[o],y-offsets[o+1]))
							Local i:Int = (y*32+x)*4
							Check(Abs(p[i+3]-expected) < 0.00002, "inner alpha matches independent shifted kernel")
							If expected > 0.0001 Then Check(Abs(p[i]-1) < 0.00002 And Abs(p[i+1]-1) < 0.00002 And Abs(p[i+2]-1) < 0.00002, "white coverage ignores source RGB")
						Next
					Next
				Next
			Next
		Next
		ResetMax2DStats()
		shadow.Update(source)
		Local stats:TMax2DStats = CaptureMax2DStats()
		Check(stats.submissions = 5 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "full resolution cost")
		Local cached:TRenderImage = shadow.Result()
		shadow.Prepare(32,32,0,PF_RGBA32F)
		Check(shadow.Result() = cached, "same preparation retains cache")
		shadow.SetRadius(100)
		Local rejected:Int
		Try
			shadow.Update(source)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected And shadow.Result() = cached, "preflight failure preserves cache")
		shadow.SetRadius(8)
		shadow.Prepare(32,32,2,PF_RGBA32F)
		rejected = False
		Try
			shadow.Result()
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "layout change invalidates cache")
		shadow.SetOffset(3,3)
		shadow.Update(source)
		ResetMax2DStats()
		shadow.Update(source)
		stats = CaptureMax2DStats()
		Check(stats.submissions = 8 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "reduced steady-state cost")
		ResetMax2DStats()
		shadow.Result()
		stats = CaptureMax2DStats()
		Check(stats.submissions = 0, "cache lookup performs no draws")
		Local after:TTextureData = ReadRenderTextureData(source)
		Local a:Float Ptr = Float Ptr(before.Level().Data()), b:Float Ptr = Float Ptr(after.Level().Data())
		For Local i:Int = 0 Until 32*32*4
			Check(a[i] = b[i], "source pixels unchanged")
		Next
		EndGraphics
	Next
	shadow.Release()
	shadow.Release()
	Print "inner_shadow passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
