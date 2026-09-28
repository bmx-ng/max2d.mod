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

AppTitle = "Max2D — tile draw orders"
Graphics 1000, 700
SetVirtualResolution(1000, 700, VIRTUAL_LETTERBOX)

Local fontPath:String
?osx
fontPath = "/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath = getenv_("WINDIR") + "/Fonts/segoeui.ttf"
?linux
fontPath = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
If FileType(fontPath) = FILETYPE_FILE Then SetImageFont(LoadScalableImageFont(fontPath, 20))

Local tiles:TTileSet = New TTileSet
For Local color:Int = EachIn [$ffe46666, $ff60cd90, $ff659bdf, $fff0c96a]
	Local pixels:TPixmap = CreatePixmap(80, 80, PF_RGBA8888)
	pixels.ClearPixels(color)
	For Local y:Int = 2 Until 78
		For Local x:Int = 2 Until 78
			If x < 5 Or y < 5 Or x >= 75 Or y >= 75 Then pixels.WritePixel(x, y, $ff202833)
		Next
	Next
	tiles.Add(TImage.FromPixmap(pixels), 0, 0, -24)
Next

Local orders:ETileRenderOrder[] = [ETileRenderOrder.RightDown, ETileRenderOrder.RightUp, ETileRenderOrder.LeftDown, ETileRenderOrder.LeftUp]
Local names:String[] = ["Right-down: yellow in front", "Right-up: green in front", "Left-down: blue in front", "Left-up: red in front"]
Local maps:TTileMap[] = New TTileMap[4]
For Local i:Int = 0 Until maps.Length
	maps[i] = TTileMap.Create(TTileGrid.Rectangular(56, 56), tiles)
	Local layer:TTileLayer = maps[i].AddLayer()
	layer.renderOrder = orders[i]
	layer.SetCell(0, 0, 1)
	layer.SetCell(1, 0, 2)
	layer.SetCell(0, 1, 3)
	layer.SetCell(1, 1, 4)
Next

Local groundDepth:Int, frames:Int, test:Int, screenshot:String
For Local arg:String = EachIn AppArgs[1..]
	If arg = "--test" Then test = True
	If arg.StartsWith("--screenshot=") Then screenshot = arg[13..]
Next
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_SPACE) Then groundDepth = Not groundDepth
	SetClsColor(18, 24, 32)
	Cls()
	SetColor(235, 240, 245)
	DrawText("Four draw orders for overlapping rectangular tiles", 24, 20)
	DrawText("Space: toggle ground-depth sorting    Escape: exit", 24, 52)
	Local mode:String = "Grid order — compare the centre overlap in each panel"
	If groundDepth Then mode = "Ground-depth sorting — all panels now put yellow in front"
	DrawText(mode, 24, 84)
	For Local i:Int = 0 Until maps.Length
		Local x:Float = 36 + (i Mod 2) * 480
		Local y:Float = 142 + (i / 2) * 270
		SetColor(28, 37, 49)
		DrawRect(x, y, 440, 240)
		SetColor(235, 240, 245)
		DrawText(names[i], x + 16, y + 12)
		maps[i].layers[0].sortMode = ETileSort.Grid
		If groundDepth Then maps[i].layers[0].sortMode = ETileSort.GroundDepth
		SetColor(255, 255, 255)
		maps[i].Draw(x + 150, y + 92)
	Next
	frames :+ 1
	If frames = 3 And screenshot Then SavePixmapPNG(GrabPixmap(0, 0, GraphicsWidth(), GraphicsHeight()), screenshot)
	Flip()
	If test And frames >= 3 Then Exit
Wend
EndGraphics()
