' Optional paragraph state: allocated only when a bidi provider is captured.

Rem
bbdoc: Resolved bidirectional ordering for one prepared paragraph block.
End Rem
Type TParagraphBidiBlock

	Rem
	bbdoc: Resolved bidirectional paragraph data.
	End Rem
	Field paragraph:TTextBidiParagraph

	Rem
	bbdoc: Text represented by this layout or imported object.
	End Rem
	Field text:String

	Rem
	bbdoc: UTF-16 starts of prepared segments within the bidi paragraph.
	End Rem
	Field starts:Int[]

	Rem
	bbdoc: Exclusive UTF-16 ends of prepared segments within the bidi paragraph.
	End Rem
	Field ends:Int[]

	Rem
	bbdoc: Resolves paragraph direction and embedding levels for a prepared block.
	param: Prepared paragraph block containing the source segments.
	param: Optional text provider used to resolve Unicode behaviour.
	param: Requested paragraph direction; Auto lets the bidi provider determine it.
	End Rem
	Function Create:TParagraphBidiBlock(block:TPreparedTextBlock,provider:TTextBidiProvider,direction:ETextDirection)
		Local result:TParagraphBidiBlock=New TParagraphBidiBlock
		result.starts=New Int[block.words.Length];result.ends=New Int[block.words.Length]
		Local pieces:String[]=New String[block.words.Length]
		Local offset:Int
		For Local i:Int=0 Until pieces.Length
			pieces[i]=block.words[i]
			If block.joiner="" Then pieces[i]=pieces[i].Replace(Chr($ad),"").Replace(Chr($200b),"")
			result.starts[i]=offset;offset:+pieces[i].Length;result.ends[i]=offset;offset:+block.joiner.Length
		Next
		result.text=block.joiner.Join(pieces)
		result.paragraph=provider.Analyze(result.text,direction)
		If Not result.paragraph Or result.paragraph.length<>result.text.Length Then Throw "Max2D: invalid bidi paragraph"
		Return result
	End Function

	Rem
	bbdoc: Shapes a visible line using this block's resolved bidirectional ordering.
	param: Prepared source text, font spans and provider settings.
	param: Inclusive start index of the requested range.
	param: Exclusive end index of the requested range.
	param: Visible display text for the requested line.
	param: Mapping from display-text UTF-16 boundaries to original-source offsets.
	End Rem
	Method Shape:TTextLayout(prepared:TPreparedText,first:Int,last:Int,visible:String,offsets:Int[])
		Local start:Int=starts[first],finish:Int=ends[last-1]
		While start<finish And text[start]=32
			start:+1
		Wend
		While finish>start And text[finish-1]=32
			finish:-1
		Wend
		Return TBidiTextLayout.CreateBidi(prepared,visible,offsets,visible.Length,paragraph,start,finish-start,False)
	End Method

End Type

Rem
bbdoc: A styled text run with direction, script and source placement.
End Rem
Type TBidiTextRun Extends TStyledTextRun

	Rem
	bbdoc: Whether this shaped run reads right to left.
	End Rem
	Field rtl:Int

	Rem
	bbdoc: Script identifier used by the shaping provider.
	End Rem
	Field script:Int
End Type

' Reuses retained font-specific rendering; only visual ordering and lazy interaction differ.

