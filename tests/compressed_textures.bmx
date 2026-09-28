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
Function Chain:TTextureData(format:Int,count:Int,width:Int=8,height:Int=8,alpha:Int=255)
	Local levels:TTextureLevel[]=New TTextureLevel[count]
	Local info:TPixelFormatInfo=GetPixelFormatInfo(format)
	For Local index:Int=0 Until count
		Local pitch:Int=Int(info.RowPitch(width))+5
		Local rows:Int=Int(info.StorageRows(height))
		Local bytes:Byte[]=New Byte[pitch*rows]
		For Local row:Int=0 Until rows
			For Local col:Int=0 Until (width+3)/4
				Local offset:Int=row*pitch+col*info.bytesPerBlock
				If format=PF_BC3_RGBA Then
					bytes[offset]=alpha
					offset:+8
				End If
				Local colour:Int=$f800
				If index Mod 3=1 Then colour=$07e0
				If index Mod 3=2 Then colour=$001f
				bytes[offset]=colour & 255
				bytes[offset+1]=colour Shr 8
				If format=PF_BC1_RGBA And alpha=0 Then
					bytes[offset]=0
					bytes[offset+1]=0
					bytes[offset+2]=255
					bytes[offset+3]=255
					For Local i:Int=4 Until 8
						bytes[offset+i]=255
					Next
				End If
			Next
		Next
		levels[index]=TTextureLevel.Create(width,height,format,bytes,pitch)
		width=Max(1,width/2)
		height=Max(1,height/2)
	Next
	Return TTextureData.Create(levels)
End Function
Function Expect(image:TImage,output:TRenderImage,level:Int,scale:Float,brightness:Int=255,sampleY:Int=0)
	SetScale(scale,scale)
	Cls()
	DrawImage(image,0,0)
	Local pixel:Int=ReadRenderImage(output).ReadPixel(0,sampleY)
	For Local channel:Int=0 Until 3
		Local expected:Int
		If channel=level Mod 3 Then expected=brightness
		Check(Abs(((pixel Shr (16-channel*8)) & 255)-expected)<=1,"Compressed sample level "+level+" pixel "+pixel)
	Next
End Function
Try
	Graphics(80,60,0,0)
	Local output:TRenderImage=CreateRenderImage(16,16,0)
	SetRenderImage(output)
	SetBlend(ALPHABLEND)
	SetClsColor(0,0,0)
	Local supported:Int
	Local retained:TImage
	For Local format:Int=EachIn [PF_BC1_RGBA,PF_BC3_RGBA]
?max2d_sdlgpu
		Check(Max2DTextureDataSupport(Chain(format,1,7,5))=ETextureFormatSupport.Unsupported,"SDL GPU block-aligned base dimensions checked")
?
		Local data:TTextureData=Chain(format,4)
		Check(Max2DTextureFormatSupport(format,MIPMAPPEDIMAGE)=ETextureFormatSupport.Unsupported,"No implicit compressed mip generation")
		Check(Max2DTextureDataSupport(data,DYNAMICIMAGE)=ETextureFormatSupport.Unsupported,"Compressed dynamic images rejected")
		Local image:TImage=LoadImage(data,0)
		If Max2DTextureDataSupport(data)=ETextureFormatSupport.Unsupported Then
			Local rejected:Int
			Try
				image.Frame()
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Unsupported compressed allocation rejected")
			Continue
		End If
		supported:+1
		retained=image
		ResetMax2DStats()
		For Local level:Int=0 Until 4
			Expect(image,output,level,1.0/Float(1 Shl level))
		Next
		Check(image.Frame().pixelFormat=format,"Native compression retained")
		Check(CaptureMax2DStats().mipmapGenerations=0,"Compressed levels never generated")
		Expect(image,output,0,1,255,7)
		Local partial:TImage=LoadImage(Chain(format,2),FILTEREDIMAGE)
		Expect(partial,output,1,0.125)
		Local single:TImage=LoadImage(Chain(format,1),FILTEREDIMAGE)
		Expect(single,output,0,0.125)
		Local rectangular:TImage=LoadImage(Chain(format,4,8,12),0)
		Expect(rectangular,output,2,0.25)
		Local transparent:TImage
		If format=PF_BC1_RGBA Then
			transparent=LoadImage(Chain(format,1,4,4,0),0)
			Expect(transparent,output,0,1,0)
		Else
			transparent=LoadImage(Chain(format,1,4,4,128),0)
			Expect(transparent,output,0,1,128)
		End If
		Local animation:TImage=LoadAnimImage(Chain(format,1),4,8,0,2,FILTEREDIMAGE)
		Expect(animation,output,0,1)
		MemClear(data.Level(2).Data(),Size_T(data.Level(2).ByteSize()))
?max2d_d3d11 And d3d11_recovery_test
		Check(Max2DTextureDataSupport(Chain(format,1,7,5))=ETextureFormatSupport.Unsupported,"D3D block-aligned base dimensions checked")
		D3D11TestRemoved=True
		For Local level:Int=0 Until 4
			Expect(image,output,level,1.0/Float(1 Shl level))
		Next
		Expect(single,output,0,1)
?
		Print "Compressed format "+format+" passed"
	Next
?max2d_gl Or max2d_d3d11 Or max2d_sdlgpu
	Check(supported=2,"Test device supports BC1 and BC3")
?
	EndGraphics()
	If retained Then
		Graphics(80,60,0,0)
		output=CreateRenderImage(16,16,0)
		SetRenderImage(output)
		SetBlend(ALPHABLEND)
		Expect(retained,output,2,0.25)
		EndGraphics()
	End If
	Print "Max2D compressed texture tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
