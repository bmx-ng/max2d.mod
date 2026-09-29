SuperStrict

Rem
bbdoc: Draw with the Direct3D 11 Max2D backend on Windows.
End Rem
Module Max2D.D3D11Max2D
ModuleInfo "Version: 0.06"
ModuleInfo "License: zlib/libpng"

?win32
Import Max2D.Core
Import BRL.DXGraphics
Import "glue.cpp"
Import "draw_shaders.cpp"

?win32 And d3d11_recovery_test

Rem
bbdoc: Test-only switch forcing alpha-coverage texture fallback.
End Rem
Global D3D11TestCoverageFallback:Int
?win32

Rem
bbdoc: Native Direct3D 11 texture storage owned by a Max2D context.
End Rem
Type TD3D11ImageFrame Extends TImageFrame

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: CPU texture data retained for native resource recreation.
	End Rem
	Field storage:TTextureData

	Rem
	bbdoc: CPU pixels retained for texture uploads and device recovery.
	End Rem
	Field pixels:TPixmap

	Rem
	bbdoc: Releases this frame's native graphics resources on the rendering thread.
	End Rem
 Method NativeDestroy() Override
  m2d11_destroy(native)
  native=Null;pixels=Null
		storage=Null
 End Method

End Type

Rem
bbdoc: Max2D rendering context implemented with Direct3D 11.
End Rem
Type TD3D11Max2DContext Extends TMax2DContext

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: Throws the backend's error when a native operation fails.
	param: Nonzero for native-operation success; zero triggers an exception.
	End Rem
 Method Require(ok:Int)
  If Not ok Then Throw "Max2D D3D11: "+String.FromUTF8String(m2d11_error())
 End Method

	Rem
	bbdoc: Makes this graphics context current for native rendering operations.
	End Rem
 Method Activate() Override
  D3D11GraphicsDriver().SetGraphics(graphics)
 End Method

	Rem
	bbdoc: Restores a lost device and invalidates native frames for lazy recreation.
	End Rem
 Method EnsureDevice()
  Local g:TD3D11Graphics=TD3D11Graphics(graphics)
  If native And g.DeviceStatus()>=0 Then Return
  ' Keep logical frames and CPU copies; discard every reference to the old device.
  For Local frame:TD3D11ImageFrame=EachIn frames
   m2d11_destroy(frame.native);frame.native=Null
  Next
  m2d11_close(native);native=Null
  g.RecreateDevice()
  native=m2d11_open(g.GetDirect3DDevice(),g.GetDeviceContext())
  Require(native<>Null)
  ' Restore mapping without flushing or re-entering the batch being submitted.
  If view Then NativeView(target,view)
 End Method

	Rem
	bbdoc: Recreates a missing native texture from retained CPU storage.
	param: Native image frame owned by this context.
	End Rem
	Method EnsureFrame(frame:TImageFrame)
		If Not frame Then Return
		Local f:TD3D11ImageFrame=TD3D11ImageFrame(frame)
		If f.native Then Return
		Local coverage:Int=f.pixelFormat=PF_A8
		If f.pixels Then coverage=f.pixels.format=PF_A8
?win32 And d3d11_recovery_test
		If D3D11TestCoverageFallback Then coverage=False
?win32
		Local bits:Int
		If f.pixelFormat=PF_RGBA16F Then bits=16
		If f.pixelFormat=PF_RGBA32F Then bits=32
		Local compression:Int
		If f.pixelFormat=PF_BC1_RGBA Then compression=1
		If f.pixelFormat=PF_BC3_RGBA Then compression=3
		Local levels:Int
		If f.storage And (f.storage.LevelCount()>1 Or compression) Then
			levels=f.storage.LevelCount()
			coverage=f.storage.Format()=PF_A8
?win32 And d3d11_recovery_test
			If D3D11TestCoverageFallback Then coverage=False
?win32
		End If
		f.native=m2d11_create(native,f.width,f.height,f.flags,f.target,coverage,bits,levels,compression)
		Require(f.native<>Null)
		If Not bits And Not compression Then f.pixelFormat=PF_RGBA8888
		If m2d11_coverage(f.native) Then f.pixelFormat=PF_A8
		If f.storage Then
			Require(UploadStorage(f,f.storage))
		Else If f.pixels Then
			Local region:TPixmap=UploadRegion(f.pixels,0,0,f.width,f.height,f.pixelFormat)
			Require(m2d11_update(native,f.native,region.pixels,region.pitch,0,0,f.width,f.height))
		End If
	End Method

	Rem
	bbdoc: Handles a native operation result and attempts recovery after device loss.
	param: Native operation result: zero for failure, nonzero for success.
	End Rem
 Method Operation:Int(result:Int)
