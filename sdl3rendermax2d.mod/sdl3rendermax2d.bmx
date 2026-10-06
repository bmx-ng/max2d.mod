SuperStrict

Rem
bbdoc: Draw with the SDL3 renderer Max2D backend.
End Rem
Module Max2D.SDL3RenderMax2D
ModuleInfo "Version: 0.02"
ModuleInfo "License: zlib/libpng"
ModuleInfo "CC_OPTS: -I%PWD%/../../sdl3.mod/sdl3.mod/SDL3/include"

Import Max2D.Core
Import SDL3.SDL3Graphics
Import "glue.c"

Rem
bbdoc: Native texture storage owned by an SDL3 renderer context.
End Rem
Type TSDLRenderImageFrame Extends TImageFrame

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: Releases this frame's native graphics resources on the rendering thread.
	End Rem
	Method NativeDestroy() Override
		If native Then m2d_sdl_destroy(native)
		native = Null
	End Method

End Type

Rem
bbdoc: Max2D rendering context implemented with the SDL3 renderer API.
End Rem
Type TSDLRenderContext Extends TMax2DContext

	Rem
	bbdoc: SDL renderer used by this graphics context.
	End Rem
	Field renderer:TSDLRenderer

	Rem
	bbdoc: Last applied presentation synchronization setting.
	End Rem
	Field sync:Int = -2

	Rem
	bbdoc: Native mask-blending helper, or Null when unavailable.
	End Rem
	Field mask:Byte Ptr

	Rem
	bbdoc: Explanation of why mask blending could not be enabled by this renderer.
	End Rem
	Field maskUnavailableReason:String

	Rem
	bbdoc: Closes the graphics resources owned by this object.
	End Rem
	Method Close() Override
		If closed Then Return
		Flush()
		m2d_sdl_mask_destroy(mask)
		mask = Null
		Super.Close()
	End Method

	Rem
	bbdoc: Throws the backend's error when a native operation fails.
	param: Nonzero for native-operation success; zero triggers an exception.
	End Rem
	Method Require(ok:Int)
		If Not ok Then Throw "Max2D SDL3: " + SDL_GetError()
	End Method

	Rem
	bbdoc: Returns the backend handle for an image frame, or Null for no texture.
	param: Texture frame to sample, or Null for untextured geometry.
	End Rem
	Method NativeFrame:Byte Ptr(frame:TImageFrame)
		If frame Then Return TSDLRenderImageFrame(frame).native
	End Method

	Rem
	bbdoc: Reports whether runtime exclusive fullscreen switching is implemented.
	End Rem
	Method SupportsFullscreen:Int() Override
		Return Not TSDLGraphics(graphics)._context.attached
	End Method

	Rem
	bbdoc: Reports whether runtime borderless fullscreen switching is implemented.
	End Rem
	Method SupportsBorderlessFullscreen:Int() Override
		Return Not TSDLGraphics(graphics)._context.attached
	End Method

	Rem
	bbdoc: Returns the established windowed, exclusive or borderless fullscreen mode.
	End Rem
	Method WindowMode:Int() Override
		Return TSDLGraphics(graphics).WindowMode()
	End Method

	Rem
	bbdoc: Changes the window's presentation mode and refreshes its native resources.
	param: MAX2D_WINDOWED, MAX2D_FULLSCREEN or MAX2D_BORDERLESS_FULLSCREEN.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Refresh rate in hertz; zero selects the backend default.
	End Rem
	Method SetWindowMode(mode:Int,width:Int,height:Int,hertz:Int) Override
		Local g:TSDLGraphics=TSDLGraphics(graphics)
		If mode=MAX2D_BORDERLESS_FULLSCREEN Then
			g.SetBorderlessFullscreen(True)
		Else
			g.SetFullscreen(mode=MAX2D_FULLSCREEN,width,height,hertz)
		End If
	End Method

	Rem
	bbdoc: Gets the window coordinate extent used by mouse input.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method NativeInputSize(width:Int Var,height:Int Var) Override
		Local context:TSDLGraphicsContext=TSDLGraphics(graphics)._context
		If context.attached Then
			SDLAttachedSize(context.window.windowPtr,width,height,False)
		Else
			Require(context.window.GetSize(width,height))
		End If
	End Method

	Rem
	bbdoc: Requests a new window size.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
	Method Resize(width:Int,height:Int) Override
		Try
			graphics.Resize(width,height)
		Catch error:Object
			Local selected:TMax2DGraphics=TMax2DGraphics.selected
			If selected And selected.context=Self Then SetGraphics(selected)
			Throw error
		End Try
	End Method

	Rem
	bbdoc: Requests a new window position.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Position(x:Int,y:Int) Override
		Local window:TSDLWindow=TSDLGraphics(graphics)._context.window
		Local currentX:Int,currentY:Int
		Require(window.GetPosition(currentX,currentY))
		If currentX<>x Or currentY<>y Then
			If WindowMode()<>MAX2D_WINDOWED Then
				SetGraphics(TMax2DGraphics.Current())
				Throw "Max2D SDL3: leave fullscreen before positioning the window"
			End If
			Require(window.SetPosition(x,y))
		End If
		Require(window.GetPosition(currentX,currentY))
		graphics.Position(currentX,currentY)
	End Method

	Rem
	bbdoc: Makes this graphics context current for native rendering operations.
	End Rem
	Method Activate() Override
		SDLGraphicsDriver().SetGraphics(graphics)
	End Method

	Rem
	bbdoc: Presents the window backbuffer with the requested synchronization setting.
	param: Requested presentation interval; negative uses the renderer default.
	End Rem
	Method Present:Int(interval:Int) Override
		If interval < 0 Then interval = 1
		If interval <> sync Then
			' Software renderers may have no controllable display synchronization.
			If renderer.SetVSync(interval) Then sync = interval
		End If
		Require(renderer.Present())
		Return True
	End Method

	Rem
	bbdoc: Allocates a native image frame or render target.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Whether to allocate render-target storage.
	End Rem
	Method NativeCreate:TImageFrame(width:Int,height:Int,flags:Int,target:Int) Override
		Local native:Byte Ptr = m2d_sdl_create(renderer.rendererPtr,width,height,flags,target)
		If Not native Then Throw "Max2D SDL3: " + SDL_GetError()
		Local frame:TSDLRenderImageFrame = New TSDLRenderImageFrame
		frame.native = native
		Return frame
	End Method

	Rem
	bbdoc: Uploads a rectangle from a full source pixmap into a native frame.
	param: Native image frame owned by this context.
	param: Source pixel data.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method NativeUpdateSource(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int) Override
		NativeUpdate(frame,pixmap,x,y,w,h)
	End Method

	Rem
	bbdoc: Uploads pixels into a rectangle of a native image frame.
	param: Native image frame owned by this context.
	param: Source pixel data.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method NativeUpdate(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int) Override
		Local region:TPixmap=UploadRegion(pixmap,x,y,w,h)
		Require(m2d_sdl_update(NativeFrame(frame),region.pixels,region.pitch,x,y,w,h))
	End Method

	Rem
	bbdoc: Submits an interleaved triangle batch to the native renderer.
	param: Texture frame to sample, or Null for untextured geometry.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	param: Interleaved vertices, with eight floats per vertex: x, y, r, g, b, a, u, v.
	param: Number of items to process.
	End Rem
	Method NativeSubmit(frame:TImageFrame,blend:Int,vertices:Float Ptr,count:Int) Override
		Require(m2d_sdl_submit(renderer.rendererPtr,mask,NativeFrame(target),NativeFrame(frame),blend,vertices,count,pixelScaleX,pixelScaleY))
	End Method

	Rem
	bbdoc: Gets the drawable window dimensions in native pixels.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method NativeOutputSize(width:Int Var,height:Int Var) Override
		Local context:TSDLGraphicsContext=TSDLGraphics(graphics)._context
		If context.attached Then
			SDLAttachedSize(context.window.windowPtr,width,height,True)
			Return
		End If
		Require(m2d_sdl_output_size(renderer.rendererPtr,Varptr width,Varptr height))
	End Method

	Rem
	bbdoc: Applies the render target, presentation transform and clipping rectangle.
	param: Render-target frame, or Null for the window backbuffer.
	param: Virtual dimensions, presentation and clipping settings.
	End Rem
	Method NativeView(frame:TImageFrame,view:TMax2DView) Override
		Require(m2d_sdl_view(renderer.rendererPtr,NativeFrame(frame),pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight,..
			pixelScaleX,pixelScaleY,view.x,view.y,view.w,view.h))
	End Method

	Rem
	bbdoc: Clears the active native target with the supplied colour.
	param: Red component, from 0 to 255.
	param: Green component, from 0 to 255.
	param: Blue component, from 0 to 255.
	param: Opacity multiplier, from 0.0 to 1.0.
	End Rem
	Method NativeClear(red:Int,green:Int,blue:Int,alpha:Float) Override
		Require(m2d_sdl_clear(renderer.rendererPtr,NativeFrame(target),view.presentation=VIRTUAL_LETTERBOX Or view.presentation=VIRTUAL_INTEGER,view.width*pixelScaleX,view.height*pixelScaleY,red,green,blue,alpha,view.barRed,view.barGreen,view.barBlue))
	End Method

	Rem
	bbdoc: Reads native target pixels into a pixmap.
	param: Render-target frame, or Null for the window backbuffer.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method NativeRead:TPixmap(frame:TImageFrame,x:Int,y:Int,w:Int,h:Int) Override
		Local pixmap:TPixmap = CreatePixmap(w,h,PF_RGBA8888)
		Require(m2d_sdl_read(renderer.rendererPtr,NativeFrame(frame),x,y,w,h,pixmap.pixels,pixmap.pitch))
		Return pixmap
	End Method

	Rem
	bbdoc: Reports whether a blend mode is supported by this context.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	End Rem
	Method SupportsBlend:Int(blend:Int) Override
		If blend = MASKBLEND Then Return mask <> Null
		Return blend >= SOLIDBLEND And blend <= SHADEBLEND
	End Method

	Rem
	bbdoc: Gets maximum supported texture dimensions, with zero for an unreported limit.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method TextureSize(width:Int Var,height:Int Var) Override
		m2d_sdl_texture_size(renderer.rendererPtr,Varptr width,Varptr height)
	End Method

	Rem
	bbdoc: Checks render-target support for dimensions and image flags.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method SupportsRenderImage:Int(width:Int,height:Int,flags:Int) Override
		If Not SupportsImageFlags(flags) Or Not ValidTextureSize(width,height) Then Return False
		Return True
	End Method

	Rem
	bbdoc: Reports whether an image flag combination is supported by this context.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method SupportsImageFlags:Int(flags:Int) Override
		Return (flags & ~(MASKEDIMAGE | FILTEREDIMAGE | DYNAMICIMAGE)) = 0
	End Method

