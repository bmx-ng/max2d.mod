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
Import "data/legacytexturemask/legacytexturemask_assets.c"
Include "data/legacytexturemask/legacytexturemask.bmx"
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Near(actual:Float,expected:Float,message:String)
	If Abs(actual-expected)>0.0005 Then Throw message+": "+actual+" expected "+expected
End Function
Function FloatImage:TImage(pixels:Float[],width:Int,flags:Int)
	Local bytes:Byte[]=New Byte[pixels.Length*4]
	MemCopy(bytes,pixels,Size_T(bytes.Length))
	Return LoadImage(TTextureData.Create([TTextureLevel.Create(width,pixels.Length/4/width,PF_RGBA32F,bytes)]),flags)
End Function
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
SetGraphicsDriver(SDLRenderMax2DDriver(),0)
?
Try
	Local mask:TMax2DShaderEffect=CreateTextureMaskEffect(Null)
	Local legacy:TMax2DShaderEffect=CreateShaderEffect(CreateLegacyTextureMaskPackage())
	legacy.SetFloat4("channels",0,0,0,1)
	Local rejected:Int
	Try
		legacy.SetTextureTransform()
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"ABI 3 rejects unsupported transforms")
	For Local lifetime:Int=0 Until 2
		Graphics(64,64)
		If Not Max2DSupportsImageEffect(mask) Then
?max2d_sdlgpu Or max2d_gl Or max2d_d3d9 Or max2d_d3d11
			Throw "Transformed masks unsupported"
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
			EndGraphics
			Exit
?
		End If
		Check(Max2DSupportsImageEffect(legacy),"Original ABI 3 shader still supported")
		For Local filtered:Int=0 Until 2
			Local flags:Int
			If filtered Then flags=FILTEREDIMAGE
			Local input:TImage=FloatImage([Float(4),1,0,0.5,4,1,0,0.5,4,1,0,0.5,4,1,0,0.5],2,flags)
			Local pixels:Float[]=New Float[64]
			For Local i:Int=0 Until 16
				pixels[i*4]=1; pixels[i*4+1]=1; pixels[i*4+2]=1; pixels[i*4+3]=1
			Next
			pixels[23]=0.125; pixels[27]=0.375; pixels[39]=0.625; pixels[43]=0.875
			Local map:TImage=FloatImage(pixels,4,flags)
			Local layer:TRenderImage=CreateRenderImage(4,4,flags,PF_RGBA32F)
			SetRenderImage(layer); SetColor(255,255,255); SetAlpha(1); SetBlend(SOLIDBLEND)
			DrawImage(map,0,0)
			Local output:TRenderImage=CreateRenderImage(4,2,0,PF_RGBA32F)
			SetRenderImage(output)
			For Local compact:Int=0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				For Local kind:Int=0 Until 2
					Local view:TImage=CreateImageView(map,1,1,2,2)
					If kind Then view=CreateImageView(layer,1,1,2,2)
					mask.SetTexture(view); legacy.SetTexture(view)
					mask.SetTextureTransform(); mask.SetTextureEdgeMode(MAX2D_EDGE_TRANSPARENT)
					DrawImageEffect(input,mask,0,0); DrawImageEffect(input,legacy,2,0)
					Local read:TTextureData=ReadRenderTextureData(output)
					Local p:Float Ptr=Float Ptr(read.Level().Data())
					For Local row:Int=0 Until 2
						For Local i:Int=0 Until 8
							Near(p[row*16+i],p[row*16+i+8],"ABI 4 identity matches ABI 3")
						Next
					Next
					mask.SetTextureTransform(0,0,1,1,90)
					DrawImageEffect(input,mask,0,0)
					mask.SetTextureTransform(0,0,-1,1)
					DrawImageEffect(input,mask,2,0)
					mask.SetTextureTransform()
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Near(p[3],0.3125,"Clockwise rotation samples bottom-left")
					Near(p[7],0.0625,"Clockwise rotation samples top-left")
					Near(p[11],0.1875,"Negative scale mirrors map")
					Near(p[0],4,"Transformed mask preserves HDR")
					For Local edge:Int=0 Until 3
						mask.SetTextureEdgeMode(edge); mask.SetTextureTransform(0.5,0)
						DrawImageEffect(input,mask,0,0)
						read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
						If edge=0 Then Near(p[3],0,"Transparent transformed map")
						If edge=1 Then Near(p[3],0.0625,"Transformed map clamp excludes atlas border")
						If edge=2 Then Near(p[3],0.1875,"Transformed map repeat wraps negative UV")
						Near(p[7],0.0625,"Positive offset moves map right")
					Next
					mask.SetTextureTransform(0.25,0)
					DrawImageEffect(input,mask,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					If filtered Then Near(p[3],0.125,"Filtered transformed repeat seam") Else Near(p[3],0.0625,"Nearest transformed seam")
					mask.SetTextureTransform(0,0,2,2)
					DrawImageEffect(input,mask,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					If filtered Then Near(p[3],0.15625,"Scale interpolates both axes") Else Near(p[3],0.0625,"Scale nearest sample")
					' Invalid updates leave the prior transform intact.
					rejected=False
					Try
						mask.SetTextureTransform(0,0,0,1)
					Catch error:Object
						rejected=True
					End Try
					Check(rejected,"Zero scale rejected")
					Local bits:Int[]=[Int($7fc00000),Int($7f800000)]
					For Local bad:Int=0 Until 3
						rejected=False
						Try
							If bad<2 Then mask.SetTextureTransform(Float Ptr(bits)[bad],0) Else mask.SetTextureTransform(0,0,Float(1.0e-40),1)
						Catch error:Object
							rejected=True
						End Try
						Check(rejected,"Non-finite or overflowing transform rejected")
					Next
					DrawImageEffect(input,mask,2,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Near(p[3],p[11],"Rejected transform is atomic")
				Next
			Next
			mask.SetTextureTransform()
			Local positions:Float[]=[Float(0),0,2,0]
			DrawImageEffectBatch(input,mask,positions)
			ResetMax2DStats(); DrawImageEffectBatch(input,mask,positions)
			Local stats:TMax2DStats=CaptureMax2DStats()
			Check(stats.submissions=1 And stats.textureCreations=0 And stats.textureUpdates=0 And stats.readbacks=0,"Transformed masks batch without intermediates")
		Next
		EndGraphics
	Next
	Print "texture_transforms passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
