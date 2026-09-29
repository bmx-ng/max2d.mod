SuperStrict
Rem
bbdoc: Max2D drawing through SDL's native GPU API (Metal, Vulkan or Direct3D 12).
End Rem
Module Max2D.SDL3GPUMax2D
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
ModuleInfo "CC_OPTS: -I%PWD%/../../sdl3.mod/sdl3.mod/SDL3/include"

Import Max2D.Core
Import SDL3.SDL3Graphics
Import "glue.c"

Rem
bbdoc: Native SDL3 GPU texture storage owned by a Max2D context.
End Rem
Type TSDLGPUImageFrame Extends TImageFrame

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: Releases this frame's native graphics resources on the rendering thread.
	End Rem
	Method NativeDestroy() Override
		If native Then m2d_gpu_destroy(native)
		native=Null
	End Method

End Type

Rem
bbdoc: Max2D rendering context implemented with SDL3 GPU.
End Rem
Type TSDLGPUMax2DContext Extends TMax2DContext

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: Throws the backend's error when a native operation fails.
	param: Nonzero for native-operation success; zero triggers an exception.
	End Rem
	Method Require(ok:Int)
		If Not ok Then Throw "Max2D SDL GPU: "+SDL_GetError()
	End Method

	Rem
	bbdoc: Returns the backend handle for an image frame, or Null for no texture.
	param: Texture frame to sample, or Null for untextured geometry.
	End Rem
	Method NativeFrame:Byte Ptr(frame:TImageFrame)
		If frame Then Return TSDLGPUImageFrame(frame).native
	End Method

	Rem
	bbdoc: Makes this graphics context current for native rendering operations.
	End Rem
	Method Activate() Override
		SDLGraphicsDriver().SetGraphics(graphics)
	End Method

	Rem
	bbdoc: Closes the graphics resources owned by this object.
	End Rem
	Method Close() Override
		If closed Then Return
		Flush()
		target=Null
		While Not frames.IsEmpty()
			TImageFrame(frames.RemoveFirst()).Dispose()
		Wend
		m2d_gpu_close(native)
		native=Null
		Super.Close()
	End Method

	Rem
	bbdoc: Reports whether runtime exclusive fullscreen switching is implemented.
	End Rem
	Method SupportsFullscreen:Int() Override
		Return True
	End Method

	Rem
	bbdoc: Reports whether runtime borderless fullscreen switching is implemented.
	End Rem
	Method SupportsBorderlessFullscreen:Int() Override
		Return True
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
		Require(TSDLGraphics(graphics)._context.window.GetSize(width,height))
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
	bbdoc: Presents the window backbuffer with the requested synchronization setting.
	param: Presentation synchronization setting; negative uses the backend default.
	End Rem
	Method Present:Int(sync:Int) Override
		Require(m2d_gpu_present(native,sync))
		Return True
	End Method

	Rem
	bbdoc: Gets the drawable window dimensions in native pixels.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method NativeOutputSize(width:Int Var,height:Int Var) Override
		Require(m2d_gpu_output(native,Varptr width,Varptr height))
	End Method

	Rem
	bbdoc: Maps a pixel format to the native GPU glue's storage-kind identifier.
	param: Pixel storage format from BRL.PixelFormat.
	End Rem
	Method TextureKind:Int(pixelFormat:Int)
		Select pixelFormat
			Case PF_RGBA8888
				Return 0
			Case PF_A8
				Return 1
			Case PF_RGBA16F
				Return 2
			Case PF_RGBA32F
				Return 3
			Case PF_BC1_RGBA
				Return 4
			Case PF_BC3_RGBA
				Return 5
		End Select
		Return -1
	End Method

	Rem
	bbdoc: Allocates a native image frame or render target.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Whether to allocate render-target storage.
	End Rem
	Method NativeCreate:TImageFrame(width:Int,height:Int,flags:Int,target:Int) Override
		Return NativeCreateFormat(width,height,flags,target,PF_RGBA8888)
	End Method

	Rem
	bbdoc: Allocates a native image frame with the requested storage format.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Whether to allocate render-target storage.
	param: Pixel storage format from BRL.PixelFormat.
	End Rem
	Method NativeCreateFormat:TImageFrame(width:Int,height:Int,flags:Int,target:Int,pixelFormat:Int) Override
		Local frame:TSDLGPUImageFrame=New TSDLGPUImageFrame
		frame.native=m2d_gpu_create(native,width,height,flags,target,TextureKind(pixelFormat),0)
		Require(frame.native<>Null)
		frame.pixelFormat=pixelFormat
		Return frame
	End Method

	Rem
	bbdoc: Checks whether supplied texture data can be uploaded by this context.
	param: Texture storage and mip levels to use.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method TextureDataSupport:ETextureFormatSupport(data:TTextureData,flags:Int) Override
		If data And (data.Format()=PF_BC1_RGBA Or data.Format()=PF_BC3_RGBA) Then
			If Not ValidTextureSize(data.Width(),data.Height()) Or data.Width() Mod 4 Or data.Height() Mod 4 Then Return ETextureFormatSupport.Unsupported
			If data.LevelCount()>1 Then flags=flags & ~MIPMAPPEDIMAGE
			Return TextureFormatSupport(data.Format(),flags)
		End If
		If Not data Or data.LevelCount()=1 Then Return Super.TextureDataSupport(data,flags)
		If (flags & DYNAMICIMAGE) Or Not ValidTextureSize(data.Width(),data.Height()) Then Return ETextureFormatSupport.Unsupported
		Return TextureFormatSupport(data.Format(),flags & ~MIPMAPPEDIMAGE)
	End Method

	Rem
	bbdoc: Allocates native storage for supplied texture data and mip levels.
	param: Texture storage and mip levels to use.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method NativeCreateTexture:TImageFrame(data:TTextureData,flags:Int) Override
		If data.LevelCount()=1 Then Return Super.NativeCreateTexture(data,flags)
		Local frame:TSDLGPUImageFrame=New TSDLGPUImageFrame
		frame.native=m2d_gpu_create(native,data.Width(),data.Height(),flags,False,TextureKind(data.Format()),data.LevelCount())
		Require(frame.native<>Null)
		frame.pixelFormat=data.Format()
		Return frame
	End Method

	Rem
	bbdoc: Uploads the supplied texture levels into an existing native frame.
	param: Native image frame owned by this context.
	param: Texture storage and mip levels to use.
	End Rem
	Method NativeUpdateTexture(frame:TImageFrame,data:TTextureData) Override
		If data.LevelCount()=1 And data.Format()<>PF_RGBA16F And data.Format()<>PF_RGBA32F And data.Format()<>PF_BC1_RGBA And data.Format()<>PF_BC3_RGBA Then
			Super.NativeUpdateTexture(frame,data)
			Return
		End If
		For Local index:Int=0 Until data.LevelCount()
			Local level:TTextureLevel=data.Level(index)
			Require(m2d_gpu_update_level(NativeFrame(frame),level.Data(),level.Pitch(),index,0,0,level.Width(),level.Height()))
		Next
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
		Local region:TPixmap=UploadRegion(pixmap,x,y,w,h,frame.pixelFormat)
		Require(m2d_gpu_update(NativeFrame(frame),region.pixels,region.pitch,x,y,w,h))
	End Method

	Rem
	bbdoc: Submits an interleaved triangle batch to the native renderer.
	param: Texture frame to sample, or Null for untextured geometry.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	param: Interleaved vertices, with eight floats per vertex: x, y, r, g, b, a, u, v.
	param: Number of items to process.
	End Rem
	Method NativeSubmit(frame:TImageFrame,blend:Int,vertices:Float Ptr,count:Int) Override
		Local result:Int=m2d_gpu_draw(native,NativeFrame(target),NativeFrame(frame),blend,vertices,count)
		Require(result)
		stats.mipmapGenerations:+result-1
	End Method

	Rem
	bbdoc: Records compact affine rectangles in submission order.
	param: Texture to sample, or Null for solid geometry.
	param: Blend mode.
	param: Sixteen-float rectangle records defined by TMax2DContext.NativeSubmitQuads.
	param: Number of rectangles.
	End Rem
	Method NativeSubmitQuads(frame:TImageFrame,blend:Int,vertices:Float Ptr,count:Int) Override
		Local result:Int=m2d_gpu_draw_quads(native,NativeFrame(target),NativeFrame(frame),blend,vertices,count)
		Require(result)
		stats.mipmapGenerations:+result-1
	End Method

	Rem
	bbdoc: Applies the render target, presentation transform and clipping rectangle.
	param: Render-target frame, or Null for the window backbuffer.
	param: Virtual dimensions, presentation and clipping settings.
	End Rem
	Method NativeView(frame:TImageFrame,view:TMax2DView) Override
		Require(m2d_gpu_view(native,NativeFrame(frame),pixelWidth,pixelHeight,pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight,..
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
		Require(m2d_gpu_clear(native,NativeFrame(target),view.presentation=VIRTUAL_LETTERBOX Or view.presentation=VIRTUAL_INTEGER,..
			red,green,blue,alpha,view.barRed,view.barGreen,view.barBlue))
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
		Local pixels:TPixmap=CreatePixmap(w,h,PF_RGBA8888)
		Require(m2d_gpu_read(native,NativeFrame(frame),x,y,w,h,pixels.pixels,pixels.pitch))
		Return pixels
	End Method

	Rem
	bbdoc: Reports whether a blend mode is supported by this context.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	End Rem
	Method SupportsBlend:Int(blend:Int) Override
		Return blend>=MASKBLEND And blend<=SHADEBLEND
	End Method

	Rem
	bbdoc: Reports whether an image flag combination is supported by this context.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method SupportsImageFlags:Int(flags:Int) Override
		If flags & ~(MASKEDIMAGE|FILTEREDIMAGE|DYNAMICIMAGE|MIPMAPPEDIMAGE) Then Return False
		Return Not (flags & MIPMAPPEDIMAGE) Or m2d_gpu_support(native,False,True)
	End Method

	Rem
	bbdoc: Reports native, converted or unsupported storage for a texture format.
	param: Pixel storage format from BRL.PixelFormat.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method TextureFormatSupport:ETextureFormatSupport(pixelFormat:Int,flags:Int) Override
		If Not SupportsImageFlags(flags) Then Return ETextureFormatSupport.Unsupported
		If (pixelFormat=PF_RGBA16F Or pixelFormat=PF_RGBA32F Or pixelFormat=PF_BC1_RGBA Or pixelFormat=PF_BC3_RGBA) And (flags & (MIPMAPPEDIMAGE|DYNAMICIMAGE)) Then Return ETextureFormatSupport.Unsupported
		Local kind:Int=TextureKind(pixelFormat)
		If kind>=0 Then
			If m2d_gpu_support(native,kind,(flags & MIPMAPPEDIMAGE)<>0) Then Return ETextureFormatSupport.Native
		End If
		Return ETextureFormatSupport.Unsupported
	End Method

	Rem
	bbdoc: Checks render-target support for dimensions, image flags and storage format.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Pixel storage format from BRL.PixelFormat.
	End Rem
	Method SupportsRenderImageFormat:Int(width:Int,height:Int,flags:Int,pixelFormat:Int) Override
		If pixelFormat=PF_RGBA8888 Then Return SupportsRenderImage(width,height,flags)
		If pixelFormat<>PF_RGBA16F And pixelFormat<>PF_RGBA32F Then Return False
		If (flags & MIPMAPPEDIMAGE) Or Not SupportsImageFlags(flags) Or Not ValidTextureSize(width,height) Then Return False
		Return m2d_gpu_target_support(native,TextureKind(pixelFormat))
	End Method

	Rem
	bbdoc: Reads native render-target storage without reducing floating-point range.
	param: Native image frame owned by this context.
	End Rem
	Method NativeReadTexture:TTextureData(frame:TImageFrame) Override
		If frame.pixelFormat=PF_RGBA8888 Then Return Super.NativeReadTexture(frame)
		Local size:Long=GetPixelFormatInfo(PF_RGBA32F).StorageSize(frame.width,frame.height)
		If size>$7fffffff Then Throw "Max2D: floating-point readback exceeds byte-array size limit"
		Local bytes:Byte[]=New Byte[Int(size)]
		Require(m2d_gpu_read_float(native,NativeFrame(frame),bytes))
		Return TTextureData.Create([TTextureLevel.Create(frame.width,frame.height,PF_RGBA32F,bytes)])
	End Method

	Rem
	bbdoc: Checks render-target support for dimensions and image flags.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method SupportsRenderImage:Int(width:Int,height:Int,flags:Int) Override
		Return SupportsImageFlags(flags) And ValidTextureSize(width,height) And m2d_gpu_support(native,False,True)
	End Method

End Type

Rem
bbdoc: Graphics driver for the SDL3 GPU Max2D backend.
End Rem
Type TSDLGPUMax2DDriver Extends TMax2DDriver

	Rem
	bbdoc: Returns display modes reported by the underlying graphics driver.
	End Rem
	Method GraphicsModes:TGraphicsMode[]() Override
		Return SDLGraphicsDriver().GraphicsModes()
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
		If flags & SDL_GRAPHICS_GL Then Throw "Max2D SDL GPU: OpenGL flags are unsupported"
		Local graphics:TSDLGraphics=SDLGraphicsDriver().CreateGraphics(width,height,depth,hertz,flags|SDL_GRAPHICS_GPU,x,y)
		If Not graphics Then Return Null
		Local context:TSDLGPUMax2DContext=New TSDLGPUMax2DContext
		context.graphics=graphics
		context.native=m2d_gpu_open(graphics._context.window.windowPtr)
		If Not context.native Then
			Local message:String=SDL_GetError()
			graphics.Close()
			Throw "Max2D SDL GPU: "+message
		End If
		context.compactQuads=m2d_gpu_compact_support(context.native)<>0
		Return context
	End Method

	Rem
	bbdoc: Returns the renderer's descriptive name.
	End Rem
	Method ToString:String() Override
		Return "Max2D SDL3 GPU"
	End Method

	Rem
	bbdoc: Gets the local handle used for drawing primitives.
	param: Kind of native graphics handle requested.
	End Rem
	Method GetHandle:Byte Ptr(handleType:EGraphicsHandleType=EGraphicsHandleType.Window) Override
		If Not current Then Return Null
		Local window:TSDLWindow=TSDLGraphics(current.context.graphics)._context.window
		If handleType=EGraphicsHandleType.Display Then Return window.GetDisplayHandle()
		Return window.GetHandle()
	End Method

End Type

Rem
bbdoc: Returns the shared SDL3 GPU Max2D graphics driver.
End Rem
Function SDLGPUMax2DDriver:TSDLGPUMax2DDriver()
	Global driver:TSDLGPUMax2DDriver=New TSDLGPUMax2DDriver
	Return driver
End Function

Rem
bbdoc: Returns the active native SDL GPU driver name, such as metal, vulkan or direct3d12.
End Rem
Function SDLGPUMax2DDriverName:String()
	Local context:TSDLGPUMax2DContext=TSDLGPUMax2DContext(TMax2DGraphics.Current().context)
	If Not context Then Throw "Max2D: current context is not SDL3 GPU"
	Return String.FromUTF8String(m2d_gpu_name(context.native))
End Function

Rem
bbdoc: Enables or disables compact sprite and glyph submission on the current SDL3 GPU context.
param: True to enable compact submission; False restores expanded triangles.
about: New contexts enable compact submission when its pipelines can be created, otherwise they use expanded triangles. Explicitly enabling it reports pipeline-creation failures. Flushes pending drawing before changing mode. Other contexts are unaffected.
End Rem
Function SetSDLGPUMax2DCompactSprites(enabled:Int)
	Local context:TSDLGPUMax2DContext=TSDLGPUMax2DContext(TMax2DGraphics.Current().context)
	If Not context Then Throw "Max2D: current context is not SDL3 GPU"
	context.Flush()
	If enabled Then context.Require(m2d_gpu_compact_support(context.native))
	context.compactQuads=enabled<>0
End Function

Extern "C"
	Function m2d_gpu_open:Byte Ptr(window:Byte Ptr)
	Function m2d_gpu_close(context:Byte Ptr)
	Function m2d_gpu_name:Byte Ptr(context:Byte Ptr)
	Function m2d_gpu_output:Int(context:Byte Ptr,width:Int Ptr,height:Int Ptr)
	Function m2d_gpu_present:Int(context:Byte Ptr,sync:Int)
	Function m2d_gpu_create:Byte Ptr(context:Byte Ptr,width:Int,height:Int,flags:Int,target:Int,kind:Int,levels:Int)
	Function m2d_gpu_target_support:Int(context:Byte Ptr,kind:Int)
	Function m2d_gpu_read_float:Int(context:Byte Ptr,frame:Byte Ptr,pixels:Byte Ptr)
	Function m2d_gpu_support:Int(context:Byte Ptr,kind:Int,renderable:Int)
	Function m2d_gpu_update_level:Int(frame:Byte Ptr,pixels:Byte Ptr,pitch:Int,level:Int,x:Int,y:Int,w:Int,h:Int)
	Function m2d_gpu_destroy(frame:Byte Ptr)
	Function m2d_gpu_update:Int(frame:Byte Ptr,pixels:Byte Ptr,pitch:Int,x:Int,y:Int,w:Int,h:Int)
	Function m2d_gpu_compact_support:Int(context:Byte Ptr)
	Function m2d_gpu_draw_quads:Int(context:Byte Ptr,target:Byte Ptr,source:Byte Ptr,blend:Int,vertices:Float Ptr,count:Int)
	Function m2d_gpu_draw:Int(context:Byte Ptr,target:Byte Ptr,source:Byte Ptr,blend:Int,vertices:Float Ptr,count:Int)
	Function m2d_gpu_view:Int(context:Byte Ptr,target:Byte Ptr,width:Int,height:Int,ox:Int,oy:Int,vw:Int,vh:Int,sx:Float,sy:Float,x:Int,y:Int,w:Int,h:Int)
	Function m2d_gpu_clear:Int(context:Byte Ptr,target:Byte Ptr,bars:Int,red:Int,green:Int,blue:Int,alpha:Float,barRed:Int,barGreen:Int,barBlue:Int)
	Function m2d_gpu_read:Int(context:Byte Ptr,target:Byte Ptr,x:Int,y:Int,w:Int,h:Int,pixels:Byte Ptr,pitch:Int)
End Extern

SetGraphicsDriver(SDLGPUMax2DDriver(),0)
