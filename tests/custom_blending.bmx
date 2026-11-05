SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import BRL.Retro
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Function Pixel(pixel:Int,r:Int,g:Int,b:Int,a:Int,message:String)
	Check(Abs(((pixel Shr 16)&255)-r)<=3 And Abs(((pixel Shr 8)&255)-g)<=3 And Abs((pixel&255)-b)<=3 And Abs(((pixel Shr 24)&255)-a)<=2,message+" got "+Hex(pixel))
End Function

Try
	Local alpha:Int=CreateBlendMode(BLEND_SRC_ALPHA,BLEND_ONE_MINUS_SRC_ALPHA)
	Check(alpha=CreateBlendMode(BLEND_SRC_ALPHA,BLEND_ONE_MINUS_SRC_ALPHA),"Stable description")
	Check(CreateBlendMode(BLEND_ONE,BLEND_ONE,BLEND_OP_MIN)=CreateBlendMode(BLEND_ZERO,BLEND_ZERO,BLEND_OP_MIN),"MIN ignores factors")
	Check(CreateBlendMode(BLEND_ONE,BLEND_ZERO,BLEND_OP_ADD,BLEND_SRC_COLOR)=CreateBlendMode(BLEND_ONE,BLEND_ZERO,BLEND_OP_ADD,BLEND_SRC_ALPHA),"Alpha aliases")
	Local rejected:Int
	Try
		CreateBlendMode(0,BLEND_ONE)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Invalid description rejected")
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
	If AppArgs.Length>1 Then SetSDLRenderMax2DRenderer(AppArgs[1])
?
	Graphics(64,64,0,0)
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
	Print "Renderer: "+SDLRenderMax2DRendererName()
?
	Local target:TRenderImage=CreateRenderImage(16,8,0)
	SetRenderImage(target)
	If Max2DSupportsBlend(SUBTRACTBLEND) Then
		For Local compact:Int=0 Until 2
?max2d_sdlgpu
			SetSDLGPUMax2DCompactSprites(compact)
