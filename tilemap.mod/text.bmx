
Rem
bbdoc: Retained text attached to a map object. Assign a font at the requested pixel size, or leave Null for the scaled built-in fallback.
about: The object rectangle controls layout and clipping. Prepare caches layout; changing text, font, size or layout settings rebuilds it on the next draw. Font family/bold/italic/kerning describe the requested face for application resolvers.
End Rem
Type TTileText

	Rem
	bbdoc: Text represented by this layout or imported object.
	End Rem
	Field text:String

	Rem
	bbdoc: Requested font family name from the map document.
	End Rem
	Field fontFamily:String="sans-serif"

	Rem
	bbdoc: Requested logical font size.
	End Rem
	Field pixelSize:Int=16

	Rem
	bbdoc: Whether a bold font face is requested.
	End Rem
	Field bold:Int

	Rem
	bbdoc: Whether an italic font face is requested.
	End Rem
	Field italic:Int

	Rem
	bbdoc: Whether an underline decoration is drawn.
	End Rem
	Field underline:Int

	Rem
	bbdoc: Whether a strike-through decoration is drawn.
	End Rem
	Field strikeout:Int

	Rem
	bbdoc: Whether pair kerning is requested for the font.
	End Rem
	Field kerning:Int=True

	Rem
	bbdoc: Whether text wraps to the object's width.
	End Rem
	Field wrap:Int

	Rem
	bbdoc: Horizontal text alignment.
	End Rem
	Field alignment:Int=TEXT_ALIGN_LEFT

	Rem
	bbdoc: Vertical alignment within a fitted text box.
	End Rem
	Field verticalAlignment:Int=TEXT_ALIGN_TOP

	Rem
	bbdoc: Whether eligible wrapped lines distribute spare width between words.
	End Rem
	Field justify:Int

	Rem
	bbdoc: Red colour component from 0 to 255.
	End Rem
	Field red:Int

	Rem
	bbdoc: Green colour component from 0 to 255.
	End Rem
	Field green:Int

	Rem
	bbdoc: Blue colour component from 0 to 255.
	End Rem
	Field blue:Int

	Rem
	bbdoc: Opacity multiplier from 0.0 to 1.0.
	End Rem
	Field alpha:Float=1

	Rem
	bbdoc: Font used to shape and draw this text.
	End Rem
	Field font:TImageFont

	Rem
	bbdoc: Number of text layouts built instead of retrieved from cache.
	End Rem
	Field layoutBuilds:Int
	Private
	Field lines:TParagraphLine[]
	Field cachedText:String,cachedFont:TImageFont,cachedWidth:Float=-1,cachedHeight:Float=-1,cachedFlags:Int,cachedSize:Int
	Field scale:Float=1,contentHeight:Float,offsetY:Float
	Field clip:TTileTextCanvas=New TTileTextCanvas
	Public

	Rem
	bbdoc: Prepares or reuses text layout for an object's drawing rectangle.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
	Method Prepare(width:Float,height:Float)
		If width<0 Or height<0 Or IsNan(width) Or IsInf(width) Or IsNan(height) Or IsInf(height) Then Throw "Max2D tilemap: invalid text box"
		If pixelSize<1 Or pixelSize>4096 Then Throw "Max2D tilemap: invalid text size"
		If alignment<TEXT_ALIGN_LEFT Or alignment>TEXT_ALIGN_RIGHT Or verticalAlignment<TEXT_ALIGN_TOP Or verticalAlignment>TEXT_ALIGN_BOTTOM Then Throw "Max2D tilemap: invalid text alignment"
		Local flags:Int=Int(wrap<>0) | (alignment Shl 1) | (verticalAlignment Shl 3) | (Int(justify<>0) Shl 5)
		If cachedWidth=width And cachedHeight=height And cachedText=text And cachedFont=font And cachedSize=pixelSize And cachedFlags=flags Then Return
		Local face:TImageFont=font
		scale=1
		If Not face Then face=TImageFont.DefaultFont(); scale=Float(pixelSize)/face.Height()
		Local boxWidth:Float=width/scale
		Local result:TList=New TList
		contentHeight=0
		For Local block:String=EachIn text.Replace("~r~n","~n").Replace("~r","~n").Split("~n")
			Local prepared:TPreparedText=TPreparedText.Create(block,face)
			Local layout:TParagraphLayout
			If wrap Then layout=prepared.Layout(boxWidth) Else layout=prepared.Layout(1.0e20)
			For Local i:Int=0 Until layout.lines.Length
				Local line:TParagraphLine=layout.lines[i]
				If justify And wrap And i<layout.lines.Length-1 Then line.layout=TTileJustifiedText.Create(line.text,face,line.layout,boxWidth)
				line.x=0
				If alignment=TEXT_ALIGN_CENTER Then line.x=(boxWidth-line.layout.width)/2
				If alignment=TEXT_ALIGN_RIGHT Then line.x=boxWidth-line.layout.width
				line.y:+contentHeight
				result.AddLast(line)
			Next
			contentHeight:+layout.height
		Next
		lines=New TParagraphLine[result.Count()]
		Local index:Int
		For Local line:TParagraphLine=EachIn result
			lines[index]=line; index:+1
		Next
		offsetY=0
		If verticalAlignment=TEXT_ALIGN_MIDDLE Then offsetY=(height/scale-contentHeight)/2
		If verticalAlignment=TEXT_ALIGN_BOTTOM Then offsetY=height/scale-contentHeight
		cachedText=text; cachedFont=font; cachedWidth=width; cachedHeight=height; cachedFlags=flags; cachedSize=pixelSize
		layoutBuilds:+1
	End Method

	Rem
	bbdoc: Draws text and decorations inside the object's logical rectangle.
	param: Drawing canvas whose state and rendering context are used.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
	Method Draw(canvas:TMax2DGraphics,width:Float,height:Float)
		Prepare(width,height)
		If width=0 Or height=0 Then Return
		TransformCoordinates(scale,0,0,scale,0,0)
		canvas.state.red=Int(Float(canvas.state.red)*red/255)
		canvas.state.green=Int(Float(canvas.state.green)*green/255)
		canvas.state.blue=Int(Float(canvas.state.blue)*blue/255)
		canvas.state.alpha:*alpha
		clip.destination=canvas; clip.context=canvas.context; clip.state=canvas.state; clip.renderImage=canvas.renderImage
		clip.width=width/scale; clip.height=height/scale
		Local face:TImageFont=font
		If Not face Then face=TImageFont.DefaultFont()
		Try
			For Local line:TParagraphLine=EachIn lines
				Local y:Float=line.y+offsetY
				If y+line.layout.height<0 Or y>clip.height Then Continue
				line.layout.Draw(clip,line.x,y)
				Local thickness:Float=Max(1.0,Float(pixelSize)/scale/16)
				If underline Then clip.DrawRect(line.x,y+face.Baseline()+thickness,line.layout.width,thickness)
				If strikeout Then clip.DrawRect(line.x,y+face.Baseline()-face.Height()*0.3,line.layout.width,thickness)
			Next
		Finally
			clip.destination=Null; clip.context=Null; clip.state=Null; clip.renderImage=Null
		End Try
	End Method

