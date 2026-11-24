Rem
bbdoc: Reusable inner shadow clipped to a layer's alpha coverage.
about: Update caches white coverage equal to source alpha times one minus the offset blurred alpha. Draw the source first, then tint Result with ordinary SetColor and SetAlpha. Radius and offset changes require Update; colour and opacity changes do not. The source is not included in the result. Pad source content for blur sampling. Borrowed results must not be independently released or retained across changed Prepare, Release or context closure. Source changes are not detected automatically.
End Rem
Type TMax2DInnerShadow
	Private
	Field buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
	Field silhouette:TMax2DColorizeEffect = CreateColorizeEffect()
	Field extraction:TMax2DImageEffect[] = [TMax2DImageEffect(silhouette)]
	Field blur:TMax2DScaledBlur = CreateScaledBlur(8)
	Field blurSupport:TMax2DBlurEffect = CreateBlurEffect()
	Field cached:TRenderImage
	Field valid:Int
	Field offsetX:Float = 3, offsetY:Float = 3
	Field width:Int, height:Int, smallestWidth:Int, smallestHeight:Int

	Public
	Rem
	bbdoc: Prepares three full-size images and retained blur storage on the current context.
	param: Positive source width.
	param: Positive source height.
	param: Number of ceil-halved reduction levels; zero uses full-resolution blur.
	param: Supported render-image format; RGBA8888 by default, or floating-point for finer alpha precision.
	about: The current radius must fit the pyramid. Identical preparation preserves the cached result; a changed layout invalidates it. Buffer-owner context, resize and release rules apply. Result requires a successful Update on the new layout.
	End Rem
	Method Prepare(width:Int, height:Int, reductionLevels:Int = 2, pixelFormat:Int = PF_RGBA8888)
		If width <= 0 Or height <= 0 Or reductionLevels < 0 Then Throw "Max2D Effects: invalid inner-shadow layout"
		Local w:Int = width, h:Int = height
		For Local i:Int = 0 Until reductionLevels
			If w = 1 And h = 1 Then Throw "Max2D Effects: too many inner-shadow reduction levels"
			w = w/2+w Mod 2; h = h/2+h Mod 2
		Next
		CheckRadius(width, height, w, h)
		buffers.Prepare(width, height, 3, reductionLevels, pixelFormat)
		Local image:TRenderImage = buffers.Image(2)
		If image <> cached Then valid = False
		cached = image
		Self.width = width; Self.height = height
		smallestWidth = w; smallestHeight = h
	End Method

	Rem
	bbdoc: Sets a finite nonnegative blur radius in full-resolution source pixels.
	param: Finite nonnegative blur radius in full-resolution source pixels.
	about: Takes effect on the next Update. Prepare and Update check that the radius fits the pyramid. Zero still resamples with reduction levels; use zero levels to avoid blur resampling.
	End Rem
	Method SetRadius(value:Float)
		blur.SetRadius(value)
	End Method

	Rem
	bbdoc: Returns the requested inner-shadow radius.
	returns: The requested inner-shadow radius.
	End Rem
	Method GetRadius:Float()
		Return blur.GetRadius()
	End Method

	Rem
	bbdoc: Sets finite shadow offsets in source pixels, applied on the next Update.
	param: Finite horizontal coordinate in caller drawing coordinates.
	param: Finite vertical coordinate in caller drawing coordinates.
	about: Positive x/y shifts the blurred silhouette right/down, exposing inner shadow along the left/top edges. Both values are validated before changing either. Cached pixels remain unchanged until Update.
	End Rem
	Method SetOffset(x:Float, y:Float)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then Throw "Max2D Effects: inner-shadow offsets must be finite"
		offsetX = x; offsetY = y
	End Method

	Rem
	bbdoc: Returns the horizontal offset in source pixels.
	returns: The horizontal offset in source pixels.
	End Rem
	Method GetOffsetX:Float()
		Return offsetX
	End Method

	Rem
	bbdoc: Returns the vertical offset in source pixels.
	returns: The vertical offset in source pixels.
	End Rem
	Method GetOffsetY:Float()
		Return offsetY
	End Method

	Rem
	bbdoc: Rebuilds and returns borrowed white inner-shadow coverage, preserving source pixels.
	param: Source render image matching the prepared dimensions, distinct from the cached result.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Source RGB is ignored. Drawing state and target views are restored. Source handles and transforms do not affect extraction. Parameters and shader support are checked before output writes; a later failure invalidates the result. Updates allocate state scopes but no images, arrays or effect descriptions. Source alpha, radius and offset changes require rebuilding. The result is bounded by source coverage and has no shadow outside it.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		Local destination:TRenderImage = buffers.Image(2)
		If Not source Then Throw "Max2D Effects: inner-shadow source is null"
		If source = destination Then Throw "Max2D Effects: inner-shadow cannot sample its cached result"
		If source.width <> width Or source.height <> height Then Throw "Max2D Effects: inner-shadow source dimensions must match prepared buffers"
		CheckRadius(width, height, smallestWidth, smallestHeight)
		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			SetBlend(SOLIDBLEND)
			source.Frame(0, TMax2DGraphics.Current())
			CheckScaledBlurTarget(buffers.Image(0), silhouette)
			CheckScaledBlurTarget(buffers.Image(1), blurSupport)
			CheckScaledBlurTarget(destination)
			If Not Max2DSupportsLayerInverseAlpha() Then Throw "Max2D Effects: inner-shadow inverse-alpha blend unsupported"
			valid = False
			buffers.ApplyChain(source, 0, extraction)
			buffers.ApplyBlur(buffers.Image(0), 1, blur)
			SetCamera(Null)
			ResetCoordinates()
			SetAffineTransform(1, 0, 0, 1)
			SetOrigin(0, 0)
			SetHandle(0, 0)
			SetColor(255, 255, 255)
			SetAlpha(1)
			Local destinationScope:SLayerTargetView = PrepareChainTarget(destination)
			Try
				SetBlend(SOLIDBLEND)
				Local coverage:TRenderImage = buffers.Image(0)
				DrawImage(coverage, coverage.handle_x, coverage.handle_y)
				SetBlend(inverseAlphaMultiplyBlend)
				Local blurred:TRenderImage = buffers.Image(1)
				DrawImage(blurred, offsetX+blurred.handle_x, offsetY+blurred.handle_y)
			Finally
				destinationScope.Close()
			End Try
			valid = True
		Finally
			scope.Close()
		End Try
		Return destination
	End Method

	Rem
	bbdoc: Returns the cached borrowed white shadow without rendering.
	returns: The cached borrowed white shadow without rendering.
	about: Throws before a successful Update, after changed layout or release, or on the wrong or closed context. Radius and offset changes keep the previous result. Tint and opacity are normal drawing settings; draw the source first, then the shadow at the same position.
	End Rem
	Method Result:TRenderImage()
		Local image:TRenderImage = buffers.Image(2)
		If Not valid Then Throw "Max2D Effects: inner-shadow result requires a successful Update"
		Return image
	End Method

	Rem
	bbdoc: Releases retained images and invalidates the result, retaining radius and offset settings.
	about: Select another target before releasing if the result is active. Repeated calls are harmless.
	End Rem
	Method Release()
		buffers.Release()
		cached = Null; valid = False
		width = 0; height = 0; smallestWidth = 0; smallestHeight = 0
	End Method

	Private
	Method CheckRadius(w:Int, h:Int, sw:Int, sh:Int)
		If blur.GetRadius()*Float(sw)/w > 4 Or blur.GetRadius()*Float(sh)/h > 4 Then Throw "Max2D Effects: inner-shadow radius requires more reduction levels"
	End Method
End Type

Rem
bbdoc: Creates a reusable inner-shadow description without allocating graphics resources.
param: Finite, nonnegative blur radius in source pixels; defaults to eight.
param: Finite horizontal offset in source pixels; defaults to three.
param: Finite vertical offset in source pixels; defaults to three.
returns: A new #TMax2DInnerShadow instance configured with the supplied settings.
End Rem
Function CreateInnerShadow:TMax2DInnerShadow(radius:Float = 8, offsetX:Float = 3, offsetY:Float = 3)
	Local shadow:TMax2DInnerShadow = New TMax2DInnerShadow
	shadow.SetRadius(radius)
	shadow.SetOffset(offsetX, offsetY)
	Return shadow
End Function
