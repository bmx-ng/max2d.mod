
Rem
bbdoc: Aligns text to the left edge of its layout box.
End Rem
Const TEXT_ALIGN_LEFT:Int=0

Rem
bbdoc: Centres text horizontally in its layout box.
End Rem
Const TEXT_ALIGN_CENTER:Int=1

Rem
bbdoc: Aligns text to the right edge of its layout box.
End Rem
Const TEXT_ALIGN_RIGHT:Int=2

Rem
bbdoc: Aligns fitted text to the top of its layout box.
End Rem
Const TEXT_ALIGN_TOP:Int=0

Rem
bbdoc: Centres fitted text vertically in its layout box.
End Rem
Const TEXT_ALIGN_MIDDLE:Int=1

Rem
bbdoc: Aligns fitted text to the bottom of its layout box.
End Rem
Const TEXT_ALIGN_BOTTOM:Int=2

Rem
bbdoc: One retained paragraph line, with its offset and shaped layout.
End Rem
Type TParagraphLine

	Rem
	bbdoc: Text represented by this layout or imported object.
	End Rem
	Field text:String

	Rem
	bbdoc: Horizontal line origin in paragraph-local logical coordinates.
	End Rem
	Field x:Float

	Rem
	bbdoc: Vertical line origin in paragraph-local logical coordinates.
	End Rem
	Field y:Float

	Rem
	bbdoc: Retained text layout associated with this object.
	End Rem
	Field layout:TTextLayout

	Rem
	bbdoc: Cached candidate source ends used when fitting an overflow marker.
	End Rem
	Field trimEnds:Int[]

	Rem
	bbdoc: Cached display text used by overflow fitting.
	End Rem
	Field trimText:String

	Rem
	bbdoc: Mapping from visible UTF-16 boundaries to original-source offsets.
	End Rem
	Field sourceOffsets:Int[]

	Rem
	bbdoc: Lazily built valid caret stops for this visual line.
	End Rem
	Field carets:TTextCaret[]

	Rem
	bbdoc: Lazily built bidirectional cell and caret mappings for this line.
	End Rem
	Field bidiCarets:TBidiTextInteraction

	Rem
	bbdoc: Visible source-text length before any synthetic overflow marker.
	End Rem
	Field sourceContentLength:Int

	Rem
	bbdoc: Cached glyph colours and background rectangles for this line.
	End Rem
	Field paint:TTextPaint
End Type

