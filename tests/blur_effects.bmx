SuperStrict

?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?

Import Max2D.Effects
Import BRL.StandardIO

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function

Function CheckPixel(p:TPixmap, x:Int, y:Int, alpha:Int, message:String)
	Local value:Int = p.ReadPixel(x, y)
	Check(Abs(((value Shr 24) & 255) - alpha) <= 1, message + " alpha")
	If alpha > 1 Then
		Check(((value Shr 16) & 255) >= 250 And ((value Shr 8) & 255) <= 2 And (value & 255) <= 2, message + " preserves red without transparent-blue fringe")
	End If
End Function

Try
	Local horizontal:TMax2DBlurEffect = CreateBlurEffect(4)
	Local vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)
	Local rejected:Int
	Try
		horizontal.SetRadius(5)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And horizontal.GetRadius() = 4 And horizontal.IsHorizontal() And Not vertical.IsHorizontal(), "validated blur parameters")
	For Local lifetime:Int = 0 Until 2
		Check(Graphics(64, 64, 0, 0) <> Null, "graphics creation failed")
		If Not Max2DSupportsImageEffect(horizontal) Then
?max2d_sdlgpu
			Throw "blur unavailable: " + SDL_GetError()
?max2d_gl
			Throw "OpenGL blur unavailable"
?Not max2d_sdlgpu And Not max2d_gl
			Print "blur_effects passed: unsupported provider reported"
			EndGraphics
			End
?
		End If
?max2d_sdlgpu
		Print "blur_effects driver=" + SDLGPUMax2DDriverName()
?
		Local image:TImage = CreateImage(17, 17, 1, DYNAMICIMAGE)
		Local p:TPixmap = LockImage(image)
		p.ClearPixels($000000ff)
		p.WritePixel(8, 8, $ffff0000)
		UnlockImage(image)
		Local source:TRenderImage = CreateRenderImage(17, 17, FILTEREDIMAGE)
		SetRenderImage(source)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetBlend(ALPHABLEND)
		DrawImage(image, 0, 0)
		rejected = False
		Try
			DrawImageEffect(image, horizontal, 0, 0)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "straight-image blur requires explicit premultiplied layer")
		Local scratch:TRenderImage = CreateRenderImage(17, 17, 0)
		Local result:TRenderImage = CreateRenderImage(17, 17, 0)
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			SetBlend(SOLIDBLEND)
			SetRenderImage(scratch)
			horizontal.SetRadius(0)
			DrawImageEffect(source, horizontal, 0, 0)
			p = ReadRenderImage(scratch)
			CheckPixel(p, 8, 8, 255, "zero radius")
			CheckPixel(p, 7, 8, 0, "zero radius neighbor")
			horizontal.SetRadius(2)
			DrawImageEffect(source, horizontal, 0, 0)
			p = ReadRenderImage(scratch)
			CheckPixel(p, 8, 8, 126, "fractional sample spacing")
			horizontal.SetRadius(4)
			DrawImageEffect(source, horizontal, 0, 0)
			p = ReadRenderImage(scratch)
			CheckPixel(p, 8, 8, 70, "horizontal center")
			CheckPixel(p, 7, 8, 56, "horizontal neighbor")
			CheckPixel(p, 8, 7, 0, "horizontal axis")
			SetRenderImage(result)
			DrawImageEffect(scratch, vertical, 0, 0)
			p = ReadRenderImage(result)
			CheckPixel(p, 8, 8, 19, "two-pass center")
			CheckPixel(p, 7, 8, 15, "two-pass horizontal neighbor")
			CheckPixel(p, 8, 7, 15, "two-pass vertical neighbor")
			CheckPixel(p, 0, 0, 0, "transparent padding")
			ResetMax2DStats()
			SetRenderImage(scratch)
			DrawImageEffect(source, horizontal, 0, 0)
			SetRenderImage(result)
			DrawImageEffect(scratch, vertical, 0, 0)
			Local stats:TMax2DStats = CaptureMax2DStats()
			Check(stats.submissions = 2 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "warmed blur uses two submissions and retained images")
			Check(GetBlend() = SOLIDBLEND, "blur retains blend state")
		Next
		SetRenderImage(source); SetClsColor(255,0,0,1); Cls
		SetRenderImage(result); DrawImageEffect(source,horizontal,0,0)
		p=ReadRenderImage(result)
		CheckPixel(p,0,8,163,"left edge fades to transparent")
		CheckPixel(p,16,8,163,"right edge fades to transparent")
		CheckPixel(p,8,8,255,"interior remains opaque")
		SetRenderImage(Null)
		EndGraphics
	Next
	Print "blur_effects passed"
Catch error:Object
	Print "FAILED: " + error.ToString()
	EndWithCode(1)
End Try