End Type

' Clip glyph quads before the object's affine/camera transform. The adapter owns
' no graphics context; normal and scalable layouts retain their usual draw path.

Rem
bbdoc: Canvas adapter that clips text glyph geometry to an object-local rectangle.
End Rem
Type TTileTextCanvas Extends TMax2DGraphics

	Rem
	bbdoc: Canvas to which the clipped text adapter forwards geometry.
	End Rem
	Field destination:TMax2DGraphics

	Rem
	bbdoc: Logical width of this object or region.
	End Rem
	Field width:Float

	Rem
	bbdoc: Logical height of this object or region.
	End Rem
	Field height:Float

	Rem
	bbdoc: Closes the temporary text adapter without closing its shared rendering context.
	End Rem
	Method Close() Override
	End Method

	Rem
	bbdoc: Adds two triangles for a textured or untextured rectangle.
	param: Texture frame to sample, or Null for untextured geometry.
	param: Left coordinate of the local rectangle.
	param: Top coordinate of the local rectangle.
	param: Horizontal coordinate of the first endpoint or rectangle's opposite corner.
	param: Vertical coordinate of the first endpoint or rectangle's opposite corner.
	param: Horizontal translation.
	param: Vertical translation.
	param: Normalized texture coordinate at the left edge.
	param: Normalized texture coordinate at the top edge.
	param: Normalized texture coordinate at the right edge.
	param: Normalized texture coordinate at the bottom edge.
	End Rem
	Method Quad(frame:TImageFrame,x0:Float,y0:Float,x1:Float,y1:Float,tx:Float,ty:Float,u0:Float=0,v0:Float=0,u1:Float=0,v1:Float=0) Override
		Local left:Float=Max(x0,-tx),top:Float=Max(y0,-ty),right:Float=Min(x1,width-tx),bottom:Float=Min(y1,height-ty)
		If right<=left Or bottom<=top Or x1<=x0 Or y1<=y0 Then Return
		Local du:Float=(u1-u0)/(x1-x0),dv:Float=(v1-v0)/(y1-y0)
		destination.Quad(frame,left,top,right,bottom,tx,ty,u0+(left-x0)*du,v0+(top-y0)*dv,u0+(right-x0)*du,v0+(bottom-y0)*dv)
	End Method

End Type

' Retains word layouts only for justified, wrapped, non-final lines.

Rem
bbdoc: A retained line with extra spacing between words for full justification.
End Rem
Type TTileJustifiedText Extends TTextLayout

	Rem
	bbdoc: Retained word layouts arranged with added justification spacing.
	End Rem
	Field words:TTextLayout[]

	Rem
	bbdoc: Horizontal word origins within the justified line.
	End Rem
	Field positions:Float[]

	Rem
	bbdoc: Creates a justified layout fitted to the requested logical width.
	param: Text to lay out, measure or draw.
	param: Font to use; Null selects the current font where supported.
	param: Original layout or line supplying source context and metrics.
	param: Width of the rectangle or drawing surface.
	End Rem
	Function Create:TTextLayout(text:String,font:TImageFont,original:TTextLayout,width:Float)
		Local parts:String[]=text.Split(" "),count:Int
		For Local part:String=EachIn parts
			If part Then count:+1
		Next
		If count<2 Or original.width>=width Or original.rightToLeft Then Return original
		Local result:TTileJustifiedText=New TTileJustifiedText
		result.width=width; result.height=original.height
		result.words=New TTextLayout[count]; result.positions=New Float[count]
		Local total:Float,index:Int
		For Local part:String=EachIn parts
			If Not part Then Continue
			result.words[index]=font.Layout(part); total:+result.words[index].width; index:+1
		Next
		Local gap:Float=(width-total)/(count-1),x:Float
		For Local i:Int=0 Until count
			result.positions[i]=x; x:+result.words[i].width+gap
		Next
		Return result
	End Function

	Rem
	bbdoc: Draws the retained justified word layouts.
	param: Drawing canvas whose state and rendering context are used.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float) Override
		For Local i:Int=0 Until words.Length
			words[i].Draw(canvas,x+positions[i],y)
		Next
	End Method

End Type
