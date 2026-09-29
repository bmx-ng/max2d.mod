SuperStrict
Rem
bbdoc: Scalable text with stable logical layouts and resolution-specific glyph atlases.
End Rem
Module Max2D.ScalableFont
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Core
Import Text.HBFreeTypeFont
Import BRL.Bank

Rem
bbdoc: A positioned glyph retaining its scalable font and glyph index for density-aware drawing.
End Rem
Type TScalablePositionedGlyph Extends TPositionedGlyph

	Rem
	bbdoc: Glyph index in the font face.
	End Rem
	Field index:Int

	Rem
	bbdoc: Horizontal glyph position relative to the text baseline.
	End Rem
	Field baselineX:Float

	Rem
	bbdoc: Vertical glyph position relative to the text baseline.
	End Rem
	Field baselineY:Float
End Type

Rem
bbdoc: Retained logical glyph positions that select raster density when drawn.
End Rem
Type TScalableTextLayout Extends TTextLayout

	Rem
	bbdoc: Font used to shape and draw this text.
	End Rem
	Field font:TScalableImageFont

	Rem
	bbdoc: Draws text with glyph rasters suited to the current drawing density.
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
		Local red:Int=canvas.state.red,green:Int=canvas.state.green,blue:Int=canvas.state.blue
		Local alpha:Float=canvas.state.alpha
		Try
			Local raster:TFontRaster=font.Raster(font.DrawingDensity(canvas))
			Local state:TMax2DState=canvas.state
			Local a:Double,b:Double,c:Double,d:Double
			Local tx:Double,ty:Double
			Local align:Int
			If font.pixelAligned Then
				state.DrawingMatrix(a,b,c,d)
				a:*canvas.context.pixelScaleX
				b:*canvas.context.pixelScaleX
				c:*canvas.context.pixelScaleY
				d:*canvas.context.pixelScaleY
				' Snap only when an axis-aligned raster texel maps to one target pixel.
				align=Abs(b)<0.000001 And Abs(c)<0.000001 And Abs(Abs(a)-raster.density)<0.000001 And Abs(Abs(d)-raster.density)<0.000001
				If align Then
					Local originX:Double=x+state.originX
					Local originY:Double=y+state.originY
					tx=state.coordXX*originX+state.coordXY*originY+state.coordTX
					ty=state.coordYX*originX+state.coordYY*originY+state.coordTY
					If state.camera Then
						Local worldX:Double=tx,worldY:Double=ty
						tx=state.cameraXX*worldX+state.cameraXY*worldY+state.cameraTX
						ty=state.cameraYX*worldX+state.cameraYY*worldY+state.cameraTY
					End If
					tx=tx*canvas.context.pixelScaleX+canvas.context.pixelOffsetX
					ty=ty*canvas.context.pixelScaleY+canvas.context.pixelOffsetY
				End If
			End If
			For Local glyphIndex:Int=0 Until glyphs.Length
				Local item:TScalablePositionedGlyph=TScalablePositionedGlyph(glyphs[glyphIndex])
				If colors Then TTextPaint.Apply(canvas.state,colors[colorOffset+glyphIndex],red,green,blue,alpha)
				Local glyph:TImageGlyph=raster.Glyph(item.index)
				Local image:TImage=glyph.image
				If Not image Then Continue
				Local frame:TImageFrame=image.Frame(0,canvas)
				Local source:TImageSource=image.sources[0]
				Local u:Float=image.sourceX[0]/Float(source.width),v:Float=image.sourceY[0]/Float(source.height)
				Local gx:Float=item.baselineX+glyph.x/Float(raster.density)-canvas.state.handleX
				Local gy:Float=item.baselineY+glyph.y/Float(raster.density)-canvas.state.handleY
				If align Then
					Local px:Double=a*gx+tx
					Local py:Double=d*gy+ty
					gx:+Float((Floor(px+0.5)-px)/a)
					gy:+Float((Floor(py+0.5)-py)/d)
				End If
				canvas.Quad(frame,gx,gy,gx+image.width/Float(raster.density),gy+image.height/Float(raster.density),..
					x+canvas.state.originX,y+canvas.state.originY,u,v,u+image.width/Float(source.width),v+image.height/Float(source.height))
			Next
		Catch error:Object
			canvas.state.red=red;canvas.state.green=green;canvas.state.blue=blue;canvas.state.alpha=alpha
			Throw error
		End Try
		canvas.state.red=red;canvas.state.green=green;canvas.state.blue=blue;canvas.state.alpha=alpha
	End Method

