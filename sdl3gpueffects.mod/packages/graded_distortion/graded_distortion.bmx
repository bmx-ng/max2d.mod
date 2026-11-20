' Generated package wrapper. Run embed after compiling shader assets.
' Import graded_distortion_assets.c alongside your application imports.
Function CreateGradedDistortionPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("graded_distortion", ["time", "strength", "frequency", "ripple", "grade", "gradeTint"], [MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4], CreateGradedDistortionPackageData(CreateGradedDistortionPackageAsset(0), CreateGradedDistortionPackageSize(0)), CreateGradedDistortionPackageData(CreateGradedDistortionPackageAsset(1), CreateGradedDistortionPackageSize(1)), CreateGradedDistortionPackageData(CreateGradedDistortionPackageAsset(2), CreateGradedDistortionPackageSize(2)), 2, CreateGradedDistortionPackageData(CreateGradedDistortionPackageAsset(3), CreateGradedDistortionPackageSize(3)), CreateGradedDistortionPackageData(CreateGradedDistortionPackageAsset(4), CreateGradedDistortionPackageSize(4)), CreateGradedDistortionPackageData(CreateGradedDistortionPackageAsset(5), CreateGradedDistortionPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateGradedDistortionPackageAsset:Byte Ptr(index:Int)
	Function CreateGradedDistortionPackageSize:Int(index:Int)
End Extern
Function CreateGradedDistortionPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
