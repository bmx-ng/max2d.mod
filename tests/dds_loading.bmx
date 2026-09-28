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
Import Image.DDS
Import Image.PNG
Import BRL.StandardIO
Import BRL.FileSystem
Import "dds_fixture.bmx"

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Type TDDSFixtureFactory Extends TStreamFactory
	Method CreateStream:TStream(url:Object,proto:String,path:String,readable:Int,writeMode:Int) Override
		If proto="ddsfixture" And readable Then Return DDSTestStream(DDSTestBytes())
	End Method
End Type

Try
	New TDDSFixtureFactory
	Local fromURL:TImage=LoadImage("ddsfixture::asset",0)
	Check(fromURL And fromURL.sources[0].textureData.LevelCount()=4,"Registered stream URL")
	Local fromStream:TImage=LoadImage(DDSTestStream(DDSTestBytes(PF_BC3_RGBA,2,True)),FILTEREDIMAGE)
	Check(fromStream.sources[0].textureData.Format()=PF_BC3_RGBA,"DX10 stream loading")
	Local animation:TImage=LoadAnimImage(DDSTestStream(DDSTestBytes()),4,8,0,2,FILTEREDIMAGE)
	Check(animation.sources[0]=animation.sources[1] And animation.sources[0].textureData.LevelCount()=4,"Animation preserves mip chain")
	' Use a non-DDS extension to verify signature-based probing.
	Local path:String="dds-loading-test.bin"
	Local stream:TStream=WriteStream(path)
	Local bytes:Byte[]=DDSTestBytes()
	stream.WriteBytes(bytes,bytes.Length)
	stream.Close()
	Local fromFile:TImage=LoadImage(path,0)
	DeleteFile(path)
	Check(fromFile And fromFile.sources[0].textureData.Format()=PF_BC1_RGBA,"Filename loading")
	Local png:TBankStream=CreateBankStream(Null)
	Local pixels:TPixmap=CreatePixmap(2,2,PF_RGBA8888)
	pixels.ClearPixels($ff123456)
	SavePixmapPNG(pixels,png)
	png.Seek(0)
	Local fallback:TImage=LoadImage(png,0)
	Check(fallback And fallback.sources[0].pixmap.ReadPixel(0,0)=$ff123456,"PNG fallback after texture probe")
	png.Seek(0)
	Check(png.ReadByte()=137,"Caller-owned stream remains open")
	DDSTestPut(bytes,84,$34545844)
	Local rejected:Int
	Try
		LoadImage(DDSTestStream(bytes),0)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Recognised unsupported DDS does not silently fall back")
	Graphics(80,60,0,0)
	Local data:TTextureData=fromFile.sources[0].textureData
	If Max2DTextureDataSupport(data)=ETextureFormatSupport.Unsupported Then
		rejected=False
		Try
			fromFile.Frame()
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Unsupported renderer rejects decoded container")
	Else
		Local output:TRenderImage=CreateRenderImage(16,16,0)
		SetRenderImage(output)
		SetBlend(SOLIDBLEND)
		For Local level:Int=0 Until 3
			SetScale(1.0/Float(1 Shl level),1.0/Float(1 Shl level))
			Cls()
			DrawImage(fromFile,0,0)
			Local expected:Int=$ff0000 Shr (level*8)
			Check((ReadRenderImage(output).ReadPixel(0,0) & $ffffff)=expected,"DDS supplied mip rendered "+level)
		Next
	End If
	EndGraphics()
	Print "Max2D DDS loading tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
