Rem
bbdoc: A font object applied to a half-open original UTF-16 source range.
about: Use actual regular/bold/italic faces or differently sized fonts. SetFontSpans snapshots these ranges; font objects themselves must remain unchanged while layouts are held. Later overlapping spans win.
End Rem
Type TTextFontSpan
	Field sourceStart:Int,sourceEnd:Int
	Field font:TImageFont
	Function Create:TTextFontSpan(first:Int,last:Int,font:TImageFont)
		Local result:TTextFontSpan=New TTextFontSpan
		result.sourceStart=first;result.sourceEnd=last;result.font=font
		Return result
	End Function
End Type

Type TStyledTextRun
	Field first:Int,last:Int,glyphStart:Int
	Field x:Float,y:Float,baseline:Float
	Field font:TImageFont
	Field layout:TTextLayout
End Type

Rem
bbdoc: A retained single line containing font-specific shaped runs sharing a baseline.
End Rem
Type TStyledTextLayout Extends TTextLayout
	Field runs:TStyledTextRun[]
	Field text:String
	Field baseline:Float
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float) Override
		DrawColored(canvas,x,y,Null)
	End Method
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
