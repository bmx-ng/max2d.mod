' Adapted from samples/threads/background_loading.bmx.
SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import BRL.RamStream
Import brl.pngloader
Import brl.map
Import brl.threads

' -----------------------------------------------------------------------------
' MAKE SURE "Threaded Build" IS CHECKED IN THE Program -> Build Options menu!
' -----------------------------------------------------------------------------





' -----------------------------------------------------------------------------
' Loading screen...
' -----------------------------------------------------------------------------

AppTitle = "Multi-threaded loading screen demo..."

' How to display an animated loading screen while loading images...

' Because only the main program thread can interact with DirectX/OpenGL,
' we have to use BlitzMax TPixmaps in the threaded loading routine.

' Decode into CPU pixmaps on the worker, then create/draw images on the main
' thread so that all graphics uploads stay on the rendering thread.

' This port decodes embedded PNGs on the worker. The pixmaps can be converted
' into images via LoadImage after joining the worker.

' You could just use DrawPixmap to skip this step, but you then can't use'
' realtime scaling, rotation, etc.

' The threaded function LoadPixmaps is at the bottom of this code...

' -----------------------------------------------------------------------------
' This is used to simulate slower loading in the LoadPixmaps thread...
' -----------------------------------------------------------------------------

Incbin "../../../samples/threads/bluboing.png"
Incbin "../../../samples/threads/bluegem.png"
Incbin "../../../samples/threads/boing.png"
Incbin "../../../samples/threads/dead.png"
Incbin "../../../samples/threads/greengem.png"
Incbin "../../../samples/threads/redgem.png"
Global TestDelay:Int = 1000 ' Simulating more/larger images, 3D models, etc...

' -----------------------------------------------------------------------------
' Set up global TMap...
' -----------------------------------------------------------------------------

?sample_test
TestDelay=10
?

Global Pixmaps:TMap = CreateMap ()

' -----------------------------------------------------------------------------
' Add list of pixmap filenames to be added to the Pixmaps TMap...
' -----------------------------------------------------------------------------

AddPixmap ("bluboing.png")
AddPixmap ("bluegem.png")
AddPixmap ("boing.png")
AddPixmap ("dead.png")
AddPixmap ("greengem.png")
AddPixmap ("redgem.png")

' -----------------------------------------------------------------------------
' Set up display...
' -----------------------------------------------------------------------------

?max2d_sdl_gpu
SetSDLRenderMax2DRenderer("gpu")
?
Graphics 640, 480, 0
SetClsColor 32, 96, 128
SetMaskColor 255, 0, 255
AutoMidHandle True

' -----------------------------------------------------------------------------
' Start the LoadPixmaps thread...
' -----------------------------------------------------------------------------

Local thread:TThread = CreateThread (LoadPixmaps, Null)

' -----------------------------------------------------------------------------
' This is the loading screen! Some movement and colours while pixmaps load...
' -----------------------------------------------------------------------------

Local r:Int = 0
Local g:Int = 255
Local b:Int = 127

' -----------------------------------------------------------------------------
' Do this routine until the thread has finished its work...
' -----------------------------------------------------------------------------

While ThreadRunning (thread) ' Worker owns the map until joined.

	Cls

	r = r + 8; If r > 255 Then r = 0
	g = g - 4; If g > 255 Then g = 0
	b = b + 2; If b > 255 Then b = 0

	SetColor 0, 0, 0	
	DrawRect VirtualMouseX(), VirtualMouseY(), 32, 32

	SetColor r, g, b
	DrawRect VirtualMouseX(), VirtualMouseY(), 30, 30

	SetColor 0, 0, 0
	DrawText "Slow-ding, please wait...", 20, 20
	SetColor 255, 255, 255
	DrawText "Slow-ding, please wait...", 18, 18

	Flip

Wend

' -----------------------------------------------------------------------------
' Right, the thread has finished. Should have a nice TMap filled with pixmaps!
' -----------------------------------------------------------------------------

' Just re-setting colours, 'scuse me...

WaitThread(thread)

r = 255; g = 255; b = 255
SetColor r, g, b

' -----------------------------------------------------------------------------
' Create a list of TImage objects and load the pixmaps into them...
' -----------------------------------------------------------------------------

Local images:TList = CreateList ()

