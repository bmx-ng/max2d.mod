' Generated package wrapper. Run embed after compiling shader assets.
' Import distortion_assets.c alongside your application imports.
Rem
bbdoc: Creates the immutable distortion shader package from embedded assets.
about: Share the package between effect instances created with CreateShaderEffect. Parameter values are initialized by those instances, not by this package factory. Import the matching effects provider and query support after opening graphics.
End Rem
Function CreateDistortionPackage:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("distortion", ["time", "strength", "frequency", "ripple"], [MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT, MAX2D_PARAMETER_FLOAT], CreateDistortionPackageData(CreateDistortionPackageAsset(0), CreateDistortionPackageSize(0)), CreateDistortionPackageData(CreateDistortionPackageAsset(1), CreateDistortionPackageSize(1)), CreateDistortionPackageData(CreateDistortionPackageAsset(2), CreateDistortionPackageSize(2)), 2, CreateDistortionPackageData(CreateDistortionPackageAsset(3), CreateDistortionPackageSize(3)), CreateDistortionPackageData(CreateDistortionPackageAsset(4), CreateDistortionPackageSize(4)), CreateDistortionPackageData(CreateDistortionPackageAsset(5), CreateDistortionPackageSize(5)))
End Function
Private
Extern "C"
	Function CreateDistortionPackageAsset:Byte Ptr(index:Int)
	Function CreateDistortionPackageSize:Int(index:Int)
End Extern
Function CreateDistortionPackageData:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public
