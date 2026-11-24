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
Import "data/coordinates/testcoordinates_assets.c"
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
?max2d_sdlgpu Or max2d_gl Or max2d_d3d9 Or max2d_d3d11
			Throw "Native coordinate effect unsupported"
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
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
		' Render-image regions use the same top-down coordinates as ordinary images.
		Local gridLayer:TRenderImage=CreateRenderImage(4,4)
		SetRenderImage(gridLayer); DrawImage(gridImage,0,0)
		SetRenderImage(square)
		DrawImageEffect(CreateImageView(gridLayer,1,1,2,2),effect,0,0)
		result=ReadRenderImage(square)
		Check(result.ReadPixel(0,0)=$ffffff00 And result.ReadPixel(1,0)=$ff0000ff And result.ReadPixel(0,1)=$ff00ff00 And result.ReadPixel(1,1)=$ffff0000,"Render-image region wraps with correct vertical orientation")
		region.SetTrim(0,0,0,2,2)
		rejected=False
		Try
			DrawImageEffect(region,effect,0,0)
		Catch error:Object
			rejected=True
		End Try
		Check(Not rejected,"Trim metadata with full pixel extent is supported")
?max2d_gl
		' Coordinate packages implement their own interpolation at mip zero.
		Local mipSource:TRenderImage=CreateRenderImage(32,32,MIPMAPPEDIMAGE|FILTEREDIMAGE)
		SetRenderImage(mipSource); SetClsColor(0,0,0,1); Cls
		SetColor(255,255,255); DrawRect(14,14,4,4)
		SetRenderImage(square); SetScale(1.0/32,1.0/32)
		effect.SetFloat4("offset",0,0,0,0)
		DrawImageEffect(mipSource,effect,0,0)
		Local baseLevel:Int,maxLevel:Int,minFilter:Int,magFilter:Int
		glGetTexParameteriv(GL_TEXTURE_2D,GL_TEXTURE_BASE_LEVEL,Varptr baseLevel)
		glGetTexParameteriv(GL_TEXTURE_2D,GL_TEXTURE_MAX_LEVEL,Varptr maxLevel)
		glGetTexParameteriv(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,Varptr minFilter)
		glGetTexParameteriv(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,Varptr magFilter)
		Check(baseLevel=0 And maxLevel>0 And minFilter=GL_LINEAR_MIPMAP_LINEAR And magFilter=GL_LINEAR,"Coordinate draw restores mip range and filters")
		DrawImage(mipSource,1,0); SetScale(1,1)
		result=ReadRenderImage(square)
		Check((result.ReadPixel(0,0)&255)>250 And (result.ReadPixel(1,0)&255)<6,"Coordinate uses mip zero; ordinary draw resumes mip sampling")
		Local coverage:TPixmap=CreatePixmap(2,2,PF_A8)
		coverage.pixels[0]=64; coverage.pixels[1]=128
		coverage.pixels[coverage.pitch]=192; coverage.pixels[coverage.pitch+1]=255
		Local mask:TImage=LoadImage(coverage,0)
		effect.SetFloat4("offset",0.5,0.5,0,0)
		DrawImageEffect(mask,effect,0,0)
		result=ReadRenderImage(square)
		Check((result.ReadPixel(0,0)&$ffffff)=$ffffff And ((result.ReadPixel(0,0) Shr 24)&255)=255,"Coordinate coverage samples white RGB and shifted alpha")
		Check(Abs(((result.ReadPixel(1,1) Shr 24)&255)-64)<=1,"Coverage wraps both axes")
