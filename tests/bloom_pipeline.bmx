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
Try
	Local bloom:TMax2DBloom = CreateBloom(1, 8)
	Local rejected:Int
	Try
		bloom.SetIntensity(-1)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And bloom.GetIntensity() = 1, "invalid intensity preserves settings")
	For Local lifetime:Int = 0 Until 2
		Graphics(64, 64)
		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		If Not Max2DSupportsImageEffect(CreateBrightPassEffect()) Then
			bloom.Prepare(32, 32, 2, PF_RGBA8888)
			Local unsupportedSource:TRenderImage = CreateRenderImage(32, 32)
			rejected = False
			Try
				bloom.Update(unsupportedSource)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected And canvas.renderImage = Null, "unsupported bloom restores target")
			bloom.Release()
			EndGraphics
			Print "bloom shader unsupported"
			Exit
		End If
		bloom.Prepare(32, 32, 2)
		rejected = False
		Try
			bloom.Result()
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "new layout has no cached result")
		Local values:Float[] = New Float[32*32*4]
		For Local y:Int = 14 Until 18
			For Local x:Int = 14 Until 18
				Local offset:Int = (y*32+x)*4
				values[offset] = 8; values[offset+1] = 4; values[offset+2] = 2; values[offset+3] = 0.5
			Next
		Next
		Local bytes:Byte[] = New Byte[values.Length*4]
		MemCopy(bytes, values, Size_T(bytes.Length))
		Local image:TImage = LoadImage(TTextureData.Create([TTextureLevel.Create(32, 32, PF_RGBA32F, bytes)]), 0)
		Local source:TRenderImage = CreateRenderImage(32, 32, FILTEREDIMAGE, PF_RGBA16F)
		SetRenderImage(source)
		SetBlend(SOLIDBLEND)
		DrawImage(image, 0, 0)
		Local result:TRenderImage
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			bloom.SetIntensity(0)
			result = bloom.Update(source)
			Check(canvas.renderImage = source, "update restores target")
			Local zero:TTextureData = ReadRenderTextureData(result)
			bloom.SetIntensity(1)
			Check(bloom.Result() = result, "setting changes retain cached result")
			bloom.Update(source)
			Local one:TTextureData = ReadRenderTextureData(result)
			bloom.SetIntensity(2)
			bloom.Update(source)
			Local two:TTextureData = ReadRenderTextureData(result)
			Local z:Float Ptr = Float Ptr(zero.Level().Data()), a:Float Ptr = Float Ptr(one.Level().Data()), b:Float Ptr = Float Ptr(two.Level().Data())
			Local halo:Int
			For Local i:Int = 0 Until 32*32
				Check(z[i*4+3] = 1 And a[i*4+3] = 1 And b[i*4+3] = 1, "bloom output is opaque")
				For Local c:Int = 0 Until 3
					Check(Abs(z[i*4+c]-values[i*4+c]*values[i*4+3]) < 0.001, "zero intensity flattens source over black")
					Check(Abs((b[i*4+c]-z[i*4+c])-2*(a[i*4+c]-z[i*4+c])) < 0.008, "intensity scales only bloom")
				Next
				If values[i*4+3] = 0 And a[i*4] > 0.001 Then halo = True
			Next
			Check(halo, "glow survives outside source coverage")
			ResetMax2DStats()
			bloom.Prepare(32, 32, 2)
			Check(bloom.Result() = result, "identical preparation retains cached result")
			bloom.Update(source)
			Local stats:TMax2DStats = CaptureMax2DStats()
			Check(stats.submissions = 9 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "warm bloom uses nine draws without texture churn")
			ResetMax2DStats()
			bloom.Result()
			stats = CaptureMax2DStats()
			Check(stats.submissions = 0 And stats.textureCreations = 0, "cached result performs no rendering")
		Next
		' Rebuild between window draws, then verify the complete frame and restored tint/origin.
		SetRenderImage(Null)
		For Local frame:Int = 0 Until 3
			SetClsColor(0, 0, 0)
			Cls
			SetBlend(SOLIDBLEND)
			SetColor(255, 0, 0)
			SetOrigin(3, 4)
			DrawRect(0, 0, 8, 8)
			bloom.SetIntensity(Float(frame))
			bloom.Update(source)
			Check(canvas.renderImage = Null, "update restores window target")
			DrawRect(40, 40, 8, 8)
			Local nw:Int = NativeResolutionWidth(), nh:Int = NativeResolutionHeight()
			Local windowPixels:TPixmap = GrabPixmap(0, 0, nw, nh)
			Check((windowPixels.ReadPixel(5*nw/64, 6*nh/64) & $ffffff) = $ff0000, "window pixels before update survive")
			Check((windowPixels.ReadPixel(45*nw/64, 46*nh/64) & $ffffff) = $ff0000, "window drawing after update restores state")
			SetOrigin(0, 0)
			Flip
		Next
		bloom.SetRadius(100)
		rejected = False
		Try
			bloom.Update(source)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected And bloom.Result() = result, "invalid radius preserves previous result")
		bloom.SetRadius(8)
		SetRenderImage(Null)
		bloom.Prepare(40, 40, 2)
		rejected = False
		Try
			bloom.Result()
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "resize invalidates cached result")
		EndGraphics
	Next
	bloom.Release()
	bloom.Release()
	Print "bloom_pipeline passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