Rem
bbdoc: Retained text runs arranged in visual order for bidirectional drawing.
End Rem
Type TBidiTextLayout Extends TStyledTextLayout

	Rem
	bbdoc: Resolved bidirectional paragraph data.
	End Rem
	Field paragraph:TTextBidiParagraph

	Rem
	bbdoc: Start offset of this line within its resolved bidi paragraph.
	End Rem
	Field paragraphStart:Int

	Rem
	bbdoc: Length of this line within its resolved bidi paragraph.
	End Rem
	Field paragraphLength:Int

	Rem
	bbdoc: Language tag passed to text providers.
	End Rem
	Field language:String

	Rem
	bbdoc: Builds caret positions at supported text-cluster boundaries.
	End Rem
	Method CreateCaretMap:TTextCaretMap() Override
		Throw "Max2D: bidi boundaries can have two caret positions; use paragraph CaretAt/HitTest"
	End Method

	Rem
	bbdoc: Builds a visually ordered layout from resolved bidi text and font spans.
	param: Prepared source text, font spans and provider settings.
	param: Text to lay out, measure or draw.
	param: Mapping from display-text UTF-16 boundaries to original-source offsets.
	param: Length of actual source text before any appended overflow marker.
	param: Resolved bidirectional paragraph containing the requested run.
	param: Starting UTF-16 offset within the paragraph.
	param: Number of UTF-16 code units in the requested text range.
	param: Whether the line includes a separately shaped overflow marker.
	End Rem
	Function CreateBidi:TBidiTextLayout(prepared:TPreparedText,text:String,offsets:Int[],contentLength:Int,paragraph:TTextBidiParagraph,start:Int,length:Int,marker:Int)
		Local result:TBidiTextLayout=New TBidiTextLayout
		result.text=text;result.language=prepared.language
		result.paragraph=paragraph;result.paragraphStart=start;result.paragraphLength=length
		result.baseline=prepared.font.Baseline();result.rightToLeft=paragraph.baseLevel & 1
		If IsNan(result.baseline) Or IsInf(result.baseline) Or result.baseline<0 Then Throw "Max2D: invalid default font baseline"
		Local below:Float=Max(0.0,prepared.naturalLineHeight-result.baseline)
		Local visual:TList=New TList
		Local resolved:TTextBidiRun[]=paragraph.Line(start,length)
		For Local levelRun:TTextBidiRun=EachIn resolved
			Local fontRuns:TList=New TList
			Local first:Int=levelRun.first
			While first<levelRun.last
				Local font:TImageFont=prepared.font
				If prepared.fontSpans.Length And first<contentLength Then font=prepared.FontAt(offsets[first])
				Local last:Int=first+1
				While last<levelRun.last
					Local nextFont:TImageFont=prepared.font
					If prepared.fontSpans.Length And last<contentLength Then nextFont=prepared.FontAt(offsets[last])
					If nextFont<>font Then Exit
					last:+1
				Wend
				Local run:TBidiTextRun=New TBidiTextRun
				run.first=first;run.last=last;run.font=font;run.rtl=levelRun.level & 1;run.script=levelRun.script
				' A discretionary hyphen belongs to the logical end run, in that run's direction.
				If Not marker And last=length Then run.last=text.Length
				If run.rtl Then fontRuns.AddFirst(run) Else fontRuns.AddLast(run)
				first=last
			Wend
			For Local run:TBidiTextRun=EachIn fontRuns
				visual.AddLast(run)
			Next
		Next
		If (marker Or Not length) And text.Length>length Then
			Local run:TBidiTextRun=New TBidiTextRun
			run.first=length;run.last=text.Length;run.font=prepared.font;run.rtl=result.rightToLeft
			' Ellipsis is an isolated suffix at the paragraph's visual end.
			If run.rtl Then visual.AddFirst(run) Else visual.AddLast(run)
		End If
		result.runs=New TStyledTextRun[visual.Count()]
		Local index:Int,glyphCount:Int
		For Local run:TBidiTextRun=EachIn visual
			run.layout=run.font.LayoutRun(text,run.first,run.last,run.rtl,run.script,result.language)
			run.baseline=run.font.Baseline()
			If IsNan(run.baseline) Or IsInf(run.baseline) Or run.baseline<0 Then Throw "Max2D: invalid font baseline"
			run.x=result.width;result.width:+run.layout.width
			result.baseline=Max(result.baseline,run.baseline);below=Max(below,run.layout.height-run.baseline)
			run.glyphStart=glyphCount;glyphCount:+run.layout.glyphs.Length
			result.runs[index]=run;index:+1
		Next
		result.height=result.baseline+below
		result.glyphs=New TPositionedGlyph[glyphCount];index=0
		For Local run:TBidiTextRun=EachIn result.runs
			run.y=result.baseline-run.baseline
			For Local original:TPositionedGlyph=EachIn run.layout.glyphs
				Local glyph:TPositionedGlyph=New TPositionedGlyph
				glyph.image=original.image;glyph.x=run.x+original.x;glyph.y=run.y+original.y
				If original.sourceOffset>=0 Then glyph.sourceOffset=run.first+original.sourceOffset
				result.glyphs[index]=glyph;index:+1
			Next
		Next
		result.CalculateBounds()
		Return result
	End Function

