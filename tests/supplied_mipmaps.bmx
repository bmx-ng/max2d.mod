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

' Each level deliberately differs from the average of the preceding level.
Function Chain:TTextureData(format:Int,count:Int,width:Int=8,height:Int=8)
	Local levels:TTextureLevel[]=New TTextureLevel[count]
	Local info:TPixelFormatInfo=GetPixelFormatInfo(format)
	For Local index:Int=0 Until count
		Local pitch:Int=width*info.bytesPerPixel+3
		Local bytes:Byte[]=New Byte[pitch*height]
		Local values:Float[4]
		Local halves:Short[4]
		values[index Mod 3]=2
		values[3]=0.5
		halves[index Mod 3]=$4000
		halves[3]=$3800
		For Local y:Int=0 Until height
			For Local x:Int=0 Until width
				Local offset:Int=y*pitch+x*info.bytesPerPixel
				Select format
					Case PF_A8
						bytes[offset]=255 Shr index
					Case PF_RGBA8888
						bytes[offset+index Mod 3]=128
						bytes[offset+3]=128
					Case PF_RGBA16F
						MemCopy(Varptr bytes[offset],halves,8)
					Case PF_RGBA32F
						MemCopy(Varptr bytes[offset],values,16)
				End Select
			Next
		Next
		levels[index]=TTextureLevel.Create(width,height,format,bytes,pitch)
		width=Max(1,width/2)
		height=Max(1,height/2)
	Next
	Return TTextureData.Create(levels)
End Function

Function ExpectLevel(image:TImage,output:TRenderImage,format:Int,level:Int,scale:Float,frame:Int=0)
	SetScale(scale,scale)
	SetColor(255,255,255)
	If format=PF_RGBA16F Or format=PF_RGBA32F Then SetColor(64,64,64)
	SetBlend(ALPHABLEND)
	Cls()
	DrawImage(image,0,0,frame)
	Local pixel:Int=ReadRenderImage(output).ReadPixel(0,0)
	For Local channel:Int=0 Until 3
		Local expected:Int
		If format=PF_A8 Then
			expected=255 Shr level
		Else If channel=level Mod 3 Then
			expected=64
		End If
		Local actual:Int=(pixel Shr (16-channel*8)) & 255
		Check(Abs(actual-expected)<=2,"Level "+level+" format "+format+" channel "+channel+": "+actual+" expected "+expected)
	Next
End Function

Try
	Graphics(80,60,0,0)
	Local output:TRenderImage=CreateRenderImage(16,16,0)
	SetRenderImage(output)
	SetClsColor(0,0,0)
	Local retained:TImage
	Local retainedFormat:Int
	Local supported:Int
	For Local format:Int=EachIn [PF_RGBA8888,PF_A8,PF_RGBA16F,PF_RGBA32F]
		Local data:TTextureData=Chain(format,4)
		Local support:ETextureFormatSupport=Max2DTextureDataSupport(data)
		Check(Max2DTextureDataSupport(data,DYNAMICIMAGE)=ETextureFormatSupport.Unsupported,"Dynamic chain rejected")
		Check(Max2DTextureDataSupport(data,$40000000)=ETextureFormatSupport.Unsupported,"Unknown flags rejected")
		Local image:TImage=LoadImage(data,0)
		Check(image.flags & MIPMAPPEDIMAGE,"Multiple levels enable mip sampling")
		If support=ETextureFormatSupport.Unsupported Then
			Local rejected:Int
			Try
				image.Frame()
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Backend rejects unsupported chain")
			Continue
		End If
		supported:+1
		retained=image
		retainedFormat=format
		ResetMax2DStats()
		For Local level:Int=0 Until 4
			ExpectLevel(image,output,format,level,1.0/Float(1 Shl level))
		Next
		Check(CaptureMax2DStats().mipmapGenerations=0,"Supplied levels are never generated")
		Check(CaptureMax2DStats().uploadedPixels=85,"Upload statistics include all mip pixels")
		' Mutating the caller's bytes cannot change the image or its recovery copy.
		For Local level:Int=0 Until 4
			MemClear(data.Level(level).Data(),Size_T(data.Level(level).ByteSize()))
		Next
		ExpectLevel(image,output,format,3,0.125)
		Local animation:TImage=LoadAnimImage(Chain(format,4),4,8,0,2,FILTEREDIMAGE)
		Check(animation.sources[0]=animation.sources[1],"Supplied animation preserves the sheet's chain")
		ExpectLevel(animation,output,format,1,0.5)
		ExpectLevel(animation,output,format,1,0.5,1)
		Local partial:TImage=LoadImage(Chain(format,2),FILTEREDIMAGE)
		ExpectLevel(partial,output,format,1,0.125)
		If format=PF_RGBA8888 Then
			SetScale(1.0/Sqr(2.0),1.0/Sqr(2.0))
			Cls()
			DrawImage(partial,0,0)
			Local interpolated:Int=ReadRenderImage(output).ReadPixel(0,0)
			Check(Abs(((interpolated Shr 16)&255)-32)<=3 And Abs(((interpolated Shr 8)&255)-32)<=3,"Filtered sampling interpolates adjacent mip levels")
			ExpectLevel(image,output,format,0,0.8)
		End If
		Local rectangular:TImage=LoadImage(Chain(format,3,7,3),0)
		ExpectLevel(rectangular,output,format,2,0.25)
?max2d_d3d11 And d3d11_recovery_test
		D3D11TestRemoved=True
		For Local level:Int=0 Until 4
			ExpectLevel(image,output,format,level,1.0/Float(1 Shl level))
		Next
		If format=PF_A8 Then
			D3D11TestCoverageFallback=True
			D3D11TestRemoved=True
			ExpectLevel(image,output,format,2,0.25)
			Check(image.Frame().pixelFormat=PF_RGBA8888,"Supplied coverage restores through RGBA fallback")
			Check(Max2DTextureDataSupport(Chain(format,2))=ETextureFormatSupport.Converted,"Supplied coverage fallback query")
			D3D11TestCoverageFallback=False
			D3D11TestRemoved=True
			ExpectLevel(image,output,format,2,0.25)
		End If
?
		Print "Supplied mip format "+format+" passed"
	Next
	Check(Max2DTextureDataSupport(Null)=ETextureFormatSupport.Unsupported,"Null data rejected")
?max2d_sdlgpu
	Check(supported>=3,"SDL GPU test device supports RGBA, coverage and floating-point chains")
?max2d_gl Or max2d_d3d11
	Check(supported=4,"Test device supports all four formats")
?
	EndGraphics()
	If retained Then
		Graphics(80,60,0,0)
		output=CreateRenderImage(16,16,0)
		SetRenderImage(output)
		ExpectLevel(retained,output,retainedFormat,2,0.25)
		EndGraphics()
	End If
	Print "Max2D supplied mipmap tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
