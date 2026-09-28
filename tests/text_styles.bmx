SuperStrict
Framework Max2D.Core
Import Text.Unibreak
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Type TMetricLayout Extends TTextLayout
	Field draws:Int
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float) Override
		draws:+1
	End Method
End Type
Type TMetricFont Extends TImageFont
	Field advance:Float,lineHeight:Float,ascent:Float
	Method Baseline:Float() Override
		Return ascent
	End Method
	Method Height:Int() Override
		Return Int(lineHeight)
	End Method
	Method Layout:TTextLayout(text:String) Override
		Local result:TTextLayout=New TMetricLayout
		result.height=lineHeight;result.width=advance*text.Length
		result.glyphs=New TPositionedGlyph[0]
		Return result
	End Method
	Method CreateCaretMap:TTextCaretMap(text:String) Override
		Local result:TTextCaretMap=TTextCaretMap.Create(text.Length)
		For Local i:Int=0 To text.Length
			result.positions[i]=i*advance;result.valid[i]=True
		Next
		Return result
	End Method
End Type
Local small:TMetricFont=New TMetricFont
small.advance=8;small.lineHeight=16;small.ascent=11
Local large:TMetricFont=New TMetricFont
large.advance=16;large.lineHeight=32;large.ascent=24
Local prepared:TPreparedText=PrepareText("ab CD ef",small,ETextBreakMode.Auto,"",True)
Local old:TParagraphLayout=prepared.Layout(200)
Local span:TTextFontSpan=TTextFontSpan.Create(3,5,large)
prepared.SetFontSpans([span])
span.font=small
Local full:TParagraphLayout=prepared.Layout(200)
Check(full<>old And full.height=32 And old.height=16,"Font changes create new stable layout snapshots")
Local mixed:TStyledTextLayout=TStyledTextLayout(full.lines[0].layout)
Check(mixed.runs.Length=3 And mixed.width=80,"Runs use explicit fonts and combined advances")
Check(mixed.runs[0].y=13 And mixed.runs[1].y=0 And mixed.runs[2].y=13,"Runs align on shared baseline")
Check(full.CaretAt(4).x=40 And full.CaretAt(4).height=32,"Mixed-font carets use run advances and line height")
Local wrapped:TParagraphLayout=prepared.Layout(40)
Check(wrapped.lines.Length=3,"Larger span participates in wrapping")
Check(wrapped.lines[0].y=0 And wrapped.lines[1].y=16 And wrapped.lines[2].y=48 And wrapped.height=64,"Variable line heights position subsequent lines")
Check(wrapped.HitTest(0,16).lineIndex=1,"Tall line is selectable from its top edge")
Check(wrapped.HitTest(0,48).lineIndex=2,"Hit testing follows variable line positions")
Local selection:TTextSelectionRect[]=wrapped.SelectionRects(3,5)
Check(selection.Length=1 And selection[0].height=32 And selection[0].y=16,"Selection follows styled line height")
Local bg:TTextColorSpan=TTextColorSpan.Create(3,5)
bg.SetBackground(10,20,30)
prepared.SetColorSpans([bg])
Check(wrapped.PrepareLinePaint(1).backgrounds[0].height=32,"Background follows styled line height")
Local box:TParagraphLayout=prepared.LayoutBox(40,48, TEXT_ALIGN_LEFT,0,0,"")
Check(box.lines.Length=2 And box.height<=48,"Height fitting uses actual line metrics")
Local bottom:TParagraphLayout=prepared.LayoutBox(40,100,TEXT_ALIGN_LEFT,0,0,"...",TEXT_ALIGN_BOTTOM)
Check(bottom.contentY=36 And bottom.lines[1].y=52,"Vertical alignment follows variable content height")
Local controller:TTextSelectionController=New TTextSelectionController
controller.SetLayout(wrapped);controller.PointerDown(0,16,1000,3)
prepared.SetFontSpans(Null)
Local reset:TParagraphLayout=prepared.Layout(40)
controller.SetLayout(reset)
Check(controller.SelectionStart()=3 And controller.SelectionEnd()=5,"Font reflow preserves source selection")
Check(wrapped.CaretAt(4).height=32 And reset.height<>wrapped.height,"Held old caret geometry is stable")
Local joined:TPreparedText=PrepareText("AB",small,ETextBreakMode.Auto,"",True)
joined.SetFontSpans([TTextFontSpan.Create(0,1,large),TTextFontSpan.Create(1,2,large)])
Check(TStyledTextLayout(joined.Layout(100).lines[0].layout).runs.Length=1,"Adjacent same-font spans merge before shaping")
Local mark:TPreparedText=PrepareText("a"+Chr($301)+"b",small,ETextBreakMode.Unicode,"",True)
mark.SetFontSpans([TTextFontSpan.Create(1,2,large)])
Check(TStyledTextLayout(mark.Layout(100).lines[0].layout).runs.Length=1,"Font boundary inside grapheme follows first character")
prepared.SetColorSpans(Null)
wrapped.DrawVisible(New TMax2DGraphics,0,0,48,64,False)
For Local i:Int=0 Until wrapped.lines.Length
	Local styled:TStyledTextLayout=TStyledTextLayout(wrapped.lines[i].layout)
	For Local run:TStyledTextRun=EachIn styled.runs
		Check(TMetricLayout(run.layout).draws=Int(i=2),"Variable-height culling submits only the intersecting line")
	Next
Next
Print "Max2D font span tests passed"
