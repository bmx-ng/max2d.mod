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

Import Max2D.RichText
Import Max2D.ScalableFont
Import Text.Unibreak
Import BRL.FileSystem
Import Pub.StdC

' Fonts are loaded once. RichText itself has no dependency on an outline font loader.
Local paths:String[4]
?osx
paths[0] = "/System/Library/Fonts/Supplemental/Arial.ttf"
paths[1] = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
paths[2] = "/System/Library/Fonts/Supplemental/Arial Italic.ttf"
paths[3] = "/System/Library/Fonts/Supplemental/Arial Bold Italic.ttf"
?win32
paths[0] = getenv_("WINDIR") + "/Fonts/segoeui.ttf"
paths[1] = getenv_("WINDIR") + "/Fonts/segoeuib.ttf"
paths[2] = getenv_("WINDIR") + "/Fonts/segoeuii.ttf"
paths[3] = getenv_("WINDIR") + "/Fonts/segoeuiz.ttf"
?linux
paths[0] = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
paths[1] = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
paths[2] = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf"
paths[3] = "/usr/share/fonts/truetype/dejavu/DejaVuSans-BoldOblique.ttf"
?

Local font:TImageFont = TImageFont.DefaultFont()
If FileType(paths[0]) = FILETYPE_FILE Then font = LoadScalableImageFont(paths[0], 20)
Local styles:TStyledTextStyles = TStyledTextStyles.Create(font)
For Local variant:Int = 0 Until 4
	If FileType(paths[variant]) <> FILETYPE_FILE Then Continue
	For Local size:Int = EachIn [0, 28]
		Local pixels:Int = size
		If pixels = 0 Then pixels = 20
		Local face:TImageFont = LoadScalableImageFont(paths[variant], pixels)
		If face Then styles.RegisterFont("default", face, size, variant & 1, (variant Shr 1) & 1)
	Next
Next
' Keep the example usable with the built-in font if no system font was available.
If FileType(paths[0]) <> FILETYPE_FILE Then styles.RegisterFont("default", font, 28)

Local heading:TStyledTextStyle = New TStyledTextStyle
heading.bold = True
heading.size = 28
heading.foreground = $FFD060
styles.RegisterStyle("heading", heading)

Local markup:String = "[style=heading]A message from mission control[/style]~n~n"
markup :+ "Welcome, " + EscapeStyledText("Pilot [42]") + ". Your [b]bold choices[/b] and [i]careful planning[/i] made the difference. "
markup :+ "Nested styles work too: [b]bold, [i]bold italic[/i], then bold again[/b].~n~n"
markup :+ "[color=#74D9FF]Fuel reserves: [b]84%[/b][/color]   [bg=#38504580][color=#BDF4C8]Landing zone clear[/color][/bg]~n~n"
markup :+ "The landing-zone background is translucent; its text stays opaque.~n~n"
markup :+ "[size=28]Larger text[/size] shares a baseline with ordinary text. [alpha=0.45]This transmission is fading.[/alpha]~n~n"
markup :+ "To show tags literally, double opening brackets: [[b]this is not bold[[/b]. "
markup :+ "Colours do not split the underlying font runs, so changing colour does not interrupt shaping.~n~n"
markup :+ "[style=heading]Select the visible text[/style]~n~n"
markup :+ "Click and drag to select. Double-click selects a word; triple-click selects a line. "
markup :+ "The selection contains plain text, never the tags. Scroll to read the rest, or change the panel width to reflow.~n~n"
markup :+ "The parser runs once before the loop. A new theme prepares the same parsed document again. "
markup :+ "Drawing uses the retained layout, and width changes reuse the prepared paragraph."

Local document:TStyledTextDocument = ParseStyledText(markup, True)
Local prepared:TPreparedText = document.Prepare(styles)
Local width:Float = 840
Local panelHeight:Float = 380
Local paragraph:TParagraphLayout = prepared.Layout(width)
Local controller:TTextSelectionController = New TTextSelectionController
controller.SetLayout(paragraph)
Local scrollY:Float
Local alternateTheme:Int
Local frames:Int

AppTitle = "Max2D rich text markup"
Graphics 960, 720
SetVirtualResolution(960, 720, VIRTUAL_LETTERBOX)
SetImageFont(font)

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local changed:Int
	If KeyHit(KEY_LEFT)
		width = Max(320, width - 80)
		changed = True
	End If
	If KeyHit(KEY_RIGHT)
		width = Min(840, width + 80)
		changed = True
	End If
	If KeyHit(KEY_T)
		alternateTheme = Not alternateTheme
		If alternateTheme Then heading.foreground = $B5A4FF Else heading.foreground = $FFD060
		styles.RegisterStyle("heading", heading)
		prepared = document.Prepare(styles)
		changed = True
	End If
	If changed
		paragraph = prepared.Layout(width)
		controller.SetLayout(paragraph)
	End If
	scrollY = Max(0.0, Min(Max(0.0, paragraph.height - panelHeight), scrollY - MouseZSpeed() * 30))
	Local mouseX:Float
	Local mouseY:Float
	Local inside:Int = GetVirtualMouse(mouseX, mouseY)
	inside = inside And mouseX >= 48 And mouseX < 48 + width And mouseY >= 184 And mouseY < 184 + panelHeight
	If AppSuspended() Then controller.CancelDrag()
	If MouseHit(1) And inside And Not AppSuspended() Then controller.PointerDown(mouseX - 48, mouseY - 184 + scrollY, MilliSecs())
	If controller.dragging
		controller.PointerMove(Max(0.0, Min(width, mouseX - 48)), Max(0.0, Min(panelHeight, mouseY - 184)) + scrollY)
		If Not MouseDown(1) Then controller.PointerUp()
	End If

	SetClsColor(18, 23, 32)
	Cls
	SetColor(235, 240, 250)
	DrawText "Rich text: parse once, draw retained layouts", 32, 24
	DrawText "[b]bold[/b]   [color=#FFD060]colour[/color]   [style=heading]title[/style]", 32, 64
	DrawText "Left/right: panel width    T: theme    Mouse wheel: scroll    Escape: exit", 32, 104
	Using
		Local panel:TMax2DStateScope = ScopedMax2DState()
	Do
		SetColor(28, 36, 49)
		DrawRect(32, 168, width + 32, panelHeight + 32)
		IntersectViewport(48, 184, Int(width), Int(panelHeight))
		DrawTextBackgroundsVisible(paragraph, 48, 184 - scrollY, scrollY, scrollY + panelHeight)
		SetColor(55, 90, 145)
		For Local rectangle:TTextSelectionRect = EachIn paragraph.SelectionRectsVisible(controller.anchor, controller.active, scrollY, scrollY + panelHeight)
			DrawRect(48 + rectangle.x, 184 - scrollY + rectangle.y, rectangle.width, rectangle.height)
		Next
		SetColor(220, 230, 244)
		DrawTextLayoutVisible(paragraph, 48, 184 - scrollY, scrollY, scrollY + panelHeight, False)
	End Using
	SetColor(235, 240, 250)
	Local first:Int = controller.SelectionStart()
	Local last:Int = controller.SelectionEnd()
	DrawText "Plain-text selection: " + first + " to " + last + "    Lines: " + paragraph.lines.Length, 32, 608
	Local selected:String = document.PlainText()[first..last].Replace("~n", " ")
	If selected.Length > 70 Then selected = selected[..70] + "..."
	DrawText selected, 32, 642
	Flip
	frames :+ 1
	If AppArgs.Length > 1 And AppArgs[1] = "--test" And frames >= 3 Then Exit
Wend

EndGraphics
