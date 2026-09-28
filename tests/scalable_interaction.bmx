SuperStrict
Framework Max2D.Core
Import Max2D.ScalableFont
Import Text.Unibreak
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
If AppArgs.Length<2 Then Throw "Supply NotoSans-Regular.ttf"
Local font:TScalableImageFont=LoadScalableImageFont(AppArgs[1],18)
Check(font<>Null,"Load scalable font")
Local blank:TParagraphLayout=PrepareText("~n",font,ETextBreakMode.Auto,"",True).Layout(200)
Check(blank.CaretAt(1).lineIndex=1,"Empty shaped lines have valid carets")
Local prepared:TPreparedText=PrepareText("office AV x"+Chr($301),font,ETextBreakMode.Auto,"",True)
Local layout:TParagraphLayout=prepared.Layout(400)
Local builds:Long=font.layoutBuilds
layout.PrepareInteraction()
Check(font.layoutBuilds=builds,"Caret shaping does not rebuild or rasterize layouts")
Local points:TTextCaret[]=layout.lines[0].carets
Check(points.Length<layout.lines[0].text.Length+1,"Ligature and combining clusters remove interior stops")
For Local point:TTextCaret=EachIn points
	Check(point.sourceOffset<>2 And point.sourceOffset<>3,"ffi ligature remains one cluster")
	Check(point.sourceOffset<>11,"Combining mark has no interior caret")
	Check(layout.HitTest(point.x,point.y).sourceOffset=point.sourceOffset,"Shaped caret hit-test round trip")
Next
Check(Abs(points[points.Length-1].x-layout.width)<0.01,"Caret extent agrees with whole-line shaping")
Local word:STextRange=layout.WordAtPoint(layout.CaretAt(1).x+1,0)
Check(word.sourceStart=0 And word.sourceEnd=6,"Word query uses shaped ligature coverage")
Local ligature:TTextSelectionRect[]=layout.SelectionRects(2,3)
Check(ligature.Length=1 And ligature[0].sourceStart=1 And ligature[0].sourceEnd=4,"Partial ffi selection expands to shaped cluster")
Local kerned:TParagraphLayout=PrepareText("AV",font,ETextBreakMode.Auto,"",True).Layout(200)
Local middle:TTextCaret=kerned.CaretAt(1)
Check(middle.x<font.Layout("A").width,"Caret uses contextual kerning advance")
For Local i:Int=0 Until 10000
	Check(kerned.CaretAt(1)=middle,"Caret object reused")
Next
Check(kerned.interactionBuilds=1,"Only one interaction geometry build")
If AppArgs.Length>2 Then
	Local arabic:TScalableImageFont=LoadScalableImageFont(AppArgs[2],18)
	Local rtl:TParagraphLayout=PrepareText("سلام",arabic,ETextBreakMode.Auto,"",True).Layout(200)
	rtl.PrepareInteraction()
	Local rtlWord:STextRange=rtl.WordAtPoint(rtl.width-1,0)
	Check(rtlWord.sourceStart=0 And rtlWord.sourceEnd=4,"RTL word query follows descending caret positions")
	Local selected:TTextSelectionRect[]=rtl.SelectionRects(0,4)
	Check(selected.Length=1 And selected[0].width>0 And Abs(selected[0].width-rtl.width)<0.01,"RTL selection covers full advance with positive width")
	Local largerArabic:TScalableImageFont=LoadScalableImageFont(AppArgs[2],26)
	Local styledArabic:TPreparedText=PrepareText("سلام",arabic,ETextBreakMode.Auto,"",True)
	styledArabic.SetFontSpans([TTextFontSpan.Create(0,2,largerArabic)])
	Local rejected:Int
	Try
		styledArabic.Layout(200)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Multi-run RTL font styling is explicitly rejected until bidi layout is available")
	Check(rtl.CaretAt(0).x>rtl.CaretAt(4).x,"Single RTL run reverses source-to-x order")
	For Local point:TTextCaret=EachIn rtl.lines[0].carets
		Check(rtl.HitTest(point.x,point.y).sourceOffset=point.sourceOffset,"RTL caret round trip")
	Next
End If
Print "Max2D scalable interaction tests passed"

Local clusterColor:TTextColorSpan=TTextColorSpan.Create(1,2)
clusterColor.SetForeground(255,80,0)
clusterColor.SetBackground(20,40,80,0.5)
prepared.SetColorSpans([clusterColor])
Local paint:TTextPaint=layout.PrepareLinePaint(0)
Local colored:Int
For Local i:Int=0 Until layout.lines[0].layout.glyphs.Length
	If layout.lines[0].layout.glyphs[i].sourceOffset=1 Then
		Check(paint.glyphColors[i]<>Null,"Ligature uses first source character's colour")
		colored:+1
	End If
Next
Check(colored>0 And paint.backgrounds.Length=1,"Real-font cluster foreground and background exist")
Local oldWidth:Float=layout.width
Local oldBuilds:Long=font.layoutBuilds
clusterColor.sourceStart=2;clusterColor.sourceEnd=3
prepared.SetColorSpans([clusterColor])
paint=layout.PrepareLinePaint(0)
For Local color:TTextColorSpan=EachIn paint.glyphColors
	Check(color=Null,"Span beginning inside a ligature does not split or recolour its first character")
Next
Check(paint.backgrounds.Length=0 And layout.width=oldWidth And font.layoutBuilds=oldBuilds,"Colour boundary changes never reshape or split clusters")
Print "Max2D scalable colour tests passed"

Local sameFont:TPreparedText=PrepareText("office AV",font,ETextBreakMode.Auto,"",True)
sameFont.SetFontSpans([TTextFontSpan.Create(0,2,font),TTextFontSpan.Create(2,9,font)])
Local combined:TStyledTextLayout=TStyledTextLayout(sameFont.Layout(200).lines[0].layout)
Check(combined.runs.Length=1 And combined.width=font.Layout("office AV").width,"Same-font spans preserve actual ligatures and kerning")
