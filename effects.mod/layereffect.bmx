Private

' For retained processors whose passes restore every output view independently.
' Keep caller state untouched; this helper must not enclose caller-view edits.
Type TLayerDrawingState
 Field state:TMax2DState=New TMax2DState
 Field active:Int
 Method Open:SLayerDrawingScope()
  Local scope:SLayerDrawingScope
  If active Then
   ' A provider may re-enter the same processor. Do not share its live state.
   scope.fallback=ScopedMax2DState()
  Else
   scope.canvas=TMax2DGraphics.Current()
   scope.callerState=scope.canvas.state
   scope.target=scope.canvas.renderImage
   scope.owner=Self
   active=True
   scope.canvas.state=state
  End If
  Return scope
 End Method
End Type

Struct SLayerDrawingScope
 Field owner:TLayerDrawingState
 Field canvas:TMax2DGraphics
 Field callerState:TMax2DState
 Field target:TRenderImage
 Field fallback:TMax2DStateScope
 Method Close()
  If fallback Then
   fallback.Close();fallback=Null
  Else If owner Then
   Try
    canvas.state=callerState
    If Not canvas.context.closed Then canvas.SetRenderImage(target)
   Finally
    owner.active=False
    owner=Null;canvas=Null;callerState=Null;target=Null
   End Try
  End If
 End Method
End Struct

' Internal pass state: the enclosing effect operation owns drawing-state
' restoration. Each output still needs its independent persistent view restored.
Struct SLayerTargetView
 Field canvas:TMax2DGraphics
 Field target:TRenderImage
 Field view:TMax2DView
 Field width:Float,height:Float
 Field x:Int,y:Int,w:Int,h:Int,automatic:Int,fullClip:Int,presentation:Int
 Field barRed:Int,barGreen:Int,barBlue:Int
 Method Close()
  If Not view Then Return
  canvas.SetRenderImage(target)
  view.width=width;view.height=height
  view.x=x;view.y=y;view.w=w;view.h=h
  view.automatic=automatic;view.fullClip=fullClip;view.presentation=presentation
  view.barRed=barRed;view.barGreen=barGreen;view.barBlue=barBlue
  canvas.context.ApplyView()
  view=Null;target=Null;canvas=Null
 End Method
End Struct

Function PrepareChainTarget:SLayerTargetView(target:TRenderImage)
 SetRenderImage(target)
 Local scope:SLayerTargetView
 scope.canvas=TMax2DGraphics.Current();scope.target=target
 Local view:TMax2DView=scope.canvas.context.view
 scope.view=view;scope.width=view.width;scope.height=view.height
 scope.x=view.x;scope.y=view.y;scope.w=view.w;scope.h=view.h
 scope.automatic=view.automatic;scope.fullClip=view.fullClip;scope.presentation=view.presentation
 scope.barRed=view.barRed;scope.barGreen=view.barGreen;scope.barBlue=view.barBlue
 Try
  SetVirtualResolution(target.width,target.height)
  SetViewport(0,0,target.width,target.height)
 Catch error:Object
  scope.Close()
  Throw error
 End Try
 Return scope
End Function

Public

Rem
bbdoc: Applies an ordered image-effect chain to a complete render-image layer.
param: Premultiplied source layer, left unchanged.
param: Same-sized destination layer, distinct from the source.
param: Reusable array of effect descriptions, applied in array order.
param: Same-sized scratch layer, required for two or more effects and distinct from source and destination.
about: Reuses destination and scratch as alternating outputs, always finishing in destination. Each effect costs one image draw. An empty chain copies the source with one ordinary draw. All passes replace the full target using SOLIDBLEND, white tint and identity coordinates, ignoring image handles. Target, camera, transforms, viewport and other drawing state are restored even on failure. Dimensions, aliasing and effect support for each target are checked before chain drawing begins; support checks can create native resources on first use. Runtime failures do not roll back pixels already written. No scratch images or per-pass arrays are allocated; the call allocates one drawing-state scope for the caller and uses allocation-free value snapshots for output views. Retain the images, descriptors and array across frames and rerun only when the source or effects change.
End Rem
Function ApplyLayerEffects(source:TRenderImage, destination:TRenderImage, effects:TMax2DImageEffect[], scratch:TRenderImage = Null)
	ApplyLayerEffectsInternal(source, destination, effects, scratch, Null)
End Function

Private
Function ApplyLayerEffectsInternal(source:TRenderImage, destination:TRenderImage, effects:TMax2DImageEffect[], scratch:TRenderImage, drawingState:TLayerDrawingState)
	If Not source Or Not destination Then Throw "Max2D Effects: source and destination layers are required"
	If source = destination Then Throw "Max2D Effects: source and destination layers must be distinct"
	If source.width <> destination.width Or source.height <> destination.height Then Throw "Max2D Effects: layer dimensions must match"
	If effects.Length > 1 Then
		If Not scratch Then Throw "Max2D Effects: a multi-pass chain requires a scratch layer"
		If scratch = source Or scratch = destination Then Throw "Max2D Effects: scratch must be distinct from source and destination"
		If scratch.width <> source.width Or scratch.height <> source.height Then Throw "Max2D Effects: scratch dimensions must match the source"
	End If
	For Local effect:TMax2DImageEffect = EachIn effects
		If Not effect Then Throw "Max2D Effects: chain entries must not be null"
	Next

	Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
	Local scope:SLayerDrawingScope
	If drawingState Then
		scope=drawingState.Open()
	Else
		scope.fallback=ScopedMax2DState()
	End If
	Try
		SetCamera(Null)
		ResetCoordinates()
		SetAffineTransform(1, 0, 0, 1)
		SetOrigin(0, 0)
		SetHandle(0, 0)
		SetColor(255, 255, 255)
		SetAlpha(1)
		SetBlend(SOLIDBLEND)
		Local destinationScope:SLayerTargetView = PrepareChainTarget(destination)
		Try
			Local scratchScope:SLayerTargetView
			If effects.Length > 1 Then scratchScope = PrepareChainTarget(scratch)
			Try
				' Materialize/validate the input before any output pixels are touched.
				source.Frame(0, canvas)
				For Local i:Int = 0 Until effects.Length
					If (effects.Length - i) Mod 2 Then
						SetRenderImage(destination)
					Else
						SetRenderImage(scratch)
					End If
					If Not Max2DSupportsImageEffect(effects[i]) Then Throw "Max2D Effects: chain effect unsupported for its output target"
				Next

				If Not effects.Length Then
					SetRenderImage(destination)
					DrawImage(source, source.handle_x, source.handle_y)
				Else
					Local input:TRenderImage = source
					For Local i:Int = 0 Until effects.Length
						Local output:TRenderImage = destination
						If Not ((effects.Length - i) Mod 2) Then output = scratch
						SetRenderImage(output)
						DrawImageEffect(input, effects[i], input.handle_x, input.handle_y)
						input = output
					Next
				End If
			Finally
				scratchScope.Close()
			End Try
		Finally
			destinationScope.Close()
		End Try
	Finally
		scope.Close()
	End Try
End Function

Public