End Type

Rem
bbdoc: Graphics driver for the SDL3 renderer Max2D backend.
End Rem
Type TSDLRenderMax2DDriver Extends TMax2DDriver

	Rem
	bbdoc: Returns display modes reported by the underlying graphics driver.
	End Rem
	Method GraphicsModes:TGraphicsMode[]() Override
		Return SDLGraphicsDriver().GraphicsModes()
	End Method

	Rem
	bbdoc: Attaches SDL rendering to a native GUI canvas using the installed attachment provider.
	param: Native canvas handle supplied by MaxGUI.
	param: Graphics surface flags.
	about: Import SDL3.SDL3MaxGUI to enable macOS attachment. The host gadget must outlive its graphics.
	End Rem
	Method AttachGraphics:TGraphics(widget:Byte Ptr,flags:Long) Override
		Local graphics:TSDLGraphics=SDLGraphicsDriver().AttachGraphics(widget,flags)
		If Not graphics Then Return Null
		Local context:TSDLRenderContext=New TSDLRenderContext
		context.graphics=graphics
		context.renderer=graphics._context.renderer
		context.mask=m2d_sdl_mask_create(context.renderer.rendererPtr)
		If Not context.mask Then context.maskUnavailableReason=SDL_GetError()
		context.windowView.Reset(graphics._context.width,graphics._context.height)
		context.view=context.windowView
		Local canvas:TMax2DGraphics=New TMax2DGraphics
		canvas.context=context
		canvas.driver=Self
		canvas.imageFont=TImageFont.DefaultFont()
		Return canvas
	End Method

	Rem
	bbdoc: Creates the backend context for a graphics window.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Fullscreen colour depth; zero requests a window.
	param: Refresh rate in hertz; zero selects the backend default.
	param: BRL.Graphics window-creation flags.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method CreateContext:TMax2DContext(width:Int,height:Int,depth:Int,hertz:Int,flags:Long,x:Int,y:Int) Override
		If flags & (SDL_GRAPHICS_GL|SDL_GRAPHICS_GPU) Then Throw "Max2D SDL3 Renderer: OpenGL/GPU context flags are unsupported"
		Local graphics:TSDLGraphics = SDLGraphicsDriver().CreateGraphics(width,height,depth,hertz,flags,x,y)
		If Not graphics Then Return Null
		Local context:TSDLRenderContext = New TSDLRenderContext
		context.graphics = graphics
		context.renderer = graphics._context.renderer
		context.mask = m2d_sdl_mask_create(context.renderer.rendererPtr)
		If Not context.mask Then context.maskUnavailableReason = SDL_GetError()
		Return context
	End Method

	Rem
	bbdoc: Returns the renderer's descriptive name.
	End Rem
	Method ToString:String() Override
		Return "Max2D SDL3 Renderer"
	End Method

	Rem
	bbdoc: Gets the local handle used for drawing primitives.
	param: Kind of native graphics handle requested.
	End Rem
	Method GetHandle:Byte Ptr(handleType:EGraphicsHandleType=EGraphicsHandleType.Window) Override
		If Not current Then Return Null
		Local window:TSDLWindow = TSDLGraphics(current.context.graphics)._context.window
		If handleType=EGraphicsHandleType.Display Then Return window.GetDisplayHandle()
		Return window.GetHandle()
	End Method

