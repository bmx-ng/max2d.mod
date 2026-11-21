SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d11 And Not max2d_d3d9
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Effects
Import BRL.StandardIO
Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
Try
	Graphics(96, 96)
	Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
	Local parent:TRenderImage = CreateRenderImage(96, 96, FILTEREDIMAGE)
	SetRenderImage(parent)
	SetVirtualResolution(96, 96)
	Local layer:TMax2DEffectLayer = New TMax2DEffectLayer
	layer.Prepare(10, 8, 3, 4, 5, 6, 2)
	Check(layer.Image().width = 36 And layer.Image().height = 36, "asymmetric padding and resolution determine storage")
	SetColor(19, 23, 27); SetAlpha(0.3); SetScale(3, 4); SetOrigin(7, 9)
	Local rejected:Int
	Try
		Using
			Local capture:TMax2DStateScope = layer.Capture()
		Do
			DrawRect(0, 0, 10, 8)
			Try
				layer.Release()
			Catch error:Object
				rejected = True
			End Try
			Check(rejected, "release during capture rejected")
			rejected = False
			Try
				layer.Capture()
			Catch error:Object
				rejected = True
			End Try
			Check(rejected, "recursive capture rejected")
			Throw "intentional capture exception"
		End Using
	Catch error:Object
		Check(String(error) = "intentional capture exception", "unexpected capture failure: " + String(error))
	End Try
	Check(canvas.renderImage = parent, "capture exception restores parent target")
	Local red:Int, green:Int, blue:Int, sx:Float, sy:Float, ox:Float, oy:Float
	GetColor(red, green, blue); GetScale(sx, sy); GetOrigin(ox, oy)
	Check(red = 19 And green = 23 And blue = 27 And Abs(GetAlpha()-0.3) < 0.001, "capture restores tint")
	Check(sx = 3 And sy = 4 And ox = 7 And oy = 9, "capture restores coordinates")
	Local pixels:TPixmap = ReadRenderImage(layer.Image())
	Check(pixels.ReadPixel(10, 12) = $ffffffff, "capture resets inherited transform and tint")
	Check(pixels.ReadPixel(0, 0) = 0 And pixels.ReadPixel(32, 32) = 0, "padding remains transparent")
	Local first:TRenderImage = layer.Image()
	ResetMax2DStats()
	layer.Prepare(10, 8, 3, 4, 5, 6, 2)
	Check(layer.Image() = first And CaptureMax2DStats().textureCreations = 0, "identical prepare reuses capture")
	Using
		Local capture:TMax2DStateScope = layer.Capture(False)
	Do
		SetColor(255, 0, 0)
		DrawRect(0, 0, 2, 2)
	End Using
	pixels = ReadRenderImage(layer.Image())
	Check(pixels.ReadPixel(7, 9) = $ffff0000 And pixels.ReadPixel(18, 18) = $ffffffff, "capture without clearing retains pixels")
	SetScale(1, 1); SetOrigin(0, 0); SetColor(255, 255, 255); SetAlpha(1); SetBlend(SOLIDBLEND)
	SetClsColor(0, 0, 0, 0); Cls
	SetImageHandle(layer.Image(), 99, 99)
	layer.Draw(20, 20)
	pixels = ReadRenderImage(parent)
	Check(pixels.ReadPixel(20, 20) = $ffff0000 And pixels.ReadPixel(25, 24) = $ffffffff, "draw preserves logical origin and ignores image handle")
	Check(pixels.ReadPixel(18, 18) = 0 And pixels.ReadPixel(31, 29) = 0, "draw includes transparent padding at logical size")

	Local empty:TMax2DImageEffect[]
	Local chain:TMax2DEffectChain = CreateEffectChain(empty)
	ResetMax2DStats()
	chain.Prepare(36, 36)
	Check(CaptureMax2DStats().textureCreations = 1, "copy chain allocates only its output")
	chain.Update(layer.Image())
	Local result:TRenderImage = chain.Result()
	Check(ReadRenderImage(result).ReadPixel(7, 9) = $ffff0000, "empty chain copies source")
	ResetMax2DStats()
	chain.Prepare(36, 36)
	Check(chain.Result() = result And CaptureMax2DStats().textureCreations = 0, "identical preparation retains result")
	If Max2DSupportsImageEffect(CreateSaturationEffect()) Then
		Local effects:TMax2DImageEffect[] = [TMax2DImageEffect(CreateSaturationEffect(0)), TMax2DImageEffect(CreateColorizeEffect(0, 255, 0))]
		chain.SetEffects(effects)
		effects[0] = Null
		rejected = False
		Try
			chain.Update(layer.Image())
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "changed configuration requires preparation")
		ResetMax2DStats()
		chain.Prepare(36, 36)
		Check(CaptureMax2DStats().textureCreations = 2, "multi-pass chain allocates output and scratch")
		chain.Update(layer.Image())
		Check(ReadRenderImage(chain.Result()).ReadPixel(18, 18) = $ff00ff00, "ordered chain owns array and applies both stages")
		ResetMax2DStats()
		chain.Update(layer.Image())
		Check(CaptureMax2DStats().textureCreations = 0, "warm chain allocates no textures")
		SetClsColor(0, 0, 0, 0); Cls
		layer.Draw(20, 20, chain.Result())
		Check(ReadRenderImage(parent).ReadPixel(25, 24) = $ff00ff00, "processed result shares padded placement")
	End If
	rejected = False
	Try
		chain.Update(chain.Result())
	Catch error:Object
		rejected = True
	End Try
	Check(rejected, "output cannot be its own source")
	rejected = False
	Try
		chain.Result()
	Catch error:Object
		rejected = True
	End Try
	Check(rejected, "failed update invalidates cached result")
	Local nested:TMax2DEffectLayer = New TMax2DEffectLayer
	nested.Prepare(4, 4)
	Using
		Local outer:TMax2DStateScope = layer.Capture(False)
	Do
		Using
			Local inner:TMax2DStateScope = nested.Capture()
		Do
			DrawRect(0, 0, 4, 4)
		End Using
		Check(canvas.renderImage = layer.Image(), "nested capture restores outer target")
		GetOrigin(ox, oy)
		Check(ox = 3 And oy = 4, "nested capture restores outer padding")
	End Using
	Check(canvas.renderImage = parent, "outer capture restores parent")
	nested.Release()
	rejected = False
	Try
		layer.Prepare(2147483647, 8, 2147483647, 0, 2147483647, 0, 2147483647)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And layer.Image() = first, "overflow rejected without losing existing source")
	SetClsColor(0, 0, 0, 0); Cls
	SetScale(2, 2)
	layer.Draw(20, 20)
	pixels = ReadRenderImage(parent)
	Check(pixels.ReadPixel(21, 21) = $ffff0000 And pixels.ReadPixel(36, 32) = $ffffffff, "layer placement respects caller object scale")
	SetScale(1, 1)
	chain.Release(); chain.Release()
	layer.Release(); layer.Release()
	SetRenderImage(Null)
	parent.ReleaseFrames()
	' Closing a context during capture must still permit cleanup and reuse.
	nested.Prepare(4, 4)
	Local abandoned:TMax2DStateScope = nested.Capture()
	EndGraphics
	nested.Release()
	abandoned.Close()
	Graphics(32, 32)
	nested.Prepare(4, 4)
	Using
		Local capture:TMax2DStateScope = nested.Capture()
	Do
		DrawRect(0, 0, 4, 4)
	End Using
	Check(ReadRenderImage(nested.Image()).ReadPixel(2, 2) = $ffffffff, "layer can be reused after context closure")
	nested.Release()
	EndGraphics
	Print "composition helpers passed"
Catch error:Object
	Print "FAIL: " + error.ToString()
	EndGraphics
	EndWithCode(1)
End Try
