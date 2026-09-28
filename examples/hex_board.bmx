SuperStrict

Framework Max2D.SDL3RenderMax2D
Import Max2D.TileMap
Import BRL.PNGLoader

AppTitle = "Max2D — a hex board built in code"
Graphics 960, 640
SetVirtualResolution(960, 640, VIRTUAL_LETTERBOX)

Local grid:TTileGrid = TTileGrid.Hexagonal(48, 56, ETileLayout.PointyHex, ETileStagger.Odd)
Local tiles:TTileSet = New TTileSet
Local grass:Int = tiles.Add(HexImage(grid, $ff538357))
Local water:Int = tiles.Add(HexImage(grid, $ff3b6892))
tiles.Properties(grass).SetString("terrain", "grass")
tiles.Properties(grass).SetLong("moveCost", 1)
tiles.Properties(water).SetString("terrain", "water")
tiles.Properties(water).SetBool("blocked", True)

Local map:TTileMap = TTileMap.Create(grid, tiles)
Local ground:TTileLayer = map.AddLayer("Terrain")
For Local row:Int = 0 Until 10
	For Local column:Int = 0 Until 16
		Local tile:Int = grass
		If column = 9 Or (column = 10 And row Mod 3 = 0) Then tile = water
		ground.SetCell(column, row, tile)
	Next
Next

Const MAP_X:Float = 40
Const MAP_Y:Float = 112
Local selectedColumn:Int = 4, selectedRow:Int = 4
Local area:STileCell[] = grid.Range(selectedColumn, selectedRow, 3)
Local frames:Int, test:Int, screenshot:String
For Local arg:String = EachIn AppArgs[1..]
	If arg = "--test" Then test = True
	If arg.StartsWith("--screenshot=") Then screenshot = arg[13..]
Next

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	PollSystem()
	Local column:Int, row:Int
	Local hover:Int = map.MouseCell(column, row, MAP_X, MAP_Y, ground)
	If hover Then hover = ground.Cell(column, row) <> 0
	If hover And MouseHit(1) Then
		selectedColumn = column
		selectedRow = row
		area = grid.Range(column, row, 3)
	End If
	SetClsColor(20, 28, 38)
	Cls()
	SetColor(255, 255, 255)
	DrawText("A hex board built entirely in code", 40, 28)
	DrawText("Click a hex: select it and show range 3. Escape: exit.", 40, 52)
	DrawText("Yellow is geometric range: it includes water and ignores movement costs.", 40, 76)
	map.Draw(MAP_X, MAP_Y)
	SetColor(245, 202, 95)
	For Local cell:STileCell = EachIn area
		If ground.Cell(cell.column, cell.row) Then Outline(grid, cell.column, cell.row)
	Next
	SetColor(255, 255, 255)
	SetLineWidth(3)
	Outline(grid, selectedColumn, selectedRow)
	SetLineWidth(1)
	If hover Then
		SetColor(140, 220, 255)
		Outline(grid, column, row)
		Local terrain:String = ground.Property(column, row, "terrain").AsString()
		DrawText("Cell " + column + ", " + row + "  Terrain: " + terrain + "  Distance: " + grid.Distance(selectedColumn, selectedRow, column, row), 40, 578)
	End If
	frames :+ 1
	If frames = 3 And screenshot Then SavePixmapPNG(GrabPixmap(0, 0, NativeResolutionWidth(), NativeResolutionHeight()), screenshot)
	Flip()
	If test And frames >= 3 Then Exit
Wend
EndGraphics()

Function HexImage:TImage(grid:TTileGrid, color:Int)
	Local pixels:TPixmap = CreatePixmap(Int(grid.TileWidth()), Int(grid.TileHeight()), PF_RGBA8888)
	pixels.ClearPixels(0)
	For Local y:Int = 0 Until pixels.height
		For Local x:Int = 0 Until pixels.width
			If grid.Contains(0, 0, x + 0.5, y + 0.5) Then pixels.WritePixel(x, y, color)
		Next
	Next
	Return TImage.FromPixmap(pixels)
End Function

Function Outline(grid:TTileGrid, column:Int, row:Int)
	For Local corner:Int = 0 Until grid.CornerCount()
		Local x0:Double, y0:Double, x1:Double, y1:Double
		grid.CellCorner(column, row, corner, x0, y0)
		grid.CellCorner(column, row, (corner + 1) Mod grid.CornerCount(), x1, y1)
		DrawLine(Float(x0) + MAP_X, Float(y0) + MAP_Y, Float(x1) + MAP_X, Float(y1) + MAP_Y, False)
	Next
End Function
