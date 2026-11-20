Private
Type TSDLGPUShaderPackageBackend Extends TMax2DShaderPackageBackend
	Method Handles:Int(context:TMax2DContext) Override
		Return TSDLGPUMax2DContext(context)<>Null
	End Method
	Method Shader:Byte Ptr(context:TMax2DContext, package:Byte Ptr) Override
		Local native:TSDLGPUMax2DContext=TSDLGPUMax2DContext(context)
		Return m2d_package_shader(native.native,native.GetGPUDevice(),package)
	End Method
	Method SelectShader(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame) Override
		Local native:TSDLGPUMax2DContext=TSDLGPUMax2DContext(context)
		If second Then
			native.Require(m2d_gpu_select_texture_effect(native.native,shader,values,native.NativeFrame(second)))
		Else
			m2d_gpu_select_package_effect(native.native,shader,values)
		End If
	End Method
	Method ClearShader(context:TMax2DContext) Override
		m2d_gpu_select_image_effect(TSDLGPUMax2DContext(context).native,Null,0,0,0,0)
	End Method
End Type
Extern "C"
	Function m2d_package_shader:Byte Ptr(context:Byte Ptr,device:Byte Ptr,package:Byte Ptr)
	Function m2d_gpu_select_texture_effect:Int(context:Byte Ptr,effect:Byte Ptr,values:Float Ptr,texture:Byte Ptr)
	Function m2d_gpu_select_package_effect(context:Byte Ptr,effect:Byte Ptr,values:Float Ptr)
End Extern
RegisterShaderPackageBackend(New TSDLGPUShaderPackageBackend)
Public
