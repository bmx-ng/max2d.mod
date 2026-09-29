SuperStrict
Module Max2D.D3D7Max2D
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

' Disabled pending validation on supported D3D7 hardware.
?win32 And disabled
Import Max2D.Core
Import BRL.DXGraphics
Import "glue.cpp"

Type TD3D7ImageFrame Extends TImageFrame
 Field native:Byte Ptr
 Field shadow:TPixmap
 Field uploaded:Int
 Method NativeDestroy() Override
  m2d7_destroy(native)
  native=Null
  shadow=Null
 End Method
End Type

Type TD3D7Max2DContext Extends TMax2DContext
 Field native:Byte Ptr
 Method Require(ok:Int)
  If Not ok Then Throw "Max2D D3D7: "+String.FromUTF8String(m2d7_error())
 End Method
 Method NativeFrame:Byte Ptr(frame:TImageFrame)
  If frame Then Return TD3D7ImageFrame(frame).native
 End Method
 Method Activate() Override
  D3D7GraphicsDriver().SetGraphics(graphics)
 End Method
 Field generation:Int
 Method Ready:Int()
  Local g:TD3D7Graphics=TD3D7Graphics(graphics)
  If Not g.Ready() Then Return False
  If generation<>g.Generation() Then
   For Local f:TD3D7ImageFrame=EachIn frames
    m2d7_destroy(f.native)
    f.native=Null; f.uploaded=False
   Next
   generation=g.Generation()
  End If
  Return True
 End Method
	Method Upload:Int(frame:TD3D7ImageFrame)
		If Not Ready() Then Return False
		If Not frame.native Then
			frame.native=m2d7_create(native,frame.width,frame.height,frame.flags)
			Require(frame.native<>Null)
		End If
		If Not frame.uploaded And frame.shadow Then
			Local p:TPixmap=frame.shadow
			If p.format<>PF_RGBA8888 Then p=p.Convert(PF_RGBA8888)
			Require(m2d7_update(frame.native,p.pixels,p.pitch,0,0,p.width,p.height))
			frame.uploaded=True
		End If
		Return True
	End Method
 Method Present:Int(sync:Int) Override
  Activate()
  If IsIconic(TD3D7Graphics(graphics)._hwnd) Then
   Delay(10)
   Return False
  End If
  If sync<0 Then sync=1
  Local result:Int=D3D7GraphicsDriver().Flip(sync)
  If Not result And Not Ready() Then Delay(10)
  Return result
 End Method
 Method NativeCreate:TImageFrame(width:Int,height:Int,flags:Int,target:Int) Override
  Activate()
  If target Then Throw "Max2D D3D7: render images are not supported yet"
  Local frame:TD3D7ImageFrame=New TD3D7ImageFrame
  Return frame
 End Method
	Method NativeUpdateSource(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int) Override
		NativeUpdate(frame,pixmap,x,y,w,h)
	End Method
	Method NativeUpdate(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int) Override
		Activate()
		Local f:TD3D7ImageFrame=TD3D7ImageFrame(frame)
		' Keep source pixels for restoring lost DirectDraw surfaces.
		f.shadow=pixmap.Copy()
		If Not Ready() Then
			f.uploaded=False
			Return
		End If
		If Not f.native Or Not f.uploaded Then
			Upload(f)
		Else
			Local region:TPixmap=UploadRegion(pixmap,x,y,w,h)
			Require(m2d7_update(f.native,region.pixels,region.pitch,x,y,w,h))
		End If
	End Method
 Method NativeSubmit(frame:TImageFrame,blend:Int,vertices:Float Ptr,count:Int) Override
  Activate()
  If Not Ready() Then Return
  If frame And Not Upload(TD3D7ImageFrame(frame)) Then Return
  Require(m2d7_submit(native,NativeFrame(frame),blend,vertices,count))
 End Method
 Method NativeOutputSize(width:Int Var,height:Int Var) Override
  Local depth:Int,hertz:Int,flags:Long,x:Int,y:Int
  graphics.GetSettings(width,height,depth,hertz,flags,x,y)
 End Method
 Method NativeView(frame:TImageFrame,view:TMax2DView) Override
  Activate()
  Require(m2d7_view(native,pixelWidth,pixelHeight,pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight,..
   pixelScaleX,pixelScaleY,view.x,view.y,view.w,view.h))
 End Method
 Method NativeClear(red:Int,green:Int,blue:Int,alpha:Float) Override
  Activate()
  If Not Ready() Then Return
  Local result:Int=m2d7_clear(native,view.presentation=VIRTUAL_LETTERBOX Or view.presentation=VIRTUAL_INTEGER,..
   red,green,blue,alpha,view.barRed,view.barGreen,view.barBlue)
  If Ready() Then Require(result)
 End Method
 Method NativeRead:TPixmap(frame:TImageFrame,x:Int,y:Int,w:Int,h:Int) Override
  Activate()
  If Not Ready() Then Throw "Max2D D3D7: readback unavailable while device is lost or window is minimized"
  If frame Then Throw "Max2D D3D7: render images are not supported yet"
  Local pixmap:TPixmap=CreatePixmap(w,h,PF_RGBA8888)
  Require(m2d7_read(native,x,y,w,h,pixmap.pixels,pixmap.pitch))
  If Not Ready() Then Throw "Max2D D3D7: device became unavailable during readback"
  Return pixmap
 End Method
 Method SupportsBlend:Int(blend:Int) Override
  Return m2d7_blend(native,blend)
 End Method
 Method SupportsImageFlags:Int(flags:Int) Override
  If (flags & ~(MASKEDIMAGE|FILTEREDIMAGE|DYNAMICIMAGE))<>0 Then Return False
  Return Not (flags & FILTEREDIMAGE) Or m2d7_filtered(native)
 End Method
 Method Resize(width:Int,height:Int) Override
  Throw "Max2D D3D7: BRL.DXGraphics does not support programmatic window resizing"
 End Method
 Method Position(x:Int,y:Int) Override
  Throw "Max2D D3D7: BRL.DXGraphics does not support programmatic window positioning"
 End Method
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
  m2d7_close(native); native=Null
  graphics.Close(); graphics=Null; closed=True
  D3D7Max2DDriver().live=Null
  If previous And previous.context<>Self And Not previous.context.closed Then previous.context.Activate()
 End Method
