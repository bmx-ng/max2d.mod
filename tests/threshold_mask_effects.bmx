SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.SDL3GPUEffects
Import BRL.StandardIO

Function Near(actual:Float,expected:Float,message:String)
	If Abs(actual-expected)>0.0005 Then Throw message+": "+actual+" expected "+expected
End Function
Function FloatImage:TImage(pixels:Float[],flags:Int=0)
	Local bytes:Byte[]=New Byte[pixels.Length*4]
	MemCopy(bytes,pixels,Size_T(bytes.Length))
	Return LoadImage(TTextureData.Create([TTextureLevel.Create(pixels.Length/4,1,PF_RGBA32F,bytes)]),flags)
End Function
?Not max2d_sdlgpu
SetGraphicsDriver(SDLRenderMax2DDriver(),0)
?
Try
	Local mask:TMax2DShaderEffect=CreateThresholdMaskEffect(Null,0.25,0.75)
	For Local lifetime:Int=0 Until 2
		Graphics(64,64)
		If Not Max2DSupportsImageEffect(mask) Then
?max2d_sdlgpu
			Throw "Native threshold mask unsupported"
?Not max2d_sdlgpu
			Local rejected:Int
			Try
				DrawImageEffect(CreateImage(4,1),mask,0,0)
			Catch error:Object
				rejected=True
			End Try
			If Not rejected Then Throw "Software must reject threshold masks"
			EndGraphics
			Exit
?
		End If
		Local input:TImage=FloatImage([Float(4),1,0.5,0.5, 4,1,0.5,0.5, 4,1,0.5,0.5, 4,1,0.5,0.5])
		Local map:TImage=FloatImage([Float(9),9,9,1, 0.25,0,0,0.25, 0.375,0,0,0.375, 0.5,0,0,0.5, 0.75,0,0,0.75, 9,9,9,1])
		Local mapLayer:TRenderImage=CreateRenderImage(6,1,0,PF_RGBA32F)
		SetRenderImage(mapLayer); SetBlend(SOLIDBLEND); DrawImage(map,0,0)
		Local output:TRenderImage=CreateRenderImage(8,1,0,PF_RGBA32F)
		SetRenderImage(output)
		For Local kind:Int=0 Until 2
			Local view:TImage=CreateImageView(map,1,0,4,1)
			If kind Then view=CreateImageView(mapLayer,1,0,4,1)
			mask.SetTexture(view)
			For Local compact:Int=0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				mask.SetFloat4("range",0.25,0.75,0,0); mask.SetFloat4("channels",0,0,0,1); mask.SetFloat("invert",0)
				DrawImageEffect(input,mask,0,0)
				mask.SetFloat("invert",1); DrawImageEffect(input,mask,4,0)
				Local read:TTextureData=ReadRenderTextureData(output)
				Local p:Float Ptr=Float Ptr(read.Level().Data())
				Local expected:Float[]=[Float(0),0.078125,0.25,0.5]
				For Local i:Int=0 Until 4
					Near(p[i*4+3],expected[i],"Smooth threshold alpha")
					Near(p[(i+4)*4+3],0.5-expected[i],"Queued inversion")
				Next
				Near(p[4],4,"HDR source preserved")
				mask.SetFloat("invert",0); mask.SetFloat4("channels",1,0,0,0)
				For Local reversed:Int=0 Until 2
					mask.SetFloat4("range",0.5,0.5-Float(reversed)*0.25,0,0)
					DrawImageEffect(input,mask,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Near(p[7],0,"Hard threshold below boundary")
					Near(p[11],0.5,"Hard threshold includes equality")
				Next
				mask.SetFloat4("range",0.25,0.75,0,0)
				SetColor(128,255,255); SetAlpha(0.5)
				DrawImageEffect(input,mask,0,0)
				read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
				Near(p[4],Float(4*128.0/255),"Tint applied once")
				Near(p[7],0.0390625,"Drawing alpha applied once")
				SetColor(255,255,255); SetAlpha(1)
			Next
		Next
		' Filtering happens before thresholding: the middle sample is 0.5.
		mask.SetTexture(FloatImage([Float(0),0,0,1, 1,0,0,1],FILTEREDIMAGE))
		mask.SetFloat4("range",0.4,0.6,0,0)
		mask.SetTextureTransform(0.125)
		DrawImageEffect(input,mask,0,0)
		Local read:TTextureData=ReadRenderTextureData(output)
		Local p:Float Ptr=Float Ptr(read.Level().Data())
		Near(p[11],0.25,"Filtered transformed map threshold")
		mask.SetTextureTransform()
		For Local endpoint:Int=0 Until 2
			Local low:Float=Float(endpoint)*1.2-0.2
			mask.SetFloat4("range",low,low+0.2,0,0)
			DrawImageEffect(input,mask,0,0)
			read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
			For Local i:Int=0 Until 4
				Near(p[i*4+3],0.5*(1-endpoint),"Complete reveal endpoints")
			Next
		Next
		DrawImage(input,0,0)
		read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
		Near(p[3],0.5,"Ordinary draw restored")
		EndGraphics
	Next
	Print "threshold_mask_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
