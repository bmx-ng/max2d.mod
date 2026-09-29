' Adapted from samples/hitoro/viewport.bmx by James L Boyd.
' The viewport clips drawing; it does not move the drawing origin.
SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import brl.pngloader
Import brl.ramstream

Incbin "../../../samples/hitoro/gfx/bg.png"
Incbin "../../../samples/hitoro/gfx/boing.png"

?max2d_sdl_gpu
SetSDLRenderMax2DRenderer("gpu")
?
Graphics 640, 480 , 0
Local backgroundBlend:Int = MASKBLEND
If Not Max2DSupportsBlend(MASKBLEND) Then backgroundBlend = ALPHABLEND

AutoImageFlags MASKEDIMAGE|FILTEREDIMAGE

SetMaskColor 255, 0, 255

Local bg:TImage = LoadImage ("incbin::../../../samples/hitoro/gfx/bg.png")
Local bgw# = GraphicsWidth () / Float (ImageWidth (bg))
Local bgh# = GraphicsHeight () / Float (ImageHeight (bg))

Local image:TImage = LoadImage ("incbin::../../../samples/hitoro/gfx/boing.png") ' My example is 256 x 256
MidHandleImage image

Local rotstep# = 1
Local rot#
?sample_test
Local testFrame:Int
?
Repeat

	Local mx:Float, my:Float
	GetVirtualMouse(mx,my)
?sample_test
	Select testFrame
		Case 0
			mx=320; my=240
		Case 1
			mx=0; my=0
		Case 2
			mx=639; my=479
	End Select
?
	
	SetViewport 0, 0, GraphicsWidth (), GraphicsHeight ()
	Cls
	
	SetViewport Int(mx) - 200, Int(my) - 150, 400, 300
	Cls
	
	' ---------------------------------------------------------------
	' Draw background...
	' ---------------------------------------------------------------
	
	SetAlpha 1
	SetBlend backgroundBlend
	
	SetRotation 0; SetScale bgw, bgh
	DrawImage bg, 0, 0
	
	' ---------------------------------------------------------------
	' Draw image...
	' ---------------------------------------------------------------
	
	rot = rot + rotstep; If rot > 360 - rotstep Then rot = 0
	SetRotation rot
	
	Local scale# = 0.1 + Sin (rot / 2); If scale < 0 Then scale = -scale
	SetScale scale, scale
	
	SetBlend ALPHABLEND
	SetAlpha scale
	
	DrawImage image, mx, my
	
?sample_test
	SavePixmapPNG(GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight()),AppDir+"/viewport-"+testFrame+".png")
	testFrame:+1
	If testFrame=3 Then Exit
?
	Flip
	
Until KeyHit (KEY_ESCAPE) Or AppTerminate()

EndGraphics()
