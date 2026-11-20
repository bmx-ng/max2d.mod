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

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Near(actual:Float,expected:Float,message:String)
	If Abs(actual-expected)>0.0005 Then Throw message+": "+actual+" expected "+expected
End Function
Function FloatImage:TImage(pixels:Float[],flags:Int)
	Local bytes:Byte[]=New Byte[pixels.Length*4]
	MemCopy(bytes,pixels,Size_T(bytes.Length))
	Return LoadImage(TTextureData.Create([TTextureLevel.Create(pixels.Length/4,1,PF_RGBA32F,bytes)]),flags)
End Function
?Not max2d_sdlgpu And Not max2d_gl
SetGraphicsDriver(SDLRenderMax2DDriver(),0)
?
Try
	Local displacement:TMax2DShaderEffect=CreateDisplacementEffect(Null,Float(1.0/3),0)
	Local dissolve:TMax2DShaderEffect=CreateDissolveEffect(Null)
	For Local lifetime:Int=0 Until 2
		Graphics(64,64)
		If Not Max2DSupportsImageEffect(displacement) Then
?max2d_sdlgpu Or max2d_gl
			Throw "Native two-texture shader unsupported"
?Not max2d_sdlgpu And Not max2d_gl
			Check(Not Max2DSupportsImageEffect(dissolve),"Software rejects dissolve")
			Local rejected:Int
			Try
				DrawImageEffect(CreateImage(3,1),displacement,0,0)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Unsupported two-texture draw rejected")
			EndGraphics
			Exit
?
		End If
		Check(Max2DSupportsImageEffect(dissolve),"Dissolve supported")
		For Local filtered:Int=0 Until 2
			Local flags:Int
			If filtered Then flags=FILTEREDIMAGE
			Local source:TImage=FloatImage([Float(9),9,9,1, 2,0,0,0.5, 4,0,0,0.5, 8,0,0,0.5, 9,9,9,1],flags)
			Local input:TImage=CreateImageView(source,1,0,3,1)
			Local map:TImage=FloatImage([Float(9),9,9,1, 0.5,0.5,0,0.25, 1,0.5,0,0.25, 0,0.5,0,0.25, 9,9,9,1],flags)
			Local neutral:TImage=FloatImage([Float(0.5),0.5,0,1, 0.5,0.5,0,1, 0.5,0.5,0,1],flags)
			Local layer:TRenderImage=CreateRenderImage(5,1,flags,PF_RGBA32F)
			SetRenderImage(layer); SetBlend(SOLIDBLEND); SetColor(255,255,255); SetAlpha(1)
			DrawImage(map,0,0)
			Local output:TRenderImage=CreateRenderImage(6,1,0,PF_RGBA32F)
			SetRenderImage(output)
			For Local compact:Int=0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				For Local kind:Int=0 Until 2
					Local view:TImage=CreateImageView(map,1,0,3,1)
					If kind Then view=CreateImageView(layer,1,0,3,1)
					displacement.SetTexture(view)
					DrawImageEffect(input,displacement,0,0)
					displacement.SetTexture(neutral)
					DrawImageEffect(input,displacement,3,0)
					displacement.SetTexture(Null)
					Local read:TTextureData=ReadRenderTextureData(output)
					Local p:Float Ptr=Float Ptr(read.Level().Data())
					Near(p[0],2,"Neutral red leaves first sample")
					Near(p[4],8,"Positive displacement preserves HDR")
					Near(p[8],4,"Negative displacement")
					Near(p[3],0.5,"Map alpha does not tint source")
					Near(p[16],4,"Queued texture binding snapshot")
					dissolve.SetTexture(view); dissolve.SetFloat("progress",0.75)
					dissolve.SetFloat("width",0.5); dissolve.SetFloat4("edge",2,0,0,1)
					DrawImageEffect(input,dissolve,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Near(p[3],0,"Dissolve removes lower map values")
					Near(p[4],5,"HDR edge glow")
					Near(p[7],0.5,"Glow preserves source alpha")
					Near(p[11],0,"Dissolve low endpoint")
					dissolve.SetFloat("progress",0)
					DrawImageEffect(input,dissolve,0,0)
					dissolve.SetFloat("progress",1)
					DrawImageEffect(input,dissolve,3,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Near(p[0],2,"Zero progress is identity")
					Near(p[11],0.5,"Zero map value visible at zero progress")
					Near(p[19],0,"One progress hides maximum map value")
				Next
			Next
			' Different map resolution exercises interpolation between bounded texels.
			Local smallMap:TImage=FloatImage([Float(9),9,9,1, 0,0.5,0,1, 1,0.5,0,1, 9,9,9,1],flags)
			displacement.SetTexture(CreateImageView(smallMap,1,0,2,1))
			For Local edge:Int=0 Until 3
				displacement.SetEdgeMode(edge)
				DrawImageEffect(input,displacement,0,0)
				Local read:TTextureData=ReadRenderTextureData(output)
				Local p:Float Ptr=Float Ptr(read.Level().Data())
				If edge=MAX2D_EDGE_TRANSPARENT Then
					Near(p[3],0,"Displacement transparent left edge")
					Near(p[11],0,"Displacement transparent right edge")
				Else If edge=MAX2D_EDGE_CLAMP Then
					Near(p[0],2,"Displacement clamps within source view")
					Near(p[8],8,"Displacement excludes source neighbour")
				Else
					Near(p[0],8,"Displacement wraps left")
					Near(p[8],2,"Displacement wraps right")
				End If
				If filtered Then Near(p[4],4,"Map bilinear interpolation") Else Near(p[4],8,"Map nearest sampling")
			Next
			displacement.SetEdgeMode(MAX2D_EDGE_TRANSPARENT)
			' Retained arena growth must preserve both parameters and texture bindings.
			For Local i:Int=0 Until 300
				If i Mod 2 Then displacement.SetTexture(neutral) Else displacement.SetTexture(CreateImageView(map,1,0,3,1))
				DrawImageEffect(input,displacement,0,0)
			Next
			Local grown:TTextureData=ReadRenderTextureData(output)
			Near(Float Ptr(grown.Level().Data())[4],4,"Texture snapshots survive arena growth")
			displacement.SetTexture(neutral)
			Local positions:Float[]=[Float(0),0,3,0]
			DrawImageEffectBatch(input,displacement,positions)
			ResetMax2DStats()
			DrawImageEffectBatch(input,displacement,positions)
			Local stats:TMax2DStats=CaptureMax2DStats()
			Check(stats.submissions=1 And stats.textureCreations=0 And stats.textureUpdates=0 And stats.readbacks=0,"Two-texture batch uses one submission without intermediates")
			Local rejected:Int
			displacement.SetTexture(Null)
			Try
				DrawImageEffect(input,displacement,0,0)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Missing texture rejected")
			rejected=False; displacement.SetTexture(output)
			Try
				DrawImageEffect(input,displacement,0,0)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Render feedback rejected")
			DrawImage(input,0,0)
			Local read:TTextureData=ReadRenderTextureData(output)
			Local p:Float Ptr=Float Ptr(read.Level().Data())
			Near(p[0],2,"Ordinary drawing recovers after rejection")
		Next
		EndGraphics
	Next
	Print "two_texture_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
