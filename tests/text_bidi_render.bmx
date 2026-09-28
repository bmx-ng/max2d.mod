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
Import Max2D.ScalableFont
Import Text.SheenBidi
Import Text.Unibreak
Import BRL.StandardIO

Function Check(value:Int,message:String)
	If Not value Then Throw message
End Function
If AppArgs.Length<2 Then Throw "Supply a font supporting Latin, Hebrew and Arabic"
Local font:TScalableImageFont=LoadScalableImageFont(AppArgs[1],22)
Local large:TScalableImageFont=LoadScalableImageFont(AppArgs[1],30)
Check(font<>Null And large<>Null,"Load fonts")
Local prepared:TPreparedText=PrepareText("abc אבג 123",font,ETextBreakMode.Auto,"",True)
prepared.SetFontSpans([TTextFontSpan.Create(4,7,large)])
Local ink:TTextColorSpan=TTextColorSpan.Create(4,7)
ink.SetForeground(100,220,180)
prepared.SetColorSpans([ink])
Local paragraph:TParagraphLayout=prepared.Layout(400)
Check(Not paragraph.lines[0].carets,"No eager real-font caret data")
' Independent, explicit visual order: Latin, digits, RTL space, larger Hebrew.
Local refs:TTextLayout[]=[font.LayoutRun("abc ",0,4,False),font.LayoutRun("123",0,3,False),font.LayoutRun(" ",0,1,True),large.LayoutRun("אבג",0,3,True)]
Graphics(440,160,0,0)
Local target:TRenderImage=CreateRenderImage(440,160,0)
SetRenderImage(target);SetClsColor(0,0,0)
For Local transformed:Int=0 To 1
	If transformed Then SetRotation(7);SetScale(1.1,1.1)
	SetColor(230,240,250);Cls();DrawTextLayout(paragraph,10,15)
	Local actual:TPixmap=ReadRenderImage(target)
	Cls()
	Local state:TMax2DState=TMax2DGraphics.Current().state
	Local pen:Float,baseline:Float=Max(font.Baseline(),large.Baseline())
	For Local i:Int=0 Until refs.Length
		Local y:Float=baseline-font.Baseline()
		If i=3 Then y=baseline-large.Baseline();SetColor(100,220,180)
		DrawTextLayout(refs[i],10+pen*state.ix+y*state.iy,15+pen*state.jx+y*state.jy)
		pen:+refs[i].width
	Next
	Local expected:TPixmap=ReadRenderImage(target)
	For Local y:Int=0 Until 160
		For Local x:Int=0 Until 440
			Check(actual.ReadPixel(x,y)=expected.ReadPixel(x,y),"Bidi pixels match independently ordered font runs")
		Next
	Next
Next
paragraph.PrepareInteraction()
Check(paragraph.SelectionRects(2,5).Length=2,"Real-font selection has disconnected rectangles")
Check(paragraph.CaretAt(4).x>paragraph.CaretAt(4,True,ETextCaretAffinity.Preceding).x,"Real-font boundary affinity")
' Context-sensitive Arabic joining must survive a font-run boundary.
Local arabic:String="سلام"
Local whole:TScalableTextLayout=TScalableTextLayout(font.LayoutRun(arabic,0,4,True))
Local splitA:TScalableTextLayout=TScalableTextLayout(font.LayoutRun(arabic,0,1,True))
Check(splitA.glyphs.Length=1,"Arabic first glyph")
Check(TScalablePositionedGlyph(splitA.glyphs[0]).index=TScalablePositionedGlyph(whole.glyphs[whole.glyphs.Length-1]).index,"Arabic joining uses surrounding context")
Local mixed:TPreparedText=PrepareText("Score 42: مرحبا بالعالم (test)",font,ETextBreakMode.Auto,"",True)
Local multi:TParagraphLayout=mixed.Layout(190)
multi.PrepareInteraction()
For Local line:TParagraphLine=EachIn multi.lines
	Check(TBidiTextLayout(line.layout)<>Null,"Arabic mixed line shaped")
Next
Local marked:String="abc שָׁלוֹם"
Local markedRun:TTextLayout=font.LayoutRun(marked,4,marked.Length,True)
Local markedCarets:TTextCaretMap=font.CreateRunCaretMap(marked,4,marked.Length,True)
Check(Abs(markedCarets.positions[0]-markedRun.width)<0.01,"Nonzero-offset multi-glyph clusters preserve full advance")
Local leftBracket:TScalableTextLayout=TScalableTextLayout(font.LayoutRun("(",0,1,True))
Local rightBracket:TScalableTextLayout=TScalableTextLayout(font.LayoutRun(")",0,1,False))
Check(TScalablePositionedGlyph(leftBracket.glyphs[0]).index=TScalablePositionedGlyph(rightBracket.glyphs[0]).index,"RTL bracket mirroring is performed by HarfBuzz")
font.LayoutRun("אבג",0,3,True)
Check(Not font.Layout("fresh latin").rightToLeft,"Explicit run direction never leaks to later ordinary shaping")
EndGraphics()
Print "Max2D real-font bidi rendering tests passed"
