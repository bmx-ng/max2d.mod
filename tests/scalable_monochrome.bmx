SuperStrict

Framework Max2D.SDL3RenderMax2D
Import Max2D.ScalableFont
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

If AppArgs.Length <> 2 Then Throw "Supply an outline font filename"
Local mono:TScalableImageFont = LoadScalableImageFont(AppArgs[1],20,KERNFONT | LIGATURESFONT)
Local smooth:TScalableImageFont = LoadScalableImageFont(AppArgs[1],20)
Check(mono And smooth,"Load fonts")
Check(Not (mono.Style() & SMOOTHFONT),"Preserve monochrome style")
Local layout:TTextLayout = mono.Layout("office AV curves 012345")
Local width:Float = layout.width
Graphics 320,100

For Local density:Int = 1 To 2
	Local target:TRenderImage = CreateRenderImage(UInt(320*density),UInt(100*density),0)
	SetRenderImage(target)
	SetVirtualResolution(320,100)
	For Local pass:Int = 0 To 1
		If pass Then mono.ClearGlyphCache()
		SetClsColor(0,0,0)
		Cls
		SetColor(255,255,255)
		DrawTextLayout(layout,10.33,10.33)
		Check(mono.DrawingDensity(TMax2DGraphics.Current())=density,"Target selects raster density")
		Check(Not (mono.Raster(density).atlas.flags & FILTEREDIMAGE),"Monochrome atlas uses nearest sampling after cache clears")
		Local pixels:TPixmap = TMax2DGraphics.Current().context.Read(target.Frame(0,TMax2DGraphics.Current()),0,0,320*density,100*density)
		Local lit:Int
		For Local y:Int = 0 Until pixels.height
			For Local x:Int = 0 Until pixels.width
				Local rgb:Int = pixels.ReadPixel(x,y) & $ffffff
				Check(rgb=0 Or rgb=$ffffff,"Monochrome text acquired intermediate coverage")
				If rgb Then lit:+1
			Next
		Next
		Check(lit>100,"Monochrome text produces visible glyphs")
		Check(layout.width=width,"Density and cache changes preserve layout")
	Next
	SetClsColor(0,0,0)
	Cls
	SetImageFont(smooth)
	DrawText("office AV curves",10,10)
	Local pixels:TPixmap = TMax2DGraphics.Current().context.Read(target.Frame(0,TMax2DGraphics.Current()),0,0,320*density,100*density)
	Local intermediate:Int
	For Local y:Int = 0 Until pixels.height
		For Local x:Int = 0 Until pixels.width
			Local rgb:Int = pixels.ReadPixel(x,y) & $ffffff
			If rgb<>0 And rgb<>$ffffff Then intermediate:+1
		Next
	Next
	Check(intermediate>0,"Default font retains antialiasing")
	SetRenderImage(Null)
	target.ReleaseFrames()
Next
EndGraphics
Print "Scalable monochrome tests passed"
