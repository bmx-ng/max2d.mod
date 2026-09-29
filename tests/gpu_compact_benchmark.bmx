SuperStrict
Framework Max2D.SDL3GPUMax2D
Import BRL.StandardIO

Extern "C"
	Function SDL_GetTicksNS:ULong()
End Extern

Graphics 640,480
Local target:TRenderImage=CreateRenderImage(512,512,0)
Local pixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
pixels.ClearPixels($c0ffffff)
Local sprite:TImage=LoadImage(pixels,0)
SetRenderImage(target)
SetVirtualResolution(512,512)
SetColor(160,220,255)
SetBlend(ALPHABLEND)
SetClsColor(0,0,0)
Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
Print "driver,count,trial,compact,submit_ms,completed_ms,batches,vertices"
For Local count:Int=EachIn [1000,10000,40000]
	Local xs:Float[count]
	Local ys:Float[count]
	For Local i:Int=0 Until count
		xs[i]=(i*37) Mod 500
		ys[i]=(i*71) Mod 500
	Next
	For Local trial:Int=0 Until 4
		For Local order:Int=0 Until 2
			Local compact:Int=(trial+order) Mod 2
			SetSDLGPUMax2DCompactSprites(compact)
			Local submitted:ULong
			Local started:ULong
			Local frames:Int=60
			For Local frame:Int=-5 Until frames
				If frame=0
					canvas.context.Read(canvas.context.target,0,0,1,1)
					ResetMax2DStats()
					started=SDL_GetTicksNS()
				End If
				Local before:ULong=SDL_GetTicksNS()
				Cls
				Local movement:Float=(frame Mod 8)*0.125
				For Local i:Int=0 Until count
					DrawImage(sprite,xs[i]+movement,ys[i])
				Next
				FlushMax2D()
				If frame>=0 Then submitted:+SDL_GetTicksNS()-before
				' Readback drains recorded GPU work; its cost is included equally in both modes.
				If frame<0 Or (frame+1) Mod 3=0 Then canvas.context.Read(canvas.context.target,0,0,1,1)
			Next
			Local elapsed:ULong=SDL_GetTicksNS()-started
			Local stats:TMax2DStats=CaptureMax2DStats()
			Print SDLGPUMax2DDriverName()+","+count+","+trial+","+compact+","+Double(submitted)/1000000/frames+","+Double(elapsed)/1000000/frames+","+stats.submissions/frames+","+stats.vertices/frames
		Next
	Next
Next
SetRenderImage(Null)
EndGraphics
