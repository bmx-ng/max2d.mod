SuperStrict

Framework Max2D.SDL3RenderMax2D

Graphics 800, 600
RunAppLoop(MenuFrame, MenuStopped)

Function MenuFrame:Int()
	If KeyHit(KEY_SPACE) Then Return False
	Cls
	DrawText("Press Space to start", 100, 100)
	Flip
	Return True
End Function

Function MenuStopped()
	RunAppLoop(GameFrame, GameStopped)
End Function

Function GameFrame:Int()
	If KeyHit(KEY_ESCAPE) Then Return False
	Cls
	DrawText("Game running - press Escape to quit", 100, 100)
	Flip
	Return True
End Function

Function GameStopped()
	EndGraphics()
End Function
