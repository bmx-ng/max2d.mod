' Generated package wrapper. Run embed after compiling shader assets.
' Import pointlight_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable pointlight shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreatePointLightPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("pointlight", ["light", "colour", "shape", "basisX", "basisY"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4], CreatePointLightPackageData(CreatePointLightPackageAsset(0), CreatePointLightPackageSize(0)), CreatePointLightPackageData(CreatePointLightPackageAsset(1), CreatePointLightPackageSize(1)), CreatePointLightPackageData(CreatePointLightPackageAsset(2), CreatePointLightPackageSize(2)), 2, CreatePointLightPackageData(CreatePointLightPackageAsset(3), CreatePointLightPackageSize(3)), CreatePointLightPackageData(CreatePointLightPackageAsset(4), CreatePointLightPackageSize(4)), CreatePointLightPackageData(CreatePointLightPackageAsset(5), CreatePointLightPackageSize(5)))
End Function
Private
Extern "C"
	Function CreatePointLightPackageAsset:Byte Ptr(index:Int)
	Function CreatePointLightPackageSize:Int(index:Int)
End Extern
Function CreatePointLightPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
