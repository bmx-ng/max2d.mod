' Generated package wrapper. Run embed after compiling shader assets.
' Import normallight_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable normallight shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreateNormalLightPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("normallight", ["light", "colour", "shape", "basisX", "basisY"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4], CreateNormalLightPackageData(CreateNormalLightPackageAsset(0), CreateNormalLightPackageSize(0)), CreateNormalLightPackageData(CreateNormalLightPackageAsset(1), CreateNormalLightPackageSize(1)), CreateNormalLightPackageData(CreateNormalLightPackageAsset(2), CreateNormalLightPackageSize(2)), 3, CreateNormalLightPackageData(CreateNormalLightPackageAsset(3), CreateNormalLightPackageSize(3)), CreateNormalLightPackageData(CreateNormalLightPackageAsset(4), CreateNormalLightPackageSize(4)), CreateNormalLightPackageData(CreateNormalLightPackageAsset(5), CreateNormalLightPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateNormalLightPackageAsset:Byte Ptr(index:Int)
	Function CreateNormalLightPackageSize:Int(index:Int)
End Extern
Function CreateNormalLightPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
