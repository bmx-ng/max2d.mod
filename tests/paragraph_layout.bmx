SuperStrict
Framework Max2D.Core
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Type TContextFont Extends TImageFont
	Field joinedWidth:Float
	Method Layout:TTextLayout(text:String) Override
		Local result:TTextLayout=New TTextLayout
		result.glyphs=New TPositionedGlyph[0]
		result.height=16;result.width=text.Length*8
		If text="a b" Then result.width=joinedWidth
		Return result
	End Method
End Type
Local contextFont:TContextFont=New TContextFont
contextFont.joinedWidth=12
Check(PrepareText("a b",contextFont).Layout(16).lines.Length=1,"Whole-line shaping can fit more than word estimates")
contextFont.joinedWidth=40
Check(PrepareText("a b",contextFont).Layout(24).lines.Length=2,"Whole-line shaping can require an earlier break")
Check(Not UnicodeTextBoundariesAvailable(),"No provider is linked by ordinary Max2D imports")
Local unavailable:Int
Try
	PrepareText("test",New TContextFont,ETextBreakMode.Unicode)
Catch error:Object
	unavailable=True
End Try
Check(unavailable,"Explicit Unicode mode requires an imported provider")
Local font:TImageFont=TImageFont.DefaultFont()
Local prepared:TPreparedText=PrepareText("one two three",font)
Local layout:TParagraphLayout=prepared.Layout(56)
Check(layout.lines.Length=2 And layout.lines[0].text="one two" And layout.lines[1].text="three","Greedy word wrap")
Check(layout.width=56 And layout.height=32 And layout.boxWidth=56,"Paragraph metrics")
Local calls:Long=font.layoutBuilds
For Local i:Int=0 Until 1000
	Check(prepared.Layout(56)=layout,"Warm reflow returns retained layout")
Next
Check(font.layoutBuilds=calls And prepared.reflowBuilds=1,"Warm requests do not shape or rebuild")
Local centered:TParagraphLayout=prepared.Layout(80,TEXT_ALIGN_CENTER,20)
Check(centered.lines[0].x=12 And centered.lines[1].x=20,"Centre alignment")
Check(centered.lines[1].y=20 And centered.height=36,"Line spacing and last line height")
Local right:TParagraphLayout=prepared.Layout(80,TEXT_ALIGN_RIGHT)
Check(right.lines[0].x=24 And right.lines[1].x=40,"Right alignment")
Check(layout.lines[0].x=0 And layout.lines[1].y=16,"Reflow does not mutate retained layouts")
Local normalized:TParagraphLayout=PrepareText("  one~t two  ~r~n~nthree~n",font).Layout(56)
Check(normalized.lines.Length=4 And normalized.lines[0].text="one two","Whitespace and CRLF normalization")
Check(normalized.lines[1].text="" And normalized.lines[3].text="","Blank and trailing lines retained")
Check(PrepareText("",font).Layout(10).height=0,"Empty paragraph has no lines")
Local narrow:TParagraphLayout=PrepareText("longword x",font).Layout(0)
Check(narrow.lines.Length=2 And narrow.lines[0].text="longword" And narrow.width=64,"Long words overflow without splitting or looping")
Local unicodeWord:String="a"+Chr($a0)+"b"
Check(PrepareText(unicodeWord,font).Layout(8).lines.Length=1,"Nonbreaking space stays inside word")
prepared.SetCacheLimit(1)
prepared.Layout(200)
Check(layout.lines[0].layout.width=56,"Cache eviction preserves held layouts")
Check(prepared.Layout(56)<>layout,"Evicted width rebuilds")
prepared.SetCacheLimit(0)
Check(prepared.Layout(56)<>prepared.Layout(56),"Cache can be disabled")
Local caught:Int
Try
	prepared.Layout(-1)
Catch error:Object
	caught=True
End Try
Check(caught,"Negative width rejected")
caught=False
Try
	prepared.Layout(40,99)
Catch error:Object
	caught=True
End Try
Check(caught,"Invalid alignment rejected")
Local boxText:TPreparedText=PrepareText("one two three four five",font)
Local full:TParagraphLayout=boxText.Layout(56)
Local box:TParagraphLayout=boxText.LayoutBox(56,32)
Check(box.lines.Length=2 And box.lines[1].text="..." And box.truncated,"Height truncation uses whole-word ellipsis")
Check(box.totalLineCount=full.lines.Length And full.lines[1].text="three","Full layout remains unchanged")
Local cachedBuilds:Long=boxText.boxBuilds
calls=font.layoutBuilds
For Local i:Int=0 Until 1000
	Check(boxText.LayoutBox(56,32)=box,"Box cache identity")
