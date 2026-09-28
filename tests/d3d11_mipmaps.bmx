SuperStrict
Framework Max2D.D3D11Max2D
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int=0,y:Int=0)
	Return GrabPixmap(x,y,1,1).ReadPixel(0,0)
End Function
Function Near:Int(value:Int,expected:Int)
	Return Abs(value-expected)<=3
End Function
Try
	Local graphics:TGraphics=Graphics(64,64,0,0)
	Check(Max2DSupportsImageFlags(FILTEREDIMAGE|MIPMAPPEDIMAGE),"D3D11 advertises mipmaps")
	Local device:ID3D11DeviceContext=TD3D11Graphics(TMax2DGraphics.selected.context.graphics).GetDeviceContext()
	Local sampler:ID3D11SamplerState
	Local desc:D3D11_SAMPLER_DESC
	Local output:TRenderImage=CreateRenderImage(64,64,0)
	SetRenderImage(output)
	SetClsColor(0,0,0,1)
	Cls()
	Local p:TPixmap=CreatePixmap(64,64,PF_RGBA8888)
	For Local y:Int=0 Until 64
		For Local x:Int=0 Until 64
			If (x+y)&1 Then p.WritePixel(x,y,$ffffffff) Else p.WritePixel(x,y,$ff000000)
		Next
	Next
	Local image:TImage=TImage.FromPixmap(p,FILTEREDIMAGE|MIPMAPPEDIMAGE|DYNAMICIMAGE)
	Local stats:TMax2DStats=Max2DStats()
	Local generations:Long=stats.mipmapGenerations
	DrawImageRect(image,0,0,8,8)
	FlushMax2D()
	Check(stats.mipmapGenerations=generations+1,"Generate chain on first sampling")
	Check(Near(Pixel(3,3)&255,128),"Shrunken checkerboard averages to grey")
	device.PSGetSamplers(0,1,Varptr sampler);sampler.GetDesc(Varptr desc);sampler.Release_()
	Check(desc.Filter=D3D11_FILTER_MIN_MAG_MIP_LINEAR And desc.MaxLOD>0,"Trilinear mip selection")
	DrawImageRect(image,8,0,8,8)
	FlushMax2D()
	Check(stats.mipmapGenerations=generations+1,"Unchanged draws reuse mip chain")
	Local frame:TImageFrame=image.Frame()
	Local edit:TPixmap=LockImage(image)
	edit.ClearPixels($ffff0000)
	UnlockImage(image)
	DrawImageRect(image,16,0,8,8)
	Check((Pixel(19,3)&$ffffff)=$ff0000,"Image edit refreshes lower levels")
	Check(image.Frame()=frame,"Edits preserve texture identity")
	Check(stats.mipmapGenerations=generations+2,"One regeneration after edit")
	Check(Near(Pixel(3,3)&255,128),"Queued old draw preserved before upload")
	Local view:TImage=CreateImageView(image,0,0,32,64)
	edit=LockImage(view);edit.ClearPixels($ff00ff00);UnlockImage(view)
	DrawImageRect(image,24,0,1,1)
	Local color:Int=Pixel(24,0)
	Check(Near((color Shr 16)&255,128) And Near((color Shr 8)&255,128),"Partial edit reaches terminal mip level")

	' Fully transparent blue must not contaminate an opaque red neighbour.
	p=CreatePixmap(2,2,PF_RGBA8888)
	p.ClearPixels($000000ff)
	p.WritePixel(0,0,$ffff0000);p.WritePixel(0,1,$ffff0000)
	Local alphaImage:TImage=TImage.FromPixmap(p,FILTEREDIMAGE|MIPMAPPEDIMAGE)
	DrawImageRect(alphaImage,30,0,1,1)
	color=Pixel(30,0)
	Check(Near((color Shr 16)&255,128) And (color&$ffff)=0,"Premultiplied mipmaps avoid transparent colour fringes")
	Check(alphaImage.sources[0].pixmap.ReadPixel(1,0)=$000000ff,"CPU source pixels remain straight alpha")
	SetBlend(SOLIDBLEND)
	DrawImageRect(alphaImage,31,0,1,1)
	color=Pixel(31,0)
	Check(((color Shr 16)&255)>=250 And Near((color Shr 24)&255,128),"SOLID mipmapped sampling and straight target readback")
	SetBlend(ALPHABLEND)

	Local target:TRenderImage=CreateRenderImage(32,32,FILTEREDIMAGE|MIPMAPPEDIMAGE)
	SetRenderImage(target);SetClsColor(0,0,255,0.5);Cls()
	SetRenderImage(output)
	generations=stats.mipmapGenerations
	DrawImageRect(target,0,12,1,1)
	color=Pixel(0,12)
	Check(Near(color&255,128),"Target clear generates fresh premultiplied mipmaps")
	Check(stats.mipmapGenerations=generations+1,"Target generates once after clear")
	SetRenderImage(target);SetColor(0,255,0);SetBlend(SOLIDBLEND);DrawRect(0,0,32,32)
	SetRenderImage(output);SetColor(255,255,255);SetBlend(ALPHABLEND)
	DrawImageRect(target,1,12,1,1)
	Check((Pixel(1,12)&$ffffff)=$00ff00,"Drawing to target invalidates mipmaps")
	Check(stats.mipmapGenerations=generations+2,"Target regenerates after geometry")

	p=CreatePixmap(3,5,PF_RGBA8888);p.ClearPixels($ffffffff)
	Local odd:TImage=TImage.FromPixmap(p,MIPMAPPEDIMAGE)
	DrawImageRect(odd,4,12,1,1);FlushMax2D()
	Check((Pixel(4,12)&$ffffff)=$ffffff,"Non-power-of-two nearest mip sampling")
	device.PSGetSamplers(0,1,Varptr sampler);sampler.GetDesc(Varptr desc);sampler.Release_()
	Check(desc.Filter=D3D11_FILTER_MIN_MAG_MIP_POINT And desc.MaxLOD>0,"Nearest mip selection")

	p=CreatePixmap(64,32,PF_RGBA8888);p.ClearPixels($ffff0000)
	For Local y:Int=0 Until 32
		For Local x:Int=32 Until 64
			p.WritePixel(x,y,$ff0000ff)
		Next
	Next
	Local animation:TImage=LoadAnimImage(p,32,32,0,2,FILTEREDIMAGE|MIPMAPPEDIMAGE)
	Check(animation.sources[0]<>animation.sources[1],"Animation cells have isolated mip chains")
	DrawImageRect(animation,8,12,1,1,0);DrawImageRect(animation,9,12,1,1,1)
	Check((Pixel(8,12)&$ffffff)=$ff0000 And (Pixel(9,12)&$ffffff)=$0000ff,"Animation mipmaps do not bleed between frames")
	Local rejected:Int
	Try
		TTextureAtlas.Create(64,FILTEREDIMAGE|MIPMAPPEDIMAGE)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Packed atlas mipmaps rejected explicitly")

	SetRenderImage(Null)
	Flip(0)
	SetRenderImage(output);SetClsColor(0,0,0);Cls()
	DrawImageRect(image,0,0,1,1)
	color=Pixel()
	Check(Near((color Shr 16)&255,128) And Near((color Shr 8)&255,128),"Mipmap image survives presentation")
	SetRenderImage(target);SetClsColor(0,0,255,1);Cls()
	SetRenderImage(output);DrawImageRect(target,1,0,1,1)
	Check((Pixel(1,0)&$ffffff)=$0000ff,"Mipmapped target regenerates after presentation")
	SetRenderImage(Null)
	EndGraphics()
	Print "Max2D D3D11 mipmap tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
