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

Type TSDLGPUImageFrame Extends TImageFrame
	Field native:Byte Ptr
	Method NativeDestroy() Override
		If native Then m2d_gpu_destroy(native)
		native=Null
	End Method
End Type

Type TSDLGPUMax2DContext Extends TMax2DContext
	Field native:Byte Ptr
	Method Require(ok:Int)
		If Not ok Then Throw "Max2D SDL GPU: "+SDL_GetError()
	End Method
	Method NativeFrame:Byte Ptr(frame:TImageFrame)
		If frame Then Return TSDLGPUImageFrame(frame).native
	End Method
	Method Activate() Override
		SDLGraphicsDriver().SetGraphics(graphics)
	End Method
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
	Method Present:Int(sync:Int) Override
		Require(m2d_gpu_present(native,sync))
		Return True
	End Method
	Method NativeOutputSize(width:Int Var,height:Int Var) Override
		Require(m2d_gpu_output(native,Varptr width,Varptr height))
	End Method
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
	Method NativeCreate:TImageFrame(width:Int,height:Int,flags:Int,target:Int) Override
		Return NativeCreateFormat(width,height,flags,target,PF_RGBA8888)
	End Method
	Method NativeCreateFormat:TImageFrame(width:Int,height:Int,flags:Int,target:Int,pixelFormat:Int) Override
		Local frame:TSDLGPUImageFrame=New TSDLGPUImageFrame
		frame.native=m2d_gpu_create(native,width,height,flags,target,TextureKind(pixelFormat),0)
		Require(frame.native<>Null)
		frame.pixelFormat=pixelFormat
		Return frame
	End Method
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
	Method NativeCreateTexture:TImageFrame(data:TTextureData,flags:Int) Override
		If data.LevelCount()=1 Then Return Super.NativeCreateTexture(data,flags)
		Local frame:TSDLGPUImageFrame=New TSDLGPUImageFrame
		frame.native=m2d_gpu_create(native,data.Width(),data.Height(),flags,False,TextureKind(data.Format()),data.LevelCount())
		Require(frame.native<>Null)
		frame.pixelFormat=data.Format()
		Return frame
	End Method
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
	Method NativeUpdateSource(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int) Override
		NativeUpdate(frame,pixmap,x,y,w,h)
	End Method
	Method NativeUpdate(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int) Override
		Local region:TPixmap=UploadRegion(pixmap,x,y,w,h,frame.pixelFormat)
		Require(m2d_gpu_update(NativeFrame(frame),region.pixels,region.pitch,x,y,w,h))
	End Method
	Method NativeSubmit(frame:TImageFrame,blend:Int,vertices:Float Ptr,count:Int) Override
		Local result:Int=m2d_gpu_draw(native,NativeFrame(target),NativeFrame(frame),blend,vertices,count)
		Require(result)
		stats.mipmapGenerations:+result-1
	End Method
	Method NativeView(frame:TImageFrame,view:TMax2DView) Override
		Require(m2d_gpu_view(native,NativeFrame(frame),pixelWidth,pixelHeight,pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight,..
			pixelScaleX,pixelScaleY,view.x,view.y,view.w,view.h))
	End Method
	Method NativeClear(red:Int,green:Int,blue:Int,alpha:Float) Override
		Require(m2d_gpu_clear(native,NativeFrame(target),view.presentation=VIRTUAL_LETTERBOX Or view.presentation=VIRTUAL_INTEGER,..
			red,green,blue,alpha,view.barRed,view.barGreen,view.barBlue))
	End Method
	Method NativeRead:TPixmap(frame:TImageFrame,x:Int,y:Int,w:Int,h:Int) Override
		Local pixels:TPixmap=CreatePixmap(w,h,PF_RGBA8888)
		Require(m2d_gpu_read(native,NativeFrame(frame),x,y,w,h,pixels.pixels,pixels.pitch))
		Return pixels
	End Method
	Method SupportsBlend:Int(blend:Int) Override
		Return blend>=MASKBLEND And blend<=SHADEBLEND
	End Method
	Method SupportsImageFlags:Int(flags:Int) Override
		If flags & ~(MASKEDIMAGE|FILTEREDIMAGE|DYNAMICIMAGE|MIPMAPPEDIMAGE) Then Return False
		Return Not (flags & MIPMAPPEDIMAGE) Or m2d_gpu_support(native,False,True)
	End Method
	Method TextureFormatSupport:ETextureFormatSupport(pixelFormat:Int,flags:Int) Override
		If Not SupportsImageFlags(flags) Then Return ETextureFormatSupport.Unsupported
		If (pixelFormat=PF_RGBA16F Or pixelFormat=PF_RGBA32F Or pixelFormat=PF_BC1_RGBA Or pixelFormat=PF_BC3_RGBA) And (flags & (MIPMAPPEDIMAGE|DYNAMICIMAGE)) Then Return ETextureFormatSupport.Unsupported
		Local kind:Int=TextureKind(pixelFormat)
		If kind>=0 Then
			If m2d_gpu_support(native,kind,(flags & MIPMAPPEDIMAGE)<>0) Then Return ETextureFormatSupport.Native
		End If
		Return ETextureFormatSupport.Unsupported
	End Method
	Method SupportsRenderImageFormat:Int(width:Int,height:Int,flags:Int,pixelFormat:Int) Override
		If pixelFormat=PF_RGBA8888 Then Return SupportsRenderImage(width,height,flags)
		If pixelFormat<>PF_RGBA16F And pixelFormat<>PF_RGBA32F Then Return False
		If (flags & MIPMAPPEDIMAGE) Or Not SupportsImageFlags(flags) Or Not ValidTextureSize(width,height) Then Return False
		Return m2d_gpu_target_support(native,TextureKind(pixelFormat))
	End Method
	Method NativeReadTexture:TTextureData(frame:TImageFrame) Override
		If frame.pixelFormat=PF_RGBA8888 Then Return Super.NativeReadTexture(frame)
		Local size:Long=GetPixelFormatInfo(PF_RGBA32F).StorageSize(frame.width,frame.height)
		If size>$7fffffff Then Throw "Max2D: floating-point readback exceeds byte-array size limit"
		Local bytes:Byte[]=New Byte[Int(size)]
		Require(m2d_gpu_read_float(native,NativeFrame(frame),bytes))
		Return TTextureData.Create([TTextureLevel.Create(frame.width,frame.height,PF_RGBA32F,bytes)])
	End Method
	Method SupportsRenderImage:Int(width:Int,height:Int,flags:Int) Override
		Return SupportsImageFlags(flags) And ValidTextureSize(width,height) And m2d_gpu_support(native,False,True)
	End Method
