SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.TileMap
Import Max2D.ScalableFont
Import BRL.FileSystem
Import BRL.PNGLoader
Import Pub.StdC

AppTitle = "Max2D — tile sizing and text objects"
Graphics 1040, 720
SetVirtualResolution(1040, 720, VIRTUAL_LETTERBOX)
Local fontPath:String
?osx
fontPath = "/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath = getenv_("WINDIR") + "/Fonts/segoeui.ttf"
?linux
fontPath = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TImageFont
If FileType(fontPath) = FILETYPE_FILE Then font = LoadScalableImageFont(fontPath, 22)
If font Then SetImageFont(font)

' One wide sprite, shown with three different display canvases.
Local pixels:TPixmap = CreatePixmap(96, 48, PF_RGBA8888)
pixels.ClearPixels($ff4fc9b4)
For Local y:Int = 0 Until 48
	For Local x:Int = 0 Until 96
		If x < 3 Or y < 3 Or x > 92 Or y > 44 Then pixels.WritePixel(x, y, $ff153c49)
		If x >= 60 And x < 84 And y >= 12 And y < 36 Then pixels.WritePixel(x, y, $ffffd16b)
	Next
Next
Local image:TImage = TImage.FromPixmap(pixels)
Local tiles:TTileSet = New TTileSet
For Local i:Int = 0 Until 3
	tiles.Add(image)
Next
' Bottom-align natural artwork, as Tiled does. A diagonal flip keeps this anchor.
tiles.tiles[1].offsetY = 120 - image.height
tiles.SetSize(2, 120, 120)
tiles.SetSize(3, 120, 120, ETileFillMode.PreserveAspectFit)
Local map:TTileMap = TTileMap.Create(TTileGrid.Rectangular(300, 120), tiles)
Local layer:TTileLayer = map.AddLayer()
For Local i:Int = 0 Until 3
	layer.SetCell(i, 0, i + 1)
Next

' These are native objects; the Tiled importer creates the same data.
Local labels:TTileMap = TTileMap.Create(TTileGrid.Rectangular(32, 32), New TTileSet)
Local textLayer:TTileLayer = labels.AddLayer()
Local left:TTileObject = TextBox(textLayer, 40, 368, 285, 155, font)
left.text.text = "Text objects wrap within their rectangle. Layout is retained between frames, including while the camera moves."
left.text.wrap = True
Local middle:TTileObject = TextBox(textLayer, 378, 368, 285, 155, font)
middle.text.text = "Centred text~nwith colour,~nunderline and alignment."
middle.text.alignment = TEXT_ALIGN_CENTER
middle.text.verticalAlignment = TEXT_ALIGN_MIDDLE
middle.text.underline = True
middle.text.red = 255; middle.text.green = 209; middle.text.blue = 107
Local right:TTileObject = TextBox(textLayer, 740, 392, 220, 115, font)
right.SetRotation(12)
right.text.text = "A long line clips at the box edges.~nClipping rotates with the object."
right.text.red = 113; right.text.green = 204; right.text.blue = 255

Local frames:Int, test:Int, screenshot:String, flipped:Int
For Local arg:String = EachIn AppArgs[1..]
	If arg = "--test" Then test = True
	If arg.StartsWith("--screenshot=") Then screenshot = arg[13..]
Next
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_SPACE) Then flipped = Not flipped
	SetClsColor(18, 24, 32)
	Cls()
	SetColor(235, 240, 245)
	DrawText("Tile sizing and retained text objects", 32, 24)
	DrawText("Space: diagonal tile flip    Escape: exit", 32, 60)
	Local titles:String[] = ["Natural size: 96 x 48", "Stretch: 120 x 120", "Aspect fit: 120 x 120"]
	For Local i:Int = 0 Until 3
		SetColor(235, 240, 245)
		DrawText(titles[i], 40 + i * 300, 112)
		SetColor(37, 49, 63)
		DrawRect(40 + i * 300, 158, 120, 120)
		Local flip:ETileFlip = ETileFlip.None
		If flipped Then flip = ETileFlip.Diagonal
		layer.SetCell(i, 0, i + 1, flip)
	Next
	SetColor(255, 255, 255)
	map.Draw(40, 158)
	SetColor(235, 240, 245)
	DrawText("Wrapped", 40, 326)
	DrawText("Centred + underlined", 378, 326)
	DrawText("Rotated + clipped", 740, 326)
	For Local obj:TTileObject = EachIn textLayer.objects
		PushMax2DState()
		TransformCoordinates(Float(obj.xx), Float(obj.xy), Float(obj.yx), Float(obj.yy), Float(obj.x), Float(obj.y))
		SetColor(37, 49, 63)
		DrawRect(0, 0, Float(obj.width), Float(obj.height))
		PopMax2DState()
	Next
	SetColor(255, 255, 255)
	labels.Draw()
	SetColor(175, 190, 207)
	DrawText("Text and tiles share layer tint, camera transforms and render targets.", 40, 600)
	DrawText("Layout builds: " + left.text.layoutBuilds + " / " + middle.text.layoutBuilds + " / " + right.text.layoutBuilds, 40, 636)
	frames :+ 1
	If frames = 3 And screenshot Then SavePixmapPNG(GrabPixmap(0, 0, NativeResolutionWidth(), NativeResolutionHeight()), screenshot)
	Flip()
	If test And frames >= 3 Then Exit
Wend
EndGraphics()

Function TextBox:TTileObject(layer:TTileLayer, x:Double, y:Double, width:Double, height:Double, font:TImageFont)
	Local obj:TTileObject = New TTileObject
	obj.x = x; obj.y = y; obj.width = width; obj.height = height
	obj.text = New TTileText
	obj.text.font = font; obj.text.pixelSize = 22
	obj.text.red = 235; obj.text.green = 240; obj.text.blue = 245
	layer.AddObject(obj)
	Return obj
End Function
