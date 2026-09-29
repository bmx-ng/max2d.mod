SuperStrict

Framework Max2D.SDL3RenderMax2D
Import Max2D.ScalableFont
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Function Same:Int(a:TPixmap,b:TPixmap)
	For Local y:Int=0 Until a.height
		For Local x:Int=0 Until a.width
			If a.ReadPixel(x,y)<>b.ReadPixel(x,y) Then Return False
		Next
	Next
	Return True
End Function

Function Capture:TPixmap(layout:TTextLayout,x:Float,y:Float)
	Cls
	DrawTextLayout(layout,x,y)
	Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
	Return canvas.context.Read(canvas.context.target,0,0,canvas.context.pixelWidth,canvas.context.pixelHeight)
End Function

If AppArgs.Length<>2 Then Throw "Supply an outline font filename"
Local font:TScalableImageFont=LoadScalableImageFont(AppArgs[1],20)
Local layout:TTextLayout=font.Layout("H")
Local width:Float=layout.width
Local baselineX:Float=TScalablePositionedGlyph(layout.glyphs[0]).baselineX
Local prepared:TPreparedText=PrepareText("office AV office AV",font)
Local paragraph:TParagraphLayout=prepared.Layout(90)
Graphics 320,100
SetClsColor(0,0,0)
SetColor(255,255,255)

For Local density:Int=1 To 2
	Local target:TRenderImage=CreateRenderImage(UInt(320*density),UInt(100*density),0)
	SetRenderImage(target)
	SetVirtualResolution(320,100)
	font.pixelAligned=False
	Local reference:TPixmap=Capture(layout,20,20)
	Local fractional:TPixmap=Capture(layout,20+0.2/density,20+0.2/density)
	Check(Not Same(reference,fractional),"Fractional positioning remains the default")
	font.pixelAligned=True
	Check(Same(reference,Capture(layout,20+0.2/density,20+0.2/density)),"Align both axes in physical pixels")
	TranslateCoordinates(0.2/density,0.2/density)
	Check(Same(reference,Capture(layout,20,20)),"Account for parent translation")
	ResetCoordinates()
	Local camera:TCamera2D=New TCamera2D
	camera.x=-0.2/density
	camera.y=-0.2/density
	SetCamera(camera)
	Check(Same(reference,Capture(layout,20,20)),"Account for camera translation")
	SetCamera(Null)
	SetOrigin(0.2/density,0.2/density)
	Check(Same(reference,Capture(layout,20,20)),"Account for drawing origin")
	SetOrigin(0,0)
	SetHandle(0.2/density,0.2/density)
	Check(Same(reference,Capture(layout,20,20)),"Account for drawing handle")
	SetHandle(0,0)
	SetScale(-1,1)
	font.pixelAligned=False
	Local mirrored:TPixmap=Capture(layout,60,20)
	font.pixelAligned=True
	Check(Same(mirrored,Capture(layout,60+0.2/density,20+0.2/density)),"Align reflected glyphs")
	SetScale(1,1)
	SetVirtualResolution(300,100,VIRTUAL_LETTERBOX)
	font.pixelAligned=False
	Local letterboxed:TPixmap=Capture(layout,20,20)
	font.pixelAligned=True
	Check(Same(letterboxed,Capture(layout,20+0.2/density,20+0.2/density)),"Include letterbox viewport offset")
	SetVirtualResolution(320,100)
	For Local transform:Int=0 To 3
		Select transform
			Case 0
				SetRotation(23)
			Case 1
				SetScale(1.25,1.25)
			Case 2
				SetScale(1,2)
			Case 3
				SetAffineTransform(1,0.2,0,1)
		End Select
		font.pixelAligned=False
		Local unsnapped:TPixmap=Capture(layout,30.2,30.2)
		font.pixelAligned=True
		Check(Same(unsnapped,Capture(layout,30.2,30.2)),"Unsupported transform retains fractional drawing")
		SetRotation(0)
		SetScale(1,1)
	Next
	Check(layout.width=width And TScalablePositionedGlyph(layout.glyphs[0]).baselineX=baselineX,"Alignment leaves layout untouched")
	Check(prepared.Layout(90)=paragraph,"Alignment retains paragraph cache")
	SetRenderImage(Null)
	target.ReleaseFrames()
Next
EndGraphics
Print "Scalable text positioning tests passed"