?
			SetClsColor(200,160,120,1)
			Cls
			SetBlend(SUBTRACTBLEND)
			SetAlpha(0.5)
			Local sprite:TImage=CreateImage(4,4,1,DYNAMICIMAGE)
			Local pixels:TPixmap=LockImage(sprite)
			pixels.ClearPixels($ff645028)
			UnlockImage(sprite)
			SetColor(255,255,255)
			DrawImage(sprite,0,0)
			SetColor(100,80,40)
			Local mode:Int=CreateBlendMode(BLEND_SRC_ALPHA,BLEND_ONE,BLEND_OP_REVERSE_SUBTRACT,BLEND_ZERO,BLEND_ONE,BLEND_OP_REVERSE_SUBTRACT)
			SetBlend(mode)
			PushMax2DState()
			SetBlend(SOLIDBLEND)
			PopMax2DState()
			Check(GetBlend()=mode,"State stack retains custom blend")
			DrawRect(4,0,4,4)
			SetBlend(ALPHABLEND)
			DrawRect(8,0,4,4)
			Local p:TPixmap=ReadRenderImage(target)
			Pixel(p.ReadPixel(1,1),150,120,100,255,"Subtract")
			Pixel(p.ReadPixel(5,1),150,120,100,255,"Custom subtract")
			Pixel(p.ReadPixel(9,1),150,120,80,255,"Restore alpha equation")
		Next
	Else
		Print "SKIP subtract: unavailable"
		rejected=False
		Try
			SetBlend(SUBTRACTBLEND)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Unsupported subtract rejected")
	End If
	If Max2DSupportsBlend(alpha) Then
		SetClsColor(0,0,0,0)
		Cls
		SetBlend(alpha)
		SetColor(100,80,40)
		SetAlpha(0.5)
		DrawRect(0,0,4,4)
		Local p:TPixmap=ReadRenderImage(target)
		Pixel(p.ReadPixel(1,1),100,80,40,128,"Custom alpha on transparent target")
		' Straight image and premultiplied render image sources must agree.
		Local image:TImage=CreateImage(4,4,1,DYNAMICIMAGE)
		p=LockImage(image)
		p.ClearPixels($80645028)
		UnlockImage(image)
		Local output:TRenderImage=CreateRenderImage(16,8,0)
		SetRenderImage(output)
		SetClsColor(40,60,80,1)
		Cls
		SetColor(255,255,255)
		SetAlpha(1)
		SetBlend(alpha)
		DrawImage(image,0,0)
		DrawImage(target,4,0)
		p=ReadRenderImage(output)
		Pixel(p.ReadPixel(1,1),70,70,60,255,"Straight source")
		Pixel(p.ReadPixel(5,1),70,70,60,255,"Premultiplied source")
		SetRenderImage(target)
	End If
	' Check every factor against a CPU reference. Destination alpha remains one.
	For Local factor:Int=BLEND_ZERO To BLEND_ONE_MINUS_DST_ALPHA
		Local mode:Int=CreateBlendMode(factor,factor,BLEND_OP_ADD,BLEND_ZERO,BLEND_ONE)
		If Not Max2DSupportsBlend(mode) Then Continue
		SetClsColor(100,80,60,1)
		Cls
		SetAlpha(0.5)
		SetColor(40,100,20)
		SetBlend(mode)
		DrawRect(0,0,4,4)
		Local source:Float[]=[40.0,100.0,20.0]
		Local dest:Float[]=[100.0,80.0,60.0]
		Local expected:Int[]=New Int[3]
		For Local channel:Int=0 Until 3
			Local f:Float
			Select factor
				Case BLEND_ZERO
					f=0
				Case BLEND_ONE
					f=1
				Case BLEND_SRC_COLOR
					f=source[channel]/255
				Case BLEND_ONE_MINUS_SRC_COLOR
					f=1-source[channel]/255
				Case BLEND_SRC_ALPHA,BLEND_ONE_MINUS_SRC_ALPHA
					f=0.5
				Case BLEND_DST_COLOR
					f=dest[channel]/255
				Case BLEND_ONE_MINUS_DST_COLOR
					f=1-dest[channel]/255
				Case BLEND_DST_ALPHA
					f=1
				Case BLEND_ONE_MINUS_DST_ALPHA
					f=0
			End Select
			expected[channel]=Int(Min(255.0,(source[channel]+dest[channel])*f)+0.5)
		Next
		Pixel(ReadRenderImage(target).ReadPixel(1,1),expected[0],expected[1],expected[2],255,"Factor "+factor)
	Next
	If Max2DSupportsBlend(SUBTRACTBLEND) Then
		SetClsColor(100,80,60,0.5)
		Cls
		SetBlend(SUBTRACTBLEND)
		SetColor(20,20,20)
		SetAlpha(0.5)
		DrawRect(0,0,4,4)
		Pixel(ReadRenderImage(target).ReadPixel(1,1),80,60,40,128,"Subtract preserves translucent destination alpha")
	End If
	Local erase:Int=CreateBlendMode(BLEND_ZERO,BLEND_ONE_MINUS_SRC_ALPHA,BLEND_OP_ADD,BLEND_ZERO,BLEND_ONE_MINUS_SRC_ALPHA)
	If Max2DSupportsBlend(erase) Then
		SetClsColor(100,80,60,1)
		Cls
		SetBlend(erase)
		SetAlpha(0.5)
		DrawRect(0,0,4,4)
		Pixel(ReadRenderImage(target).ReadPixel(1,1),100,80,60,128,"Erase scales premultiplied colour and alpha together")
	End If
	For Local operation:Int=BLEND_OP_ADD To BLEND_OP_MAX
		Local mode:Int=CreateBlendMode(BLEND_ONE,BLEND_ONE,operation,BLEND_ZERO,BLEND_ONE,operation)
		If operation=BLEND_OP_SUBTRACT Then mode=CreateBlendMode(BLEND_ONE,BLEND_ONE,operation,BLEND_ONE,BLEND_ZERO)
		If Not Max2DSupportsBlend(mode) Then
			Print "SKIP operation "+operation
			Continue
		End If
		SetClsColor(100,80,60,1)
		Cls
		SetAlpha(1)
		SetColor(40,100,20)
		SetBlend(mode)
		DrawRect(0,0,4,4)
		Local p:TPixmap=ReadRenderImage(target)
		Select operation
			Case BLEND_OP_ADD
				Pixel(p.ReadPixel(1,1),140,180,80,255,"ADD")
			Case BLEND_OP_SUBTRACT
				Pixel(p.ReadPixel(1,1),0,20,0,255,"SUBTRACT")
			Case BLEND_OP_REVERSE_SUBTRACT
				Pixel(p.ReadPixel(1,1),60,0,40,255,"REVERSE SUBTRACT")
			Case BLEND_OP_MIN
				Pixel(p.ReadPixel(1,1),40,80,20,255,"MIN")
			Case BLEND_OP_MAX
				Pixel(p.ReadPixel(1,1),100,100,60,255,"MAX")
		End Select
	Next
	SetRenderImage(Null)
	EndGraphics()
	Print "Custom blending tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
