Rem
bbdoc: Reusable bright-pass, scaled-blur and bloom-composition pipeline.
about: Prepare owns intermediate buffers; Update rebuilds explicitly; Result returns the cached borrowed image. By default composition flattens the source over opaque black. SetOpaqueBackground(False) preserves transparency and adds glow coverage for scene composition. Use linear source colours and a floating-point format for HDR. The class does not select a window output mode or tone-map its result. Borrowed results must not be independently released or retained across changed Prepare, Release or context closure. Source changes are not detected automatically.
End Rem
Type TMax2DBloom
	Private
	Field buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
	Field bright:TMax2DBrightPassEffect = CreateBrightPassEffect(1)
	Field blur:TMax2DScaledBlur = CreateScaledBlur(8)
	Field gain:TMax2DLinearOutputEffect = CreateLinearOutputEffect(True)
	Field extraction:TMax2DImageEffect[] = [TMax2DImageEffect(bright)]
	Field cached:TRenderImage
	Field opaqueBackground:Int = True
	Field transparentBlend:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE)
	Field drawingState:TLayerDrawingState=New TLayerDrawingState
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
	param: Finite nonnegative luminance threshold in source colour units.
	about: Takes effect on the next Update; the cached result is unchanged until then.
	End Rem
	Method SetThreshold(value:Float)
		bright.SetThreshold(value)
	End Method
	Rem
	bbdoc: Returns the bright-pass threshold.
	returns: The bright-pass threshold.
	End Rem
	Method GetThreshold:Float()
		Return bright.GetThreshold()
	End Method
	Rem
	bbdoc: Sets the finite, nonnegative blur radius in full-resolution source pixels.
	param: Finite nonnegative blur radius in full-resolution source pixels.
	about: Prepare and Update check that the radius fits the prepared reduction levels. Takes effect on the next Update.
	End Rem
	Method SetRadius(value:Float)
		blur.SetRadius(value)
	End Method
	Rem
	bbdoc: Returns the blur radius.
	returns: The blur radius.
	End Rem
	Method GetRadius:Float()
		Return blur.GetRadius()
	End Method
	Rem
	bbdoc: Sets finite, nonnegative bloom intensity; one is unchanged glow, zero suppresses it.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	about: Values above one amplify bloom without changing source brightness. Takes effect on the next Update.
	End Rem
	Method SetIntensity(value:Float)
		gain.SetExposure(value)
	End Method
	Rem
	bbdoc: Returns the bloom intensity multiplier.
	returns: The bloom intensity multiplier.
	End Rem
	Method GetIntensity:Float()
		Return gain.GetExposure()
	End Method

 Rem
 bbdoc: Chooses opaque-black composition (default True) or transparent composition.
 param: True for opaque-black composition, False to preserve transparent composition.
 about: Takes effect on the next Update without reallocating textures. Transparent output adds bloom RGB and combines source and glow alpha as coverage: a = glowAlpha + sourceAlpha*(1-glowAlpha). Glow coverage scales with intensity up to one; higher intensity increases RGB only. Zero intensity preserves source RGBA. Present with ordinary ALPHABLEND; this is a composited glow, not additive lighting applied to the eventual background.
 End Rem
 Method SetOpaqueBackground(value:Int)
  opaqueBackground = value <> 0
 End Method
 Rem
 bbdoc: Returns whether composition fills the canvas with opaque black.
 returns: Whether composition fills the canvas with opaque black.
 End Rem
 Method GetOpaqueBackground:Int()
  Return opaqueBackground
 End Method
 Private
 Method SelectGlowBlend()
  If opaqueBackground Then
   SetBlend(LIGHTBLEND)
  Else
   SetBlend(transparentBlend)
  End If
 End Method
 Public

 Rem
 bbdoc: Validates bloom effects on the prepared targets without changing pixels or caller state.
 about: Call after Prepare. Throws when the selected backend cannot perform extraction, blur or additive composition for this format.
 End Rem
 Method ValidateSupport()
  Local scope:SLayerDrawingScope = drawingState.Open()
  Try
   SetBlend(SOLIDBLEND)
   CheckScaledBlurTarget(buffers.Image(0), bright)
   CheckScaledBlurTarget(buffers.Image(1), blurSupport)
   SelectGlowBlend()
   CheckScaledBlurTarget(buffers.Image(2), gain)
  Finally
   scope.Close()
  End Try
 End Method

	Rem
	bbdoc: Rebuilds bloom and returns the cached borrowed result.
	param: Source render image matching the prepared dimensions, distinct from the cached result.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Preserves source pixels, drawing state and target views. Performs extraction, scaled blur, source composition and scaled glow addition. No images, arrays or descriptors are allocated after preparation. Warm updates reuse private drawing state throughout the pipeline; reentrant calls use separate scopes. Rerun only when scene content or bloom settings change. Parameters and shader support are checked before output writes; a later runtime failure invalidates the cached result. Pad source content to retain halos. Transparent areas remain transparent when opaque background is disabled.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		Local destination:TRenderImage = buffers.Image(2)
		If Not source Then Throw "Max2D Effects: bloom source is null"
		If source = destination Then Throw "Max2D Effects: bloom cannot sample its cached result"
		If source.width <> width Or source.height <> height Then Throw "Max2D Effects: bloom source dimensions must match prepared buffers"
		CheckRadius(width, height, smallestWidth, smallestHeight)
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
			CheckScaledBlurTarget(buffers.Image(0), bright)
			CheckScaledBlurTarget(buffers.Image(1), blurSupport)
			SelectGlowBlend()
			CheckScaledBlurTarget(destination, gain)
			SetBlend(ALPHABLEND)
			valid = False
			buffers.ApplyChain(source, 0, extraction)
			buffers.ApplyBlur(buffers.Image(0), 1, blur)
			Local destinationScope:SLayerTargetView = PrepareChainTarget(destination)
			Try
				SetBlend(SOLIDBLEND)
				If opaqueBackground Then
				 SetColor(0, 0, 0)
				 DrawRect(0, 0, width, height)
				 SetColor(255, 255, 255)
				 SetBlend(ALPHABLEND)
				End If
				DrawImage(source, source.handle_x, source.handle_y)
				SelectGlowBlend()
				Local glow:TRenderImage = buffers.Image(1)
				Local strength:Float = gain.GetExposure()
				Try
				 If Not opaqueBackground Then
				  SetAlpha(Min(strength,1.0:Float))
				  gain.SetExposure(Max(strength,1.0:Float))
				 End If
				 DrawImageEffect(glow, gain, glow.handle_x, glow.handle_y)
				Finally
				 gain.SetExposure(strength)
				End Try
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
	returns: The cached borrowed result without performing drawing.
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
param: Finite, nonnegative luminance threshold in source colour units; defaults to one.
param: Finite, nonnegative blur radius in source pixels; defaults to eight.
param: Finite, nonnegative glow multiplier; defaults to one.
returns: A new #TMax2DBloom instance configured with the supplied settings.
End Rem
Function CreateBloom:TMax2DBloom(threshold:Float = 1, radius:Float = 8, intensity:Float = 1)
	Local bloom:TMax2DBloom = New TMax2DBloom
	bloom.SetThreshold(threshold)
	bloom.SetRadius(radius)
	bloom.SetIntensity(intensity)
	Return bloom
End Function
