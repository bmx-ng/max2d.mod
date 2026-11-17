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

' Independent CPU alpha reference, including rounding at every 8-bit target.
Type TAlphaGrid
	Field w:Int, h:Int, values:Float[]
	Function Create:TAlphaGrid(w:Int, h:Int)
		Local grid:TAlphaGrid = New TAlphaGrid
		grid.w = w
		grid.h = h
		grid.values = New Float[w * h]
		Return grid
	End Function
	Method Sample:Float(x:Float, y:Float)
		x = Max(0.0, Min(Float(w - 1), x))
		y = Max(0.0, Min(Float(h - 1), y))
		Local ix:Int = Int(x), iy:Int = Int(y)
		Local jx:Int = Min(ix + 1, w - 1), jy:Int = Min(iy + 1, h - 1)
		Local fx:Float = x - ix, fy:Float = y - iy
		Return (values[iy*w+ix]*(1-fx)+values[iy*w+jx]*fx)*(1-fy) + (values[jy*w+ix]*(1-fx)+values[jy*w+jx]*fx)*fy
	End Method
	Method Resize:TAlphaGrid(nw:Int, nh:Int)
		Local result:TAlphaGrid = Create(nw, nh)
		For Local y:Int = 0 Until nh
			For Local x:Int = 0 Until nw
				result.values[y*nw+x] = Floor(Sample((x+0.5)*w/nw-0.5, (y+0.5)*h/nh-0.5)+0.5)
			Next
		Next
		Return result
	End Method
	Method Blur:TAlphaGrid(radius:Float, horizontal:Int)
		Local result:TAlphaGrid = Create(w, h)
		Local weights:Int[] = [1, 8, 28, 56, 70, 56, 28, 8, 1]
		For Local y:Int = 0 Until h
			For Local x:Int = 0 Until w
				Local value:Float
				For Local k:Int = 0 Until 9
					Local sx:Float = x, sy:Float = y
					If horizontal Then sx :+ (k-4)*radius/4 Else sy :+ (k-4)*radius/4
					If sx >= -0.5 And sx <= w-0.5 And sy >= -0.5 And sy <= h-0.5 Then value :+ Sample(sx, sy)*weights[k]/256.0
				Next
				result.values[y*w+x] = Floor(value+0.5)
			Next
		Next
		Return result
	End Method
End Type

Try
	Local blur:TMax2DScaledBlur = CreateScaledBlur()
	Local bad:Int
	Try
		blur.SetRadius(-1)
	Catch error:Object
		bad = True
	End Try
	Check(bad And blur.GetRadius() = 8, "radius validation")
	For Local lifetime:Int = 0 Until 2
		Check(Graphics(96, 96, 0, 0) <> Null, "graphics creation")
		Local supported:Int = Max2DSupportsImageEffect(CreateBlurEffect())
?max2d_sdlgpu
		Check(supported, "native blur required")
		Print "scaled_blur driver=" + SDLGPUMax2DDriverName()
?
		For Local odd:Int = 0 Until 2
			Local w:Int = 32 + odd, h:Int = 24 + odd
			Local reference:TAlphaGrid = TAlphaGrid.Create(w, h)
			Local image:TImage = CreateImage(w, h, 1, DYNAMICIMAGE)
			Local pixels:TPixmap = LockImage(image)
			pixels.ClearPixels($000000ff)
			For Local y:Int = 3 Until h-3
				For Local x:Int = 3 Until w-3
					Local a:Int = 255 * ((x+y) Mod 2)
					reference.values[y*w+x] = a
					pixels.WritePixel(x, y, (a Shl 24) | $ff0000)
				Next
			Next
			UnlockImage(image)
			Local source:TRenderImage = CreateRenderImage(UInt(w), UInt(h), FILTEREDIMAGE)
			Local destination:TRenderImage = CreateRenderImage(UInt(w), UInt(h), 0)
			SetRenderImage(source)
			SetBlend(SOLIDBLEND)
			DrawImage(image, 0, 0)
			SetImageHandle(source, 3, 5)
			For Local count:Int = 0 To 2
				Local levels:TRenderImage[] = New TRenderImage[count]
				Local rw:Int = w, rh:Int = h
				Local expected:TAlphaGrid = reference
				For Local i:Int = 0 Until count
					rw = (rw+1)/2
					rh = (rh+1)/2
					levels[i] = CreateRenderImage(UInt(rw), UInt(rh), FILTEREDIMAGE)
					SetImageHandle(levels[i], 2, 1)
					SetRenderImage(levels[i])
					SetVirtualResolution(rw*2, rh*2)
					SetViewport(1, 2, 3, 4)
					expected = expected.Resize(rw, rh)
				Next
				Local scratch:TRenderImage = CreateRenderImage(UInt(rw), UInt(rh), FILTEREDIMAGE)
				SetImageHandle(scratch, 4, 2)
				SetRenderImage(scratch)
				SetVirtualResolution(rw*3, rh*3)
				SetViewport(3, 2, 4, 5)
				SetRenderImage(destination)
				SetVirtualResolution(w*2, h*2)
				SetViewport(4, 3, 5, 6)
				Local radius:Float = 4
				If count = 1 Then radius = 7
				If count = 2 Then radius = 12
				blur.SetRadius(radius)
				expected = expected.Blur(radius*rw/w, True).Blur(radius*rh/h, False)
				If count Then expected = expected.Resize(w, h)
				For Local compact:Int = 0 Until 2
