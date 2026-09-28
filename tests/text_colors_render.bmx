SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Graphics(160,120,0,0)
Local target:TRenderImage=CreateRenderImage(128,128,0)
SetRenderImage(target);SetClsColor(0,0,0)
Local font:TImageFont=TImageFont.DefaultFont()
Local prepared:TPreparedText=PrepareText("A B",font,ETextBreakMode.Basic,"",True)
Local layout:TParagraphLayout=prepared.Layout(40)
Local fg:TTextColorSpan=TTextColorSpan.Create(0,1)
fg.SetForeground(255,0,0,0.5)
Local bg:TTextColorSpan=TTextColorSpan.Create(0,3)
bg.SetBackground(0,0,255,0.4)
prepared.SetColorSpans([fg,bg])
For Local transformed:Int=0 To 1
	If transformed Then
		SetRotation(20);SetScale(1.2,1.1);SetHandle(2,3);SetOrigin(5,7)
		TranslateCoordinates(4,3)
	End If
	SetColor(220,190,90);SetAlpha(0.6)
	Cls();DrawTextLayout(layout,30,25)
	Local actual:TPixmap=ReadRenderImage(target)
	Local red:Int,green:Int,blue:Int
	GetColor(red,green,blue)
	Check(red=220 And green=190 And blue=90 And Abs(GetAlpha()-0.6)<0.001,"Paint restores caller colour and alpha")
	Cls()
	SetColor(0,0,255);SetAlpha(0.24);DrawRect(30,25,24,16)
	SetColor(255,0,0);SetAlpha(0.3);DrawTextLayout(font.Layout("A"),30,25)
	SetColor(220,190,90);SetAlpha(0.6)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	DrawTextLayout(font.Layout("B"),30+16*state.ix,25+16*state.jx)
	Local expected:TPixmap=ReadRenderImage(target)
	For Local y:Int=0 Until 128
		For Local x:Int=0 Until 128
			Check(actual.ReadPixel(x,y)=expected.ReadPixel(x,y),"Span foreground/background matches independent drawing with transforms and alpha")
		Next
	Next
Next
ResetCoordinates();SetOrigin(0,0);SetHandle(0,0);SetTransform()
SetAlpha(1);SetColor(255,255,255);Cls()
DrawTextBackgroundsVisible(layout,30,25,0,16)
SetColor(0,255,0);DrawRect(38,25,8,16)
SetColor(255,255,255);DrawTextLayoutVisible(layout,30,25,0,16,False)
Local selected:TPixmap=ReadRenderImage(target)
Check((selected.ReadPixel(42,30)&$ffffff)=$00ff00,"Selection overlays backgrounds without a second background pass")
EndGraphics()
Print "Max2D text colour rendering tests passed"
