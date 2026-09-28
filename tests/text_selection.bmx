SuperStrict
Framework Max2D.Core
Import Text.Unibreak
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Type TWordCountingProvider Extends TTextBoundaryProvider
	Field inner:TTextBoundaryProvider
	Field wordCalls:Int
	Method Name:String() Override
		Return inner.Name()
	End Method
	Method Analyze:TTextBoundaries(text:String,language:String="",maps:ETextBoundaryMaps=ETextBoundaryMaps.All) Override
		If (maps & ETextBoundaryMaps.Word)<>ETextBoundaryMaps.None Then
			Check(maps=ETextBoundaryMaps.Word,"Lazy word request asks only for words")
			wordCalls:+1
		End If
		Return inner.Analyze(text,language,maps)
	End Method
End Type
Local font:TImageFont=TImageFont.DefaultFont()
Local provider:TTextBoundaryProvider=GetTextBoundaryProvider()
Local counted:TWordCountingProvider=New TWordCountingProvider
counted.inner=provider
RegisterTextBoundaryProvider(counted)
Local prepared:TPreparedText=PrepareText("one two three",font,ETextBreakMode.Auto,"",True)
Local layout:TParagraphLayout=prepared.Layout(200)
Local controller:TTextSelectionController=New TTextSelectionController
controller.SetLayout(layout)
Check(controller.PointerDown(41,0,1000),"First click has target")
Check(controller.unit=ETextSelectionUnit.Character And controller.anchor=5 And controller.active=5,"First click places caret")
controller.PointerUp()
Check(Not prepared.interaction.wordBreaks And counted.wordCalls=0,"Single clicks never request words")
controller.PointerDown(41,0,1100)
Check(controller.unit=ETextSelectionUnit.Word And controller.SelectionStart()=4 And controller.SelectionEnd()=7,"Double click selects word")
Check(counted.wordCalls=1,"First word selection requests one map")
controller.PointerMove(97,0)
Check(controller.SelectionStart()=4 And controller.SelectionEnd()=13,"Word drag extends through word end")
controller.PointerMove(1,0)
Check(controller.anchor=7 And controller.active=0,"Reversed word drag retains initial word")
controller.PointerMove(41,0)
Check(controller.SelectionStart()=4 And controller.SelectionEnd()=7,"Returning to initial word restores its extent")
controller.PointerUp()
controller.PointerDown(41,0,1200)
Check(controller.unit=ETextSelectionUnit.Character,"Drag resets click sequence")
controller.PointerUp()
controller.PointerDown(41,0,1300)
controller.PointerUp()
controller.PointerDown(41,0,1400)
Check(controller.unit=ETextSelectionUnit.Line And controller.SelectionStart()=0 And controller.SelectionEnd()=13,"Triple click selects visual line")
controller.PointerUp()
controller.PointerDown(41,0,1500)
Check(controller.unit=ETextSelectionUnit.Character,"Fourth click starts a new sequence")
controller.CancelDrag()
controller.PointerDown(41,0,1600,2)
Check(controller.unit=ETextSelectionUnit.Word,"Toolkit click count overrides detection")
Local oldAnchor:Int=controller.anchor,oldActive:Int=controller.active
controller.SetLayout(prepared.Layout(56))
Check(controller.anchor=oldAnchor And controller.active=oldActive And controller.dragging,"Reflow preserves source selection and capture")
controller.PointerMove(1,16)
Check(controller.SelectionEnd()=13,"Word drag works after reflow")
controller.CancelDrag()
Check(Not controller.dragging,"Cancellation releases logical capture")
controller.PointerDown(1,16,2000,3)
Check(controller.SelectionStart()=8 And controller.SelectionEnd()=13,"Triple click selects wrapped visual line")
controller.PointerMove(1,0)
Check(controller.SelectionStart()=0 And controller.SelectionEnd()=13,"Line drag extends by visual lines")
controller.PointerUp()
Local last:STextRange=layout.WordAtPoint(23,0)
Check(last.sourceStart=0 And last.sourceEnd=3,"Right half of final character still selects that word")
Local space:STextRange=layout.WordAtPoint(28,0)
Check(space.sourceStart=3 And space.sourceEnd=4,"Whitespace is a selectable segment")
RegisterTextBoundaryProvider(Null)
Check(layout.WordAt(5).sourceStart=4,"Captured word provider survives unregister")
Check(counted.wordCalls=1,"Reflow and repeated word queries reuse original word map")
RegisterTextBoundaryProvider(provider)
For Local mode:ETextBreakMode=EachIn [ETextBreakMode.Basic,ETextBreakMode.Unicode]
	Local p:TParagraphLayout=PrepareText("  one~t two, three",font,mode,"",True).Layout(200)
	Local word:STextRange=p.WordAtPoint(23,0)
	Check(word.sourceStart=2 And word.sourceEnd=5,"Word selection uses original normalized-source offsets")
	Local punctuation:STextRange=p.WordAt(10)
	Check(punctuation.sourceStart=10 And punctuation.sourceEnd=11,"Punctuation has its own range")
	Check(p.WordAt(999).sourceEnd=17,"End offset chooses final segment")
