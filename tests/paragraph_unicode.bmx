SuperStrict
Framework Max2D.Core
Import Text.Unibreak
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

' Deterministic advances, independent of installed fonts or missing glyphs.
Type TBoundaryTestFont Extends TImageFont
	Method Layout:TTextLayout(text:String) Override
		Local result:TTextLayout=New TTextLayout
		result.glyphs=New TPositionedGlyph[0];result.height=16
		For Local i:Int=0 Until text.Length
			Local ch:Int=text[i]
			If ch=$ad Or ch=$200b Or ch=$2060 Or ch=$200d Or ch=$301 Then Continue
			If ch>=$dc00 And ch<=$dfff Then Continue
			result.width:+8
		Next
		Return result
	End Method
End Type
Type TCountingBoundaryProvider Extends TTextBoundaryProvider
	Field inner:TTextBoundaryProvider
	Field calls:Int
	Field requestedMaps:ETextBoundaryMaps
	Method Name:String() Override
		Return inner.Name()
	End Method
	Method Analyze:TTextBoundaries(text:String,language:String="",maps:ETextBoundaryMaps=ETextBoundaryMaps.All) Override
		calls:+1
		requestedMaps=maps
		Return inner.Analyze(text,language,maps)
	End Method
End Type
Local font:TImageFont=New TBoundaryTestFont
Local cjk:String=Chr($4e00)+Chr($4e8c)+Chr($4e09)+Chr($56db)
Local prepared:TPreparedText=PrepareText(cjk,font)
Check(prepared.breakMode=ETextBreakMode.Unicode,"Import selects Unicode automatically")
Local layout:TParagraphLayout=prepared.Layout(16)
Check(layout.lines.Length=2 And layout.lines[0].text=cjk[..2] And layout.lines[1].text=cjk[2..],"CJK wraps without inserted spaces")
Check(PrepareText(cjk,font,ETextBreakMode.Basic).Layout(16).lines.Length=1,"Basic mode remains selectable")
Local provider:TTextBoundaryProvider=GetTextBoundaryProvider()
RegisterTextBoundaryProvider(Null)
Check(PrepareText(cjk,font).breakMode=ETextBreakMode.Basic,"Automatic mode falls back without provider")
Check(prepared.Layout(8).lines.Length=4,"Prepared Unicode boundaries survive provider removal")
Local caught:Int
Try
	PrepareText(cjk,font,ETextBreakMode.Unicode)
Catch error:Object
	caught=True
End Try
Check(caught,"Explicit unavailable Unicode mode throws")
RegisterTextBoundaryProvider(provider)
Check(PrepareText("one two three",font).Layout(56).lines[0].text="one two","Ordinary word wrapping remains familiar")
Check(PrepareText("a"+Chr($a0)+"b",font).Layout(8).lines.Length=1,"Nonbreaking space prohibits wrapping")
Check(PrepareText("a"+Chr($2060)+"b",font).Layout(8).lines.Length=1,"Word joiner prohibits wrapping")
Check(PrepareText("a"+Chr($200b)+"b",font).Layout(8).lines.Length=2,"Zero-width space permits wrapping")
Check(PrepareText("a"+Chr($200b)+"b",font).Layout(16).lines[0].text="ab","Zero-width separator is not rendered")
Local shy:TPreparedText=PrepareText("ab"+Chr($ad)+"cd",font)
Check(shy.Layout(32).lines[0].text="abcd","Unbroken soft hyphen is invisible")
Check(shy.Layout(24).lines[0].text="ab-" And shy.Layout(24).lines[1].text="cd","Chosen soft hyphen renders a hyphen")
Check(PrepareText("a"+Chr($2028)+"b"+Chr($85),font).Layout(200).lines.Length=3,"Unicode mandatory breaks and trailing empty line")
Check(PrepareText("  a~t b  ~n~n",font).Layout(200).lines.Length=3,"Collapsed spaces and explicit empty paragraphs")
Local combined:String="a"+Chr($301)
Check(PrepareText(combined+"b",font).Layout(8).lines.Length=1,"No unsafe emergency split inside word")
Local box:TParagraphLayout=prepared.LayoutBox(24,16,TEXT_ALIGN_LEFT,0,1,".")
Check(box.lines[0].text=cjk[..2]+".","Unicode ellipsis removes break segments instead of the whole CJK line")
Check(prepared.LayoutBox(24,16,TEXT_ALIGN_LEFT,0,1,".")=box,"Unicode box cache identity")
Check(PrepareText("",font).Layout(10).lines.Length=0,"Empty Unicode input")
Check(PrepareText(" ",font).Layout(10).lines.Length=1,"Whitespace-only Unicode input")
Local punctuated:String=cjk[..1]+Chr($3008)+cjk[1..2]+Chr($3009)+cjk[2..3]
Local punctuation:TParagraphLayout=PrepareText(punctuated,font).Layout(24)
For Local line:TParagraphLine=EachIn punctuation.lines
	Check(Not line.text.EndsWith(Chr($3008)) And Not line.text.StartsWith(Chr($3009)),"CJK punctuation stays on the appropriate side of a break")
Next
Local emojiUnits:Short[]=[$d83d:Short,$dc69:Short,$200d:Short,$d83d:Short,$dcbb:Short]
Local emoji:String=String.FromShorts(emojiUnits,emojiUnits.Length)
Check(PrepareText(emoji+" x",font).Layout(8).lines[0].text=emoji,"Overwide emoji ZWJ sequence stays intact")
Local counter:TCountingBoundaryProvider=New TCountingBoundaryProvider
counter.inner=provider
RegisterTextBoundaryProvider(counter)
Local retained:TPreparedText=PrepareText(cjk,font)
Check(counter.requestedMaps=(ETextBoundaryMaps.Line | ETextBoundaryMaps.Grapheme),"Paragraphs request only line and grapheme maps")
Check(retained.boundaries.wordBreaks=Null,"Paragraphs do not allocate unused word boundaries")
retained.Layout(8);retained.Layout(16);retained.LayoutBox(24,16)
Check(counter.calls=1,"Boundary analysis runs once during preparation, not reflow")
RegisterTextBoundaryProvider(provider)
Print "Max2D Unicode paragraph tests passed"
