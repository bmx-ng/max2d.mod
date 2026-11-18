SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Effects
Import BRL.StandardIO
Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
Try
	For Local lifetime:Int = 0 Until 2
		Graphics(64, 64)
		Local layer:TRenderImage = CreateRenderImage(8, 8, 0)
		Local mask:TImage = CreateImage(8, 8, 1, DYNAMICIMAGE)
		Local p:TPixmap = LockImage(mask)
		For Local y:Int = 0 Until 8
			For Local x:Int = 0 Until 8
				p.WritePixel(x, y, (Int(x*255/7) Shl 24) | $40a0ff)
			Next
		Next
		UnlockImage(mask)
		SetRenderImage(layer)
		If Not Max2DSupportsLayerInverseAlpha() Then
			Local rejected:Int
			Try
				ApplyLayerInverseAlphaMask(mask)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected And TMax2DGraphics.Current().renderImage = layer, "unsupported blend rejects without changing target")
			EndGraphics
			Print "inverse alpha unsupported"
			Exit
		End If
		Local renderMask:TRenderImage = CreateRenderImage(8, 8, 0)
		SetRenderImage(renderMask)
		SetBlend(SOLIDBLEND)
		DrawImage(mask, 0, 0)
		Local maskBefore:TPixmap = ReadRenderImage(renderMask)
		For Local kind:Int = 0 Until 2
			Local input:TImage = mask
			If kind Then input = renderMask
			SetImageHandle(input, 3, 2)
			For Local compact:Int = 0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				SetRenderImage(layer)
				SetOrigin(0, 0)
				SetScale(1, 1)
				SetViewport(0, 0, 8, 8)
				SetColor(180, 100, 60)
				SetAlpha(1)
				SetBlend(SOLIDBLEND)
				For Local y:Int = 0 Until 8
					SetAlpha(Float(y)/7)
					DrawRect(0, y, 8, 1)
				Next
				SetOrigin(10, 20)
				SetScale(2, 3)
				SetViewport(1, 1, 2, 2)
				SetColor(15, 25, 35)
				SetAlpha(0.2)
				ApplyLayerInverseAlphaMask(input)
				Check(TMax2DGraphics.Current().renderImage = layer, "target restored")
				Local r:Int, g:Int, b:Int
				GetColor(r, g, b)
				Check(r = 15 And g = 25 And b = 35 And Abs(GetAlpha()-0.2) < 0.001, "drawing state restored")
				Local pixels:TPixmap = ReadRenderImage(layer)
				For Local y:Int = 0 Until 8
					For Local x:Int = 0 Until 8
						Local pixel:Int = pixels.ReadPixel(x, y)
						Local expected:Int = Int((Float(y)/7)*(255-Int(x*255/7)))
						Local alpha:Int = (pixel Shr 24) & 255
						Check(Abs(alpha-expected) <= 2, "inverse alpha product")
						If alpha > 32 Then
							Check(Abs(((pixel Shr 16) & 255)-180) <= 8, "straight red preserved")
							Check(Abs(((pixel Shr 8) & 255)-100) <= 8, "straight green preserved")
							Check(Abs((pixel & 255)-60) <= 8, "straight blue preserved")
						End If
					Next
				Next
				ResetMax2DStats()
				ApplyLayerInverseAlphaMask(input)
				Local stats:TMax2DStats = CaptureMax2DStats()
				Check(stats.submissions = 1 And stats.textureCreations = 0 And stats.textureUpdates = 0 And stats.readbacks = 0, "warmed inverse mask uses one draw without texture churn")
			Next
		Next
		Local maskAfter:TPixmap = ReadRenderImage(renderMask)
		For Local y:Int = 0 Until 8
			For Local x:Int = 0 Until 8
				Check(maskBefore.ReadPixel(x,y) = maskAfter.ReadPixel(x,y), "mask pixels preserved")
			Next
		Next
		Local rejected:Int
		Try
			ApplyLayerInverseAlphaMask(layer)
		Catch error:Object
			rejected = True
		End Try
		Check(rejected, "feedback rejected")
		EndGraphics
	Next
	Print "inverse_layer_masks passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
