' Generated package wrapper. Run embed after compiling shader assets.
' Import texturemask_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable texturemask shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreateTextureMaskPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("texturemask", ["channels", "invert"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT], CreateTextureMaskPackageData(CreateTextureMaskPackageAsset(0), CreateTextureMaskPackageSize(0)), CreateTextureMaskPackageData(CreateTextureMaskPackageAsset(1), CreateTextureMaskPackageSize(1)), CreateTextureMaskPackageData(CreateTextureMaskPackageAsset(2), CreateTextureMaskPackageSize(2)), 4, CreateTextureMaskPackageData(CreateTextureMaskPackageAsset(3), CreateTextureMaskPackageSize(3)), CreateTextureMaskPackageData(CreateTextureMaskPackageAsset(4), CreateTextureMaskPackageSize(4)), CreateTextureMaskPackageData(CreateTextureMaskPackageAsset(5), CreateTextureMaskPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateTextureMaskPackageAsset:Byte Ptr(index:Int)
	Function CreateTextureMaskPackageSize:Int(index:Int)
End Extern
Function CreateTextureMaskPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
