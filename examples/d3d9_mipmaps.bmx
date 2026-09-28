SuperStrict
Framework Max2D.D3D9Max2D

Graphics 800, 480, 0
If Not Max2DSupportsImageFlags(FILTEREDIMAGE | MIPMAPPEDIMAGE) Then
	Throw "This D3D9 device does not support automatic mipmaps"
End If

Local pixels:TPixmap = CreatePixmap(512, 512, PF_RGBA8888)
For Local y:Int = 0 Until 512
	For Local x:Int = 0 Until 512
		If ((x / 8) + (y / 8)) & 1 Then
			pixels.WritePixel(x, y, $ffffffff)
		Else
			pixels.WritePixel(x, y, $ff204060)
		End If
	Next
Next
Local plain:TImage = TImage.FromPixmap(pixels, FILTEREDIMAGE)
Local mipmapped:TImage = TImage.FromPixmap(pixels, FILTEREDIMAGE | MIPMAPPEDIMAGE)

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	PollSystem()
	SetClsColor(24, 32, 48)
	Cls()
	Local size:Float = 64 + 48 * (1 + Sin(MilliSecs() * 0.04))
	DrawText("Filtered only", 80, 60)
	DrawText("Filtered with mipmaps", 440, 60)
	DrawImageRect(plain, 160 - size / 2, 230 - size / 2, size, size)
	DrawImageRect(mipmapped, 520 - size / 2, 230 - size / 2, size, size)
	DrawText("Watch the checkerboard as both copies shrink.", 80, 380)
	DrawText("Escape to exit", 80, 410)
	Flip(1)
Wend

EndGraphics()
