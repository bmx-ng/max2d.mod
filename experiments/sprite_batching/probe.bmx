SuperStrict

Framework SDL3.SDL3Graphics
Import BRL.StandardIO
?osx
Import "probe.o"
Extern "C"
	Function sprite_probe:Int(window:Byte Ptr)
End Extern
?

?osx
Local driver:TSDLGraphicsDriver=SDLGraphicsDriver()
Local graphics:TSDLGraphics=driver.CreateGraphics(640,480,0,60,SDL_GRAPHICS_GPU,-1,-1)
If Not graphics Then Throw SDL_GetError()
SetGraphics(graphics)
Local result:Int=sprite_probe(driver.GetSDLWindow().windowPtr)
Local error:String=SDL_GetError()
CloseGraphics(graphics)
If Not result Then Throw error
?Not osx
Print "This isolated shader prototype currently requires macOS/Metal."
?
