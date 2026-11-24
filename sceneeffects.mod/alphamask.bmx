Rem
bbdoc: Applies an image's alpha in a local rectangle, optionally cutting it out instead.
about: Uses two retained full-canvas images and checked layer blending, without shaders or readback. The shared mask image remains caller-owned; call Invalidate after editing it. Stage order determines whether earlier effects are masked or later effects extend beyond the mask. Bounds are unchanged. Picking is unchanged until SetInputMask supplies a CPU snapshot.
End Rem
Type TSceneAlphaMaskStage Extends TSceneEffectStage
	Private
	Field drawState:TMax2DState = New TMax2DState
	Field mask:TImage
	Field rect:TSceneRect
	Field inverted:Int
	Field input:TPixmap
	Field threshold:Int = 1
	Field buffers:TMax2DEffectBuffers
	Field prepared:TSceneStageLayout
	Field canvas:TSceneRect = New TSceneRect
	Public
	Rem
	bbdoc: Creates an alpha-mask stage mapping frame zero across a copied local rectangle.
	param: Required shared alpha-mask image; frame zero is used and image handles are ignored.
	param: Finite group-local rectangle, copied by this call; dimensions must be nonnegative.
	param: True for inverse cutout, False to retain coverage inside the mask.
	returns: A new #TSceneAlphaMaskStage instance configured with the supplied settings.
	about: Image handles are ignored. Outside the rectangle coverage is zero: normal masks erase it and inverted masks retain it. Zero-area rectangles are allowed. No graphics resources are allocated here.
	End Rem
	Function Create:TSceneAlphaMaskStage(mask:TImage, rect:TSceneRect, inverted:Int = False)
		Local result:TSceneAlphaMaskStage = New TSceneAlphaMaskStage
		result.SetMask(mask, rect, inverted)
		Return result
	End Function
	Rem
	bbdoc: Replaces the shared image, copied local rectangle and inversion, clearing any input snapshot.
	param: Borrowed image; its lifetime remains application-owned.
	param: Finite group-local rectangle, copied by this call; dimensions must be nonnegative.
	param: True for inverse cutout, False to retain coverage inside the mask.
	about: Invalidates attached composites. Invalid arguments leave the previous configuration unchanged. Call SetInputMask again if picking should follow the new mask.
	End Rem
	Method SetMask(image:TImage, region:TSceneRect, inverse:Int = False)
		If Not image Or image.width < 1 Or image.height < 1 Then
			Throw "Max2D SceneEffects: invalid alpha mask image"
		End If

		CheckStageRect(region)
		Invalidate()
		If Not rect Then
			rect = New TSceneRect
		End If

		CopyStageRect(region, rect)
		mask = image;inverted = inverse;input = Null
	End Method
	Rem
	bbdoc: Moves or resizes the local mask rectangle, preserving the image and input snapshot.
	param: Finite group-local rectangle, copied by this call; dimensions must be nonnegative.
	about: Copies into retained storage without allocation after initial configuration. Invalidates processed pixels without recapturing unchanged children.
	End Rem
	Method SetMaskRect(region:TSceneRect)
		CheckStageRect(region)
		If Not mask Then
			Throw "Max2D SceneEffects: configure alpha mask before its rectangle"
		End If

		Invalidate();CopyStageRect(region, rect)
	End Method
	Rem
	bbdoc: Switches normal masking and inverted cutout while retaining the CPU input snapshot.
	param: True for inverse cutout, False for normal alpha masking.
	End Rem
	Method SetInverted(value:Int)
		Invalidate();inverted = value
	End Method
	Rem
	bbdoc: Copies a CPU alpha mask for local input tests, or disables mask picking when Null.
	param: CPU alpha artwork to copy; Null disables alpha-mask picking.
	param: Inclusive alpha threshold from 1 to 255.
	about: Coverage is sampled by nearest texel over the mask rectangle, independent of capture resolution. Any positive pixmap dimensions are accepted. Alpha after inversion must be at least threshold (1..255). This explicit snapshot may differ from filtered rendering or later effects; refresh it after artwork edits. No GPU readback occurs. Captured pointers continue outside the mask. CPU snapshot bytes are not texture-budget charges.
	End Rem
	Method SetInputMask(pixmap:TPixmap, threshold:Int = 1)
		If threshold < 1 Or threshold > 255 Then
			Throw "Max2D SceneEffects: input alpha threshold must be 1..255"
		End If

		Local copy:TPixmap
		If pixmap Then
			If Not rect Then
				Throw "Max2D SceneEffects: configure alpha mask before input coverage"
			End If

			If pixmap.width < 1 Or pixmap.height < 1 Then
				Throw "Max2D SceneEffects: input mask must have positive dimensions"
			End If

			copy = pixmap.Copy()
		End If

		Invalidate();input = copy;Self.threshold = threshold
	End Method
	Rem
	bbdoc: Tests optional CPU alpha coverage in group-local coordinates without allocation.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	returns: True when the point passes this input test, False otherwise.
	End Rem
	Method HitTestInputClip:Int(x:Float, y:Float) Override
		If Not input Then
			Return True
		End If

		Local alpha:Int
		If x >= rect.x And y >= rect.y And Double(x) < Double(rect.x) + rect.width And Double(y) < Double(rect.y) + rect.height Then
			Local px:Int = Min(input.width - 1, Int((Double(x) - rect.x) / rect.width * input.width))
			Local py:Int = Min(input.height - 1, Int((Double(y) - rect.y) / rect.height * input.height))
			alpha = (input.ReadPixel(px, py) Shr 24) & 255
		End If

		If inverted Then
			alpha = 255 - alpha
		End If

		Return alpha >= threshold
	End Method
	Rem
	bbdoc: Preserves input bounds; the mask does not enlarge or shrink the capture canvas.
	param: Finite logical input rectangle; may be the same object as output.
	param: Required reusable destination rectangle.
	End Rem
	Method ExpandBounds(input:TSceneRect, output:TSceneRect)
		CheckStageRect(input)
		If Not output Then
			Throw "Max2D SceneEffects: bounds destination is null"
		End If

		CopyStageRect(input, output)
	End Method
	Rem
	bbdoc: Estimates two full-canvas render images, excluding the shared mask and optional CPU snapshot.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Estimated owned texture bytes for the complete replacement layout, excluding driver overhead.
	End Rem
	Method EstimateStorageBytes:Long(layout:TSceneStageLayout)
		If Not layout Then
			Throw "Max2D SceneEffects: layout is null"
		End If

		Return layout.EstimateImageBytes(2)
	End Method
	Rem
	bbdoc: Reports zero extra bytes when existing textures match the requested pixel layout.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Additional peak texture bytes required during preparation; zero when retained storage can be reused.
	End Rem
	Method EstimatePreparationBytes:Long(layout:TSceneStageLayout) Override
		If Reuses(layout) Then
			Return 0
		End If

		Return EstimateStorageBytes(layout)
	End Method
	Rem
	bbdoc: Prepares retained targets and validates layer-alpha blending on the actual output format.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	End Rem
	Method Prepare(layout:TSceneStageLayout)
		EstimateStorageBytes(layout)
		If Not mask Then
			Throw "Max2D SceneEffects: configure alpha mask before preparation"
		End If

		If Reuses(layout) Then
			CheckBlend(buffers.Image(0));prepared = layout;layout.CopyCanvasRect(canvas)
			Return
		End If

		Local candidate:TMax2DEffectBuffers = New TMax2DEffectBuffers
		Try
			candidate.Prepare(layout.PixelWidth(), layout.PixelHeight(), 2, -1, layout.PixelFormat())
			CheckBlend(candidate.Image(0))
			If buffers Then
				buffers.Release()
			End If
		Catch error:Object
			candidate.Release()
			Throw error
		End Try

		buffers = candidate;prepared = layout;layout.CopyCanvasRect(canvas)
	End Method
	Rem
	bbdoc: Returns distinct masked output while preserving source pixels and caller drawing state.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Warm updates allocate no textures. Source must match the prepared layout and must not alias either owned target; the shared mask must also be distinct from both targets.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		If Not prepared Or Not buffers Then
			Throw "Max2D SceneEffects: prepare alpha mask before update"
		End If

		Local output:TRenderImage = buffers.Image(0), coverage:TRenderImage = buffers.Image(1)
		If Not source Or source = output Or source = coverage Or mask = output Or mask = coverage Then
			Throw "Max2D SceneEffects: alpha mask target alias"
		End If

		If source.width <> prepared.PixelWidth() Or source.height <> prepared.PixelHeight() Or source.sources[0].targetFormat <> prepared.PixelFormat() Then
			Throw "Max2D SceneEffects: alpha mask source differs from layout"
		End If

		Local graphics:TMax2DGraphics = TMax2DGraphics.Current()
		Local callerState:TMax2DState = graphics.state
		Local callerTarget:TRenderImage = graphics.renderImage
		Local scope:TMax2DStateScope
		' An owned target selected by the caller needs its view restored as well.
		If callerTarget = output Or callerTarget = coverage Then
			scope = ScopedMax2DState()
		End If

		graphics.state = drawState
		Try
			SetRenderImage(coverage)
			' Both passes establish their complete view and drawing state.
			SetVirtualResolution(coverage.width, coverage.height);SetViewport(0, 0, coverage.width, coverage.height)
			SetCamera(Null);ResetCoordinates();SetAffineTransform(1, 0, 0, 1);SetOrigin(0, 0);SetHandle(0, 0)
			SetClsColor(0, 0, 0, 0);Cls;SetColor(255, 255, 255);SetAlpha(1);SetBlend(SOLIDBLEND)
			Local scale:Int = prepared.ResolutionScale()
			If rect.width > 0 And rect.height > 0 Then
				TMax2DGraphics.Current().DrawImageRegion(mask, (rect.x - canvas.x) * scale, (rect.y - canvas.y) * scale, rect.width * scale, rect.height * scale, 0, 0, mask.width, mask.height, 0, 0)
			End If

			SetRenderImage(output)
			SetVirtualResolution(output.width, output.height);SetViewport(0, 0, output.width, output.height)
			SetCamera(Null);ResetCoordinates();SetAffineTransform(1, 0, 0, 1);SetOrigin(0, 0);SetHandle(0, 0)
			SetColor(255, 255, 255);SetAlpha(1);SetBlend(SOLIDBLEND)
			DrawImage(source, source.handle_x, source.handle_y)
			If inverted Then ApplyLayerInverseAlphaMask(coverage) Else ApplyLayerAlphaMask(coverage)
		Finally
			graphics.state = callerState
			If scope Then
				scope.Close()
			Else If Not graphics.context.closed Then
				graphics.SetRenderImage(callerTarget)
			End If
		End Try

		Return output
	End Method
	Rem
	bbdoc: Releases owned GPU storage while retaining configuration and the CPU input snapshot.
	End Rem
	Method ReleaseResources()
		If buffers Then
			buffers.Release()
		End If

		buffers = Null;prepared = Null
	End Method

	Private
	Method Reuses:Int(layout:TSceneStageLayout)
		Return buffers And prepared And layout And prepared.PixelWidth() = layout.PixelWidth() And prepared.PixelHeight() = layout.PixelHeight() And prepared.PixelFormat() = layout.PixelFormat()
	End Method

	Method CheckBlend(target:TRenderImage)
		Local graphics:TMax2DGraphics = TMax2DGraphics.Current()
		Local previous:TRenderImage = graphics.renderImage
		Try
			SetRenderImage(target)
			If inverted Then
				If Not Max2DSupportsLayerInverseAlpha() Then
					Throw "Max2D SceneEffects: inverse alpha masks unsupported"
				End If
			Else
				If Not Max2DSupportsLayerAlpha() Then
					Throw "Max2D SceneEffects: alpha masks unsupported"
				End If
			End If
		Finally
			If Not graphics.context.closed Then
				graphics.SetRenderImage(previous)
			End If
		End Try
	End Method
End Type
