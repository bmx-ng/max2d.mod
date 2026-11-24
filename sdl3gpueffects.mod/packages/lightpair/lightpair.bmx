' Generated package wrapper. Run embed after compiling shader assets.
' Import lightpair_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable lightpair shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreateLightPairPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("lightpair", ["lightA", "colourA", "lightB", "colourB", "basisX", "basisY", "options"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4], CreateLightPairPackageData(CreateLightPairPackageAsset(0), CreateLightPairPackageSize(0)), CreateLightPairPackageData(CreateLightPairPackageAsset(1), CreateLightPairPackageSize(1)), CreateLightPairPackageData(CreateLightPairPackageAsset(2), CreateLightPairPackageSize(2)), 5, CreateLightPairPackageData(CreateLightPairPackageAsset(3), CreateLightPairPackageSize(3)), CreateLightPairPackageData(CreateLightPairPackageAsset(4), CreateLightPairPackageSize(4)), CreateLightPairPackageData(CreateLightPairPackageAsset(5), CreateLightPairPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateLightPairPackageAsset:Byte Ptr(index:Int)
	Function CreateLightPairPackageSize:Int(index:Int)
End Extern
Function CreateLightPairPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
