SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d7
Framework Max2D.D3D7Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d7 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
?osx And max2d_gl
Import "gl_hidpi_mode.m"
Extern "C"
 Function max2d_test_gl_lowdpi()
End Extern
?

Local graphics:TGraphics=Graphics(160,120,0,0)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
If Not graphics Then Throw "Graphics creation failed"
SetClsColor(10,20,30)
Cls()
SetColor(255,0,0)
DrawRect(5,5,20,20)
Local pixels:TPixmap=GrabPixmap(10,10,1,1)
If (pixels.ReadPixel(0,0) & $ffffff)<>$ff0000 Then Throw "Red rectangle failed"
SetGraphics(graphics)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
DrawText("Hello World",10,40)
Flip(0)
EndGraphics()
Print "Max2D smoke test passed"
