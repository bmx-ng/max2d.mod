Rem
bbdoc: Retained source-plus-soft-shadow stage with logical radius and offset.
about: Draws the coloured shadow behind the original source. Padding includes blur sampling and offset. Uses ordinary alpha composition and retains transparent unused pixels. Settings invalidate processing; unchanged layouts reuse storage.
End Rem
Type TSceneShadowStage Extends TSceneEffectStage
	Internal
	Field inner:Int
	Private
	Field radius:Float = 8, offsetX:Float = 3, offsetY:Float = 3, opacity:Float = 0.5
	Field fixedPadding:Float = -1
	Field red:Int, green:Int, blue:Int
	Field shadow:TMax2DShadow
	Field inset:TMax2DInnerShadow
	Field output:TMax2DEffectBuffers
	Field prepared:TSceneStageLayout
	Field levels:Int
	Field preparedRevision:Long
	Field context:TMax2DContext
	Field colourSupport:TMax2DColorizeEffect = CreateColorizeEffect()
	Field blurSupport:TMax2DBlurEffect = CreateBlurEffect()
	Public
	Rem
	bbdoc: Creates a source-plus-shadow stage without allocating graphics resources.
	param: Finite nonnegative radius in logical scene units.
	param: Finite horizontal offset in logical scene units.
	param: Finite vertical offset in logical scene units.
	returns: A new #TSceneShadowStage instance configured with the supplied settings.
	End Rem
	Function Create:TSceneShadowStage(radius:Float = 8, offsetX:Float = 3, offsetY:Float = 3)
		Local result:TSceneShadowStage = New TSceneShadowStage
		result.SetRadius(radius);result.SetOffset(offsetX, offsetY)
		Return result
	End Function
	Rem
	bbdoc: Sets a finite nonnegative radius in logical units.
	param: Finite nonnegative blur radius in logical scene units.
	End Rem
	Method SetRadius(value:Float)
		CheckStagePadding(value)
		If radius = value Then
			Return
		End If

		Invalidate();radius = value
	End Method
	Rem
	bbdoc: Returns the logical blur radius.
	returns: The logical blur radius.
	End Rem
	Method GetRadius:Float();Return radius;End Method
	Rem
	bbdoc: Sets finite offsets in logical units; positive values shift the silhouette right/down.
	param: Finite horizontal coordinate in consumer-local logical units.
	param: Finite vertical coordinate in consumer-local logical units.
	End Rem
	Method SetOffset(x:Float, y:Float)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then
			Throw "Max2D SceneEffects: shadow offset must be finite"
		End If

		If offsetX = x And offsetY = y Then
			Return
		End If

		Invalidate();offsetX = x;offsetY = y
	End Method
	Rem
	bbdoc: Returns the horizontal logical offset.
	returns: The horizontal logical offset.
	End Rem
	Method GetOffsetX:Float();Return offsetX;End Method
	Rem
	bbdoc: Returns the vertical logical offset.
	returns: The vertical logical offset.
	End Rem
	Method GetOffsetY:Float();Return offsetY;End Method
	Rem
	bbdoc: Sets shadow RGB components in 0..255 and opacity in 0..1; defaults to half-opacity black.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	param: Opacity multiplier in the inclusive range 0..1.
	about: Does not tint the source. Changes processing without recapturing unchanged artwork when the layout is unchanged.
	End Rem
	Method SetShadowColor(r:Int, g:Int, b:Int, alpha:Float = 0.5)
		If r < 0 Or r > 255 Or g < 0 Or g > 255 Or b < 0 Or b > 255 Or IsNan(alpha) Or IsInf(alpha) Or alpha < 0 Or alpha > 1 Then
			Throw "Max2D SceneEffects: invalid shadow colour"
		End If

		If red = r And green = g And blue = b And opacity = alpha Then
			Return
		End If

		Invalidate();red = r;green = g;blue = b;opacity = alpha
	End Method
	Rem
	bbdoc: Returns the shadow red component.
	returns: The shadow red component.
	End Rem
	Method GetRed:Int();Return red;End Method
	Rem
	bbdoc: Returns the shadow green component.
	returns: The shadow green component.
	End Rem
	Method GetGreen:Int();Return green;End Method
	Rem
	bbdoc: Returns the shadow blue component.
	returns: The shadow blue component.
	End Rem
	Method GetBlue:Int();Return blue;End Method
	Rem
	bbdoc: Returns shadow opacity.
	returns: Shadow opacity.
	End Rem
	Method GetOpacity:Float();Return opacity;End Method
	Rem
	bbdoc: Reserves fixed symmetric logical padding for animated radius or offsets.
	param: Finite nonnegative symmetric padding in logical scene units.
	about: Bounds validation rejects settings that need more padding. ClearPadding restores automatic sizing. Fixed padding keeps the stage extent stable while settings remain within it.
	End Rem
	Method SetPadding(value:Float)
		CheckStagePadding(value)
		If fixedPadding = value Then
			Return
		End If

		Invalidate();fixedPadding = value
	End Method
	Rem
	bbdoc: Restores automatic blur and offset padding.
	End Rem
	Method ClearPadding()
		If fixedPadding < 0 Then
			Return
		End If

		Invalidate();fixedPadding = -1
	End Method
	Rem
	bbdoc: Returns fixed logical padding, or -1 for automatic sizing.
	returns: Fixed logical padding, or -1 for automatic sizing.
	End Rem
	Method GetPadding:Float();Return fixedPadding;End Method
	Rem
	bbdoc: Reserves blur sampling and offset padding; accepts aliased rectangles.
	param: Finite logical input rectangle; may be the same object as output.
	param: Required reusable destination rectangle.
	about: Inner shadows also reserve sampling space, but leave pixels outside source coverage transparent. Fixed stage padding can reserve a stable extent for animation.
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

		Local left:Float = padding + Max(0.0:Float, -offsetX), top:Float = padding + Max(0.0:Float, -offsetY)
		Local right:Float = padding + Max(0.0:Float, offsetX), bottom:Float = padding + Max(0.0:Float, offsetY)
		If fixedPadding >= 0 Then
			If fixedPadding < left Or fixedPadding < top Or fixedPadding < right Or fixedPadding < bottom Then
				Throw "Max2D SceneEffects: fixed shadow padding is too small"
			End If

			left = fixedPadding;top = fixedPadding;right = fixedPadding;bottom = fixedPadding
		End If

		Local x:Float = input.x - left, y:Float = input.y - top, w:Float = input.width + left + right, h:Float = input.height + top + bottom
		If IsInf(x) Or IsInf(y) Or IsInf(w) Or IsInf(h) Then
			Throw "Max2D SceneEffects: shadow bounds overflow"
		End If

		output.x = x;output.y = y;output.width = w;output.height = h
	End Method
	Rem
	bbdoc: Estimates helper images, combined output, reduction levels and blur scratch.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Estimated owned texture bytes for the complete replacement layout, excluding driver overhead.
	End Rem
	Method EstimateStorageBytes:Long(layout:TSceneStageLayout)
		Local count:Int = ReductionLevels(layout)
		Local bytes:Long = layout.EstimateImageBytes(3 + inner)
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
				Throw "Max2D SceneEffects: shadow storage overflow"
			End If

			bytes :+ extra
		Next

		If count > 0 Then
			Local extra:Long = Long(w) * h * bpp
			If bytes > $7fffffffffffffff:Long - extra Then
				Throw "Max2D SceneEffects: shadow storage overflow"
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
	bbdoc: Prepares retained helper/output buffers and checks effects on the actual target format.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	about: Radius and offset are scaled exactly once. Changed layouts are prepared before replacing existing storage. Release before switching live contexts.
	End Rem
	Method Prepare(layout:TSceneStageLayout)
		EstimateStorageBytes(layout)
		Local current:TMax2DContext = TMax2DGraphics.Current().context
		If context And context <> current And Not context.closed Then
			Throw "Max2D SceneEffects: release shadow before changing live contexts"
		End If

		Local count:Int = ReductionLevels(layout), scale:Float = layout.ResolutionScale()
		If IsInf(offsetX * scale) Or IsInf(offsetY * scale) Then
			Throw "Max2D SceneEffects: shadow offset overflow"
		End If

		If Matches(layout) And context = current Then
			Validate(output.Image(0))
			If inner Then
				inset.SetRadius(radius * scale);inset.SetOffset(offsetX * scale, offsetY * scale)
				inset.Prepare(layout.PixelWidth(), layout.PixelHeight(), count, layout.PixelFormat())
			Else
				shadow.SetRadius(radius * scale)
				shadow.Prepare(layout.PixelWidth(), layout.PixelHeight(), count, layout.PixelFormat())
			End If
		Else
			Local candidate:TMax2DEffectBuffers = New TMax2DEffectBuffers
			Local nextShadow:TMax2DShadow, nextInset:TMax2DInnerShadow
			Try
				candidate.Prepare(layout.PixelWidth(), layout.PixelHeight(), 1, -1, layout.PixelFormat())
				Validate(candidate.Image(0))
				If inner Then
					nextInset = CreateInnerShadow(radius * scale, offsetX * scale, offsetY * scale)
					nextInset.Prepare(layout.PixelWidth(), layout.PixelHeight(), count, layout.PixelFormat())
				Else
					nextShadow = CreateShadow(radius * scale)
					nextShadow.Prepare(layout.PixelWidth(), layout.PixelHeight(), count, layout.PixelFormat())
				End If

				ReleaseResources()
			Catch error:Object
				candidate.Release()
				If nextShadow Then
					nextShadow.Release()
				End If

				If nextInset Then
					nextInset.Release()
				End If

				Throw error
			End Try

			output = candidate;shadow = nextShadow;inset = nextInset
		End If

		prepared = layout;levels = count;context = current;preparedRevision = Revision()
	End Method
	Rem
	bbdoc: Returns borrowed source-plus-shadow output, preserving source and caller state.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Requires preparation after settings changes. Outer shadows draw behind the source; inner shadows overlay it. Ordinary source-over composition can increase alpha on translucent source pixels. Zero opacity copies the source. Warm updates allocate no textures.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		If Not prepared Or preparedRevision <> Revision() Then
			Throw "Max2D SceneEffects: prepare shadow after configuration changes"
		End If

		Local destination:TRenderImage = output.Image(0)
		If Not source Or source = destination Then
			Throw "Max2D SceneEffects: shadow source must be distinct"
		End If

		If source.width <> prepared.PixelWidth() Or source.height <> prepared.PixelHeight() Or source.sources[0].targetFormat <> prepared.PixelFormat() Then
			Throw "Max2D SceneEffects: shadow source differs from layout"
		End If

		Local mask:TRenderImage
		If opacity > 0 Then
			If inner Then mask = inset.Update(source) Else mask = shadow.Update(source)
		End If

		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			SetRenderImage(destination)
			Local view:TMax2DStateScope = ScopedMax2DState()
			Try
				SetVirtualResolution(destination.width, destination.height);SetViewport(0, 0, destination.width, destination.height)
				SetCamera(Null);ResetCoordinates();SetAffineTransform(1, 0, 0, 1)
				SetOrigin(0, 0);SetHandle(0, 0);SetClsColor(0, 0, 0, 0);Cls
				SetBlend(ALPHABLEND)
				If mask And Not inner Then
					DrawMask(mask, offsetX * prepared.ResolutionScale(), offsetY * prepared.ResolutionScale())
				End If

				SetColor(255, 255, 255);SetAlpha(1)
				DrawImage(source, source.handle_x, source.handle_y)
				If mask And inner Then
					DrawMask(mask, 0, 0)
				End If
			Finally
				view.Close()
			End Try
		Finally
			scope.Close()
		End Try

		Return destination
	End Method
	Rem
	bbdoc: Releases owned images while retaining settings; repeated calls are harmless.
	End Rem
	Method ReleaseResources()
		If output Then
			output.Release()
		End If

		If shadow Then
			shadow.Release()
		End If

		If inset Then
			inset.Release()
		End If

		output = Null;shadow = Null;inset = Null;prepared = Null;context = Null
	End Method

	Private
	Method DrawMask(mask:TRenderImage, x:Float, y:Float)
		SetColor(red, green, blue);SetAlpha(opacity)
		DrawImage(mask, x + mask.handle_x, y + mask.handle_y)
	End Method

	Method Validate(target:TRenderImage)
		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			SetRenderImage(target);SetBlend(SOLIDBLEND)
			If Not Max2DSupportsImageEffect(colourSupport) Or Not Max2DSupportsImageEffect(blurSupport) Then
				Throw "Max2D SceneEffects: shadow effects unsupported"
			End If

			If inner And Not Max2DSupportsLayerInverseAlpha() Then
				Throw "Max2D SceneEffects: inner shadow blend unsupported"
			End If

			If Not Max2DSupportsBlend(ALPHABLEND) Then
				Throw "Max2D SceneEffects: shadow composition unsupported"
			End If
		Finally
			scope.Close()
		End Try
	End Method

	Method Matches:Int(layout:TSceneStageLayout)
		Local count:Int = ReductionLevels(layout)
		If Not prepared Or Not output Then
			Return False
		End If

		If context And context.closed Then
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
			Throw "Max2D SceneEffects: shadow radius overflow"
		End If

		While pixels * Float(w) / layout.PixelWidth() > 4 Or pixels * Float(h) / layout.PixelHeight() > 4
			If w = 1 And h = 1 Then
				Throw "Max2D SceneEffects: shadow radius exceeds canvas"
			End If

			w = w / 2 + w Mod 2; h = h / 2 + h Mod 2; count :+ 1
		Wend

		Return count
	End Method
End Type

Rem
bbdoc: Retained source-plus-inner-shadow stage using the source alpha silhouette.
about: Overlays the coloured inner shadow on the source, with ordinary source-over alpha composition. Positive offset exposes shadow along left/top edges. Pixels outside source coverage stay transparent. Inherits logical radius, offset, colour and storage controls from TSceneShadowStage.
End Rem
Type TSceneInnerShadowStage Extends TSceneShadowStage
	Rem
	bbdoc: Creates a source-plus-inner-shadow description without graphics resources.
	param: Finite nonnegative radius in logical scene units.
	param: Finite horizontal offset in logical scene units.
	param: Finite vertical offset in logical scene units.
	returns: A new #TSceneInnerShadowStage instance configured with the supplied settings.
	End Rem
	Function Create:TSceneInnerShadowStage(radius:Float = 8, offsetX:Float = 3, offsetY:Float = 3)
		Local result:TSceneInnerShadowStage = New TSceneInnerShadowStage
		result.inner = True
		result.SetRadius(radius);result.SetOffset(offsetX, offsetY)
		Return result
	End Function
End Type
