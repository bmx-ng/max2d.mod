' Artwork is built once. The colour and normal maps share the same silhouette.
Function Channel:Int(value:Float)
	Return Int(Max(0:Float, Min(255:Float, value)))
End Function

Function RockImage:TImage(normal:Int = False, background:Int = False, entrance:Int = False)
	Local pix:TPixmap = CreatePixmap(192, 192, PF_RGBA8888)
	For Local y:Int = 0 Until 192
		For Local x:Int = 0 Until 192
			Local nx:Float = (x - 95.5) / 96, ny:Float = (y - 95.5) / 96
			Local d:Float = Sqr(nx * nx + ny * ny), a:Float = ATan2(ny, nx)
			Local edge:Float = 0.91 + 0.035 * Sin(a * 5) + 0.025 * Cos(a * 9)
			Local alpha:Int = Channel((edge - d) * 17000)
			If background Then
				alpha = 255
			End If

			If entrance Then
				Local fade:Float = y / 191.0
				alpha = Channel(255 * fade * fade * (3 - 2 * fade))
			End If

			Local grain:Float = Sin(x * 27 + y * 13) * Sin(y * 31 - x * 8)
			Local ridge:Float = Sin(x * 3 + y * 5 + Sin(y * 4) * 18)
			If background Then
				ridge = Sin(x * 360.0 / 192 * 2 + y * 360.0 / 192) + 0.4 * Cos(x * 360.0 / 192 - y * 360.0 / 192 * 3)
				d = 0.6
				nx = 0.2 * Cos(x * 360.0 / 192 * 2 + y * 360.0 / 192)
				ny = 0.2 * Sin(y * 360.0 / 192 * 3 - x * 360.0 / 192)
				grain = 0
			End If

			Local r:Int, g:Int, b:Int
			If normal Then
				If Not background Then nx = nx * 0.65 + 0.18 * ridge;ny = ny * 0.65 + 0.16 * Cos(x * 3 + y * 5)

				Local z:Float = Sqr(Max(0.05:Float, 1 - nx * nx - ny * ny))
				r = Channel(127.5 + nx * 127.5)
				g = Channel(127.5 + ny * 127.5)
				b = Channel(127.5 + z * 127.5)
			Else
				Local v:Float = 54 + ridge * 13 + grain * 6 + (1 - d) * 30
				r = Channel(v * 0.65)
				g = Channel(v * 0.95)
				b = Channel(v * 1.05)
			End If

			pix.WritePixel(x, y, (alpha Shl 24) | (r Shl 16) | (g Shl 8) | b)
		Next
	Next

	Local image:TImage = LoadImage(pix, FILTEREDIMAGE)
	If Not background Then
		SetImageHandle(image, 96, 96)
	End If

	Return image
End Function

Function BeamImage:TImage()
	Local pix:TPixmap = CreatePixmap(256, 128, PF_RGBA8888)
	For Local y:Int = 0 Until 128
		For Local x:Int = 0 Until 256
			Local u:Float = x / 255.0, v:Float = Abs(y - 63.5) / 64
			Local width:Float = 0.04 + u * 0.92
			Local alpha:Float = Max(0:Float, 1 - v / width)
			alpha = alpha * alpha * (1 - u) * Min(1:Float, u * 25)
			pix.WritePixel(x, y, (Channel(alpha * 255) Shl 24) | $bdefff)
		Next
	Next

	Local image:TImage = LoadImage(pix, FILTEREDIMAGE)
	SetImageHandle(image, 0, 64)
	Return image
End Function

