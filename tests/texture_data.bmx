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
Try
	For Local invalid:Int=0 Until 3
		Local rejected:Int
		Try
			Select invalid
				Case 0
					TImage.FromTextureData(TTextureData.FromPixmap(CreatePixmap(2,2,PF_RGB565)))
				Case 1
					TImage.FromTextureData(TTextureData.Create([TTextureLevel.Create(2,2,PF_A8,New Byte[4]),TTextureLevel.Create(1,1,PF_A8,New Byte[1])]),DYNAMICIMAGE)
				Case 2
					TImage.FromTextureData(TTextureData.FromPixmap(CreatePixmap(2,2,PF_A8)),DYNAMICIMAGE)
			End Select
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Unsupported storage request rejected "+invalid)
	Next
	Graphics(100,80,0,0)
	Local output:TRenderImage=CreateRenderImage(32,32,0)
	SetRenderImage(output)
	Local retained:TImage
	For Local format:Int=0 Until 2
		Local pixelFormat:Int=PF_RGBA8888
		If format Then pixelFormat=PF_A8
		Local pitch:Int=5*BytesPerPixel[pixelFormat]+3
		Local bytes:Byte[]=New Byte[pitch*3]
		Local pixels:TPixmap=CreateStaticPixmap(bytes,5,3,pitch,pixelFormat)
		pixels.ClearPixels($ffffffff)
		pixels.WritePixel(2,1,$40ffffff)
		Local data:TTextureData=TTextureData.Create([TTextureLevel.Create(5,3,pixelFormat,bytes,pitch)])
		Local image:TImage=LoadImage(data,FILTEREDIMAGE)
		retained=image
		Check(image.sources[0].pixmap=Null,"Image stores texture data without a pixmap")
		Local animation:TImage=LoadAnimImage(data,1,3,0,5,FILTEREDIMAGE)
		Check(animation.sources.Length=5,"Texture data accepted by animation loader")
		Local reference:TImage=TImage.FromPixmap(pixels,FILTEREDIMAGE,pixelFormat)
		data.Level().Data()[0]=0
		SetColor(80,160,240)
		SetScale(3,3)
		SetBlend(ALPHABLEND)
		Cls()
		DrawImage(image,3,3)
		Local actual:TPixmap=ReadRenderImage(output)
		Cls()
		DrawImage(reference,3,3)
		Local expected:TPixmap=ReadRenderImage(output)
		For Local y:Int=0 Until 32
			For Local x:Int=0 Until 32
				Check(actual.ReadPixel(x,y)=expected.ReadPixel(x,y),"Raw storage renders like pixmap")
			Next
		Next
		Local read:TPixmap=LockImage(image,0,True,False)
		read.ClearPixels(0)
		UnlockImage(image)
		Check(TCollisionMask.ForSource(image.sources[0]).Solid(0,0),"Read lock cannot alter texture bytes")
		Check(Not TCollisionMask.ForSource(image.sources[0]).Solid(2,1),"Coverage collision threshold")
		Local rejected:Int
		Try
			LockImage(image)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Write lock rejected explicitly")
		Local view:TImage=CreateImageView(image,1,0,3,3)
		DrawImage(view,20,20)
		FlushMax2D()
	Next
	EndGraphics()
	Graphics(80,60,0,0)
	output=CreateRenderImage(16,16,0)
	SetRenderImage(output)
	Cls()
	DrawImage(retained,0,0)
	Check((ReadRenderImage(output).ReadPixel(0,0)&$ffffff)=$ffffff,"Texture storage survives close and reopen")
	EndGraphics()
	Print "Max2D texture data tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
