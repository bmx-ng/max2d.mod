Rem
bbdoc: Context-owned reusable render images for effect chains and scaled blur.
about: Prepare allocates and materializes a complete layout. Repeating the same layout on the same context preserves images and pixels. Image returns borrowed storage, invalidated by a changed Prepare or Release. Keep sources separate from outputs and do not retain borrowed images in saved drawing-state scopes across reconfiguration. Operations use existing effect functions and retain their state-restoration and alias checks. This is an explicit owner, not a global pool or an automatic result cache.
End Rem
Type TMax2DEffectBuffers
	Private
	Field owner:TMax2DContext
	Field images:TRenderImage[]
	Field levels:TRenderImage[]
	Field blurScratch:TRenderImage
	Field width:Int, height:Int, format:Int
	Field reductionCount:Int = -1

	Public
	Rem
	bbdoc: Allocates a reusable layout on the current graphics context, or keeps an identical layout.
	param: Positive full-size width.
	param: Positive full-size height.
	param: Number of independently indexed full-size images; at least one.
	param: Number of successive ceil-halved blur levels; -1 omits blur storage (default), zero blurs at full size.
	param: Render-image storage format; defaults to RGBA8888.
	about: All images use FILTEREDIMAGE without mipmaps. The layout contains imageCount full-size images, reductionLevels reduced images and one blur scratch image at the smallest size when reductionLevels is nonnegative. Changing layout discards old contents only after successful allocation. Native textures are created here; shader pipelines may still need warming. A live set cannot migrate between contexts; Release it first, or Prepare after its old context closes. Reconfiguration is rejected while any owned image is selected as a target. The active target and drawing state are unchanged.
	End Rem
	Method Prepare(width:Int, height:Int, imageCount:Int = 2, reductionLevels:Int = -1, pixelFormat:Int = PF_RGBA8888)
		Local context:TMax2DContext = TMax2DGraphics.Current().context
		context.CheckOpen()
		If width <= 0 Or height <= 0 Or imageCount < 1 Or reductionLevels < -1 Then Throw "Max2D Effects: invalid buffer layout"
		If owner And owner <> context And Not owner.closed Then Throw "Max2D Effects: release buffers before changing live contexts"
		If owner = context And Self.width = width And Self.height = height And images.Length = imageCount And reductionCount = reductionLevels And format = pixelFormat Then Return
		CheckNotSelected()
		Local w:Int = width, h:Int = height
		If Not Max2DSupportsRenderImage(w, h, FILTEREDIMAGE, pixelFormat) Then Throw "Max2D Effects: unsupported full-size buffer"
		For Local i:Int = 0 Until reductionLevels
			If w = 1 And h = 1 Then Throw "Max2D Effects: too many blur reduction levels"
			w = w/2+w Mod 2; h = h/2+h Mod 2
			If Not Max2DSupportsRenderImage(w, h, FILTEREDIMAGE, pixelFormat) Then Throw "Max2D Effects: unsupported blur buffer"
		Next
		' Keep allocated images in an object across exception unwinding.
		Local candidate:TMax2DEffectBuffers = New TMax2DEffectBuffers
		Try
			candidate.Allocate(context, width, height, imageCount, reductionLevels, pixelFormat)
		Catch error:Object
			candidate.Release()
			Throw error
		End Try
		Self.Release()
		owner = candidate.owner
		images = candidate.images
		levels = candidate.levels
		blurScratch = candidate.blurScratch
		Self.width = width; Self.height = height; format = pixelFormat
		reductionCount = reductionLevels
	End Method

	Rem
	bbdoc: Returns a borrowed full-size image by zero-based index.
	about: Requires the owning context to be current and open. Do not release or resize the returned image independently.
	End Rem
	Method Image:TRenderImage(index:Int)
		CheckCurrent()
		If index < 0 Or index >= images.Length Then Throw "Max2D Effects: buffer index outside layout"
		Return images[index]
	End Method

	Rem
	bbdoc: Applies a chain into an indexed full-size image and returns that borrowed result.
	param: Source layer, distinct from all output images used by this operation.
	param: Index of the result image.
	param: Retained effect descriptions in drawing order.
	param: Index of a distinct full-size scratch image, used only for chains with two or more effects; defaults to one.
	about: Dimensions must match the prepared layout. Empty chains copy the source. Every call rebuilds the output; there is no dirty tracking. Full-layer processing ignores drawing tint, transforms and source handles, and restores caller state and target views. The returned image is overwritten by subsequent operations targeting that index and expires after changed Prepare, Release or context closure.
	End Rem
	Method ApplyChain:TRenderImage(source:TRenderImage, destinationIndex:Int, effects:TMax2DImageEffect[], scratchIndex:Int = 1)
		Local destination:TRenderImage = Image(destinationIndex)
		Local scratch:TRenderImage
		If effects.Length > 1 Then scratch = Image(scratchIndex)
		ApplyLayerEffects(source, destination, effects, scratch)
		Return destination
	End Method

	Rem
	bbdoc: Applies scaled blur using the retained pyramid and returns the borrowed result image.
	param: Filtered source layer, distinct from the result.
	param: Index of the full-size result image.
	param: Reusable scaled-blur descriptor; its radius must fit the prepared pyramid.
	about: Prepare must include blur storage with nonnegative reductionLevels. Source dimensions must match the full-size layout and its flags must include FILTEREDIMAGE without MIPMAPPEDIMAGE. No images or arrays are allocated here. Existing scaled-blur validation and state restoration apply. Every call rebuilds the indexed output; the borrowed result has the same lifetime as Image(index).
	End Rem
	Method ApplyBlur:TRenderImage(source:TRenderImage, destinationIndex:Int, blur:TMax2DScaledBlur)
		Local destination:TRenderImage = Image(destinationIndex)
		If Not blurScratch Then Throw "Max2D Effects: prepare blur storage before applying blur"
		If Not blur Then Throw "Max2D Effects: blur description is null"
		blur.Apply(source, destination, levels, blurScratch)
		Return destination
	End Method

	Rem
	bbdoc: Releases owned image frames and resets this set; repeated calls are harmless.
	about: Native release is queued for the owning context's normal cleanup. May be called after that context closes. Rejects release while an owned image is selected as its target. Borrowed images must no longer be used after release.
	End Rem
	Method Release()
		CheckNotSelected()
		For Local image:TRenderImage = EachIn images
			If image Then image.ReleaseFrames()
		Next
		For Local image:TRenderImage = EachIn levels
			If image Then image.ReleaseFrames()
		Next
		If blurScratch Then blurScratch.ReleaseFrames()
		images = Null; levels = Null; blurScratch = Null; owner = Null
		width = 0; height = 0; format = 0; reductionCount = -1
	End Method

	Private
	Method CheckCurrent()
		If Not owner Then Throw "Max2D Effects: buffers have not been prepared"
		owner.CheckOpen()
		If TMax2DGraphics.Current().context <> owner Then Throw "Max2D Effects: buffers belong to another context"
	End Method

	Method CheckNotSelected()
		If Not owner Or owner.closed Or Not owner.target Then Return
		For Local image:TRenderImage = EachIn images
			CheckImageNotSelected(image)
		Next
		For Local image:TRenderImage = EachIn levels
			CheckImageNotSelected(image)
		Next
		CheckImageNotSelected(blurScratch)
	End Method

	Method CheckImageNotSelected(image:TRenderImage)
		If Not image Then Return
		For Local source:TImageSource = EachIn image.sources
			For Local frame:TImageFrame = EachIn source.frames
				If frame = owner.target Then Throw "Max2D Effects: deselect owned buffers before release or resize"
			Next
		Next
	End Method

	Method Allocate(context:TMax2DContext, width:Int, height:Int, imageCount:Int, reductionLevels:Int, pixelFormat:Int)
		owner = context
		images = New TRenderImage[imageCount]
		levels = New TRenderImage[Max(0, reductionLevels)]
		For Local i:Int = 0 Until imageCount
			images[i] = CreateRenderImage(UInt(width), UInt(height), FILTEREDIMAGE, pixelFormat)
			images[i].Frame(0, TMax2DGraphics.Current())
		Next
		Local w:Int = width, h:Int = height
		For Local i:Int = 0 Until reductionLevels
			w = w/2+w Mod 2; h = h/2+h Mod 2
			levels[i] = CreateRenderImage(UInt(w), UInt(h), FILTEREDIMAGE, pixelFormat)
			levels[i].Frame(0, TMax2DGraphics.Current())
		Next
		If reductionLevels >= 0 Then
			blurScratch = CreateRenderImage(UInt(w), UInt(h), FILTEREDIMAGE, pixelFormat)
			blurScratch.Frame(0, TMax2DGraphics.Current())
		End If
	End Method
End Type
