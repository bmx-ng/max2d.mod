' Generated package wrapper. Run embed after compiling shader assets.
' Import testcoordinates_assets.c alongside your application imports.
Function CreateTestCoordinatesPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("testcoordinates", ["offset"], [MAX2D_PARAMETER_FLOAT4], CreateTestCoordinatesPackageData(CreateTestCoordinatesPackageAsset(0), CreateTestCoordinatesPackageSize(0)), CreateTestCoordinatesPackageData(CreateTestCoordinatesPackageAsset(1), CreateTestCoordinatesPackageSize(1)), CreateTestCoordinatesPackageData(CreateTestCoordinatesPackageAsset(2), CreateTestCoordinatesPackageSize(2)), 2)
End Function
Private
Extern "C"
	Function CreateTestCoordinatesPackageAsset:Byte Ptr(index:Int)
	Function CreateTestCoordinatesPackageSize:Int(index:Int)
End Extern
Function CreateTestCoordinatesPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
