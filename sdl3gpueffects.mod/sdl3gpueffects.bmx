SuperStrict

Rem
bbdoc: Optional native SDL GPU shader provider for Max2D image effects.
End Rem
Module Max2D.SDL3GPUEffects
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
ModuleInfo "CC_OPTS: -I%PWD%/../../sdl3.mod/sdl3.mod/SDL3/include"

Import Max2D.Effects
Import Max2D.SDL3GPUMax2D
Import "glue.c"

Private

Type TSDLGPUImageEffectBackend Extends TMax2DImageEffectBackend

	Method Handles:Int(context:TMax2DContext, effect:TMax2DImageEffect) Override
		Return TSDLGPUMax2DContext(context) <> Null And (TMax2DSaturationEffect(effect) <> Null Or TMax2DBlurEffect(effect) <> Null Or TMax2DColorizeEffect(effect) <> Null)
	End Method

	Method Supports:Int(canvas:TMax2DGraphics, effect:TMax2DImageEffect) Override
		Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(canvas.context)
		Local shader:Byte Ptr = GetEffectShader(context, effect)
		If Not shader Then Return False
		Return m2d_gpu_image_effect_support(context.native, shader, context.NativeFrame(context.target), canvas.state.blend, context.compactQuads)
	End Method

	Method Draw(canvas:TMax2DGraphics, image:TImage, effect:TMax2DImageEffect, x:Float, y:Float, frame:Int) Override
		DrawMany(canvas, image, effect, Null, x, y, frame)
	End Method

	Method DrawBatch(canvas:TMax2DGraphics, image:TImage, effect:TMax2DImageEffect, positions:Float[], frame:Int) Override
		DrawMany(canvas, image, effect, positions, 0, 0, frame)
	End Method

	Private

	Method GetEffectShader:Byte Ptr(context:TSDLGPUMax2DContext, effect:TMax2DImageEffect)
		If TMax2DColorizeEffect(effect) Then Return m2d_colorize_shader(context.native, context.GetGPUDevice())
		If TMax2DBlurEffect(effect) Then Return m2d_blur_shader(context.native, context.GetGPUDevice())
		Return m2d_saturation_shader(context.native, context.GetGPUDevice())
	End Method

	Method DrawMany(canvas:TMax2DGraphics, image:TImage, effect:TMax2DImageEffect, positions:Float[], x:Float, y:Float, frame:Int)
		If TMax2DBlurEffect(effect) And Not TRenderImage(image) Then Throw "Max2D Effects: blur requires a premultiplied render-image source"
		Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(canvas.context)
		Local shader:Byte Ptr = GetEffectShader(context, effect)
		If Not shader Then Throw "Max2D Effects: shader creation failed: " + SDL_GetError()
		context.Flush()
		Local saturation:TMax2DSaturationEffect = TMax2DSaturationEffect(effect)
		If saturation Then
			m2d_gpu_select_image_effect(context.native, shader, saturation.GetAmount(), 0, 0, 0)
		Else If TMax2DColorizeEffect(effect) Then
			Local red:Int, green:Int, blue:Int
			TMax2DColorizeEffect(effect).GetColor(red, green, blue)
			m2d_gpu_select_image_effect(context.native, shader, red / 255.0, green / 255.0, blue / 255.0, 0)
		Else
			Local blur:TMax2DBlurEffect = TMax2DBlurEffect(effect)
			Local dx:Float, dy:Float
			If blur.IsHorizontal() Then
				dx = blur.GetRadius() / (4 * image.width)
			Else
				dy = blur.GetRadius() / (4 * image.height)
			End If
			m2d_gpu_select_image_effect(context.native, shader, dx, dy, 0, 0)
		End If
		Try
			If positions Then
				For Local i:Int = 0 Until positions.Length Step 2
					canvas.DrawImage(image, positions[i], positions[i + 1], frame)
				Next
			Else
				canvas.DrawImage(image, x, y, frame)
			End If
			context.Flush()
		Catch error:Object
			' A failed submission must not leak effect geometry into an ordinary batch.
			context.batchCount = 0
			context.batchFrame = Null
			Throw error
		Finally
			m2d_gpu_select_image_effect(context.native, Null, 0, 0, 0, 0)
		End Try
	End Method

End Type

Extern "C"
	Function m2d_colorize_shader:Byte Ptr(context:Byte Ptr, device:Byte Ptr)
	Function m2d_blur_shader:Byte Ptr(context:Byte Ptr, device:Byte Ptr)
	Function m2d_saturation_shader:Byte Ptr(context:Byte Ptr, device:Byte Ptr)
	Function m2d_gpu_image_effect_support:Int(context:Byte Ptr, effect:Byte Ptr, target:Byte Ptr, blend:Int, compact:Int)
	Function m2d_gpu_select_image_effect(context:Byte Ptr, effect:Byte Ptr, p0:Float, p1:Float, p2:Float, p3:Float)
End Extern

RegisterMax2DImageEffectBackend(New TSDLGPUImageEffectBackend)
