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

Type TSDLGPUSaturationBackend Extends TMax2DImageEffectBackend

	Method Handles:Int(context:TMax2DContext, effect:TMax2DImageEffect) Override
		Return TSDLGPUMax2DContext(context) <> Null And TMax2DSaturationEffect(effect) <> Null
	End Method

	Method Supports:Int(canvas:TMax2DGraphics, effect:TMax2DImageEffect) Override
		Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(canvas.context)
		Local shader:Byte Ptr = m2d_saturation_shader(context.native, context.GetGPUDevice())
		If Not shader Then Return False
		Return m2d_gpu_image_effect_support(context.native, shader, context.NativeFrame(context.target), canvas.state.blend, context.compactQuads)
	End Method

	Method Draw(canvas:TMax2DGraphics, image:TImage, effect:TMax2DImageEffect, x:Float, y:Float, frame:Int) Override
		Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(canvas.context)
		Local shader:Byte Ptr = m2d_saturation_shader(context.native, context.GetGPUDevice())
		If Not shader Then Throw "Max2D Effects: shader creation failed: " + SDL_GetError()
		context.Flush()
		m2d_gpu_select_image_effect(context.native, shader, TMax2DSaturationEffect(effect).GetAmount(), 0, 0, 0)
		Try
			canvas.DrawImage(image, x, y, frame)
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
	Function m2d_saturation_shader:Byte Ptr(context:Byte Ptr, device:Byte Ptr)
	Function m2d_gpu_image_effect_support:Int(context:Byte Ptr, effect:Byte Ptr, target:Byte Ptr, blend:Int, compact:Int)
	Function m2d_gpu_select_image_effect(context:Byte Ptr, effect:Byte Ptr, p0:Float, p1:Float, p2:Float, p3:Float)
End Extern

RegisterMax2DImageEffectBackend(New TSDLGPUSaturationBackend)
