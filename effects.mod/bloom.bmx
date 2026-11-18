Rem
bbdoc: Reusable bright-pass, scaled-blur and bloom-composition pipeline.
about: Prepare owns intermediate buffers; Update rebuilds explicitly; Result returns the cached borrowed image. Composition flattens the source over opaque black, then adds bloom, producing an opaque result suitable for final HDR or SDR presentation. Use linear source colours and a floating-point format for HDR. The class does not select a window output mode or tone-map its result.
End Rem
Type TMax2DBloom
	Private
	Field buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
	Field bright:TMax2DBrightPassEffect = CreateBrightPassEffect(1)
	Field blur:TMax2DScaledBlur = CreateScaledBlur(8)
	Field gain:TMax2DLinearOutputEffect = CreateLinearOutputEffect(True)
	Field extraction:TMax2DImageEffect[] = [TMax2DImageEffect(bright)]
	Field cached:TRenderImage
	Field valid:Int
	Field width:Int, height:Int, smallestWidth:Int, smallestHeight:Int

	Public
	Rem
	bbdoc: Prepares three full-size buffers and a blur pyramid on the current context.
	param: Positive source width.
	param: Positive source height.
	param: Number of ceil-halved reduction levels; zero uses full-resolution blur.
	param: Render-image format; defaults to RGBA16F and must be supported by the backend.
	about: The current radius must fit the selected pyramid. An identical layout preserves the cached result. A changed layout invalidates it. Existing buffer-owner context, resize and release rules apply. Call Update before Result on a new layout.
	End Rem
	Method Prepare(width:Int, height:Int, reductionLevels:Int = 2, pixelFormat:Int = PF_RGBA16F)
		If width <= 0 Or height <= 0 Or reductionLevels < 0 Then Throw "Max2D Effects: invalid bloom layout"
		Local w:Int = width, h:Int = height
		For Local i:Int = 0 Until reductionLevels
			If w = 1 And h = 1 Then Throw "Max2D Effects: too many bloom reduction levels"
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
	bbdoc: Sets the finite, nonnegative bright-pass threshold in source colour units.
	about: Takes effect on the next Update; the cached result is unchanged until then.
	End Rem
	Method SetThreshold(value:Float)
		bright.SetThreshold(value)
	End Method
	Rem
	bbdoc: Returns the bright-pass threshold.
	End Rem
	Method GetThreshold:Float()
		Return bright.GetThreshold()
	End Method
	Rem
	bbdoc: Sets the finite, nonnegative blur radius in full-resolution source pixels.
	about: Prepare and Update check that the radius fits the prepared reduction levels. Takes effect on the next Update.
	End Rem
	Method SetRadius(value:Float)
		blur.SetRadius(value)
	End Method
	Rem
	bbdoc: Returns the blur radius.
	End Rem
	Method GetRadius:Float()
		Return blur.GetRadius()
	End Method
	Rem
	bbdoc: Sets finite, nonnegative bloom intensity; one is unchanged glow, zero suppresses it.
	about: Values above one amplify bloom without changing source brightness. Takes effect on the next Update.
	End Rem
	Method SetIntensity(value:Float)
		gain.SetExposure(value)
	End Method
	Rem
	bbdoc: Returns the bloom intensity multiplier.
	End Rem
	Method GetIntensity:Float()
		Return gain.GetExposure()
	End Method

	Rem
	bbdoc: Rebuilds bloom and returns the cached borrowed opaque result.
	param: Source render image matching the prepared dimensions, distinct from the cached result.
	about: Preserves source pixels, drawing state and target views. Performs extraction, scaled blur, opaque-black fill, source composition and scaled glow addition. No images, arrays or descriptors are allocated after preparation. State scopes are allocated by the underlying operations. Rerun only when scene content or bloom settings change. Parameters and shader support are checked before output writes; a later runtime failure invalidates the cached result. Pad source content to retain halos. Transparent areas are flattened over black.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		Local destination:TRenderImage = buffers.Image(2)
		If Not source Then Throw "Max2D Effects: bloom source is null"
		If source = destination Then Throw "Max2D Effects: bloom cannot sample its cached result"
		If source.width <> width Or source.height <> height Then Throw "Max2D Effects: bloom source dimensions must match prepared buffers"
		CheckRadius(width, height, smallestWidth, smallestHeight)
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
			source.Frame(0, TMax2DGraphics.Current())
			CheckScaledBlurTarget(buffers.Image(0), bright)
			CheckScaledBlurTarget(buffers.Image(1), blurSupport)
			SetBlend(LIGHTBLEND)
			CheckScaledBlurTarget(destination, gain)
			SetBlend(ALPHABLEND)
			valid = False
			buffers.ApplyChain(source, 0, extraction)
			buffers.ApplyBlur(buffers.Image(0), 1, blur)
			Local destinationScope:TMax2DStateScope = PrepareChainTarget(destination)
			Try
				SetBlend(SOLIDBLEND)
				SetColor(0, 0, 0)
				DrawRect(0, 0, width, height)
				SetColor(255, 255, 255)
				SetBlend(ALPHABLEND)
				DrawImage(source, source.handle_x, source.handle_y)
				SetBlend(LIGHTBLEND)
				Local glow:TRenderImage = buffers.Image(1)
				DrawImageEffect(glow, gain, glow.handle_x, glow.handle_y)
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
	bbdoc: Returns the cached borrowed result without performing drawing.
	about: Throws before the first successful Update, after layout changes or release, and on the wrong or closed context. Settings changes alone do not rebuild or discard the last result.
	End Rem
	Method Result:TRenderImage()
		Local image:TRenderImage = buffers.Image(2)
		If Not valid Then Throw "Max2D Effects: bloom result requires a successful Update"
		Return image
	End Method

	Rem
	bbdoc: Releases retained buffers and invalidates the cached result.
	about: Select another target first if the result is currently selected. Settings remain available for a later Prepare.
	End Rem
	Method Release()
		buffers.Release()
		cached = Null; valid = False
		width = 0; height = 0; smallestWidth = 0; smallestHeight = 0
	End Method

	Private
	Field blurSupport:TMax2DBlurEffect = CreateBlurEffect()
	Method CheckRadius(w:Int, h:Int, sw:Int, sh:Int)
		If blur.GetRadius()*Float(sw)/w > 4 Or blur.GetRadius()*Float(sh)/h > 4 Then Throw "Max2D Effects: bloom radius requires more reduction levels"
	End Method
End Type

Rem
bbdoc: Creates a reusable bloom description without allocating graphics resources.
End Rem
Function CreateBloom:TMax2DBloom(threshold:Float = 1, radius:Float = 8, intensity:Float = 1)
	Local bloom:TMax2DBloom = New TMax2DBloom
	bloom.SetThreshold(threshold)
	bloom.SetRadius(radius)
	bloom.SetIntensity(intensity)
	Return bloom
End Function
