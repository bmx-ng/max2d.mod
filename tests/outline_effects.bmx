SuperStrict

?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
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

Function Expected:Int(alpha:Int[], w:Int, h:Int, x:Int, y:Int, radius:Int)
	Local maximum:Int = alpha[y*w+x]
	For Local dy:Int = -radius To radius
		For Local dx:Int = -radius To radius
			If dx*dx+dy*dy > radius*radius Then Continue
			Local sx:Int = x+dx, sy:Int = y+dy
			If sx >= 0 And sy >= 0 And sx < w And sy < h Then maximum = Max(maximum, alpha[sy*w+sx])
		Next
	Next
	Return maximum-alpha[y*w+x]
End Function

Function CheckMask(p:TPixmap, alpha:Int[], radius:Int, offset:Int = 0, r:Int = 255, g:Int = 255, b:Int = 255, opacity:Float = 1)
	For Local y:Int = 0 Until 15
		For Local x:Int = 0 Until 17
			Local pixel:Int = p.ReadPixel(x+offset, y)
			Local a:Int = Int(Expected(alpha, 17, 15, x, y, radius)*opacity+0.5)
			Check(Abs(((pixel Shr 24) & 255)-a) <= 1, "outline alpha radius="+radius+" at "+x+","+y)
			If a > 8 Then Check(Abs(((pixel Shr 16) & 255)-r) <= 3 And Abs(((pixel Shr 8) & 255)-g) <= 3 And Abs((pixel & 255)-b) <= 3, "outline colour")
		Next
	Next
End Function

Try
	Local outline:TMax2DOutlineEffect = CreateOutlineEffect(2)
	Local rejected:Int
	Try
		outline.SetRadius(5)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected And outline.GetRadius() = 2, "validated radius")
	For Local lifetime:Int = 0 Until 2
		Check(Graphics(80, 60, 0, 0) <> Null, "graphics creation")
		If Not Max2DSupportsImageEffect(outline) Then
?max2d_sdlgpu
			Throw "outline unavailable: "+SDL_GetError()
?Not max2d_sdlgpu
			EndGraphics
			Print "outline_effects passed: unsupported provider reported"
			End
?
		End If
?max2d_sdlgpu
		Print "outline_effects driver="+SDLGPUMax2DDriverName()
?
		Local alpha:Int[255]
		For Local y:Int = 4 To 10
			For Local x:Int = 4 To 12
				alpha[y*17+x] = 128
			Next
		Next
		alpha[7*17+8] = 0 ' An enclosed hole also gets an outline.
		alpha[5*17+5] = 255
		alpha[0] = 255 ' Image edge must not wrap to the opposite side.
		alpha[14*17+16] = 64
		Local image:TImage = CreateImage(17, 15, 1, DYNAMICIMAGE)
		Local pixels:TPixmap = LockImage(image)
		For Local y:Int = 0 Until 15
			For Local x:Int = 0 Until 17
				pixels.WritePixel(x, y, (alpha[y*17+x] Shl 24) | ((x*811+y*719) & $ffffff))
			Next
		Next
		UnlockImage(image)
		Local source:TRenderImage = CreateRenderImage(17, 15, FILTEREDIMAGE)
		Local result:TRenderImage = CreateRenderImage(40, 15, 0)
		Local coloured:TRenderImage = CreateRenderImage(17, 15, 0)
		Local scratch:TRenderImage = CreateRenderImage(17, 15, 0)
		SetRenderImage(source)
		SetBlend(SOLIDBLEND)
		DrawImage(image, 0, 0)
		SetImageHandle(source, 2, 3)
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			SetRenderImage(result)
			SetBlend(SOLIDBLEND)
			SetColor(255, 255, 255)
			SetAlpha(1)
			For Local radius:Int = 0 To 4
				outline.SetRadius(radius)
				DrawImageEffect(source, outline, 2, 3)
				CheckMask(ReadRenderImage(result), alpha, radius)
			Next
			outline.SetRadius(1)
			DrawImageEffect(source, outline, 2, 3)
			outline.SetRadius(4)
			DrawImageEffect(source, outline, 22, 3)
			pixels = ReadRenderImage(result)
			CheckMask(pixels, alpha, 1)
			CheckMask(pixels, alpha, 4, 20)
			Local positions:Float[] = [2.0, 3.0, 22.0, 3.0]
			ResetMax2DStats()
			DrawImageEffectBatch(source, outline, positions)
			Local stats:TMax2DStats = CaptureMax2DStats()
			Check(stats.submissions = 1 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "batched outlines reuse existing storage")
			pixels = ReadRenderImage(result)
			CheckMask(pixels, alpha, 4)
			CheckMask(pixels, alpha, 4, 20)
			SetClsColor(0, 0, 0, 0)
			Cls
			Local blend:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA)
			SetBlend(blend)
			SetColor(40, 160, 240)
			SetAlpha(0.5)
			DrawImageEffect(source, outline, 2, 3)
			CheckMask(ReadRenderImage(result), alpha, 4, 0, 40, 160, 240, 0.5)
			Check(GetBlend() = blend And GetAlpha() = 0.5, "drawing state retained")
			SetColor(255, 255, 255)
			SetAlpha(1)
			SetBlend(SOLIDBLEND)
			DrawImage(source, 22, 3)
			pixels = ReadRenderImage(result)
			For Local y:Int = 0 Until 15
				For Local x:Int = 0 Until 17
					Check(((pixels.ReadPixel(x+20, y) Shr 24) & 255) = alpha[y*17+x], "ordinary draw after outline")
				Next
			Next
			Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(outline), TMax2DImageEffect(CreateColorizeEffect(40, 160, 240))]
			ApplyLayerEffects(source, coloured, chain, scratch)
			CheckMask(ReadRenderImage(coloured), alpha, 4, 0, 40, 160, 240)
			rejected = False
			Try
				DrawImageEffect(image, outline, 0, 0)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected, "ordinary image outline rejected")
			rejected = False
			Try
				DrawImageEffect(result, outline, 0, 0)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected, "feedback rejected")
		Next
		SetRenderImage(Null)
		EndGraphics
	Next
	Print "outline_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