?max2d_sdlgpu
					SetSDLGPUMax2DCompactSprites(compact)
?
					SetRenderImage(source)
					SetViewport(2, 3, 4, 5)
					SetScale(2, 3)
					SetColor(20, 40, 60)
					SetAlpha(0.3)
					SetBlend(LIGHTBLEND)
					If supported Then
						blur.Apply(source, destination, levels, scratch)
						ResetMax2DStats()
						blur.Apply(source, destination, levels, scratch)
						Local stats:TMax2DStats = CaptureMax2DStats()
						Local passes:Int = 2
						If count Then passes = count+3
						Check(stats.submissions = passes And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "retained blur pass costs")
						pixels = ReadRenderImage(destination)
						For Local y:Int = 0 Until h
							For Local x:Int = 0 Until w
								Local pixel:Int = pixels.ReadPixel(x, y), a:Int = (pixel Shr 24) & 255
								Check(Abs(a-expected.values[y*w+x]) <= 2, "CPU alpha reference levels=" + count + " odd=" + odd + " at " + x + "," + y + " actual=" + a + " expected=" + expected.values[y*w+x])
								If a > 8 Then Check(((pixel Shr 16) & 255) >= 250 And (pixel & $ffff) = 0, "premultiplied red preserved")
							Next
						Next
					Else
						bad = False
						Try
							blur.Apply(source, destination, levels, scratch)
						Catch error:Object
							bad = True
						End Try
						Check(bad, "unsupported blur rejected")
					End If
					Check(TMax2DGraphics.Current().renderImage = source And GetBlend() = LIGHTBLEND And Abs(GetAlpha()-0.3) < 0.001, "caller restored")
					Local vx:Int, vy:Int, vw:Int, vh:Int
					GetViewport(vx, vy, vw, vh)
					Check(vx = 2 And vy = 3 And vw = 4 And vh = 5, "caller viewport restored")
				Next
				For Local level:TRenderImage = EachIn levels
					SetRenderImage(level)
					Local vx:Int, vy:Int, vw:Int, vh:Int
					GetViewport(vx, vy, vw, vh)
					Check(vx = 1 And vy = 2 And vw = 3 And vh = 4 And TMax2DGraphics.Current().context.view.width = level.width*2, "level view restored")
				Next
				SetRenderImage(scratch)
				Local vx:Int, vy:Int, vw:Int, vh:Int
				GetViewport(vx, vy, vw, vh)
				Check(vx = 3 And vy = 2 And vw = 4 And vh = 5 And TMax2DGraphics.Current().context.view.width = rw*3, "scratch view restored")
				SetRenderImage(destination)
				GetViewport(vx, vy, vw, vh)
				Check(vx = 4 And vy = 3 And vw = 5 And vh = 6 And TMax2DGraphics.Current().context.view.width = w*2, "destination view restored")
				If count = 0 And supported Then
					blur.SetRadius(0)
					blur.Apply(source, destination, levels, scratch)
					pixels = ReadRenderImage(destination)
					For Local y:Int = 0 Until h
						For Local x:Int = 0 Until w
							Check(((pixels.ReadPixel(x, y) Shr 24) & 255) = reference.values[y*w+x], "zero radius full-resolution identity")
						Next
					Next
				End If
				Local before:Int = ReadRenderImage(destination).ReadPixel(w/2, h/2)
				blur.SetRadius(1000)
				bad = False
				Try
					blur.Apply(source, destination, levels, scratch)
				Catch error:Object
					bad = True
				End Try
				Check(bad And ReadRenderImage(destination).ReadPixel(w/2, h/2) = before, "oversized radius rejected before writes")
				blur.SetRadius(0)
				bad = False
				Try
					blur.Apply(source, destination, levels, source)
				Catch error:Object
					bad = True
				End Try
				Check(bad And ReadRenderImage(destination).ReadPixel(w/2, h/2) = before, "scratch alias rejected before writes")
			Next
			pixels = ReadRenderImage(source)
			For Local y:Int = 0 Until h
				For Local x:Int = 0 Until w
					Check(((pixels.ReadPixel(x, y) Shr 24) & 255) = reference.values[y*w+x], "source preserved")
				Next
			Next
			SetRenderImage(Null)
			ResetCoordinates()
			SetScale(1, 1)
			SetColor(255, 255, 255)
			SetAlpha(1)
		Next
		EndGraphics
	Next
	Print "scaled_blur passed"
Catch error:Object
	Print "FAILED: " + error.ToString()
	EndWithCode(1)
End Try