End Type

' Faces retain their own input buffer; native texture deletion stays with the context.

Rem
bbdoc: Glyph atlas and FreeType face for one raster density of a scalable font.
End Rem
Type TFontRaster

	Rem
	bbdoc: Native FreeType face owned by this rasterizer.
	End Rem
	Field face:Byte Ptr

	Rem
	bbdoc: Reusable glyph-raster pixel buffer.
	End Rem
	Field buffer:Byte[]

	Rem
	bbdoc: Raster pixels per logical font unit.
	End Rem
	Field density:Int

	Rem
	bbdoc: Shared texture atlas containing artwork or glyph images.
	End Rem
	Field atlas:TTextureAtlas=TTextureAtlas.Create(512,FILTEREDIMAGE,1,PF_A8)

	Rem
	bbdoc: Whether glyphs use antialiased coverage and linear texture filtering.
	End Rem
	Field smooth:Int=True

	Rem
	bbdoc: Glyph images cached by native glyph index.
	End Rem
	Field glyphs:TMap=New TMap

	Rem
	bbdoc: Number of glyphs rasterized instead of retrieved from cache.
	End Rem
	Field glyphBuilds:Long

	Rem
	bbdoc: Creates a rasterizer from font bytes at a logical size and pixel density.
	param: Font-file bytes retained while the native face is alive.
	param: Requested font size.
	param: Number of raster pixels per logical font unit.
	param: Font flags; omit SMOOTHFONT for monochrome glyphs and nearest-neighbour sampling.
	End Rem
	Function Create:TFontRaster(data:TBank,size:Float,density:Int,style:Int=SMOOTHFONT)
		Local result:TFontRaster=New TFontRaster
		result.density=density
		result.smooth=(style & SMOOTHFONT)<>0
		Local flags:Int
		If result.smooth Then flags=FILTEREDIMAGE
		result.atlas=TTextureAtlas.Create(512,flags,1,PF_A8)
		result.face=TFreeTypeFont.LoadFace(data,size*density,style,result.buffer)
		If Not result.face Then Return Null
		Return result
	End Function

	Rem
	bbdoc: Releases the rasterizer's native font face.
	End Rem
 Method Delete()
  If face Then FT_Done_Face(face)
 End Method

	Rem
	bbdoc: Discards cached glyph images for this raster density.
	End Rem
	Method Clear()
		For Local page:TImage=EachIn atlas.pages
			page.ReleaseFrames()
		Next
		Local flags:Int
		If smooth Then flags=FILTEREDIMAGE
		atlas=TTextureAtlas.Create(512,flags,1,PF_A8)
		glyphs.Clear()
	End Method

	Rem
	bbdoc: Gets or rasterizes a glyph at this raster density.
	param: Zero-based index.
	End Rem
	Method Glyph:TImageGlyph(index:Int)
		Local key:String=String(index)
		Local cached:TImageGlyph=TImageGlyph(glyphs.ValueForKey(key))
		If cached Then Return cached
		Local loadFlags:Int=FT_LOAD_RENDER
		If Not smooth Then loadFlags:|FT_LOAD_MONOCHROME
		If FT_Load_Glyph(face,UInt(index),loadFlags) Then Throw "Max2D scalable font: cannot render glyph "+index
		Local slot:Byte Ptr=bmx_freetype_Face_glyph(face)
		Local w:Int=bmx_freetype_Slot_bitmap_width(slot),h:Int=bmx_freetype_Slot_bitmap_rows(slot)
		cached=New TImageGlyph
		cached.x=bmx_freetype_Slot_bitmapleft(slot)-1
		cached.y=-bmx_freetype_Slot_bitmaptop(slot)-1
		If w>0 And h>0 Then
			Local mode:Int=bmx_freetype_Slot_bitmap_pixelmode(slot)
			If mode<>FT_PIXEL_MODE_GRAY And mode<>FT_PIXEL_MODE_MONO Then Throw "Max2D scalable font: unsupported glyph pixel format"
			Local pixmap:TPixmap=CreatePixmap(w+2,h+2,PF_A8)
			pixmap.ClearPixels($00ffffff)
			Local bytes:Byte Ptr=bmx_freetype_Slot_bitmap_buffer(slot)
			Local pitch:Int=bmx_freetype_Slot_bitmap_pitch(slot)
			For Local y:Int=0 Until h
				Local row:Byte Ptr=bytes+y*pitch
				For Local x:Int=0 Until w
					Local alpha:Int
					If mode=FT_PIXEL_MODE_GRAY Then
						alpha=row[x]
					Else
						If row[x/8] & (128 Shr (x Mod 8)) Then alpha=255
					End If
					pixmap.WritePixel(x+1,y+1,(alpha Shl 24)|$ffffff)
				Next
			Next
			cached.image=atlas.AddPixmap(pixmap)
			cached.w=w+2
			cached.h=h+2
		End If
		glyphs.Insert(key,cached)
		glyphBuilds:+1
		Return cached
	End Method

