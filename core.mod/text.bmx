Rem
bbdoc: Optional single-line caret positions indexed by UTF-16 offsets.
about: valid marks supported cluster edges; positions use logical font units. Font subclasses with custom shaping must override CreateCaretMap.
End Rem
Type TTextCaretMap
	Field positions:Float[]
	Field valid:Byte[]
	Function Create:TTextCaretMap(length:Int)
		Local result:TTextCaretMap=New TTextCaretMap
		result.positions=New Float[length+1]
		result.valid=New Byte[length+1]
		Return result
	End Function
End Type

' The built-in bitmap data is from BRL.Max2D (Blitz Research Ltd).
' See NOTICE.md and LICENSE for its zlib/libpng attribution.


Type TImageGlyph
	Field image:TImage
	Field advance:Float
	Field x:Int, y:Int, w:Int, h:Int
End Type

Type TPositionedGlyph
	Field sourceOffset:Int=-1
	Field image:TImage
	Field x:Float, y:Float
End Type

Type TTextLayout
	Field glyphs:TPositionedGlyph[]
	Field width:Float, height:Float
	Field rightToLeft:Int
	Field boundsX:Float,boundsY:Float,boundsWidth:Float,boundsHeight:Float
	Method CalculateBounds()
		Local first:Int=True,right:Float,bottom:Float
		For Local glyph:TPositionedGlyph=EachIn glyphs
			If Not glyph.image Then Continue
			If first Then
				boundsX=glyph.x; boundsY=glyph.y; right=glyph.x+glyph.image.width; bottom=glyph.y+glyph.image.height
				first=False
			Else
				boundsX=Min(boundsX,glyph.x); boundsY=Min(boundsY,glyph.y)
				right=Max(right,glyph.x+glyph.image.width); bottom=Max(bottom,glyph.y+glyph.image.height)
			End If
		Next
		If Not first Then boundsWidth=right-boundsX; boundsHeight=bottom-boundsY
	End Method
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float)
		DrawColored(canvas,x,y,Null)
	End Method
	Method DrawColored(canvas:TMax2DGraphics,x:Float,y:Float,colors:TTextColorSpan[],colorOffset:Int=0)
		Local red:Int=canvas.state.red,green:Int=canvas.state.green,blue:Int=canvas.state.blue
		Local alpha:Float=canvas.state.alpha
		Try
			For Local index:Int=0 Until glyphs.Length
				Local glyph:TPositionedGlyph=glyphs[index]
				If colors Then TTextPaint.Apply(canvas.state,colors[colorOffset+index],red,green,blue,alpha)
				Local image:TImage = glyph.image
				If Not image Then Continue
				Local native:TImageFrame = image.Frame(0, canvas)
				Local source:TImageSource = image.sources[0]
				Local u:Float = image.sourceX[0] / Float(source.width)
				Local v:Float = image.sourceY[0] / Float(source.height)
				Local gx:Float = glyph.x - canvas.state.handleX
				Local gy:Float = glyph.y - canvas.state.handleY
				canvas.Quad(native,gx,gy,gx+image.width,gy+image.height,x+canvas.state.originX,y+canvas.state.originY,..
					u,v,u+image.width/Float(source.width),v+image.height/Float(source.height))
			Next
		Catch error:Object
			canvas.state.red=red;canvas.state.green=green;canvas.state.blue=blue;canvas.state.alpha=alpha
			Throw error
		End Try
		canvas.state.red=red;canvas.state.green=green;canvas.state.blue=blue;canvas.state.alpha=alpha
	End Method

End Type

