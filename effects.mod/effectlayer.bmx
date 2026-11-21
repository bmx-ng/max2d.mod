Rem
bbdoc: Reusable padded capture layer with logical coordinates and explicit resolution scaling.
about: Prepare owns one filtered render image. Capture draws in content coordinates, with (0,0) inside the padding. Draw places that same content origin at the requested position, including when drawing a same-sized effect result. Padding is explicit and is not inferred from effects. Capture and effect updates remain separate operations.
End Rem
Type TMax2DEffectLayer
	Private
	Field buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
	Field capture:TMax2DStateScope
	Field logicalWidth:Int, logicalHeight:Int
	Field padLeft:Int, padTop:Int
	Field scale:Int = 1

	Public
	Rem
	bbdoc: Prepares a padded image at an integer number of pixels per logical unit.
	param: Positive content width in logical units.
	param: Positive content height in logical units.
	param: Nonnegative left padding in logical units.
	param: Nonnegative top padding in logical units.
	param: Nonnegative right padding in logical units.
	param: Nonnegative bottom padding in logical units.
	param: Positive integer rendering scale; defaults to one.
	param: Render-image format; defaults to RGBA8888.
	about: Image dimensions are (content plus padding) times resolutionScale. Identical storage preserves pixels; changing only logical interpretation also preserves pixels until the next capture. Prepare and Release are forbidden during capture. Borrowed images expire on changed storage, release or context closure. Effect radii are in image pixels: multiply logical radii by resolutionScale.
	End Rem
	Method Prepare(width:Int, height:Int, left:Int = 0, top:Int = 0, right:Int = 0, bottom:Int = 0, resolutionScale:Int = 1, pixelFormat:Int = PF_RGBA8888)
		CheckNotCapturing()
		If width <= 0 Or height <= 0 Or left < 0 Or top < 0 Or right < 0 Or bottom < 0 Or resolutionScale < 1 Then Throw "Max2D Effects: invalid layer layout"
		Local w:Long = Long(width) + left + right, h:Long = Long(height) + top + bottom
		If w > 2147483647:Long / resolutionScale Or h > 2147483647:Long / resolutionScale Then Throw "Max2D Effects: layer dimensions overflow"
		buffers.Prepare(Int(w * resolutionScale), Int(h * resolutionScale), 1, -1, pixelFormat)
		logicalWidth = Int(w); logicalHeight = Int(h)
		padLeft = left; padTop = top; scale = resolutionScale
	End Method

	Rem
	bbdoc: Begins a scoped capture, optionally clearing the complete padded image to transparent black.
	param: Clear the image before drawing; defaults to True.
	about: Use the returned scope in a Using block or close it in Finally. Closing restores the previous target and caller drawing state. Capture resets camera, coordinates, transform, handle, colour, alpha and blend, selects ALPHABLEND and a full padded viewport, and places the origin inside the padding. Font and line settings are inherited. Padding is drawable. The owned image's view is configured for capture. Nested capture on the same layer is rejected; different layers may nest. With clear=False, existing pixels are retained.
	End Rem
	Method Capture:TMax2DStateScope(clear:Int = True)
		CheckNotCapturing()
		Local image:TRenderImage = buffers.Image(0)
		capture = ScopedMax2DState()
		Try
			SetRenderImage(image)
			SetVirtualResolution(logicalWidth, logicalHeight)
			SetViewport(0, 0, logicalWidth, logicalHeight)
			SetCamera(Null)
			ResetCoordinates()
			SetTransform(0, 1, 1)
			SetOrigin(padLeft, padTop)
			SetHandle(0, 0)
			SetColor(255, 255, 255)
			SetAlpha(1)
			SetBlend(ALPHABLEND)
			If clear Then
				SetClsColor(0, 0, 0, 0)
				Cls
			End If
		Catch error:Object
			capture.Close()
			Throw error
		End Try
		Return capture
	End Method

	Rem
	bbdoc: Returns the borrowed padded source image for effect processing.
	about: Close capture before sampling this image. No rendering or automatic effect update occurs here. Do not release or resize the image independently. Its initial pixels are unspecified until captured or explicitly drawn.
	End Rem
	Method Image:TRenderImage()
		Return buffers.Image(0)
	End Method

	Rem
	bbdoc: Draws the captured image or a matching effect result with its content origin at (x,y).
	param: Horizontal content-origin position in caller coordinates.
	param: Vertical content-origin position in caller coordinates.
	param: Optional same-sized image to draw instead of the captured source.
	about: Includes all padding and converts image pixels back to logical units. Image handles are ignored. Caller camera, transform, colour, alpha, blend and clipping apply and are unchanged. Close capture before drawing. Result images belong to their own effect helper and are not retained by this layer.
	End Rem
	Method Draw(x:Float, y:Float, result:TImage = Null)
		CheckNotCapturing()
		Local source:TRenderImage = buffers.Image(0)
		If Not result Then result = source
		If result.width <> source.width Or result.height <> source.height Then Throw "Max2D Effects: layer result dimensions must match its image"
		DrawSubImageRect(result, x, y, logicalWidth, logicalHeight, 0, 0, result.width, result.height, padLeft * scale, padTop * scale)
	End Method

	Rem
	bbdoc: Releases the captured image; repeated calls are harmless.
	about: Close capture and deselect the image before release. Effect helpers processing the source own separate storage and must be released separately.
	End Rem
	Method Release()
		CheckNotCapturing()
		buffers.Release()
		capture = Null
	End Method

	Private
	Method CheckNotCapturing()
		If capture And capture.canvas And capture.canvas.context.closed Then capture.Close()
		If capture And capture.entry And capture.entry.active Then Throw "Max2D Effects: close layer capture before reuse or release"
	End Method
End Type
