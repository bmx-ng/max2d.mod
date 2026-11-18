SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_sdlgpu And Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Effects
Import BRL.StandardIO
Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
Try
	Local buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
	For Local lifetime:Int = 0 Until 2
		Graphics(96, 96)
		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		Local source:TRenderImage = CreateRenderImage(17, 13, FILTEREDIMAGE)
		SetRenderImage(source)
		SetClsColor(80, 120, 160)
		Cls
		canvas.context.Flush()
		ResetMax2DStats()
		buffers.Prepare(17, 13)
		Local stats:TMax2DStats = CaptureMax2DStats()
		Check(stats.textureCreations = 2, "chain-only preparation materializes exactly two textures")
		Check(canvas.renderImage = source, "preparation preserves target")
		Local first:TRenderImage = buffers.Image(0)
		Local empty:TMax2DImageEffect[]
		buffers.ApplyChain(source, 0, empty)
		Local before:Int = ReadRenderImage(first).ReadPixel(0, 0)
		ResetMax2DStats()
		buffers.Prepare(17, 13)
		stats = CaptureMax2DStats()
		Check(stats.textureCreations = 0 And stats.submissions = 0, "same layout is a no-op")
		Check(buffers.Image(0) = first And ReadRenderImage(first).ReadPixel(0, 0) = before, "same layout preserves identity and pixels")
		Local rejected:Int
		Try
			buffers.Prepare(17, 13, 2, 99)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected And buffers.Image(0) = first, "invalid layout preserves old images")
		SetRenderImage(first)
		rejected = False
		Try
			buffers.Release()
		Catch error:Object
			rejected = True
		End Try
		Check(rejected And canvas.renderImage = first, "selected storage cannot be released")
		rejected = False
		Try
			buffers.Prepare(20, 20)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected And buffers.Image(0) = first, "selected storage cannot be resized")
		SetRenderImage(source)
		ResetMax2DStats()
		buffers.Prepare(17, 13, 2, 2)
		stats = CaptureMax2DStats()
		Check(stats.textureCreations = 5 And buffers.Image(0) <> first, "pyramid layout materialized")
		If Max2DSupportsImageEffect(CreateBlurEffect()) Then
			Local blur:TMax2DScaledBlur = CreateScaledBlur(8)
			Local reference:TRenderImage = CreateRenderImage(17, 13, FILTEREDIMAGE)
			Local levels:TRenderImage[] = [CreateRenderImage(9, 7, FILTEREDIMAGE), CreateRenderImage(5, 4, FILTEREDIMAGE)]
			Local scratch:TRenderImage = CreateRenderImage(5, 4, FILTEREDIMAGE)
			blur.Apply(source, reference, levels, scratch)
			buffers.ApplyBlur(source, 0, blur)
			Local expected:TPixmap = ReadRenderImage(reference), actual:TPixmap = ReadRenderImage(buffers.Image(0))
			For Local y:Int = 0 Until 13
				For Local x:Int = 0 Until 17
					Check(expected.ReadPixel(x, y) = actual.ReadPixel(x, y), "owned blur matches manual buffers")
				Next
			Next
			ResetMax2DStats()
			buffers.Prepare(17, 13, 2, 2)
			buffers.ApplyBlur(source, 0, blur)
			stats = CaptureMax2DStats()
			Check(stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0 And stats.submissions = 5, "warm blur has five draws and no texture churn")
			Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(CreateSaturationEffect(0)), TMax2DImageEffect(CreateColorizeEffect(255, 80, 30))]
			buffers.ApplyChain(source, 0, chain)
			Check(canvas.renderImage = source, "chain restores source target")
			ResetMax2DStats()
			buffers.ApplyChain(source, 0, chain)
			stats = CaptureMax2DStats()
			Check(stats.submissions = 2 And stats.textureCreations = 0 And stats.textureUpdates = 0, "warm chain reuses scratch")
		End If
		SetRenderImage(Null)
		Local oldFrame:TImageFrame = buffers.Image(0).Frame()
		buffers.Prepare(19, 15, 1, 0)
		FlushMax2D()
		Check(oldFrame.closed And buffers.Image(0).width = 19 And buffers.Image(0).height = 15, "resize replaces storage and drains old frames")
		Local other:TGraphics = CreateGraphics(40, 40, 0, 0, 0, -1, -1)
		SetGraphics(other)
		rejected = False
		Try
			buffers.Prepare(19, 15, 1, 0)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "live context migration rejected")
		rejected = False
		Try
			buffers.Image(0)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "borrowed image access checks current context")
		other.Close()
		SetGraphics(canvas)
		Check(buffers.Image(0).width = 19, "foreign context failure preserves layout")
		' Keep the owner across context closure; the next Prepare rebuilds it.
		EndGraphics
	Next
	buffers.Release()
	buffers.Release()
	Print "effect_buffers passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
