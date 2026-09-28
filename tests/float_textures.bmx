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
Function Near:Int(pixel:Int,r:Int,g:Int,b:Int)
	Return Abs(((pixel Shr 16)&255)-r)<=1 And Abs(((pixel Shr 8)&255)-g)<=1 And Abs((pixel&255)-b)<=1
End Function
Try
	Graphics(80,60,0,0)
	Local target:TRenderImage=CreateRenderImage(8,8,0)
	SetRenderImage(target)
	Local supported:Int
	For Local format:Int=PF_RGBA16F To PF_RGBA32F
		Local info:TPixelFormatInfo=GetPixelFormatInfo(format)
		Check(info.floatingPoint And info.bytesPerPixel=(format-PF_RGBA16F+1)*8,"Float metadata")
		Local pitch:Int=info.bytesPerPixel*2+3
		Local bytes:Byte[]=New Byte[pitch*2]
		Local values:Float[4]
		Local halves:Short[4]
		For Local row:Int=0 Until 2
			values[0]=2
			values[1]=0.5
			values[2]=0.25
			values[3]=1
			halves[0]=$4000
			halves[1]=$3800
			halves[2]=$3400
			halves[3]=$3c00
			If row Then
				values[0]=-1
				values[1]=0.25
				values[2]=2
				halves[0]=$bc00
				halves[1]=$3400
				halves[2]=$4000
			End If
			For Local x:Int=0 Until 2
				If format=PF_RGBA16F Then
					MemCopy(Varptr bytes[row*pitch+x*info.bytesPerPixel],halves,8)
				Else
					MemCopy(Varptr bytes[row*pitch+x*info.bytesPerPixel],values,16)
				End If
			Next
		Next
		Local data:TTextureData=TTextureData.Create([TTextureLevel.Create(2,2,format,bytes,pitch)])
		Local rejected:Int
		Try
			data.ToPixmap()
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"No implicit float-to-pixmap quantisation")
		Check(Max2DTextureFormatSupport(format,MIPMAPPEDIMAGE)=ETextureFormatSupport.Unsupported,"Float mipmaps rejected")
		Local image:TImage=LoadImage(data,FILTEREDIMAGE)
		If Max2DTextureFormatSupport(format,FILTEREDIMAGE)=ETextureFormatSupport.Unsupported Then
			rejected=False
			Try
				image.Frame()
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Unsupported backend rejects float allocation")
			Continue
		End If
		supported:+1
		SetColor(64,128,255)
		SetBlend(SOLIDBLEND)
		Cls()
		DrawImage(image,0,0)
		Local pixels:TPixmap=ReadRenderImage(target)
		Check(Near(pixels.ReadPixel(0,0),128,64,64),"Values above one survive upload and are scaled in the shader")
		Check(Near(pixels.ReadPixel(0,1),0,32,255),"Negative values and padded rows survive upload")
		Check(image.Frame().pixelFormat=format,"Native precision retained")
?max2d_d3d11 And d3d11_recovery_test
		D3D11TestRemoved=True
		Cls()
		DrawImage(image,0,0)
		Check(Near(ReadRenderImage(target).ReadPixel(0,0),128,64,64),"Float texture restored after device replacement")
?
		Print "Float format "+format+" passed"
	Next
?max2d_gl Or max2d_d3d11 Or max2d_sdlgpu
	Check(supported>0,"Test device supports a floating-point format")
?
	EndGraphics()
	Print "Max2D floating-point texture tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
