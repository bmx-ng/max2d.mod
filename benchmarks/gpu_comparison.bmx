SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import "comparison_timing.c"

Extern "C"
	Function max2d_bench_seconds:Double()
	Function max2d_bench_visibility:Int(window:Byte Ptr)
End Extern

' Arguments: workload (snow/atlas/switches), vsync (0/1), frames, SDL renderer.
Try
	Local workload:String = AppArgs[1]
	Local sync:Int = Int(AppArgs[2])
	Local frames:Int = Int(AppArgs[3])
	If frames<100 Then Throw "Use at least 100 frames"
?Not max2d_sdlgpu
	If Not SetSDLRenderMax2DRenderer(AppArgs[4]) Then Throw "Renderer unavailable"
?
	If Not Graphics(800,600,0,0) Then Throw "Cannot create graphics"
	SetVirtualResolution(800,600)
?max2d_sdlgpu
	Print "# backend=native driver="+SDLGPUMax2DDriverName()
?Not max2d_sdlgpu
	Print "# backend=renderer driver="+SDLRenderMax2DRendererName()
?
	Print "# workload="+workload+" vsync="+sync+" pixels="+NativeResolutionWidth()+"x"+NativeResolutionHeight()
	Local count:Int = 1000
	If workload="atlas" Then count=10000
	If workload="switches" Then count=4096
	If workload<>"snow" And workload<>"atlas" And workload<>"switches" Then Throw "Unknown workload"
	Local pixmap:TPixmap = CreatePixmap(32,32,PF_RGBA8888)
	For Local y:Int = 0 Until 32
		For Local x:Int = 0 Until 32
			Local alpha:Int = Int(255*Max(0.0,1.0-Sqr((x-15.5)^2+(y-15.5)^2)/16))
			pixmap.WritePixel(x,y,(alpha Shl 24)|$ffffff)
		Next
	Next
	Local atlas:TTextureAtlas = TTextureAtlas.Create(512,FILTEREDIMAGE)
	Local images:TImage[64]
	For Local i:Int = 0 Until 64
		If workload="switches" Then
			images[i]=LoadImage(pixmap,FILTEREDIMAGE)
		Else
			images[i]=atlas.AddPixmap(pixmap,String(i))
		End If
	Next
	Local window:Byte Ptr = TSDLGraphics(TMax2DGraphics.Current().context.graphics)._context.window.windowPtr
	Local visibility:Int[frames]
	Local rows:Double[frames,3]
	Local submissions:Long[frames]
	Local vertices:Long[frames]
	Local stats:TMax2DStats = Max2DStats()
	For Local frame:Int = 0 Until frames+120
		If frame=120 Then GCCollect()
		Local start:Double = max2d_bench_seconds()
		PollSystem()
		If AppTerminate() Or KeyDown(KEY_ESCAPE) Then Throw "Benchmark interrupted"
		Local flags:Int = max2d_bench_visibility(window)
		ResetMax2DStats()
		Cls()
		SetBlend(ALPHABLEND)
		If workload="snow" Then SetBlend(LIGHTBLEND)
		For Local i:Int = 0 Until count
			Local x:Float = (i*137) Mod 768
			Local y:Float = (i*71+frame*2) Mod 568
			If workload="snow" Then
				x:+Sin(frame*5+i Mod 45)*2
				Local size:Float = 0.15+Float(i Mod 10)*0.075
				SetScale(size,size)
			End If
			DrawImage(images[i Mod 64],x,y)
		Next
		SetScale(1,1)
		FlushMax2D()
		Local drawn:Double = max2d_bench_seconds()
		Flip(sync)
		Local finished:Double = max2d_bench_seconds()
		If frame>=120 Then
			Local index:Int = frame-120
			visibility[index]=flags
			rows[index,0]=(finished-start)*1000
			rows[index,1]=(drawn-start)*1000
			rows[index,2]=(finished-drawn)*1000
			submissions[index]=stats.submissions
			vertices[index]=stats.vertices
		End If
	Next
	EndGraphics()
	Print "frame,total_ms,draw_flush_ms,flip_ms,submissions,vertices,visibility_flags"
	For Local i:Int = 0 Until frames
		Print i+","+rows[i,0]+","+rows[i,1]+","+rows[i,2]+","+submissions[i]+","+vertices[i]+","+visibility[i]
	Next
	Print "# benchmark complete"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
