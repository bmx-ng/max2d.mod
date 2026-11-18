' Generated package wrapper. Run embed.py after compiling shader assets.
' Import testgain_assets.c alongside your application imports.
Function CreateTestGainPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("testgain", ["gain", "bias"], [MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT4], CreateTestGainPackageData(CreateTestGainPackageAsset(0), CreateTestGainPackageSize(0)), CreateTestGainPackageData(CreateTestGainPackageAsset(1), CreateTestGainPackageSize(1)), CreateTestGainPackageData(CreateTestGainPackageAsset(2), CreateTestGainPackageSize(2)))
End Function
Private
Extern "C"
	Function CreateTestGainPackageAsset:Byte Ptr(index:Int)
	Function CreateTestGainPackageSize:Int(index:Int)
End Extern
Function CreateTestGainPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