End Type

Type TD3D7Max2DDriver Extends TMax2DDriver
 Field live:TD3D7Max2DContext
 Method GraphicsModes:TGraphicsMode[]() Override
  If D3D7GraphicsDriver() Then Return D3D7GraphicsDriver().GraphicsModes()
  Return New TGraphicsMode[0]
 End Method
 Method CanResize:Int() Override
  Return False
 End Method
 Method CreateContext:TMax2DContext(width:Int,height:Int,depth:Int,hertz:Int,flags:Long,x:Int,y:Int) Override
  If live And Not live.closed Then Throw "Max2D D3D7: only one window is currently supported"
  If depth<>0 Then Throw "Max2D D3D7: fullscreen is not implemented yet"
  If Not D3D7GraphicsDriver() Then Throw "Max2D D3D7: no available D3D7 device"
  Local previous:TMax2DGraphics=TMax2DGraphics.selected
  If previous And Not previous.context.closed Then previous.context.Flush()
  Local graphics:TD3D7Graphics=D3D7GraphicsDriver().CreateGraphics(width,height,depth,hertz,flags|GRAPHICS_BACKBUFFER,x,y)
  If Not graphics Then Return Null
  If Not graphics._hwnd Then
   graphics.Close()
   Throw "Max2D D3D7: window/device creation failed"
  End If
  Local context:TD3D7Max2DContext=New TD3D7Max2DContext
  context.graphics=graphics
  Try
   context.Activate()
   context.native=m2d7_open(graphics.DirectDraw7(),graphics.Direct3DDevice7(),graphics.RenderSurface())
   context.Require(context.native<>Null)
   context.generation=graphics.Generation()
  Catch error:Object
   context.Close()
   Throw error
  End Try
  If previous And Not previous.context.closed Then previous.context.Activate()
  live=context
  Return context
 End Method
 Method ToString:String() Override
  Return "Max2D Direct3D7"
 End Method
End Type

Function D3D7Max2DDriver:TD3D7Max2DDriver()
 Global driver:TD3D7Max2DDriver=New TD3D7Max2DDriver
 Return driver
End Function

Extern "C"
 Function m2d7_error:Byte Ptr()
 Function m2d7_open:Byte Ptr(dd:Byte Ptr,device:Byte Ptr,surface:Byte Ptr)
 Function m2d7_close(context:Byte Ptr)
 Function m2d7_blend:Int(context:Byte Ptr,blend:Int)
 Function m2d7_filtered:Int(context:Byte Ptr)
 Function m2d7_create:Byte Ptr(context:Byte Ptr,width:Int,height:Int,flags:Int)
 Function m2d7_destroy(frame:Byte Ptr)
 Function m2d7_update:Int(frame:Byte Ptr,pixels:Byte Ptr,pitch:Int,x:Int,y:Int,w:Int,h:Int)
 Function m2d7_submit:Int(context:Byte Ptr,frame:Byte Ptr,blend:Int,vertices:Float Ptr,count:Int)
 Function m2d7_view:Int(context:Byte Ptr,width:Int,height:Int,ox:Int,oy:Int,vw:Int,vh:Int,sx:Float,sy:Float,x:Int,y:Int,w:Int,h:Int)
 Function m2d7_clear:Int(context:Byte Ptr,bars:Int,r:Int,g:Int,b:Int,a:Float,br:Int,bg:Int,bb:Int)
 Function m2d7_read:Int(context:Byte Ptr,x:Int,y:Int,w:Int,h:Int,pixels:Byte Ptr,pitch:Int)
End Extern

SetGraphicsDriver(D3D7Max2DDriver(),0)
?