?win32 And d3d11_recovery_test
  If D3D11TestOperationRemoved Then
   D3D11TestOperationRemoved=False;D3D11TestRemoved=True;result=0
  End If
?win32
  If result Then Return True
  If TD3D11Graphics(graphics).DeviceStatus()<0 Then
   EnsureDevice()
   Return False
  End If
  Require(False)
 End Method

	Rem
	bbdoc: Reports whether the native graphics device is ready for drawing.
	End Rem
 Method Ready:Int()
  EnsureDevice()
  Try
   Return TD3D11Graphics(graphics).Ready()
  Catch error:Object
   If TD3D11Graphics(graphics).DeviceStatus()>=0 Then Throw error
   EnsureDevice()
   Return False
  End Try
 End Method

	Rem
	bbdoc: Returns the active native render-target handle.
	End Rem
 Method RenderTarget:Byte Ptr()
  EnsureFrame(target)
  If target Then Return m2d11_target(TD3D11ImageFrame(target).native)
  Return TD3D11Graphics(graphics).GetRenderTarget()
 End Method

	Rem
	bbdoc: Presents the window backbuffer with the requested synchronization setting.
	param: Presentation synchronization setting; negative uses the backend default.
	End Rem
 Method Present:Int(sync:Int) Override
  Activate()
  If sync<0 Then sync=1
  EnsureDevice()
  Local result:Int
  Try
   result=D3D11GraphicsDriver().Flip(sync)
  Catch error:Object
   If TD3D11Graphics(graphics).DeviceStatus()>=0 Then Throw error
   EnsureDevice()
   Return False
  End Try
  If Not result Then Delay(10)
  Return result
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
		EnsureDevice()
		Local frame:TD3D11ImageFrame=New TD3D11ImageFrame
		Local coverage:Int=pixelFormat=PF_A8
?win32 And d3d11_recovery_test
		If D3D11TestCoverageFallback Then coverage=False
?win32
		Local bits:Int
		If pixelFormat=PF_RGBA16F Then bits=16
		If pixelFormat=PF_RGBA32F Then bits=32
		frame.native=m2d11_create(native,width,height,flags,target,coverage,bits,0,0)
		Require(frame.native<>Null)
		If m2d11_coverage(frame.native) Then frame.pixelFormat=PF_A8
		If bits Then frame.pixelFormat=pixelFormat
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
		If flags & DYNAMICIMAGE Or Not ValidTextureSize(data.Width(),data.Height()) Then Return ETextureFormatSupport.Unsupported
		Local support:ETextureFormatSupport=TextureFormatSupport(data.Format(),flags & ~MIPMAPPEDIMAGE)
		If support=ETextureFormatSupport.Unsupported Then Return support
		Local bits:Int
		If data.Format()=PF_RGBA16F Then bits=16
		If data.Format()=PF_RGBA32F Then bits=32
		Local coverage:Int=data.Format()=PF_A8 And support=ETextureFormatSupport.Native
		If Not m2d11_supplied_supported(native,coverage,bits) Then Return ETextureFormatSupport.Unsupported
		Return support
	End Method

	Rem
	bbdoc: Allocates native storage for supplied texture data and mip levels.
	param: Texture storage and mip levels to use.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method NativeCreateTexture:TImageFrame(data:TTextureData,flags:Int) Override
		If data.LevelCount()=1 And data.Format()<>PF_BC1_RGBA And data.Format()<>PF_BC3_RGBA Then Return Super.NativeCreateTexture(data,flags)
		EnsureDevice()
		Local frame:TD3D11ImageFrame=New TD3D11ImageFrame
		Local coverage:Int=data.Format()=PF_A8
?win32 And d3d11_recovery_test
		If D3D11TestCoverageFallback Then coverage=False