Next
Local apostrophe:TParagraphLayout=PrepareText("can't",font,ETextBreakMode.Unicode,"",True).Layout(100)
Check(apostrophe.WordAt(2).sourceEnd=5,"Unicode apostrophe joins word")
Local marks:TParagraphLayout=PrepareText("a"+Chr($301)+" b",font,ETextBreakMode.Unicode,"",True).Layout(100)
Check(marks.WordAt(1).sourceStart=0 And marks.WordAt(1).sourceEnd=2,"Word ranges respect combining clusters")
Local blank:TParagraphLayout=PrepareText("one~n~ntwo",font,ETextBreakMode.Auto,"",True).Layout(200)
Check(blank.LineRange(1).valid And blank.LineRange(1).sourceStart=4 And blank.LineRange(1).sourceEnd=4,"Blank visual line is a valid empty range")
controller.SetLayout(blank)
Check(controller.anchor=0 And controller.active=0 And Not controller.dragging,"Different source resets controller")
controller.PointerDown(0,16,3000,3)
Check(controller.SelectionStart()=4 And controller.SelectionEnd()=4,"Triple click on blank line is empty")
controller.SetLayout(PrepareText("",font,ETextBreakMode.Auto,"",True).Layout(100))
Check(Not controller.PointerDown(0,0,4000),"Empty paragraph has no pointer target")
Check(Not controller.layout.WordAt(0).valid,"Empty source has no word")
controller.SetLayout(Null)
Check(Not controller.PointerDown(0,0,5000),"Detached controller is inactive")
Print "Max2D text selection controller tests passed"

controller.SetLayout(layout)
controller.PointerDown(1,0,10000);controller.PointerUp()
controller.PointerDown(1,0,11000)
Check(controller.unit=ETextSelectionUnit.Character,"Click timeout starts a fresh sequence")
controller.PointerUp()
controller.PointerDown(41,0,11100)
Check(controller.unit=ETextSelectionUnit.Character,"Distant click starts a fresh sequence")
controller.PointerUp()
controller.PointerDown(41,0,10900)
Check(controller.unit=ETextSelectionUnit.Character,"Backward timestamp resets click count")
controller.PointerUp()
controller.tripleClickEnabled=False
controller.PointerDown(41,0,11000);controller.PointerUp()
Check(controller.unit=ETextSelectionUnit.Word,"Disabled triple-click still permits double-click")
controller.PointerDown(41,0,11100)
Check(controller.unit=ETextSelectionUnit.Character,"Disabled triple-click cycles after double-click")
controller.CancelDrag()
Local lineOnly:TPreparedText=PrepareText("one two",font,ETextBreakMode.Auto,"",True)
controller.SetLayout(lineOnly.Layout(100))
controller.tripleClickEnabled=True
controller.PointerDown(1,0,12000,3)
Check(Not lineOnly.interaction.wordBreaks,"Explicit line selection does not request word boundaries")
Print "Max2D selection click policy tests passed"

Local truncated:TParagraphLayout=PrepareText("one two three",font,ETextBreakMode.Auto,"",True).LayoutBox(24,16)
Local synthetic:STextRange=truncated.WordAtPoint(8,0)
Check(synthetic.valid And synthetic.sourceStart=synthetic.sourceEnd,"Ellipsis-only line does not select a hidden word")
