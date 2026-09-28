SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
?max2d_unicode
Import Text.Unibreak
?
Import Max2D.ScalableFont
Import BRL.StandardIO
?osx And max2d_gl
Import "gl_hidpi_mode.m"
Extern "C"
	Function max2d_test_gl_lowdpi()
End Extern
?

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
If AppArgs.Length<2 Then Throw "Supply NotoSans-Regular.ttf (and optionally an Arabic-capable font)"
Local font:TScalableImageFont=LoadScalableImageFont(AppArgs[1],18)
Check(font<>Null,"Load scalable font")
Local layout:TTextLayout=font.Layout("office AV x́ Ωμέγα")
Local width:Float=layout.width,height:Float=layout.height
Check(width>0 And height>0,"Logical text metrics")
Check(font.Layout("office").glyphs.Length<6,"Real-font ligature shaping")
Check(font.Layout("AV").width<font.Layout("A").width+font.Layout("V").width,"Real-font kerning")
Local marks:TTextLayout=font.Layout("x́")
Check(marks.glyphs.Length=2,"Combining mark remains separately positioned")
Check(Abs(marks.glyphs[1].y)<font.Height()*2,"Mark offsets use pixels, not fixed-point units")
For Local glyph:TScalablePositionedGlyph=EachIn font.Layout("Ωμέγα").glyphs
	Check(glyph.index<>0,"Greek glyph coverage")
Next
If AppArgs.Length>2 Then
	Local arabic:TScalableImageFont=LoadScalableImageFont(AppArgs[2],18)
	Check(arabic<>Null,"Arabic font load")
	Local shaped:TTextLayout=arabic.Layout("سلام")
	Check(shaped.width>0 And shaped.glyphs.Length>0,"Arabic shaping")
	For Local glyph:TScalablePositionedGlyph=EachIn shaped.glyphs
		Check(glyph.index<>0,"Arabic glyph coverage")
	Next
End If

Local graphics:TGraphics=Graphics(400,240,0,0)
?osx And max2d_gl
	max2d_test_gl_lowdpi()
	TMax2DGraphics.Current().context.ApplyView()
?
Check(graphics<>Null,"Graphics creation")
SetImageFont(font)
SetVirtualResolution(100,60)
SetClsColor(0,0,0); Cls()
DrawTextLayout(layout,2,2)
Check(font.DrawingDensity(TMax2DGraphics.Current())=4,"Virtual scale selects 4x raster")
Local high:TFontRaster=font.Raster(4)
Check(Not high.glyphs.IsEmpty(),"High-resolution glyphs rasterized")
Local first:TScalablePositionedGlyph=TScalablePositionedGlyph(layout.glyphs[0])
Check(high.Glyph(first.index).image.width>first.image.width*2,"High density uses newly rasterized glyph pixels")
Local pixels:TPixmap=GrabPixmap(0,0,400,240)
Local lit:Int
For Local y:Int=0 Until pixels.height
	For Local x:Int=0 Until pixels.width
		If pixels.ReadPixel(x,y)&$ffffff Then lit:+1
	Next
Next
Check(lit>100,"Text draws actual pixels")
PushMax2DState()
SetNativeResolution()
Check(font.DrawingDensity(TMax2DGraphics.Current())=1,"Native overlay selects 1x raster")
DrawTextLayout(layout,10,150)
Check(TextWidth("office AV x́ Ωμέγα")=Ceil(width),"Measurement stable in native overlay")
ScaleCoordinates(2,3)
Check(font.DrawingDensity(TMax2DGraphics.Current())=3,"Parent coordinates select font density")
ResetCoordinates()
SetScale(1,2)
Check(font.DrawingDensity(TMax2DGraphics.Current())=2,"Anisotropic transform density")
SetAffineTransform(1,2,0,1)
Check(font.DrawingDensity(TMax2DGraphics.Current())=3,"Shear density uses maximum magnification")
PopMax2DState()
Check(layout.width=width And layout.height=height,"Layout unchanged after DPI/transform changes")
PushMax2DState()
Local camera:TCamera2D=New TCamera2D
camera.zoom=2;camera.rotation=37
SetCamera(camera)
Check(font.DrawingDensity(TMax2DGraphics.Current())=8,"Camera zoom selects higher raster density")
DrawTextLayout(layout,2,2)
Check(layout.width=width And layout.height=height,"Camera does not change text layout metrics")
PopMax2DState()
Local prepared:TPreparedText=PrepareText("office AV office AV office AV",font)
Local paragraph:TParagraphLayout=prepared.Layout(font.Layout("office AV").width+0.01,TEXT_ALIGN_CENTER)
Check(paragraph.lines.Length=3,"Scalable paragraph wraps shaped lines")
Check(paragraph.lines[0].layout.glyphs.Length=font.Layout("office AV").glyphs.Length,"Paragraph retains shaped ligatures")
Local builds:Long=font.layoutBuilds
For Local repeat:Int=0 Until 20
	DrawTextLayout(paragraph,2,2)
	Check(prepared.Layout(paragraph.boxWidth,TEXT_ALIGN_CENTER)=paragraph,"Scalable warm paragraph identity")
Next
Check(font.layoutBuilds=builds And prepared.reflowBuilds=1,"Scalable drawing does not reshape paragraphs")
Local fitted:TParagraphLayout=prepared.LayoutBox(paragraph.boxWidth,paragraph.lines[0].layout.height,TEXT_ALIGN_CENTER)
Check(fitted.truncated And fitted.lines.Length=1,"Scalable box height truncation")
Check(fitted.width<=fitted.boxWidth,"Scalable ellipsis fits measured advance")
Check(fitted.lines[0].layout=font.Layout(fitted.lines[0].text),"Ellipsis uses whole-line shaping")
DrawTextLayout(fitted,2,2)
?max2d_unicode
Local discretionary:TPreparedText=PrepareText("co"+Chr($ad)+"operate",font)
Local wrapped:TParagraphLayout=discretionary.Layout(font.Layout("co-").width+0.01)
Check(wrapped.lines[0].text="co-","Unicode break inserts a shaped discretionary hyphen")
DrawTextLayout(wrapped,2,2)
Check(discretionary.Layout(1000).lines[0].text="cooperate","Unbroken real-font text omits soft hyphen")
?
Local oldBounds:Float=layout.boundsWidth
font.SetRasterCacheLimit(1)
font.Raster(2)
Check(font.RasterCacheCount()=2,"Raster variants bounded, plus base metrics")
DrawTextLayout(layout,2,2)
font.ClearGlyphCache()
DrawTextLayout(layout,2,2)
FlushMax2D()
Check(layout.boundsWidth=oldBounds And layout.width=width,"Retained layout survives cache clear")
Check(font.baseRaster.glyphs.IsEmpty(),"Drawing high-resolution retained layout does not rebuild base glyph cache")
font.SetMaxRasterDensity(2)
Check(font.DrawingDensity(TMax2DGraphics.Current())=2,"Explicit raster density cap")
DrawTextLayout(layout,2,2)
FlushMax2D()
EndGraphics()
Print "Max2D scalable text tests passed"
