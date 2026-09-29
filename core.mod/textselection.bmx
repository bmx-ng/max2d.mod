
Rem
bbdoc: Selection granularity used by the optional text selection controller.
End Rem
Enum ETextSelectionUnit

	Rem
	bbdoc: Extends selection between supported text-cluster caret stops.
	End Rem
	Character

	Rem
	bbdoc: Extends selection in whole words.
	End Rem
	Word

	Rem
	bbdoc: Extends selection in whole visual lines.
	End Rem
	Line
End Enum

Rem
bbdoc: Optional input-independent controller for character, word and visual-line selection.
about: Supply paragraph-local pointer positions and monotonic milliseconds. Begin gestures only inside the text viewport; route move/up events while captured. Drawing, OS capture, focus loss and edge scrolling belong to the host. Fields describing selection are read-only; configure clickInterval, clickDistance and tripleClickEnabled as needed.
End Rem
Type TTextSelectionController

	Rem
	bbdoc: Retained text layout associated with this object.
	End Rem
	Field layout:TParagraphLayout

	Rem
	bbdoc: Fixed selection endpoint in original UTF-16 source coordinates; maintained by the controller.
	End Rem
	Field anchor:Int

	Rem
	bbdoc: Moving selection endpoint in original UTF-16 source coordinates; maintained by the controller.
	End Rem
	Field active:Int

	Rem
	bbdoc: Whether a pointer selection gesture is active; maintained by the controller.
	End Rem
	Field dragging:Int

	Rem
	bbdoc: Visual-side affinity of the fixed selection endpoint.
	End Rem
	Field anchorAffinity:ETextCaretAffinity

	Rem
	bbdoc: Visual-side affinity of the moving selection endpoint.
	End Rem
	Field activeAffinity:ETextCaretAffinity

	Rem
	bbdoc: Current selection granularity: character, word or visual line.
	End Rem
	Field unit:ETextSelectionUnit=ETextSelectionUnit.Character

	Rem
	bbdoc: Maximum interval between repeated clicks in milliseconds.
	End Rem
	Field clickInterval:Int=500

	Rem
	bbdoc: Maximum repeated-click distance in paragraph-local units.
	End Rem
	Field clickDistance:Float=4

	Rem
	bbdoc: Whether automatic triple-click gestures select a whole visual line.
	End Rem
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
	param: Interactive layout to attach, or Null to detach.
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

	Rem
	bbdoc: Returns the smaller selection endpoint as a UTF-16 source offset.
	End Rem
	Method SelectionStart:Int()
		Return Min(anchor,active)
	End Method

	Rem
	bbdoc: Returns the larger selection endpoint as an exclusive UTF-16 source offset.
	End Rem
	Method SelectionEnd:Int()
		Return Max(anchor,active)
	End Method

	Rem
	bbdoc: Begins a selection gesture. Optional clickCount=1/2/3 overrides automatic click counting for toolkit integrations.
	param: Horizontal paragraph-local pointer coordinate.
	param: Vertical paragraph-local pointer coordinate.
	param: Monotonic pointer-event time in milliseconds.
	param: Explicit click count from 1 to 3, or zero for automatic counting.
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
	param: Horizontal paragraph-local pointer coordinate.
	param: Vertical paragraph-local pointer coordinate.
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

	Rem
	bbdoc: Ends the active selection drag while preserving the selection and click history.
	End Rem
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
