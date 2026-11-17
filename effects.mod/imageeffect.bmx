Rem
bbdoc: Reusable, context-independent description of an image colour effect.
about: Pass an effect to DrawImageEffect. Native shader resources are cached by the current graphics context and released when that context closes.
End Rem
Type TMax2DImageEffect Abstract
End Type

Rem
bbdoc: Adjustable saturation applied to straight RGB after image sampling and drawing tint.
about: Zero produces grayscale, one preserves colour, and larger values increase saturation. Luminance uses weights 0.2126, 0.7152 and 0.0722 on the sampled colour components, without an implicit colour-space conversion. Alpha is preserved.
End Rem
Type TMax2DSaturationEffect Extends TMax2DImageEffect

	Private

	Field amount:Float = 1

	Public

	Rem
	bbdoc: Changes saturation for subsequent effect draws.
	param: Finite, nonnegative saturation value.
	about: Previously queued draws retain the value they used. This updates a reusable description and allocates no graphics resource.
	End Rem
	Method SetAmount(value:Float)
		If value < 0 Or IsNan(value) Or IsInf(value) Then Throw "Max2D Effects: saturation must be finite and nonnegative"
		amount = value
	End Method

	Rem
	bbdoc: Returns the selected saturation value.
	End Rem
	Method GetAmount:Float()
		Return amount
	End Method

End Type

Rem
bbdoc: Creates a reusable saturation effect without allocating graphics resources.
param: Finite, nonnegative saturation; zero is grayscale and one preserves colour.
End Rem
Function CreateSaturationEffect:TMax2DSaturationEffect(amount:Float = 1)
	Local effect:TMax2DSaturationEffect = New TMax2DSaturationEffect
	effect.SetAmount(amount)
	Return effect
End Function

Rem
bbdoc: Replaces image RGB with a selected colour while preserving sampled alpha.
about: Drawing tint multiplies the selected colour and drawing alpha multiplies the source alpha. Works with ordinary and render images. Useful for silhouettes, shadows and coloured glows in explicit layer chains.
End Rem
Type TMax2DColorizeEffect Extends TMax2DImageEffect

	Private
	Field red:Int = 255
	Field green:Int = 255
	Field blue:Int = 255

	Public

	Rem
	bbdoc: Sets silhouette RGB components, each from zero to 255.
	about: Invalid components leave the previous colour unchanged. Previously submitted draws retain their colour.
	End Rem
	Method SetColor(r:Int, g:Int, b:Int)
		If r < 0 Or r > 255 Or g < 0 Or g > 255 Or b < 0 Or b > 255 Then Throw "Max2D Effects: colour components must be between zero and 255"
		red = r
		green = g
		blue = b
	End Method

	Rem
	bbdoc: Returns the selected silhouette RGB components.
	End Rem
	Method GetColor(r:Int Var, g:Int Var, b:Int Var)
		r = red
		g = green
		b = blue
	End Method

End Type

Rem
bbdoc: Creates a reusable silhouette colour description without graphics resources.
about: Components range from zero to 255. The default is white.
End Rem
Function CreateColorizeEffect:TMax2DColorizeEffect(red:Int = 255, green:Int = 255, blue:Int = 255)
	Local effect:TMax2DColorizeEffect = New TMax2DColorizeEffect
	effect.SetColor(red, green, blue)
	Return effect
End Function

Rem
bbdoc: One axis of a nine-tap blur that filters premultiplied colour and alpha together.
about: Requires a premultiplied render-image source. Draw horizontal and vertical effects into separate caller-owned render images for a two-dimensional blur. Radius is in source-image pixels, from zero to four. Pad the group with transparent pixels to retain the blur outside its content bounds. Each draw uses one pass; no scratch image is allocated automatically.
End Rem
Type TMax2DBlurEffect Extends TMax2DImageEffect

	Private
	Field radius:Float = 4
	Field horizontal:Int = True

	Public

	Rem
	bbdoc: Sets the source-pixel sampling radius from zero to four.
	about: Four uses the full binomial kernel; smaller radii scale its sample spacing. Zero preserves the source. Values must be finite.
	End Rem
	Method SetRadius(value:Float)
		If value < 0 Or value > 4 Or IsNan(value) Or IsInf(value) Then Throw "Max2D Effects: blur radius must be finite and between zero and four"
		radius = value
	End Method

	Rem
	bbdoc: Returns the source-pixel sampling radius.
	End Rem
	Method GetRadius:Float()
		Return radius
	End Method

	Rem
	bbdoc: Selects horizontal sampling when True, or vertical sampling when False.
	End Rem
	Method SetHorizontal(value:Int)
		horizontal = value <> 0
	End Method

	Rem
	bbdoc: Returns True for horizontal sampling.
	End Rem
	Method IsHorizontal:Int()
		Return horizontal
	End Method

End Type

Rem
bbdoc: Creates a reusable single-axis blur description without graphics resources.
param: Source-pixel sampling radius, from zero to four.
param: True for horizontal sampling, False for vertical sampling.
End Rem
Function CreateBlurEffect:TMax2DBlurEffect(radius:Float = 4, horizontal:Int = True)
	Local effect:TMax2DBlurEffect = New TMax2DBlurEffect
	effect.SetRadius(radius)
	effect.SetHorizontal(horizontal)
	Return effect
End Function

