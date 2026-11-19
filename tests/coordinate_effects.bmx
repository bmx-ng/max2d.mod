SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.SDL3GPUEffects
Import BRL.StandardIO
Import "data/coordinates/testcoordinates_assets.c"
Include "data/coordinates/testcoordinates.bmx"

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Near(actual:Float,expected:Float,message:String)
	If Abs(actual-expected)>0.0005 Then Throw message+": "+actual+" expected "+expected
End Function
?Not max2d_sdlgpu
SetGraphicsDriver(SDLRenderMax2DDriver(),0)
?
Try
	Local effect:TMax2DShaderEffect=CreateShaderEffect(CreateTestCoordinatesPackage())
	Local distortion:TMax2DShaderEffect=CreateDistortionEffect(0)
	Local rejected:Int
	Try
		effect.SetEdgeMode(99)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Invalid edge mode rejected")
	For Local lifetime:Int=0 Until 2
		Graphics(64,64)
		If Not Max2DSupportsImageEffect(effect) Then
?max2d_sdlgpu
			Throw "Native coordinate effect unsupported"
?Not max2d_sdlgpu
			rejected=False
			Try
				DrawImageEffect(CreateImage(2,2),effect,0,0)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Software draw rejects coordinate effect")
			EndGraphics
			Exit
?
		End If
		Check(Max2DSupportsImageEffect(distortion),"Distortion shader compiles")
		' Bright neighbours flank a two-pixel image region with fractional alpha.
		Local pixels:Float[]=[Float(9),9,9,1, 2,0,0,0.5, 0,0,4,0.25, 9,9,9,1]
		Local bytes:Byte[]=New Byte[pixels.Length*4]
		MemCopy(bytes,pixels,Size_T(bytes.Length))
		For Local filtered:Int=0 Until 2
			Local flags:Int
			If filtered Then flags=FILTEREDIMAGE
			Local image:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(4,1,PF_RGBA32F,bytes)]),flags)
			Local view:TImage=CreateImageView(image,1,0,2,1)
			Local layer:TRenderImage=CreateRenderImage(4,1,flags,PF_RGBA32F)
			SetRenderImage(layer); SetBlend(SOLIDBLEND); DrawImage(image,0,0)
			Local output:TRenderImage=CreateRenderImage(6,1,0,PF_RGBA32F)
			For Local compact:Int=0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				For Local kind:Int=0 Until 2
					Local input:TImage=view
					If kind Then input=CreateImageView(layer,1,0,2,1)
					SetRenderImage(output); SetColor(255,255,255); SetAlpha(1)
					effect.SetFloat4("offset",0.5,0,0,0)
					For Local edge:Int=0 Until 3
						effect.SetEdgeMode(edge)
						DrawImageEffect(input,effect,edge*2,0)
					Next
					effect.SetFloat4("offset",0,0,0,0)
					Local read:TTextureData=ReadRenderTextureData(output)
					Local p:Float Ptr=Float Ptr(read.Level().Data())
					For Local edge:Int=0 Until 3
						Near(p[edge*8+2],4,"Shifted HDR blue")
						Near(p[edge*8+3],0.25,"Shifted alpha")
					Next
					Near(p[7],0,"Transparent outside")
					Near(p[14],4,"Clamp blue"); Near(p[15],0.25,"Clamp alpha")
					Near(p[20],2,"Repeat red"); Near(p[23],0.5,"Repeat alpha")
					' Negative wrap and filtered seam must never see atlas neighbours.
					effect.SetEdgeMode(MAX2D_EDGE_REPEAT)
					effect.SetFloat4("offset",-1.25,0,0,0)
					DrawImageEffect(input,effect,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					If filtered Then
						If kind Then
							Near(p[0],Float(4.0/3),"Premultiplied seam red")
							Near(p[2],Float(4.0/3),"Premultiplied seam blue")
						Else
							Near(p[0],1,"Straight seam red")
							Near(p[2],2,"Straight seam blue")
						End If
						Near(p[3],0.375,"Filtered seam alpha")
					Else
						Near(p[0],2,"Nearest negative repeat")
					End If
					' Identity distortion preserves tint, alpha and HDR.
					SetColor(128,255,255); SetAlpha(0.8)
					DrawImageEffect(input,distortion,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Near(p[0],Float(2.0*128/255),"Identity tinted HDR")
					Near(p[3],0.4,"Identity tinted alpha")
					SetColor(255,255,255); SetAlpha(1)
				Next
			Next
			SetRenderImage(output)
			effect.SetFloat4("offset",0,0,0,0)
			Local positions:Float[]=[Float(0),0,2,0]
			DrawImageEffectBatch(view,effect,positions)
			ResetMax2DStats()
			DrawImageEffectBatch(view,effect,positions)
			Local stats:TMax2DStats=CaptureMax2DStats()
			Check(stats.submissions=1 And stats.textureCreations=0 And stats.textureUpdates=0 And stats.readbacks=0,"Warm coordinate batch")
			rejected=False
			Try
				DrawImageEffect(view,effect,0,0,99)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Bad frame rejected")
			DrawImage(view,0,0)
			Local read:TTextureData=ReadRenderTextureData(output)
			Near(Float Ptr(read.Level().Data())[0],2,"Ordinary draw restored")
		Next
		Local grid:TPixmap=CreatePixmap(4,4,PF_RGBA8888)
		grid.ClearPixels($ffffffff)
		grid.WritePixel(1,1,$ffff0000); grid.WritePixel(2,1,$ff00ff00)
		grid.WritePixel(1,2,$ff0000ff); grid.WritePixel(2,2,$ffffff00)
		Local gridImage:TImage=LoadImage(grid,0)
		Local region:TImage=CreateImageView(gridImage,1,1,2,2)
		Local square:TRenderImage=CreateRenderImage(2,2)
		SetRenderImage(square)
		effect.SetEdgeMode(MAX2D_EDGE_REPEAT); effect.SetFloat4("offset",0.5,0.5,0,0)
		DrawImageEffect(region,effect,0,0)
		Local result:TPixmap=ReadRenderImage(square)
		Check(result.ReadPixel(0,0)=$ffffff00 And result.ReadPixel(1,0)=$ff0000ff And result.ReadPixel(0,1)=$ff00ff00 And result.ReadPixel(1,1)=$ffff0000,"Both axes wrap inside offset atlas region")
		region.SetTrim(0,0,0,2,2)
		rejected=False
		Try
			DrawImageEffect(region,effect,0,0)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Trimmed storage rejected explicitly")
		EndGraphics
	Next
	Print "coordinate_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
