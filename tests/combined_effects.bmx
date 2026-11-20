SuperStrict
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Import Max2D.SDL3GPUEffects
?
Import BRL.StandardIO
Import "data/combined/testcombined_assets.c"
Import "data/coordinates/testcoordinates_assets.c"
Include "data/combined/testcombined.bmx"
Include "data/coordinates/testcoordinates.bmx"

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Near(actual:Float,expected:Float,message:String)
	If Abs(actual-expected)>0.0005 Then Throw message+": "+actual+" expected "+expected
End Function
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
SetGraphicsDriver(SDLRenderMax2DDriver(),0)
?
Try
	Local combined:TMax2DShaderEffect=CreateShaderEffect(CreateTestCombinedPackage())
	Local coordinates:TMax2DShaderEffect=CreateShaderEffect(CreateTestCoordinatesPackage())
	Local colour:TMax2DShaderEffect=CreateColorMatrixEffect()
	Local graded:TMax2DShaderEffect=CreateGradedDistortionEffect(0)
	For Local lifetime:Int=0 Until 2
		Graphics(64,64)
		If Not Max2DSupportsImageEffect(combined) Then
?max2d_sdlgpu Or max2d_gl Or max2d_d3d9 Or max2d_d3d11
			Throw "Native combined effect unsupported"
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
			Check(Not Max2DSupportsImageEffect(graded),"Software rejects graded distortion")
			Local rejected:Int
			Try
				DrawImageEffect(CreateImage(3,1),combined,0,0)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Unsupported combined draw rejected")
			EndGraphics
			Exit
?
		End If
		Check(Max2DSupportsImageEffect(graded),"Six-slot combined shader supported")
		Local pixels:Float[]=[Float(9),9,9,1, 2,0.5,0,0.5, 0,1,4,0.25, 1,0,2,0.75, 9,9,9,1]
		Local bytes:Byte[]=New Byte[pixels.Length*4]
		MemCopy(bytes,pixels,Size_T(bytes.Length))
		For Local filtered:Int=0 Until 2
			Local flags:Int
			If filtered Then flags=FILTEREDIMAGE
			Local image:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(5,1,PF_RGBA32F,bytes)]),flags)
			Local layer:TRenderImage=CreateRenderImage(5,1,flags,PF_RGBA32F)
			SetRenderImage(layer); SetBlend(SOLIDBLEND); SetColor(255,255,255); SetAlpha(1)
			DrawImage(image,0,0)
			Local output:TRenderImage=CreateRenderImage(6,1,0,PF_RGBA32F)
			Local scratch:TRenderImage=CreateRenderImage(3,1,0,PF_RGBA32F)
			For Local compact:Int=0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				For Local kind:Int=0 Until 2
					Local input:TImage=CreateImageView(image,1,0,3,1)
					If kind Then input=CreateImageView(layer,1,0,3,1)
					combined.SetFloat4("offset",Float(1.0/3),0,0,0)
					coordinates.SetFloat4("offset",Float(1.0/3),0,0,0)
					combined.SetFloat("gain",1.5); combined.SetFloat4("bias",0.1,-0.2,0.3,0.1)
					colour.SetFloat4("row0",1.5,0,0,0); colour.SetFloat4("row1",0,1.5,0,0); colour.SetFloat4("row2",0,0,1.5,0)
					colour.SetFloat4("bias",0.1,-0.2,0.3,0.1)
					For Local edge:Int=0 Until 3
						combined.SetEdgeMode(edge); coordinates.SetEdgeMode(edge)
						SetRenderImage(output); SetColor(128,200,255); SetAlpha(0.8)
						DrawImageEffect(input,combined,0,0)
						' The reference chain applies drawing tint once, before grading.
						SetRenderImage(scratch)
						DrawImageEffect(input,coordinates,0,0)
						SetRenderImage(output); SetColor(255,255,255); SetAlpha(1)
						DrawImageEffect(scratch,colour,3,0)
						Local read:TTextureData=ReadRenderTextureData(output)
						Local p:Float Ptr=Float Ptr(read.Level().Data())
						For Local i:Int=0 Until 12
							Near(p[i],p[i+12],"Single pass matches explicit two-pass chain")
						Next
						Near(p[0],0.1,"Grade follows shifted source")
						Near(p[1],Float(1.5*200/255-0.2),"Drawing tint precedes colour body")
						Near(p[2],6.3,"HDR survives combined effect")
						Near(p[3],0.3,"Straight alpha reaches colour body")
						If edge=MAX2D_EDGE_TRANSPARENT Then
							Near(p[8],0.1,"Colour bias applies to outside samples")
							Near(p[11],0.1,"Colour body may create outside alpha")
						End If
					Next
					' Snapshot colour and coordinates together, including reserved edge slots.
					combined.SetFloat("gain",1); combined.SetFloat4("bias",0,0,0,0)
					combined.SetFloat4("offset",0,0,0,0)
					DrawImageEffect(input,combined,0,0)
					combined.SetFloat("gain",2); combined.SetFloat4("offset",Float(1.0/3),0,0,0)
					DrawImageEffect(input,combined,3,0)
					combined.SetFloat("gain",0); combined.SetFloat4("offset",0,0,0,0)
					Local read:TTextureData=ReadRenderTextureData(output)
					Local p:Float Ptr=Float Ptr(read.Level().Data())
					Near(p[0],2,"Queued colour snapshot")
					Near(p[14],8,"Queued coordinate/colour snapshot")
					' Full six-slot package leaves its bounds and edge controls intact.
					graded.SetEdgeMode(MAX2D_EDGE_REPEAT)
					graded.SetFloat4("grade",0,2,1,0)
					graded.SetFloat4("gradeTint",1,0.5,0.25,0.5)
					DrawImageEffect(input,graded,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Local luminance:Float=Float((2*0.2126+0.5*0.7152)*2)
					Near(p[0],luminance,"Graded distortion saturation/exposure")
					Near(p[1],luminance*0.5,"Graded distortion tint")
					Near(p[3],0.25,"Graded distortion alpha")
				Next
			Next
			Local input:TImage=CreateImageView(image,1,0,3,1)
			combined.SetFloat("gain",1); combined.SetFloat4("offset",0,0,0,0); combined.SetFloat4("bias",0,0,0,0)
			Local positions:Float[]=[Float(0),0,3,0]
			DrawImageEffectBatch(input,combined,positions)
			ResetMax2DStats()
			DrawImageEffectBatch(input,combined,positions)
			Local stats:TMax2DStats=CaptureMax2DStats()
			Check(stats.submissions=1 And stats.textureCreations=0 And stats.textureUpdates=0 And stats.readbacks=0,"Combined batch uses one submission without intermediates")
			SetClsColor(0,0,0,0); Cls
			SetBlend(MASKBLEND)
			combined.SetFloat4("bias",0,0,0,-0.2)
			DrawImageEffect(input,combined,0,0)
			Local read:TTextureData=ReadRenderTextureData(output)
			Local p:Float Ptr=Float Ptr(read.Level().Data())
			Near(p[3],0,"Mask discard follows colour alpha")
			Near(p[11],0.55,"Mask accepts graded alpha above threshold")
			SetBlend(SOLIDBLEND)
			combined.SetFloat4("bias",0,0,0,2)
			DrawImageEffect(input,combined,0,0)
			read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
			Near(p[3],1,"Alpha clamps after colour body")
			DrawImage(input,0,0)
			read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
			Near(p[3],0.5,"No ambient combined effect remains")
		Next
		EndGraphics
	Next
	Print "combined_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