Rem
bbdoc: Import-based extension contract for explicit image effects.
about: Backend modules register a provider once. Providers must preserve drawing state, capture parameters for queued draws and release native resources with their context. No provider is invoked for ordinary DrawImage calls.
End Rem
Type TMax2DImageEffectBackend Abstract

	Rem
	bbdoc: Reports whether this provider handles a context and effect description.
	param: Active graphics context.
	param: Requested effect description.
	End Rem
	Method Handles:Int(context:TMax2DContext, effect:TMax2DImageEffect) Abstract

	Rem
	bbdoc: Checks support for the current target, blend mode and submission path.
	param: Active drawing canvas.
	param: Requested effect description.
	End Rem
	Method Supports:Int(canvas:TMax2DGraphics, effect:TMax2DImageEffect) Abstract

	Rem
	bbdoc: Draws an image with an effect while preserving canvas drawing state.
	param: Active drawing canvas.
	param: Source image.
	param: Requested effect description.
	param: Horizontal drawing position.
	param: Vertical drawing position.
	param: Zero-based image frame.
	End Rem
	Method Draw(canvas:TMax2DGraphics, image:TImage, effect:TMax2DImageEffect, x:Float, y:Float, frame:Int) Abstract

	Rem
	bbdoc: Draws repeated images at interleaved x,y positions.
	about: Providers may override this to coalesce compatible sprites. The default preserves ordering by invoking Draw for each position. The caller has validated an even, nonempty positions array.
	End Rem
	Method DrawBatch(canvas:TMax2DGraphics, image:TImage, effect:TMax2DImageEffect, positions:Float[], frame:Int)
		For Local i:Int = 0 Until positions.Length Step 2
			Draw(canvas, image, effect, positions[i], positions[i + 1], frame)
		Next
	End Method

End Type

Private

Global imageEffectBackends:TList = New TList

Function ImageEffectBackend:TMax2DImageEffectBackend(canvas:TMax2DGraphics, effect:TMax2DImageEffect)
	For Local backend:TMax2DImageEffectBackend = EachIn imageEffectBackends
		If backend.Handles(canvas.context, effect) Then Return backend
	Next
	Return Null
End Function

Public

Rem
bbdoc: Registers an optional image-effect backend provider.
param: Provider instance retained for the lifetime of the application.
about: Intended for backend module initialization on the rendering thread.
End Rem
Function RegisterMax2DImageEffectBackend(backend:TMax2DImageEffectBackend)
	If Not backend Then Throw "Max2D Effects: backend is null"
	imageEffectBackends.AddLast(backend)
End Function

Rem
bbdoc: Checks an effect against the active backend, target, blend and submission path.
param: Effect description to check.
about: Returns False if no provider is imported. A successful query may compile and cache a shader and pipeline; warm it before timing. Query again after changing context, target format, blend mode or compact-sprite mode.
End Rem
Function Max2DSupportsImageEffect:Int(effect:TMax2DImageEffect)
	If Not effect Then Return False
	Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
	Local backend:TMax2DImageEffectBackend = ImageEffectBackend(canvas, effect)
	If Not backend Then Return False
	Return backend.Supports(canvas, effect)
End Function

Rem
bbdoc: Draws one image through a reusable effect, using the normal image handle, transform, camera, tint and blend.
param: Source image; sampling the current render target is forbidden.
param: Reusable effect description.
param: Horizontal drawing position.
param: Vertical drawing position.
param: Zero-based image frame.
about: Each call ends the previous batch and submits one effect image. It needs no intermediate image or readback. Parameters are captured for that draw; later edits do not change queued work. Use an explicit render-image layer to process a whole group in one call. No ambient effect remains selected afterwards. Unsupported effects throw before drawing.
End Rem
Function DrawImageEffect(image:TImage, effect:TMax2DImageEffect, x:Float, y:Float, frame:Int = 0)
	If Not image Or Not effect Then Throw "Max2D Effects: image and effect are required"
	Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
	If image = canvas.renderImage Then Throw "Max2D Effects: an effect cannot sample the current target"
	Local backend:TMax2DImageEffectBackend = ImageEffectBackend(canvas, effect)
	If Not backend Then Throw "Max2D Effects: no backend supports this image effect"
	If Not backend.Supports(canvas, effect) Then Throw "Max2D Effects: image effect unsupported for this drawing state"
	backend.Draw(canvas, image, effect, x, y, frame)
End Function

Rem
bbdoc: Draws repeated copies of one image through an effect at interleaved x,y positions.
param: Source image; sampling the current render target is forbidden.
param: Reusable effect description.
param: Reusable array containing x,y pairs in drawing order; no array copy is made.
param: Zero-based image frame shared by all copies.
about: Uses the normal image handle and current drawing state. The native SDL GPU provider captures parameters once and batches copies up to the existing sprite-buffer capacity. It ends the preceding batch and flushes before returning, leaving no ambient effect. Empty positions are a no-op; an odd length throws before drawing. Allocate and update the positions array outside the draw call to avoid per-frame allocation. Providers without batch acceleration may submit each copy separately.
End Rem
Function DrawImageEffectBatch(image:TImage, effect:TMax2DImageEffect, positions:Float[], frame:Int = 0)
	If Not image Or Not effect Then Throw "Max2D Effects: image and effect are required"
	If positions.Length Mod 2 Then Throw "Max2D Effects: positions must contain x,y pairs"
	If Not positions.Length Then Return
	Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
	If image = canvas.renderImage Then Throw "Max2D Effects: an effect cannot sample the current target"
	Local backend:TMax2DImageEffectBackend = ImageEffectBackend(canvas, effect)
	If Not backend Then Throw "Max2D Effects: no backend supports this image effect"
	If Not backend.Supports(canvas, effect) Then Throw "Max2D Effects: image effect unsupported for this drawing state"
	backend.DrawBatch(canvas, image, effect, positions, frame)
End Function