For Local p:String = EachIn MapKeys (Pixmaps)
	Local pix:TPixmap=TPixmap(MapValueForKey(Pixmaps,p))
	If Not pix Then Throw "Could not decode "+p
	ListAddLast images, LoadImage(pix)
Next

' In reality, you would probably load each image based on the filename in the
' map. You could just pass each filename you passed to AddPixmap at the start,
' for example (untested)...

' rocket:TImage = LoadImage (TPixmap (MapValueForKey (Pixmaps, "boing.png")))

' -----------------------------------------------------------------------------
' Free the map and all TPixmap objects it holds...
' -----------------------------------------------------------------------------

ClearMap Pixmaps

' -----------------------------------------------------------------------------
' Yay... into the main game! Woo! Fun!
' -----------------------------------------------------------------------------

?sample_test
SampleCheck(images.Count()=6,"Worker image count")
Local testFrames:Int
?
Local ang:Float
Repeat

	Cls
	
	Local x:Int = 0
	Local y:Int = 0

	SetRotation ang; ang = ang + 1; If ang > 360 Then ang = 0
	
	' Draw all images...
	
	For Local i:TImage = EachIn images
	
		DrawImage i, x, y
		x = x + 96
		y = y + 96
	Next

	SetRotation 0

	SetColor 0, 0, 0	
	DrawRect VirtualMouseX(), VirtualMouseY(), 32, 32
	SetColor 255, 255, 255
	DrawRect VirtualMouseX(), VirtualMouseY(), 30, 30
	
	SetColor 0, 0, 0	
	DrawText "All done! We're in-game now! Fun, fun, fun...", 20, 20
	SetColor 255, 255, 255
	DrawText "All done! We're in-game now! Fun, fun, fun...", 18, 18

?sample_test
	testFrames:+1
	If testFrames=120 Then
		SampleCheck(Max2DStats().textureCreations>=6,"Decoded image uploads")
		SampleCapture("background-loading")
		Exit
	End If
	Flip(0)
?Not sample_test
	Flip
?
Until KeyHit (KEY_ESCAPE) Or AppTerminate()

EndGraphics()

' -----------------------------------------------------------------------------
' Helper function for anyone scared of maps...
' -----------------------------------------------------------------------------

Function AddPixmap (p$)

	' Maps are similar to lists, but associated two values with each other;
	' in this case, a filename and a TPixmap pointer, which is Null here.
	
	' The LoadPixmaps function will load the pixmap for each filename in the
	' map, and associated the resulting TPixmap with that filename.
	
	MapInsert (Pixmaps, p$, New TPixmap)
	
End Function

' -----------------------------------------------------------------------------
' The threaded pixmap loading function...
' -----------------------------------------------------------------------------

' No mutexes are needed here since the global Pixmaps:TMap is only accessed by
' the main program after this thread is finished...

Function LoadPixmaps:Object (data:Object)

	' Iterate through the global Map...
	
	For Local p:String = EachIn MapKeys (Pixmaps)
	
		' Load pixmaps into the existing [Null] TPixmap slots for each
		' filename...

		Local pix:TPixmap = LoadPixmap("incbin::../../../samples/threads/"+p)
		MapInsert (Pixmaps, p$, pix)
		
		' Fake delay to simulate loading bigger images for this demo!
		
		Delay TestDelay
		
	Next

End Function


?sample_test
Function SampleCheck(condition:Int,message:String)
	If Not condition Then
		Print "FAILED: "+message
		EndWithCode(1)
	End If
End Function
Function SampleCapture(name:String)
	Local p:TPixmap=GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight())
	Local lit:Int
	For Local y:Int=0 Until p.height Step 4
		For Local x:Int=0 Until p.width Step 4
			If p.ReadPixel(x,y)&$ffffff Then lit:+1
		Next
	Next
	SampleCheck(lit>100,"Blank sample: "+name)
	SampleCheck(SavePixmapPNG(p,AppDir+"/"+name+".png"),"Screenshot save")
	Local stats:TMax2DStats=Max2DStats()
	Print name+" passed: output="+p.width+"x"+p.height+" textures="+stats.textureCreations+" uploads="+stats.textureUpdates+" mipmaps="+stats.mipmapGenerations
End Function
?
