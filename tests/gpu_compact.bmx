SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.ScalableFont
Import BRL.StandardIO
Import Pub.StdC

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Function Capture:TPixmap(target:TRenderImage)
	Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
	Return canvas.context.Read(target.Frame(0,canvas),0,0,target.width,target.height)
End Function

Function Scene(target:TRenderImage,source:TRenderImage,image:TImage,compact:Int)
	SetSDLGPUMax2DCompactSprites(compact)
	SetRenderImage(source)
	SetVirtualResolution(64,64)
	SetClsColor(0,0,0)
	Cls
	SetBlend(ALPHABLEND)
	SetColor(255,255,255)
	DrawImage(image,3,4)
	DrawText("ABC",4,36)
	SetRenderImage(target)
	SetVirtualResolution(320,240,VIRTUAL_LETTERBOX)
	SetClsColor(20,30,40)
	Cls
	For Local blend:Int=MASKBLEND To LIGHTBLEND
		SetBlend(blend)
		SetColor(170,210,250)
		SetAlpha(0.75)
		DrawImage(source,Float(blend*42),18)
		DrawImage(image,Float(blend*42),30)
	Next
	SetBlend(ALPHABLEND)
	SetAlpha(1)
	SetColor(200,100,40)
	' Three vertices followed by compact records tests storage offset alignment.
	DrawPoly([5.0,90.0,40.0,90.0,22.0,120.0])
	DrawImage(image,45,90)
	DrawOval(80,90,20,30)
	DrawImage(image,110,90)
	SetViewport(0,0,240,220)
	DrawImage(source,210,160)
	SetViewport(0,0,320,240)
	SetRotation(90)
	DrawImage(image,155,110)
	SetRotation(0)
	SetScale(-1,1)
	DrawImage(image,180,90)
	SetScale(1,1)
	TranslateCoordinates(2,3)
	DrawImage(image,200,90)
	ResetCoordinates()
	Local camera:TCamera2D=New TCamera2D
	camera.x=-4
	camera.y=2
	SetCamera(camera)
	DrawImage(image,245,90)
	SetCamera(Null)
	DrawText("Atlas glyphs and shapes",10,145)
	' Texture edits and target reuse must preserve earlier commands.
	SetRenderImage(source)
	SetColor(0,255,100)
	DrawRect(0,0,20,20)
	SetRenderImage(target)
	DrawImage(source,20,170)
	' Toggle with pending work to exercise mode changes within one frame.
	SetSDLGPUMax2DCompactSprites(Not compact)
	DrawImage(image,120,190)
	SetSDLGPUMax2DCompactSprites(compact)
	DrawRect(170,190,20,20)
End Function

Graphics 400,300
Print "Driver: "+SDLGPUMax2DDriverName()
Local pixmap:TPixmap=CreatePixmap(24,24,PF_RGBA8888)
For Local y:Int=0 Until 24
	For Local x:Int=0 Until 24
		Local alpha:Int=255
		If (x+y) Mod 3=0 Then alpha=80
		pixmap.WritePixel(x,y,(alpha Shl 24) | (x*10 Shl 16) | (y*10 Shl 8) | 128)
	Next
Next
Local image:TImage=LoadImage(pixmap,0)
Local source:TRenderImage=CreateRenderImage(64,64,FILTEREDIMAGE | MIPMAPPEDIMAGE)
For Local density:Int=1 To 2
	Local target:TRenderImage=CreateRenderImage(UInt(320*density),UInt(240*density),0)
	Scene(target,source,image,False)
	Local reference:TPixmap=Capture(target)
	Scene(target,source,image,True)
	Local actual:TPixmap=Capture(target)
	Local different:Int
	For Local y:Int=0 Until actual.height
		For Local x:Int=0 Until actual.width
			If actual.ReadPixel(x,y)<>reference.ReadPixel(x,y) Then different:+1
		Next
	Next
	Check(different=0,"Mixed compact drawing differs at "+different+" pixels (density "+density+")")
	SetRenderImage(Null)
	target.ReleaseFrames()
Next
Local fontPath:String
?osx
fontPath="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
fontPath="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TScalableImageFont=LoadScalableImageFont(fontPath,20)
Check(font<>Null,"Scalable font fixture")
SetImageFont(font)
For Local density:Int=1 To 2
	Local target:TRenderImage=CreateRenderImage(UInt(320*density),UInt(100*density),0)
	SetRenderImage(target)
	SetVirtualResolution(320,100)
	SetColor(255,255,255)
	SetAlpha(1)
	For Local aligned:Int=0 To 1
		font.pixelAligned=aligned
		Local reference:TPixmap
		For Local compact:Int=0 To 1
			SetSDLGPUMax2DCompactSprites(compact)
			Cls
			DrawText("Fuel reserves: office AV",10.25,20.25)
			Local pixels:TPixmap=Capture(target)
			If compact=0
				reference=pixels
			Else
				For Local y:Int=0 Until pixels.height
					For Local x:Int=0 Until pixels.width
						Local a:Int=reference.ReadPixel(x,y)
						Local b:Int=pixels.ReadPixel(x,y)
						For Local channel:Int=0 Until 4
							Check(Abs(((a Shr (channel*8)) & 255)-((b Shr (channel*8)) & 255))<=1,"Scalable glyph coverage differs")
						Next
					Next
				Next
			End If
		Next
	Next
	SetRenderImage(Null)
	target.ReleaseFrames()
Next
' Force both representations across the native upload-buffer limit.
Local stress:TRenderImage=CreateRenderImage(64,64,0)
Local saved:TPixmap
For Local compact:Int=0 To 1
	SetSDLGPUMax2DCompactSprites(compact)
	SetRenderImage(stress)
	SetVirtualResolution(64,64)
	SetColor(255,255,255)
	SetAlpha(0.5)
	Cls
	For Local i:Int=0 Until 140000
		DrawImage(image,Float(i Mod 45),Float((i/45) Mod 45))
	Next
	Local pixels:TPixmap=Capture(stress)
	If compact=0
		saved=pixels
	Else
		For Local y:Int=0 Until 64
			For Local x:Int=0 Until 64
				Check(saved.ReadPixel(x,y)=pixels.ReadPixel(x,y),"Native upload-buffer rollover")
			Next
		Next
	End If
Next
SetRenderImage(Null)
EndGraphics
Print "Compact GPU mixed drawing tests passed"
