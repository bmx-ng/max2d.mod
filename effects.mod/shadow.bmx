Rem
bbdoc: Reusable soft shadow built from a layer's alpha coverage.
about: Update caches a blurred white silhouette in premultiplied storage. Draw Result with ordinary SetColor, SetAlpha and DrawImage to choose shadow colour, opacity and offset without rebuilding. The source is not included in the result. Pad source content to retain the halo.
End Rem
Type TMax2DShadow
	Private
	Field buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
	Field silhouette:TMax2DColorizeEffect = CreateColorizeEffect()
	Field extraction:TMax2DImageEffect[] = [TMax2DImageEffect(silhouette)]
	Field blur:TMax2DScaledBlur = CreateScaledBlur(8)
	Field blurSupport:TMax2DBlurEffect = CreateBlurEffect()
	Field cached:TRenderImage
	Field valid:Int
	Field width:Int, height:Int, smallestWidth:Int, smallestHeight:Int

	Public
	Rem
	bbdoc: Prepares two full-size images and retained blur storage on the current context.
	param: Positive source width.
	param: Positive source height.
	param: Number of ceil-halved reduction levels; zero uses full-resolution blur.
	param: Supported render-image format; RGBA8888 by default, or floating-point for finer alpha precision.
	about: The current radius must fit the pyramid. Identical preparation preserves the cached result; a changed layout invalidates it. Buffer-owner context, resize and release rules apply. Result requires a successful Update on the new layout.
	End Rem
	Method Prepare(width:Int, height:Int, reductionLevels:Int = 2, pixelFormat:Int = PF_RGBA8888)
		If width <= 0 Or height <= 0 Or reductionLevels < 0 Then Throw "Max2D Effects: invalid shadow layout"
		Local w:Int = width, h:Int = height
		For Local i:Int = 0 Until reductionLevels
			If w = 1 And h = 1 Then Throw "Max2D Effects: too many shadow reduction levels"
			w = w/2+w Mod 2; h = h/2+h Mod 2
		Next
		CheckRadius(width, height, w, h)
		buffers.Prepare(width, height, 2, reductionLevels, pixelFormat)
		Local image:TRenderImage = buffers.Image(1)
		If image <> cached Then valid = False
		cached = image
		Self.width = width; Self.height = height
		smallestWidth = w; smallestHeight = h
	End Method

	Rem
	bbdoc: Sets a finite nonnegative blur radius in full-resolution source pixels.
	about: Takes effect on the next Update. Prepare and Update check that the radius fits the pyramid. Zero still resamples with reduction levels; use zero levels for an exact silhouette.
	End Rem
	Method SetRadius(value:Float)
		blur.SetRadius(value)
	End Method

	Rem
	bbdoc: Returns the requested shadow radius.
	End Rem
	Method GetRadius:Float()
		Return blur.GetRadius()
	End Method

	Rem
	bbdoc: Rebuilds and returns a borrowed blurred white silhouette, preserving source pixels.
	param: Source render image matching the prepared dimensions, distinct from the cached result.
	about: Source RGB is ignored. Drawing state and target views are restored. Source handles and transforms do not affect extraction. Parameters and shader support are checked before output writes; a later failure invalidates the result. Updates allocate state scopes but no images, arrays or effect descriptions. Only source alpha or radius changes require rebuilding.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		Local destination:TRenderImage = buffers.Image(1)
		If Not source Then Throw "Max2D Effects: shadow source is null"
		If source = destination Then Throw "Max2D Effects: shadow cannot sample its cached result"
		If source.width <> width Or source.height <> height Then Throw "Max2D Effects: shadow source dimensions must match prepared buffers"
		CheckRadius(width, height, smallestWidth, smallestHeight)
		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			SetBlend(SOLIDBLEND)
			source.Frame(0, TMax2DGraphics.Current())
			CheckScaledBlurTarget(buffers.Image(0), silhouette)
			CheckScaledBlurTarget(destination, blurSupport)
			valid = False
			buffers.ApplyChain(source, 0, extraction)
			buffers.ApplyBlur(buffers.Image(0), 1, blur)
			valid = True
		Finally
			scope.Close()
		End Try
		Return destination
	End Method

	Rem
	bbdoc: Returns the cached borrowed white shadow without rendering.
	about: Throws before a successful Update, after changed layout or release, or on the wrong or closed context. Radius changes alone keep the previous result. Tint, opacity and position are normal drawing settings; draw the source separately after its shadow.
	End Rem
	Method Result:TRenderImage()
		Local image:TRenderImage = buffers.Image(1)
		If Not valid Then Throw "Max2D Effects: shadow result requires a successful Update"
		Return image
	End Method

	Rem
	bbdoc: Releases retained images and invalidates the result, retaining the radius setting.
	about: Select another target before releasing if the result is active. Repeated calls are harmless.
	End Rem
	Method Release()
		buffers.Release()
		cached = Null; valid = False
		width = 0; height = 0; smallestWidth = 0; smallestHeight = 0
	End Method

	Private
	Method CheckRadius(w:Int, h:Int, sw:Int, sh:Int)
		If blur.GetRadius()*Float(sw)/w > 4 Or blur.GetRadius()*Float(sh)/h > 4 Then Throw "Max2D Effects: shadow radius requires more reduction levels"
	End Method
End Type

Rem
bbdoc: Creates a reusable shadow description without allocating graphics resources.
End Rem
Function CreateShadow:TMax2DShadow(radius:Float = 8)
	Local shadow:TMax2DShadow = New TMax2DShadow
	shadow.SetRadius(radius)
	Return shadow
End Function
