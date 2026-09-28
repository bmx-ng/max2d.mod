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

Type TScalablePositionedGlyph Extends TPositionedGlyph
 Field index:Int
 Field baselineX:Float,baselineY:Float
End Type

Type TScalableTextLayout Extends TTextLayout
 Field font:TScalableImageFont
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float) Override
		DrawColored(canvas,x,y,Null)
	End Method
	Method DrawColored(canvas:TMax2DGraphics,x:Float,y:Float,colors:TTextColorSpan[],colorOffset:Int=0) Override
		Local red:Int=canvas.state.red,green:Int=canvas.state.green,blue:Int=canvas.state.blue
		Local alpha:Float=canvas.state.alpha
		Try
			Local raster:TFontRaster=font.Raster(font.DrawingDensity(canvas))
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
Type TFontRaster
 Field face:Byte Ptr
 Field buffer:Byte[]
 Field density:Int
	Field atlas:TTextureAtlas=TTextureAtlas.Create(512,FILTEREDIMAGE,1,PF_A8)
 Field glyphs:TMap=New TMap
 Field glyphBuilds:Long
 Function Create:TFontRaster(data:TBank,size:Float,density:Int)
  Local result:TFontRaster=New TFontRaster
  result.density=density
  result.face=TFreeTypeFont.LoadFace(data,size*density,SMOOTHFONT,result.buffer)
  If Not result.face Then Return Null
  Return result
 End Function
 Method Delete()
  If face Then FT_Done_Face(face)
 End Method
	Method Clear()
		For Local page:TImage=EachIn atlas.pages
			page.ReleaseFrames()
		Next
		atlas=TTextureAtlas.Create(512,FILTEREDIMAGE,1,PF_A8)
		glyphs.Clear()
	End Method
	Method Glyph:TImageGlyph(index:Int)
		Local key:String=String(index)
		Local cached:TImageGlyph=TImageGlyph(glyphs.ValueForKey(key))
		If cached Then Return cached
		If FT_Load_Glyph(face,UInt(index),FT_LOAD_RENDER) Then Throw "Max2D scalable font: cannot render glyph "+index
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
 Field data:TBank
 Field logicalSize:Float
 Field baseRaster:TFontRaster
 Field hbFont:Byte Ptr,hbBuffer:Byte Ptr,hbFeatures:Byte Ptr
 Field featureCount:Int
 Field lineHeight:Float,ascender:Float
 Field rasterVariants:TMap=New TMap
 Field rasterKeys:TList=New TList
 Field rasterCacheLimit:Int=3
 Field maxDensity:Int=8

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
  result.logicalSize=size; result.styleFlags=style|SMOOTHFONT
  result.baseRaster=TFontRaster.Create(result.data,size,1)
  If Not result.baseRaster Then Return Null
  Local metrics:Byte Ptr=bmx_freetype_Face_size(result.baseRaster.face)
  result.lineHeight=bmx_freetype_Size_height(metrics)/64.0
  result.ascender=bmx_freetype_Size_ascend(metrics)/64.0
  result.hbFont=bmx_hb_ft_font_create(result.baseRaster.face)
  result.hbBuffer=bmx_hb_buffer_create()
  result.hbFeatures=bmx_hb_ft_font_features(style,result.featureCount)
  Return result
 End Function
 Method Delete()
  If hbFont Then bmx_hb_ft_font_destroy(hbFont)
  If hbBuffer Then bmx_hb_buffer_destroy(hbBuffer)
  If hbFeatures Then bmx_hb_features_destroy(hbFeatures)
 End Method
	Method Baseline:Float() Override
		Return ascender
	End Method
 Method Height:Int() Override
  Return Ceil(lineHeight)
 End Method
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
 Method Raster:TFontRaster(density:Int)
  density=Min(maxDensity,Max(1,density))
  If density=1 Then Return baseRaster
  Local key:String=String(density)
  Local result:TFontRaster=TFontRaster(rasterVariants.ValueForKey(key))
  If result Then
   rasterKeys.Remove(key); rasterKeys.AddLast(key)
   Return result
  End If
  result=TFontRaster.Create(data,logicalSize,density)
  If Not result Then Throw "Max2D scalable font: cannot create raster size"
  While rasterKeys.Count()>=rasterCacheLimit
   Local oldest:String=String(rasterKeys.RemoveFirst())
   TFontRaster(rasterVariants.ValueForKey(oldest)).Clear()
   rasterVariants.Remove(oldest)
  Wend
  rasterVariants.Insert(key,result); rasterKeys.AddLast(key)
  Return result
 End Method
 Method SetRasterCacheLimit(limit:Int)
  If limit<1 Then Throw "Max2D scalable font: raster cache limit must be positive"
  rasterCacheLimit=limit
  While rasterKeys.Count()>limit
   Local oldest:String=String(rasterKeys.RemoveFirst())
   TFontRaster(rasterVariants.ValueForKey(oldest)).Clear()
   rasterVariants.Remove(oldest)
  Wend
 End Method
 Method ClearRasterCache()
  For Local value:TFontRaster=EachIn rasterVariants.Values()
   value.Clear()
  Next
  rasterVariants.Clear(); rasterKeys.Clear()
 End Method
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
 Method ClearGlyphCache()
  ClearLayoutCache(); ClearRasterCache(); baseRaster.Clear()
 End Method
	Method CreateCaretMap:TTextCaretMap(text:String) Override
		If text.Contains("~n") Or text.Contains("~r") Or text.Contains("~t") Then Throw "Max2D: caret geometry requires a normalized single line"
		Local result:TTextCaretMap=TTextCaretMap.Create(text.Length)
		If Not bmx_hb_buffer_caret_positions(hbFont,hbBuffer,hbFeatures,featureCount,text,result.positions,result.valid) Then Throw "Max2D: unsupported caret shaping direction or cluster order"
		For Local i:Int=0 To text.Length
			result.positions[i]:/64.0
		Next
		Return result
	End Method
	Method CreateRunCaretMap:TTextCaretMap(text:String,first:Int,last:Int,rtl:Int,script:Int=0,language:String="") Override
		If first<0 Or last<first Or last>text.Length Then Throw "Max2D: invalid directional run range"
		Local result:TTextCaretMap=TTextCaretMap.Create(last-first)
		If Not bmx_hb_buffer_run_carets(hbFont,hbBuffer,hbFeatures,featureCount,text,result.positions,result.valid,first,last-first,rtl,script,language) Then Throw "Max2D: unsupported directional caret shaping"
		For Local i:Int=0 To last-first
			result.positions[i]:/64.0
		Next
		Return result
	End Method

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

Function LoadScalableImageFont:TScalableImageFont(url:Object,size:Float,style:Int=SMOOTHFONT|KERNFONT|LIGATURESFONT)
 Return TScalableImageFont.LoadScalable(url,size,style)
End Function
