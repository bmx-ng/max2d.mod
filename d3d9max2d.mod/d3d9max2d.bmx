SuperStrict

Rem
bbdoc: Draw with the Direct3D 9 Max2D backend on Windows.
End Rem
Module Max2D.D3D9Max2D
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

?win32
Import Max2D.Core
Import BRL.DXGraphics
Import "glue.cpp"
Import "draw_shader.cpp"

Rem
bbdoc: Native Direct3D 9 texture storage owned by a Max2D context.
End Rem
Type TD3D9ImageFrame Extends TImageFrame

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: CPU pixels waiting to be uploaded to the Direct3D texture.
	End Rem
	Field pending:TPixmap

	Rem
	bbdoc: Native retained texture snapshot used for device-loss recovery.
	End Rem
	Field snapshot:Byte Ptr

	Rem
	bbdoc: Releases this frame's native graphics resources on the rendering thread.
	End Rem
 Method NativeDestroy() Override
  owner.Activate()
  m2d9_destroy(native)
  native=Null
  pending=Null
  m2d9_release_snapshot(snapshot);snapshot=Null
 End Method

End Type

Rem
bbdoc: Max2D rendering context implemented with Direct3D 9.
End Rem
Type TD3D9Max2DContext Extends TMax2DContext

	Rem
	bbdoc: Opaque backend resource handle; managed by the owning graphics context.
	End Rem
	Field native:Byte Ptr

	Rem
	bbdoc: Throws the backend's error when a native operation fails.
	param: Nonzero for native-operation success; zero triggers an exception.
	End Rem
 Method Require(ok:Int)
  If Not ok Then Throw "Max2D D3D9: "+String.FromUTF8String(m2d9_error())
 End Method

	Rem
	bbdoc: Returns the backend handle for an image frame, or Null for no texture.
	param: Texture frame to sample, or Null for untextured geometry.
	End Rem
 Method NativeFrame:Byte Ptr(frame:TImageFrame)
  If frame Then Return TD3D9ImageFrame(frame).native
 End Method

	Rem
	bbdoc: Makes this graphics context current for native rendering operations.
	End Rem
 Method Activate() Override
  D3D9GraphicsDriver().SetGraphics(graphics)
 End Method

	Rem
	bbdoc: Reports whether the native graphics device is ready for drawing.
	End Rem
 Method Ready:Int()
  Local g:TD3D9Graphics=TD3D9Graphics(graphics)
  Local status:Int=g.DeviceStatus()
  If status=D3DERR_DEVICELOST Or status=D3DERR_DEVICENOTRESET Then Return False
  If status<0 Then Throw "Max2D D3D9: device failure " + status
  Return Not IsIconic(g._hwnd)
 End Method

	Rem
	bbdoc: Uploads retained pixels into a Direct3D image frame.
	param: Native image frame owned by this context.
	End Rem
	Method Upload:Int(frame:TD3D9ImageFrame)
		If Not Ready() Then Return False
		If Not frame.native Then
			frame.native=m2d9_create(native,frame.width,frame.height,frame.flags,frame.target)
			If Not frame.native And Not Ready() Then Return False
			Require(frame.native<>Null)
		End If
		If frame.snapshot Then
			Require(m2d9_restore(native,frame.native,frame.snapshot))
			m2d9_release_snapshot(frame.snapshot)
			frame.snapshot=Null
		End If
		If frame.pending Then
			Local p:TPixmap=frame.pending
			If p.format<>PF_RGBA8888 Then p=p.Convert(PF_RGBA8888)
			Local ok:Int=m2d9_update(frame.native,p.pixels,p.pitch,0,0,p.width,p.height)
			If Not Ready() Then Return False
			Require(ok)
			frame.pending=Null
		End If
		Return True
	End Method

	Rem
	bbdoc: Presents the window backbuffer with the requested synchronization setting.
	param: Presentation synchronization setting; negative uses the backend default.
	End Rem
 Method Present:Int(sync:Int) Override
  Activate()
  If IsIconic(TD3D9Graphics(graphics)._hwnd) Then
   Delay(10)
   Return False
  End If
  If sync<0 Then sync=1
  Local result:Int=D3D9GraphicsDriver().Flip(sync)
  If Not result And Not Ready() Then Delay(10)
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
  Activate()
  Local frame:TD3D9ImageFrame=New TD3D9ImageFrame
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
		Activate()
		Local f:TD3D9ImageFrame=TD3D9ImageFrame(frame)
		' Retain edits made while unavailable, including creation of new images.
		If Not Ready() Or f.pending Or Not f.native Then
			f.pending=pixmap.Copy()
			Upload(f)
			Return
		End If
		Local region:TPixmap=UploadRegion(pixmap,x,y,w,h)
		Local ok:Int=m2d9_update(f.native,region.pixels,region.pitch,x,y,w,h)
		If Not Ready() Then
			f.pending=pixmap.Copy()
			Return
		End If
		Require(ok)
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
  If Not Ready() Then Return
  If target And Not Upload(TD3D9ImageFrame(target)) Then Return
  If frame And Not Upload(TD3D9ImageFrame(frame)) Then Return
  Local result:Int=m2d9_submit(native,NativeFrame(target),NativeFrame(frame),blend,vertices,count)
  If Ready() Then
   Require(result)
   stats.mipmapGenerations:+result-1
  End If
 End Method

	Rem
	bbdoc: Gets the window coordinate extent used by mouse input.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
 Method NativeInputSize(width:Int Var,height:Int Var) Override
  TD3D9Graphics(graphics).ClientSize(width,height)
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
  Activate()
  Require(m2d9_view(native,pixelWidth,pixelHeight,pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight,..
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
  If Not Ready() Then Return
  If target And Not Upload(TD3D9ImageFrame(target)) Then Return
  Local result:Int=m2d9_clear(native,NativeFrame(target),view.presentation=VIRTUAL_LETTERBOX Or view.presentation=VIRTUAL_INTEGER,..
   red,green,blue,alpha,view.barRed,view.barGreen,view.barBlue)
  If Ready() Then Require(result)
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
  If Not Ready() Then Throw "Max2D D3D9: readback unavailable while device is lost or window is minimized"
  If frame And Not Upload(TD3D9ImageFrame(frame)) Then Throw "Max2D D3D9: render image unavailable"
  Local pixmap:TPixmap=CreatePixmap(w,h,PF_RGBA8888)
  Require(m2d9_read(native,NativeFrame(frame),x,y,w,h,pixmap.pixels,pixmap.pitch))
  If Not Ready() Then Throw "Max2D D3D9: device became unavailable during readback"
  Return pixmap
 End Method

	Rem
	bbdoc: Invalidates context resources when the underlying Direct3D device is lost.
	param: Context supplied by the graphics device-loss callback.
	End Rem
 Function DeviceLost(obj:Object)
  Local context:TD3D9Max2DContext=TD3D9Max2DContext(obj)
  m2d9_unbind(context.native)
  For Local frame:TD3D9ImageFrame=EachIn context.frames
   If frame.target Then
    m2d9_destroy(frame.native)
    frame.native=Null
   Else
    m2d9_dirty(frame.native)
   End If
  Next
 End Function

	Rem
	bbdoc: Reports whether a blend mode is supported by this context.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	End Rem
 Method SupportsBlend:Int(blend:Int) Override
  Return blend>=MASKBLEND And blend<=SHADEBLEND
 End Method

	Rem
	bbdoc: Gets maximum supported texture dimensions, with zero for an unreported limit.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method TextureSize(width:Int Var,height:Int Var) Override
		m2d9_texture_size(native,Varptr width,Varptr height)
	End Method

	Rem
	bbdoc: Checks render-target support for dimensions and image flags.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method SupportsRenderImage:Int(width:Int,height:Int,flags:Int) Override
		If Not SupportsImageFlags(flags) Or Not ValidTextureSize(width,height) Then Return False
		Return m2d9_render_image(native,width,height)
	End Method

	Rem
	bbdoc: Reports whether an image flag combination is supported by this context.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
 Method SupportsImageFlags:Int(flags:Int) Override
  If (flags & ~(MASKEDIMAGE|FILTEREDIMAGE|MIPMAPPEDIMAGE|DYNAMICIMAGE))<>0 Then Return False
  Return Not (flags & MIPMAPPEDIMAGE) Or m2d9_mipmaps(native)
 End Method

	Rem
	bbdoc: Reports whether runtime exclusive fullscreen switching is implemented.
	End Rem
 Method SupportsFullscreen:Int() Override
  Return TD3D9Graphics(graphics).SupportsFullscreen()
 End Method

	Rem
	bbdoc: Reports whether runtime borderless fullscreen switching is implemented.
	End Rem
 Method SupportsBorderlessFullscreen:Int() Override
  Return TD3D9Graphics(graphics).SupportsFullscreen()
 End Method

	Rem
	bbdoc: Returns the established windowed, exclusive or borderless fullscreen mode.
	End Rem
 Method WindowMode:Int() Override
  If TD3D9Graphics(graphics)._borderless Then Return MAX2D_BORDERLESS_FULLSCREEN
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
  ChangeWindow(mode,width,height,hertz)
 End Method

 ' mode=-1 resizes; other values are shared Max2D window modes.

	Rem
	bbdoc: Changes the Direct3D window mode and refreshes context state.
	param: MAX2D_WINDOWED, MAX2D_FULLSCREEN or MAX2D_BORDERLESS_FULLSCREEN.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Refresh rate in hertz; zero selects the backend default.
	End Rem
 Method ChangeWindow(mode:Int,width:Int,height:Int,hertz:Int=0)
  Activate()
  Local g:TD3D9Graphics=TD3D9Graphics(graphics)
  If mode=-1 Then
   If width<=0 Or height<=0 Then Throw "Max2D D3D9: window dimensions must be positive"
   If g._borderless Or g._depth Then Throw "Max2D D3D9: leave fullscreen before resizing"
   If width=g._width And height=g._height Then Return
  Else If mode=MAX2D_FULLSCREEN Then
   Local selectedMode:TGraphicsMode=g.SelectFullscreenMode(width,height,hertz)
   If g._depth And selectedMode.width=g._width And selectedMode.height=g._height And selectedMode.hertz=g._hertz Then Return
  Else
   If Not g._depth And (mode=MAX2D_BORDERLESS_FULLSCREEN)=g._borderless Then Return
  End If
  If Not g.SupportsFullscreen() Or Not Ready() Then Throw "Max2D D3D9: window/device unavailable for window change"
  Try
   For Local frame:TD3D9ImageFrame=EachIn frames
    If frame.target And frame.native And Not frame.snapshot Then
     frame.snapshot=m2d9_snapshot(native,frame.native)
     Require(frame.snapshot<>Null)
    End If
   Next
   If mode=-1 Then
    g.Resize(width,height)
   Else If mode=MAX2D_FULLSCREEN Then
    g.SetFullscreen(True,width,height,hertz)
   Else
    If g._depth Then g.SetFullscreen(False)
    g.SetBorderless(mode=MAX2D_BORDERLESS_FULLSCREEN)
   End If
  Catch error:Object
   ' If reset never released a target, its live contents remain authoritative.
   For Local frame:TD3D9ImageFrame=EachIn frames
    If frame.native And frame.snapshot Then
     m2d9_release_snapshot(frame.snapshot)
			frame.snapshot=Null
    End If
   Next
   Throw error
  End Try
 End Method

	Rem
	bbdoc: Requests a new window size.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
 Method Resize(width:Int,height:Int) Override
  Try
   ChangeWindow(-1,width,height)
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
  TD3D9Graphics(graphics).RemoveDeviceLostCallback(DeviceLost)
  If native And Ready() Then m2d9_unbind(native)
  While Not frames.IsEmpty()
   TImageFrame(frames.RemoveFirst()).Dispose()
  Wend
  uploadImage=Null
  m2d9_close(native); native=Null
  graphics.Close(); graphics=Null; closed=True
  D3D9Max2DDriver().live=Null
  If previous And previous.context<>Self And Not previous.context.closed Then previous.context.Activate()
 End Method

End Type

Rem
bbdoc: Graphics driver for the Direct3D 9 Max2D backend.
End Rem
Type TD3D9Max2DDriver Extends TMax2DDriver

	Rem
	bbdoc: Live backend context owned by this driver.
	End Rem
	Field live:TD3D9Max2DContext

	Rem
	bbdoc: Returns display modes reported by the underlying graphics driver.
	End Rem
 Method GraphicsModes:TGraphicsMode[]() Override
  If D3D9GraphicsDriver() Then Return D3D9GraphicsDriver().GraphicsModes()
  Return New TGraphicsMode[0]
 End Method

	Rem
	bbdoc: Reports whether the driver supports resizing its graphics windows.
	End Rem
 Method CanResize:Int() Override
  Return True
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
  If live And Not live.closed Then Throw "Max2D D3D9: only one window is currently supported"
  If depth<>0 Then Throw "Max2D D3D9: fullscreen is not implemented yet"
  If Not D3D9GraphicsDriver() Then Throw "Max2D D3D9: no available D3D9 device"
  Local previous:TMax2DGraphics=TMax2DGraphics.selected
  If previous And Not previous.context.closed Then previous.context.Flush()
  Local graphics:TD3D9Graphics=D3D9GraphicsDriver().CreateLogicalGraphics(width,height,depth,hertz,flags|GRAPHICS_BACKBUFFER,x,y)
  If Not graphics Then Return Null
  If Not graphics._hwnd Then
   graphics.Close()
   Throw "Max2D D3D9: window/device creation failed"
  End If
  Local context:TD3D9Max2DContext=New TD3D9Max2DContext
  context.graphics=graphics
  Try
   context.Activate()
   context.native=m2d9_open(graphics.GetDirect3DDevice())
   context.Require(context.native<>Null)
   graphics.AddDeviceLostCallback(TD3D9Max2DContext.DeviceLost,context)
  Catch error:Object
   context.Close()
   Throw error
  End Try
  If previous And Not previous.context.closed Then previous.context.Activate()
  live=context
  Return context
 End Method

	Rem
	bbdoc: Returns the renderer's descriptive name.
	End Rem
 Method ToString:String() Override
  Return "Max2D Direct3D9"
 End Method

End Type

Rem
bbdoc: Returns the shared Direct3D 9 Max2D graphics driver.
End Rem
Function D3D9Max2DDriver:TD3D9Max2DDriver()
 Global driver:TD3D9Max2DDriver=New TD3D9Max2DDriver
 Return driver
End Function

Extern "C"
 Function m2d9_snapshot:Byte Ptr(context:Byte Ptr,frame:Byte Ptr)
 Function m2d9_release_snapshot(snapshot:Byte Ptr)
 Function m2d9_restore:Int(context:Byte Ptr,frame:Byte Ptr,snapshot:Byte Ptr)
 Function m2d9_mipmaps:Int(context:Byte Ptr)
 Function m2d9_dirty(frame:Byte Ptr)
 Function m2d9_error:Byte Ptr()
 Function m2d9_open:Byte Ptr(device:IDirect3DDevice9)
 Function m2d9_close(context:Byte Ptr)
 Function m2d9_unbind(context:Byte Ptr)
 Function m2d9_create:Byte Ptr(context:Byte Ptr,width:Int,height:Int,flags:Int,target:Int)
 Function m2d9_destroy(frame:Byte Ptr)
 Function m2d9_update:Int(frame:Byte Ptr,pixels:Byte Ptr,pitch:Int,x:Int,y:Int,w:Int,h:Int)
 Function m2d9_submit:Int(context:Byte Ptr,target:Byte Ptr,frame:Byte Ptr,blend:Int,vertices:Float Ptr,count:Int)
 Function m2d9_view:Int(context:Byte Ptr,width:Int,height:Int,ox:Int,oy:Int,vw:Int,vh:Int,sx:Float,sy:Float,x:Int,y:Int,w:Int,h:Int)
 Function m2d9_clear:Int(context:Byte Ptr,target:Byte Ptr,bars:Int,r:Int,g:Int,b:Int,a:Float,br:Int,bg:Int,bb:Int)
 Function m2d9_read:Int(context:Byte Ptr,target:Byte Ptr,x:Int,y:Int,w:Int,h:Int,pixels:Byte Ptr,pitch:Int)

	Function m2d9_texture_size(context:Byte Ptr,width:Int Ptr,height:Int Ptr)
	Function m2d9_render_image:Int(context:Byte Ptr,width:Int,height:Int)
End Extern

SetGraphicsDriver(D3D9Max2DDriver(),0)
?
