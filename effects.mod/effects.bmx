SuperStrict

Rem
bbdoc: Optional compositing effects for Max2D render-image layers.
End Rem
Module Max2D.Effects
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Core

Include "imageeffect.bmx"
Include "layereffect.bmx"

Private

Global alphaMultiplyBlend:Int = CreateBlendMode(BLEND_ZERO, BLEND_SRC_ALPHA, BLEND_OP_ADD, BLEND_ZERO, BLEND_SRC_ALPHA)

Function BeginLayerOperation:TMax2DStateScope(layer:TRenderImage)
	If Not layer Then Throw "Max2D Effects: select a render image before applying a layer effect"
	If Not Max2DSupportsBlend(alphaMultiplyBlend) Then Throw "Max2D Effects: alpha multiplication is unsupported by this backend"

	Local scope:TMax2DStateScope = ScopedMax2DState()
	Try
		SetVirtualResolution(layer.width, layer.height)
		SetViewport(0, 0, layer.width, layer.height)
		SetCamera(Null)
		ResetCoordinates()
		SetAffineTransform(1, 0, 0, 1)
		SetOrigin(0, 0)
		SetHandle(0, 0)
		SetColor(255, 255, 255)
		SetAlpha(1)
		SetBlend(alphaMultiplyBlend)
	Catch error:Object
		scope.Close()
		Throw error
	End Try
	Return scope
End Function

Public

Rem
bbdoc: Reports whether the active backend can multiply a layer by alpha.
about: Call after Graphics. A render image is also required; query Max2DSupportsRenderImage for its dimensions and flags. This operation uses a drawing pass over that image, with no readback or new target allocation.
End Rem
Function Max2DSupportsLayerAlpha:Int()
	Return Max2DSupportsBlend(alphaMultiplyBlend)
End Function

Rem
bbdoc: Multiplies the current render image's colour and alpha by a mask image's alpha.
param: Same-size mask image; its RGB is ignored.
about: Draw the group into a transparent render image, then apply this mask and draw the group image to its parent target. The mask must cover the entire layer, including transparent areas. The mask and layer must be distinct images to avoid sampling the active target. This explicit operation costs one additional pass over the layer bounds. RGB and alpha are multiplied together, preserving premultiplied render-image storage. Unsupported blend modes throw before changing drawing state. Drawing state, camera, viewport and current target are restored on return.
End Rem
Function ApplyLayerAlphaMask(mask:TImage)
	Local layer:TRenderImage = TMax2DGraphics.Current().renderImage
	If Not layer Then Throw "Max2D Effects: select a render image before applying a layer mask"
	If Not mask Then Throw "Max2D Effects: mask image is null"
	If mask = layer Then Throw "Max2D Effects: a layer cannot sample itself as its mask"
	If mask.width <> layer.width Or mask.height <> layer.height Then Throw "Max2D Effects: mask and layer dimensions must match"

	Local scope:TMax2DStateScope = BeginLayerOperation(layer)
	Try
		TMax2DGraphics.Current().DrawImageRegion(mask, 0, 0, layer.width, layer.height, 0, 0, mask.width, mask.height, 0, 0)
	Finally
		scope.Close()
	End Try
End Function

Rem
bbdoc: Multiplies the current render image's colour and alpha by an opacity value.
param: Opacity between zero and one, inclusive.
about: Useful for fading a complete group without changing each draw. This uses the same checked alpha-multiply pass as ApplyLayerAlphaMask. For a single image, SetAlpha before DrawImage is cheaper. Drawing state and the selected render target are restored.
End Rem
Function ApplyLayerOpacity(opacity:Float)
	If opacity < 0 Or opacity > 1 Or IsNan(opacity) Then Throw "Max2D Effects: opacity must be between zero and one"
	Local layer:TRenderImage = TMax2DGraphics.Current().renderImage
	Local scope:TMax2DStateScope = BeginLayerOperation(layer)
	Try
		SetAlpha(opacity)
		DrawRect(0, 0, layer.width, layer.height)
	Finally
		scope.Close()
	End Try
End Function
