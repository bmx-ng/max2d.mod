SuperStrict
Framework Max2D.D3D11Max2D

Graphics 800, 480, 0
Local scene:TRenderImage = CreateRenderImage(128, 128, FILTEREDIMAGE)
Local composite:TRenderImage = CreateRenderImage(256, 128, FILTEREDIMAGE)

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()

	' Draw both passes each frame, using the shared render-image API.
	SetRenderImage(scene)
	SetClsColor(0, 0, 0, 0)
	Cls()
	SetBlend(ALPHABLEND)
	SetAlpha(0.6)
	SetColor(0, 180, 255)
	DrawOval(8, 8, 96, 96)
	SetColor(255, 100, 40)
	DrawRect(48, 48, 72, 72)
	SetAlpha(1)
	SetColor(255, 255, 255)
	DrawText("Max2D", 28, 58)

	' The first render image becomes an ordinary source for the second pass.
	SetRenderImage(composite)
	SetClsColor(0, 0, 0, 0)
	Cls()
	DrawImage(scene, 0, 0)
	SetColor(180, 255, 180)
	DrawImage(scene, 128, 0)

	SetRenderImage(Null)
	SetClsColor(32, 40, 56)
	Cls()
	SetColor(255, 255, 255)
	DrawText("D3D11 - existing Max2D render-image API", 24, 24)
	DrawText("Source", 24, 80)
	DrawImage(scene, 24, 110)
	DrawText("Second pass, enlarged", 240, 80)
	SetScale(2, 2)
	DrawImage(composite, 240, 110)
	SetScale(1, 1)
	DrawText("Escape to exit", 24, 440)
	Flip(1)
Wend

EndGraphics()
