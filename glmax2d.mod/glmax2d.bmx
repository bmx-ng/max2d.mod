SuperStrict

Rem
bbdoc: Draw with the desktop OpenGL Max2D backend.
End Rem
Module Max2D.GLMax2D
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Core
Import BRL.GLGraphics
Import "glue.c"
?osx
Import "drawable.m"
?

Rem
bbdoc: Native OpenGL texture storage owned by a Max2D context.
End Rem
Type TGLImageFrame Extends TImageFrame

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: Releases this frame's native graphics resources on the rendering thread.
	End Rem
 Method NativeDestroy() Override
  owner.Activate()
  m2d_gl_destroy(native)
  native=Null
 End Method

End Type

Rem
bbdoc: Max2D rendering context implemented with OpenGL.
End Rem
Type TGLMax2DContext Extends TMax2DContext

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: Throws the backend's error when a native operation fails.
	param: Nonzero for native-operation success; zero triggers an exception.
	End Rem
 Method Require(ok:Int)
  If Not ok Then Throw "Max2D OpenGL: "+String.FromUTF8String(m2d_gl_error())
 End Method

	Rem
	bbdoc: Returns the backend handle for an image frame, or Null for no texture.
	param: Texture frame to sample, or Null for untextured geometry.
	End Rem
 Method NativeFrame:Byte Ptr(frame:TImageFrame)
  If frame Then Return TGLImageFrame(frame).native
 End Method

	Rem
	bbdoc: Makes this graphics context current for native rendering operations.
	End Rem
 Method Activate() Override
  GLGraphicsDriver().SetGraphics(graphics)
 End Method

	Rem
	bbdoc: Presents the window backbuffer with the requested synchronization setting.
	param: Presentation synchronization setting; negative uses the backend default.
	End Rem
 Method Present:Int(sync:Int) Override
  Activate()
  If sync<0 Then sync=1
  GLGraphicsDriver().Flip(sync)
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
		Activate()
		Local frame:TGLImageFrame=New TGLImageFrame
		frame.native=m2d_gl_create(width,height,flags,target,False,0)
		Require(frame.native<>Null)
		Return frame
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
		Local storage:Int
		Select pixelFormat
			Case PF_RGBA16F
				storage=2
			Case PF_RGBA32F
				storage=3
			Case PF_A8
				If Not target And Not (flags & MIPMAPPEDIMAGE) Then storage=1
		End Select
		If storage=0 Then Return NativeCreate(width,height,flags,target)
		Activate()
		Local frame:TGLImageFrame=New TGLImageFrame
		frame.native=m2d_gl_create(width,height,flags,target,storage,0)
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
		If Not data Or data.LevelCount()=1 Then Return Super.TextureDataSupport(data,flags)
		If flags & DYNAMICIMAGE Or Not ValidTextureSize(data.Width(),data.Height()) Then Return ETextureFormatSupport.Unsupported
		Return TextureFormatSupport(data.Format(),flags & ~MIPMAPPEDIMAGE)
	End Method

	Rem
	bbdoc: Allocates native storage for supplied texture data and mip levels.
	param: Texture storage and mip levels to use.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method NativeCreateTexture:TImageFrame(data:TTextureData,flags:Int) Override
		If data.LevelCount()=1 And data.Format()<>PF_BC1_RGBA And data.Format()<>PF_BC3_RGBA Then Return Super.NativeCreateTexture(data,flags)
		Activate()
		Local storage:Int
		Select data.Format()
			Case PF_BC1_RGBA
				storage=4
			Case PF_BC3_RGBA
				storage=5
			Case PF_A8
				storage=1
			Case PF_RGBA16F
				storage=2
			Case PF_RGBA32F
				storage=3
		End Select
		Local frame:TGLImageFrame=New TGLImageFrame
		frame.native=m2d_gl_create(data.Width(),data.Height(),flags,False,storage,data.LevelCount())
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
		If data.Format()=PF_BC1_RGBA Or data.Format()=PF_BC3_RGBA Then
			Activate()
			For Local index:Int=0 Until data.LevelCount()
				Local level:TTextureLevel=data.Level(index)
				Require(m2d_gl_update_compressed(NativeFrame(frame),index,level.Data(),level.Pitch(),level.Width(),level.Height()))
			Next
			Return
		End If
		If data.LevelCount()>1 Then
			Activate()
			For Local index:Int=0 Until data.LevelCount()
				Local level:TTextureLevel=data.Level(index)
				Require(m2d_gl_update_level(NativeFrame(frame),index,level.Data(),level.Pitch(),level.Width(),level.Height()))
			Next
			Return
		End If
		If data.Format()<>PF_RGBA16F And data.Format()<>PF_RGBA32F Then
			Super.NativeUpdateTexture(frame,data)
			Return
		End If
		Activate()
		Local level:TTextureLevel=data.Level()
		Require(m2d_gl_update(NativeFrame(frame),level.Data(),level.Pitch(),0,0,level.Width(),level.Height()))
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
		Activate()
		Local region:TPixmap=UploadRegion(pixmap,x,y,w,h,frame.pixelFormat)
		Require(m2d_gl_update(NativeFrame(frame),region.pixels,region.pitch,x,y,w,h))
	End Method

	Rem
	bbdoc: Submits an interleaved triangle batch to the native renderer.
	param: Texture frame to sample, or Null for untextured geometry.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	param: Interleaved vertices, with eight floats per vertex: x, y, r, g, b, a, u, v.
	param: Number of items to process.
	End Rem
 Method NativeSubmit(frame:TImageFrame,blend:Int,vertices:Float Ptr,count:Int) Override
  Activate()
  Local result:Int=m2d_gl_submit(native,NativeFrame(target),NativeFrame(frame),blend,vertices,count)
  Require(result)
  stats.mipmapGenerations:+result-1
 End Method

	Rem
	bbdoc: Gets the window coordinate extent used by mouse input.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
 Method NativeInputSize(width:Int Var,height:Int Var) Override
  TGLGraphics(graphics).ClientSize(width,height)
 End Method

	Rem
	bbdoc: Gets the drawable window dimensions in native pixels.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
 Method NativeOutputSize(width:Int Var,height:Int Var) Override
