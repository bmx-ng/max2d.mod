Rem
bbdoc: Retained bloom stage with logical-unit radius and automatic blur-pyramid sizing.
about: Preserves transparency by default, adding glow colour and coverage around the source. SetOpaqueBackground(True) selects opaque-black composition for final presentation. Does not select HDR output or tone mapping. Threshold uses source colour units; an SDR source usually needs a threshold below one.
End Rem
Type TSceneBloomStage Extends TSceneEffectStage
	Private
	Field threshold:Float = 1, radius:Float = 8, intensity:Float = 1
	Field opaqueBackground:Int
	Field processor:TMax2DBloom
	Field prepared:TSceneStageLayout
	Field levels:Int
	Field preparedRevision:Long
	Public
	Rem
	bbdoc: Creates a bloom description without allocating graphics resources.
	param: Finite nonnegative bright-pass threshold in source colour units.
	param: Finite nonnegative radius in logical scene units.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	returns: A new #TSceneBloomStage instance configured with the supplied settings.
	End Rem
	Function Create:TSceneBloomStage(threshold:Float = 1, radius:Float = 8, intensity:Float = 1)
		Local result:TSceneBloomStage = New TSceneBloomStage
		result.SetThreshold(threshold); result.SetRadius(radius); result.SetIntensity(intensity)
		Return result
	End Function
	Rem
	bbdoc: Sets finite nonnegative bright-pass threshold in source colour units.
	param: Finite nonnegative luminance threshold in source colour units.
	End Rem
	Method SetThreshold(value:Float)
		CheckStagePadding(value)
		If threshold = value Then
			Return
		End If

		Invalidate(); threshold = value
	End Method
	Rem
	bbdoc: Sets finite nonnegative blur radius in logical scene units.
	param: Finite nonnegative blur radius in logical scene units.
	End Rem
	Method SetRadius(value:Float)
		CheckStagePadding(value)
		If radius = value Then
			Return
		End If

		Invalidate(); radius = value
	End Method
	Rem
	bbdoc: Sets finite nonnegative glow intensity, without changing source brightness.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	End Rem
	Method SetIntensity(value:Float)
		CheckStagePadding(value)
		If intensity = value Then
			Return
		End If

		Invalidate(); intensity = value
	End Method
	Rem
	bbdoc: Chooses opaque-black composition; defaults to False for transparent scene composition.
	param: True for opaque-black composition, False to preserve transparent composition.
	about: Changes processing only, reusing captured content and stage textures. Transparent glow combines coverage with source alpha and scales glow coverage with intensity up to one. Values above one increase RGB only. Zero intensity preserves the captured source RGBA.
	End Rem
	Method SetOpaqueBackground(value:Int)
		value = value <> 0
		If opaqueBackground = value Then
			Return
		End If

		Invalidate(); opaqueBackground = value
	End Method
	Rem
	bbdoc: Returns whether bloom flattens the padded canvas over opaque black.
	returns: Whether bloom flattens the padded canvas over opaque black.
	End Rem
	Method GetOpaqueBackground:Int()
		Return opaqueBackground
	End Method
	Rem
	bbdoc: Returns the bright-pass threshold.
	returns: The bright-pass threshold.
	End Rem
	Method GetThreshold:Float()
		Return threshold
	End Method
	Rem
	bbdoc: Returns the logical blur radius.
	returns: The logical blur radius.
	End Rem
	Method GetRadius:Float()
		Return radius
	End Method
	Rem
	bbdoc: Returns the glow intensity multiplier.
	returns: The glow intensity multiplier.
	End Rem
	Method GetIntensity:Float()
		Return intensity
	End Method
	Rem
	bbdoc: Reserves symmetric logical padding for blur and pyramid filtering.
	param: Finite logical input rectangle; may be the same object as output.
	param: Required reusable destination rectangle.
	about: Uses ceil(2*radius+2) units for a nonzero radius, zero otherwise. Accepts aliased rectangles.
	End Rem
	Method ExpandBounds(input:TSceneRect, output:TSceneRect)
		CheckStageRect(input)
		If Not output Then
			Throw "Max2D SceneEffects: bounds destination is null"
		End If

		Local padding:Float
		If radius > 0 Then
			padding = Float(Ceil(Double(radius) * 2 + 2))
		End If

		Local x:Float = input.x - padding, y:Float = input.y - padding
		Local w:Float = input.width + padding * 2, h:Float = input.height + padding * 2
		If IsInf(x) Or IsInf(y) Or IsInf(w) Or IsInf(h) Then
			Throw "Max2D SceneEffects: bloom bounds overflow"
		End If

		output.x = x; output.y = y; output.width = w; output.height = h
	End Method
	Rem
	bbdoc: Estimates three full images, each reduction level and the smallest-level scratch image.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Estimated owned texture bytes for the complete replacement layout, excluding driver overhead.
	End Rem
	Method EstimateStorageBytes:Long(layout:TSceneStageLayout)
		Local count:Int = ReductionLevels(layout)
		Local bytes:Long = layout.EstimateImageBytes(3)
		Local bpp:Int = 4
		If layout.PixelFormat() = PF_RGBA16F Then
			bpp = 8
		End If

		If layout.PixelFormat() = PF_RGBA32F Then
			bpp = 16
		End If

		Local w:Int = layout.PixelWidth(), h:Int = layout.PixelHeight()
		For Local i:Int = 0 To count
			If i > 0 Then w = w / 2 + w Mod 2; h = h / 2 + h Mod 2

			If i = 0 And count > 0 Then
				Continue
			End If

			Local extra:Long = Long(w) * h * bpp
			If bytes > $7fffffffffffffff:Long - extra Then
				Throw "Max2D SceneEffects: bloom storage overflow"
			End If

			bytes :+ extra
		Next

		If count > 0 Then
			Local extra:Long = Long(w) * h * bpp
			If bytes > $7fffffffffffffff:Long - extra Then
				Throw "Max2D SceneEffects: bloom storage overflow"
			End If

			bytes :+ extra
		End If

		Return bytes
	End Method
	Rem
	bbdoc: Reports candidate allocation bytes, or zero when existing textures can be reused.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Additional peak texture bytes required during preparation; zero when retained storage can be reused.
	End Rem
	Method EstimatePreparationBytes:Long(layout:TSceneStageLayout) Override
		If Matches(layout) Then
			Return 0
		End If

		Return EstimateStorageBytes(layout)
	End Method
	Rem
	bbdoc: Prepares automatic reduction levels and validates effects against the actual target format.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	about: Stable dimensions, format and pyramid depth reuse textures. Prepare again after changing settings. Radius is multiplied by the resolution scale exactly once.
	End Rem
	Method Prepare(layout:TSceneStageLayout)
		EstimateStorageBytes(layout)
		Local count:Int = ReductionLevels(layout)
		If Matches(layout) Then
			processor.SetThreshold(threshold); processor.SetRadius(radius * layout.ResolutionScale()); processor.SetIntensity(intensity)
			processor.SetOpaqueBackground(opaqueBackground)
			processor.Prepare(layout.PixelWidth(), layout.PixelHeight(), count, layout.PixelFormat())
			processor.ValidateSupport()
		Else
			Local candidate:TMax2DBloom = CreateBloom(threshold, radius * layout.ResolutionScale(), intensity)
			candidate.SetOpaqueBackground(opaqueBackground)
			Try
				candidate.Prepare(layout.PixelWidth(), layout.PixelHeight(), count, layout.PixelFormat())
				candidate.ValidateSupport()
				If processor Then
					processor.Release()
				End If
			Catch error:Object
				candidate.Release()
				Throw error
			End Try

			processor = candidate
		End If

		prepared = layout; levels = count; preparedRevision = Revision()
	End Method
	Rem
	bbdoc: Returns borrowed bloom output, preserving matching source pixels and caller state.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Requires successful preparation after the latest settings change. Warm updates allocate no textures.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		If Not prepared Or preparedRevision <> Revision() Then
			Throw "Max2D SceneEffects: prepare bloom after configuration changes"
		End If

		If Not source Then
			Throw "Max2D SceneEffects: source is null"
		End If

		If source.width <> prepared.PixelWidth() Or source.height <> prepared.PixelHeight() Or source.sources[0].targetFormat <> prepared.PixelFormat() Then
			Throw "Max2D SceneEffects: bloom source differs from layout"
		End If

		Return processor.Update(source)
	End Method
	Rem
	bbdoc: Releases bloom storage while retaining settings; safe to call repeatedly.
	End Rem
	Method ReleaseResources()
		If processor Then
			processor.Release()
		End If

		processor = Null; prepared = Null
	End Method

	Private
	Method Matches:Int(layout:TSceneStageLayout)
		Local count:Int = ReductionLevels(layout)
		If Not prepared Or Not processor Then
			Return False
		End If

		Return prepared.PixelWidth() = layout.PixelWidth() And prepared.PixelHeight() = layout.PixelHeight() And prepared.PixelFormat() = layout.PixelFormat() And count = levels
	End Method

	Method ReductionLevels:Int(layout:TSceneStageLayout)
		If Not layout Then
			Throw "Max2D SceneEffects: layout is null"
		End If

		Local w:Int = layout.PixelWidth(), h:Int = layout.PixelHeight(), count:Int
		Local pixels:Float = radius * layout.ResolutionScale()
		If IsInf(pixels) Then
			Throw "Max2D SceneEffects: bloom radius overflow"
		End If

		While pixels * Float(w) / layout.PixelWidth() > 4 Or pixels * Float(h) / layout.PixelHeight() > 4
			If w = 1 And h = 1 Then
				Throw "Max2D SceneEffects: bloom radius exceeds canvas"
			End If

			w = w / 2 + w Mod 2; h = h / 2 + h Mod 2; count :+ 1
		Wend

		Return count
	End Method
End Type
