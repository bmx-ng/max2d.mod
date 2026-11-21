SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import BRL.StandardIO

Graphics 800, 300
Const layerWidth:Int = 240, layerHeight:Int = 180
If Not Max2DSupportsRenderImage(layerWidth, layerHeight, FILTEREDIMAGE) Then Throw "Filtered render images are required"

' Allocate and draw this padded source once. Keep it for subsequent frames.
Local source:TRenderImage = CreateRenderImage(layerWidth, layerHeight, FILTEREDIMAGE)
Using
	Local scope:TMax2DStateScope = ScopedMax2DState()
Do
	SetRenderImage(source)
	SetVirtualResolution(layerWidth, layerHeight)
	SetClsColor(0, 0, 0, 0)
	Cls
	SetColor(255, 145, 45)
	DrawOval(40, 35, 100, 100)
	SetColor(60, 190, 235)
	DrawRect(115, 65, 80, 70)
End Using

' Descriptions allocate no render images and can be retained and edited.
Local grayscale:TMax2DSaturationEffect = CreateSaturationEffect(0)
Local tint:TMax2DColorizeEffect = CreateColorizeEffect(100, 185, 255)
Local horizontal:TMax2DBlurEffect = CreateBlurEffect(4, True)
Local vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)
If Not Max2DSupportsImageEffect(grayscale) Then Throw "Import an effects provider supported by this graphics context"

' The retained chain chooses and reuses its own output and scratch images.
Local chain:TMax2DEffectChain = CreateEffectChain([TMax2DImageEffect(horizontal), TMax2DImageEffect(vertical), TMax2DImageEffect(tint)])
chain.Prepare(layerWidth, layerHeight)
Local softened:TRenderImage = chain.Update(source)

' Cached helpers own their intermediate images. Update only when needed.
Local shadow:TMax2DShadow = CreateShadow(8)
shadow.Prepare(layerWidth, layerHeight, 2)
shadow.Update(source)

Local testMode:Int = AppArgs.Length > 1 And AppArgs[1] = "--test"
Local frames:Int
SetClsColor(24, 28, 38)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls
	SetBlend(ALPHABLEND)
	SetColor(255, 255, 255)
	SetAlpha(1)
	DrawImageEffect(source, grayscale, 10, 60)
	DrawImage(softened, 280, 60)
	SetColor(0, 0, 0)
	SetAlpha(0.65)
	DrawImage(shadow.Result(), 550+8, 60+8)
	SetColor(255, 255, 255)
	SetAlpha(1)
	DrawImage(source, 550, 60)
	DrawText("Direct effect", 30, 30)
	DrawText("Cached blur + colour", 280, 30)
	DrawText("Cached shadow", 550, 30)
	Flip
	frames:+1
	If testMode And frames=3 Then Exit
Wend

' Borrowed results expire here; select a separate target before releasing.
SetRenderImage(Null)
shadow.Release()
chain.Release()
source.ReleaseFrames()
EndGraphics
If testMode Then Print "PASS effects quickstart"
