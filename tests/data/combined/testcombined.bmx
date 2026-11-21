' Generated package wrapper. Run embed after compiling shader assets.
' Import testcombined_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable testcombined shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreateTestCombinedPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("testcombined", ["offset", "gain", "bias"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT4], CreateTestCombinedPackageData(CreateTestCombinedPackageAsset(0), CreateTestCombinedPackageSize(0)), CreateTestCombinedPackageData(CreateTestCombinedPackageAsset(1), CreateTestCombinedPackageSize(1)), CreateTestCombinedPackageData(CreateTestCombinedPackageAsset(2), CreateTestCombinedPackageSize(2)), 2, CreateTestCombinedPackageData(CreateTestCombinedPackageAsset(3), CreateTestCombinedPackageSize(3)), CreateTestCombinedPackageData(CreateTestCombinedPackageAsset(4), CreateTestCombinedPackageSize(4)), CreateTestCombinedPackageData(CreateTestCombinedPackageAsset(5), CreateTestCombinedPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateTestCombinedPackageAsset:Byte Ptr(index:Int)
	Function CreateTestCombinedPackageSize:Int(index:Int)
End Extern
Function CreateTestCombinedPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
