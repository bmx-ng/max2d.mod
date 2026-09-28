Rem
bbdoc: Selection granularity used by the optional text selection controller.
End Rem
Enum ETextSelectionUnit
	Character
	Word
	Line
End Enum

Rem
bbdoc: Optional input-independent controller for character, word and visual-line selection.
about: Supply paragraph-local pointer positions and monotonic milliseconds. Begin gestures only inside the text viewport; route move/up events while captured. Drawing, OS capture, focus loss and edge scrolling belong to the host. Fields describing selection are read-only; configure clickInterval, clickDistance and tripleClickEnabled as needed.
End Rem
Type TTextSelectionController
	Field layout:TParagraphLayout
	Field anchor:Int,active:Int,dragging:Int
	Field anchorAffinity:ETextCaretAffinity,activeAffinity:ETextCaretAffinity
	Field unit:ETextSelectionUnit=ETextSelectionUnit.Character
	Field clickInterval:Int=500
	Field clickDistance:Float=4
	Field tripleClickEnabled:Int=True
	Private
	Field anchorStart:Int,anchorEnd:Int
	Field previousTime:Long
	Field previousX:Float,previousY:Float
	Field downX:Float,downY:Float
	Field clicks:Int,havePrevious:Int
	Public

	Rem
	bbdoc: Attaches an interactive layout. Reflow of the same prepared source preserves selection; a different source resets it.
	End Rem
	Method SetLayout(value:TParagraphLayout)
		If value And Not value.interaction Then Throw "Max2D: selection controller requires interactive text"
		If value=layout Then Return
		Local sameSource:Int
		If value And layout Then sameSource=value.interaction=layout.interaction
		layout=value;havePrevious=False
		If Not sameSource Then
			anchor=0;active=0;anchorStart=0;anchorEnd=0;dragging=False
			anchorAffinity=ETextCaretAffinity.Following;activeAffinity=ETextCaretAffinity.Following
			unit=ETextSelectionUnit.Character
		End If
	End Method

	Method SelectionStart:Int()
		Return Min(anchor,active)
	End Method
	Method SelectionEnd:Int()
		Return Max(anchor,active)
	End Method

	Rem
	bbdoc: Begins a selection gesture. Optional clickCount=1/2/3 overrides automatic click counting for toolkit integrations.
	about: Automatic counting uses configurable time and distance thresholds, cycles after a triple click, and resets after a drag. It does not query platform preferences. Returns False when no caret is available.
	End Rem
	Method PointerDown:Int(x:Float,y:Float,timeMillis:Long,clickCount:Int=0)
		If clickInterval<0 Or IsNan(clickDistance) Or IsInf(clickDistance) Or clickDistance<0 Then Throw "Max2D: invalid selection click thresholds"
		If clickCount<0 Or clickCount>3 Then Throw "Max2D: click count must be 0 through 3"
		If Not layout Then Return False
		Local caret:TTextCaret=layout.HitTest(x,y)
		If Not caret Then CancelDrag();Return False
		Local dx:Double=Double(x)-previousX,dy:Double=Double(y)-previousY
		Local limit:Int=2
		If tripleClickEnabled Then limit=3
		If clickCount Then
			clicks=Min(limit,clickCount)
		Else If havePrevious And timeMillis>=previousTime And timeMillis-previousTime<=clickInterval And dx*dx+dy*dy<=Double(clickDistance)*clickDistance And clicks<limit Then
			clicks:+1
		Else
			clicks=1
		End If
		previousTime=timeMillis;previousX=x;previousY=y;havePrevious=True
		downX=x;downY=y;dragging=True
		unit=ETextSelectionUnit.Character
		Local range:STextRange
		Select clicks
			Case 2
				unit=ETextSelectionUnit.Word
				range=layout.WordAtPoint(x,y)
			Case 3
				unit=ETextSelectionUnit.Line
				range=layout.LineRange(caret.lineIndex)
		End Select
		If range.valid Then
			anchorStart=range.sourceStart;anchorEnd=range.sourceEnd
		Else
			anchorStart=caret.sourceOffset;anchorEnd=caret.sourceOffset
		End If
		anchor=anchorStart;active=anchorEnd
		anchorAffinity=caret.affinity;activeAffinity=caret.affinity
		If range.valid Then anchorAffinity=ETextCaretAffinity.Following;activeAffinity=ETextCaretAffinity.Preceding
		Return True
	End Method

	Rem
	bbdoc: Extends a captured selection. Word/line dragging retains the entire initial unit when reversing direction.
	End Rem
	Method PointerMove(x:Float,y:Float)
		If Not dragging Or Not layout Then Return
		Local caret:TTextCaret=layout.HitTest(x,y)
		If Not caret Then Return
		Local dx:Double=Double(x)-downX,dy:Double=Double(y)-downY
		If dx*dx+dy*dy>Double(clickDistance)*clickDistance Then havePrevious=False
		If unit=ETextSelectionUnit.Character Then
			active=caret.sourceOffset;activeAffinity=caret.affinity
			Return
		End If
		Local range:STextRange
		If unit=ETextSelectionUnit.Word Then range=layout.WordAtPoint(x,y) Else range=layout.LineRange(caret.lineIndex)
		If Not range.valid Then Return
		If range.sourceEnd<=anchorStart Then
			anchor=anchorEnd;active=range.sourceStart
			anchorAffinity=ETextCaretAffinity.Preceding;activeAffinity=ETextCaretAffinity.Following
		Else If range.sourceStart>=anchorEnd Then
			anchor=anchorStart;active=range.sourceEnd
			anchorAffinity=ETextCaretAffinity.Following;activeAffinity=ETextCaretAffinity.Preceding
		Else
			anchor=anchorStart;active=anchorEnd
			anchorAffinity=ETextCaretAffinity.Following;activeAffinity=ETextCaretAffinity.Preceding
		End If
	End Method

	Method PointerUp()
		dragging=False
	End Method

	Rem
	bbdoc: Ends capture and resets click counting, preserving selection. Call on focus loss or cancellation.
	End Rem
	Method CancelDrag()
		dragging=False;havePrevious=False
	End Method
End Type
