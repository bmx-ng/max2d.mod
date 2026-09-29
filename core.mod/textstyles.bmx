
Rem
bbdoc: A font object applied to a half-open original UTF-16 source range.
about: Use actual regular/bold/italic faces or differently sized fonts. SetFontSpans snapshots these ranges; font objects themselves must remain unchanged while layouts are held. Later overlapping spans win.
End Rem
Type TTextFontSpan

	Rem
	bbdoc: Inclusive UTF-16 source offset.
	End Rem
	Field sourceStart:Int

	Rem
	bbdoc: Exclusive UTF-16 source offset.
	End Rem
	Field sourceEnd:Int

	Rem
	bbdoc: Font used to shape and draw this text.
	End Rem
	Field font:TImageFont

	Rem
	bbdoc: Creates a font span over a half-open original-source range.
	param: Inclusive UTF-16 start offset in the original source.
	param: Exclusive UTF-16 end offset in the original source.
	param: Font applied to this range; keep it unchanged while layouts retain it.
	End Rem
	Function Create:TTextFontSpan(first:Int,last:Int,font:TImageFont)
		Local result:TTextFontSpan=New TTextFontSpan
		result.sourceStart=first;result.sourceEnd=last;result.font=font
		Return result
	End Function

End Type

Rem
bbdoc: A font-specific shaped run positioned on a shared text baseline.
End Rem
Type TStyledTextRun

	Rem
	bbdoc: Inclusive start index or source offset.
	End Rem
	Field first:Int

	Rem
	bbdoc: Exclusive end index or source offset.
	End Rem
	Field last:Int

	Rem
	bbdoc: Index of this run's first glyph in the combined layout.
	End Rem
	Field glyphStart:Int

	Rem
	bbdoc: Horizontal run offset within the combined text layout.
	End Rem
	Field x:Float

	Rem
	bbdoc: Vertical run offset used to align its baseline with the combined layout.
	End Rem
	Field y:Float

	Rem
	bbdoc: Logical distance from the layout origin to the shared baseline.
	End Rem
	Field baseline:Float

	Rem
	bbdoc: Font used to shape and draw this text.
	End Rem
	Field font:TImageFont

	Rem
	bbdoc: Retained text layout associated with this object.
	End Rem
	Field layout:TTextLayout
End Type

