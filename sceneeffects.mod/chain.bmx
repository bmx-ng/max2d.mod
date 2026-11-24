Rem
bbdoc: Retained scene stage applying an ordered sequence of image effects with explicit logical padding.
about: Copies the effect array but shares descriptions. Raw effect parameters retain their pixel/UV units at every resolution scale. Empty chains copy without a shader provider. Owns one output image and, for multiple effects, one scratch image. Uses the existing Max2D effect-buffer implementation.
End Rem
Type TSceneChainStage Extends TSceneEffectStage
	Private
	Field effects:TMax2DImageEffect[]
	Field left:Float, top:Float, right:Float, bottom:Float
	Field buffers:TMax2DEffectBuffers
	Field prepared:TSceneStageLayout
	Public
	Rem
	bbdoc: Creates a stage without graphics resources; padding must be finite and nonnegative.
	param: Ordered shared effect descriptions; Null or empty means copy, and Null entries are rejected.
	param: Finite nonnegative left padding in logical scene units.
	param: Finite nonnegative top padding in logical scene units.
	param: Finite nonnegative right padding in logical scene units.
	param: Finite nonnegative bottom padding in logical scene units.
	returns: A new #TSceneChainStage instance configured with the supplied settings.
	about: Null entries are rejected. Null or an empty array means copy. Supply a new stage to replace the sequence; call Invalidate after editing a retained description.
	End Rem
	Function Create:TSceneChainStage(effects:TMax2DImageEffect[], left:Float = 0, top:Float = 0, right:Float = 0, bottom:Float = 0)
		CheckStagePadding(left); CheckStagePadding(top); CheckStagePadding(right); CheckStagePadding(bottom)
		For Local effect:TMax2DImageEffect = EachIn effects
			If Not effect Then
				Throw "Max2D SceneEffects: null chain effect"
			End If
		Next

		Local result:TSceneChainStage = New TSceneChainStage
		result.effects = effects[..]
		result.left = left; result.top = top; result.right = right; result.bottom = bottom
		Return result
	End Function
	Rem
	bbdoc: Adds this stage's logical padding without rounding or changing input bounds.
	param: Finite logical input rectangle; may be the same object as output.
	param: Required reusable destination rectangle.
	End Rem
	Method ExpandBounds(input:TSceneRect, output:TSceneRect)
		CheckStageRect(input)
		If Not output Then
			Throw "Max2D SceneEffects: bounds destination is null"
		End If

		Local x:Float = input.x - left, y:Float = input.y - top
		Local w:Float = input.width + left + right, h:Float = input.height + top + bottom
		If IsInf(x) Or IsInf(y) Or IsInf(w) Or IsInf(h) Then
			Throw "Max2D SceneEffects: expanded bounds overflow"
		End If

		output.x = x; output.y = y; output.width = w; output.height = h
	End Method
	Rem
	bbdoc: Estimates one full-canvas output image, plus scratch for two or more effects.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Estimated owned texture bytes for the complete replacement layout, excluding driver overhead.
	End Rem
	Method EstimateStorageBytes:Long(layout:TSceneStageLayout)
		If Not layout Then
			Throw "Max2D SceneEffects: layout is null"
		End If

		Local count:Int = 1
		If effects.Length > 1 Then
			count = 2
		End If

		Return layout.EstimateImageBytes(count)
	End Method
	Rem
	bbdoc: Returns zero for reusable pixel storage, otherwise the full candidate allocation.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Additional peak texture bytes required during preparation; zero when retained storage can be reused.
	End Rem
	Method EstimatePreparationBytes:Long(layout:TSceneStageLayout) Override
		If prepared And layout And buffers Then
			If prepared.PixelWidth() = layout.PixelWidth() And prepared.PixelHeight() = layout.PixelHeight() And prepared.PixelFormat() = layout.PixelFormat() Then
				Return 0
			End If
		End If

		Return EstimateStorageBytes(layout)
	End Method
	Rem
	bbdoc: Prepares and validates retained output targets transactionally, preserving caller state.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	about: Checks shader support under SOLIDBLEND on the actual target format. Identical pixel layouts reuse storage and recheck mutable descriptions. Logical origin and scale changes alone do not require replacement textures. Source-specific validation still occurs during Update.
	End Rem
	Method Prepare(layout:TSceneStageLayout)
		EstimateStorageBytes(layout)
		If buffers And prepared And prepared.PixelWidth() = layout.PixelWidth() And prepared.PixelHeight() = layout.PixelHeight() And prepared.PixelFormat() = layout.PixelFormat() Then
			CheckTargets(buffers)
			prepared = layout
			Return
		End If
		' Check context/selection before allocating replacements.
		If buffers Then
			Local old:TRenderImage = buffers.Image(0)
			If TMax2DGraphics.Current().renderImage = old Then
				Throw "Max2D SceneEffects: deselect stage output before preparation"
			End If
		End If

		Local candidate:TMax2DEffectBuffers = New TMax2DEffectBuffers
		Local count:Int = 1
		If effects.Length > 1 Then
			count = 2
		End If

		Try
			candidate.Prepare(layout.PixelWidth(), layout.PixelHeight(), count, -1, layout.PixelFormat())
			CheckTargets(candidate)
		Catch error:Object
			candidate.Release()
			Throw error
		End Try

		Try
			If buffers Then
				buffers.Release()
			End If
		Catch error:Object
			candidate.Release()
			Throw error
		End Try

		buffers = candidate; prepared = layout
	End Method
	Rem
	bbdoc: Processes a matching source, leaving it and caller drawing state unchanged.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Returns borrowed output; does not automatically compare configuration revisions or cache pixels. Throws before preparation, on source aliasing, format/size mismatch or unavailable effects. No render images are allocated by a warm update.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		If Not prepared Or Not buffers Then
			Throw "Max2D SceneEffects: prepare stage before update"
		End If

		If Not source Then
			Throw "Max2D SceneEffects: source is null"
		End If

		If source.width <> prepared.PixelWidth() Or source.height <> prepared.PixelHeight() Then
			Throw "Max2D SceneEffects: source dimensions differ from layout"
		End If

		If source.sources[0].targetFormat <> prepared.PixelFormat() Then
			Throw "Max2D SceneEffects: source format differs from layout"
		End If

		Return buffers.ApplyChain(source, 0, effects)
	End Method
	Rem
	bbdoc: Releases stage-owned images and clears preparation, retaining descriptions and revision.
	End Rem
	Method ReleaseResources()
		If buffers Then
			buffers.Release()
		End If

		buffers = Null; prepared = Null
	End Method

	Private
	Method CheckTargets(storage:TMax2DEffectBuffers)
		Local target:TRenderImage = storage.Image(0)
		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			SetRenderImage(target)
			SetBlend(SOLIDBLEND)
			For Local effect:TMax2DImageEffect = EachIn effects
				If Not Max2DSupportsImageEffect(effect) Then
					Throw "Max2D SceneEffects: unsupported chain effect for layout"
				End If
			Next
		Finally
			scope.Close()
		End Try
	End Method
End Type

Private
Function CheckStagePadding(value:Float)
	If value < 0 Or IsNan(value) Or IsInf(value) Then
		Throw "Max2D SceneEffects: padding must be finite and nonnegative"
	End If
End Function

Public