?osx
  Activate()
  If m2d_gl_drawable_size(Varptr width,Varptr height) Then Return
?
  TGLGraphics(graphics).ClientSize(width,height)
 End Method

	Rem
	bbdoc: Applies the render target, presentation transform and clipping rectangle.
	param: Render-target frame, or Null for the window backbuffer.
	param: Virtual dimensions, presentation and clipping settings.
	End Rem
 Method NativeView(frame:TImageFrame,view:TMax2DView) Override
  Activate()
  Require(m2d_gl_view(native,NativeFrame(frame),pixelWidth,pixelHeight,pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight,..
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
  Activate()
  Require(m2d_gl_clear(native,NativeFrame(target),view.presentation=VIRTUAL_LETTERBOX Or view.presentation=VIRTUAL_INTEGER,..
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
  Activate()
  Local width:Int,height:Int
  NativeOutputSize(width,height)
  Local pixmap:TPixmap=CreatePixmap(w,h,PF_RGBA8888)
  Require(m2d_gl_read(native,NativeFrame(frame),width,height,x,y,w,h,pixmap.pixels,pixmap.pitch))
  Return pixmap
 End Method

	Rem
	bbdoc: Reports whether a blend mode is supported by this context.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	End Rem
 Method SupportsBlend:Int(blend:Int) Override
  Return blend>=MASKBLEND And blend<=SHADEBLEND
 End Method

	Rem
	bbdoc: Reports native, converted or unsupported storage for a texture format.
	param: Pixel storage format from BRL.PixelFormat.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method TextureFormatSupport:ETextureFormatSupport(pixelFormat:Int,flags:Int) Override
		If pixelFormat=PF_BC1_RGBA Or pixelFormat=PF_BC3_RGBA Then
			If Not SupportsImageFlags(flags) Or (flags & (MIPMAPPEDIMAGE|DYNAMICIMAGE)) Then Return ETextureFormatSupport.Unsupported
			Activate()
			If m2d_gl_compressed_supported() Then Return ETextureFormatSupport.Native
			Return ETextureFormatSupport.Unsupported
		End If
		Local support:ETextureFormatSupport=Super.TextureFormatSupport(pixelFormat,flags)
		If pixelFormat=PF_RGBA16F Or pixelFormat=PF_RGBA32F Then
			If Not SupportsImageFlags(flags) Or (flags & MIPMAPPEDIMAGE) Then Return ETextureFormatSupport.Unsupported
			Activate()
			Local bits:Int=16
			If pixelFormat=PF_RGBA32F Then bits=32
			If m2d_gl_float_supported(bits) Then Return ETextureFormatSupport.Native
			Return ETextureFormatSupport.Unsupported
		End If
		If support=ETextureFormatSupport.Converted And Not (flags & MIPMAPPEDIMAGE) Then Return ETextureFormatSupport.Native
		Return support
	End Method

	Rem
	bbdoc: Gets maximum supported texture dimensions, with zero for an unreported limit.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method TextureSize(width:Int Var,height:Int Var) Override
		Activate()
		m2d_gl_texture_size(native,Varptr width,Varptr height)
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
		If (flags & MIPMAPPEDIMAGE) Or Not SupportsRenderImage(width,height,flags) Then Return False
		Local bits:Int=16
		If pixelFormat=PF_RGBA32F Then bits=32
		Return m2d_gl_float_target_supported(bits)
	End Method

	Rem
	bbdoc: Reads native render-target storage without reducing floating-point range.
	param: Native image frame owned by this context.
	End Rem
	Method NativeReadTexture:TTextureData(frame:TImageFrame) Override
		If frame.pixelFormat=PF_RGBA8888 Then Return Super.NativeReadTexture(frame)
		Activate()
		Local size:Long=GetPixelFormatInfo(PF_RGBA32F).StorageSize(frame.width,frame.height)
		If size>$7fffffff Then Throw "Max2D: floating-point readback exceeds byte-array size limit"
		Local bytes:Byte[]=New Byte[Int(size)]
		Require(m2d_gl_read_float(NativeFrame(frame),bytes))
		Return TTextureData.Create([TTextureLevel.Create(frame.width,frame.height,PF_RGBA32F,bytes)])
	End Method

	Rem
	bbdoc: Checks render-target support for dimensions and image flags.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method SupportsRenderImage:Int(width:Int,height:Int,flags:Int) Override
		If Not SupportsImageFlags(flags) Or Not ValidTextureSize(width,height) Then Return False
		Return m2d_gl_render_image(width,height)
	End Method

	Rem
	bbdoc: Reports whether an image flag combination is supported by this context.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
 Method SupportsImageFlags:Int(flags:Int) Override
  Return (flags & ~(MASKEDIMAGE|FILTEREDIMAGE|MIPMAPPEDIMAGE|DYNAMICIMAGE))=0
 End Method

	Rem
	bbdoc: Reports whether runtime exclusive fullscreen switching is implemented.
	End Rem
 Method SupportsFullscreen:Int() Override
  Return TGLGraphics(graphics).SupportsFullscreen()
 End Method

	Rem
	bbdoc: Reports whether runtime borderless fullscreen switching is implemented.
	End Rem
 Method SupportsBorderlessFullscreen:Int() Override
  Return TGLGraphics(graphics).SupportsBorderless()
 End Method

	Rem
	bbdoc: Returns the established windowed, exclusive or borderless fullscreen mode.
	End Rem
 Method WindowMode:Int() Override
  If TGLGraphics(graphics).IsBorderless() Then Return MAX2D_BORDERLESS_FULLSCREEN
  Return Super.WindowMode()
 End Method

	Rem
	bbdoc: Changes the window's presentation mode and refreshes its native resources.
	param: MAX2D_WINDOWED, MAX2D_FULLSCREEN or MAX2D_BORDERLESS_FULLSCREEN.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Refresh rate in hertz; zero selects the backend default.
	End Rem
 Method SetWindowMode(mode:Int,width:Int,height:Int,hertz:Int) Override
  Activate()
  Local g:TGLGraphics=TGLGraphics(graphics)
  If mode=MAX2D_FULLSCREEN Then
   g.SetFullscreen(True,width,height,hertz)
  Else
   g.SetFullscreen(False)
   If mode=MAX2D_BORDERLESS_FULLSCREEN Then g.SetBorderless(True)
  End If
 End Method

	Rem
	bbdoc: Requests a new window size.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
 Method Resize(width:Int,height:Int) Override
  Activate()
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
  Try
   graphics.Position(x,y)
  Catch error:Object
   Local selected:TMax2DGraphics=TMax2DGraphics.selected
   If selected And selected.context=Self Then SetGraphics(selected)
   Throw error
  End Try
 End Method

	Rem
	bbdoc: Closes the graphics resources owned by this object.
	End Rem
 Method Close() Override
  If closed Then Return
  Local previous:TMax2DGraphics=TMax2DGraphics.selected
  Activate()
  Flush()
  target=Null
  While Not frames.IsEmpty()
   TImageFrame(frames.RemoveFirst()).Dispose()
  Wend
  uploadImage=Null
  m2d_gl_close(native); native=Null
  graphics.Close(); graphics=Null; closed=True
  If previous And previous.context<>Self And Not previous.context.closed Then previous.context.Activate()
 End Method

End Type

Rem
bbdoc: Graphics driver for the OpenGL Max2D backend.
End Rem
Type TGLMax2DDriver Extends TMax2DDriver

	Rem
	bbdoc: Returns display modes reported by the underlying graphics driver.
	End Rem
 Method GraphicsModes:TGraphicsMode[]() Override
  If current And TGLGraphics(current.context.graphics).SupportsFullscreen() Then Return TGLGraphics(current.context.graphics).FullscreenModes()
  Return GLGraphicsDriver().GraphicsModes()
 End Method

	Rem
	bbdoc: Reports whether the driver supports resizing its graphics windows.
	End Rem
 Method CanResize:Int() Override
  Return GLGraphicsDriver().CanResize()
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
  ' Creating a native GL context changes the current context. Submit the old
  ' canvas first, then restore it until the new canvas is explicitly selected.
  Local previous:TMax2DGraphics=TMax2DGraphics.selected
  If previous And Not previous.context.closed Then previous.context.Flush()
  Local graphics:TGLGraphics=GLGraphicsDriver().CreateGraphics(width,height,depth,hertz,flags|GRAPHICS_BACKBUFFER,x,y)
  If Not graphics Or Not graphics._context Then Return Null
  Local context:TGLMax2DContext=New TGLMax2DContext
  context.graphics=graphics
  Try
   context.Activate()
   context.native=m2d_gl_open()
   context.Require(context.native<>Null)
  Catch error:Object
   context.Close()
   Throw error
  End Try
  If previous And Not previous.context.closed Then previous.context.Activate()
  Return context
 End Method

	Rem
	bbdoc: Returns the renderer's descriptive name.
	End Rem
 Method ToString:String() Override
  Return "Max2D OpenGL 2.1"
 End Method

End Type

Rem
bbdoc: Returns the shared OpenGL Max2D graphics driver.
End Rem
Function GLMax2DDriver:TGLMax2DDriver()
 Global driver:TGLMax2DDriver=New TGLMax2DDriver
 Return driver
End Function

?osx
Extern "C"
 Function m2d_gl_drawable_size:Int(width:Int Ptr,height:Int Ptr)
End Extern
?

Extern "C"
 Function m2d_gl_error:Byte Ptr()
 Function m2d_gl_open:Byte Ptr()
 Function m2d_gl_close(context:Byte Ptr)
	Function m2d_gl_compressed_supported:Int()
	Function m2d_gl_update_compressed:Int(frame:Byte Ptr,level:Int,pixels:Byte Ptr,pitch:Int,w:Int,h:Int)
	Function m2d_gl_float_target_supported:Int(bits:Int)
	Function m2d_gl_read_float:Int(frame:Byte Ptr,pixels:Byte Ptr)
	Function m2d_gl_float_supported:Int(bits:Int)
 Function m2d_gl_create:Byte Ptr(width:Int,height:Int,flags:Int,target:Int,storage:Int,levels:Int)
 Function m2d_gl_destroy(frame:Byte Ptr)
	Function m2d_gl_update_level:Int(frame:Byte Ptr,level:Int,pixels:Byte Ptr,pitch:Int,w:Int,h:Int)
 Function m2d_gl_update:Int(frame:Byte Ptr,pixels:Byte Ptr,pitch:Int,x:Int,y:Int,w:Int,h:Int)
 Function m2d_gl_submit:Int(context:Byte Ptr,target:Byte Ptr,frame:Byte Ptr,blend:Int,vertices:Float Ptr,count:Int)
 Function m2d_gl_view:Int(context:Byte Ptr,target:Byte Ptr,width:Int,height:Int,ox:Int,oy:Int,vw:Int,vh:Int,sx:Float,sy:Float,x:Int,y:Int,w:Int,h:Int)
 Function m2d_gl_clear:Int(context:Byte Ptr,target:Byte Ptr,bars:Int,r:Int,g:Int,b:Int,a:Float,br:Int,bg:Int,bb:Int)
 Function m2d_gl_read:Int(context:Byte Ptr,target:Byte Ptr,width:Int,height:Int,x:Int,y:Int,w:Int,h:Int,pixels:Byte Ptr,pitch:Int)

	Function m2d_gl_render_image:Int(width:Int,height:Int)
	Function m2d_gl_texture_size(context:Byte Ptr,width:Int Ptr,height:Int Ptr)
End Extern

SetGraphicsDriver(GLMax2DDriver(),0)
