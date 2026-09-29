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
Import Text.SheenBidi

' Use a system outline font when available; no font asset is bundled.
Local fontPath:String,boldPath:String,italicPath:String
?osx
fontPath = "/System/Library/Fonts/Supplemental/Arial.ttf"
boldPath = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
italicPath = "/System/Library/Fonts/Supplemental/Arial Italic.ttf"
?win32
fontPath = getenv_("WINDIR") + "/Fonts/segoeui.ttf"
boldPath = getenv_("WINDIR") + "/Fonts/segoeuib.ttf"
italicPath = getenv_("WINDIR") + "/Fonts/segoeuii.ttf"
?linux
fontPath = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
boldPath = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
italicPath = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf"
?
Local font:TScalableImageFont,boldFont:TScalableImageFont,italicFont:TScalableImageFont
If FileType(fontPath) = FILETYPE_FILE Then font = LoadScalableImageFont(fontPath, 18)
If FileType(boldPath) = FILETYPE_FILE Then boldFont = LoadScalableImageFont(boldPath, 28)
If FileType(italicPath) = FILETYPE_FILE Then italicFont = LoadScalableImageFont(italicPath, 20)
AppTitle = "Max2D bidirectional text interaction"
Graphics 1080, 720
SetVirtualResolution(720, 480, VIRTUAL_LETTERBOX)
If font Then SetImageFont(font)
If Not font Then Throw "This example requires an outline font with Latin, Hebrew and Arabic glyphs. Set fontPath to a suitable installed font."
Local text:String = "Mixed text: abc אבג 123 (test). Select across the language boundary.~n~n"
text :+ "مرحبا بالعالم! Score: 42 (Max2D). هذا مثال للنص العربي.~n~n"
text :+ "שלום עולם! Max2D supports mixed text and numbers: 123.45.~n~n"
text :+ "Arabic and Latin: مرحبا بالعالم. Wrapping retains the paragraph direction.~n~n"
text :+ text
Local prepared:TPreparedText = PrepareText(text, Null, ETextBreakMode.Auto, "", True)
Local emphasis:TTextColorSpan = TTextColorSpan.Create(0, 16)
emphasis.SetForeground(255, 205, 80)
Local tinted:TTextColorSpan = TTextColorSpan.Create(21, 34)
tinted.SetForeground(120, 220, 255)
tinted.SetBackground(30, 75, 110, 0.7)
prepared.SetColorSpans([emphasis, tinted])
Local fontSpans:TTextFontSpan[]
If boldFont And italicFont Then
	fontSpans = [TTextFontSpan.Create(text.Find("אבג"), text.Find("אבג") + 3, boldFont), TTextFontSpan.Create(text.Find("Score"), text.Find("Score") + 5, italicFont)]
	prepared.SetFontSpans(fontSpans)
End If
Local stylesEnabled:Int = fontSpans.Length > 0
Local coloursEnabled:Int = True
Local boxWidth:Float = 520
Local boxHeight:Float = 200
Local alignment:Int = TEXT_ALIGN_LEFT
Local scrollY:Float
Local paragraph:TParagraphLayout = prepared.Layout(boxWidth, alignment, 25)
Local frames:Int
Local controller:TTextSelectionController = New TTextSelectionController
controller.SetLayout(paragraph)
Local selection:TTextSelectionRect[]
Local caret:TTextCaret
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local changed:Int
	If KeyHit(KEY_F) And fontSpans.Length Then
		stylesEnabled = Not stylesEnabled
		If stylesEnabled Then prepared.SetFontSpans(fontSpans) Else prepared.SetFontSpans(Null)
		changed = True
	End If
	If KeyHit(KEY_C) Then
		coloursEnabled = Not coloursEnabled
		If coloursEnabled Then prepared.SetColorSpans([emphasis, tinted]) Else prepared.SetColorSpans(Null)
	End If
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
	If changed Then
		paragraph = prepared.Layout(boxWidth, alignment, 25)
		controller.SetLayout(paragraph)
	End If
	scrollY = Max(0.0, Min(Max(0.0, paragraph.height - boxHeight), scrollY - MouseZSpeed() * 25))
	Local mouseX:Float, mouseY:Float
	caret = Null
	If GetVirtualMouse(mouseX, mouseY) Then
		If mouseX >= 36 And mouseX < 36 + boxWidth And mouseY >= 152 And mouseY < 152 + boxHeight Then
			caret = paragraph.HitTest(mouseX - 36, mouseY - 152 + scrollY)
		End If
	End If
	If AppSuspended() Then controller.CancelDrag()
	If MouseHit(1) And caret And Not AppSuspended() Then controller.PointerDown(mouseX - 36, mouseY - 152 + scrollY, MilliSecs())
	If controller.dragging Then
		' Host keeps routing captured input, clamping at the visible panel edges.
		Local localX:Float = Max(0.0, Min(boxWidth, mouseX - 36))
		Local localY:Float = Max(0.0, Min(boxHeight, mouseY - 152)) + scrollY
		controller.PointerMove(localX, localY)
		caret = paragraph.HitTest(localX, localY)
		If Not MouseDown(1) Then controller.PointerUp()
	End If
	selection = paragraph.SelectionRectsVisible(controller.anchor, controller.active, scrollY, scrollY + boxHeight)
	SetClsColor(18, 23, 32)
	Cls()
	SetColor(240, 245, 255)
	DrawText "Optional bidirectional text", 24, 18
	DrawText "C colours; F fonts; wheel scrolls; arrows resize; 1/2/3 align", 24, 48
	DrawText "Width: " + Int(boxWidth) + "   Height: " + Int(boxHeight) + "   Lines: " + paragraph.lines.Length + "/" + paragraph.totalLineCount, 24, 80
	Using
		Local panel:TMax2DStateScope = ScopedMax2DState()
	Do
		IntersectViewport(24, 140, Int(boxWidth) + 24, Int(boxHeight) + 24)
		SetColor(32, 43, 60)
		DrawRect(24, 140, boxWidth + 24, boxHeight + 24)
		SetColor(220, 230, 244)
		IntersectViewport(36, 152, Int(boxWidth), Int(boxHeight))
		DrawTextBackgroundsVisible(paragraph, 36, 152 - scrollY, scrollY, scrollY + boxHeight)
		SetColor(55, 90, 145)
		For Local rectangle:TTextSelectionRect = EachIn selection
			DrawRect(36 + rectangle.x, 152 - scrollY + rectangle.y, rectangle.width, rectangle.height)
		Next
		SetColor(220, 230, 244)
		DrawTextLayoutVisible(paragraph, 36, 152 - scrollY, scrollY, scrollY + boxHeight, False)
		If caret Then
			SetColor(255, 205, 80)
			DrawRect(36 + caret.x, 152 - scrollY + caret.y, 1, caret.height)
		End If
	End Using
	SetColor(240, 245, 255)
	If caret Then DrawText "Source offset: " + caret.sourceOffset + "   Line: " + caret.lineIndex, 24, 408
	DrawText "Double-click word; triple-click line; drag extends. Esc exits.", 24, 442
	Flip
	frames :+ 1
	If AppArgs.Length > 1 And AppArgs[1] = "--test" And frames >= 3 Then Exit
Wend
EndGraphics()
