' Generated package wrapper. Run embed after compiling shader assets.
' Import displacement_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable displacement shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreateDisplacementPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("displacement", ["amount"], [MAX2D_PARAMETER_FLOAT4], CreateDisplacementPackageData(CreateDisplacementPackageAsset(0), CreateDisplacementPackageSize(0)), CreateDisplacementPackageData(CreateDisplacementPackageAsset(1), CreateDisplacementPackageSize(1)), CreateDisplacementPackageData(CreateDisplacementPackageAsset(2), CreateDisplacementPackageSize(2)), 4, CreateDisplacementPackageData(CreateDisplacementPackageAsset(3), CreateDisplacementPackageSize(3)), CreateDisplacementPackageData(CreateDisplacementPackageAsset(4), CreateDisplacementPackageSize(4)), CreateDisplacementPackageData(CreateDisplacementPackageAsset(5), CreateDisplacementPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateDisplacementPackageAsset:Byte Ptr(index:Int)
	Function CreateDisplacementPackageSize:Int(index:Int)
End Extern
Function CreateDisplacementPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
