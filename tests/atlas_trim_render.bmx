SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Render:TPixmap(image:TImage,mode:Int)
	SetCamera(Null); SetTransform(0,1,1)
	SetClsColor(23,31,47); Cls()
	Select mode
		Case 0
			DrawImage(image,20,20)
		Case 1
			SetTransform(0,3,2); DrawImage(image,30,30)
		Case 2
			SetTransform(90,-2,2); DrawImage(image,70,60)
		Case 3
			DrawSubImageRect(image,10,10,48,40,2,3,16,10)
		Case 4
			DrawSubImageRect(image,90,10,-48,40,2,3,16,10)
		Case 5
			DrawImage(TImage.View(image,3,4,14,12),10,10)
		Case 6
			Local camera:TCamera2D=New TCamera2D
			camera.x=4; camera.y=3; camera.zoom=2; camera.offsetX=10; camera.offsetY=8
			SetCamera(camera); DrawImage(image,20,20)
		Case 7
			DrawSubImageRect(image,10,10,50,50,0,0,2,2)
	End Select
	Return GrabPixmap(0,0,128,96)
End Function

Try
	Local graphics:TGraphics=Graphics(128,96,0,0)
	Check(graphics<>Null,"Graphics creation")
	Local target:TRenderImage=CreateRenderImage(128,96,0)
	SetRenderImage(target)
	SetBlend(ALPHABLEND)
	Local pixels:TPixmap=CreatePixmap(32,24,PF_RGBA8888)
	pixels.ClearPixels(0)
	For Local y:Int=6 Until 12
		For Local x:Int=5 Until 13
			pixels.WritePixel(x,y,$c0ff8000)
		Next
	Next
	For Local filtered:Int=0 Until 2
		Local flags:Int
		If filtered Then flags=FILTEREDIMAGE
		Local atlas:TTextureAtlas=TTextureAtlas.Create(64,flags)
		Local trimmed:TImage=atlas.AddPixmap(pixels,"trimmed",True)
		Local full:TImage=atlas.AddPixmap(pixels,"full")
		trimmed.handle_x=4; trimmed.handle_y=3
		full.handle_x=4; full.handle_y=3
		For Local mode:Int=0 Until 8
			Local a:TPixmap=Render(full,mode),b:TPixmap=Render(trimmed,mode)
			For Local y:Int=0 Until a.height
				For Local x:Int=0 Until a.width
					Local pa:Int=a.ReadPixel(x,y),pb:Int=b.ReadPixel(x,y)
					For Local shift:Int=0 To 16 Step 8
						Check(Abs(((pa Shr shift)&255)-((pb Shr shift)&255))<=2,"Trim render mismatch: filtered="+filtered+" mode="+mode+" pixel="+x+","+y+" colors="+pa+","+pb)
					Next
				Next
			Next
		Next
	Next
	SetCamera(Null); SetTransform(0,1,1); SetRenderImage(Null)
	EndGraphics()
	Print "Max2D trimmed atlas rendering tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
