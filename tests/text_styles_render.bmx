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
Import BRL.StandardIO
Import BRL.FileSystem
Import Max2D.ScalableFont
Import Text.Unibreak
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
If AppArgs.Length<2 Then Throw "Supply an outline font path"
Local fontPath:String=AppArgs[1]
Local regular:TScalableImageFont=LoadScalableImageFont(fontPath,18)
Local large:TScalableImageFont=LoadScalableImageFont(fontPath,30)
Check(regular<>Null And large<>Null,"Load real fonts")
Graphics(160,120,0,0)
Local target:TRenderImage=CreateRenderImage(160,120,0)
SetRenderImage(target);SetClsColor(0,0,0)
Local prepared:TPreparedText=PrepareText("AV big",regular,ETextBreakMode.Auto,"",True)
prepared.SetFontSpans([TTextFontSpan.Create(3,6,large)])
Local paragraph:TParagraphLayout=prepared.Layout(150)
Local composite:TStyledTextLayout=TStyledTextLayout(paragraph.lines[0].layout)
Local fg:TTextColorSpan=TTextColorSpan.Create(3,6)
fg.SetForeground(255,100,50)
prepared.SetColorSpans([fg])
Local ascent:Float=Max(regular.Baseline(),large.Baseline())
For Local transform:Int=0 To 1
	If transform Then SetRotation(10);SetScale(1.1,1.1);SetHandle(2,1)
	SetColor(220,230,240);Cls();DrawTextLayout(paragraph,10,15)
	Local actual:TPixmap=ReadRenderImage(target)
	Cls()
	Local state:TMax2DState=TMax2DGraphics.Current().state
	Local firstY:Float=ascent-regular.Baseline()
	DrawTextLayout(regular.Layout("AV "),10+firstY*state.iy,15+firstY*state.jy)
	SetColor(255,100,50)
	Local nextX:Float=regular.Layout("AV ").width,nextY:Float=ascent-large.Baseline()
	DrawTextLayout(large.Layout("big"),10+nextX*state.ix+nextY*state.iy,15+nextX*state.jx+nextY*state.jy)
	Local expected:TPixmap=ReadRenderImage(target)
	For Local y:Int=0 Until 120
		For Local x:Int=0 Until 160
			Check(actual.ReadPixel(x,y)=expected.ReadPixel(x,y),"Mixed run drawing matches independent baseline-aligned fonts and colours")
		Next
	Next
Next
Check(composite.runs[0].layout.width=regular.Layout("AV ").width,"Shaping preserves kerning within runs")
Local priorBuilds:Long=regular.layoutBuilds+large.layoutBuilds
paragraph.PrepareInteraction()
Check(paragraph.CaretAt(4).height=paragraph.height,"Real-font caret uses combined line height")
Check(regular.layoutBuilds+large.layoutBuilds=priorBuilds,"Caret preparation does not rebuild mixed layouts")
EndGraphics()
Print "Max2D styled text rendering tests passed"
