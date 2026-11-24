' Generated package wrapper. Run embed after compiling shader assets.
' Import emissionlight_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable emissionlight shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreateEmissionLightPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("emissionlight", ["ambient", "emission"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4], CreateEmissionLightPackageData(CreateEmissionLightPackageAsset(0), CreateEmissionLightPackageSize(0)), CreateEmissionLightPackageData(CreateEmissionLightPackageAsset(1), CreateEmissionLightPackageSize(1)), CreateEmissionLightPackageData(CreateEmissionLightPackageAsset(2), CreateEmissionLightPackageSize(2)), 3, CreateEmissionLightPackageData(CreateEmissionLightPackageAsset(3), CreateEmissionLightPackageSize(3)), CreateEmissionLightPackageData(CreateEmissionLightPackageAsset(4), CreateEmissionLightPackageSize(4)), CreateEmissionLightPackageData(CreateEmissionLightPackageAsset(5), CreateEmissionLightPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateEmissionLightPackageAsset:Byte Ptr(index:Int)
	Function CreateEmissionLightPackageSize:Int(index:Int)
End Extern
Function CreateEmissionLightPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
