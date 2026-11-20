' Generated package wrapper. Run embed after compiling shader assets.
' Import dissolve_assets.c alongside your application imports.
Function CreateDissolvePackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("dissolve", ["progress", "width", "edge"], [MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT4], CreateDissolvePackageData(CreateDissolvePackageAsset(0), CreateDissolvePackageSize(0)), CreateDissolvePackageData(CreateDissolvePackageAsset(1), CreateDissolvePackageSize(1)), CreateDissolvePackageData(CreateDissolvePackageAsset(2), CreateDissolvePackageSize(2)), 4, CreateDissolvePackageData(CreateDissolvePackageAsset(3), CreateDissolvePackageSize(3)), CreateDissolvePackageData(CreateDissolvePackageAsset(4), CreateDissolvePackageSize(4)), CreateDissolvePackageData(CreateDissolvePackageAsset(5), CreateDissolvePackageSize(5)))
End Function
Private
Extern "C"
	Function CreateDissolvePackageAsset:Byte Ptr(index:Int)
	Function CreateDissolvePackageSize:Int(index:Int)
End Extern
Function CreateDissolvePackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
