SuperStrict

Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
Import BRL.StandardIO
Import "comparison_timing.c"

Extern "C"
	Function max2d_bench_seconds:Double()
	Function max2d_bench_visibility:Int(window:Byte Ptr)
End Extern

Function PrepareLayer(layer:TRenderImage, mask:TImage)
	SetRenderImage(layer)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(200, 100, 50)
	DrawRect(0, 0, layer.width, layer.height)
	ApplyLayerAlphaMask(mask)
	SetRenderImage(Null)
	SetColor(255, 255, 255)
End Function

Try
	Local measured:Int = 120
	If AppArgs.Length > 1 Then measured = Int(AppArgs[1])
	If measured < 100 Then Throw "Use at least 100 measured frames"
	Print "size,mode,draw_mean_ms,frame_mean_ms,frame_p95_ms,batches_per_frame,texture_creations,uploads,readbacks,layer_and_mask_bytes"
	For Local size:Int = EachIn [128, 512]
		For Local mode:Int = 0 Until 3
			If Not Graphics(640, 600, 0, 0) Then Throw "Cannot create graphics"
			Local effect:TMax2DSaturationEffect = CreateSaturationEffect(0)
			If Not Max2DSupportsImageEffect(effect) Or Not Max2DSupportsLayerAlpha() Then Throw "Effects unavailable"
			Local window:Byte Ptr = TSDLGraphics(TMax2DGraphics.Current().context.graphics)._context.window.windowPtr
			Local layer:TRenderImage = CreateRenderImage(UInt(size), UInt(size), 0)
			Local mask:TImage = CreateImage(size, size, 1, DYNAMICIMAGE)
			Local pixels:TPixmap = LockImage(mask)
			For Local y:Int = 0 Until size
				For Local x:Int = 0 Until size
					pixels.WritePixel(x, y, ((x * 255 / (size - 1)) Shl 24) | $ffffff)
				Next
			Next
			UnlockImage(mask)
			PrepareLayer(layer, mask)
			Local times:Double[measured]
			Local drawTime:Double
			Local frameTime:Double
			For Local frame:Int = 0 Until measured + 30
				If frame = 30 Then ResetMax2DStats()
				Local start:Double = max2d_bench_seconds()
				If AppTerminate() Or KeyDown(KEY_ESCAPE) Then Throw "Benchmark interrupted"
				If max2d_bench_visibility(window) Then Throw "Benchmark window hidden or occluded"
				If mode = 2 Then PrepareLayer(layer, mask)
				SetClsColor(24, 29, 39)
				Cls
				If mode = 0 Then
					DrawImage(layer, 20, 20)
				Else
					DrawImageEffect(layer, effect, 20, 20)
				End If
				FlushMax2D()
				Local drawn:Double = max2d_bench_seconds()
				Flip(0)
				Local finished:Double = max2d_bench_seconds()
				If frame >= 30 Then
					times[frame - 30] = (finished - start) * 1000
					drawTime :+ (drawn - start) * 1000
					frameTime :+ times[frame - 30]
				End If
			Next
			Local stats:TMax2DStats = CaptureMax2DStats()
			Print "# driver=" + SDLGPUMax2DDriverName() + " pixels=" + NativeResolutionWidth() + "x" + NativeResolutionHeight()
			times.Sort()
			Local names:String[] = ["cached", "shader", "rebuild_mask_shader"]
			Print size + "," + names[mode] + "," + drawTime / measured + "," + frameTime / measured + "," + times[Int(Ceil(measured * 0.95)) - 1] + "," + Double(stats.submissions) / measured + "," + stats.textureCreations + "," + stats.textureUpdates + "," + stats.readbacks + "," + Long(size) * size * 8
			EndGraphics
		Next
	Next
	Print "# benchmark complete"
Catch error:Object
	Print "FAILED: " + error.ToString()
	EndWithCode(1)
End Try
