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
Function FloatImage:TImage(pixels:Float[],width:Int,flags:Int)
	Local bytes:Byte[]=New Byte[pixels.Length*4]
	MemCopy(bytes,pixels,Size_T(bytes.Length))
	Return LoadImage(TTextureData.Create([TTextureLevel.Create(width,pixels.Length/4/width,PF_RGBA32F,bytes)]),flags)
End Function
Function Solid:TImage(size:Int)
	Local pixels:Float[]=New Float[size*size*4]
	For Local i:Int=0 Until size*size
		pixels[i*4]=4; pixels[i*4+1]=1; pixels[i*4+3]=0.5
	Next
	Return FloatImage(pixels,size,0)
End Function
?Not max2d_sdlgpu And Not max2d_gl
SetGraphicsDriver(SDLRenderMax2DDriver(),0)
?
Try
	Local effect:TMax2DShaderEffect=CreateTextureMaskEffect(Null)
	For Local lifetime:Int=0 Until 2
		Graphics(64,64)
		If Not Max2DSupportsImageEffect(effect) Then
?max2d_sdlgpu Or max2d_gl
			Throw "Shared texture mapping unsupported"
?Not max2d_sdlgpu And Not max2d_gl
			EndGraphics
			Exit
?
		End If
		Local small:TImage=Solid(2), whole:TImage=Solid(4)
		SetImageHandle(small,1,1); SetImageHandle(whole,2,2)
		Local output:TRenderImage=CreateRenderImage(16,16,0,PF_RGBA32F)
		SetRenderImage(output); SetBlend(SOLIDBLEND); SetColor(255,255,255); SetAlpha(1)
		For Local filtered:Int=0 Until 2
			Local flags:Int
			If filtered Then flags=FILTEREDIMAGE
			Local map:TImage=FloatImage([Float(1),1,1,0.125, 1,1,1,0.375, 1,1,1,0.625, 1,1,1,0.875],2,flags)
			SetImageHandle(map,1,1); effect.SetTexture(map)
			For Local compact:Int=0 Until 2
?max2d_sdlgpu
				SetSDLGPUMax2DCompactSprites(compact)
?
				For Local style:Int=0 Until 3
					ResetCoordinates(); SetCamera(Null); SetOrigin(0,0); SetTransform()
					If style=1 Then TranslateCoordinates(10,1); RotateCoordinates(90)
					If style=2 Then
						Local camera:TCamera2D=New TCamera2D
						' Keep outer edges between pixel centres: rotated quads can differ at exact coverage boundaries.
						camera.zoom=1.5; camera.offsetX=2.5; camera.offsetY=2.5
						SetCamera(camera)
						TranslateCoordinates(1,0); SetOrigin(0,1)
					End If
					SetScale(4,4)
					Local placement:TMax2DDrawTransform=CaptureImageTransform(map,4,4)
					SetScale(2,2)
					effect.SetTextureMapping(placement,whole,4,4)
					SetClsColor(0,0,0,0); Cls
					DrawImageEffect(whole,effect,4,4)
					Local reference:TTextureData=ReadRenderTextureData(output)
					Cls
					For Local row:Int=0 Until 2
						For Local col:Int=0 Until 2
							Local x:Float=2+col*4,y:Float=2+row*4
							SetRotation((row*2+col)*90)
							If row Then SetScale(-2,2) Else SetScale(2,2)
							effect.SetTextureMapping(placement,small,x,y)
							DrawImageEffect(small,effect,x,y)
						Next
					Next
					' Mutation after submission must not change queued map coefficients.
					placement.tx:+100
					effect.SetTextureTransform()
					Local actual:TTextureData=ReadRenderTextureData(output)
					Local a:Float Ptr=Float Ptr(actual.Level().Data()),b:Float Ptr=Float Ptr(reference.Level().Data())
					For Local i:Int=0 Until 16*16*4
						Near(a[i],b[i],"Shared map matches layer filtered="+filtered+" compact="+compact+" style="+style+" component="+i)
					Next
				Next
			Next
		Next
		ResetCoordinates(); SetCamera(Null); SetOrigin(0,0); SetTransform()
		Local placement:TMax2DDrawTransform=CaptureDrawTransform()
		placement.xx=4; placement.yy=4
		effect.SetTextureMapping(placement,whole,4,4)
		SetClsColor(0,0,0,0); Cls; DrawImageEffect(whole,effect,4,4)
		Local expected:TTextureData=ReadRenderTextureData(output)
		Near(Float Ptr(expected.Level().Data())[(3*16+3)*4],4,"Atomicity reference contains visible HDR pixels")
		Local rejected:Int
		placement.xx=0; placement.xy=0
		Try
			effect.SetTextureMapping(placement,whole,4,4)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Collapsed map placement rejected")
		Cls; DrawImageEffect(whole,effect,4,4)
		Local actual:TTextureData=ReadRenderTextureData(output)
		Local a:Float Ptr=Float Ptr(actual.Level().Data()),b:Float Ptr=Float Ptr(expected.Level().Data())
		For Local i:Int=0 Until 16*16*4
			Near(a[i],b[i],"Rejected mapping preserves previous transform")
		Next
		EndGraphics
	Next
	Print "shared_texture_mapping passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
