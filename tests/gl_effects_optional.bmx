SuperStrict
Framework Max2D.GLMax2D
Import Max2D.Effects
Import BRL.StandardIO
Try
	Graphics(32,32)
	If Max2DSupportsImageEffect(CreateSaturationEffect()) Or Max2DSupportsImageEffect(CreateColorizeEffect()) Or Max2DSupportsImageEffect(CreateBlurEffect()) Or Max2DSupportsImageEffect(CreateOutlineEffect()) Or Max2DSupportsImageEffect(CreateBrightPassEffect()) Or Max2DSupportsImageEffect(CreateToneMapEffect()) Or Max2DSupportsImageEffect(CreateLinearOutputEffect()) Then Throw "Effects require the optional provider import"
	Local target:TRenderImage=CreateRenderImage(4,4)
	SetRenderImage(target); SetBlend(SOLIDBLEND); SetColor(255,0,0)
	DrawRect(0,0,4,4)
	If ReadRenderImage(target).ReadPixel(1,1)<>Int($ffff0000) Then Throw "Ordinary OpenGL drawing changed"
	EndGraphics
	Print "gl_effects_optional passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
