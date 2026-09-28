SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Atlas
Import Max2D.AtlasIO
Import BRL.System

' Optionally supply a NEW output directory to save and reload the package.
' The moving shape deliberately occupies different parts of its logical canvas.
Local pixels:TPixmap[]=New TPixmap[6]
Local original:TImage[]=New TImage[6]
Local durations:Int[]=[120,120,120,120,120,450]
For Local frame:Int=0 Until pixels.Length
	Local p:TPixmap=CreatePixmap(80,64,PF_RGBA8888)
	p.ClearPixels(0)
	Local left:Int=8+frame*7,top:Int=18-(frame Mod 3)*4
	For Local y:Int=top Until top+24
		For Local x:Int=left Until left+20
			p.WritePixel(x,y,$ff30c8f0)
		Next
	Next
	p.WritePixel(left+14,top+6,$ffffffff)
	p.WritePixel(left+15,top+6,$ffffffff)
	pixels[frame]=p
	original[frame]=TImage.FromPixmap(p,FILTEREDIMAGE)
Next

Local builder:TAtlasBuilder=New TAtlasBuilder
builder.pageSize=128
builder.trimTransparent=True
builder.AddAnimation("walker",pixels,durations)
Local atlas:TTextureAtlas=builder.Build()
Local animation:TImage=atlas.GetImage("walker")
SetImageHandle(animation,40,32)
If AppArgs.Length>1 Then
	SaveTextureAtlas(atlas,AppArgs[1])
	atlas=LoadTextureAtlas(AppArgs[1])
	animation=atlas.GetImage("walker")
End If
For Local image:TImage=EachIn original
	SetImageHandle(image,40,32)
Next

Graphics 900,600
SetClsColor(20,24,34)
SetBlend(ALPHABLEND)
Local start:Int=MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local elapsed:Long=Long(UInt(MilliSecs()-start))
	Local frame:Int=animation.FrameAtTime(elapsed)
	Cls()
	SetColor(255,255,255)
	DrawText("Atlas animation: original canvas and timing preserved",24,20)
	DrawText("Original images",100,70)
	DrawText("Trimmed atlas frames",480,70)
	DrawText("Frame "+frame+" / "+animation.sources.Length+"    duration "+animation.frameDuration[frame]+" ms",24,330)
	DrawText("The final frame holds longer. Both versions share the same anchor.",24,355)
	DrawText("Packed texture pages (including transparent filtering fringes):",24,405)
	For Local column:Int=0 Until 2
		Local x:Int=100+column*380,y:Int=110
		SetColor(39,47,63); DrawRect(x,y,240,192)
		SetColor(94,108,136)
		DrawLine(x+120,y,x+120,y+192); DrawLine(x,y+96,x+240,y+96)
		SetColor(255,255,255)
		SetScale(3,3)
		If column=0 Then
			DrawImage(original[frame],x+120,y+96)
		Else
			DrawImage(animation,x+120,y+96,frame)
		End If
		SetScale(1,1)
	Next
	For Local page:Int=0 Until atlas.PageCount()
		SetColor(39,47,63); DrawRect(24+page*150,435,128,128)
		SetColor(255,255,255); DrawImage(atlas.Page(page),24+page*150,435)
	Next
	Flip()
Wend
EndGraphics()
