Private

Function PrepareChainTarget:TMax2DStateScope(target:TRenderImage)
	SetRenderImage(target)
	Local scope:TMax2DStateScope = ScopedMax2DState()
	Try
		SetVirtualResolution(target.width, target.height)
		SetViewport(0, 0, target.width, target.height)
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
about: Reuses destination and scratch as alternating outputs, always finishing in destination. Each effect costs one image draw. An empty chain copies the source with one ordinary draw. All passes replace the full target using SOLIDBLEND, white tint and identity coordinates, ignoring image handles. Target, camera, transforms, viewport and other drawing state are restored even on failure. Dimensions, aliasing and effect support for each target are checked before chain drawing begins; support checks can create native resources on first use. Runtime failures do not roll back pixels already written. No scratch images or per-pass arrays are allocated; the call allocates up to three drawing-state scopes to preserve the caller and both output views. Retain the images, descriptors and array across frames and rerun only when the source or effects change.
End Rem
Function ApplyLayerEffects(source:TRenderImage, destination:TRenderImage, effects:TMax2DImageEffect[], scratch:TRenderImage = Null)
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
	Local scope:TMax2DStateScope = ScopedMax2DState()
	Try
		SetCamera(Null)
		ResetCoordinates()
		SetAffineTransform(1, 0, 0, 1)
		SetOrigin(0, 0)
		SetHandle(0, 0)
		SetColor(255, 255, 255)
		SetAlpha(1)
		SetBlend(SOLIDBLEND)
		Local destinationScope:TMax2DStateScope = PrepareChainTarget(destination)
		Try
			Local scratchScope:TMax2DStateScope
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
				If scratchScope Then scratchScope.Close()
			End Try
		Finally
			destinationScope.Close()
		End Try
	Finally
		scope.Close()
	End Try
End Function