End Type

Type TSDLGPUMax2DDriver Extends TMax2DDriver
	Method GraphicsModes:TGraphicsMode[]() Override
		Return SDLGraphicsDriver().GraphicsModes()
	End Method
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
		Return context
	End Method
	Method ToString:String() Override
		Return "Max2D SDL3 GPU"
	End Method
	Method GetHandle:Byte Ptr(handleType:EGraphicsHandleType=EGraphicsHandleType.Window) Override
		If Not current Then Return Null
		Local window:TSDLWindow=TSDLGraphics(current.context.graphics)._context.window
		If handleType=EGraphicsHandleType.Display Then Return window.GetDisplayHandle()
		Return window.GetHandle()
	End Method
End Type

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
	Function m2d_gpu_draw:Int(context:Byte Ptr,target:Byte Ptr,source:Byte Ptr,blend:Int,vertices:Float Ptr,count:Int)
	Function m2d_gpu_view:Int(context:Byte Ptr,target:Byte Ptr,width:Int,height:Int,ox:Int,oy:Int,vw:Int,vh:Int,sx:Float,sy:Float,x:Int,y:Int,w:Int,h:Int)
	Function m2d_gpu_clear:Int(context:Byte Ptr,target:Byte Ptr,bars:Int,red:Int,green:Int,blue:Int,alpha:Float,barRed:Int,barGreen:Int,barBlue:Int)
	Function m2d_gpu_read:Int(context:Byte Ptr,target:Byte Ptr,x:Int,y:Int,w:Int,h:Int,pixels:Byte Ptr,pitch:Int)
End Extern

SetGraphicsDriver(SDLGPUMax2DDriver(),0)