Rem
bbdoc: A reusable composite text layout. Inspect lines for individual glyph layouts.
about: width is the widest line advance; boxWidth is the requested wrapping width. Fields should be treated as read-only. The inherited glyphs array is empty because each line retains its font-specific layout.
End Rem
Type TParagraphLayout Extends TTextLayout

	Rem
	bbdoc: Visual paragraph lines in top-to-bottom order; treat as read-only.
	End Rem
	Field lines:TParagraphLine[]

	Rem
	bbdoc: Requested layout box width in logical text units.
	End Rem
	Field boxWidth:Float

	Rem
	bbdoc: Requested distance between line origins; zero uses natural metrics.
	End Rem
	Field lineSpacing:Float

	Rem
	bbdoc: Horizontal text alignment.
	End Rem
	Field alignment:Int

	Rem
	bbdoc: Whether lines require individual vertical metrics.
	End Rem
	Field variableLines:Int

	Rem
	bbdoc: Vertical alignment within a fitted text box.
	End Rem
	Field verticalAlignment:Int

	Rem
	bbdoc: Vertical offset applied to content by box alignment.
	End Rem
	Field contentY:Float

	Rem
	bbdoc: Requested box height, or -1 when height is unconstrained.
	End Rem
	Field boxHeight:Float=-1

	Rem
	bbdoc: Maximum visible lines requested for box layout; zero means no separate limit.
	End Rem
	Field maxLines:Int

	Rem
	bbdoc: Number of lines before box truncation.
	End Rem
	Field totalLineCount:Int

	Rem
	bbdoc: Whether the fitted box omits some source text.
	End Rem
	Field truncated:Int

	Rem
	bbdoc: Overflow marker used when content is truncated.
	End Rem
	Field ellipsis:String

	Rem
	bbdoc: Optional source mapping retained for text hit testing and selection.
	End Rem
	Field interaction:TTextSourceMap

	Rem
	bbdoc: Number of line-interaction cache builds, useful for profiling.
	End Rem
	Field interactionBuilds:Int

	Rem
	bbdoc: Minimum logical y extent of paragraph content.
	End Rem
	Field minLineY:Float

	Rem
	bbdoc: Maximum logical y extent of paragraph content.
	End Rem
	Field maxLineY:Float

	Rem
	bbdoc: Cached selection rectangles; maintained by selection queries.
	End Rem
	Field selectionCache:TTextSelectionRect[]

	Rem
	bbdoc: Inclusive source endpoint used by the cached selection query.
	End Rem
	Field selectionStart:Int

	Rem
	bbdoc: Exclusive source endpoint used by the cached selection query.
	End Rem
	Field selectionEnd:Int

	Rem
	bbdoc: Whether cached selection rectangles match a previous query.
	End Rem
	Field selectionCached:Int

	Rem
	bbdoc: Top of the vertical band used by the cached selection query.
	End Rem
	Field selectionTop:Float

	Rem
	bbdoc: Bottom of the vertical band used by the cached selection query.
	End Rem
	Field selectionBottom:Float

	Rem
	bbdoc: Number of selection-rectangle cache builds.
	End Rem
	Field selectionBuilds:Int

	Rem
	bbdoc: Builds and caches caret geometry for an explicitly interactive paragraph.
	about: HitTest and CaretAt build only the lines needed; this method prewarms all lines. Call it beforehand to avoid first-query shaping work. Coordinates are paragraph-local logical units; no camera or drawing transform is applied.
	End Rem
	Method PrepareInteraction()
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to use caret geometry"
		For Local i:Int=0 Until lines.Length
			PrepareLineInteraction(i)
		Next
	End Method

	Rem
	bbdoc: Builds and caches caret information for one paragraph line when needed.
	param: Zero-based index.
	End Rem
	Method PrepareLineInteraction(index:Int)
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to use caret geometry"
		If lines[index].carets Then Return
		Local bidi:TBidiTextLayout=TBidiTextLayout(lines[index].layout)
		If bidi Then
			lines[index].bidiCarets=TBidiTextInteraction.Create(bidi,lines[index],index,interaction)
			lines[index].carets=lines[index].bidiCarets.items
		Else
			lines[index].carets=interaction.BuildCarets(lines[index],index).items
		End If
		interactionBuilds:+1
	End Method

	Rem
	bbdoc: Returns the nearest supported caret to a paragraph-local point, or Null for no visible lines.
	param: Horizontal paragraph-local pointer coordinate.
	param: Vertical paragraph-local pointer coordinate.
	about: Returned caret objects are cached and read-only. Outside points clamp to the nearest line/edge. Source offsets refer to the original UTF-16 string, including normalization differences.
	End Rem
	Method HitTest:TTextCaret(x:Float,y:Float)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then Throw "Max2D: hit-test coordinates must be finite"
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to use caret geometry"
		If Not lines.Length Then Return Null
		Local index:Int,lastLine:Int=lines.Length-1
		While index<lastLine
			Local middle:Int=(index+lastLine+1)/2
			If lines[middle].y<=y Then index=middle Else lastLine=middle-1
		Wend
		If index+1<lines.Length And y>=lines[index].y+lines[index].layout.height Then
			Local below:Float=y-lines[index].y-lines[index].layout.height
			Local above:Float=lines[index+1].y-y
			If above<=below Then index:+1
		End If
		PrepareLineInteraction(index)
		If lines[index].bidiCarets Then Return lines[index].bidiCarets.HitTest(x)
		Local points:TTextCaret[]=lines[index].carets
		If Not points.Length Then Return Null
		Local first:Int,last:Int=points.Length-1
		Local reverse:Int=points[last].x<points[0].x
		While first<last
			Local middle:Int=(first+last)/2
			If (Not reverse And points[middle].x<x) Or (reverse And points[middle].x>x) Then
				first=middle+1
			Else
				last=middle
			End If
		Wend
		If first>0 And Abs(points[first-1].x-x)<=Abs(points[first].x-x) Then first:-1
		Return points[first]
	End Method

	Rem
	bbdoc: Returns the nearest visible supported caret for an original UTF-16 source offset.
	param: Offset in the original UTF-16 source string.
	param: Whether a shared wrap-boundary offset selects the following visual line.
	param: Which visual side to prefer when a source offset has two bidi caret positions.
	about: Offsets inside clusters or omitted text snap to a supported stop. preferNextLine chooses the later line when equally close; False chooses the earlier one. affinity chooses the following or preceding logical run at a bidi boundary. No per-query allocation or shaping is performed after preparation.
	End Rem
	Method CaretAt:TTextCaret(sourceOffset:Int,preferNextLine:Int=True,affinity:ETextCaretAffinity=ETextCaretAffinity.Following)
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to use caret geometry"
		If Not lines.Length Then Return Null
		sourceOffset=Max(0,Min(interaction.sourceLength,sourceOffset))
		Local nearest:Int,distance:Int=$7fffffff
		For Local i:Int=0 Until lines.Length
			Local delta:Int=SourceDistance(lines[i],sourceOffset)
			If delta<distance Or (delta=distance And preferNextLine) Then nearest=i;distance=delta
		Next
		PrepareLineInteraction(nearest)
		Local best:TTextCaret=LineCaretAt(lines[nearest],sourceOffset,affinity)
		distance=$7fffffff
		If best Then distance=Abs(best.sourceOffset-sourceOffset)
		For Local i:Int=0 Until lines.Length
			If i=nearest Or SourceDistance(lines[i],sourceOffset)>distance Then Continue
			PrepareLineInteraction(i)
			Local candidate:TTextCaret=LineCaretAt(lines[i],sourceOffset,affinity)
			If Not candidate Then Continue
			Local delta:Int=Abs(candidate.sourceOffset-sourceOffset)
			Local preferred:Int=Not best
			If best Then preferred=(preferNextLine And i>best.lineIndex) Or (Not preferNextLine And i<best.lineIndex)
			If delta<distance Or (delta=distance And preferred) Then best=candidate;distance=delta
		Next
		Return best
	End Method

	Rem
	bbdoc: Returns the source word segment containing an offset; word analysis is lazy.
	param: Offset in the original UTF-16 source string.
	about: At a boundary the following segment is chosen; the source end chooses the preceding segment. Whitespace and punctuation are selectable segments. Unicode rules come from the captured provider; Basic mode groups ASCII word characters/non-ASCII code points and ASCII whitespace, with individual ASCII punctuation.
	End Rem
	Method WordAt:STextRange(sourceOffset:Int)
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to select words"
		Return interaction.WordAt(sourceOffset)
	End Method

	Rem
	bbdoc: Returns the word under a paragraph-local point, using cluster coverage rather than the nearest insertion point.
	param: Horizontal paragraph-local pointer coordinate.
	param: Vertical paragraph-local pointer coordinate.
	End Rem
	Method WordAtPoint:STextRange(x:Float,y:Float)
		Local result:STextRange
		Local caret:TTextCaret=HitTest(x,y)
		If Not caret Then Return result
		If lines[caret.lineIndex].bidiCarets Then
			Local cell:TBidiTextCell=lines[caret.lineIndex].bidiCarets.CellAt(x)
			If cell And cell.first<cell.last Then Return WordAt(cell.first)
			Return WordAt(Max(0,caret.sourceOffset-1))
		End If
		Local points:TTextCaret[]=lines[caret.lineIndex].carets
		If points.Length<2 Then Return LineRange(caret.lineIndex)
		Local first:Int,last:Int=points.Length-1
		Local reverse:Int=points[last].x<points[0].x
		While first<last
			Local middle:Int=(first+last+1)/2
			If (Not reverse And points[middle].x<=x) Or (reverse And points[middle].x>=x) Then first=middle Else last=middle-1
		Wend
		first=Min(first,points.Length-2)
		' Synthetic trailing glyphs have no source span: choose the preceding span.
		While first>0 And points[first].sourceOffset=points[first+1].sourceOffset
			first:-1
		Wend
		If points[first].sourceOffset=points[first+1].sourceOffset Then Return LineRange(caret.lineIndex)
		Return WordAt(points[first].sourceOffset)
	End Method

	Rem
	bbdoc: Returns the visible source range of a wrapped visual line, excluding newline separators and synthetic ellipsis.
	param: Zero-based visual line index.
	End Rem
	Method LineRange:STextRange(lineIndex:Int)
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to select lines"
		Local result:STextRange
		If lineIndex<0 Or lineIndex>=lines.Length Then Return result
		Local offsets:Int[]=lines[lineIndex].sourceOffsets
		result.sourceStart=offsets[0];result.sourceEnd=offsets[offsets.Length-1];result.valid=True
		Return result
	End Method

	Rem
	bbdoc: Returns the original-source range of the visual line nearest a local point.
	param: Horizontal paragraph-local pointer coordinate.
	param: Vertical paragraph-local pointer coordinate.
	End Rem
	Method LineAtPoint:STextRange(x:Float,y:Float)
		Local caret:TTextCaret=HitTest(x,y)
		If caret Then Return LineRange(caret.lineIndex)
		Local result:STextRange
		Return result
	End Method

	Rem
	bbdoc: Returns the distance from a source offset to a line's source range.
	param: Prepared visual paragraph line.
	param: Offset in the original UTF-16 source string.
	End Rem
	Function SourceDistance:Int(line:TParagraphLine,offset:Int)
		Local first:Int=line.sourceOffsets[0],last:Int=line.sourceOffsets[line.sourceOffsets.Length-1]
		If offset<first Then Return first-offset
		If offset>last Then Return offset-last
		Return 0
	End Function

	Rem
	bbdoc: Finds the closest supported caret on a line for a source offset and affinity.
	param: Prepared visual paragraph line.
	param: Offset in the original UTF-16 source string.
	param: Which visual side to prefer when a source offset has two bidi caret positions.
	End Rem
	Function LineCaretAt:TTextCaret(line:TParagraphLine,offset:Int,affinity:ETextCaretAffinity=ETextCaretAffinity.Following)
		If line.bidiCarets Then Return line.bidiCarets.CaretAt(offset,affinity)
		Local points:TTextCaret[]=line.carets
		If Not points.Length Then Return Null
		Local first:Int,last:Int=points.Length-1
		While first<last
			Local middle:Int=(first+last)/2
			If points[middle].sourceOffset<offset Then first=middle+1 Else last=middle
		Wend
		If first>0 And Abs(points[first-1].sourceOffset-offset)<=Abs(points[first].sourceOffset-offset) Then first:-1
		Return points[first]
	End Function

	Rem
	bbdoc: Returns cached selection rectangles for a half-open original-source range.
	param: Inclusive start offset in the original UTF-16 source.
	param: Exclusive end offset in the original UTF-16 source.
	about: Reversed ranges are accepted. Partial clusters expand outward. Empty ranges, invisible separators and synthetic ellipsis do not add rectangles. Results are read-only and remain valid after subsequent queries.
	End Rem
	Method SelectionRects:TTextSelectionRect[](sourceStart:Int,sourceEnd:Int)
		Return SelectionRectsVisible(sourceStart,sourceEnd,contentY,contentY+height)
	End Method

	Rem
	bbdoc: Returns selection rectangles only for lines intersecting a local vertical band.
	param: Inclusive start offset in the original UTF-16 source.
	param: Exclusive end offset in the original UTF-16 source.
	param: Inclusive top of the visible band in paragraph-local coordinates.
	param: Exclusive bottom of the visible band in paragraph-local coordinates.
	about: Rectangles retain full line height; use viewport clipping at the edges. Only intersecting selected lines build caret geometry. The most recent range/band result is cached, independently of drawing colour.
	End Rem
	Method SelectionRectsVisible:TTextSelectionRect[](sourceStart:Int,sourceEnd:Int,top:Float,bottom:Float)
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to use selection geometry"
		If IsNan(top) Or IsInf(top) Or IsNan(bottom) Or IsInf(bottom) Then Throw "Max2D: selection bounds must be finite"
		sourceStart=Max(0,Min(interaction.sourceLength,sourceStart))
		sourceEnd=Max(0,Min(interaction.sourceLength,sourceEnd))
		If sourceStart>sourceEnd Then
			Local swap:Int=sourceStart;sourceStart=sourceEnd;sourceEnd=swap
		End If
		If selectionCached And sourceStart=selectionStart And sourceEnd=selectionEnd And top=selectionTop And bottom=selectionBottom Then Return selectionCache
		Local rectangles:TList=New TList
		If sourceStart<sourceEnd And top<bottom Then
			For Local i:Int=0 Until lines.Length
				Local line:TParagraphLine=lines[i]
				If line.y>=bottom Or line.y+line.layout.height<=top Then Continue
				If line.sourceOffsets[0]>=sourceEnd Or line.sourceOffsets[line.sourceOffsets.Length-1]<=sourceStart Then Continue
				PrepareLineInteraction(i)
				Local rectangle:TTextSelectionRect
				If line.bidiCarets Then
					For Local cell:TBidiTextCell=EachIn line.bidiCarets.cells
						If cell.first>=cell.last Or cell.first>=sourceEnd Or cell.last<=sourceStart Then
							rectangle=Null;Continue
						End If
						Local left:Float=cell.left.x,right:Float=cell.right.x
						If right<=left Then Continue
						If rectangle And Abs(rectangle.x+rectangle.width-left)<0.001 Then
							rectangle.width=right-rectangle.x
							rectangle.sourceStart=Min(rectangle.sourceStart,cell.first);rectangle.sourceEnd=Max(rectangle.sourceEnd,cell.last)
						Else
							rectangle=New TTextSelectionRect
							rectangle.x=left;rectangle.width=right-left;rectangle.y=line.y;rectangle.height=line.layout.height
							rectangle.lineIndex=i;rectangle.sourceStart=cell.first;rectangle.sourceEnd=cell.last;rectangles.AddLast(rectangle)
						End If
					Next
					Continue
				End If
				For Local j:Int=1 Until line.carets.Length
					Local first:TTextCaret=line.carets[j-1],last:TTextCaret=line.carets[j]
					If first.sourceOffset>=last.sourceOffset Or first.sourceOffset>=sourceEnd Or last.sourceOffset<=sourceStart Then Continue
					Local left:Float=Min(first.x,last.x),right:Float=Max(first.x,last.x)
					If right<=left Then Continue
					If Not rectangle Then
						rectangle=New TTextSelectionRect
						rectangle.x=left;rectangle.width=right-left
						rectangle.y=line.y;rectangle.height=line.layout.height;rectangle.lineIndex=i
						rectangle.sourceStart=first.sourceOffset;rectangle.sourceEnd=last.sourceOffset
						rectangles.AddLast(rectangle)
					Else
						right=Max(right,rectangle.x+rectangle.width)
						rectangle.x=Min(left,rectangle.x);rectangle.width=right-rectangle.x
						rectangle.sourceEnd=last.sourceOffset
					End If
				Next
			Next
		End If
		Local result:TTextSelectionRect[]=New TTextSelectionRect[rectangles.Count()]
		Local index:Int
		For Local rectangle:TTextSelectionRect=EachIn rectangles
			result[index]=rectangle;index:+1
		Next
		selectionCache=result;selectionCached=True
		selectionStart=sourceStart;selectionEnd=sourceEnd;selectionTop=top;selectionBottom=bottom
		selectionBuilds:+1
		Return result
	End Method

	Rem
	bbdoc: Builds or refreshes cached glyph colours and background rectangles for one line.
	param: Zero-based index.
	End Rem
	Method PrepareLinePaint:TTextPaint(index:Int)
		Local line:TParagraphLine=lines[index]
		If Not interaction Or Not interaction.colorSpans.Length Then
			line.paint=Null
			Return Null
		End If
		If line.paint And line.paint.revision=interaction.paintRevision Then Return line.paint
		Local paint:TTextPaint=New TTextPaint
		paint.revision=interaction.paintRevision
		paint.glyphColors=New TTextColorSpan[line.layout.glyphs.Length]
		For Local i:Int=0 Until line.layout.glyphs.Length
			Local offset:Int=line.layout.glyphs[i].sourceOffset
			If offset<0 Or offset>=line.text.Length Then Throw "Max2D: font layout does not expose glyph source clusters for colouring"
			If offset<line.sourceContentLength Then paint.glyphColors[i]=interaction.ColorAt(line.sourceOffsets[offset])
		Next
		Local backgrounds:TList=New TList
		If interaction.hasBackgrounds Then
			PrepareLineInteraction(index)
			Local previous:TTextBackground
			If line.bidiCarets Then
				For Local cell:TBidiTextCell=EachIn line.bidiCarets.cells
					If cell.first>=cell.last Then previous=Null;Continue
					Local color:TTextColorSpan=interaction.ColorAt(cell.first,True)
					If Not color Then previous=Null;Continue
					Local left:Float=cell.left.x,right:Float=cell.right.x
					If right<=left Then Continue
					If previous And previous.color=color And Abs(previous.x+previous.width-left)<0.001 Then
						previous.width=right-previous.x
					Else
						previous=New TTextBackground
						previous.x=left;previous.y=line.y;previous.width=right-left;previous.height=line.layout.height;previous.color=color
						backgrounds.AddLast(previous)
					End If
				Next
			Else
				For Local i:Int=1 Until line.carets.Length
					Local first:TTextCaret=line.carets[i-1],last:TTextCaret=line.carets[i]
					If first.sourceOffset>=last.sourceOffset Then Continue
					Local color:TTextColorSpan=interaction.ColorAt(first.sourceOffset,True)
					If Not color Then previous=Null;Continue
					Local left:Float=Min(first.x,last.x),right:Float=Max(first.x,last.x)
					If right<=left Then Continue
					If previous And previous.color=color And (Abs(previous.x+previous.width-left)<0.001 Or Abs(right-previous.x)<0.001) Then
						right=Max(right,previous.x+previous.width);previous.x=Min(left,previous.x);previous.width=right-previous.x
					Else
						previous=New TTextBackground
						previous.x=left;previous.y=line.y;previous.width=right-left;previous.height=line.layout.height;previous.color=color
						backgrounds.AddLast(previous)
					End If
				Next
			End If
		End If
		paint.backgrounds=New TTextBackground[backgrounds.Count()]
		Local i:Int
		For Local rectangle:TTextBackground=EachIn backgrounds
			paint.backgrounds[i]=rectangle;i:+1
		Next
		line.paint=paint
		Return paint
	End Method

	Rem
	bbdoc: Draws span backgrounds on lines intersecting a paragraph-local vertical band.
	param: Drawing canvas whose state and rendering context are used.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Inclusive top of the visible band in paragraph-local coordinates.
	param: Exclusive bottom of the visible band in paragraph-local coordinates.
	End Rem
	Method DrawBackgroundsVisible(canvas:TMax2DGraphics,x:Float,y:Float,top:Float,bottom:Float)
		If IsNan(top) Or IsInf(top) Or IsNan(bottom) Or IsInf(bottom) Then Throw "Max2D: visible text bounds must be finite"
		If Not interaction Or Not interaction.hasBackgrounds Or bottom<=top Then Return
		For Local i:Int=0 Until lines.Length
			If lines[i].y>=bottom Or lines[i].y+lines[i].layout.height<=top Then Continue
			Local paint:TTextPaint=PrepareLinePaint(i)
			If paint Then paint.DrawBackgrounds(canvas,x,y)
		Next
	End Method

	Rem
	bbdoc: Draws a line using the current colour, line width and transform.
	param: Drawing canvas whose state and rendering context are used.
	param: Zero-based index.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	End Rem
	Method DrawLine(canvas:TMax2DGraphics,index:Int,x:Float,y:Float)
		Local line:TParagraphLine=lines[index]
		Local paint:TTextPaint=PrepareLinePaint(index)
		Local tx:Float=x+line.x*canvas.state.ix+line.y*canvas.state.iy,ty:Float=y+line.x*canvas.state.jx+line.y*canvas.state.jy
		If paint Then line.layout.DrawColored(canvas,tx,ty,paint.glyphColors) Else line.layout.Draw(canvas,tx,ty)
	End Method

	Rem
	bbdoc: Draws only lines intersecting a paragraph-local vertical band.
	param: Drawing canvas whose state and rendering context are used.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Inclusive top of the visible band in paragraph-local coordinates.
	param: Exclusive bottom of the visible band in paragraph-local coordinates.
	param: Whether to draw span backgrounds before glyphs.
	about: Use a viewport as well to clip partially visible glyphs. top and bottom are local coordinates before drawing transforms, and bottom is exclusive. Layout and source mapping still cover the entire paragraph.
	End Rem
	Method DrawVisible(canvas:TMax2DGraphics,x:Float,y:Float,top:Float,bottom:Float,backgrounds:Int=True)
		If IsNan(top) Or IsInf(top) Or IsNan(bottom) Or IsInf(bottom) Then Throw "Max2D: visible text bounds must be finite"
		If bottom<=top Then Return
		If backgrounds Then DrawBackgroundsVisible(canvas,x,y,top,bottom)
		Local first:Int,last:Int=lines.Length
		If variableLines Then
			first=LineAfter(top-maxLineY,True)
			last=LineAfter(bottom-minLineY,False)
		Else If lineSpacing>0 Then
			first=Int(Max(0.0,Min(Float(last),Floor((top-contentY-maxLineY)/lineSpacing)+1)))
			last=Int(Max(0.0,Min(Float(last),Ceil((bottom-contentY-minLineY)/lineSpacing))))
		End If
		For Local i:Int=first Until last
			Local line:TParagraphLine=lines[i]
			Local lineTop:Float=line.y+Min(0.0,line.layout.boundsY)
			Local lineBottom:Float=line.y+Max(line.layout.height,line.layout.boundsY+line.layout.boundsHeight)
			If lineTop>=bottom Or lineBottom<=top Then Continue
			DrawLine(canvas,i,x,y)
		Next
	End Method

	Rem
	bbdoc: Finds a line by its vertical extent using a binary search.
	param: Vertical coordinate.
	param: Whether a line starting exactly at the supplied y is skipped.
	End Rem
	Method LineAfter:Int(y:Float,strict:Int)
		Local first:Int,last:Int=lines.Length
		While first<last
			Local middle:Int=(first+last)/2
			If lines[middle].y<y Or (strict And lines[middle].y=y) Then first=middle+1 Else last=middle
		Wend
		Return first
	End Method

	Rem
	bbdoc: Draws every paragraph line using the supplied canvas state.
	param: Drawing canvas whose state and rendering context are used.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float) Override
		DrawBackgroundsVisible(canvas,x,y,contentY,contentY+height)
		For Local i:Int=0 Until lines.Length
			DrawLine(canvas,i,x,y)
		Next
	End Method

