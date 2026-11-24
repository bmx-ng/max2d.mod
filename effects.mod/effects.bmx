SuperStrict

Rem
bbdoc: Optional compositing effects for Max2D render-image layers.
End Rem
Module Max2D.Effects
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Core

Include "imageeffect.bmx"
Include "linearcolour.bmx"
Include "layereffect.bmx"
Include "scaledblur.bmx"
Include "effectbuffers.bmx"
Include "effectchain.bmx"
Include "effectlayer.bmx"
Include "bloom.bmx"
Include "shadow.bmx"
Include "innershadow.bmx"

Private

Global alphaMultiplyBlend:Int = CreateBlendMode(BLEND_ZERO, BLEND_SRC_ALPHA, BLEND_OP_ADD, BLEND_ZERO, BLEND_SRC_ALPHA)

Global inverseAlphaMultiplyBlend:Int = CreateBlendMode(BLEND_ZERO, BLEND_ONE_MINUS_SRC_ALPHA, BLEND_OP_ADD, BLEND_ZERO, BLEND_ONE_MINUS_SRC_ALPHA)

' Closed layer passes only change these drawing fields and the target view.
' No callbacks or shader providers run here; camera settings are never edited.
Struct SLayerOperation
 Field state:TMax2DState
 Field view:SLayerTargetView
 Field red:Int,green:Int,blue:Int,colorByteAlpha:Int,blend:Int
 Field alpha:Float,ix:Float,iy:Float,jx:Float,jy:Float,originX:Float,originY:Float,handleX:Float,handleY:Float
 Field coordXX:Double,coordXY:Double,coordYX:Double,coordYY:Double,coordTX:Double,coordTY:Double,cameraXX:Double,cameraXY:Double,cameraYX:Double,cameraYY:Double,cameraTX:Double,cameraTY:Double
 Field camera:TCamera2D
 Method Capture(source:TMax2DState)
  state=source
  red=source.red
  green=source.green
  blue=source.blue
  colorByteAlpha=source.colorByteAlpha
  blend=source.blend
  alpha=source.alpha
  ix=source.ix
  iy=source.iy
  jx=source.jx
  jy=source.jy
  originX=source.originX
  originY=source.originY
  handleX=source.handleX
  handleY=source.handleY
  coordXX=source.coordXX
  coordXY=source.coordXY
  coordYX=source.coordYX
  coordYY=source.coordYY
  coordTX=source.coordTX
  coordTY=source.coordTY
  cameraXX=source.cameraXX
  cameraXY=source.cameraXY
  cameraYX=source.cameraYX
  cameraYY=source.cameraYY
  cameraTX=source.cameraTX
  cameraTY=source.cameraTY
  camera=source.camera
 End Method
 Method Close()
  If Not state Then Return
  state.red=red
  state.green=green
  state.blue=blue
  state.colorByteAlpha=colorByteAlpha
  state.blend=blend
  state.alpha=alpha
  state.ix=ix
  state.iy=iy
  state.jx=jx
  state.jy=jy
  state.originX=originX
  state.originY=originY
  state.handleX=handleX
  state.handleY=handleY
  state.coordXX=coordXX
  state.coordXY=coordXY
  state.coordYX=coordYX
  state.coordYY=coordYY
  state.coordTX=coordTX
  state.coordTY=coordTY
  state.cameraXX=cameraXX
  state.cameraXY=cameraXY
  state.cameraYX=cameraYX
  state.cameraYY=cameraYY
  state.cameraTX=cameraTX
  state.cameraTY=cameraTY
  state.camera=camera
  state=Null;camera=Null
  view.Close()
 End Method
End Struct

Function BeginLayerOperation:SLayerOperation(layer:TRenderImage, blend:Int)
	If Not layer Then Throw "Max2D Effects: select a render image before applying a layer effect"
	If Not Max2DSupportsBlend(blend) Then Throw "Max2D Effects: alpha multiplication is unsupported by this backend"

	Local scope:SLayerOperation
	scope.Capture(TMax2DGraphics.Current().state)
	Try
		scope.view=PrepareChainTarget(layer)
		SetCamera(Null)
		ResetCoordinates()
		SetAffineTransform(1, 0, 0, 1)
		SetOrigin(0, 0)
		SetHandle(0, 0)
		SetColor(255, 255, 255)
		SetAlpha(1)
		SetBlend(blend)
	Catch error:Object
		scope.Close()
		Throw error
	End Try
	Return scope
