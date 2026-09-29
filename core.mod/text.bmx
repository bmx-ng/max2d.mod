
Rem
bbdoc: Optional single-line caret positions indexed by UTF-16 offsets.
about: valid marks supported cluster edges; positions use logical font units. Font subclasses with custom shaping must override CreateCaretMap.
End Rem
Type TTextCaretMap

	Rem
	bbdoc: Logical horizontal caret or word positions.
	End Rem
	Field positions:Float[]

	Rem
	bbdoc: One flag per UTF-16 boundary; nonzero marks a supported caret stop.
	End Rem
	Field valid:Byte[]

	Rem
	bbdoc: Allocates caret positions and validity flags for a UTF-16 string length.
	param: Number of UTF-16 code units in the requested text range.
	End Rem
	Function Create:TTextCaretMap(length:Int)
		Local result:TTextCaretMap=New TTextCaretMap
		result.positions=New Float[length+1]
		result.valid=New Byte[length+1]
		Return result
	End Function

End Type

' The built-in bitmap data is from BRL.Max2D (Blitz Research Ltd).
' See NOTICE.md and LICENSE for its zlib/libpng attribution.

Rem
bbdoc: An image-backed glyph with its drawing offset and advance.
End Rem
Type TImageGlyph

	Rem
	bbdoc: Image or animation supplying this object's artwork.
	End Rem
	Field image:TImage

	Rem
	bbdoc: Logical horizontal advance to the next glyph.
	End Rem
	Field advance:Float

	Rem
	bbdoc: Glyph bitmap horizontal bearing relative to its drawing position.
	End Rem
	Field x:Int

	Rem
	bbdoc: Glyph bitmap vertical offset relative to the text origin.
	End Rem
	Field y:Int

	Rem
	bbdoc: Glyph bitmap width in pixels.
	End Rem
	Field w:Int

	Rem
	bbdoc: Glyph bitmap height in pixels.
	End Rem
	Field h:Int
End Type

Rem
bbdoc: A glyph image positioned within a retained text layout.
End Rem
Type TPositionedGlyph

	Rem
	bbdoc: Offset in the original UTF-16 source; negative means no mapping is available.
	End Rem
	Field sourceOffset:Int=-1

	Rem
	bbdoc: Image or animation supplying this object's artwork.
	End Rem
	Field image:TImage

	Rem
	bbdoc: Horizontal glyph position relative to the layout origin.
	End Rem
	Field x:Float

	Rem
	bbdoc: Vertical glyph position relative to the layout origin.
	End Rem
	Field y:Float
End Type

Rem
bbdoc: Retained glyph positions, advance dimensions and visible ink bounds.
End Rem
Type TTextLayout

	Rem
	bbdoc: Positioned glyphs in drawing order; treat retained layouts as read-only.
	End Rem
	Field glyphs:TPositionedGlyph[]

	Rem
	bbdoc: Logical advance width of the layout; not necessarily the width of visible ink.
	End Rem
	Field width:Float

	Rem
	bbdoc: Logical layout height used for line placement and selection.
	End Rem
	Field height:Float

	Rem
	bbdoc: Whether the retained text run is laid out right to left.
	End Rem
	Field rightToLeft:Int

	Rem
	bbdoc: Horizontal origin of the glyph-ink bounds relative to the text origin.
	End Rem
	Field boundsX:Float

	Rem
	bbdoc: Vertical origin of the glyph-ink bounds relative to the text origin.
	End Rem
	Field boundsY:Float

	Rem
	bbdoc: Width of the visible glyph-ink bounds.
	End Rem
	Field boundsWidth:Float

	Rem
	bbdoc: Height of the visible glyph-ink bounds.
	End Rem
	Field boundsHeight:Float

	Rem
	bbdoc: Recalculates ink bounds from the positioned glyph images.
	End Rem
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

	Rem
	bbdoc: Draws retained glyphs using the supplied canvas state.
	param: Drawing canvas whose state and rendering context are used.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float)
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

