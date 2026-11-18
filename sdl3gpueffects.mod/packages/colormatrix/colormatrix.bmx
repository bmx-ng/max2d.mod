' Generated package wrapper. Run embed after compiling shader assets.
' Import colormatrix_assets.c alongside your application imports.
Function CreateColorMatrixPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("colormatrix", ["row0", "row1", "row2", "row3", "bias"], [MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4, MAX2D_PARAMETER_FLOAT4], CreateColorMatrixPackageData(CreateColorMatrixPackageAsset(0), CreateColorMatrixPackageSize(0)), CreateColorMatrixPackageData(CreateColorMatrixPackageAsset(1), CreateColorMatrixPackageSize(1)), CreateColorMatrixPackageData(CreateColorMatrixPackageAsset(2), CreateColorMatrixPackageSize(2)))
End Function
Private
Extern "C"
	Function CreateColorMatrixPackageAsset:Byte Ptr(index:Int)
	Function CreateColorMatrixPackageSize:Int(index:Int)
End Extern
Function CreateColorMatrixPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