End Function

Function ApplyLayerMaskWithBlend(mask:TImage, blend:Int)
	Local layer:TRenderImage = TMax2DGraphics.Current().renderImage
	If Not layer Then Throw "Max2D Effects: select a render image before applying a layer mask"
	If Not mask Then Throw "Max2D Effects: mask image is null"
	If mask = layer Then Throw "Max2D Effects: a layer cannot sample itself as its mask"
	If mask.width <> layer.width Or mask.height <> layer.height Then Throw "Max2D Effects: mask and layer dimensions must match"

	Local scope:SLayerOperation = BeginLayerOperation(layer, blend)
	Try
		TMax2DGraphics.Current().DrawImageRegion(mask, 0, 0, layer.width, layer.height, 0, 0, mask.width, mask.height, 0, 0)
	Finally
		scope.Close()
	End Try
End Function

Public

Rem
bbdoc: Reports whether the active backend can multiply a layer by alpha.
returns: True if the active backend can multiply a layer by alpha, False otherwise.
about: Call after Graphics. A render image is also required; query Max2DSupportsRenderImage for its dimensions and flags. This operation uses a drawing pass over that image, with no readback or new target allocation.
End Rem
Function Max2DSupportsLayerAlpha:Int()
	Return Max2DSupportsBlend(alphaMultiplyBlend)
End Function

Rem
bbdoc: Multiplies the current render image's colour and alpha by a mask image's alpha.
param: Same-size mask image; its RGB is ignored.
about: Draw the group into a transparent render image, then apply this mask and draw the group image to its parent target. The mask must cover the entire layer, including transparent areas. The mask and layer must be distinct images to avoid sampling the active target. This explicit operation costs one additional pass over the layer bounds. RGB and alpha are multiplied together, preserving premultiplied render-image storage. Unsupported blend modes throw before changing drawing state. Drawing state, camera, viewport and current target are restored on return using allocation-free value snapshots.
End Rem
Function ApplyLayerAlphaMask(mask:TImage)
	ApplyLayerMaskWithBlend(mask, alphaMultiplyBlend)
End Function

Rem
bbdoc: Reports whether the active backend supports inverse layer alpha masks.
returns: True if the active backend supports inverse layer alpha masks, False otherwise.
about: Query after Graphics, alongside render-image support. This checks the exact destination-times-one-minus-source-alpha blend equation; no shader provider is needed.
End Rem
Function Max2DSupportsLayerInverseAlpha:Int()
	Return Max2DSupportsBlend(inverseAlphaMultiplyBlend)
End Function

Rem
bbdoc: Cuts a mask's alpha coverage out of the current render image.
param: Same-size mask image; its RGB is ignored.
about: Multiplies stored colour and alpha by one minus mask alpha, preserving premultiplied storage. Opaque mask pixels erase the layer, transparent pixels leave it unchanged, and partial coverage fades it. Costs one ordinary draw without temporary images or readback. Mask and layer must be distinct. Caller state and target views are restored, and source mask pixels are unchanged. Query Max2DSupportsLayerInverseAlpha first; unsupported blends throw before drawing.
End Rem
Function ApplyLayerInverseAlphaMask(mask:TImage)
	ApplyLayerMaskWithBlend(mask, inverseAlphaMultiplyBlend)
End Function

Rem
bbdoc: Multiplies the current render image's colour and alpha by an opacity value.
param: Opacity between zero and one, inclusive.
about: Useful for fading a complete group without changing each draw. This uses the same checked alpha-multiply pass as ApplyLayerAlphaMask. For a single image, SetAlpha before DrawImage is cheaper. Drawing state and the selected render target are restored.
End Rem
Function ApplyLayerOpacity(opacity:Float)
	If opacity < 0 Or opacity > 1 Or IsNan(opacity) Then Throw "Max2D Effects: opacity must be between zero and one"
	Local layer:TRenderImage = TMax2DGraphics.Current().renderImage
	Local scope:SLayerOperation = BeginLayerOperation(layer, alphaMultiplyBlend)
	Try
		SetAlpha(opacity)
		DrawRect(0, 0, layer.width, layer.height)
	Finally
		scope.Close()
	End Try
End Function