Next
Check(boxText.boxBuilds=cachedBuilds And font.layoutBuilds=calls,"Cached boxes do not rebuild or reshape")
Local oneLine:TParagraphLayout=boxText.LayoutBox(56,100,TEXT_ALIGN_RIGHT,0,1)
Check(oneLine.lines.Length=1 And oneLine.lines[0].text="one..." And oneLine.lines[0].x=8,"Line limit and aligned marker")
Check(boxText.LayoutBox(56,15).lines.Length=0,"Less than one line fits no text")
Check(boxText.LayoutBox(56,0).truncated,"Zero height reports omitted text")
Check(Not PrepareText("",font).LayoutBox(0,0).truncated,"Empty input has no omitted text")
Local exact:TParagraphLayout=PrepareText("one two",font).LayoutBox(56,16)
Check(Not exact.truncated And exact.lines[0].text="one two","Exact fit needs no marker")
Local narrowBox:TParagraphLayout=PrepareText("longword",font).LayoutBox(16,16)
Check(narrowBox.truncated And narrowBox.lines[0].text="" And narrowBox.width=0,"Marker too wide produces empty line")
Check(boxText.LayoutBox(56,32,TEXT_ALIGN_LEFT,0,0,"").lines[1].text="three","Empty marker keeps fitting words")
Check(boxText.LayoutBox(56,35,TEXT_ALIGN_LEFT,20).lines.Length=1,"Height honours explicit spacing")
Local unicodeBox:TParagraphLayout=PrepareText("a"+Chr($301)+"word next",font).LayoutBox(24,16)
Check(unicodeBox.lines[0].text="...","Truncation does not slice a combining sequence")
caught=False
Try
	boxText.LayoutBox(56,-1)
Catch error:Object
	caught=True
End Try
Check(caught,"Negative box height rejected")
Local vertical:TPreparedText=PrepareText("one~ntwo",font)
Local top:TParagraphLayout=vertical.LayoutBox(80,80)
Local middle:TParagraphLayout=vertical.LayoutBox(80,80,TEXT_ALIGN_LEFT,0,0,"...",TEXT_ALIGN_MIDDLE)
Local bottom:TParagraphLayout=vertical.LayoutBox(80,80,TEXT_ALIGN_LEFT,0,0,"...",TEXT_ALIGN_BOTTOM)
Check(top.contentY=0 And middle.contentY=24 And bottom.contentY=48,"Vertical alignment uses logical paragraph height")
Check(middle.height=32 And bottom.height=32 And middle.lines[1].y=40 And bottom.lines[1].y=64,"Vertical placement preserves height and line spacing")
Check(middle.boundsY=top.boundsY+24 And bottom.boundsY=top.boundsY+48 And bottom.boundsHeight=top.boundsHeight,"Ink bounds track vertical placement")
Check(top.lines[0].y=0 And top.lines[1].y=16,"Alignment does not mutate another retained box")
Check(vertical.LayoutBox(80,80,TEXT_ALIGN_LEFT,0,0,"...",TEXT_ALIGN_BOTTOM)=bottom,"Vertical alignment participates in cache identity")
Check(vertical.LayoutBox(80,80)=top,"Default alignment remains top")
Local capped:TParagraphLayout=vertical.LayoutBox(80,80,TEXT_ALIGN_CENTER,0,1,"...",TEXT_ALIGN_BOTTOM)
Check(capped.truncated And capped.lines[0].y=64 And capped.lines[0].text="one...","Align the retained ellipsized content")
Local emptyBox:TParagraphLayout=PrepareText("",font).LayoutBox(80,80,TEXT_ALIGN_LEFT,0,0,"...",TEXT_ALIGN_BOTTOM)
Check(emptyBox.contentY=0 And emptyBox.boundsY=0 And emptyBox.height=0,"Empty boxes keep zero content bounds")
caught=False
Try
	vertical.LayoutBox(80,80,TEXT_ALIGN_LEFT,0,0,"...",99)
Catch error:Object
	caught=True
End Try
Check(caught,"Invalid vertical alignment rejected")
Print "Max2D paragraph layout tests passed"
