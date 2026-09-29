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
Import BRL.StandardIO
Import BRL.FileSystem
Import Pub.StdC
Import Max2D.ScalableFont
Import Text.Unibreak

' Use a system outline font when available; no font asset is bundled.
Local fontPath:String
?osx
fontPath = "/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath = getenv_("WINDIR") + "/Fonts/segoeui.ttf"
?linux
fontPath = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TScalableImageFont
If FileType(fontPath) = FILETYPE_FILE Then font = LoadScalableImageFont(fontPath, 18)
AppTitle = "Max2D optional Unicode boundaries"
Graphics 1080, 720
SetVirtualResolution(720, 480, VIRTUAL_LETTERBOX)
If font Then SetImageFont(font)
Local text:String = "This example imports Text.Unibreak. Resize the box to see Unicode break opportunities in use.~n~n"
text :+ "A soft hyphen allows co" + Chr($ad) + "operate to break when needed. A nonbreaking space keeps 10" + Chr($a0) + "km together. A zero-width space permits a break in path" + Chr($200b) + "segment."
Local prepared:TPreparedText = PrepareText(text)
Local boxWidth:Float = 520
Local boxHeight:Float = 200
Local alignment:Int = TEXT_ALIGN_LEFT
Local verticalAlignment:Int = TEXT_ALIGN_TOP
Local paragraph:TParagraphLayout = prepared.LayoutBox(boxWidth, boxHeight, alignment, 25, 0, "...", verticalAlignment)
Local frames:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local changed:Int
	If KeyHit(KEY_LEFT) Then
		boxWidth = Max(200, boxWidth - 40)
		changed = True
	End If
	If KeyHit(KEY_RIGHT) Then
		boxWidth = Min(640, boxWidth + 40)
		changed = True
	End If
	If KeyHit(KEY_UP) Then
		boxHeight = Max(0, boxHeight - 25)
		changed = True
	End If
	If KeyHit(KEY_DOWN) Then
		boxHeight = Min(250, boxHeight + 25)
		changed = True
	End If
	If KeyHit(KEY_1) Then alignment = TEXT_ALIGN_LEFT; changed = True
	If KeyHit(KEY_2) Then alignment = TEXT_ALIGN_CENTER; changed = True
	If KeyHit(KEY_3) Then alignment = TEXT_ALIGN_RIGHT; changed = True
	If KeyHit(KEY_4) Then verticalAlignment = TEXT_ALIGN_TOP; changed = True
	If KeyHit(KEY_5) Then verticalAlignment = TEXT_ALIGN_MIDDLE; changed = True
	If KeyHit(KEY_6) Then verticalAlignment = TEXT_ALIGN_BOTTOM; changed = True
	If changed Then paragraph = prepared.LayoutBox(boxWidth, boxHeight, alignment, 25, 0, "...", verticalAlignment)
	SetClsColor(18, 23, 32)
	Cls()
	SetColor(240, 245, 255)
	DrawText "Optional Unicode boundaries", 24, 18
	DrawText "Arrows resize; 1/2/3 horizontal; 4/5/6 vertical", 24, 48
	DrawText "Width: " + Int(boxWidth) + "   Height: " + Int(boxHeight) + "   Lines: " + paragraph.lines.Length + "/" + paragraph.totalLineCount, 24, 80
	Using
		Local panel:TMax2DStateScope = ScopedMax2DState()
	Do
		IntersectViewport(24, 140, Int(boxWidth) + 24, Int(boxHeight) + 24)
		SetColor(32, 43, 60)
		DrawRect(24, 140, boxWidth + 24, boxHeight + 24)
		SetColor(220, 230, 244)
		DrawTextLayout(paragraph, 36, 152)
	End Using
	SetColor(240, 245, 255)
	DrawText GetTextBoundaryProvider().Name() + "   Escape to exit.", 24, 442
	Flip
	frames :+ 1
	If AppArgs.Length > 1 And AppArgs[1] = "--test" And frames >= 3 Then Exit
Wend
EndGraphics()