Rem
bbdoc: A retained single line containing font-specific shaped runs sharing a baseline.
End Rem
Type TStyledTextLayout Extends TTextLayout

	Rem
	bbdoc: Font-specific shaped runs in visual drawing order.
	End Rem
	Field runs:TStyledTextRun[]

	Rem
	bbdoc: Text represented by this layout or imported object.
	End Rem
	Field text:String

	Rem
	bbdoc: Logical distance from the layout origin to the shared baseline.
	End Rem
	Field baseline:Float

	Rem
	bbdoc: Draws all font-specific runs at their retained positions.
	param: Drawing canvas whose state and rendering context are used.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float) Override
		DrawColored(canvas,x,y,Null)
	End Method

	Rem
	bbdoc: Draws retained glyphs with optional per-glyph colour overrides.
	param: Drawing canvas whose state and rendering context are used.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Per-glyph colour spans, or Null to use the current drawing colour.
	param: Starting index in the per-glyph colour array.
	End Rem
	Method DrawColored(canvas:TMax2DGraphics,x:Float,y:Float,colors:TTextColorSpan[],colorOffset:Int=0) Override
		For Local run:TStyledTextRun=EachIn runs
			Local tx:Float=x+run.x*canvas.state.ix+run.y*canvas.state.iy
			Local ty:Float=y+run.x*canvas.state.jx+run.y*canvas.state.jy
			If colors Then
				run.layout.DrawColored(canvas,tx,ty,colors,colorOffset+run.glyphStart)
			Else
				run.layout.Draw(canvas,tx,ty)
			End If
		Next
	End Method

	Rem
	bbdoc: Builds caret positions at supported text-cluster boundaries.
	End Rem
	Method CreateCaretMap:TTextCaretMap()
		Local result:TTextCaretMap=TTextCaretMap.Create(text.Length)
		For Local run:TStyledTextRun=EachIn runs
			Local map:TTextCaretMap=run.font.CreateCaretMap(text[run.first..run.last])
			Local length:Int=run.last-run.first
			If Not map Or map.valid.Length<>length+1 Or map.positions.Length<>length+1 Then Throw "Max2D: invalid styled run caret map"
			If map.valid[0] And map.valid[length] Then
				If Abs(Abs(map.positions[length]-map.positions[0])-run.layout.width)>0.05 Then Throw "Max2D: styled run caret map does not match layout"
			End If
			For Local i:Int=0 Until map.valid.Length
				If Not map.valid[i] Then Continue
				result.positions[run.first+i]=run.x+map.positions[i]
				result.valid[run.first+i]=True
			Next
		Next
		Return result
	End Method

	Rem
	bbdoc: Shapes font spans into runs aligned on a common baseline.
	param: Prepared source text, font spans and provider settings.
	param: Text to lay out, measure or draw.
	param: Mapping from display-text UTF-16 boundaries to original-source offsets.
	param: Length of actual source text before any appended overflow marker.
	End Rem
	Function Create:TStyledTextLayout(prepared:TPreparedText,text:String,offsets:Int[],contentLength:Int)
		Local result:TStyledTextLayout=New TStyledTextLayout
		result.text=text
		result.baseline=prepared.font.Baseline()
		If IsNan(result.baseline) Or IsInf(result.baseline) Or result.baseline<0 Then Throw "Max2D: invalid default font baseline"
		Local below:Float=Max(0.0,prepared.naturalLineHeight-result.baseline)
		Local runs:TList=New TList
		Local first:Int
		Repeat
			Local font:TImageFont=prepared.font
			If first<contentLength Then font=prepared.FontAt(offsets[first])
			Local last:Int=first+1
			While last<text.Length
				Local nextFont:TImageFont=prepared.font
				If last<contentLength Then nextFont=prepared.FontAt(offsets[last])
				If nextFont<>font Then Exit
				last:+1
			Wend
			last=Min(last,text.Length)
			Local run:TStyledTextRun=New TStyledTextRun
			run.first=first;run.last=last;run.font=font
			run.layout=font.Layout(text[first..last]);run.baseline=font.Baseline()
			If IsNan(run.baseline) Or IsInf(run.baseline) Or run.baseline<0 Then Throw "Max2D: invalid font baseline"
			run.x=result.width;result.width:+run.layout.width
			result.baseline=Max(result.baseline,run.baseline)
			below=Max(below,run.layout.height-run.baseline)
			runs.AddLast(run)
			first=last
		Until first>=text.Length
		result.height=result.baseline+below
		result.runs=New TStyledTextRun[runs.Count()]
		Local count:Int,index:Int
		For Local run:TStyledTextRun=EachIn runs
			If runs.Count()>1 And run.layout.rightToLeft Then Throw "Max2D: mixed-font RTL runs require bidirectional paragraph layout"
			result.rightToLeft=run.layout.rightToLeft
			run.glyphStart=count;count:+run.layout.glyphs.Length
			run.y=result.baseline-run.baseline
			result.runs[index]=run;index:+1
		Next
		result.glyphs=New TPositionedGlyph[count]
		index=0
		For Local run:TStyledTextRun=EachIn result.runs
			For Local original:TPositionedGlyph=EachIn run.layout.glyphs
				Local item:TPositionedGlyph=New TPositionedGlyph
				item.image=original.image;item.x=run.x+original.x;item.y=run.y+original.y
				If original.sourceOffset>=0 Then item.sourceOffset=run.first+original.sourceOffset
				result.glyphs[index]=item;index:+1
			Next
		Next
		result.CalculateBounds()
		Return result
	End Function

End Type
