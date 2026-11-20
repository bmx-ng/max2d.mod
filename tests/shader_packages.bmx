SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_sdlgpu And Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?Not max2d_gl
Import Max2D.SDL3GPUEffects
?
Import BRL.StandardIO
Import "data/shaderpackage/testgain_assets.c"
Include "data/shaderpackage/testgain.bmx"
Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function
?max2d_gl
Function GLPackage:TMax2DShaderEffect(source:String)
	Local bytes:Byte[] = New Byte[source.Length]
	For Local i:Int=0 Until source.Length
		bytes[i]=source[i]
	Next
	Return CreateShaderEffect(TMax2DShaderPackage.Create("same name",["unused"],[MAX2D_PARAMETER_FLOAT],Null,Null,Null,1,bytes))
End Function
?
?Not max2d_sdlgpu And Not max2d_gl
SetGraphicsDriver(SDLRenderMax2DDriver(),0)
?
Try
	Local package:TMax2DShaderPackage = CreateTestGainPackage()
	Local custom:TMax2DShaderEffect = CreateShaderEffect(package)
	custom.SetFloat("gain",1)
	For Local invalid:Int = 0 Until 7
		Local rejected:Int
		Try
			Select invalid
				Case 0
					custom.SetFloat("bias",1)
				Case 1
					custom.SetFloat4("gain",1,2,3,4)
				Case 2
					custom.SetFloat("missing",1)
				Case 3
					TMax2DShaderPackage.Create("bad",["x"],[MAX2D_PARAMETER_FLOAT],Null,[Byte(1),2,3,4],Null)
				Case 4
					TMax2DShaderPackage.Create("bad",["x","x"],[1,1],Null,Null,Null)
				Case 5
					TMax2DShaderPackage.Create("bad",["x"],[99],Null,Null,Null)
				Case 6
					TMax2DShaderPackage.Create("bad",["x"],[1],[Byte(32)],Null,Null,99)
			End Select
		Catch error:Object
			rejected = True
		End Try
		Check(rejected,"invalid schema/parameter/container rejected")
	Next
	Local matrix:TMax2DShaderEffect = CreateColorMatrixEffect()
	matrix.SetFloat4("row0",1.5,0.2,0,0)
	matrix.SetFloat4("row1",0,0.5,0.3,0)
	matrix.SetFloat4("row2",-0.2,0,1,0)
	matrix.SetFloat4("row3",0,0,0,0.5)
	matrix.SetFloat4("bias",0.1,-0.1,0.2,0.1)
	Local pixels:Float[] = [Float(0.2),0.4,0.8,1, 2,1,0.5,0.5, 0,0,0,0]
	Local bytes:Byte[] = New Byte[pixels.Length*4]
	MemCopy(bytes,pixels,Size_T(bytes.Length))
	For Local lifetime:Int = 0 Until 2
		Graphics(64,64)
?max2d_gl
		Check(Max2DSupportsImageEffect(matrix),"OpenGL colour packages supported")
?
		If Not Max2DSupportsImageEffect(matrix) Then
			Check(Not Max2DSupportsImageEffect(custom),"unregistered context rejects packages")
			Local image:TImage = CreateImage(3,1)
			Local rejected:Int
			Try
				DrawImageEffect(image,custom,0,0)
			Catch error:Object
				rejected = True
			End Try
			Check(rejected,"unsupported package draw rejected")
			EndGraphics
			Print "shader packages unsupported"
			Exit
		End If
?max2d_gl
		Local missing:TMax2DShaderEffect=CreateShaderEffect(TMax2DShaderPackage.Create("legacy",["gain","bias"],[1,4],CreateTestGainPackageData(CreateTestGainPackageAsset(0),CreateTestGainPackageSize(0)),Null,Null))
		Local invalidGL:TMax2DShaderEffect=GLPackage("not valid GLSL")
		Local unsupported:TMax2DShaderEffect[]=[missing,invalidGL]
		For Local effect:TMax2DShaderEffect=EachIn unsupported
			Check(Not Max2DSupportsImageEffect(effect),"unsupported ABI, missing asset or compiler failure rejected")
		Next