?
        ' Trimmed source and auxiliary frames retain logical transparent margins.
        SetRenderImage(Null);ResetCoordinates();SetScale(1,1);SetRotation(0)
        SetColor(255,255,255);SetAlpha(1);SetBlend(SOLIDBLEND)
        Local trimPixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
        trimPixels.ClearPixels(0)
        For Local y:Int=2 Until 6
            For Local x:Int=2 Until 6
                trimPixels.WritePixel(x,y,$80904020)
            Next
        Next
        For Local filtering:Int=0 Until 2
            Local atlasFlags:Int
            If filtering Then atlasFlags=FILTEREDIMAGE
            Local trimAtlas:TTextureAtlas=TTextureAtlas.Create(64,atlasFlags)
            Local trimmed:TImage=trimAtlas.AddPixmap(trimPixels,"trim",True)
            Local full:TImage=LoadImage(trimPixels,atlasFlags)
            trimmed.handle_x=1;trimmed.handle_y=2
            full.handle_x=1;full.handle_y=2
            Local trimmedOutput:TRenderImage=CreateRenderImage(16,8)
            For Local edge:Int=0 Until 3
                effect.SetFloat4("offset",0.25,0.125,0,0);effect.SetEdgeMode(edge)
                SetRenderImage(trimmedOutput);Cls
                DrawImageEffect(full,effect,1,2)
                DrawImageEffect(trimmed,effect,9,2)
                Local comparison:TPixmap=ReadRenderImage(trimmedOutput)
                For Local y:Int=0 Until 8
                    For Local x:Int=0 Until 8
                        Check(comparison.ReadPixel(x,y)=comparison.ReadPixel(x+8,y),"Trimmed coordinate margins and edge sampling")
                    Next
                Next
            Next
            Local maskEffect:TMax2DShaderEffect=CreateTextureMaskEffect(full)
            SetRenderImage(trimmedOutput);Cls
            DrawImageEffect(full,maskEffect,1,2)
            maskEffect.SetTexture(trimmed)
            DrawImageEffect(full,maskEffect,9,2)
            Local masked:TPixmap=ReadRenderImage(trimmedOutput)
            For Local y:Int=0 Until 8
                For Local x:Int=0 Until 8
                    Check(masked.ReadPixel(x,y)=masked.ReadPixel(x+8,y),"Trimmed auxiliary mask preserves logical margins")
                Next
            Next
            Local index:Int=0
            Local retained:TImage=trimmed.SamplingImage(index)
            index=0
            Check(retained=trimmed.SamplingImage(index),"Warm sampling reuses storage")
            trimPixels.WritePixel(3,3,$ff20a050)
            trimmed.ReplacePixels(trimPixels)
            index=0
            Check(retained=trimmed.SamplingImage(index),"Pixel edits reuse storage")
            Local updated:TPixmap=retained.Lock(0,True,False)
            Check(updated.ReadPixel(3,3)=$ff20a050,"Pixel edits refresh expanded storage")
            retained.Unlock()
            SetRenderImage(trimmedOutput)
            DrawImageEffect(trimmed,effect,1,2)
            TMax2DGraphics.Current().context.Flush()
            ResetMax2DStats()
            DrawImageEffect(trimmed,effect,1,2)
            TMax2DGraphics.Current().context.Flush()
            Local warm:TMax2DStats=CaptureMax2DStats()
            Check(warm.textureCreations=0 And warm.textureUpdates=0 And warm.readbacks=0,"Warm trimmed draw reuses uploaded pixels")
            Local emptyPixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
            emptyPixels.ClearPixels(0)
            Local empty:TImage=trimAtlas.AddPixmap(emptyPixels,"empty",True)
            empty.handle_x=trimmed.handle_x;empty.handle_y=trimmed.handle_y
            Local animation:TImage=TImage.Animation([trimmed,empty],[100,100])
            index=1
            Local emptySampling:TImage=animation.SamplingImage(index)
            Check(index=0,"Expanded animation frame selects frame zero")
            Local emptyRead:TPixmap=emptySampling.Lock(0,True,False)
            Check(emptyRead.ReadPixel(3,3)=0,"Empty trimmed frame retains transparent canvas")
            emptySampling.Unlock()
            index=0
            Check(animation.SamplingImage(index)<>emptySampling,"Animation frames have independent retained storage")

        Next

		EndGraphics
	Next
	Print "coordinate_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