Function HullImage:TImage()
	Local target:TRenderImage = CreateRenderImage(120, 64, FILTEREDIMAGE)
	Using
		Local scope:TMax2DStateScope = ScopedMax2DState()
	Do
		SetRenderImage(target)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetBlend(ALPHABLEND)
		SetColor(27, 62, 71)
		DrawRect(9, 24, 25, 16)
		DrawOval(12, 17, 10, 30)
		SetColor(137, 100, 47)
		DrawRect(41, 10, 28, 19)
		DrawRect(59, 5, 6, 13)
		SetColor(232, 173, 70)
		DrawOval(25, 17, 83, 34)
		SetColor(255, 210, 110)
		DrawOval(32, 19, 68, 14)
		SetColor(111, 80, 38)
		DrawRect(42, 43, 40, 6)
		SetColor(26, 53, 62)
		DrawOval(70, 21, 27, 26)
		SetColor(94, 222, 239)
		DrawOval(74, 25, 19, 18)
		SetColor(200, 255, 250)
		DrawOval(77, 26, 6, 7)
		SetColor(190, 232, 232)
		DrawRect(101, 28, 10, 9)
		SetColor(53, 67, 62)
		DrawRect(40, 48, 40, 4)
		For Local i:Int = 0 Until 4
			DrawOval(40 + i * 7, 29, 3, 3)
		Next
	End Using

	Local image:TImage = LoadImage(ReadRenderImage(target), FILTEREDIMAGE)
	target.ReleaseFrames()
	SetImageHandle(image, 60, 32)
	Return image
End Function

Function WaterHazeImage:TImage()
	Local pix:TPixmap = CreatePixmap(128, 80, PF_RGBA8888)
	For Local y:Int = 0 Until 80
		For Local x:Int = 0 Until 128
			Local dx:Float = (x - 63.5) / 64, dy:Float = (y - 39.5) / 40
			Local edge:Float = Min(1:Float, (dx * dx + dy * dy) * 0.7)
			Local alpha:Int = Channel(20 + edge * 76)
			pix.WritePixel(x, y, (alpha Shl 24) | $061c20)
		Next
	Next

	Return LoadImage(pix, FILTEREDIMAGE)
End Function

' Soft shafts from uneven surface openings. Their axes stay coherent with depth;
' surface motion slowly modulates width, direction and intensity. Built once.
Function SurfaceLightImage:TImage(frame:Int)
	Local pix:TPixmap = CreatePixmap(384, 256, PF_RGBA8888), phase:Float = frame * 15
	Local centres:Float[9], widths:Float[9], strengths:Float[9]
	For Local y:Int = 0 Until 256
		Local depth:Float = y / 255.0
		For Local ray:Int = 0 Until 9
			Local origin:Float = (ray + 0.3 + 0.24 * Sin(ray * 137)) / 9
			Local sway:Float = Sin(phase + ray * 73) * 0.004
			centres[ray] = origin + sway + depth * (0.075 + Sin(ray * 59) * 0.035 + Sin(phase + ray * 43) * 0.008)
			widths[ray] = (0.0035 + 0.002 * (0.5 + 0.5 * Sin(ray * 97 + phase))) * (1 + depth * 7)
			Local reach:Float = 0.62 + 0.38 * (0.5 + 0.5 * Sin(ray * 113))
			Local fade:Float = Max(0:Float, 1 - depth / reach)
			strengths[ray] = fade * fade * (0.12 + 0.16 * (0.5 + 0.5 * Sin(phase + ray * 81)))
		Next

		For Local x:Int = 0 Until 384
			Local u:Float = x / 384.0, alpha:Float
			For Local ray:Int = 0 Until 9
				Local distance:Float = u - centres[ray]
				distance :- Floor(distance + 0.5)
				Local d:Float = distance / widths[ray]
				' A bright soft core inside a wider, faint scattering halo.
				alpha :+ strengths[ray] * Float(0.72 * Exp(-d * d * 0.5) + 0.28 * Exp(-d * d * 0.065))
			Next

			alpha :* Min(1:Float, depth * 90)
			pix.WritePixel(x, y, (Channel(alpha * 255) Shl 24) | $d5ede5)
		Next
	Next

	Return LoadImage(pix, FILTEREDIMAGE)
End Function