Rem
bbdoc: An image-backed font with glyph and text-layout caches.
End Rem
Type TImageFont

	Rem
	bbdoc: Explicit logical baseline offset; a negative value requests automatic metrics.
	End Rem
	Field baselineOffset:Float=-1

	Rem
	bbdoc: Baseline from logical line top. Custom fonts should override this or set baselineOffset.
	about: Legacy fonts without ascent metadata default to the line bottom; scalable fonts expose their real ascent.
	End Rem
	Method Baseline:Float()
		If baselineOffset>=0 Then Return baselineOffset
		Return Height()
	End Method

	Rem
	bbdoc: Underlying BRL font used to obtain glyph metrics and bitmaps.
	End Rem
	Field sourceFont:TFont

	Rem
	bbdoc: Font style and shaping flags.
	End Rem
	Field styleFlags:Int

	Rem
	bbdoc: Glyph images and metrics indexed by glyph ID.
	End Rem
	Field glyphCache:TImageGlyph[]

	Rem
	bbdoc: Retained layouts indexed by source text.
	End Rem
	Field layouts:TMap = New TMap

	Rem
	bbdoc: Order used to evict entries from the text-layout cache.
	End Rem
	Field layoutKeys:TList = New TList

	Rem
	bbdoc: Shared texture atlas containing artwork or glyph images.
	End Rem
	Field atlas:TTextureAtlas

	Rem
	bbdoc: Number of text layouts built instead of retrieved from cache.
	End Rem
	Field layoutBuilds:Long

	Rem
	bbdoc: Number of glyphs rasterized instead of retrieved from cache.
	End Rem
	Field glyphBuilds:Long

	Rem
	bbdoc: Maximum number of text layouts retained by the font.
	End Rem
	Field layoutCacheLimit:Int = 128

	Rem
	bbdoc: Wraps a BRL font for use with Max2D image-based text drawing.
	param: Underlying BRL font supplying glyph metrics and bitmaps.
	param: Font style flags, such as SMOOTHFONT, BOLDFONT or ITALICFONT.
	End Rem
	Function FromFont:TImageFont(font:TFont, style:Int = 0)
		If Not font Then Return Null
		Local result:TImageFont = New TImageFont
		result.sourceFont = font; result.styleFlags = style | font.Style()
		result.glyphCache = New TImageGlyph[font.CountGlyphs()]
		Return result
	End Function

	Rem
	bbdoc: Loads a BRL font and wraps it for Max2D drawing.
	param: Font filename, stream URL or supported readable stream.
	param: Requested font size.
	param: Font style flags, such as SMOOTHFONT, BOLDFONT or ITALICFONT.
	End Rem
	Function Load:TImageFont(url:Object, size:Int, style:Int = SMOOTHFONT)
		Return FromFont(LoadFont(url,size,style),style)
	End Function

	Rem
	bbdoc: Returns the font's logical line height.
	End Rem
	Method Height:Int()
		If sourceFont Then Return sourceFont.Height()
		Return 16
	End Method

	Rem
	bbdoc: Returns the font style flags.
	End Rem
	Method Style:Int()
		Return styleFlags
	End Method

	Rem
	bbdoc: Adds a glyph bitmap to shared atlas storage or a standalone image.
	param: Source pixel data.
	End Rem
	Method Pack:TImage(pixmap:TPixmap)
		If Not pixmap Then Return Null
		If Not atlas Then
			Local flags:Int
			If styleFlags & SMOOTHFONT Then flags=FILTEREDIMAGE
			atlas=TTextureAtlas.Create(512,flags)
		End If
		Return atlas.AddPixmap(pixmap)
	End Method

	Rem
	bbdoc: Packs a rasterized glyph and stores its metrics in the glyph cache.
	param: Zero-based index.
	param: Rasterized glyph and metrics to cache.
	End Rem
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

	Rem
	bbdoc: Gets a cached glyph, rasterizing it when needed.
	param: Zero-based index.
	End Rem
	Method LoadGlyph:TImageGlyph(index:Int)
		If index < 0 Or index >= glyphCache.Length Then Return Null
		If glyphCache[index] Then Return glyphCache[index]
		If Not sourceFont Then Return Null
		Return CacheGlyph(index,sourceFont.LoadGlyph(index))
	End Method

	Rem
	bbdoc: Builds optional single-line caret geometry from glyph advances.
	param: Text to lay out, measure or draw.
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
	param: Text to lay out, measure or draw.
	param: Inclusive start index of the requested range.
	param: Exclusive end index of the requested range.
	param: Whether the run is shaped right to left.
	param: Script identifier understood by the shaping provider; zero selects its default.
	param: Language tag used by the text provider; empty uses its default.
	about: first/last are UTF-16 offsets in text. The returned glyph source offsets are relative to first. The base implementation supports LTR only; use ScalableFont for RTL shaping and mirrored glyphs.
	End Rem
	Method LayoutRun:TTextLayout(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="")
		If first<0 Or last<first Or last>text.Length Then Throw "Max2D: invalid directional run range"
		If rtl Then Throw "Max2D: RTL layout requires a direction-aware font (such as ScalableFont)"
		Return Layout(text[first..last])
	End Method

	Rem
	bbdoc: Builds caret positions for a directed run within a larger text string.
	param: Text to lay out, measure or draw.
	param: Inclusive start index of the requested range.
	param: Exclusive end index of the requested range.
	param: Whether the run is shaped right to left.
	param: Script identifier understood by the shaping provider; zero selects its default.
	param: Language tag used by the text provider; empty uses its default.
	End Rem
	Method CreateRunCaretMap:TTextCaretMap(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="")
		If first<0 Or last<first Or last>text.Length Then Throw "Max2D: invalid directional run range"
		If rtl Then Throw "Max2D: RTL carets require a direction-aware font"
		Return CreateCaretMap(text[first..last])
	End Method

	Rem
	bbdoc: Shapes and positions text, reusing the font's layout cache when possible.
	param: Text to lay out, measure or draw.
	End Rem
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
	param: Maximum retained text layouts; zero disables layout caching.
	End Rem
	Method SetLayoutCacheLimit(limit:Int)
		If limit<0 Then Throw "Max2D: layout cache limit cannot be negative"
		layoutCacheLimit=limit
		While layoutKeys.Count()>limit
			layouts.Remove(String(layoutKeys.RemoveFirst()))
		Wend
	End Method

	Rem
	bbdoc: Discards cached text layouts without discarding glyph images.
	End Rem
	Method ClearLayoutCache()
		layouts.Clear(); layoutKeys.Clear()
	End Method

	Rem
	bbdoc: Returns the shared built-in bitmap font.
	End Rem
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
