SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.SDL3GPUEffects
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
?Not max2d_sdlgpu
SetGraphicsDriver(SDLRenderMax2DDriver(),0)
?
Try
	Local mask:TMax2DShaderEffect=CreateTextureMaskEffect(Null)
	For Local lifetime:Int=0 Until 2
		Graphics(64,64)
		If Not Max2DSupportsImageEffect(mask) Then
?max2d_sdlgpu
			Throw "Native texture mask unsupported"
?Not max2d_sdlgpu
			Local rejected:Int
			Try
				DrawImageEffect(CreateImage(4,1),mask,0,0)
			Catch error:Object
				rejected=True
			End Try
			Check(rejected,"Software rejects texture masks")
			EndGraphics
			Exit
?
		End If
		For Local filtered:Int=0 Until 2
			Local flags:Int
			If filtered Then flags=FILTEREDIMAGE
			Local input:TImage=FloatImage([Float(4),0.5,1,0.5, 4,0.5,1,0.5, 4,0.5,1,0.5, 4,0.5,1,0.5],flags)
			Local map:TImage=FloatImage([Float(9),9,9,1, 1,0.5,0,0, 0.75,0.5,0,0.25, 0.25,0.5,0,0.75, 0,0.5,0,1, 9,9,9,1],flags)
			Local layer:TRenderImage=CreateRenderImage(6,1,flags,PF_RGBA32F)
			SetRenderImage(layer); SetBlend(SOLIDBLEND); SetColor(255,255,255); SetAlpha(1)
			DrawImage(map,0,0)
			Local output:TRenderImage=CreateRenderImage(8,1,0,PF_RGBA32F)
			SetRenderImage(output)
			For Local compact:Int=0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				For Local kind:Int=0 Until 2
					Local view:TImage=CreateImageView(map,1,0,4,1)
					If kind Then view=CreateImageView(layer,1,0,4,1)
					mask.SetTexture(view); mask.SetFloat4("channels",0,0,0,1); mask.SetFloat("invert",0)
					DrawImageEffect(input,mask,0,0)
					mask.SetFloat("invert",1)
					DrawImageEffect(input,mask,4,0)
					mask.SetFloat("invert",0)
					Local read:TTextureData=ReadRenderTextureData(output)
					Local p:Float Ptr=Float Ptr(read.Level().Data())
					Local alpha:Float[]=[Float(0),0.125,0.375,0.5]
					For Local i:Int=0 Until 4
						Near(p[i*4+3],alpha[i],"Alpha mask multiplies source alpha")
						Near(p[(i+4)*4+3],0.5-alpha[i],"Queued inverted mask")
					Next
					Near(p[4],4,"Partial mask preserves straight HDR")
					mask.SetFloat4("channels",1,0,0,0)
					DrawImageEffect(input,mask,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Near(p[7],0.375,"Red mask uses straight map RGB")
					Near(p[11],0.125,"Red channel independent of map alpha")
					mask.SetFloat4("channels",0.25,0,0,0.75)
					SetColor(128,255,255); SetAlpha(0.5)
					DrawImageEffect(input,mask,0,0)
					read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
					Near(p[4],Float(4*128.0/255),"Drawing tint applied once")
					Near(p[7],0.09375,"Weighted mask and drawing alpha")
					SetColor(255,255,255); SetAlpha(1)
				Next
			Next
			' R8 coverage is exposed through map alpha, including inverted masks.
			Local pixmap:TPixmap=CreatePixmap(4,1,PF_A8)
			pixmap.pixels[0]=0; pixmap.pixels[1]=64; pixmap.pixels[2]=192; pixmap.pixels[3]=255
			mask.SetTexture(TImage.FromPixmap(pixmap,flags,PF_A8))
			mask.SetFloat4("channels",0,0,0,1)
			DrawImageEffect(input,mask,0,0)
			Local read:TTextureData=ReadRenderTextureData(output)
			Local p:Float Ptr=Float Ptr(read.Level().Data())
			Near(p[7],Float(0.5*64/255),"Single-channel coverage mask")
			Near(p[11],Float(0.5*192/255),"Single-channel coverage mask high value")
			' Clamp coverage before inversion, without clamping source HDR.
			mask.SetFloat4("channels",0,0,0,4)
			mask.SetFloat("invert",1)
			DrawImageEffect(input,mask,0,0)
			read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
			Near(p[0],4,"Inverted zero coverage preserves HDR")
			Near(p[7],0,"Coverage clamp precedes inversion")
			mask.SetFloat("invert",0); mask.SetFloat4("channels",0,0,0,1)
			mask.SetTexture(CreateImageView(map,1,0,4,1))
			SetClsColor(0,0,255,1); Cls; SetBlend(ALPHABLEND)
			DrawImageEffect(input,mask,0,0)
			read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
			Near(p[4],0.5,"Mask participates in alpha compositing once")
			Near(p[6],1,"Background contributes through soft coverage")
			Near(p[7],1,"Opaque destination alpha retained")
			SetClsColor(0,0,0,0); Cls; SetBlend(MASKBLEND)
			DrawImageEffect(input,mask,0,0)
			read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
			Near(p[11],0,"Mask blend discards reduced coverage")
			Near(p[15],0.5,"Mask blend accepts threshold coverage")
			SetBlend(SOLIDBLEND)
			Local positions:Float[]=[Float(0),0,4,0]
			DrawImageEffectBatch(input,mask,positions)
			ResetMax2DStats(); DrawImageEffectBatch(input,mask,positions)
			Local stats:TMax2DStats=CaptureMax2DStats()
			Check(stats.submissions=1 And stats.textureCreations=0 And stats.textureUpdates=0 And stats.readbacks=0,"Mask batch uses one submission without intermediates")
			DrawImage(input,0,0)
			read=ReadRenderTextureData(output); p=Float Ptr(read.Level().Data())
			Near(p[3],0.5,"Mask does not leak into ordinary drawing")
		Next
		EndGraphics
	Next
	Print "texture_mask_effects passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
