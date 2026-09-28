SuperStrict
Module Max2D.SDL3RenderMax2D
ModuleInfo "Version: 0.02"
ModuleInfo "License: zlib/libpng"
ModuleInfo "CC_OPTS: -I%PWD%/../../sdl3.mod/sdl3.mod/SDL3/include"

Import Max2D.Core
Import SDL3.SDL3Graphics
Import "glue.c"

Type TSDLRenderImageFrame Extends TImageFrame
	Field native:Byte Ptr
	Method NativeDestroy() Override
		If native Then m2d_sdl_destroy(native)
		native = Null
	End Method
End Type

Type TSDLRenderContext Extends TMax2DContext
	Field renderer:TSDLRenderer
	Field sync:Int = -2
	Field mask:Byte Ptr
	Field maskUnavailableReason:String
	Method Close() Override
		If closed Then Return
		Flush()
		m2d_sdl_mask_destroy(mask)
		mask = Null
		Super.Close()
	End Method
	Method Require(ok:Int)
		If Not ok Then Throw "Max2D SDL3: " + SDL_GetError()
	End Method
	Method NativeFrame:Byte Ptr(frame:TImageFrame)
		If frame Then Return TSDLRenderImageFrame(frame).native
	End Method
	Method SupportsFullscreen:Int() Override
		Return True
	End Method
	Method SupportsBorderlessFullscreen:Int() Override
		Return True
	End Method
	Method WindowMode:Int() Override
		Return TSDLGraphics(graphics).WindowMode()
	End Method
	Method SetWindowMode(mode:Int,width:Int,height:Int,hertz:Int) Override
		Local g:TSDLGraphics=TSDLGraphics(graphics)
		If mode=MAX2D_BORDERLESS_FULLSCREEN Then
			g.SetBorderlessFullscreen(True)
		Else
			g.SetFullscreen(mode=MAX2D_FULLSCREEN,width,height,hertz)
		End If
	End Method
	Method NativeInputSize(width:Int Var,height:Int Var) Override
		Require(TSDLGraphics(graphics)._context.window.GetSize(width,height))
	End Method
	Method Resize(width:Int,height:Int) Override
		Try
			graphics.Resize(width,height)
		Catch error:Object
			Local selected:TMax2DGraphics=TMax2DGraphics.selected
			If selected And selected.context=Self Then SetGraphics(selected)
			Throw error
		End Try
	End Method
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
	Method Activate() Override
		SDLGraphicsDriver().SetGraphics(graphics)
	End Method
	Method Present:Int(interval:Int) Override
		If interval < 0 Then interval = 1
		If interval <> sync Then
			' Software renderers may have no controllable display synchronization.
			If renderer.SetVSync(interval) Then sync = interval
		End If
		Require(renderer.Present())
		Return True
	End Method
	Method NativeCreate:TImageFrame(width:Int,height:Int,flags:Int,target:Int) Override
		Local native:Byte Ptr = m2d_sdl_create(renderer.rendererPtr,width,height,flags,target)
		If Not native Then Throw "Max2D SDL3: " + SDL_GetError()
		Local frame:TSDLRenderImageFrame = New TSDLRenderImageFrame
		frame.native = native
		Return frame
	End Method
	Method NativeUpdateSource(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int) Override
		NativeUpdate(frame,pixmap,x,y,w,h)
	End Method
	Method NativeUpdate(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int) Override
		Local region:TPixmap=UploadRegion(pixmap,x,y,w,h)
		Require(m2d_sdl_update(NativeFrame(frame),region.pixels,region.pitch,x,y,w,h))
	End Method
	Method NativeSubmit(frame:TImageFrame,blend:Int,vertices:Float Ptr,count:Int) Override
		Require(m2d_sdl_submit(renderer.rendererPtr,mask,NativeFrame(target),NativeFrame(frame),blend,vertices,count,pixelScaleX,pixelScaleY))
	End Method
	Method NativeOutputSize(width:Int Var,height:Int Var) Override
		Require(m2d_sdl_output_size(renderer.rendererPtr,Varptr width,Varptr height))
	End Method
	Method NativeView(frame:TImageFrame,view:TMax2DView) Override
		Require(m2d_sdl_view(renderer.rendererPtr,NativeFrame(frame),pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight,..
			pixelScaleX,pixelScaleY,view.x,view.y,view.w,view.h))
	End Method
	Method NativeClear(red:Int,green:Int,blue:Int,alpha:Float) Override
		Require(m2d_sdl_clear(renderer.rendererPtr,NativeFrame(target),view.presentation=VIRTUAL_LETTERBOX Or view.presentation=VIRTUAL_INTEGER,view.width*pixelScaleX,view.height*pixelScaleY,red,green,blue,alpha,view.barRed,view.barGreen,view.barBlue))
	End Method
	Method NativeRead:TPixmap(frame:TImageFrame,x:Int,y:Int,w:Int,h:Int) Override
		Local pixmap:TPixmap = CreatePixmap(w,h,PF_RGBA8888)
		Require(m2d_sdl_read(renderer.rendererPtr,NativeFrame(frame),x,y,w,h,pixmap.pixels,pixmap.pitch))
		Return pixmap
	End Method
	Method SupportsBlend:Int(blend:Int) Override
		If blend = MASKBLEND Then Return mask <> Null
		Return blend >= SOLIDBLEND And blend <= SHADEBLEND
	End Method
	Method TextureSize(width:Int Var,height:Int Var) Override
		m2d_sdl_texture_size(renderer.rendererPtr,Varptr width,Varptr height)
	End Method
	Method SupportsRenderImage:Int(width:Int,height:Int,flags:Int) Override
		If Not SupportsImageFlags(flags) Or Not ValidTextureSize(width,height) Then Return False
		Return True
	End Method
	Method SupportsImageFlags:Int(flags:Int) Override
		Return (flags & ~(MASKEDIMAGE | FILTEREDIMAGE | DYNAMICIMAGE)) = 0
	End Method
End Type

Type TSDLRenderMax2DDriver Extends TMax2DDriver
	Method GraphicsModes:TGraphicsMode[]() Override
		Return SDLGraphicsDriver().GraphicsModes()
	End Method
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
	Method ToString:String() Override
		Return "Max2D SDL3 Renderer"
	End Method
	Method GetHandle:Byte Ptr(handleType:EGraphicsHandleType=EGraphicsHandleType.Window) Override
		If Not current Then Return Null
		Local window:TSDLWindow = TSDLGraphics(current.context.graphics)._context.window
		If handleType=EGraphicsHandleType.Display Then Return window.GetDisplayHandle()
		Return window.GetHandle()
	End Method
End Type

Function SDLRenderMax2DDriver:TSDLRenderMax2DDriver()
	Global driver:TSDLRenderMax2DDriver = New TSDLRenderMax2DDriver
	Return driver
End Function

Rem
bbdoc: Selects SDL's renderer for subsequently created windows.
about: Call before Graphics. Use "gpu" for the GPU renderer. Returns False if an
existing environment override takes priority. Does not change existing windows.
End Rem
Function SetSDLRenderMax2DRenderer:Int(name:String)
	Local utf8:Byte Ptr = name.ToUTF8String()
	Local ok:Int = m2d_sdl_renderer_hint(utf8)
	MemFree(utf8)
	Return ok
End Function

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