?win32
		Local bits:Int
		If data.Format()=PF_RGBA16F Then bits=16
		If data.Format()=PF_RGBA32F Then bits=32
		Local compression:Int
		If data.Format()=PF_BC1_RGBA Then compression=1
		If data.Format()=PF_BC3_RGBA Then compression=3
		frame.native=m2d11_create(native,data.Width(),data.Height(),flags,False,coverage,bits,data.LevelCount(),compression)
		Require(frame.native<>Null)
		If m2d11_coverage(frame.native) Then frame.pixelFormat=PF_A8
		If bits Or compression Then frame.pixelFormat=data.Format()
		Return frame
	End Method

	Rem
	bbdoc: Uploads retained texture data and mip levels to a native frame.
	param: Native image frame owned by this context.
	param: Texture storage and mip levels to use.
	End Rem
	Method UploadStorage:Int(frame:TD3D11ImageFrame,data:TTextureData)
		If data.LevelCount()=1 And data.Format()<>PF_BC1_RGBA And data.Format()<>PF_BC3_RGBA Then
			Local level:TTextureLevel=data.Level()
			Return m2d11_update(native,frame.native,level.Data(),level.Pitch(),0,0,level.Width(),level.Height())
		End If
		For Local index:Int=0 Until data.LevelCount()
			Local level:TTextureLevel=data.Level(index)
			Local pixels:Byte Ptr=level.Data()
			Local pitch:Int=level.Pitch()
			Local converted:TPixmap
			If data.Format()=PF_A8 And frame.pixelFormat=PF_RGBA8888 Then
				converted=data.ToPixmap(index).Convert(PF_RGBA8888)
				pixels=converted.pixels
				pitch=converted.pitch
			End If
			If Not m2d11_update_level(native,frame.native,index,pixels,pitch) Then Return False
		Next
		Return True
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
		Local f:TD3D11ImageFrame=TD3D11ImageFrame(frame)
		f.storage=data
		EnsureDevice()
		EnsureFrame(frame)
		Operation(UploadStorage(f,data))
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
		Local f:TD3D11ImageFrame=TD3D11ImageFrame(frame)
		' Retain the latest full source even if replacement fails during this update.
		If Not f.pixels Then
			f.pixels=pixmap.Copy()
		Else
			f.pixels.Paste(pixmap.Window(x,y,w,h),x,y)
		End If
		EnsureDevice()
		EnsureFrame(frame)
		Local region:TPixmap=UploadRegion(pixmap,x,y,w,h,f.pixelFormat)
		Operation(m2d11_update(native,f.native,region.pixels,region.pitch,x,y,w,h))
	End Method

	Rem
	bbdoc: Submits an interleaved triangle batch to the native renderer.
	param: Texture frame to sample, or Null for untextured geometry.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	param: Interleaved vertices, with eight floats per vertex: x, y, r, g, b, a, u, v.
	param: Number of items to process.
	End Rem
 Method NativeSubmit(frame:TImageFrame,blend:Int,vertices:Float Ptr,count:Int) Override
  EnsureDevice()
  If Not target And Not Ready() Then Return
  EnsureFrame(frame)
  Local image:Byte Ptr
  If frame Then image=TD3D11ImageFrame(frame).native
  Local result:Int=m2d11_submit(native,RenderTarget(),image,blend,vertices,count,target<>Null)
  If Not Operation(result) Then Return
  stats.mipmapGenerations:+result-1
  If target Then m2d11_dirty(TD3D11ImageFrame(target).native)
 End Method

	Rem
	bbdoc: Gets the window coordinate extent used by mouse input.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
 Method NativeInputSize(width:Int Var,height:Int Var) Override
  Local rect:Int[4]
  GetClientRect(TD3D11Graphics(graphics)._hwnd,rect)
  width=rect[2];height=rect[3]
 End Method

	Rem
	bbdoc: Gets the drawable window dimensions in native pixels.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
 Method NativeOutputSize(width:Int Var,height:Int Var) Override
  Local depth:Int,hertz:Int,flags:Long,x:Int,y:Int
  graphics.GetSettings(width,height,depth,hertz,flags,x,y)
 End Method

	Rem
	bbdoc: Applies the render target, presentation transform and clipping rectangle.
	param: Render-target frame, or Null for the window backbuffer.
	param: Virtual dimensions, presentation and clipping settings.
	End Rem
 Method NativeView(frame:TImageFrame,view:TMax2DView) Override
  EnsureDevice()
  Require(m2d11_view(native,pixelWidth,pixelHeight,pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight,..
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
  EnsureDevice()
  If Not target And Not Ready() Then Return
  If Not Operation(m2d11_clear(native,RenderTarget(),view.presentation=VIRTUAL_LETTERBOX Or view.presentation=VIRTUAL_INTEGER,..
   red,green,blue,alpha,view.barRed,view.barGreen,view.barBlue,target<>Null)) Then Return
  If target Then m2d11_dirty(TD3D11ImageFrame(target).native)
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
  EnsureDevice();EnsureFrame(frame)
  If Not frame And Not Ready() Then Throw "Max2D D3D11: readback unavailable while minimized"
  Local pixmap:TPixmap=CreatePixmap(w,h,PF_RGBA8888)
  Local surface:Byte Ptr
  If frame Then
   surface=m2d11_target(TD3D11ImageFrame(frame).native)
  Else
   surface=TD3D11Graphics(graphics).GetRenderTarget()
  End If
  If Not Operation(m2d11_read(native,surface,x,y,w,h,pixmap.pixels,pixmap.pitch,frame<>Null)) Then Throw "Max2D D3D11: device replaced during readback; redraw and retry"
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
			If Not SupportsImageFlags(flags & ~MIPMAPPEDIMAGE) Or (flags & (MIPMAPPEDIMAGE|DYNAMICIMAGE)) Then Return ETextureFormatSupport.Unsupported
			Local compression:Int=1
			If pixelFormat=PF_BC3_RGBA Then compression=3
			If m2d11_compressed_supported(native,compression) Then Return ETextureFormatSupport.Native
			Return ETextureFormatSupport.Unsupported
		End If
		Local support:ETextureFormatSupport=Super.TextureFormatSupport(pixelFormat,flags)
		If pixelFormat=PF_RGBA16F Or pixelFormat=PF_RGBA32F Then
			If Not SupportsImageFlags(flags) Or (flags & MIPMAPPEDIMAGE) Then Return ETextureFormatSupport.Unsupported
			Local bits:Int=16
			If pixelFormat=PF_RGBA32F Then bits=32
			If m2d11_float_supported(native,bits) Then Return ETextureFormatSupport.Native
			Return ETextureFormatSupport.Unsupported
		End If
		If support<>ETextureFormatSupport.Converted Or (flags & MIPMAPPEDIMAGE) Then Return support
?win32 And d3d11_recovery_test
		If D3D11TestCoverageFallback Then Return support
?win32
		If m2d11_coverage_supported(native) Then Return ETextureFormatSupport.Native
		Return support
	End Method

	Rem
	bbdoc: Gets maximum supported texture dimensions, with zero for an unreported limit.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method TextureSize(width:Int Var,height:Int Var) Override
		EnsureDevice()
		m2d11_texture_size(native,Varptr width,Varptr height)
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
		Local bits:Int=16
		If pixelFormat=PF_RGBA32F Then bits=32
		Return m2d11_float_target_supported(native,bits)
	End Method

	Rem
	bbdoc: Reads native render-target storage without reducing floating-point range.
	param: Native image frame owned by this context.
	End Rem
	Method NativeReadTexture:TTextureData(frame:TImageFrame) Override
		If frame.pixelFormat=PF_RGBA8888 Then Return Super.NativeReadTexture(frame)
		EnsureDevice()
		EnsureFrame(frame)
		Local size:Long=GetPixelFormatInfo(PF_RGBA32F).StorageSize(frame.width,frame.height)
		If size>$7fffffff Then Throw "Max2D: floating-point readback exceeds byte-array size limit"
		Local bytes:Byte[]=New Byte[Int(size)]
		If Not Operation(m2d11_read_float(native,TD3D11ImageFrame(frame).native,bytes)) Then Throw "Max2D D3D11: device replaced during readback; redraw and retry"
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
		Return m2d11_render_image(native,width,height)
	End Method

	Rem
	bbdoc: Reports whether an image flag combination is supported by this context.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
 Method SupportsImageFlags:Int(flags:Int) Override
  If (flags & ~(MASKEDIMAGE|FILTEREDIMAGE|MIPMAPPEDIMAGE|DYNAMICIMAGE))<>0 Then Return False
  EnsureDevice()
  Return Not (flags & MIPMAPPEDIMAGE) Or m2d11_mipmaps(native)
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
  Local g:TD3D11Graphics=TD3D11Graphics(graphics)
  If g._borderless Then Return MAX2D_BORDERLESS_FULLSCREEN
  If g._depth Then Return MAX2D_FULLSCREEN
  Return MAX2D_WINDOWED
 End Method

	Rem
	bbdoc: Changes the window's presentation mode and refreshes its native resources.
	param: MAX2D_WINDOWED, MAX2D_FULLSCREEN or MAX2D_BORDERLESS_FULLSCREEN.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Refresh rate in hertz; zero selects the backend default.
	End Rem
 Method SetWindowMode(mode:Int,width:Int,height:Int,hertz:Int) Override
  EnsureDevice()
  Local g:TD3D11Graphics=TD3D11Graphics(graphics)
  If mode=MAX2D_BORDERLESS_FULLSCREEN Then
   g.SetBorderless(True)
  Else
   g.SetFullscreen(mode=MAX2D_FULLSCREEN,width,height,hertz)
  End If
 End Method

	Rem
	bbdoc: Requests a new window position.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
 Method Position(x:Int,y:Int) Override
  EnsureDevice()
  graphics.Position(x,y)
 End Method

	Rem
	bbdoc: Requests a new window size.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
 Method Resize(width:Int,height:Int) Override
  EnsureDevice()
  Try
   graphics.Resize(width,height)
  Catch error:Object
   If TD3D11Graphics(graphics).DeviceStatus()>=0 Then
    If TMax2DGraphics.selected And TMax2DGraphics.selected.context=Self Then SetGraphics(TMax2DGraphics.selected)
    Throw error
   End If
   EnsureDevice()
  End Try
  If TMax2DGraphics.selected And TMax2DGraphics.selected.context=Self Then SetGraphics(TMax2DGraphics.selected)
 End Method

	Rem
	bbdoc: Closes the graphics resources owned by this object.
	End Rem
 Method Close() Override
  If closed Then Return
  ' Closing must release resources even after a fatal device-removal error.
  batchCount=0;batchFrame=Null;target=Null
  While Not frames.IsEmpty()
   TImageFrame(frames.RemoveFirst()).Dispose()
  Wend
  uploadImage=Null
  m2d11_close(native);native=Null
  If graphics Then graphics.Close()
  graphics=Null;closed=True
  D3D11Max2DDriver().live=Null
 End Method

End Type

Rem
bbdoc: Graphics driver for the Direct3D 11 Max2D backend.
End Rem
Type TD3D11Max2DDriver Extends TMax2DDriver

	Rem
	bbdoc: Live backend context owned by this driver.
	End Rem
	Field live:TD3D11Max2DContext

	Rem
	bbdoc: Selects the active Max2D canvas and applies its current view.
	param: Graphics canvas or native graphics object to select.
	End Rem
 Method SetGraphics(graphics:TGraphics) Override
  ' BRL deselects before Close. Do not try to flush a lost device during teardown.
  If Not graphics And current And Not current.context.closed Then
   Local c:TD3D11Max2DContext=TD3D11Max2DContext(current.context)
   If Not c.native Or TD3D11Graphics(c.graphics).DeviceStatus()<0 Then
    c.batchCount=0;c.batchFrame=Null
   End If
  End If
  Super.SetGraphics(graphics)
 End Method

	Rem
	bbdoc: Returns display modes reported by the underlying graphics driver.
	End Rem
 Method GraphicsModes:TGraphicsMode[]() Override
  Return D3D11GraphicsDriver().GraphicsModes()
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
  If live And Not live.closed Then Throw "Max2D D3D11: only one window is currently supported"
  Local previous:TMax2DGraphics=TMax2DGraphics.selected
  If previous And Not previous.context.closed Then previous.context.Flush()
  Local graphics:TD3D11Graphics=D3D11GraphicsDriver().CreateGraphics(width,height,depth,hertz,flags|GRAPHICS_BACKBUFFER,x,y)
  If Not graphics Then Return Null
  Local context:TD3D11Max2DContext=New TD3D11Max2DContext
  context.graphics=graphics
  Try
   context.Activate()
   context.native=m2d11_open(graphics.GetDirect3DDevice(),graphics.GetDeviceContext())
   context.Require(context.native<>Null)
  Catch error:Object
   context.Close()
   Throw error
  End Try
  live=context
  Return context
 End Method

	Rem
	bbdoc: Returns the renderer's descriptive name.
	End Rem
 Method ToString:String() Override
  Return "Max2D Direct3D11"
 End Method

End Type

 ' Compatibility wrappers for the original backend-specific entry points.

Rem
bbdoc: Switches the current D3D11 canvas between exclusive fullscreen and windowed mode.
param: True to enable the mode; False to restore windowed mode.
param: Exclusive fullscreen width; zero uses the current drawing width.
param: Exclusive fullscreen height; zero uses the current drawing height.
param: Refresh rate in hertz; zero selects the backend default.
End Rem
Function D3D11SetFullscreen(enabled:Int,width:Int=0,height:Int=0,hertz:Int=0)
 If Not TD3D11Max2DContext(TMax2DGraphics.Current().context) Then Throw "Max2D D3D11: current graphics uses another backend"
 SetFullscreen(enabled,width,height,hertz)
End Function

Rem
bbdoc: Switches the current D3D11 canvas between borderless fullscreen and windowed mode.
param: True to enable the mode; False to restore windowed mode.
End Rem
Function D3D11SetBorderless(enabled:Int)
 If Not TD3D11Max2DContext(TMax2DGraphics.Current().context) Then Throw "Max2D D3D11: current graphics uses another backend"
 SetBorderlessFullscreen(enabled)
End Function

Rem
bbdoc: Returns the shared Direct3D 11 Max2D graphics driver.
End Rem
Function D3D11Max2DDriver:TD3D11Max2DDriver()
 Global driver:TD3D11Max2DDriver=New TD3D11Max2DDriver
 Return driver
End Function

Extern "C"
 Function m2d11_error:Byte Ptr()
 Function m2d11_open:Byte Ptr(device:ID3D11Device,context:ID3D11DeviceContext)
 Function m2d11_close(context:Byte Ptr)
	Function m2d11_update_level:Int(context:Byte Ptr,frame:Byte Ptr,level:Int,pixels:Byte Ptr,pitch:Int)
	Function m2d11_supplied_supported:Int(context:Byte Ptr,coverage:Int,bits:Int)
	Function m2d11_compressed_supported:Int(context:Byte Ptr,compression:Int)
	Function m2d11_float_target_supported:Int(context:Byte Ptr,bits:Int)
	Function m2d11_read_float:Int(context:Byte Ptr,frame:Byte Ptr,pixels:Byte Ptr)
	Function m2d11_float_supported:Int(context:Byte Ptr,bits:Int)
	Function m2d11_coverage_supported:Int(context:Byte Ptr)
	Function m2d11_coverage:Int(frame:Byte Ptr)
	Function m2d11_create:Byte Ptr(context:Byte Ptr,width:Int,height:Int,flags:Int,target:Int,coverage:Int,floatBits:Int,levels:Int,compression:Int)
 Function m2d11_mipmaps:Int(context:Byte Ptr)
 Function m2d11_dirty(frame:Byte Ptr)
 Function m2d11_target:Byte Ptr(frame:Byte Ptr)
 Function m2d11_destroy(frame:Byte Ptr)
 Function m2d11_update:Int(context:Byte Ptr,frame:Byte Ptr,pixels:Byte Ptr,pitch:Int,x:Int,y:Int,w:Int,h:Int)
 Function m2d11_submit:Int(context:Byte Ptr,target:Byte Ptr,frame:Byte Ptr,blend:Int,vertices:Float Ptr,count:Int,premult:Int)
 Function m2d11_view:Int(context:Byte Ptr,width:Int,height:Int,ox:Int,oy:Int,vw:Int,vh:Int,sx:Float,sy:Float,x:Int,y:Int,w:Int,h:Int)
 Function m2d11_clear:Int(context:Byte Ptr,target:Byte Ptr,bars:Int,r:Int,g:Int,b:Int,a:Float,br:Int,bg:Int,bb:Int,premult:Int)
 Function m2d11_read:Int(context:Byte Ptr,target:Byte Ptr,x:Int,y:Int,w:Int,h:Int,pixels:Byte Ptr,pitch:Int,premult:Int)

	Function m2d11_texture_size(context:Byte Ptr,width:Int Ptr,height:Int Ptr)
	Function m2d11_render_image:Int(context:Byte Ptr,width:Int,height:Int)
End Extern

SetGraphicsDriver(D3D11Max2DDriver(),0)
?
