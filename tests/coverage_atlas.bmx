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
Import Max2D.ScalableFont
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Compare(a:TPixmap,b:TPixmap)
	For Local y:Int=0 Until a.height
		For Local x:Int=0 Until a.width
			Local p:Int=a.ReadPixel(x,y)
			Local q:Int=b.ReadPixel(x,y)
			For Local shift:Int=0 To 24 Step 8
				Check(Abs(((p Shr shift)&255)-((q Shr shift)&255))<=1,"Coverage and RGBA output differ at "+x+","+y+": "+p+" / "+q)
			Next
		Next
	Next
End Function
Try
	Graphics(160,120,0,0)
	Local target:TRenderImage=CreateRenderImage(96,96,0)
	SetRenderImage(target)
	Local coverage:TTextureAtlas=TTextureAtlas.Create(32,DYNAMICIMAGE|FILTEREDIMAGE,1,PF_A8)
	Local rgba:TTextureAtlas=TTextureAtlas.Create(32,DYNAMICIMAGE|FILTEREDIMAGE)
	Local p:TPixmap=CreatePixmap(7,9,PF_A8)
	For Local y:Int=0 Until 9
		For Local x:Int=0 Until 7
			p.WritePixel(x,y,((x*37+y*19) Mod 256) Shl 24)
		Next
	Next
	Local a:TImage=coverage.AddPixmap(p,"a")
	Local b:TImage=rgba.AddPixmap(p,"a")
	' A second row exercises nonzero source/destination offsets and padded pitch.
	Local pad:TPixmap=CreatePixmap(24,4,PF_A8)
	pad.ClearPixels($ffffffff)
	coverage.AddPixmap(pad)
	rgba.AddPixmap(pad)
	Local c:TImage=coverage.AddPixmap(p,"c")
	Local d:TImage=rgba.AddPixmap(p,"c")
	Check(c.sourceY[0]>1,"Exercise a later atlas row")
	Check(a.sources[0].pixmap.format=PF_A8,"CPU coverage is retained")
	Check(b.sources[0].pixmap.format=PF_RGBA8888,"Default storage remains RGBA")
	For Local pass:Int=0 Until 3
		If pass Then
			p.ClearPixels($7fffffff)
			p.WritePixel(3,4,$ffffffff)
			coverage.UpdatePixmap("c",p)
			rgba.UpdatePixmap("c",p)
		End If
		SetBlend(ALPHABLEND)
		SetColor(90,210,140)
		SetAlpha(0.7)
		SetScale(2.3,2.3)
		Cls()
		DrawImage(a,5,5)
		DrawImage(c,40,30)
		Local actual:TPixmap=ReadRenderImage(target)
		Cls()
		DrawImage(b,5,5)
		DrawImage(d,40,30)
		Compare(actual,ReadRenderImage(target))
	Next
?max2d_gl Or max2d_sdlgpu
	Check(a.Frame().pixelFormat=PF_A8,"Backend uses native coverage storage")
?max2d_d3d11
	Check(a.Frame().pixelFormat=PF_A8,"D3D11 test device uses native coverage storage")
?Not max2d_gl And Not max2d_d3d11 And Not max2d_sdlgpu
	Check(a.Frame().pixelFormat=PF_RGBA8888,"Fallback uses RGBA storage")
?
	' The CPU storage choice must not change mipmap behaviour.
	If Max2DSupportsImageFlags(MIPMAPPEDIMAGE|FILTEREDIMAGE) Then
		Local ma:TImage=TImage.FromPixmap(p,MIPMAPPEDIMAGE|FILTEREDIMAGE,PF_A8)
		Local mb:TImage=TImage.FromPixmap(p,MIPMAPPEDIMAGE|FILTEREDIMAGE)
		SetScale(0.4,0.4)
		Cls()
		DrawImage(ma,5,5)
		Local actual:TPixmap=ReadRenderImage(target)
		Cls()
		DrawImage(mb,5,5)
		Compare(actual,ReadRenderImage(target))
?max2d_sdlgpu
		Check(ma.Frame().pixelFormat=PF_A8,"SDL GPU mipmapped coverage stays single-channel")
?Not max2d_sdlgpu
		Check(ma.Frame().pixelFormat=PF_RGBA8888,"Mipmapped coverage uses RGBA fallback")
?
	End If
	SetScale(1,1)
	If Max2DSupportsBlend(MASKBLEND) Then
		SetAlpha(1)
		SetBlend(MASKBLEND)
		Cls()
		DrawImage(c,5,5)
		Local actual:TPixmap=ReadRenderImage(target)
		Cls()
		DrawImage(d,5,5)
		Compare(actual,ReadRenderImage(target))
	End If
	SetBlend(ALPHABLEND)
	Local trimmedAtlas:TTextureAtlas=TTextureAtlas.Create(32,DYNAMICIMAGE,1,PF_A8)
	Local trimPixels:TPixmap=CreatePixmap(8,8,PF_A8)
	trimPixels.ClearPixels(0)
	trimPixels.WritePixel(3,4,$ffffffff)
	Local trimmed:TImage=trimmedAtlas.AddPixmap(trimPixels,"trim",True)
	Local trimLock:TPixmap=trimmed.Lock()
	Check(trimLock.format=PF_A8 And trimLock.width=8 And trimLock.height=8,"Trimmed lock has logical size and coverage format")
	trimLock.WritePixel(3,4,$80ffffff)
	trimmed.Unlock()
	Check(((trimmed.sources[0].pixmap.ReadPixel(trimmed.sourceX[0],trimmed.sourceY[0]) Shr 24)&255)=128,"Trimmed coverage write preserved")
	Local mask:TCollisionMask=TCollisionMask.ForSource(c.sources[0])
	Check(mask.Solid(c.sourceX[0]+3,c.sourceY[0]+4),"Opaque coverage collides")
	Check(Not mask.Solid(c.sourceX[0],c.sourceY[0]),"Coverage below 128 does not collide")
	Local lock:TPixmap=c.Lock()
	Check(lock.format=PF_A8,"Coverage lock retains format")
	lock.ClearPixels($ffffffff)
	c.Unlock()
	Cls()
	DrawImage(c,0,0)
	FlushMax2D()
	Check(TImageFont.DefaultFont().atlas.pages[0].sources[0].pixmap.format=PF_A8,"Built-in font uses coverage")
	If AppArgs.Length>1 Then
		Local font:TScalableImageFont=LoadScalableImageFont(AppArgs[1],20)
		Check(font<>Null,"Outline font loaded")
		SetImageFont(font)
		SetScale(1,1)
		DrawText("Coverage glyphs",0,60)
		FlushMax2D()
		Check(font.baseRaster.atlas.pages.Length>0,"Outline glyphs were generated")
		Check(font.baseRaster.atlas.pages[0].sources[0].pixmap.format=PF_A8,"Outline glyphs use coverage")
	End If
	EndGraphics()
	Print "Max2D coverage atlas tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
