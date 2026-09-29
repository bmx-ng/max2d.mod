SuperStrict
Framework Max2D.SDL3RenderMax2D
Import Max2D.ScalableFont
Import BRL.StandardIO

If AppArgs.Length<>2 Then
	Print "Usage: scalable_text /absolute/path/to/font.ttf"
	EndWithCode(1)
End If
Local font:TScalableImageFont=LoadScalableImageFont(AppArgs[1],18)
If Not font Then Throw "Could not load font"
AppTitle="Max2D scalable text"

Graphics 1000,700,0

SetImageFont(font)
Local narrow:Int=True
Local low:TRenderImage=CreateRenderImage(400,90,0)

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_SPACE) Then narrow=Not narrow
	If KeyHit(KEY_C) Then font.ClearGlyphCache()
	If narrow Then SetVirtualResolution(400,280,VIRTUAL_LETTERBOX) Else SetVirtualResolution(600,420,VIRTUAL_LETTERBOX)
	SetClsColor(24,32,48); Cls()
	SetColor(255,255,255)
	DrawText("Scalable scene text: office AV x́",12,40)
	DrawText("Greek: Ωμέγα",12,70)

	' This intentionally rasterizes text into a small image, for comparison.
	PushMax2DState()
	SetRenderImage(low)
	SetClsColor(24,32,48); Cls()
	DrawText("Text baked into a low-resolution image",12,10)
	PopMax2DState()

	DrawImage(low,0,110)

	PushMax2DState()
	SetNativeResolution()
	SetColor(255,255,255)
	DrawText("Native overlay — Space: change virtual size, C: clear glyph caches",16,16)
	DrawText("Raster resolutions: "+font.RasterCacheCount()+"   Atlas pages: "+font.RasterPageCount(),16,NativeResolutionHeight()-40)
	PopMax2DState()

	Flip()
Wend
EndGraphics()
