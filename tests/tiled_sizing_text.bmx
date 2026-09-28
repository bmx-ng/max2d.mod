SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Tiled
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
	Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Type TBlockFont Extends TImageFont
	Field image:TImage
	Method Height:Int() Override
		Return 4
	End Method
	Method Baseline:Float() Override
		Return 3
	End Method
	Method Layout:TTextLayout(text:String) Override
		Local result:TTextLayout=New TTextLayout
		result.width=text.Length*4; result.height=4
		result.glyphs=New TPositionedGlyph[text.Length]
		For Local i:Int=0 Until text.Length
			Local glyph:TPositionedGlyph=New TPositionedGlyph
			If text[i]<>32 Then glyph.image=image
			glyph.x=i*4; result.glyphs[i]=glyph
		Next
		Return result
	End Method
End Type
Type TTestFonts Extends TTiledFontResolver
	Field font:TBlockFont,calls:Int
	Method Resolve:TImageFont(family:String,pixelSize:Int,bold:Int,italic:Int,kerning:Int) Override
		calls:+1
		Return font
	End Method
End Type
Try
	Local fonts:TTestFonts=New TTestFonts
	fonts.font=New TBlockFont
	Local pixels:TPixmap=CreatePixmap(4,4,PF_RGBA8888)
	pixels.ClearPixels($ffffffff); fonts.font.image=TImage.FromPixmap(pixels)
	Graphics 64,64
	Local target:TRenderImage=CreateRenderImage(64,64,0)
	SetRenderImage(target); SetClsColor(0,0,0)
	For Local extension:String=EachIn ["tmx","tmj"]
		Local map:TTiledMap=LoadTiledMap(AppArgs[1]+"/sizing-text."+extension,0,"",Null,fonts)
		Local naturalAnimation:TTileDefinition=map.tileset.tiles[map.importedTilesets[2].NativeID(0)]
		Check(naturalAnimation.drawWidth=4 And naturalAnimation.drawHeight=2 And naturalAnimation.offsetY=7,"Natural animation uses frame dimensions, not static preview dimensions")
		Local gridAnimation:TTileDefinition=map.tileset.tiles[map.importedTilesets[3].NativeID(0)]
		Check(gridAnimation.drawWidth=8 And gridAnimation.drawHeight=8 And gridAnimation.offsetX=2 And gridAnimation.offsetY=4,"Grid animation retains canvas and scales offsets using frame dimensions")
		Local fit:TTileLayer=map.layers[1]
		Local id:Int=fit.Cell(0,0)
		Check(map.tileset.tiles[id].drawWidth=8 And map.tileset.tiles[id].drawHeight=8,"Grid display size")
		Local l:Double,t:Double,r:Double,b:Double
		Local shape:STileObjectInstance=map.CellCollision(fit,0,0,0)
		shape.Bounds(l,t,r,b)
		Check(l=16 And r=24 And t=2 And b=6,"Aspect-fit collision scaling and padding")
		shape=map.CellCollision(fit,1,0,0); shape.Bounds(l,t,r,b)
		Check(l=26 And r=30 And t=0 And b=8,"Diagonal resized collision")
		Check(map.QueryTileCollisions(fit,16,2,1,1).count=1,"Scaled collision query envelope")
		Local label:TTileText=map.ObjectByID(3).text
		Check(label.text="AB CD" And label.bold And label.italic And Not label.kerning And label.fontFamily="Test","Text metadata and JSON content")
		Local builds:Int=label.layoutBuilds
		For Local mode:ETileSort=EachIn [ETileSort.Grid,ETileSort.GroundDepth]
			fit.sortMode=mode
			Cls(); map.Draw()
			Check(Pixel(0,0)=$ff0000 And Pixel(7,7)=$00ff00,"Stretched cell")
			Check(Pixel(16,0)=0 And Pixel(16,2)=$ff0000 And Pixel(23,5)=$00ff00 And Pixel(16,6)=0,"Fitted cell with padding")
			Check(Pixel(24,0)=0 And Pixel(26,0)=$ff0000 And Pixel(29,7)=$00ff00,"Fitted diagonal cell")
			Check(Pixel(0,16)=0 And Pixel(0,18)=$ff0000 And Pixel(7,21)=$00ff00,"Aspect-fit tile object")
			Check(Pixel(16,16)=0 And Pixel(18,16)=$ff0000,"Aspect-fit diagonal object")
			Check(Abs((Pixel(32,2) Shr 16)-128)<=1 And Pixel(32,0)=0 And Pixel(32,10)=0,"Wrapped vertically centred text colour/alpha")
			Check(Pixel(46,17)=$ffffff And Pixel(46,15)=0 And Pixel(46,24)=0,"Rotated text clips overflowing glyphs in object coordinates")
		Next
		Check(label.layoutBuilds=builds And map.drawnTexts=2,"Text layout retained across draws")
		Cls(); map.Draw(0,0,100)
		Check(Pixel(0,0)=$0000ff And Pixel(16,2)=$0000ff,"Resized animations keep display canvas")
		label.text="AB"; Cls(); map.Draw()
		Check(label.layoutBuilds=builds+1,"Changed text rebuilds layout once")
		label.underline=True; label.strikeout=True; label.red=255; label.green=255; label.blue=255; label.alpha=1
		label.verticalAlignment=TEXT_ALIGN_BOTTOM; Cls(); map.Draw()
		Check(Pixel(32,8)=$ffffff And Pixel(31,8)=0 And Pixel(40,8)=0,"Decorated text obeys local box")
	Next
	Check(fonts.calls=4,"Resolver called during import only")
	SetRenderImage(Null); EndGraphics()
	Print "Tiled sizing and text tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
