SuperStrict

Rem
bbdoc: Optional Direct3D 9 provider for colour, blur, outline, bloom and tone-mapping image effects.
about: Shaders are embedded and owned by each graphics context. Applications do not require D3DCompiler.
End Rem
Module Max2D.D3D9Effects
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.ShaderEffects
Import Max2D.D3D9Max2D
?win32
Import "effect_shaders.cpp"

Private

Type TD3D9ImageEffectBackend Extends TMax2DImageEffectBackend
	Method Handles:Int(context:TMax2DContext,effect:TMax2DImageEffect) Override
		Return TD3D9Max2DContext(context)<>Null And (TMax2DShaderEffect(effect)<>Null Or TMax2DSaturationEffect(effect)<>Null Or TMax2DColorizeEffect(effect)<>Null Or TMax2DBlurEffect(effect)<>Null Or TMax2DOutlineEffect(effect)<>Null Or TMax2DBrightPassEffect(effect)<>Null Or TMax2DToneMapEffect(effect)<>Null Or TMax2DLinearOutputEffect(effect)<>Null)
	End Method

	Method Supports:Int(canvas:TMax2DGraphics,effect:TMax2DImageEffect) Override
		Local context:TD3D9Max2DContext=TD3D9Max2DContext(canvas.context)
		Return GetShader(context,effect)<>Null And context.SupportsBlend(canvas.state.blend)
	End Method

	Method Draw(canvas:TMax2DGraphics,image:TImage,effect:TMax2DImageEffect,x:Float,y:Float,frame:Int) Override
		DrawMany(canvas,image,effect,Null,x,y,frame)
	End Method

	Method DrawBatch(canvas:TMax2DGraphics,image:TImage,effect:TMax2DImageEffect,positions:Float[],frame:Int) Override
		DrawMany(canvas,image,effect,positions,0,0,frame)
	End Method

	Private
	Method GetShader:Byte Ptr(context:TD3D9Max2DContext,effect:TMax2DImageEffect)
		context.CheckOpen()
		context.Activate()
		If TMax2DShaderEffect(effect) Then Return TMax2DShaderEffect(effect).NativeShader(context)
		Local kind:Int
		If TMax2DColorizeEffect(effect) Then kind=1
		If TMax2DBlurEffect(effect) Then kind=2
		If TMax2DOutlineEffect(effect) Then kind=3
		If TMax2DBrightPassEffect(effect) Then kind=4
		If TMax2DToneMapEffect(effect) Then kind=5
		If TMax2DLinearOutputEffect(effect) Then kind=6
		Local size:Size_T
		Local code:Byte Ptr=m2d9_builtin_effect(kind,size)
		Return m2d9_create_image_effect(context.native,code,size)
	End Method

	Method DrawMany(canvas:TMax2DGraphics,image:TImage,effect:TMax2DImageEffect,positions:Float[],x:Float,y:Float,frame:Int)
		If TMax2DShaderEffect(effect) Then
			TMax2DShaderEffect(effect).DrawNative(canvas,image,positions,x,y,frame)
			Return
		End If
		If TMax2DOutlineEffect(effect) And Not TRenderImage(image) Then Throw "Max2D Effects: outline requires a render-image source"
		If TMax2DBlurEffect(effect) And Not TRenderImage(image) Then Throw "Max2D Effects: blur requires a premultiplied render-image source"
		Local context:TD3D9Max2DContext=TD3D9Max2DContext(canvas.context)
		context.Flush()
		Local shader:Byte Ptr=GetShader(context,effect)
		context.Require(shader<>Null)
		Local saturation:TMax2DSaturationEffect=TMax2DSaturationEffect(effect)
		If saturation Then
			m2d9_select_image_effect(context.native,shader,saturation.GetAmount(),0,0,0)
		Else If TMax2DBrightPassEffect(effect) Then
			m2d9_select_image_effect(context.native,shader,TMax2DBrightPassEffect(effect).GetThreshold(),0,0,0)
		Else If TMax2DLinearOutputEffect(effect) Then
			Local output:TMax2DLinearOutputEffect=TMax2DLinearOutputEffect(effect)
			m2d9_select_image_effect(context.native,shader,output.GetExposure(),output.GetWhiteLevel(),output.IsHDR(),0)
		Else If TMax2DToneMapEffect(effect) Then
			Local tone:TMax2DToneMapEffect=TMax2DToneMapEffect(effect)
			m2d9_select_image_effect(context.native,shader,tone.GetExposure(),1.0/tone.GetGamma(),0,0)
		Else If TMax2DOutlineEffect(effect) Then
			m2d9_select_image_effect(context.native,shader,1.0/image.width,1.0/image.height,TMax2DOutlineEffect(effect).GetRadius(),0,True)
		Else If TMax2DBlurEffect(effect) Then
			Local blur:TMax2DBlurEffect=TMax2DBlurEffect(effect)
			Local dx:Float,dy:Float
			If blur.IsHorizontal() Then dx=blur.GetRadius()/(4*image.width) Else dy=blur.GetRadius()/(4*image.height)
			m2d9_select_image_effect(context.native,shader,dx,dy,0,0,True)
		Else
			Local red:Int,green:Int,blue:Int
			TMax2DColorizeEffect(effect).GetColor(red,green,blue)
			m2d9_select_image_effect(context.native,shader,red/255.0,green/255.0,blue/255.0,0)
		End If
		Try
			If positions Then
				For Local i:Int=0 Until positions.Length Step 2
					canvas.DrawImage(image,positions[i],positions[i+1],frame)
				Next
			Else
				canvas.DrawImage(image,x,y,frame)
			End If
			context.Flush()
		Catch error:Object
			context.batchCount=0
			context.batchFrame=Null
			Throw error
		Finally
			m2d9_select_image_effect(context.native,Null,0,0,0,0)
		End Try
	End Method