Type TImageFont
	Field baselineOffset:Float=-1
	Rem
	bbdoc: Baseline from logical line top. Custom fonts should override this or set baselineOffset.
	about: Legacy fonts without ascent metadata default to the line bottom; scalable fonts expose their real ascent.
	End Rem
	Method Baseline:Float()
		If baselineOffset>=0 Then Return baselineOffset
		Return Height()
	End Method
	Field sourceFont:TFont
	Field styleFlags:Int
	Field glyphCache:TImageGlyph[]
	Field layouts:TMap = New TMap
	Field layoutKeys:TList = New TList
	Field atlas:TTextureAtlas
	Field layoutBuilds:Long
	Field glyphBuilds:Long
	Field layoutCacheLimit:Int = 128

	Function FromFont:TImageFont(font:TFont, style:Int = 0)
		If Not font Then Return Null
		Local result:TImageFont = New TImageFont
		result.sourceFont = font; result.styleFlags = style | font.Style()
		result.glyphCache = New TImageGlyph[font.CountGlyphs()]
		Return result
	End Function
	Function Load:TImageFont(url:Object, size:Int, style:Int = SMOOTHFONT)
		Return FromFont(LoadFont(url,size,style),style)
	End Function
	Method Height:Int()
		If sourceFont Then Return sourceFont.Height()
		Return 16
	End Method
	Method Style:Int()
		Return styleFlags
	End Method
	Method Pack:TImage(pixmap:TPixmap)
		If Not pixmap Then Return Null
		If Not atlas Then
			Local flags:Int
			If styleFlags & SMOOTHFONT Then flags=FILTEREDIMAGE
			atlas=TTextureAtlas.Create(512,flags)
		End If
		Return atlas.AddPixmap(pixmap)
	End Method
	Method CacheGlyph:TImageGlyph(index:Int, glyph:TGlyph)
		If index < 0 Or index >= glyphCache.Length Then Throw "Max2D: font returned an invalid glyph index"
		If glyphCache[index] Then Return glyphCache[index]
		If Not glyph Then Throw "Max2D: font failed to load glyph " + index
		Local cached:TImageGlyph = New TImageGlyph
		cached.advance = glyph.Advance()
		glyph.GetRect(cached.x,cached.y,cached.w,cached.h)
		cached.image = Pack(TPixmap(glyph.Pixels()))
		glyphCache[index] = cached
		glyphBuilds :+ 1
		Return cached
	End Method
	Method LoadGlyph:TImageGlyph(index:Int)
		If index < 0 Or index >= glyphCache.Length Then Return Null
		If glyphCache[index] Then Return glyphCache[index]
		If Not sourceFont Then Return Null
		Return CacheGlyph(index,sourceFont.LoadGlyph(index))
	End Method
	Rem
	bbdoc: Builds optional single-line caret geometry from glyph advances.
	about: Custom layout implementations must override this method. Shaped legacy fonts without cluster metadata are unsupported; use Max2D.ScalableFont for shaped interaction.
	End Rem
	Method CreateCaretMap:TTextCaretMap(text:String)
		If text.Contains("~n") Or text.Contains("~r") Or text.Contains("~t") Then Throw "Max2D: caret geometry requires a normalized single line"
		If sourceFont And (styleFlags & ~(BOLDFONT | ITALICFONT | SMOOTHFONT)) Then Throw "Max2D: this shaped font does not expose caret clusters"
		Local result:TTextCaretMap=TTextCaretMap.Create(text.Length)
		Local i:Int,pen:Float
		result.valid[0]=True
		While i<text.Length
			Local ch:Int=text[i]
			i:+1
			If ch>=$d800 And ch<=$dbff And i<text.Length Then
				Local low:Int=text[i]
				If low>=$dc00 And low<=$dfff Then
					ch=$10000+((ch-$d800) Shl 10)+low-$dc00
					i:+1
				End If
			End If
			Local index:Int=ch-32
			If sourceFont Then index=sourceFont.CharToGlyph(ch)
			Local entry:TImageGlyph=LoadGlyph(index)
			If entry Then pen:+entry.advance
			result.positions[i]=pen;result.valid[i]=True
		Wend
		Return result
	End Method

	Rem
	bbdoc: Shapes a directional run with surrounding line context. Custom shaped fonts can override this hook.
	about: first/last are UTF-16 offsets in text. The returned glyph source offsets are relative to first. The base implementation supports LTR only; use ScalableFont for RTL shaping and mirrored glyphs.
	End Rem
	Method LayoutRun:TTextLayout(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="")
		If first<0 Or last<first Or last>text.Length Then Throw "Max2D: invalid directional run range"
		If rtl Then Throw "Max2D: RTL layout requires a direction-aware font (such as ScalableFont)"
		Return Layout(text[first..last])
	End Method
	Method CreateRunCaretMap:TTextCaretMap(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="")
		If first<0 Or last<first Or last>text.Length Then Throw "Max2D: invalid directional run range"
		If rtl Then Throw "Max2D: RTL carets require a direction-aware font"
		Return CreateCaretMap(text[first..last])
	End Method

	Method Layout:TTextLayout(text:String)
		Local cached:TTextLayout = TTextLayout(layouts.ValueForKey(text))
		If cached Then
			layoutKeys.Remove(text); layoutKeys.AddLast(text)
			Return cached
		End If
		Local result:TTextLayout = New TTextLayout
		Local positioned:TList = New TList
		Local lines:String[] = text.Replace("~t","    ").Split("~n")
		Local baseline:Float
		For Local line:String = EachIn lines
			If line.EndsWith("~r") Then line = line[..line.Length-1]
			Local pen:Float
			If sourceFont And (styleFlags & ~(BOLDFONT | ITALICFONT | SMOOTHFONT)) Then
				Local shaped:TGlyph[] = sourceFont.LoadGlyphs(line)
				For Local glyph:TGlyph = EachIn shaped
					If Not glyph Then Continue
					Local entry:TImageGlyph = CacheGlyph(glyph.Index(),glyph)
					Local x:Int,y:Int,w:Int,h:Int
					glyph.GetRect(x,y,w,h)
					If entry.image Then
						Local item:TPositionedGlyph = New TPositionedGlyph
						item.image = entry.image; item.x = pen+x; item.y = baseline+y
						positioned.AddLast(item)
					End If
					pen :+ glyph.Advance()
				Next
			Else
				Local i:Int
				While i < line.Length
					Local sourceOffset:Int=i
					Local ch:Int = line[i]
					i :+ 1
					If ch >= $d800 And ch <= $dbff And i < line.Length Then
						Local low:Int = line[i]
						If low >= $dc00 And low <= $dfff Then
							ch = $10000 + ((ch-$d800) Shl 10) + low-$dc00
							i :+ 1
						End If
					End If
					Local index:Int = ch-32
					If sourceFont Then index = sourceFont.CharToGlyph(ch)
					Local entry:TImageGlyph = LoadGlyph(index)
					If Not entry Then Continue
					If entry.image Then
						Local item:TPositionedGlyph = New TPositionedGlyph
						item.sourceOffset=sourceOffset
						item.image = entry.image; item.x = pen+entry.x; item.y = baseline+entry.y
						positioned.AddLast(item)
					End If
					pen :+ entry.advance
				Wend
			End If
			result.width = Max(result.width,pen)
			baseline :+ Height()
		Next
		result.height = baseline
		result.glyphs = New TPositionedGlyph[positioned.Count()]
		Local index:Int
		For Local item:TPositionedGlyph = EachIn positioned
			result.glyphs[index] = item; index :+ 1
		Next
		result.CalculateBounds()
		If layoutCacheLimit>0 Then
			While layoutKeys.Count()>=layoutCacheLimit
				layouts.Remove(String(layoutKeys.RemoveFirst()))
			Wend
			layoutKeys.AddLast(text); layouts.Insert(text,result)
		End If
		layoutBuilds :+ 1
		Return result
	End Method

	Rem
	bbdoc: Limits cached text layouts. Zero disables caching. Existing layouts remain usable.
	End Rem
	Method SetLayoutCacheLimit(limit:Int)
		If limit<0 Then Throw "Max2D: layout cache limit cannot be negative"
		layoutCacheLimit=limit
		While layoutKeys.Count()>limit
			layouts.Remove(String(layoutKeys.RemoveFirst()))
		Wend
	End Method
	Method ClearLayoutCache()
		layouts.Clear(); layoutKeys.Clear()
	End Method

	Function DefaultFont:TImageFont()
		Global font:TImageFont
		If font Then Return font
		font = New TImageFont
		font.baselineOffset=11
		font.atlas=TTextureAtlas.Create(512,0,1,PF_A8)
		font.glyphCache = New TImageGlyph[96]
		Local bits:Byte Ptr = IncbinPtr("blitzfont.bin")
		For Local index:Int = 0 Until 96
			Local pixmap:TPixmap = CreatePixmap(8,16,PF_A8)
			pixmap.ClearPixels(0)
			For Local y:Int = 0 Until 16
				For Local x:Int = 0 Until 8
					If bits[y*96+index] & (1 Shl x) Then pixmap.WritePixel(x,y,$ffffffff)
				Next
			Next
			Local glyph:TImageGlyph = New TImageGlyph
			glyph.image = font.Pack(pixmap); glyph.advance = 8; glyph.w = 8; glyph.h = 16
			font.glyphCache[index] = glyph
		Next
		Return font
	End Function
End Type
