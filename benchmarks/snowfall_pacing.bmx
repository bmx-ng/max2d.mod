 ' Included only by the snowfall sample's sample_pacing build.
?max2d_gl
Import "gl_timing.c"
?Not max2d_gl
Import "timing.c"
?
Import BRL.TextStream
Extern "C"
	Function max2d_bench_seconds:Double()
End Extern
Global pacingFrame:Int
Global pacingDone:Int
Global pacingStartTime:Double, pacingFlipTime:Double
Global pacingRows:Double[240,3]
Function PacingStart()
	pacingStartTime=max2d_bench_seconds()
End Function
Function PacingBeforeFlip()
	pacingFlipTime=max2d_bench_seconds()
End Function
Function PacingEnd:Int()
	Local now:Double=max2d_bench_seconds()
	If pacingFrame>=72 Then
		Local row:Int=pacingFrame-72
		pacingRows[row,0]=(now-pacingStartTime)*1000
		pacingRows[row,1]=(pacingFlipTime-pacingStartTime)*1000
		pacingRows[row,2]=(now-pacingFlipTime)*1000
	End If
	pacingFrame:+1
	If pacingFrame<312 Then Return False
	Local output:TStream=WriteFile(AppDir+"/snowfall-pacing.csv")
	If Not output Then Throw "Cannot write pacing results"
	WriteLine(output,"frame,total_ms,update_draw_ms,flip_clear_ms")
	For Local i:Int=0 Until 240
		WriteLine(output,i+","+pacingRows[i,0]+","+pacingRows[i,1]+","+pacingRows[i,2])
	Next
	CloseStream(output)
	Print "Pacing recorded: "+AppDir+"/snowfall-pacing.csv"
	pacingDone=True
	Return True
End Function
