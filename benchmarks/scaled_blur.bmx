SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
Import BRL.StandardIO
Import "timing.c"
Extern "C"
	Function max2d_bench_seconds:Double()
End Extern

Graphics(640, 600)
Print "driver,size,levels,radius,cached,frames,mean_cpu_ms,submissions,texture_creations,uploads,readbacks,retained_bytes"
For Local size:Int = 256 To 512 Step 256
	For Local count:Int = 0 To 2
		Local source:TRenderImage = CreateRenderImage(UInt(size), UInt(size), FILTEREDIMAGE)
		Local output:TRenderImage = CreateRenderImage(UInt(size), UInt(size), FILTEREDIMAGE)
		Local levels:TRenderImage[] = New TRenderImage[count]
		Local small:Int = size, bytes:Int = size*size*8
		For Local i:Int = 0 Until count
			small :/ 2
			levels[i] = CreateRenderImage(UInt(small), UInt(small), FILTEREDIMAGE)
			bytes :+ small*small*4
		Next
		Local scratch:TRenderImage = CreateRenderImage(UInt(small), UInt(small), FILTEREDIMAGE)
		bytes :+ small*small*4
		Local radius:Int = 4 Shl count
		Local blur:TMax2DScaledBlur = CreateScaledBlur(radius)
		SetRenderImage(source)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetColor(255, 90, 40)
		DrawOval(size/4, size/4, size/2, size/2)
		SetRenderImage(Null)
		SetColor(255, 255, 255)
		For Local cached:Int = 0 To 1
			Local elapsed:Double
			Local submissions:Long, creations:Long, uploads:Long, readbacks:Long
			For Local frame:Int = -20 Until 60
				ResetMax2DStats()
				Local start:Double = max2d_bench_seconds()
				If Not cached Or frame = -20 Then blur.Apply(source, output, levels, scratch)
				SetClsColor(24, 29, 39)
				Cls
				DrawImage(output, 0, 0)
				Flip(0)
				Local duration:Double = max2d_bench_seconds()-start
				Local stats:TMax2DStats = CaptureMax2DStats()
				If frame >= 0 Then
					elapsed :+ duration
					submissions :+ stats.submissions
					creations :+ stats.textureCreations
					uploads :+ stats.textureUpdates
					readbacks :+ stats.readbacks
				End If
			Next
			Print SDLGPUMax2DDriverName()+","+size+","+count+","+radius+","+cached+",60,"+(elapsed*1000/60)+","+(Double(submissions)/60)+","+creations+","+uploads+","+readbacks+","+bytes
		Next
	Next
Next
EndGraphics
