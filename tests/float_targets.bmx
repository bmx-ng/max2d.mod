SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Channel:Float(data:TTextureData,x:Int,y:Int,channel:Int)
	Local value:Float
	MemCopy(Varptr value,data.Level().Data()+y*data.Level().Pitch()+x*16+channel*4,4)
	Return value
End Function
Function Near(value:Float,expected:Float,message:String)
	Check(Abs(value-expected)<0.005,message+": "+value+" expected "+expected)
End Function
Try
	Graphics(80,60,0,0)
	Local byteTarget:TRenderImage=CreateRenderImage(4,4,0)
	ClearImage(byteTarget,40,80,120,1)
	Local byteData:TTextureData=ReadRenderTextureData(byteTarget)
	Check(byteData.Format()=PF_RGBA8888 And byteData.ToPixmap().ReadPixel(0,0)=$ff285078,"Existing targets read back as RGBA8 texture data")
	Local bytes:Byte[]=New Byte[32]
	Local values:Float[]=[2.0,-0.5,0.25,0.5,0.25,2.0,-1.0,1.0]
	MemCopy(bytes,values,32)
	Local sourceData:TTextureData=TTextureData.Create([TTextureLevel.Create(1,2,PF_RGBA32F,bytes)])
	Local supported:Int
	For Local format:Int=PF_RGBA16F To PF_RGBA32F
		Check(Not Max2DSupportsRenderImage(8,8,MIPMAPPEDIMAGE,format),"Float target mipmaps rejected")
		Local target:TRenderImage=CreateRenderImage(8,8,0,format)
		If Not Max2DSupportsRenderImage(8,8,0,format) Then
			Local rejected:Int
			Try
				target.Frame()
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Unsupported target creation rejected")
			Continue
		End If
		supported:+1
		Local source:TImage=LoadImage(sourceData,0)
		SetRenderImage(target)
		Check(target.Frame().pixelFormat=format,"Requested target precision retained")
		Local data:TTextureData=ReadRenderTextureData(target)
		Check(data.Format()=PF_RGBA32F,"Float readback representation")
		Near(Channel(data,0,0,3),0,"New target is transparent")
		SetBlend(SOLIDBLEND)
		DrawImage(source,0,0)
		data=ReadRenderTextureData(target)
		Near(Channel(data,0,0,0),2,"HDR range survives target storage")
		Near(Channel(data,0,0,1),-0.5,"Negative range retained")
		Near(Channel(data,0,0,3),0.5,"Straight-alpha readback")
		Near(Channel(data,0,1,1),2,"Top-left readback row order")
		Near(Channel(data,0,1,2),-1,"Second row negative value")
		Local rejected:Int
		Try
			ReadRenderImage(target)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Pixmap readback cannot silently quantise")
		Local nextTarget:TRenderImage=CreateRenderImage(8,8,0,format)
		SetRenderImage(nextTarget)
		SetBlend(ALPHABLEND)
		DrawImage(target,0,0)
		data=ReadRenderTextureData(nextTarget)
		Near(Channel(data,0,0,0),2,"Target-to-target sampling retains range")
		Near(Channel(data,0,0,3),0.5,"Target-to-target alpha is not multiplied twice")
		' Read a different target while retaining the selected destination.
		ReadRenderTextureData(target)
		SetBlend(SOLIDBLEND)
		DrawImage(source,2,0)
		Near(Channel(ReadRenderTextureData(nextTarget),2,0,0),2,"Readback preserves active destination")
		Near(Channel(ReadRenderTextureData(target),2,0,3),0,"Readback does not change source target")
		ClearImage(nextTarget,0,0,0,1)
		SetRenderImage(nextTarget)
		SetBlend(LIGHTBLEND)
		DrawImage(source,0,0)
		DrawImage(source,0,0)
		Near(Channel(ReadRenderTextureData(nextTarget),0,0,0),2,"Additive blending retains values above one")
		Local ordinary:TRenderImage=CreateRenderImage(8,8,0)
		SetRenderImage(ordinary)
		SetBlend(SOLIDBLEND)
		SetColor(64,64,64)
		DrawImage(target,0,0)
		Local pixel:Int=ReadRenderImage(ordinary).ReadPixel(0,0)
		Check(Abs(((pixel Shr 16)&255)-128)<=1,"Float target can be scaled into an ordinary target")
		Check(ReadRenderTextureData(ordinary).Format()=PF_RGBA8888,"Ordinary readback stays RGBA8")
		SetColor(255,255,255)
?max2d_d3d11 And d3d11_recovery_test
		D3D11TestRemoved=True
		SetRenderImage(target)
		Near(Channel(ReadRenderTextureData(target),0,0,3),0,"Lost float target recreates transparent")
		Check(target.Frame().pixelFormat=format,"Recovery preserves target format")
		SetBlend(SOLIDBLEND)
		DrawImage(source,0,0)
		Near(Channel(ReadRenderTextureData(target),0,0,0),2,"Float drawing resumes after recovery")
?
		SetRenderImage(Null)
		Print "Float target format "+format+" passed"
	Next
?max2d_gl Or max2d_d3d11 Or max2d_sdlgpu
	Check(supported>0,"Test device supports a floating-point render target")
?
	EndGraphics()
	Print "Max2D floating-point render target tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
