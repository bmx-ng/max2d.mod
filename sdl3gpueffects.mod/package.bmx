Private
Type TSDLGPUShaderPackageBackend Extends TMax2DShaderPackageBackend
 Field frames:Byte Ptr[4]
 Method MaximumTextures:Int(context:TMax2DContext) Override
  If Handles(context) Then Return 5
  Return 0
 End Method
 Method BindTextureSet(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,textures:TImageFrame[],count:Int) Override
  Local native:TSDLGPUMax2DContext=TSDLGPUMax2DContext(context)
  For Local i:Int=0 Until count
   frames[i]=native.NativeFrame(textures[i])
  Next
  Try
   native.Require(m2d_gpu_select_texture_set(native.native,shader,values,frames,count))
  Finally
   For Local i:Int=0 Until count
    frames[i]=Null
   Next
  End Try
 End Method
 Method SupportsShader:Int(canvas:TMax2DGraphics,shader:Byte Ptr) Override
  Local context:TSDLGPUMax2DContext=TSDLGPUMax2DContext(canvas.context)
  If Not shader Then Return False
  Return m2d_gpu_image_effect_support(context.native,shader,context.NativeFrame(context.target),canvas.state.blend,context.compactQuads)
 End Method
	Method Handles:Int(context:TMax2DContext) Override
		Return TSDLGPUMax2DContext(context)<>Null
	End Method
	Method Shader:Byte Ptr(context:TMax2DContext, package:Byte Ptr) Override
		Local native:TSDLGPUMax2DContext=TSDLGPUMax2DContext(context)
		Return m2d_package_shader(native.native,native.GetGPUDevice(),package)
	End Method
	Method SelectShader(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame) Override
  SelectTextures(context,shader,values,second,Null)
 End Method
 Method SelectTextures(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame,third:TImageFrame) Override
		Local native:TSDLGPUMax2DContext=TSDLGPUMax2DContext(context)
		If second Then
			native.Require(m2d_gpu_select_texture_effect(native.native,shader,values,native.NativeFrame(second),native.NativeFrame(third)))
		Else
			m2d_gpu_select_package_effect(native.native,shader,values)
		End If
	End Method
	Method ClearShader(context:TMax2DContext) Override
		m2d_gpu_select_image_effect(TSDLGPUMax2DContext(context).native,Null,0,0,0,0)
	End Method
End Type
Extern "C"
 Function m2d_gpu_select_texture_set:Int(context:Byte Ptr,effect:Byte Ptr,values:Float Ptr,textures:Byte Ptr Ptr,count:Int)
	Function m2d_package_shader:Byte Ptr(context:Byte Ptr,device:Byte Ptr,package:Byte Ptr)
	Function m2d_gpu_select_texture_effect:Int(context:Byte Ptr,effect:Byte Ptr,values:Float Ptr,texture:Byte Ptr,third:Byte Ptr)
	Function m2d_gpu_select_package_effect(context:Byte Ptr,effect:Byte Ptr,values:Float Ptr)
End Extern
RegisterShaderPackageBackend(New TSDLGPUShaderPackageBackend)
Public
