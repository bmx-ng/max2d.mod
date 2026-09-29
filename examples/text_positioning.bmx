SuperStrict

Framework Max2D.SDL3RenderMax2D
Import Max2D.ScalableFont
Import Pub.StdC

Local path:String
?osx
path="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
path=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
path="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
If AppArgs.Length>1 Then path=AppArgs[1]
Local smooth:TScalableImageFont=LoadScalableImageFont(path,20)
Local mono:TScalableImageFont=LoadScalableImageFont(path,20,KERNFONT | LIGATURESFONT)
If Not smooth Or Not mono Then Throw "Supply a readable outline font filename"
Local font:TScalableImageFont=smooth
Local text:String="Fuel reserves: 84%   office AV   0123456789"
Local smoothLayout:TTextLayout=smooth.Layout(text)
Local monoLayout:TTextLayout=mono.Layout(text)
Local moving:Int
Local monochrome:Int
Local offset:Float=0.2
AppTitle="Max2D text positioning"
Graphics 800,420
SetVirtualResolution(800,420,VIRTUAL_LETTERBOX)

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_SPACE) Then moving=Not moving
	If KeyHit(KEY_M) Then monochrome=Not monochrome
	If KeyHit(KEY_LEFT) Then offset:-0.1
	If KeyHit(KEY_RIGHT) Then offset:+0.1
	Local layout:TTextLayout=smoothLayout
	font=smooth
	If monochrome
		font=mono
		layout=monoLayout
	End If
	Local x:Float=32+offset
	If moving Then x:+20*Sin(MilliSecs()*0.03)
	SetClsColor(28,36,49)
	Cls
	SetColor(220,230,244)
	SetImageFont(smooth)
	smooth.pixelAligned=True
	DrawText("Left/right: offset   Space: motion   M: smoothing   Escape: exit",24,24)
	DrawText("Fractional positioning (default)",24,100)
	DrawText("Pixel-aligned positioning (stationary text)",24,220)
	DrawText("Both rows use the same retained layout and native-density glyphs.",24,340)
	DrawText("Offset: "+offset+"   Raster density: "+font.DrawingDensity(TMax2DGraphics.Current()),24,374)
	SetColor(116,217,255)
	font.pixelAligned=False
	DrawTextLayout(layout,x,140)
	font.pixelAligned=True
	DrawTextLayout(layout,x,260)
	Flip
Wend
EndGraphics
