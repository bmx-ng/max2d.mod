SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import BRL.StandardIO

Graphics 760, 280
Local layer:TMax2DEffectLayer = New TMax2DEffectLayer
' 160 x 100 logical content, 24 units of padding, two pixels per unit.
layer.Prepare(160, 100, 24, 24, 24, 24, 2)
Using
	Local capture:TMax2DStateScope = layer.Capture()
Do
	SetColor(255, 145, 45)
	DrawOval(0, 0, 90, 90)
	SetColor(60, 190, 235)
	DrawRect(75, 35, 85, 65)
End Using

Local chain:TMax2DEffectChain = CreateEffectChain([TMax2DImageEffect(CreateSaturationEffect(0))])
chain.Prepare(layer.Image().width, layer.Image().height)
chain.Update(layer.Image())
Local shadow:TMax2DShadow = CreateShadow(16) ' Eight logical units at scale two.
shadow.Prepare(layer.Image().width, layer.Image().height, 3)
shadow.Update(layer.Image())

Local testMode:Int = AppArgs.Length > 1 And AppArgs[1] = "--test"
Local frames:Int
SetClsColor(24, 28, 38)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls
	SetColor(255, 255, 255)
	SetAlpha(1)
	layer.Draw(40, 90)
	layer.Draw(290, 90, chain.Result())
	SetColor(0, 0, 0)
	SetAlpha(0.7)
	layer.Draw(540+6, 90+8, shadow.Result())
	SetColor(255, 255, 255)
	SetAlpha(1)
	layer.Draw(540, 90)
	DrawText("Captured layer", 40, 35)
	DrawText("Retained chain", 290, 35)
	DrawText("Padded shadow", 540, 35)
	Flip
	frames :+ 1
	If testMode And frames = 3 Then Exit
Wend
shadow.Release()
chain.Release()
layer.Release()
EndGraphics
If testMode Then Print "PASS composition example"