End Type

Rem
bbdoc: Returns the shared SDL3 renderer Max2D graphics driver.
End Rem
Function SDLRenderMax2DDriver:TSDLRenderMax2DDriver()
	Global driver:TSDLRenderMax2DDriver = New TSDLRenderMax2DDriver
	Return driver
End Function

Rem
bbdoc: Selects SDL's renderer for subsequently created windows.
param: Name used to register or look up the item.
about: Call before Graphics. Use "gpu" for the GPU renderer. Returns False if an
existing environment override takes priority. Does not change existing windows.
End Rem
Function SetSDLRenderMax2DRenderer:Int(name:String)
	Local utf8:Byte Ptr = name.ToUTF8String()
	Local ok:Int = m2d_sdl_renderer_hint(utf8)
	MemFree(utf8)
	Return ok
End Function

Rem
bbdoc: Returns the active SDL renderer name, or an empty string without an SDL renderer canvas.
End Rem
Function SDLRenderMax2DRendererName:String()
	Local context:TSDLRenderContext = TSDLRenderContext(TMax2DGraphics.Current().context)
	If Not context Then Throw "Max2D: current context is not SDL3 Renderer"
	Return String.FromUTF8String(m2d_sdl_renderer_name(context.renderer.rendererPtr))
End Function

Extern
	Function m2d_sdl_mask_create:Byte Ptr(renderer:Byte Ptr)
	Function m2d_sdl_mask_destroy(mask:Byte Ptr)
	Function m2d_sdl_renderer_hint:Int(name:Byte Ptr)
	Function m2d_sdl_renderer_name:Byte Ptr(renderer:Byte Ptr)
	Function m2d_sdl_create:Byte Ptr(renderer:Byte Ptr,width:Int,height:Int,flags:Int,target:Int)
	Function m2d_sdl_destroy(frame:Byte Ptr)
	Function m2d_sdl_update:Int(frame:Byte Ptr,pixels:Byte Ptr,pitch:Int,x:Int,y:Int,w:Int,h:Int)
	Function m2d_sdl_submit:Int(renderer:Byte Ptr,mask:Byte Ptr,target:Byte Ptr,frame:Byte Ptr,blend:Int,vertices:Float Ptr,count:Int,sx:Float,sy:Float)
	Function m2d_sdl_output_size:Int(renderer:Byte Ptr,width:Int Ptr,height:Int Ptr)
	Function m2d_sdl_view:Int(renderer:Byte Ptr,target:Byte Ptr,vx:Int,vy:Int,vw:Int,vh:Int,sx:Float,sy:Float,x:Int,y:Int,w:Int,h:Int)
	Function m2d_sdl_clear:Int(renderer:Byte Ptr,target:Byte Ptr,letterbox:Int,width:Float,height:Float,red:Int,green:Int,blue:Int,alpha:Float,barRed:Int,barGreen:Int,barBlue:Int)
	Function m2d_sdl_read:Int(renderer:Byte Ptr,target:Byte Ptr,x:Int,y:Int,w:Int,h:Int,pixels:Byte Ptr,pitch:Int)

	Function m2d_sdl_texture_size(context:Byte Ptr,width:Int Ptr,height:Int Ptr)
End Extern

SetGraphicsDriver(SDLRenderMax2DDriver(),0)