End Type

Rem
bbdoc: A logical-size font that selects glyph resolution at drawing time.
about: Logical layouts stay unchanged across DPI, target, and transform changes. Higher-resolution raster caches use LRU eviction.
End Rem
Type TScalableImageFont Extends TImageFont

	Rem
	bbdoc: Aligns glyph artwork to physical pixels when enabled; defaults to False.
	about: Applies only to axis-aligned drawing with one raster texel per target pixel.
	Other transforms keep fractional positioning. Layout, wrapping and interaction
	coordinates are unchanged. Enable for stationary text; leave disabled for smooth motion.
	End Rem
	Field pixelAligned:Int


	Rem
	bbdoc: Font-file bytes retained while native shaping and raster faces use them.
	End Rem
	Field data:TBank

	Rem
	bbdoc: Requested font size in logical drawing units.
	End Rem
	Field logicalSize:Float

	Rem
	bbdoc: Base-density raster used for font metrics and shaping.
	End Rem
	Field baseRaster:TFontRaster

	Rem
	bbdoc: Native HarfBuzz font handle owned by this font.
	End Rem
	Field hbFont:Byte Ptr

	Rem
	bbdoc: Reusable native HarfBuzz shaping buffer.
	End Rem
	Field hbBuffer:Byte Ptr

	Rem
	bbdoc: Native array of shaping features enabled by the font style.
	End Rem
	Field hbFeatures:Byte Ptr

	Rem
	bbdoc: Number of active HarfBuzz shaping features.
	End Rem
	Field featureCount:Int

	Rem
	bbdoc: Natural logical distance between text baselines.
	End Rem
	Field lineHeight:Float

	Rem
	bbdoc: Logical distance above the font baseline.
	End Rem
	Field ascender:Float

	Rem
	bbdoc: Cached glyph rasterizers indexed by drawing density.
	End Rem
	Field rasterVariants:TMap=New TMap

	Rem
	bbdoc: Order used to evict cached raster densities.
	End Rem
	Field rasterKeys:TList=New TList

	Rem
	bbdoc: Maximum number of retained raster-density variants.
	End Rem
	Field rasterCacheLimit:Int=3

	Rem
	bbdoc: Maximum raster pixels per logical font unit.
	End Rem
	Field maxDensity:Int=8

	Rem
	bbdoc: Loads a font whose glyph raster density follows the drawing scale.
	param: Font filename, stream URL or supported readable stream.
	param: Requested font size.
	param: SMOOTHFONT, KERNFONT and LIGATURESFONT flags; omit SMOOTHFONT for monochrome glyphs.
	End Rem
	Function LoadScalable:TScalableImageFont(url:Object,size:Float,style:Int=SMOOTHFONT|KERNFONT|LIGATURESFONT)
		If Not (size>0 And size<=512) Then Throw "Max2D scalable font: logical size must be in (0,512]"
		If style & (BOLDFONT|ITALICFONT) Then Throw "Max2D scalable font: load a bold or italic font face instead of synthetic style flags"
		Local input:TBank=TBank(url)
		If Not input Then input=LoadBank(url)
		If Not input Then Return Null
		Local result:TScalableImageFont=New TScalableImageFont
		If input.Size()>$7fffffff Then Throw "Max2D scalable font: font data is too large"
		result.data=CreateBank(Int(input.Size()))
		CopyBank(input,0,result.data,0,input.Size())
		result.logicalSize=size
		result.styleFlags=style
		result.baseRaster=TFontRaster.Create(result.data,size,1,style)
		If Not result.baseRaster Then Return Null
		Local metrics:Byte Ptr=bmx_freetype_Face_size(result.baseRaster.face)
		result.lineHeight=bmx_freetype_Size_height(metrics)/64.0
		result.ascender=bmx_freetype_Size_ascend(metrics)/64.0
		result.hbFont=bmx_hb_ft_font_create(result.baseRaster.face)
		result.hbBuffer=bmx_hb_buffer_create()
		result.hbFeatures=bmx_hb_ft_font_features(style,result.featureCount)
		Return result
	End Function

	Rem
	bbdoc: Releases native shaping and raster resources held by this font.
	End Rem
 Method Delete()
  If hbFont Then bmx_hb_ft_font_destroy(hbFont)
  If hbBuffer Then bmx_hb_buffer_destroy(hbBuffer)
  If hbFeatures Then bmx_hb_features_destroy(hbFeatures)
 End Method

	Rem
	bbdoc: Returns the logical distance from the text origin to the font baseline.
	End Rem
	Method Baseline:Float() Override
		Return ascender
	End Method

	Rem
	bbdoc: Returns the font's logical line height.
	End Rem
 Method Height:Int() Override
  Return Ceil(lineHeight)
 End Method

	Rem
	bbdoc: Chooses glyph pixel density from the canvas transforms and output scale.
	param: Drawing canvas whose state and rendering context are used.
	End Rem
 Method DrawingDensity:Int(canvas:TMax2DGraphics)
  ' Largest singular value includes anisotropic scale, rotation, reflection and shear.
  Local state:TMax2DState=canvas.state
  Local a:Double,b:Double,c:Double,d:Double
  state.DrawingMatrix(a,b,c,d)
  a:*canvas.context.pixelScaleX;b:*canvas.context.pixelScaleX
  c:*canvas.context.pixelScaleY;d:*canvas.context.pixelScaleY
  Local trace:Double=a*a+b*b+c*c+d*d,determinant:Double=a*d-b*c
  Local scale:Double=Sqr((trace+Sqr(Max(0.0,trace*trace-4*determinant*determinant)))*0.5)
  Return Max(1,Int(Ceil(Min(Double(maxDensity),scale))))
 End Method

	Rem
	bbdoc: Gets or creates the cached glyph rasterizer for a pixel density.
	param: Number of raster pixels per logical font unit.
	End Rem
	Method Raster:TFontRaster(density:Int)
		density=Min(maxDensity,Max(1,density))
		If density=1 Then Return baseRaster
		Local key:String=String(density)
		Local result:TFontRaster=TFontRaster(rasterVariants.ValueForKey(key))
		If result Then
			rasterKeys.Remove(key); rasterKeys.AddLast(key)
			Return result
		End If
		result=TFontRaster.Create(data,logicalSize,density,styleFlags)
		If Not result Then Throw "Max2D scalable font: cannot create raster size"
		While rasterKeys.Count()>=rasterCacheLimit
			Local oldest:String=String(rasterKeys.RemoveFirst())
			TFontRaster(rasterVariants.ValueForKey(oldest)).Clear()
			rasterVariants.Remove(oldest)
		Wend
		rasterVariants.Insert(key,result); rasterKeys.AddLast(key)
		Return result
	End Method

	Rem
	bbdoc: Limits the number of cached raster densities.
	param: Maximum cached raster variants; must be at least one.
	End Rem
 Method SetRasterCacheLimit(limit:Int)
  If limit<1 Then Throw "Max2D scalable font: raster cache limit must be positive"
  rasterCacheLimit=limit
  While rasterKeys.Count()>limit
   Local oldest:String=String(rasterKeys.RemoveFirst())
   TFontRaster(rasterVariants.ValueForKey(oldest)).Clear()
   rasterVariants.Remove(oldest)
  Wend
 End Method

	Rem
	bbdoc: Discards cached raster densities and their glyph images.
	End Rem
 Method ClearRasterCache()
  For Local value:TFontRaster=EachIn rasterVariants.Values()
   value.Clear()
  Next
  rasterVariants.Clear(); rasterKeys.Clear()
 End Method

	Rem
	bbdoc: Caps the pixel density used for future glyph rasterization.
	param: Number of raster pixels per logical font unit.
	End Rem
 Method SetMaxRasterDensity(density:Int)
  If density<1 Or density>16 Then Throw "Max2D scalable font: maximum raster density must be 1 to 16"
  maxDensity=density
  ClearRasterCache()
 End Method

 Rem
 bbdoc: Number of retained raster resolutions, including the 1x metric raster.
 End Rem
 Method RasterCacheCount:Int()
  Return 1+rasterKeys.Count()
 End Method

 Rem
 bbdoc: Number of atlas pages currently owned by the font's raster caches.
 about: Application-held layouts may keep older base pages alive after ClearGlyphCache.
 End Rem
 Method RasterPageCount:Int()
  Local count:Int=baseRaster.atlas.PageCount()
  For Local raster:TFontRaster=EachIn rasterVariants.Values()
   count:+raster.atlas.PageCount()
  Next
  Return count
 End Method

	Rem
	bbdoc: Discards glyph rasters while keeping logical text layouts.
	End Rem
 Method ClearGlyphCache()
  ClearLayoutCache(); ClearRasterCache(); baseRaster.Clear()
 End Method

	Rem
	bbdoc: Builds caret positions at supported text-cluster boundaries.
	param: Text to lay out, measure or draw.
	End Rem
	Method CreateCaretMap:TTextCaretMap(text:String) Override
		If text.Contains("~n") Or text.Contains("~r") Or text.Contains("~t") Then Throw "Max2D: caret geometry requires a normalized single line"
		Local result:TTextCaretMap=TTextCaretMap.Create(text.Length)
		If Not bmx_hb_buffer_caret_positions(hbFont,hbBuffer,hbFeatures,featureCount,text,result.positions,result.valid) Then Throw "Max2D: unsupported caret shaping direction or cluster order"
		For Local i:Int=0 To text.Length
			result.positions[i]:/64.0
		Next
		Return result
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
	Method CreateRunCaretMap:TTextCaretMap(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="") Override
		If first<0 Or last<first Or last>text.Length Then Throw "Max2D: invalid directional run range"
		Local result:TTextCaretMap=TTextCaretMap.Create(last-first)
		If Not bmx_hb_buffer_run_carets(hbFont,hbBuffer,hbFeatures,featureCount,text,result.positions,result.valid,first,last-first,rtl,script,language) Then Throw "Max2D: unsupported directional caret shaping"
		For Local i:Int=0 To last-first
			result.positions[i]:/64.0
		Next
		Return result
	End Method

	Rem
	bbdoc: Shapes a directed source range with its script and language context.
	param: Text to lay out, measure or draw.
	param: Inclusive start index of the requested range.
	param: Exclusive end index of the requested range.
	param: Whether the run is shaped right to left.
	param: Script identifier understood by the shaping provider; zero selects its default.
	param: Language tag used by the text provider; empty uses its default.
	End Rem
	Method LayoutRun:TTextLayout(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="") Override
		If first<0 Or last<first Or last>text.Length Then Throw "Max2D: invalid directional run range"
		Local result:TScalableTextLayout=New TScalableTextLayout
		result.font=Self;result.rightToLeft=rtl;result.height=lineHeight
		Local count:Int
		Local infos:SGlyphPosition Ptr=bmx_hb_buffer_calc_run_info(hbFont,hbBuffer,hbFeatures,featureCount,text,count,first,last-first,rtl,script,language)
		Local positioned:TList=New TList
		Local penX:Float,penY:Float
		Try
			For Local i:Int=0 Until count
				Local info:SGlyphPosition=infos[i]
				Local glyph:TImageGlyph=baseRaster.Glyph(info.glyphIndex)
				If glyph.image Then
					Local item:TScalablePositionedGlyph=New TScalablePositionedGlyph
					item.sourceOffset=bmx_hb_buffer_glyph_cluster(hbBuffer,i)-first
					item.index=info.glyphIndex;item.image=glyph.image
					item.baselineX=penX+info.xOffset/64.0
					item.baselineY=ascender+penY-info.yOffset/64.0
					item.x=item.baselineX+glyph.x;item.y=item.baselineY+glyph.y
					positioned.AddLast(item)
				End If
				penX:+info.xAdvance/64.0;penY:-info.yAdvance/64.0
			Next
		Catch error:Object
			bmx_hb_buffer_calc_glyphs_info_destroy(infos)
			Throw error
		End Try
		bmx_hb_buffer_calc_glyphs_info_destroy(infos)
		result.width=penX
		result.glyphs=New TPositionedGlyph[positioned.Count()]
		Local index:Int
		For Local item:TPositionedGlyph=EachIn positioned
			result.glyphs[index]=item;index:+1
		Next
		result.CalculateBounds();layoutBuilds:+1
		Return result
	End Method

	Rem
	bbdoc: Shapes text with logical metrics independent of the current output density.
	param: Text to lay out, measure or draw.
	End Rem
 Method Layout:TTextLayout(text:String) Override
  Local cached:TTextLayout=TTextLayout(layouts.ValueForKey(text))
  If cached Then
   layoutKeys.Remove(text); layoutKeys.AddLast(text)
   Return cached
  End If
  Local result:TScalableTextLayout=New TScalableTextLayout
  result.font=Self
  Local positioned:TList=New TList
  Local baseline:Float=ascender
  For Local line:String=EachIn text.Replace("~t","    ").Split("~n")
   If line.EndsWith("~r") Then line=line[..line.Length-1]
   Local count:Int
   Local infos:SGlyphPosition Ptr=bmx_hb_buffer_calc_glyphs_info(hbFont,hbBuffer,hbFeatures,featureCount,line,count)
   Local penX:Float,penY:Float
			result.rightToLeft=bmx_hb_buffer_is_rtl(hbBuffer)
   Try
    For Local i:Int=0 Until count
     Local info:SGlyphPosition=infos[i]
     Local glyph:TImageGlyph=baseRaster.Glyph(info.glyphIndex)
     If glyph.image Then
      Local item:TScalablePositionedGlyph=New TScalablePositionedGlyph
						item.sourceOffset=bmx_hb_buffer_glyph_cluster(hbBuffer,i)
      item.index=info.glyphIndex; item.image=glyph.image
      item.baselineX=penX+info.xOffset/64.0
      item.baselineY=baseline+penY-info.yOffset/64.0
      item.x=item.baselineX+glyph.x; item.y=item.baselineY+glyph.y
      positioned.AddLast(item)
     End If
     penX:+info.xAdvance/64.0; penY:-info.yAdvance/64.0
    Next
   Catch error:Object
    bmx_hb_buffer_calc_glyphs_info_destroy(infos)
    Throw error
   End Try
   bmx_hb_buffer_calc_glyphs_info_destroy(infos)
   result.width=Max(result.width,penX)
   result.height:+lineHeight; baseline:+lineHeight
  Next
  result.glyphs=New TPositionedGlyph[positioned.Count()]
  Local i:Int
  For Local item:TPositionedGlyph=EachIn positioned
   result.glyphs[i]=item; i:+1
  Next
  result.CalculateBounds()
  If layoutCacheLimit>0 Then
   While layoutKeys.Count()>=layoutCacheLimit
    layouts.Remove(String(layoutKeys.RemoveFirst()))
   Wend
   layouts.Insert(text,result); layoutKeys.AddLast(text)
  End If
  layoutBuilds:+1
  Return result
 End Method

End Type

Rem
bbdoc: Loads a density-aware image font for crisp text under scaling and high-DPI output.
param: Font filename, stream URL or supported readable stream.
param: Requested font size.
param: SMOOTHFONT, KERNFONT and LIGATURESFONT flags; omit SMOOTHFONT for monochrome glyphs.
End Rem
Function LoadScalableImageFont:TScalableImageFont(url:Object,size:Float,style:Int=SMOOTHFONT|KERNFONT|LIGATURESFONT)
 Return TScalableImageFont.LoadScalable(url,size,style)
End Function