End Type

Rem
bbdoc: Prepared word or break segments for one hard-break-delimited paragraph.
End Rem
Type TPreparedTextBlock

	Rem
	bbdoc: Prepared words or Unicode break segments in source order.
	End Rem
	Field words:String[]

	Rem
	bbdoc: Cached logical advance widths of prepared segments.
	End Rem
	Field widths:Float[]

	Rem
	bbdoc: Cached logical spacing between prepared segments.
	End Rem
	Field gaps:Float[]

	Rem
	bbdoc: Text inserted when joining prepared segments.
	End Rem
	Field joiner:String=" "

	Rem
	bbdoc: Inclusive UTF-16 source offset.
	End Rem
	Field sourceStart:Int

	Rem
	bbdoc: Offsets of prepared segments within normalized text.
	End Rem
	Field wordOffsets:Int[]

	Rem
	bbdoc: Optional resolved bidirectional data for this paragraph block.
	End Rem
	Field bidi:TParagraphBidiBlock

	Rem
	bbdoc: Joins a segment range into display text, including an optional discretionary hyphen.
	param: Inclusive start index of the requested range.
	param: Exclusive end index of the requested range.
	param: Whether to show a discretionary hyphen when the range ends at its break.
	End Rem
	Method Text:String(first:Int,last:Int,hyphenate:Int=True)
		Local value:String=joiner.Join(words[first..last])
		If joiner="" Then
			value=value.Replace(Chr($ad),"").Replace(Chr($200b),"")
			value=TrimSpaces(value)
			If hyphenate And last<words.Length And words[last-1].EndsWith(Chr($ad)) Then value:+"-"
		End If
		Return value
	End Method

	Rem
	bbdoc: Removes leading and trailing ordinary spaces from a string.
	param: Value to read, convert or store.
	End Rem
	Function TrimSpaces:String(value:String)
		Local first:Int,last:Int=value.Length
		While first<last And value[first]=32
			first:+1
		Wend
		While last>first And value[last-1]=32
			last:-1
		Wend
		Return value[first..last]
	End Function

