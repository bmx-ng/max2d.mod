' Generated package wrapper. Run embed after compiling shader assets.
' Import thresholdmask_assets.c alongside your application imports.
Function CreateThresholdMaskPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("thresholdmask", ["channels", "range", "invert"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT], CreateThresholdMaskPackageData(CreateThresholdMaskPackageAsset(0), CreateThresholdMaskPackageSize(0)), CreateThresholdMaskPackageData(CreateThresholdMaskPackageAsset(1), CreateThresholdMaskPackageSize(1)), CreateThresholdMaskPackageData(CreateThresholdMaskPackageAsset(2), CreateThresholdMaskPackageSize(2)), 4, CreateThresholdMaskPackageData(CreateThresholdMaskPackageAsset(3), CreateThresholdMaskPackageSize(3)))
End Function
Private
Extern "C"
	Function CreateThresholdMaskPackageAsset:Byte Ptr(index:Int)
	Function CreateThresholdMaskPackageSize:Int(index:Int)
End Extern
Function CreateThresholdMaskPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
