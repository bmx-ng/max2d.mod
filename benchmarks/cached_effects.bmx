SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
Import BRL.StandardIO
Import "comparison_timing.c"
Extern "C"
	Function max2d_bench_seconds:Double()
	Function max2d_bench_visibility:Int(window:Byte Ptr)
End Extern
Try
	Local measured:Int = 100, repetitions:Int = 2
	If AppArgs.Length > 1 Then measured = Int(AppArgs[1])
	If AppArgs.Length > 2 Then repetitions = Int(AppArgs[2])
	If measured < 100 Or repetitions < 1 Then Throw "Use at least 100 frames and one repetition"
	Local names:String[] = ["source", "cached_shadow", "rebuild_shadow", "cached_inner", "rebuild_inner", "cached_bloom", "rebuild_bloom"]
	Local expected:Int[] = [1,2,8,2,10,1,10]
	Print "repeat,driver,size,mode,frames,cpu_draw_mean_ms,cpu_frame_mean_ms,cpu_frame_p95_ms,submissions_per_frame,texture_creations,uploads,readbacks,logical_image_bytes"
	For Local repetition:Int = 0 Until repetitions
		For Local size:Int = EachIn [128,512]
			For Local stepIndex:Int = 0 Until names.Length
				Local mode:Int = stepIndex
				If repetition Mod 2 Then mode = names.Length-1-stepIndex
				Graphics(640,600)
				Local window:Byte Ptr = TSDLGraphics(TMax2DGraphics.Current().context.graphics)._context.window.windowPtr
				Local source:TRenderImage = CreateRenderImage(UInt(size),UInt(size),FILTEREDIMAGE,PF_RGBA16F)
				SetRenderImage(source)
				SetClsColor(0,0,0,0)
				Cls
				For Local i:Int = 0 Until 9
					SetColor(80+i*15,160,220-i*15)
					SetAlpha(0.6+Float(i Mod 3)*0.2)
					DrawRect(size*(0.1+(i Mod 3)*0.28),size*(0.1+(i/3)*0.28),size*0.22,size*0.22)
				Next
				SetRenderImage(Null)
				SetColor(255,255,255); SetAlpha(1)
				Local shadow:TMax2DShadow, inner:TMax2DInnerShadow, bloom:TMax2DBloom
				Local tone:TMax2DLinearOutputEffect = CreateLinearOutputEffect()
				Local bytes:Long = Long(size)*size*8
				Select mode
					Case 1,2
						shadow = CreateShadow(8)
						shadow.Prepare(size,size,2,PF_RGBA16F)
						shadow.Update(source)
						bytes :+ Long(size)*size*16
					Case 3,4
						inner = CreateInnerShadow(8,4,4)
						inner.Prepare(size,size,2,PF_RGBA16F)
						inner.Update(source)
						bytes :+ Long(size)*size*24
					Case 5,6
						bloom = CreateBloom(0.5,8)
						bloom.Prepare(size,size,2,PF_RGBA16F)
						bloom.Update(source)
						bytes :+ Long(size)*size*24
				End Select
				If mode Then bytes :+ Long(size/2)*(size/2)*8+Long(size/4)*(size/4)*16
				Local times:Double[measured], drawing:Double, total:Double
				For Local frame:Int = -30 Until measured
					If frame = 0 Then ResetMax2DStats()
					Local start:Double = max2d_bench_seconds()
					If AppTerminate() Or KeyDown(KEY_ESCAPE) Then Throw "Benchmark interrupted"
					If max2d_bench_visibility(window) Then Throw "Benchmark window hidden or occluded"
					Select mode
						Case 2
							shadow.Update(source)
						Case 4
							inner.Update(source)
						Case 6
							bloom.Update(source)
					End Select
					SetClsColor(80,90,110)
					Cls
					If shadow Then
						SetColor(0,0,0); SetAlpha(0.6)
						DrawImage(shadow.Result(),28,28)
					End If
					SetColor(255,255,255); SetAlpha(1)
					If bloom Then DrawImageEffect(bloom.Result(),tone,20,20) Else DrawImage(source,20,20)
					If inner Then
						SetColor(0,0,0); SetAlpha(0.6)
						DrawImage(inner.Result(),20,20)
					End If
					SetColor(255,255,255); SetAlpha(1)
					FlushMax2D()
					Local drawn:Double = max2d_bench_seconds()
					Flip(0)
					Local finish:Double = max2d_bench_seconds()
					If frame >= 0 Then
						times[frame] = (finish-start)*1000
						drawing :+ (drawn-start)*1000
						total :+ times[frame]
					End If
				Next
				Local stats:TMax2DStats = CaptureMax2DStats()
				If stats.submissions <> Long(expected[mode])*measured Or stats.textureCreations Or stats.textureUpdates Or stats.readbacks Then Throw "Unexpected steady-state resource or submission count: "+names[mode]
				times.Sort()
				Print repetition+","+SDLGPUMax2DDriverName()+","+size+","+names[mode]+","+measured+","+drawing/measured+","+total/measured+","+times[Int(Ceil(measured*0.95))-1]+","+Double(stats.submissions)/measured+","+stats.textureCreations+","+stats.textureUpdates+","+stats.readbacks+","+bytes
				If shadow Then shadow.Release()
				If inner Then inner.Release()
				If bloom Then bloom.Release()
				EndGraphics
			Next
		Next
	Next
	Print "# benchmark complete"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
