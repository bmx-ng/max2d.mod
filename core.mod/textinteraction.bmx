Rem
bbdoc: A half-open range in the original UTF-16 input.
about: valid distinguishes an empty range (such as a blank line) from no target.
End Rem
Struct STextRange
	Field sourceStart:Int,sourceEnd:Int,valid:Int
End Struct

Rem
bbdoc: A retained, read-only caret in paragraph-local logical coordinates.
about: sourceOffset indexes the original UTF-16 input. lineIndex identifies the visible line. height is the logical line height. Transform local coordinates through the same drawing state as the paragraph when positioning screen UI.
End Rem
Type TTextCaret
	Field affinity:ETextCaretAffinity
	Field sourceOffset:Int,lineIndex:Int
	Field x:Float,y:Float,height:Float
End Type

Rem
bbdoc: A read-only selection rectangle in paragraph-local logical coordinates.
about: Source ranges are half-open and expanded to supported cluster edges. Rectangles describe advance coverage, not glyph ink, and use logical line height.
End Rem
Type TTextSelectionRect
	Field sourceStart:Int,sourceEnd:Int,lineIndex:Int
	Field x:Float,y:Float,width:Float,height:Float
End Type

' Internal construction helpers. Arrays are allocated only for interactive text.
Type TTextCaretLine
	Field items:TTextCaret[]
End Type

