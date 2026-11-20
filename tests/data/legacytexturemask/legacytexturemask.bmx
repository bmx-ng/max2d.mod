' Generated package wrapper. Run embed after compiling shader assets.
' Import legacytexturemask_assets.c alongside your application imports.
Function CreateLegacyTextureMaskPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("legacytexturemask", ["channels", "invert"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT], CreateLegacyTextureMaskPackageData(CreateLegacyTextureMaskPackageAsset(0), CreateLegacyTextureMaskPackageSize(0)), CreateLegacyTextureMaskPackageData(CreateLegacyTextureMaskPackageAsset(1), CreateLegacyTextureMaskPackageSize(1)), CreateLegacyTextureMaskPackageData(CreateLegacyTextureMaskPackageAsset(2), CreateLegacyTextureMaskPackageSize(2)), 3, CreateLegacyTextureMaskPackageData(CreateLegacyTextureMaskPackageAsset(3), CreateLegacyTextureMaskPackageSize(3)), CreateLegacyTextureMaskPackageData(CreateLegacyTextureMaskPackageAsset(4), CreateLegacyTextureMaskPackageSize(4)), CreateLegacyTextureMaskPackageData(CreateLegacyTextureMaskPackageAsset(5), CreateLegacyTextureMaskPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateLegacyTextureMaskPackageAsset:Byte Ptr(index:Int)
	Function CreateLegacyTextureMaskPackageSize:Int(index:Int)
End Extern
Function CreateLegacyTextureMaskPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
