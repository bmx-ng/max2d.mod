SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d7
Framework Max2D.D3D7Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d7 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO

Function CheckRect(x:Int,y:Int,w:Int,h:Int,clear:Int)
	SetViewport(0,0,640,480)
	SetClsColor(0,0,255); Cls
	SetViewport(x,y,w,h)
	If clear Then
		SetClsColor(255,0,0); Cls
	Else
		SetBlend(SOLIDBLEND); SetColor(255,0,0)
		DrawRect(0,0,640,480)
	End If
	Local pw:Int=NativeResolutionWidth(), ph:Int=NativeResolutionHeight()
	Local p:TPixmap=GrabPixmap(0,0,pw,ph)
	For Local py:Int=0 Until ph
		For Local px:Int=0 Until pw
			Local lx:Double=(Double(px)+0.5)*640/pw
			Local ly:Double=(Double(py)+0.5)*480/ph
			Local expected:Int=$0000ff
			If lx>=x And lx<x+w And ly>=y And ly<y+h Then expected=$ff0000
			If (p.ReadPixel(px,py)&$ffffff)<>expected Then Throw "Clip mismatch at "+px+","+py+" rectangle="+x+","+y+","+w+","+h+" clear="+clear
		Next
	Next
End Function

Try
	Graphics 640,480,0,0
	Print "Viewport surface: "+NativeResolutionWidth()+"x"+NativeResolutionHeight()
	Local rects:Int[][]=[[120,90,400,300],[-200,-150,400,300],[-200,90,400,300],[120,-150,400,300],[439,329,400,300],[-500,90,400,300],[700,90,400,300],[120,-400,400,300],[120,500,400,300],[0,0,0,300],[0,0,400,0],[0,0,640,480]]
	For Local rect:Int[]=EachIn rects
		CheckRect(rect[0],rect[1],rect[2],rect[3],False)
		CheckRect(rect[0],rect[1],rect[2],rect[3],True)
	Next
	' Clip positions do not change mouse-to-scene coordinates.
	SetViewport(-200,-150,400,300)
	Local mapping:TMax2DInputMapping=CaptureWindowInput()
	Local vx:Float,vy:Float
	mapping.WindowToVirtual(0,0,vx,vy)
	If vx<>0 Or vy<>0 Then Throw "Clipping moved the mouse origin"
	EndGraphics()
	Print "Max2D viewport tests passed (24 complete pixel checks)"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