End Type

Extern "C"
	Function m2d9_builtin_effect:Byte Ptr(kind:Int,size:Size_T Var)
	Function m2d9_create_image_effect:Byte Ptr(context:Byte Ptr,code:Byte Ptr,size:Size_T)
	Function m2d9_select_image_effect(context:Byte Ptr,shader:Byte Ptr,x:Float,y:Float,z:Float,w:Float,baseLevelOnly:Int=False)
End Extern

RegisterMax2DImageEffectBackend(New TD3D9ImageEffectBackend)


Private
Type TD3D9ShaderPackageBackend Extends TMax2DShaderPackageBackend
 Field frames:Byte Ptr[4]
 Method MaximumTextures:Int(context:TMax2DContext) Override
  If Handles(context) Then Return 5
  Return 0
 End Method
 Method BindTextureSet(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,textures:TImageFrame[],count:Int) Override
  Local native:TD3D9Max2DContext=TD3D9Max2DContext(context)
  Try
   For Local i:Int=0 Until count
    native.Upload(TD3D9ImageFrame(textures[i]))
    frames[i]=native.NativeFrame(textures[i])
   Next
   native.Require(m2d9_select_texture_set(native.native,shader,values,frames,count))
  Finally
   For Local i:Int=0 Until count
    frames[i]=Null
   Next
  End Try
 End Method
 Method Handles:Int(context:TMax2DContext) Override
  Return TD3D9Max2DContext(context)<>Null
 End Method
 Method Shader:Byte Ptr(context:TMax2DContext,package:Byte Ptr) Override
  Local nativeContext:TD3D9Max2DContext=TD3D9Max2DContext(context)
  context.CheckOpen()
  context.Activate()

  Return m2d9_package_shader(nativeContext.native,package)
 End Method
 Method SelectShader(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame) Override
  SelectTextures(context,shader,values,second,Null)
 End Method
 Method SelectTextures(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame,third:TImageFrame) Override
  Local nativeContext:TD3D9Max2DContext=TD3D9Max2DContext(context)
  If third And third=context.target Then Throw "Max2D package: cannot sample destination as third texture"
  If second And second=context.target Then Throw "Max2D package: cannot sample the destination as second texture"
  If third Then nativeContext.Upload(TD3D9ImageFrame(third))
  If second Then nativeContext.Upload(TD3D9ImageFrame(second))
  m2d9_select_package_effect(nativeContext.native,shader,values,nativeContext.NativeFrame(second),nativeContext.NativeFrame(third))
 End Method
 Method ClearShader(context:TMax2DContext) Override
  m2d9_select_image_effect(TD3D9Max2DContext(context).native,Null,0,0,0,0)
 End Method
End Type
Extern "C"
 Function m2d9_select_texture_set:Int(context:Byte Ptr,shader:Byte Ptr,values:Float Ptr,textures:Byte Ptr Ptr,count:Int)
 Function m2d9_package_shader:Byte Ptr(context:Byte Ptr,package:Byte Ptr)
 Function m2d9_select_package_effect(context:Byte Ptr,shader:Byte Ptr,values:Float Ptr,second:Byte Ptr,third:Byte Ptr)
End Extern
RegisterShaderPackageBackend(New TD3D9ShaderPackageBackend)
?
