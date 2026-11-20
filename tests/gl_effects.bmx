SuperStrict
Framework Max2D.GLMax2D
Import Max2D.GLEffects
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Near(actual:Float,expected:Float,message:String)
	If Abs(actual-expected)>0.005 Then Throw message+": "+actual+" expected "+expected
End Function
Function ReadChannel:Float(data:TTextureData,x:Int,y:Int,channel:Int)
	Return Float Ptr(data.Level().Data()+y*data.Level().Pitch())[x*4+channel]
End Function
Try
	Local saturation:TMax2DSaturationEffect=CreateSaturationEffect(1)
	Local colour:TMax2DColorizeEffect=CreateColorizeEffect(80,160,240)
	For Local lifetime:Int=0 Until 2
		Graphics(96,96)
		Check(Max2DSupportsImageEffect(saturation) And Max2DSupportsImageEffect(colour),"GL providers required")
		Check(Not Max2DSupportsImageEffect(CreateBrightPassEffect()),"Bright pass remains unsupported")
		Local pixels:TPixmap=CreatePixmap(4,4,PF_RGBA8888)
		For Local y:Int=0 Until 4
			For Local x:Int=0 Until 4
				pixels.WritePixel(x,y,((64+x*40+y*10) Shl 24) | ((40+x*50) Shl 16) | ((20+y*60) Shl 8) | 100)
			Next
		Next
		Local image:TImage=LoadImage(pixels,0)
		Local source:TRenderImage=CreateRenderImage(4,4,0)
		SetRenderImage(source); SetBlend(SOLIDBLEND); DrawImage(image,0,0)
		Local reference:TRenderImage=CreateRenderImage(32,32,0)
		Local result:TRenderImage=CreateRenderImage(32,32,0)
		For Local kind:Int=0 Until 2
			Local view:TImage=CreateImageView(image,1,1,2,2)
			If kind Then view=CreateImageView(source,1,1,2,2)
			SetImageHandle(view,1,1)
			SetOrigin(3,2); SetRotation(90); SetScale(3,2)
			SetColor(128,220,255); SetAlpha(0.75)
			SetRenderImage(reference); SetClsColor(0,0,0,0); Cls
			DrawImage(view,10,10)
			SetRenderImage(result); Cls
			saturation.SetAmount(1); DrawImageEffect(view,saturation,10,10)
			Local expected:TPixmap=ReadRenderImage(reference),actual:TPixmap=ReadRenderImage(result)
			For Local y:Int=0 Until 32
				For Local x:Int=0 Until 32
					Check(actual.ReadPixel(x,y)=expected.ReadPixel(x,y),"Identity effect preserves atlas bounds, orientation, handle and transform")
				Next
			Next
		Next
		SetOrigin(0,0); SetTransform(); SetColor(255,255,255); SetAlpha(1)
		' Alpha-only input must not inherit the RGB interpretation of RGBA storage.
		Local coverage:TPixmap=CreatePixmap(2,2,PF_A8)
		coverage.pixels[0]=32; coverage.pixels[1]=64
		coverage.pixels[coverage.pitch]=128; coverage.pixels[coverage.pitch+1]=255
		Local mask:TImage=TImage.FromPixmap(coverage,0,PF_A8)
		SetRenderImage(result); Cls; saturation.SetAmount(0)
		DrawImageEffect(mask,saturation,0,0)
		Local whiteCoverage:TPixmap=ReadRenderImage(result)
		Check((whiteCoverage.ReadPixel(0,0) & $ffffff)=$ffffff,"Saturation interprets coverage as white RGB")
		SetBlend(MASKBLEND); Cls; DrawImageEffect(mask,colour,0,0)
		Local clipped:TPixmap=ReadRenderImage(result)
		Check((clipped.ReadPixel(0,0) Shr 24)=0 And (clipped.ReadPixel(1,0) Shr 24)=0,"Mask blend discards alpha below threshold")
		Check(((clipped.ReadPixel(0,1) Shr 24) & 255)=128 And ((clipped.ReadPixel(1,1) Shr 24) & 255)=255,"Mask blend retains accepted alpha")
		SetBlend(SOLIDBLEND); DrawImageEffect(mask,colour,0,0)
		Local actual:TPixmap=ReadRenderImage(result)
		For Local y:Int=0 Until 2
			For Local x:Int=0 Until 2
				Local pixel:Int=actual.ReadPixel(x,y)
				Check(Abs(((pixel Shr 24) & 255)-coverage.pixels[y*coverage.pitch+x])<=1,"Coverage alpha and row orientation")
				Check(Abs(((pixel Shr 16) & 255)-80)<=5 And Abs(((pixel Shr 8) & 255)-160)<=5 And Abs((pixel & 255)-240)<=5,"Colourized coverage")
			Next
		Next
		' Blur samples mip zero, even under minification, then restores the texture range.
		Local mipSource:TRenderImage=CreateRenderImage(32,32,MIPMAPPEDIMAGE)
		SetRenderImage(mipSource); SetClsColor(0,0,0,1); Cls
		SetColor(255,255,255); DrawRect(14,14,4,4)
		SetRenderImage(result); SetScale(1.0/32,1.0/32)
		DrawImageEffect(mipSource,CreateBlurEffect(0),0,0)
		Local baseLevel:Int,maxLevel:Int
		glGetTexParameteriv(GL_TEXTURE_2D,GL_TEXTURE_BASE_LEVEL,Varptr baseLevel)
		glGetTexParameteriv(GL_TEXTURE_2D,GL_TEXTURE_MAX_LEVEL,Varptr maxLevel)
		Check(baseLevel=0 And maxLevel>0,"Blur restores mip range")
		DrawImage(mipSource,1,0); SetScale(1,1)
		Local mipPixels:TPixmap=ReadRenderImage(result)
		Check((mipPixels.ReadPixel(0,0)&255)>250,"Minified blur reads base level")
		Check((mipPixels.ReadPixel(1,0)&255)<6,"Ordinary drawing resumes mip sampling")
		SetScale(1.0/32,1.0/32)
		DrawImageEffect(mipSource,CreateOutlineEffect(4),2,0)
		glGetTexParameteriv(GL_TEXTURE_2D,GL_TEXTURE_BASE_LEVEL,Varptr baseLevel)
		glGetTexParameteriv(GL_TEXTURE_2D,GL_TEXTURE_MAX_LEVEL,Varptr maxLevel)
		Check(baseLevel=0 And maxLevel>0,"Outline restores mip range")
		DrawImage(mipSource,3,0); SetScale(1,1)
		mipPixels=ReadRenderImage(result)
		Check(((mipPixels.ReadPixel(2,0) Shr 24)&255)=0,"Opaque interior has no outline")
		Check((mipPixels.ReadPixel(3,0)&255)<6,"Ordinary mip sampling after outline")
		If Max2DSupportsRenderImage(4,4,0,PF_RGBA32F) Then
			Local values:Float[]=[Float(4),0.5,-0.25,0.5, 0.25,2,0.5,0.25, 0.1,0.2,3,1, 1,1,1,0.75]
			Local bytes:Byte[]=New Byte[64]; MemCopy(bytes,values,64)
			Local hdr:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(2,2,PF_RGBA32F,bytes)]),0)
			Local hdrLayer:TRenderImage=CreateRenderImage(2,2,0,PF_RGBA32F)
			SetRenderImage(hdrLayer); DrawImage(hdr,0,0)
			Local target:TRenderImage=CreateRenderImage(4,2,0,PF_RGBA32F)
			SetRenderImage(target)
			saturation.SetAmount(1); DrawImageEffect(hdr,saturation,0,0)
			saturation.SetAmount(0); DrawImageEffect(hdrLayer,saturation,2,0)
			Local data:TTextureData=ReadRenderTextureData(target)
			For Local y:Int=0 Until 2
				For Local x:Int=0 Until 2
					Local i:Int=(y*2+x)*4
					For Local channel:Int=0 Until 4
						Near(ReadChannel(data,x,y,channel),values[i+channel],"Straight HDR source and alpha preserved")
					Next
					Local grey:Float=values[i]*0.2126+values[i+1]*0.7152+values[i+2]*0.0722
					For Local channel:Int=0 Until 3
						Near(ReadChannel(data,x+2,y,channel),grey,"Premultiplied HDR saturation and orientation")
					Next
					Near(ReadChannel(data,x+2,y,3),values[i+3],"HDR saturation alpha")
				Next
			Next
			DrawImageEffect(hdrLayer,CreateBlurEffect(4),0,0)
			data=ReadRenderTextureData(target)
			For Local y:Int=0 Until 2
				For Local x:Int=0 Until 2
					Local i:Int=(y*2+x)*4,j:Int=(y*2+1-x)*4
					Local alpha:Float=(values[i+3]*70+values[j+3]*56)/256
					Near(ReadChannel(data,x,y,3),alpha,"HDR blur edge alpha")
					For Local channel:Int=0 Until 3
						Local expected:Float=(values[i+channel]*values[i+3]*70+values[j+channel]*values[j+3]*56)/(256*alpha)
						Near(ReadChannel(data,x,y,channel),expected,"HDR blur premultiplied kernel")
					Next
				Next
			Next
		Else
			Print "Float target unavailable; HDR checks skipped"
		End If
		SetRenderImage(Null); EndGraphics
	Next
	Print "gl_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
