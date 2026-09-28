Rem
bbdoc: Retained text attached to a map object. Assign a font at the requested pixel size, or leave Null for the scaled built-in fallback.
about: The object rectangle controls layout and clipping. Prepare caches layout; changing text, font, size or layout settings rebuilds it on the next draw. Font family/bold/italic/kerning describe the requested face for application resolvers.
End Rem
Type TTileText
	Field text:String,fontFamily:String="sans-serif",pixelSize:Int=16
	Field bold:Int,italic:Int,underline:Int,strikeout:Int,kerning:Int=True
	Field wrap:Int,alignment:Int=TEXT_ALIGN_LEFT,verticalAlignment:Int=TEXT_ALIGN_TOP,justify:Int
	Field red:Int,green:Int,blue:Int,alpha:Float=1
	Field font:TImageFont
	Field layoutBuilds:Int
	Private
	Field lines:TParagraphLine[]
	Field cachedText:String,cachedFont:TImageFont,cachedWidth:Float=-1,cachedHeight:Float=-1,cachedFlags:Int,cachedSize:Int
	Field scale:Float=1,contentHeight:Float,offsetY:Float
	Field clip:TTileTextCanvas=New TTileTextCanvas
	Public
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
Type TTileTextCanvas Extends TMax2DGraphics
	Field destination:TMax2DGraphics,width:Float,height:Float
	Method Close() Override
	End Method
	Method Quad(frame:TImageFrame,x0:Float,y0:Float,x1:Float,y1:Float,tx:Float,ty:Float,u0:Float=0,v0:Float=0,u1:Float=0,v1:Float=0) Override
		Local left:Float=Max(x0,-tx),top:Float=Max(y0,-ty),right:Float=Min(x1,width-tx),bottom:Float=Min(y1,height-ty)
		If right<=left Or bottom<=top Or x1<=x0 Or y1<=y0 Then Return
		Local du:Float=(u1-u0)/(x1-x0),dv:Float=(v1-v0)/(y1-y0)
		destination.Quad(frame,left,top,right,bottom,tx,ty,u0+(left-x0)*du,v0+(top-y0)*dv,u0+(right-x0)*du,v0+(bottom-y0)*dv)
	End Method
End Type

' Retains word layouts only for justified, wrapped, non-final lines.
Type TTileJustifiedText Extends TTextLayout
	Field words:TTextLayout[],positions:Float[]
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
	Method Draw(canvas:TMax2DGraphics,x:Float,y:Float) Override
		For Local i:Int=0 Until words.Length
			words[i].Draw(canvas,x+positions[i],y)
		Next
	End Method
End Type
