SuperStrict
Framework Max2D.Core
Import BRL.StandardIO
Import Text.Unibreak

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Local font:TImageFont=TImageFont.DefaultFont()
Local plain:TPreparedText=PrepareText("one two",font)
Local ordinary:TParagraphLayout=plain.Layout(80)
Check(Not plain.interaction And Not ordinary.interaction,"Ordinary text has no source mapping")
Check(Not ordinary.lines[0].sourceOffsets And Not ordinary.lines[0].carets,"Ordinary lines allocate no interaction arrays")
Local rejected:Int
Try
	ordinary.HitTest(0,0)
Catch error:Object
	rejected=True
End Try
Check(rejected,"Interaction requires opt-in")
For Local mode:ETextBreakMode=EachIn [ETextBreakMode.Basic,ETextBreakMode.Unicode]
	Local source:String="  one~t  two  ~r~n~nthree~n"
	Local prepared:TPreparedText=PrepareText(source,font,mode,"",True)
	Local layout:TParagraphLayout=prepared.Layout(80)
	Check(layout.lines.Length=4,"Source mapping preserves blank and trailing lines")
	Check(layout.interactionBuilds=0 And Not layout.lines[0].carets,"Caret geometry remains lazy")
	Check(layout.HitTest(-10,0).sourceOffset=2,"Leading whitespace maps to first visible source character")
	Check(layout.HitTest(32,0).sourceOffset=8,"Collapsed tab/space maps to next word start")
	Check(layout.HitTest(56,0).sourceOffset=11,"Line end excludes trailing spaces")
	Check(layout.CaretAt(16).lineIndex=2,"Source offset finds line after blank paragraph")
	Check(layout.CaretAt(source.Length).lineIndex=3,"Trailing blank line maps to source end")
	Local wrapped:TParagraphLayout=prepared.Layout(24,TEXT_ALIGN_RIGHT,20)
	Check(wrapped.HitTest(0,20).sourceOffset=8,"Wrapped word uses its original source offset")
	Check(wrapped.interactionBuilds=1 And Not wrapped.lines[0].carets,"Hit-test builds only the target line")
	Local builds:Long=font.layoutBuilds
	Local caret:TTextCaret=wrapped.HitTest(0,20)
	For Local i:Int=0 Until 10000
		Check(wrapped.HitTest(0,20)=caret,"Repeated hit tests return cached caret objects")
		wrapped.CaretAt(8)
	Next
	Check(wrapped.interactionBuilds=1 And font.layoutBuilds=builds,"Warm queries never reshape or rebuild")
	Local centered:TParagraphLayout=prepared.LayoutBox(80,120,TEXT_ALIGN_CENTER,20,0,"...",TEXT_ALIGN_BOTTOM)
	Local point:TTextCaret=centered.CaretAt(2)
	Check(point.x=centered.lines[0].x And point.y=centered.contentY,"Caret includes horizontal and vertical alignment")
	Local box:TParagraphLayout=prepared.LayoutBox(56,16)
	Check(box.lines[0].text="one...","Truncation fixture")
	Check(box.HitTest(100,0).sourceOffset=5,"Ellipsis maps to truncation boundary, not hidden text")
	Check(box.CaretAt(source.Length).sourceOffset=5,"Hidden source clamps to last visible source stop")
	Local empty:TParagraphLayout=prepared.LayoutBox(56,0)
	Check(empty.HitTest(0,0)=Null And empty.CaretAt(0)=Null,"No visible lines return no caret")
	prepared.ClearCache()
	Check(wrapped.HitTest(0,20)=caret,"Held interaction survives layout cache eviction")
Next
Local empty:TParagraphLayout=PrepareText("",font,ETextBreakMode.Auto,"",True).Layout(20)
Check(empty.HitTest(0,0)=Null,"Empty source returns no caret")
Local unicode:TParagraphLayout=PrepareText("a"+Chr($301)+" b",font,ETextBreakMode.Unicode,"",True).Layout(100)
unicode.PrepareInteraction()
For Local point:TTextCaret=EachIn unicode.lines[0].carets
	Check(point.sourceOffset<>1,"Combining sequence has no interior caret")
Next
Local soft:TParagraphLayout=PrepareText("co"+Chr($ad)+"operate",font,ETextBreakMode.Unicode,"",True).Layout(24)
Check(soft.lines[0].text="co-","Discretionary hyphen fixture")
Check(soft.HitTest(24,0).sourceOffset=3,"Inserted hyphen maps to source soft hyphen end")
Local unbroken:TParagraphLayout=PrepareText("co"+Chr($ad)+"operate",font,ETextBreakMode.Unicode,"",True).Layout(200)
Check(unbroken.HitTest(16,0).sourceOffset=3,"Removed soft hyphen preserves following offsets")
Local zwsp:TParagraphLayout=PrepareText("ab"+Chr($200b)+"cd",font,ETextBreakMode.Unicode,"",True).Layout(16)
Check(zwsp.HitTest(0,16).sourceOffset=3,"Zero-width break preserves source offsets")
Local units:Short[]=[$d83d:Short,$dc69:Short,$200d:Short,$d83d:Short,$dcbb:Short]
Local emoji:String=String.FromShorts(units,units.Length)
Local sequence:TParagraphLayout=PrepareText(emoji,font,ETextBreakMode.Unicode,"",True).Layout(100)
sequence.PrepareInteraction()
For Local point:TTextCaret=EachIn sequence.lines[0].carets
	Check(point.sourceOffset=0 Or point.sourceOffset=emoji.Length,"No interior emoji ZWJ or surrogate caret")
