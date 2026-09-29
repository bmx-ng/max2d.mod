SuperStrict
Framework Max2D.GLMax2D

AppTitle = "Max2D OpenGL mipmaps"
Graphics 900,600,0
SetVirtualResolution(900,600,VIRTUAL_LETTERBOX)

Local pixmap:TPixmap = CreatePixmap(256,256,PF_RGBA8888)
For Local y:Int = 0 Until 256
	For Local x:Int = 0 Until 256
		If x Mod 8 = 0 Or y Mod 8 = 0 Then
			pixmap.WritePixel(x,y,$ffffffff)
		Else
			pixmap.WritePixel(x,y,$ff202020)
		End If
	Next
Next

Local plain:TImage = LoadImage(pixmap,FILTEREDIMAGE)
Local mipmapped:TImage = LoadImage(pixmap,FILTEREDIMAGE|MIPMAPPEDIMAGE)
SetImageHandle(plain,128,128)
SetImageHandle(mipmapped,128,128)
Local size:Float = 70
Local angle:Float
Local rotating:Int = True

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyDown(KEY_LEFT) Then size = Max(8,size-0.5)
	If KeyDown(KEY_RIGHT) Then size = Min(256,size+0.5)
	If KeyHit(KEY_SPACE) Then rotating = Not rotating
	If rotating Then angle :+ 0.15

	SetClsColor(20,24,36)
	Cls()
	SetTransform(angle,size/256,size/256)
	DrawImage(plain,225,300)
	DrawImage(mipmapped,675,300)
	SetTransform()

	DrawText("Linear filtering",145,100)
	DrawText("Trilinear mipmaps",595,100)
	DrawText("Left/Right: size   Space: pause rotation   Escape: exit",16,16)
	DrawText("Image size: " + Int(size) + " virtual pixels",16,540)
	DrawText("Mip chains generated: " + Max2DStats().mipmapGenerations,16,560)

	Flip()
Wend
EndGraphics()
