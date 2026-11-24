Rem
bbdoc: Reusable description of a blur performed at a caller-selected resolution.
about: Radius is measured in full-resolution source pixels. Reduction and enlargement add filtering, so this is an approximation rather than the full-resolution kernel. Retain the descriptor and caller-owned images across frames.
End Rem
Type TMax2DScaledBlur
	Private
	Field drawingState:TLayerDrawingState=New TLayerDrawingState
	Field radius:Float = 8
	Field horizontal:TMax2DBlurEffect = CreateBlurEffect()
	Field vertical:TMax2DBlurEffect = CreateBlurEffect(4, False)

	Public
	Rem
	bbdoc: Sets a finite, nonnegative radius in full-resolution source pixels.
	param: Finite nonnegative blur radius in full-resolution source pixels.
	about: Apply checks that the supplied reduction levels can accommodate this radius. Zero still performs reduction/enlargement when levels are supplied; use no levels for an identity blur.
	End Rem
	Method SetRadius(value:Float)
		If value < 0 Or IsNan(value) Or IsInf(value) Then Throw "Max2D Effects: scaled blur radius must be finite and nonnegative"
		radius = value
	End Method

	Rem
	bbdoc: Returns the requested radius in source pixels.
	returns: The requested radius in source pixels.
	End Rem
	Method GetRadius:Float()
		Return radius
	End Method

	Rem
	bbdoc: Reduces a layer, blurs at reduced resolution and enlarges into the destination.
	param: Premultiplied source layer, left unchanged.
	param: Distinct destination with the same dimensions as source.
	param: Retained reduction images in largest-to-smallest order, each dimension rounded up after halving the preceding image. An empty array runs the blur at full resolution.
	param: Retained scratch image matching the smallest level, or source when there are no levels.
	about: The radius must fit a four-pixel kernel in both dimensions at the selected resolution. All images must be distinct. Source, levels and scratch require FILTEREDIMAGE without MIPMAPPEDIMAGE. The operation makes one draw per reduction, two blur draws and one enlargement when levels exist. Warm calls reuse private drawing state and allocation-free value snapshots for per-pass output views, with no images, arrays or effect descriptions. Reentrant calls use a separate caller scope. Target views and caller drawing state are restored on success and failure. Parameters, images and shader support are validated before pixel writes; a later runtime failure does not roll back pixels. Pad source content to retain the blur halo; reduction uses clamped bilinear sampling and odd dimensions are approximate. Rerun only when content or settings change.
	End Rem
	Method Apply(source:TRenderImage, destination:TRenderImage, levels:TRenderImage[], scratch:TRenderImage)
		If Not source Or Not destination Or Not scratch Then Throw "Max2D Effects: scaled blur requires source, destination, scratch"
		If source = destination Or source = scratch Or destination = scratch Then Throw "Max2D Effects: scaled blur images must be distinct"
		If source.width <> destination.width Or source.height <> destination.height Then Throw "Max2D Effects: scaled blur destination dimensions must match source"
		CheckBlurSampling(source)
		CheckBlurSampling(scratch)
		Local smallest:TRenderImage = source
		For Local i:Int = 0 Until levels.Length
			Local level:TRenderImage = levels[i]
			If Not level Then Throw "Max2D Effects: scaled blur level is null"
			If level = source Or level = destination Or level = scratch Then Throw "Max2D Effects: scaled blur level aliases another image"
			For Local j:Int = 0 Until i
				If level = levels[j] Then Throw "Max2D Effects: scaled blur levels must be distinct"
			Next
			If level.width <> (smallest.width + 1) / 2 Or level.height <> (smallest.height + 1) / 2 Then Throw "Max2D Effects: each scaled blur level must halve the preceding dimensions, rounded up"
			If level.width = smallest.width And level.height = smallest.height Then Throw "Max2D Effects: scaled blur level must reduce image size"
			CheckBlurSampling(level)
			smallest = level
		Next
		If scratch.width <> smallest.width Or scratch.height <> smallest.height Then Throw "Max2D Effects: scaled blur scratch must match the smallest level"
		Local rx:Float = radius * Float(smallest.width) / source.width
		Local ry:Float = radius * Float(smallest.height) / source.height
		If rx > 4 Or ry > 4 Then Throw "Max2D Effects: scaled blur radius requires more reduction levels"
		horizontal.SetRadius(rx)
		vertical.SetRadius(ry)

		Local scope:SLayerDrawingScope = drawingState.Open()
		Try
			SetCamera(Null)
			ResetCoordinates()
			SetAffineTransform(1, 0, 0, 1)
			SetOrigin(0, 0)
			SetHandle(0, 0)
			SetColor(255, 255, 255)
			SetAlpha(1)
			SetBlend(SOLIDBLEND)
			source.Frame(0, TMax2DGraphics.Current())
			For Local level:TRenderImage = EachIn levels
				CheckScaledBlurTarget(level)
			Next
			CheckScaledBlurTarget(scratch, horizontal)
			Local verticalTarget:TRenderImage = destination
			If levels.Length Then verticalTarget = smallest
			CheckScaledBlurTarget(verticalTarget, vertical)
			CheckScaledBlurTarget(destination)
			Local input:TRenderImage = source
			For Local level:TRenderImage = EachIn levels
				ScaledBlurPass(input, level)
				input = level
			Next
			ScaledBlurPass(input, scratch, horizontal)
			ScaledBlurPass(scratch, verticalTarget, vertical)
			If levels.Length Then ScaledBlurPass(smallest, destination)
		Finally
			scope.Close()
		End Try
	End Method
End Type

Rem
bbdoc: Creates a reusable scaled-blur description without allocating images.
param: Finite, nonnegative radius in full-resolution source pixels; defaults to eight.
returns: A new #TMax2DScaledBlur instance configured with the supplied settings.
End Rem
Function CreateScaledBlur:TMax2DScaledBlur(radius:Float = 8)
	Local blur:TMax2DScaledBlur = New TMax2DScaledBlur
	blur.SetRadius(radius)
	Return blur
End Function

Private

Function CheckBlurSampling(image:TRenderImage)
	If Not (image.flags & FILTEREDIMAGE) Or (image.flags & MIPMAPPEDIMAGE) Then Throw "Max2D Effects: scaled blur inputs require filtering without mipmaps"
End Function

Function ScaledBlurPass(source:TRenderImage, target:TRenderImage, effect:TMax2DImageEffect = Null)
	Local scope:SLayerTargetView = PrepareChainTarget(target)
	Try
		If effect Then
			DrawImageEffect(source, effect, source.handle_x, source.handle_y)
		Else
			DrawImageRect(source, source.handle_x, source.handle_y, target.width, target.height)
		End If
	Finally
		scope.Close()
	End Try
End Function

Function CheckScaledBlurTarget(target:TRenderImage, effect:TMax2DImageEffect = Null)
	' Support depends on the target, blend and submission path, not its view.
	' The enclosing operation owns the caller-state scope. Leave this target
	' selected, as PrepareChainTarget/Close did, without modifying its view.
	SetRenderImage(target)
	If effect Then
		If Not Max2DSupportsImageEffect(effect) Then Throw "Max2D Effects: scaled blur unsupported for output target"
	End If
End Function

Public