Next
Local provider:TTextBoundaryProvider=GetTextBoundaryProvider()
RegisterTextBoundaryProvider(Null)
Check(soft.CaretAt(3).sourceOffset=3,"Interaction survives provider removal")
RegisterTextBoundaryProvider(provider)
Print "Max2D paragraph interaction tests passed"

' CPU submission test: no graphics context or texture access is needed.
Type TCountingDrawLayout Extends TTextLayout
	Field draws:Int
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float) Override
		draws:+1
	End Method
End Type
Local visible:TParagraphLayout=New TParagraphLayout
visible.lineSpacing=20;visible.minLineY=-4;visible.maxLineY=18
visible.lines=New TParagraphLine[100]
For Local i:Int=0 Until visible.lines.Length
	Local line:TParagraphLine=New TParagraphLine
	line.y=i*20;line.layout=New TCountingDrawLayout
	line.layout.height=16;line.layout.boundsY=-4;line.layout.boundsHeight=22
	visible.lines[i]=line
Next
visible.DrawVisible(New TMax2DGraphics,0,-200,200,220)
For Local i:Int=0 Until visible.lines.Length
	Local expected:Int=(i=10 Or i=11)
	Check(TCountingDrawLayout(visible.lines[i].layout).draws=expected,"Visible drawing culls lines but retains ink overhang")
Next
Print "Max2D visible paragraph submission tests passed"

Local selected:TParagraphLayout=PrepareText("one two three",font,ETextBreakMode.Basic,"",True).Layout(56)
Local rectangles:TTextSelectionRect[]=selected.SelectionRects(1,10)
Check(rectangles.Length=2,"Selection spans wrapped lines")
Check(rectangles[0].x=8 And rectangles[0].width=48 And rectangles[0].height=16,"First selection line geometry")
Check(rectangles[1].x=0 And rectangles[1].width=16 And rectangles[1].y=16,"Last selection line geometry")
Check(selected.SelectionRects(10,1)=rectangles,"Reversed range shares normalized cache")
Local builds:Int=selected.selectionBuilds
For Local i:Int=0 Until 10000
	Check(selected.SelectionRects(1,10)=rectangles,"Selection result reused")
Next
Check(selected.selectionBuilds=builds,"Warm selection does not rebuild")
Check(selected.SelectionRects(4,4).Length=0,"Collapsed selection is empty")
Check(rectangles[0].width=48,"Held selection survives cache replacement")
Local lazy:TParagraphLayout=PrepareText("one two three",font,ETextBreakMode.Basic,"",True).Layout(24)
Local band:TTextSelectionRect[]=lazy.SelectionRectsVisible(0,13,16,32)
Check(band.Length=1 And band[0].lineIndex=1,"Visible selection only returns intersecting lines")
Check(lazy.interactionBuilds=1 And Not lazy.lines[0].carets And Not lazy.lines[2].carets,"Off-screen selected lines remain lazy")
Local fitted:TParagraphLayout=PrepareText("one two three",font,ETextBreakMode.Basic,"",True).LayoutBox(56,16)
Check(fitted.SelectionRects(3,13).Length=0,"Hidden text and synthetic ellipsis are not selected")
Check(fitted.SelectionRects(0,13)[0].width=24,"Selection excludes synthetic ellipsis width")
Local combined:TParagraphLayout=PrepareText("a"+Chr($301)+"b",font,ETextBreakMode.Unicode,"",True).Layout(100)
Local cluster:TTextSelectionRect[]=combined.SelectionRects(1,2)
Check(cluster.Length=1 And cluster[0].sourceStart=0 And cluster[0].sourceEnd=2,"Partial grapheme selection expands to cluster edges")
Local blankSelection:TParagraphLayout=PrepareText("a~n~nb",font,ETextBreakMode.Basic,"",True).Layout(100)
Check(blankSelection.SelectionRects(1,3).Length=0,"Invisible newlines do not create rectangles")
Print "Max2D selection geometry tests passed"

Local hyphenSelection:TTextSelectionRect[]=soft.SelectionRects(2,3)
Check(hyphenSelection.Length=1 And hyphenSelection[0].x=16 And hyphenSelection[0].width=8,"Displayed discretionary hyphen selects its source soft hyphen")
