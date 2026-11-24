' Generated package wrapper. Run embed after compiling shader assets.
' Import texturedlight_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable texturedlight shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreateTexturedLightPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("texturedlight", ["light", "colour", "shape", "basisX", "basisY", "cookieX", "cookieY"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4], CreateTexturedLightPackageData(CreateTexturedLightPackageAsset(0), CreateTexturedLightPackageSize(0)), CreateTexturedLightPackageData(CreateTexturedLightPackageAsset(1), CreateTexturedLightPackageSize(1)), CreateTexturedLightPackageData(CreateTexturedLightPackageAsset(2), CreateTexturedLightPackageSize(2)), 5, CreateTexturedLightPackageData(CreateTexturedLightPackageAsset(3), CreateTexturedLightPackageSize(3)), CreateTexturedLightPackageData(CreateTexturedLightPackageAsset(4), CreateTexturedLightPackageSize(4)), CreateTexturedLightPackageData(CreateTexturedLightPackageAsset(5), CreateTexturedLightPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateTexturedLightPackageAsset:Byte Ptr(index:Int)
	Function CreateTexturedLightPackageSize:Int(index:Int)
End Extern
Function CreateTexturedLightPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