?
		Local image:TImage = LoadImage(TTextureData.Create([TTextureLevel.Create(3,1,PF_RGBA32F,bytes)]),0)
		Local source:TRenderImage = CreateRenderImage(3,1,0,PF_RGBA32F)
		Local output:TRenderImage = CreateRenderImage(6,1,0,PF_RGBA32F)
		SetRenderImage(source)
		SetBlend(SOLIDBLEND)
		DrawImage(image,0,0)
		For Local compact:Int = 0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			For Local kind:Int = 0 Until 2
				Local input:TImage = image
				If kind Then input = source
				SetRenderImage(output)
				SetColor(128,255,255)
				SetAlpha(0.8)
				DrawImageEffect(input,matrix,0,0)
				Local read:TTextureData = ReadRenderTextureData(output)
				Local p:Float Ptr = Float Ptr(read.Level().Data())
				For Local i:Int = 0 Until 3
					Local r:Float = pixels[i*4]*128/255, g:Float = pixels[i*4+1], b:Float = pixels[i*4+2], a:Float = pixels[i*4+3]*0.8
					Check(Abs(p[i*4]-(1.5*r+0.2*g+0.1)) < 0.0001,"matrix red and bias")
					Check(Abs(p[i*4+1]-(0.5*g+0.3*b-0.1)) < 0.0001,"matrix green and HDR range")
					Check(Abs(p[i*4+2]-(-0.2*r+b+0.2)) < 0.0001,"matrix blue")
					Check(Abs(p[i*4+3]-(a*0.5+0.1)) < 0.0001,"matrix alpha after tint")
				Next
			Next
			SetColor(255,255,255); SetAlpha(1)
			custom.SetFloat("gain",1)
			custom.SetFloat4("bias",0,0,0,0)
			DrawImageEffect(image,custom,0,0)
			custom.SetFloat("gain",0.5)
			DrawImageEffect(image,custom,3,0)
			custom.SetFloat("gain",0)
			Local read:TTextureData = ReadRenderTextureData(output)
			Local p:Float Ptr = Float Ptr(read.Level().Data())
			Check(Abs(p[0]-0.2)<0.0001 And Abs(p[12]-0.1)<0.0001,"queued parameter snapshots")
			custom.SetFloat("gain",1)
			Local positions:Float[] = [Float(0),0,3,0]
			DrawImageEffectBatch(image,custom,positions)
			ResetMax2DStats()
			DrawImageEffectBatch(image,custom,positions)
			Local stats:TMax2DStats = CaptureMax2DStats()
			Check(stats.submissions=1 And stats.textureCreations=0 And stats.textureUpdates=0 And stats.readbacks=0,"warmed packaged batch")
			Local rejected:Int
			Try
				DrawImageEffect(image,custom,0,0,99)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"invalid frame rejected")
			DrawImage(image,0,0)
			read=ReadRenderTextureData(output)
			p=Float Ptr(read.Level().Data())
			Check(Abs(p[0]-0.2)<0.0001,"ordinary draw after error has no effect")
		Next
?max2d_gl
		SetRenderImage(output)
		Local red:TMax2DShaderEffect=GLPackage("#version 120~nvoid main(){gl_FragColor=vec4(1,0,0,1);}")
		Local green:TMax2DShaderEffect=GLPackage("#version 120~nvoid main(){gl_FragColor=vec4(0,1,0,1);}")
		DrawImageEffect(image,red,0,0)
		DrawImageEffect(image,green,3,0)
		Local identities:TTextureData=ReadRenderTextureData(output)
		Local identityPixels:Float Ptr=Float Ptr(identities.Level().Data())
		Check(Abs(identityPixels[0]-1)<0.0001 And Abs(identityPixels[1])<0.0001 And Abs(identityPixels[12])<0.0001 And Abs(identityPixels[13]-1)<0.0001,"same-name packages keep independent shaders: "+identityPixels[0]+", "+identityPixels[1]+", "+identityPixels[12]+", "+identityPixels[13])
		For Local effect:TMax2DShaderEffect=EachIn unsupported
			Local rejected:Int
			Try
				DrawImageEffect(image,effect,0,0)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"unsupported package draw throws")
		Next
		identities=ReadRenderTextureData(output)
		identityPixels=Float Ptr(identities.Level().Data())
		Check(Abs(identityPixels[0]-1)<0.0001 And Abs(identityPixels[13]-1)<0.0001,"rejected package draws leave target unchanged")
?
		' Force the retained large-uniform arena to grow while draws are queued.
		Local wide:TRenderImage = CreateRenderImage(300,1,0,PF_RGBA32F)
		SetRenderImage(wide)
		For Local i:Int = 0 Until 100
			matrix.SetFloat4("bias",Float(i)/100,0,0,0)
			DrawImageEffect(image,matrix,i*3,0)
		Next
		Local snapshots:TTextureData = ReadRenderTextureData(wide)
		Local values:Float Ptr = Float Ptr(snapshots.Level().Data())
		For Local i:Int = 0 Until 100
			Check(Abs(values[i*12]-(0.38+Float(i)/100))<0.0001,"uniform arena preserves snapshots after growth")
		Next
		matrix.SetFloat4("bias",0.1,-0.1,0.2,0.1)

		EndGraphics
	Next
	Print "shader_packages passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