End Type

Rem
bbdoc: Which side of a logical insertion offset to use at a directional run boundary.
End Rem
Enum ETextCaretAffinity

	Rem
	bbdoc: Prefers the visual caret associated with following logical text.
	End Rem
	Following

	Rem
	bbdoc: Prefers the visual caret associated with preceding logical text.
	End Rem
	Preceding
End Enum

Rem
bbdoc: One visually ordered text cell with its source range and edge carets.
End Rem
Type TBidiTextCell

	Rem
	bbdoc: Caret at the cell's visual left edge.
	End Rem
	Field left:TTextCaret

	Rem
	bbdoc: Caret at the cell's visual right edge.
	End Rem
	Field right:TTextCaret

	Rem
	bbdoc: Inclusive start index or source offset.
	End Rem
	Field first:Int

	Rem
	bbdoc: Exclusive end index or source offset.
	End Rem
	Field last:Int
End Type

' Created only on first interaction with a bidi line. Cells are in visual order;
' items are in source order, retaining both positions at directional boundaries.

Rem
bbdoc: Cached source-to-visual mappings for hit testing a bidirectional line.
End Rem
Type TBidiTextInteraction

	Rem
	bbdoc: Caret stops sorted by logical source position.
	End Rem
	Field items:TTextCaret[]

	Rem
	bbdoc: Text cells in visual left-to-right order.
	End Rem
	Field cells:TBidiTextCell[]

	Rem
	bbdoc: Compares carets by their logical source offsets for sorting.
	param: First caret to compare by logical source offset.
	param: Second caret to compare by logical source offset.
	End Rem
	Function SourceCompare:Int(a:Object,b:Object)
		Local first:TTextCaret=TTextCaret(a),last:TTextCaret=TTextCaret(b)
		If first.sourceOffset<>last.sourceOffset Then Return first.sourceOffset-last.sourceOffset
		Return Int(first.affinity)-Int(last.affinity)
	End Function

	Rem
	bbdoc: Builds visual cells and source-sorted carets for one bidirectional line.
	param: Retained text layout to draw or inspect.
	param: Prepared visual paragraph line.
	param: Zero-based visual line index.
	param: Source data or object to read.
	End Rem
	Function Create:TBidiTextInteraction(layout:TBidiTextLayout,line:TParagraphLine,lineIndex:Int,source:TTextSourceMap)
		Local result:TBidiTextInteraction=New TBidiTextInteraction
		Local points:TList=New TList,visual:TList=New TList
		For Local run:TBidiTextRun=EachIn layout.runs
			Local map:TTextCaretMap=run.font.CreateRunCaretMap(layout.text,run.first,run.last,run.rtl,run.script,layout.language)
			Local length:Int=run.last-run.first
			If Not map Or map.positions.Length<>length+1 Or map.valid.Length<>length+1 Then Throw "Max2D: invalid bidi caret map"
			If map.valid[0] And map.valid[length] Then
				If Abs(Abs(map.positions[length]-map.positions[0])-run.layout.width)>0.05 Then Throw "Max2D: bidi caret map does not match layout"
			End If
			Local previous:TTextCaret
			Local runCells:TList=New TList
			For Local i:Int=0 To length
				If Not map.valid[i] Then Continue
				Local offset:Int=run.first+i,original:Int=line.sourceOffsets[offset]
				If source.graphemes And Not source.graphemes[original] Then Continue
				If offset>0 And offset<line.text.Length Then
					If line.text[offset]>=$dc00 And line.text[offset]<=$dfff And line.text[offset-1]>=$d800 And line.text[offset-1]<=$dbff Then Continue
				End If
				Local point:TTextCaret=New TTextCaret
				point.sourceOffset=original;point.lineIndex=lineIndex
				point.x=line.x+run.x+map.positions[i];point.y=line.y;point.height=line.layout.height
				If i=length Then point.affinity=ETextCaretAffinity.Preceding
				points.AddLast(point)
				If previous Then
					If (Not run.rtl And point.x<previous.x) Or (run.rtl And point.x>previous.x) Then Throw "Max2D: nonmonotone directional run carets"
					Local cell:TBidiTextCell=New TBidiTextCell
					cell.first=previous.sourceOffset;cell.last=point.sourceOffset
					If run.rtl Then cell.left=point;cell.right=previous Else cell.left=previous;cell.right=point
					If run.rtl Then runCells.AddFirst(cell) Else runCells.AddLast(cell)
				End If
				previous=point
			Next
			For Local cell:TBidiTextCell=EachIn runCells
				visual.AddLast(cell)
			Next
		Next
		If Not points.Count() Then
			Local point:TTextCaret=New TTextCaret
			point.sourceOffset=line.sourceOffsets[0];point.lineIndex=lineIndex
			point.x=line.x;point.y=line.y;point.height=line.layout.height;points.AddLast(point)
		End If
		points.Sort(True,SourceCompare)
		result.items=New TTextCaret[points.Count()]
		Local index:Int
		For Local point:TTextCaret=EachIn points
			result.items[index]=point;index:+1
		Next
		result.cells=New TBidiTextCell[visual.Count()];index=0
		For Local cell:TBidiTextCell=EachIn visual
			result.cells[index]=cell;index:+1
		Next
		Return result
	End Function

	Rem
	bbdoc: Returns the visual text cell nearest a horizontal line coordinate.
	param: Horizontal coordinate.
	End Rem
	Method CellAt:TBidiTextCell(x:Float)
		If Not cells.Length Then Return Null
		Local first:Int,last:Int=cells.Length-1
		While first<last
			Local middle:Int=(first+last+1)/2
			If cells[middle].left.x<=x Then first=middle Else last=middle-1
		Wend
		Return cells[first]
	End Method

	Rem
	bbdoc: Returns the nearest visual caret at a horizontal line coordinate.
	param: Horizontal paragraph-local pointer coordinate.
	End Rem
	Method HitTest:TTextCaret(x:Float)
		Local cell:TBidiTextCell=CellAt(x)
		If Not cell Then Return items[0]
		If Abs(x-cell.left.x)<=Abs(x-cell.right.x) Then Return cell.left
		Return cell.right
	End Method

	Rem
	bbdoc: Returns the nearest logical caret with the requested bidi affinity.
	param: Offset in the original UTF-16 source string.
	param: Which visual side to prefer when a source offset has two bidi caret positions.
	End Rem
	Method CaretAt:TTextCaret(offset:Int,affinity:ETextCaretAffinity)
		Local first:Int,last:Int=items.Length-1
		While first<last
			Local middle:Int=(first+last)/2
			If items[middle].sourceOffset<offset Then first=middle+1 Else last=middle
		Wend
		If first>0 And Abs(items[first-1].sourceOffset-offset)<Abs(items[first].sourceOffset-offset) Then first:-1
		Local chosen:Int=items[first].sourceOffset
		While first>0 And items[first-1].sourceOffset=chosen
			first:-1
		Wend
		Local index:Int=first
		While index<items.Length And items[index].sourceOffset=chosen
			If items[index].affinity=affinity Then Return items[index]
			index:+1
		Wend
		Return items[first]
	End Method

End Type