Type TTextSourceMap
	Field normalized:String
	Field offsets:Int[]
	Field graphemes:Byte[]
	Field font:TImageFont
	Field fontHeight:Float
	Field sourceLength:Int
	Field unicode:Int
	Field sourceText:String,language:String
	Field provider:TTextBoundaryProvider
	Field wordBreaks:Byte[]
	Field wordBuilds:Int
	Field colorSpans:TTextColorSpan[]
	Field paintRevision:Int,hasBackgrounds:Int

	Function Create:TTextSourceMap(text:String,prepared:TPreparedText)
		Local result:TTextSourceMap=New TTextSourceMap
		result.font=prepared.font;result.fontHeight=prepared.naturalLineHeight
		result.sourceLength=text.Length;result.unicode=prepared.boundaryProvider<>Null
		result.sourceText=text;result.provider=prepared.boundaryProvider;result.language=prepared.language
		Local units:Short[]=New Short[text.Length]
		Local mapping:Int[]=New Int[text.Length+1]
		Local count:Int,i:Int
		While i<text.Length
			Local ch:Int=text[i]
			i:+1
			If ch=13 Then
				If i<text.Length And text[i]=10 Then i:+1
				ch=10
			Else If ch=9 Then
				ch=32
			End If
			If result.unicode And ch=32 And (count=0 Or units[count-1]=32) Then
				mapping[count]=i
				Continue
			End If
			units[count]=ch;count:+1;mapping[count]=i
		Wend
		If result.unicode And count>0 And units[count-1]=32 Then count:-1
		result.normalized=String.FromShorts(units,count)
		result.offsets=mapping[..count+1]
		If result.unicode Then
			If result.normalized<>prepared.normalizedText Then Throw "Max2D: inconsistent normalized source mapping"
			Local boundaries:TTextBoundaries=prepared.boundaryProvider.Analyze(text,prepared.language,ETextBoundaryMaps.Grapheme)
			If Not boundaries Or boundaries.graphemeBreaks.Length<>text.Length+1 Then Throw "Max2D: invalid interaction grapheme map"
			result.graphemes=boundaries.graphemeBreaks
		End If
		Local cursor:Int
		For Local block:TPreparedTextBlock=EachIn prepared.blocks
			block.sourceStart=cursor
			block.wordOffsets=New Int[block.words.Length]
			For Local j:Int=0 Until block.words.Length
				Local found:Int=result.normalized.Find(block.words[j],cursor)
				If found<0 Then Throw "Max2D: cannot map prepared segment to source"
				block.wordOffsets[j]=found;cursor=found+block.words[j].Length
			Next
			' Advance over a mandatory separator, including empty paragraphs.
			While cursor<result.normalized.Length
				Local ch:Int=result.normalized[cursor]
				cursor:+1
				If ch=10 Or (result.unicode And (ch=11 Or ch=12 Or ch=$85 Or ch=$2028 Or ch=$2029)) Then Exit
			Wend
		Next
		Return result
	End Function

	Method SetColorSpans(spans:TTextColorSpan[])
		Local copy:TTextColorSpan[]=New TTextColorSpan[spans.Length]
		Local backgrounds:Int
		For Local i:Int=0 Until spans.Length
			If Not spans[i] Then Throw "Max2D: null text colour span"
			If spans[i].sourceStart<0 Or spans[i].sourceEnd<spans[i].sourceStart Or spans[i].sourceEnd>sourceLength Then Throw "Max2D: invalid text colour source range"
			copy[i]=spans[i].Copy()
			backgrounds:|copy[i].hasBackground
		Next
		colorSpans=copy;hasBackgrounds=backgrounds;paintRevision:+1
	End Method

	Method ColorAt:TTextColorSpan(offset:Int,background:Int=False)
		If graphemes Then
			While offset>0 And Not graphemes[offset]
				offset:-1
			Wend
		End If
		For Local i:Int=colorSpans.Length-1 To 0 Step -1
			Local span:TTextColorSpan=colorSpans[i]
			If offset<span.sourceStart Or offset>=span.sourceEnd Then Continue
			If (background And span.hasBackground) Or (Not background And span.hasForeground) Then Return span
		Next
		Return Null
	End Method

	Method PrepareWords()
		If wordBreaks Then Return
		Local map:Byte[]
		If provider Then
			Local analyzed:TTextBoundaries=provider.Analyze(sourceText,language,ETextBoundaryMaps.Word)
			If Not analyzed Or analyzed.wordBreaks.Length<>sourceLength+1 Then Throw "Max2D: invalid word boundary map"
			map=analyzed.wordBreaks
		Else
			map=New Byte[sourceLength+1]
			For Local i:Int=1 Until sourceLength
				Local before:Int=BasicWordClass(sourceText[i-1]),after:Int=BasicWordClass(sourceText[i])
				map[i]=(before<>after Or before=2)
			Next
		End If
		wordBreaks=map;wordBuilds:+1
	End Method

	Function BasicWordClass:Int(ch:Int)
		If ch=32 Or ch=9 Or ch=10 Or ch=13 Then Return 0
		If ch>=128 Or ch=95 Or (ch>=48 And ch<=57) Or (ch>=65 And ch<=90) Or (ch>=97 And ch<=122) Then Return 1
		Return 2
	End Function

	Method IsWordBoundary:Int(offset:Int)
		If offset=0 Or offset=sourceLength Then Return True
		If graphemes And Not graphemes[offset] Then Return False
		If sourceText[offset]>=$dc00 And sourceText[offset]<=$dfff And sourceText[offset-1]>=$d800 And sourceText[offset-1]<=$dbff Then Return False
		Return wordBreaks[offset]<>0
	End Method

	Method WordAt:STextRange(offset:Int)
		Local result:STextRange
		If Not sourceLength Then Return result
		PrepareWords()
		offset=Max(0,Min(sourceLength-1,offset))
		Local first:Int=offset,last:Int=offset+1
		While first>0 And Not IsWordBoundary(first)
			first:-1
		Wend
		While last<sourceLength And Not IsWordBoundary(last)
			last:+1
		Wend
		result.sourceStart=first;result.sourceEnd=last;result.valid=True
		Return result
	End Method

	Method LineOffsets:Int[](block:TPreparedTextBlock,first:Int,last:Int,text:String)
		Local start:Int=block.wordOffsets[first]
		Local finish:Int=block.wordOffsets[last-1]+block.words[last-1].Length
		While start<finish And normalized[start]=32
			start:+1
		Wend
		While finish>start And normalized[finish-1]=32
			finish:-1
		Wend
		Local result:Int[]=New Int[text.Length+1]
		Local count:Int,i:Int=start
		result[0]=offsets[start]
		While i<finish
			Local ch:Int=normalized[i]
			i:+1
			If unicode And (ch=$ad Or ch=$200b) Then
				If ch=$ad And i=finish And count+1=text.Length And text[count]=45 Then
					' A rendered discretionary hyphen represents the source soft hyphen.
					result[count]=offsets[i-1]
				Else
					result[count]=offsets[i]
				End If
				Continue
			End If
			If Not unicode And ch=32 Then
				While i<finish And normalized[i]=32
					i:+1
				Wend
			End If
			If count>=text.Length Or text[count]<>ch Then Throw "Max2D: inconsistent visible source mapping"
			count:+1;result[count]=offsets[i]
		Wend
		' A displayed discretionary hyphen maps to the soft-hyphen source end.
		If count<text.Length Then
			If count+1<>text.Length Or text[count]<>45 Then Throw "Max2D: inconsistent discretionary hyphen mapping"
			result[count+1]=offsets[finish]
		End If
		Return result
	End Method

	Method BuildCarets:TTextCaretLine(line:TParagraphLine,lineIndex:Int)
		Local map:TTextCaretMap
		Local styled:TStyledTextLayout=TStyledTextLayout(line.layout)
		If styled Then map=styled.CreateCaretMap() Else map=font.CreateCaretMap(line.text)
		If Not map Or map.valid.Length<>line.text.Length+1 Or map.positions.Length<>line.text.Length+1 Then Throw "Max2D: invalid font caret map"
		' Reject custom font implementations whose geometry does not match drawing.
		If map.valid[0] And map.valid[line.text.Length] Then
			If Abs(Abs(map.positions[line.text.Length]-map.positions[0])-line.layout.width)>0.05 Then Throw "Max2D: font caret map does not match layout; override CreateCaretMap for custom shaping"
		End If
		Local points:TList=New TList
		Local previous:Float,direction:Int
		For Local i:Int=0 To line.text.Length
			If Not map.valid[i] Then Continue
			Local source:Int=line.sourceOffsets[i]
			If graphemes And Not graphemes[source] Then Continue
			If i>0 And i<line.text.Length Then
				If line.text[i]>=$dc00 And line.text[i]<=$dfff And line.text[i-1]>=$d800 And line.text[i-1]<=$dbff Then Continue
			End If
			Local point:TTextCaret=New TTextCaret
			point.sourceOffset=source;point.lineIndex=lineIndex
			point.x=line.x+map.positions[i];point.y=line.y;point.height=line.layout.height
			If points.Count() And point.x<>previous Then
				Local stepDirection:Int=1
				If point.x<previous Then stepDirection=-1
				If direction And direction<>stepDirection Then Throw "Max2D: nonmonotone caret positions are unsupported"
				direction=stepDirection
			End If
			previous=point.x;points.AddLast(point)
		Next
		Local result:TTextCaretLine=New TTextCaretLine
		result.items=New TTextCaret[points.Count()]
		Local j:Int
		For Local point:TTextCaret=EachIn points
			result.items[j]=point;j:+1
		Next
		Return result
	End Method
End Type