End Type

Rem
bbdoc: Prepared words and measurements for reusable paragraph reflow.
about: Ordinary spaces and tabs collapse; explicit newlines are retained. Optional providers add Unicode break opportunities. Font settings must remain unchanged while this object is used.
End Rem
Type TPreparedText

	Rem
	bbdoc: Font used to shape and draw this text.
	End Rem
	Field font:TImageFont

	Rem
	bbdoc: Snapshot of font spans applied to the prepared source.
	End Rem
	Field fontSpans:TTextFontSpan[]

	Rem
	bbdoc: Optional provider used to resolve bidirectional ordering.
	End Rem
	Field bidiProvider:TTextBidiProvider

	Rem
	bbdoc: Requested base text direction.
	End Rem
	Field direction:ETextDirection

	Rem
	bbdoc: Requested line-breaking mode.
	End Rem
	Field breakMode:ETextBreakMode

	Rem
	bbdoc: Language tag passed to text providers.
	End Rem
	Field language:String

	Rem
	bbdoc: Optional provider used for Unicode line, word and grapheme boundaries.
	End Rem
	Field boundaryProvider:TTextBoundaryProvider

	Rem
	bbdoc: Boundary maps prepared by the selected Unicode provider.
	End Rem
	Field boundaries:TTextBoundaries

	Rem
	bbdoc: Source text after whitespace and line-break normalization.
	End Rem
	Field normalizedText:String

	Rem
	bbdoc: Optional source mapping retained for text hit testing and selection.
	End Rem
	Field interaction:TTextSourceMap

	Rem
	bbdoc: Prepared blocks separated by mandatory paragraph breaks.
	End Rem
	Field blocks:TPreparedTextBlock[]

	Rem
	bbdoc: Logical line height used when no explicit spacing is supplied.
	End Rem
	Field naturalLineHeight:Float

	Rem
	bbdoc: Logical advance of an ordinary space in the default font.
	End Rem
	Field spaceWidth:Float

	Rem
	bbdoc: Number of fitted paragraph-box layouts built.
	End Rem
	Field boxBuilds:Long

	Rem
	bbdoc: Number of paragraph reflows performed instead of returned from cache.
	End Rem
	Field reflowBuilds:Long

	Rem
	bbdoc: Retained layout cache; use cache-control methods rather than editing it directly.
	End Rem
	Field cache:TList=New TList

	Rem
	bbdoc: Maximum number of retained paragraph layouts.
	End Rem
	Field cacheLimit:Int=8

	Rem
	bbdoc: Prepares reusable text, font metrics and optional Unicode, bidi and interaction data.
	param: Text to lay out, measure or draw.
	param: Default font for the prepared source; must not be Null.
	param: Basic, Unicode or automatically selected line-breaking behaviour.
	param: Language tag used by the text provider; empty uses its default.
	param: Whether to retain source mappings for hit testing and selection.
	param: Requested paragraph direction; Auto lets the bidi provider determine it.
	End Rem
	Function Create:TPreparedText(text:String,font:TImageFont,breakMode:ETextBreakMode=ETextBreakMode.Auto,language:String="",interactive:Int=False,direction:ETextDirection=ETextDirection.Auto)
		If Not font Then Throw "Max2D: paragraph font is null"
		Local result:TPreparedText=New TPreparedText
		result.font=font
		If direction<>ETextDirection.Auto And direction<>ETextDirection.Disabled And direction<>ETextDirection.LeftToRight And direction<>ETextDirection.RightToLeft Then Throw "Max2D: invalid paragraph direction"
		result.direction=direction
		If direction<>ETextDirection.Disabled Then result.bidiProvider=GetTextBidiProvider()
		If direction<>ETextDirection.Auto And direction<>ETextDirection.Disabled And Not result.bidiProvider Then Throw "Max2D: explicit direction requires an imported bidi provider"
		If breakMode<>ETextBreakMode.Auto And breakMode<>ETextBreakMode.Basic And breakMode<>ETextBreakMode.Unicode Then Throw "Max2D: invalid text break mode"
		If breakMode<>ETextBreakMode.Basic Then result.boundaryProvider=GetTextBoundaryProvider()
		If breakMode=ETextBreakMode.Unicode And Not result.boundaryProvider Then Throw "Max2D: Unicode text boundaries require an imported provider (such as Text.Unibreak)"
		result.breakMode=ETextBreakMode.Basic
		If result.boundaryProvider Then result.breakMode=ETextBreakMode.Unicode
		result.language=language
		result.naturalLineHeight=font.Layout("").height
		result.spaceWidth=font.Layout(" ").width
		If result.boundaryProvider Then
			result.PrepareUnicode(text)
			If result.bidiProvider Then result.PrepareBidi()
			If interactive Then result.interaction=TTextSourceMap.Create(text,result)
			Return result
		End If
		Local paragraphs:String[]=New String[0]
		If text.Length Then paragraphs=text.Replace("~r~n","~n").Replace("~r","~n").Replace("~t"," ").Split("~n")
		result.blocks=New TPreparedTextBlock[paragraphs.Length]
		For Local i:Int=0 Until paragraphs.Length
			Local block:TPreparedTextBlock=New TPreparedTextBlock
			Local words:TList=New TList
			For Local word:String=EachIn paragraphs[i].Split(" ")
				If word.Length Then words.AddLast(word)
			Next
			block.words=New String[words.Count()];block.widths=New Float[words.Count()];block.gaps=New Float[words.Count()]
			Local index:Int
			For Local word:String=EachIn words
				block.words[index]=word;block.widths[index]=font.Layout(word).width;block.gaps[index]=result.spaceWidth
				index:+1
			Next
			result.blocks[i]=block
		Next
		If result.bidiProvider Then result.PrepareBidi()
		If interactive Then result.interaction=TTextSourceMap.Create(text,result)
		Return result
	End Function

	Rem
	bbdoc: Resolves bidirectional paragraph information using the selected provider.
	End Rem
	Method PrepareBidi()
		For Local block:TPreparedTextBlock=EachIn blocks
			block.bidi=TParagraphBidiBlock.Create(block,bidiProvider,direction)
		Next
	End Method

	Rem
	bbdoc: Splits normalized text using the selected Unicode boundary provider.
	param: Text to lay out, measure or draw.
	End Rem
	Method PrepareUnicode(text:String)
		Local parts:TList=New TList
		For Local part:String=EachIn text.Replace("~r~n","~n").Replace("~r","~n").Replace("~t"," ").Split(" ")
			If part.Length Then parts.AddLast(part)
		Next
		Local collapsed:String[]=New String[parts.Count()]
		Local p:Int
		For Local part:String=EachIn parts
			collapsed[p]=part;p:+1
		Next
		normalizedText=" ".Join(collapsed)
		boundaries=boundaryProvider.Analyze(normalizedText,language,ETextBoundaryMaps.Line | ETextBoundaryMaps.Grapheme)
		If Not boundaries Or boundaries.lineBreaks.Length<>normalizedText.Length+1 Or boundaries.graphemeBreaks.Length<>normalizedText.Length+1 Then Throw "Max2D: invalid boundary provider result"
		Local preparedBlocks:TList=New TList,segments:TList=New TList
		Local start:Int,lastMandatory:Int
		For Local offset:Int=1 To normalizedText.Length
			Local mandatory:Int=boundaries.lineBreaks[offset]=TEXT_BOUNDARY_MANDATORY
			If offset<normalizedText.Length And Not mandatory And (Not boundaries.lineBreaks[offset] Or Not boundaries.graphemeBreaks[offset]) Then Continue
			Local finish:Int=offset
			If mandatory Then
				Local ch:Int=normalizedText[offset-1]
				If ch=10 Or ch=11 Or ch=12 Or ch=$85 Or ch=$2028 Or ch=$2029 Then finish:-1
			End If
			Local segment:String=normalizedText[start..finish]
			If TPreparedTextBlock.TrimSpaces(segment).Length Then segments.AddLast(segment)
			start=offset
			If mandatory Or offset=normalizedText.Length Then
				preparedBlocks.AddLast(UnicodeBlock(segments))
				segments=New TList
				lastMandatory=mandatory
			End If
		Next
		If lastMandatory Then preparedBlocks.AddLast(UnicodeBlock(segments))
		' A whitespace-only, nonempty input still represents one blank line.
		If Not normalizedText.Length And text.Length Then preparedBlocks.AddLast(UnicodeBlock(segments))
		blocks=New TPreparedTextBlock[preparedBlocks.Count()]
		p=0
		For Local block:TPreparedTextBlock=EachIn preparedBlocks
			blocks[p]=block;p:+1
		Next
	End Method

	Rem
	bbdoc: Builds a prepared block from Unicode break segments.
	param: Prepared break segments in source order.
	End Rem
	Method UnicodeBlock:TPreparedTextBlock(segments:TList)
		Local block:TPreparedTextBlock=New TPreparedTextBlock
		block.joiner=""
		block.words=New String[segments.Count()];block.widths=New Float[segments.Count()];block.gaps=New Float[segments.Count()]
		Local i:Int
		For Local segment:String=EachIn segments
			block.words[i]=segment;i:+1
		Next
		For i=0 Until block.words.Length
			block.widths[i]=font.Layout(block.Text(i,i+1,False)).width
			If block.words[i].EndsWith(" ") Then block.gaps[i]=spaceWidth
		Next
		Return block
	End Method

	Rem
	bbdoc: Replaces optional foreground/background spans without reflowing held layouts.
	param: Source ranges and styles to copy; later overlaps take precedence.
	about: Requires source mapping (interactive=True at preparation). Null clears spans. Input spans are copied. All layouts from this prepared text see the new paints lazily, including layouts held after cache eviction.
	End Rem
	Method SetColorSpans(spans:TTextColorSpan[])
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to use source colour spans"
		interaction.SetColorSpans(spans)
	End Method

	Rem
	bbdoc: Replaces font spans and clears the reflow cache. Previously returned layouts retain their original fonts and geometry.
	param: Source ranges and styles to copy; later overlaps take precedence.
	about: Requires source mapping (interactive=True). Ranges are copied; later spans win. Font objects must remain unchanged while layouts are held. Null restores the default font. Adjacent identical fonts shape together; colour spans do not split shaping runs.
	End Rem
	Method SetFontSpans(spans:TTextFontSpan[])
		If Not interaction Then Throw "Max2D: prepare text with interactive=True to use font spans"
		Local copy:TTextFontSpan[]=New TTextFontSpan[spans.Length]
		For Local i:Int=0 Until spans.Length
			Local span:TTextFontSpan=spans[i]
			If Not span Or Not span.font Then Throw "Max2D: null text font span or font"
			If span.sourceStart<0 Or span.sourceEnd<span.sourceStart Or span.sourceEnd>interaction.sourceLength Then Throw "Max2D: invalid font span range"
			copy[i]=TTextFontSpan.Create(span.sourceStart,span.sourceEnd,span.font)
		Next
		fontSpans=copy
		ClearCache()
	End Method

	Rem
	bbdoc: Returns the font selected by the last matching font span at a source offset.
	param: Offset in the original UTF-16 source string.
	End Rem
	Method FontAt:TImageFont(offset:Int)
		If interaction.graphemes Then
			While offset>0 And Not interaction.graphemes[offset]
				offset:-1
			Wend
		Else If offset>0 And offset<interaction.sourceLength Then
			Local ch:Int=interaction.sourceText[offset],before:Int=interaction.sourceText[offset-1]
			If ch>=$dc00 And ch<=$dfff And before>=$d800 And before<=$dbff Then offset:-1
		End If
		For Local i:Int=fontSpans.Length-1 To 0 Step -1
			If offset>=fontSpans[i].sourceStart And offset<fontSpans[i].sourceEnd Then Return fontSpans[i].font
		Next
		Return font
	End Method

	Rem
	bbdoc: Shapes the visible segment range using its font spans and bidi information.
	param: Prepared paragraph block containing the source segments.
	param: Inclusive start index of the requested range.
	param: Exclusive end index of the requested range.
	param: Text to lay out, measure or draw.
	End Rem
	Method ShapeBlock:TTextLayout(block:TPreparedTextBlock,first:Int,last:Int,text:String)
		If block.bidi Then
			Local offsets:Int[]
			If fontSpans.Length Then offsets=interaction.LineOffsets(block,first,last,text)
			Return block.bidi.Shape(Self,first,last,text,offsets)
		End If
		If Not fontSpans.Length Then Return font.Layout(text)
		Return TStyledTextLayout.Create(Self,text,interaction.LineOffsets(block,first,last,text),text.Length)
	End Method

	Rem
	bbdoc: Shapes a shortened line and its overflow marker with the original source styles.
	param: Text to lay out, measure or draw.
	param: Original layout or line supplying source context and metrics.
	param: Length of actual source text before any appended overflow marker.
	End Rem
	Method ShapeFitted:TTextLayout(text:String,original:TParagraphLine,contentLength:Int)
		Local bidi:TBidiTextLayout=TBidiTextLayout(original.layout)
		If Not fontSpans.Length And Not bidi Then Return font.Layout(text)
		Local offsets:Int[]
		If fontSpans.Length Then
			offsets=New Int[text.Length+1]
			For Local i:Int=0 To text.Length
				offsets[i]=original.sourceOffsets[Min(i,contentLength)]
			Next
		End If
		If bidi Then Return TBidiTextLayout.CreateBidi(Self,text,offsets,contentLength,bidi.paragraph,bidi.paragraphStart,Min(contentLength,bidi.paragraphLength),True)
		Return TStyledTextLayout.Create(Self,text,offsets,contentLength)
	End Method

	Rem
	bbdoc: Sets the maximum number of retained paragraph layouts; zero disables caching.
	param: Maximum retained layouts; zero disables layout caching.
	End Rem
	Method SetCacheLimit(limit:Int)
		If limit<0 Then Throw "Max2D: paragraph cache limit must not be negative"
		cacheLimit=limit
		While cache.Count()>limit
			cache.RemoveFirst()
		Wend
	End Method

	Rem
	bbdoc: Discards cached paragraph layouts while keeping the prepared source.
	End Rem
	Method ClearCache()
		cache.Clear()
	End Method

	Rem
	bbdoc: Wraps prepared text to a width and reuses a matching cached layout when available.
	param: Maximum line width in logical text units.
	param: Horizontal text alignment, such as TEXT_ALIGN_LEFT.
	param: Distance between line origins; zero uses the natural line height.
	End Rem
	Method Layout:TParagraphLayout(maxWidth:Float,alignment:Int=TEXT_ALIGN_LEFT,lineSpacing:Float=0)
		If IsNan(maxWidth) Or IsInf(maxWidth) Or maxWidth<0 Then Throw "Max2D: paragraph width must be finite and nonnegative"
		If IsNan(lineSpacing) Or IsInf(lineSpacing) Or lineSpacing<0 Then Throw "Max2D: line spacing must be finite and nonnegative"
		If alignment<TEXT_ALIGN_LEFT Or alignment>TEXT_ALIGN_RIGHT Then Throw "Max2D: invalid text alignment"
		If lineSpacing=0 Then lineSpacing=naturalLineHeight
		Local found:TParagraphLayout
		For Local entry:TParagraphLayout=EachIn cache
			If entry.boxHeight=-1 And entry.boxWidth=maxWidth And entry.alignment=alignment And entry.lineSpacing=lineSpacing Then
				found=entry
				Exit
			End If
		Next
		If found Then
			cache.Remove(found);cache.AddLast(found)
			Return found
		End If
		Local result:TParagraphLayout=New TParagraphLayout
		result.interaction=interaction
		result.variableLines=fontSpans.Length>0
		result.boxWidth=maxWidth;result.alignment=alignment;result.lineSpacing=lineSpacing
		result.glyphs=New TPositionedGlyph[0]
		Local lines:TList=New TList
		For Local block:TPreparedTextBlock=EachIn blocks
			If Not block.words.Length Then
				Local blank:TParagraphLine=AddLine(lines,"",font.Layout(""))
				If interaction Then blank.sourceOffsets=[interaction.offsets[block.sourceStart]]
				Continue
			End If
			Local start:Int
			While start<block.words.Length
				Local finish:Int=start+1
				Local estimate:Float=block.widths[start]
				While finish<block.words.Length
					Local nextWidth:Float=estimate+block.gaps[finish-1]+block.widths[finish]
					If nextWidth>maxWidth Then Exit
					estimate=nextWidth;finish:+1
				Wend
				Local text:String=block.Text(start,finish)
				Local shaped:TTextLayout=ShapeBlock(block,start,finish,text)
				' Whole-line shaping is authoritative. Word advances provide a quick
				' starting point, not a promise that shaping is additive across spaces.
				While shaped.width>maxWidth And finish>start+1
					finish:-1;text=block.Text(start,finish);shaped=ShapeBlock(block,start,finish,text)
				Wend
				While finish<block.words.Length
					Local candidate:String=block.Text(start,finish+1)
					Local nextLayout:TTextLayout=ShapeBlock(block,start,finish+1,candidate)
					If nextLayout.width>maxWidth Then Exit
					text=candidate;shaped=nextLayout;finish:+1
				Wend
				Local line:TParagraphLine=AddLine(lines,text,shaped)
				If interaction Then line.sourceOffsets=interaction.LineOffsets(block,start,finish,text)
				line.sourceContentLength=text.Length
				If boundaryProvider Then
					line.trimText=block.Text(start,finish,False)
					line.trimEnds=New Int[finish-start]
					Local prefixLength:Int
					For Local boundary:Int=start Until finish-1
						Local piece:String=block.words[boundary].Replace(Chr($ad),"").Replace(Chr($200b),"")
						If boundary=start Then
							Local first:Int
							While first<piece.Length And piece[first]=32
								first:+1
							Wend
							piece=piece[first..]
						End If
						prefixLength:+piece.Length
						Local trailing:Int=piece.Length
						While trailing>0 And piece[trailing-1]=32
							trailing:-1
						Wend
						line.trimEnds[boundary-start+1]=prefixLength-piece.Length+trailing
					Next
				End If
				start=finish
			Wend
		Next
		FinishLayout(result,lines)
		result.totalLineCount=result.lines.Length
		reflowBuilds:+1
		If cacheLimit Then
			While cache.Count()>=cacheLimit
				cache.RemoveFirst()
			Wend
			cache.AddLast(result)
		End If
		Return result
	End Method

	Rem
	bbdoc: Fits a paragraph into a width and logical height, optionally limiting its line count.
	param: Maximum line width in logical text units.
	param: Height available for visible lines in logical text units.
	param: Horizontal text alignment, such as TEXT_ALIGN_LEFT.
	param: Distance between line origins; zero uses the natural line height.
	param: Maximum visible line count; zero imposes no separate line-count limit.
	param: Overflow marker appended when text is omitted.
	param: TEXT_ALIGN_TOP, TEXT_ALIGN_MIDDLE or TEXT_ALIGN_BOTTOM.
	about: Omitted content is marked with an ellipsis on the last retained line. Whole words are removed to fit the marker; an empty marker silently truncates. Glyph overhangs still require viewport clipping.
	End Rem
	Method LayoutBox:TParagraphLayout(maxWidth:Float,maxHeight:Float,alignment:Int=TEXT_ALIGN_LEFT,lineSpacing:Float=0,maxLines:Int=0,ellipsis:String="...",verticalAlignment:Int=TEXT_ALIGN_TOP)
		If IsNan(maxHeight) Or IsInf(maxHeight) Or maxHeight<0 Then Throw "Max2D: paragraph height must be finite and nonnegative"
		If verticalAlignment<TEXT_ALIGN_TOP Or verticalAlignment>TEXT_ALIGN_BOTTOM Then Throw "Max2D: invalid vertical text alignment"
		If maxLines<0 Then Throw "Max2D: maximum lines must not be negative"
		If ellipsis.Contains("~n") Or ellipsis.Contains("~r") Or ellipsis.Contains("~t") Then Throw "Max2D: ellipsis must be a single line without tabs"
		If lineSpacing=0 Then lineSpacing=naturalLineHeight
		Local found:TParagraphLayout
		For Local entry:TParagraphLayout=EachIn cache
			If entry.boxHeight=maxHeight And entry.boxWidth=maxWidth And entry.alignment=alignment And entry.lineSpacing=lineSpacing And entry.maxLines=maxLines And entry.ellipsis=ellipsis And entry.verticalAlignment=verticalAlignment Then
				found=entry
				Exit
			End If
		Next
		If found Then
			cache.Remove(found);cache.AddLast(found)
			Return found
		End If
		' Reuse the ordinary wrapped layout. Height changes never alter its lines.
		Local full:TParagraphLayout=Layout(maxWidth,alignment,lineSpacing)
		Local count:Int
		While count<full.lines.Length
			If maxLines And count>=maxLines Then Exit
			If full.lines[count].y+full.lines[count].layout.height>maxHeight Then Exit
			count:+1
		Wend
		Local result:TParagraphLayout=New TParagraphLayout
		result.interaction=interaction
		result.variableLines=fontSpans.Length>0
		result.boxWidth=maxWidth;result.boxHeight=maxHeight;result.alignment=alignment;result.lineSpacing=lineSpacing
		result.verticalAlignment=verticalAlignment
		result.maxLines=maxLines;result.ellipsis=ellipsis;result.totalLineCount=full.lines.Length
		Local hiddenLines:Int=count<full.lines.Length
		result.truncated=hiddenLines
		result.glyphs=New TPositionedGlyph[0]
		Local lines:TList=New TList
		For Local i:Int=0 Until count
			Local original:TParagraphLine=full.lines[i]
			Local text:String=original.text,shaped:TTextLayout=original.layout
			Local retainedLength:Int=text.Length
			If shaped.width>maxWidth Or (i=count-1 And hiddenLines) Then
				result.truncated=True
				If original.trimEnds Then text=original.trimText
				Local candidate:String=text+ellipsis
				shaped=ShapeFitted(candidate,original,text.Length)
				While shaped.width>maxWidth And text.Length
					Local space:Int=text.FindLast(" ")
					If original.trimEnds Then
						space=0
						For Local offset:Int=EachIn original.trimEnds
							If offset<text.Length Then space=Max(space,offset)
						Next
					End If
					If space<0 Then
						text=""
					Else
						text=text[..space]
					End If
					candidate=text+ellipsis;shaped=ShapeFitted(candidate,original,text.Length)
				Wend
				retainedLength=text.Length
				If shaped.width>maxWidth Then candidate="";shaped=font.Layout("");retainedLength=0
				text=candidate
			End If
			Local line:TParagraphLine=AddLine(lines,text,shaped)
			line.sourceContentLength=retainedLength
			If interaction Then
				line.sourceOffsets=New Int[text.Length+1]
				For Local j:Int=0 To text.Length
					line.sourceOffsets[j]=original.sourceOffsets[Min(j,retainedLength)]
				Next
			End If
		Next
		FinishLayout(result,lines)
		If result.lines.Length Then
			Select verticalAlignment
				Case TEXT_ALIGN_MIDDLE
					result.contentY=Max(0.0,maxHeight-result.height)*0.5
				Case TEXT_ALIGN_BOTTOM
					result.contentY=Max(0.0,maxHeight-result.height)
			End Select
			For Local line:TParagraphLine=EachIn result.lines
				line.y:+result.contentY
			Next
			If result.boundsHeight>0 Then result.boundsY:+result.contentY
		End If
		boxBuilds:+1
		If cacheLimit Then
			While cache.Count()>=cacheLimit
				cache.RemoveFirst()
			Wend
			cache.AddLast(result)
		End If
		Return result
	End Method

	Rem
	bbdoc: Finalizes paragraph lines, bounds and layout-cache bookkeeping.
	param: Result object to fill; optional reusable query results are cleared before use.
	param: Collection of paragraph lines in drawing order.
	End Rem
	Method FinishLayout(result:TParagraphLayout,lines:TList)
		Local maxWidth:Float=result.boxWidth,lineSpacing:Float=result.lineSpacing
		Local alignment:Int=result.alignment
		result.lines=New TParagraphLine[lines.Count()]
		Local index:Int,hasBounds:Int
		Local right:Float,bottom:Float,penY:Float
		For Local line:TParagraphLine=EachIn lines
			line.y=penY
			If result.variableLines Then penY:+Max(lineSpacing,line.layout.height) Else penY:+lineSpacing
			result.minLineY=Min(result.minLineY,line.layout.boundsY)
			result.maxLineY=Max(result.maxLineY,Max(line.layout.height,line.layout.boundsY+line.layout.boundsHeight))
			Select alignment
				Case TEXT_ALIGN_CENTER
					line.x=(maxWidth-line.layout.width)*0.5
				Case TEXT_ALIGN_RIGHT
					line.x=maxWidth-line.layout.width
			End Select
			result.lines[index]=line;index:+1
			result.width=Max(result.width,line.layout.width)
			If line.layout.boundsWidth>0 And line.layout.boundsHeight>0 Then
				Local left:Float=line.x+line.layout.boundsX,top:Float=line.y+line.layout.boundsY
				Local r:Float=left+line.layout.boundsWidth,b:Float=top+line.layout.boundsHeight
				If Not hasBounds Then
					result.boundsX=left;result.boundsY=top;right=r;bottom=b;hasBounds=True
				Else
					result.boundsX=Min(result.boundsX,left);result.boundsY=Min(result.boundsY,top)
					right=Max(right,r);bottom=Max(bottom,b)
				End If
			End If
		Next
		If index Then result.height=result.lines[index-1].y+result.lines[index-1].layout.height
		If hasBounds Then result.boundsWidth=right-result.boundsX;result.boundsHeight=bottom-result.boundsY
	End Method

	Rem
	bbdoc: Appends a shaped line to the paragraph under construction.
	param: Collection of paragraph lines in drawing order.
	param: Text to lay out, measure or draw.
	param: Retained text layout to draw or inspect.
	End Rem
	Function AddLine:TParagraphLine(lines:TList,text:String,layout:TTextLayout)
		Local line:TParagraphLine=New TParagraphLine
		line.text=text;line.layout=layout;lines.AddLast(line)
		Return line
	End Function

End Type

Rem
bbdoc: Prepares text for repeated paragraph layouts. Retain the result when resizing.
param: Text to lay out, measure or draw.
param: Default font, or Null for the current image font.
param: Basic, Unicode or automatically selected line-breaking behaviour.
param: Language tag used by the text provider; empty uses its default.
param: Whether to retain source mappings for hit testing and selection.
param: Requested paragraph direction; Auto lets the bidi provider determine it.
about: AUTO selects an imported Unicode boundary provider or the basic space-based fallback. BASIC forces the fallback. UNICODE requires an available provider. Set interactive=True to retain source mapping for optional caret geometry; ordinary preparation does not allocate it. Direction Auto uses an imported Text.Bidi provider; Disabled skips bidi entirely. Explicit LTR/RTL require a provider.
End Rem
Function PrepareText:TPreparedText(text:String,font:TImageFont=Null,breakMode:ETextBreakMode=ETextBreakMode.Auto,language:String="",interactive:Int=False,direction:ETextDirection=ETextDirection.Auto)
	If Not font Then font=GetImageFont()
	Return TPreparedText.Create(text,font,breakMode,language,interactive,direction)
End Function
