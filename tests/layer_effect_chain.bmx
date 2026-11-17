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

Type TUnavailableEffect Extends TMax2DImageEffect
End Type

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function

Function CheckPixel(p:TPixmap, alpha:Int, gray:Int = -1)
	Local value:Int = p.ReadPixel(8, 8)
	Check(Abs(((value Shr 24) & 255) - alpha) <= 1, "chain alpha")
	If gray >= 0 Then
		Check(Abs(((value Shr 16) & 255) - gray) <= 3 And Abs(((value Shr 8) & 255) - gray) <= 3 And Abs((value & 255) - gray) <= 3, "chain colour")
	Else
		Check(((value Shr 16) & 255) >= 250 And (value & $ffff) = 0, "chain red colour")
	End If
End Function

Function CheckCaller(target:TRenderImage)
	Check(TMax2DGraphics.Current().renderImage = target, "caller target restored")
	Check(GetBlend() = LIGHTBLEND And Abs(GetAlpha() - 0.3) < 0.001, "caller blend and alpha restored")
	Local x:Int, y:Int, w:Int, h:Int
	GetViewport(x, y, w, h)
	Check(x = 2 And y = 3 And w = 4 And h = 5, "caller viewport restored")
	Local sx:Float, sy:Float
	GetScale(sx, sy)
	Check(sx = 2 And sy = 3, "caller transform restored")
	Local camera:TCamera2D = GetCamera()
	Check(camera And camera.x = 13 And camera.zoom = 2, "caller camera restored")
	Local red:Int, green:Int, blue:Int
	GetColor(red, green, blue)
	Check(red = 10 And green = 20 And blue = 30, "caller tint restored")
End Function

Try
	Check(Graphics(64, 64, 0, 0) <> Null, "graphics creation")
	If Not Max2DSupportsRenderImage(17, 17, FILTEREDIMAGE) Then
		Print "layer_effect_chain passed: render images unavailable"
		EndGraphics
		End
	End If
	Local source:TRenderImage = CreateRenderImage(17, 17, FILTEREDIMAGE)
	Local destination:TRenderImage = CreateRenderImage(17, 17, FILTEREDIMAGE)
	Local scratch:TRenderImage = CreateRenderImage(17, 17, FILTEREDIMAGE)
	SetRenderImage(source)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(255, 0, 0)
	DrawRect(8, 8, 1, 1)
	SetImageHandle(source, 5, 6)
	SetImageHandle(destination, 3, 4)
	SetImageHandle(scratch, 1, 2)
	SetRenderImage(destination)
	SetVirtualResolution(34, 34)
	SetViewport(3, 4, 5, 6)
	SetRenderImage(scratch)
	SetVirtualResolution(51, 51)
	SetViewport(4, 5, 6, 7)
	SetRenderImage(source)
	SetVirtualResolution(68, 68)
	SetViewport(2, 3, 4, 5)
	SetColor(10, 20, 30)
	SetAlpha(0.3)
	SetScale(2, 3)
	SetRotation(20)
	SetOrigin(7, 9)
	SetBlend(LIGHTBLEND)
	Local camera:TCamera2D = New TCamera2D
	camera.x = 13
	camera.zoom = 2
	SetCamera(camera)

	Local empty:TMax2DImageEffect[0]
	ApplyLayerEffects(source, destination, empty)
	CheckCaller(source)
	CheckPixel(ReadRenderImage(destination), 255)
	Local horizontal:TMax2DBlurEffect = CreateBlurEffect(4)
	Local vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)
	Local saturation:TMax2DSaturationEffect = CreateSaturationEffect(0)
?max2d_sdlgpu
	Check(Max2DSupportsImageEffect(horizontal), "native blur provider required")
	Print "layer_effect_chain driver=" + SDLGPUMax2DDriverName()
?
	If Max2DSupportsImageEffect(horizontal) Then
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			For Local count:Int = 1 To 3
				Local chain:TMax2DImageEffect[]
				Select count
					Case 1
						chain = [TMax2DImageEffect(saturation)]
					Case 2
						chain = [TMax2DImageEffect(horizontal), TMax2DImageEffect(vertical)]
					Case 3
						chain = [TMax2DImageEffect(horizontal), TMax2DImageEffect(vertical), TMax2DImageEffect(saturation)]
				End Select
				ApplyLayerEffects(source, destination, chain, scratch)
				ResetMax2DStats()
				ApplyLayerEffects(source, destination, chain, scratch)
				Local stats:TMax2DStats = CaptureMax2DStats()
				Check(stats.submissions = count And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "chain has one warmed submission per effect")
				CheckCaller(source)
				Local p:TPixmap = ReadRenderImage(destination)
				Select count
					Case 1
						CheckPixel(p, 255, 54)
					Case 2
						CheckPixel(p, 19)
					Case 3
						CheckPixel(p, 19, 54)
				End Select
			Next
		Next
	End If
	Local before:Int = ReadRenderImage(destination).ReadPixel(8, 8)
	Local scratchBefore:Int = ReadRenderImage(scratch).ReadPixel(8, 8)
	Local unsupported:TMax2DImageEffect[] = [TMax2DImageEffect(horizontal), TMax2DImageEffect(New TUnavailableEffect)]
	Local rejected:Int
	Try
		ApplyLayerEffects(source, destination, unsupported, scratch)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected, "unsupported chain rejected")
	CheckCaller(source)
	Check(ReadRenderImage(destination).ReadPixel(8, 8) = before And ReadRenderImage(scratch).ReadPixel(8, 8) = scratchBefore, "support preflight leaves outputs unchanged")
	rejected = False
	Try
		ApplyLayerEffects(source, destination, unsupported, source)
	Catch error:Object
		rejected = True
	End Try
	Check(rejected, "scratch alias rejected")
	CheckPixel(ReadRenderImage(source), 255)
	SetRenderImage(destination)
	Local x:Int, y:Int, w:Int, h:Int
	GetViewport(x, y, w, h)
	Check(x = 3 And y = 4 And w = 5 And h = 6 And TMax2DGraphics.Current().context.view.width = 34, "destination view preserved")
	SetRenderImage(scratch)
	GetViewport(x, y, w, h)
	Check(x = 4 And y = 5 And w = 6 And h = 7 And TMax2DGraphics.Current().context.view.width = 51, "scratch view preserved")
	Check(source.handle_x = 5 And destination.handle_x = 3 And scratch.handle_x = 1, "image handles preserved")
	SetRenderImage(Null)
	EndGraphics
	Print "layer_effect_chain passed"
Catch error:Object
	Print "FAILED: " + error.ToString()
	EndWithCode(1)
End Try
