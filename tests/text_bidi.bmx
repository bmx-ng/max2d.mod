SuperStrict
Framework Max2D.Core
Import Text.SheenBidi
Import Text.Unibreak
Import BRL.StandardIO

Function Check(value:Int,message:String)
	If Not value Then Throw message
End Function
Type TDirectionFont Extends TImageFont
	Field caretBuilds:Int,runBuilds:Int
	Method Height:Int() Override
		Return 16
	End Method
	Method Layout:TTextLayout(text:String) Override
		Local result:TTextLayout=New TTextLayout
		result.width=text.Length*8;result.height=16
		Return result
	End Method
	Method LayoutRun:TTextLayout(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="") Override
		runBuilds:+1
		Local result:TTextLayout=Layout(text[first..last]);result.rightToLeft=rtl
		Return result
	End Method
	Method CreateRunCaretMap:TTextCaretMap(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="") Override
		caretBuilds:+1
		Local result:TTextCaretMap=TTextCaretMap.Create(last-first)
		For Local i:Int=0 To last-first
			result.valid[i]=True
			If rtl Then result.positions[i]=(last-first-i)*8 Else result.positions[i]=i*8
		Next
		Return result
	End Method
End Type
Local font:TDirectionFont=New TDirectionFont
Local disabled:TPreparedText=PrepareText("abc אבג 123",font,ETextBreakMode.Auto,"",False,ETextDirection.Disabled)
Check(Not disabled.bidiProvider And Not disabled.blocks[0].bidi And Not disabled.interaction,"Disabled path allocates no bidi or interaction state")
disabled.Layout(200)
Check(font.runBuilds=0 And font.caretBuilds=0,"Disabled path never enters directional shaping")
Local prepared:TPreparedText=PrepareText("abc אבג 123",font,ETextBreakMode.Auto,"",True)
Local layout:TParagraphLayout=prepared.Layout(200)
Local shaped:TBidiTextLayout=TBidiTextLayout(layout.lines[0].layout)
Check(shaped<>Null And shaped.runs.Length=3,"Three visual runs")
Check(shaped.runs[0].first=0 And shaped.runs[1].first=8 And shaped.runs[2].first=4,"Visual order retains logical offsets")
Check(Not layout.lines[0].carets And Not layout.lines[0].bidiCarets And font.caretBuilds=0,"Interaction is lazy")
Check(layout.CaretAt(4).x=88,"Following affinity uses Hebrew leading edge")
Check(layout.CaretAt(4,True,ETextCaretAffinity.Preceding).x=32,"Preceding affinity uses Latin trailing edge")
Check(layout.HitTest(87,0).sourceOffset=4,"Right edge maps back to Hebrew start")
Check(layout.WordAtPoint(80,0).sourceStart=4 And layout.WordAtPoint(80,0).sourceEnd=7,"Word selection follows visual Hebrew cell")
Local rects:TTextSelectionRect[]=layout.SelectionRects(2,5)
Check(rects.Length=2,"One logical selection can occupy disconnected rectangles")
Check(rects[0].x=16 And rects[0].width=16 And rects[1].x=80 And rects[1].width=8,"Selection excludes unrelated visual text")
Local bg:TTextColorSpan=TTextColorSpan.Create(2,5)
bg.SetBackground(20,40,60)
prepared.SetColorSpans([bg])
Check(layout.PrepareLinePaint(0).backgrounds.Length=2,"Backgrounds follow disconnected coverage")
Local controller:TTextSelectionController=New TTextSelectionController
controller.SetLayout(layout);controller.PointerDown(80,0,100,2)
Check(controller.SelectionStart()=4 And controller.SelectionEnd()=7,"Double-click selects logical RTL word")
controller.PointerUp()
Local carets:Int=font.caretBuilds,runs:Int=font.runBuilds
For Local i:Int=0 Until 1000
	Check(prepared.Layout(200)=layout,"Reflow cache retained")
	layout.HitTest(i Mod 88,0);layout.CaretAt(i Mod 12)
	Check(layout.SelectionRects(2,5)=rects,"Selection result retained")
Next
Check(font.caretBuilds=carets And font.runBuilds=runs,"Warm interaction never reshapes")
Local wrapped:TParagraphLayout=prepared.Layout(32)
For Local line:TParagraphLine=EachIn wrapped.lines
	Check(TBidiTextLayout(line.layout).paragraph.baseLevel=0,"Wrapped lines preserve paragraph base direction")
Next
Local box:TParagraphLayout=prepared.LayoutBox(64,16)
Check(box.truncated And TBidiTextLayout(box.lines[0].layout)<>Null,"Ellipsis uses bidi layout")
box.PrepareInteraction()
Local plain:TPreparedText=PrepareText("abc אבג",font)
Local plainLayout:TParagraphLayout=plain.Layout(200)
Check(Not plain.interaction And Not plainLayout.lines[0].carets,"Noninteractive bidi text has no caret mappings")
Local provider:TTextBidiProvider=GetTextBidiProvider()
RegisterTextBidiProvider(Null)
Local fallback:TPreparedText=PrepareText("abc",font)
Check(Not fallback.bidiProvider And Not fallback.blocks[0].bidi,"No provider uses original path")
Check(prepared.Layout(200)=layout,"Captured layouts survive unregister")
RegisterTextBidiProvider(provider)
Local styleFont:TDirectionFont=New TDirectionFont
prepared.SetFontSpans([TTextFontSpan.Create(4,5,styleFont)])
Local styled:TParagraphLayout=prepared.Layout(200)
Local styledLine:TBidiTextLayout=TBidiTextLayout(styled.lines[0].layout)
Check(styledLine.runs[styledLine.runs.Length-1].font=styleFont,"RTL font subdivisions reverse visually")
Check(styled.SelectionRects(2,5).Length=2,"Mixed-font directional selection")
controller.SetLayout(styled)
Check(controller.SelectionStart()=4 And controller.SelectionEnd()=7,"Selection survives bidi font reflow")
Local rtl:TPreparedText=PrepareText("אבג abc 123",font,ETextBreakMode.Auto,"",True)
Local rtlBox:TParagraphLayout=rtl.LayoutBox(64,16)
Local rtlLine:TBidiTextLayout=TBidiTextLayout(rtlBox.lines[0].layout)
Check(rtlLine.rightToLeft And rtlLine.runs[0].first=rtlLine.paragraphLength,"RTL ellipsis is at the visual left")
rtlBox.PrepareInteraction()
Check(rtlBox.SelectionRects(0,100).Length=1,"Synthetic RTL ellipsis is not selected")
Local normalized:TPreparedText=PrepareText("  abc~tאבג  123~r~nאבג",font,ETextBreakMode.Auto,"",True)
Local normalizedLayout:TParagraphLayout=normalized.Layout(200)
Check(normalizedLayout.CaretAt(6).sourceOffset=6,"Bidi preserves original normalized source offsets")
Check(normalizedLayout.LineRange(1).sourceStart=16,"Bidi preserves CRLF source offsets")
Local bgBuilds:Int=styled.interactionBuilds
styled.SelectionRectsVisible(0,10,1000,1100)
Check(styled.interactionBuilds=bgBuilds,"Invisible lines do not build bidi carets")
Print "Max2D bidi layout and interaction tests passed"
