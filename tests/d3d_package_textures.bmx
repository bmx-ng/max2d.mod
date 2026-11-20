SuperStrict
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?Not max2d_d3d9
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Near(value:Float,expected:Float,message:String)
	If Abs(value-expected)>0.005 Then Throw message+": "+value+" expected "+expected
End Function
Try
	For Local lifetime:Int=0 Until 2
		Graphics(64,64)
		Local source:TRenderImage=CreateRenderImage(32,32,MIPMAPPEDIMAGE|FILTEREDIMAGE)
		SetRenderImage(source); SetClsColor(255,255,255,0.5); Cls
		Local map:TRenderImage=CreateRenderImage(32,32,MIPMAPPEDIMAGE|FILTEREDIMAGE)
		SetRenderImage(map); SetClsColor(255,255,255,0.25); Cls
		SetColor(255,255,255); SetAlpha(1); SetBlend(SOLIDBLEND); DrawRect(14,14,4,4)
		Local output:TRenderImage=CreateRenderImage(4,4,0,PF_RGBA32F)
		Local effect:TMax2DShaderEffect=CreateTextureMaskEffect(map)
		SetRenderImage(output); SetScale(1.0/32,1.0/32)
		DrawImageEffect(source,effect,0,0)
		DrawImage(map,1,0)
		effect.SetTexture(source)
		DrawImageEffect(source,effect,2,0)
		SetScale(1,1)
		Local read:TTextureData=ReadRenderTextureData(output)
		Local pixels:Float Ptr=Float Ptr(read.Level().Data())
		Near(pixels[3],0.5,"Map samples mip zero")
		Near(pixels[7],Float(0.25+0.75/64),"Ordinary map draw resumes mip sampling")
		Near(pixels[11],0.25,"Same source and map texture supports independent bindings")
		Near(pixels[8],1,"Same-texture sampling preserves straight colour")
		' Distinct rows catch render-target map orientation errors.
		Local coverage:TPixmap=CreatePixmap(2,2,PF_A8)
		coverage.pixels[0]=32; coverage.pixels[1]=96
		coverage.pixels[coverage.pitch]=160; coverage.pixels[coverage.pitch+1]=224
		Local coverageImage:TImage=LoadImage(coverage,MIPMAPPEDIMAGE|FILTEREDIMAGE)
		Local mapLayer:TRenderImage=CreateRenderImage(2,2,0,PF_RGBA32F)
		SetRenderImage(mapLayer); DrawImage(coverageImage,0,0)
		SetRenderImage(output); SetScale(1.0/16,1.0/16)
		For Local kind:Int=0 Until 2
			If kind Then effect.SetTexture(mapLayer) Else effect.SetTexture(coverageImage)
			effect.SetFloat4("channels",0,0,0,1)
			DrawImageEffect(source,effect,0,0)
			read=ReadRenderTextureData(output); pixels=Float Ptr(read.Level().Data())
			For Local y:Int=0 Until 2
				For Local x:Int=0 Until 2
					Near(pixels[(y*4+x)*4+3],Float(coverage.pixels[y*coverage.pitch+x])/510,"Coverage/map row orientation")
				Next
			Next
		Next
		effect.SetTexture(coverageImage); effect.SetFloat4("channels",0.25,0,0,0)
		DrawImageEffect(source,effect,0,0)
		read=ReadRenderTextureData(output); pixels=Float Ptr(read.Level().Data())
		Near(pixels[3],0.125,"Mipmapped coverage exposes straight white RGB")
		SetScale(1,1)
		Local rejected:Int
		effect.SetTexture(output)
		Try
			DrawImageEffect(source,effect,0,0)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Destination feedback rejected")
		read=ReadRenderTextureData(output); pixels=Float Ptr(read.Level().Data())
		Near(pixels[3],0.125,"Feedback rejection leaves target unchanged")
		DrawImage(mapLayer,0,0)
		read=ReadRenderTextureData(output); pixels=Float Ptr(read.Level().Data())
		Near(pixels[3],Float(32.0/255),"Ordinary draw recovers after feedback rejection")
		EndGraphics
	Next
	Print "d3d_package_textures passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
