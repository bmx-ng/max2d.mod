Rem
bbdoc: Immutable logical canvas and pixel storage description for scene effect stages.
about: Create rounds bounds outward to whole logical units. Construction and queries require no graphics context. CanvasRect allocates a detached rectangle; CopyCanvasRect reuses caller storage.
End Rem
Type TSceneStageLayout
	Private
	Field left:Int, top:Int, logicalWidth:Int, logicalHeight:Int
	Field scale:Int, format:Int, width:Int, height:Int
	Public
	Rem
	bbdoc: Creates an outward-rounded nonempty canvas with positive integer resolution scale.
	param: Required finite logical canvas rectangle; it is copied and rounded outward.
	param: Positive integer number of image pixels per logical unit.
	param: Render-image format: PF_RGBA8888, PF_RGBA16F or PF_RGBA32F, subject to backend support.
	returns: A new #TSceneStageLayout instance configured with the supplied settings.
	about: RGBA8888, RGBA16F and RGBA32F are accepted. Dimensions and byte estimates are checked for overflow; backend limits are checked during stage preparation.
	End Rem
	Function Create:TSceneStageLayout(canvas:TSceneRect, resolutionScale:Int = 1, pixelFormat:Int = PF_RGBA8888)
		CheckStageRect(canvas)
		If canvas.width <= 0 Or canvas.height <= 0 Or resolutionScale < 1 Then
			Throw "Max2D SceneEffects: layout must have positive area and scale"
		End If

		If pixelFormat <> PF_RGBA8888 And pixelFormat <> PF_RGBA16F And pixelFormat <> PF_RGBA32F Then
			Throw "Max2D SceneEffects: layout requires an RGBA render-image format"
		End If

		Local x:Double = Floor(Double(canvas.x)), y:Double = Floor(Double(canvas.y))
		Local right:Double = Ceil(Double(canvas.x) + canvas.width), bottom:Double = Ceil(Double(canvas.y) + canvas.height)
		If x < -2147483648:Double Or y < -2147483648:Double Or right > 2147483647:Double Or bottom > 2147483647:Double Then
			Throw "Max2D SceneEffects: canvas coordinates overflow"
		End If

		Local w:Double = right - x, h:Double = bottom - y
		If w > 2147483647:Double / resolutionScale Or h > 2147483647:Double / resolutionScale Then
			Throw "Max2D SceneEffects: pixel dimensions overflow"
		End If

		Local result:TSceneStageLayout = New TSceneStageLayout
		result.left = Int(x); result.top = Int(y); result.logicalWidth = Int(w); result.logicalHeight = Int(h)
		result.scale = resolutionScale; result.format = pixelFormat
		result.width = Int(w) * resolutionScale; result.height = Int(h) * resolutionScale
		result.EstimateImageBytes(1)
		Return result
	End Function
	Rem
	bbdoc: Returns storage width in pixels.
	returns: Storage width in pixels.
	End Rem
	Method PixelWidth:Int()
		Return width
	End Method
	Rem
	bbdoc: Returns storage height in pixels.
	returns: Storage height in pixels.
	End Rem
	Method PixelHeight:Int()
		Return height
	End Method
	Rem
	bbdoc: Returns the number of pixels per logical unit.
	returns: The number of pixels per logical unit.
	End Rem
	Method ResolutionScale:Int()
		Return scale
	End Method
	Rem
	bbdoc: Returns the render-image storage format.
	returns: The render-image storage format.
	End Rem
	Method PixelFormat:Int()
		Return format
	End Method
	Rem
	bbdoc: Allocates a detached logical canvas rectangle.
	returns: A new detached rectangle containing the logical canvas bounds.
	End Rem
	Method CanvasRect:TSceneRect()
		Local result:TSceneRect = New TSceneRect
		CopyCanvasRect(result)
		Return result
	End Method
	Rem
	bbdoc: Copies the logical canvas into reusable caller storage without allocating.
	param: Required reusable destination rectangle.
	End Rem
	Method CopyCanvasRect(output:TSceneRect)
		If Not output Then
			Throw "Max2D SceneEffects: rectangle destination is null"
		End If

		output.x = left; output.y = top; output.width = logicalWidth; output.height = logicalHeight
	End Method
	Rem
	bbdoc: Estimates storage for a positive number of full-canvas images, excluding driver overhead.
	param: Positive number of full-canvas images to include in the byte estimate.
	returns: Estimated bytes for the requested full-canvas images.
	about: Throws if the signed 64-bit byte count would overflow. RGBA8888 uses four bytes per pixel, RGBA16F eight and RGBA32F sixteen.
	End Rem
	Method EstimateImageBytes:Long(count:Int = 1)
		If count < 1 Or width < 1 Or height < 1 Then
			Throw "Max2D SceneEffects: invalid storage estimate"
		End If

		Local bytes:Int = 4
		If format = PF_RGBA16F Then
			bytes = 8
		End If

		If format = PF_RGBA32F Then
			bytes = 16
		End If

		Local pixels:Long = Long(width) * height
		If pixels > 9223372036854775807:Long / bytes / count Then
			Throw "Max2D SceneEffects: storage estimate overflow"
		End If

		Return pixels * bytes * count
	End Method
End Type

Rem
bbdoc: Provider contract for a retained scene effect stage.
about: Stages expand bounds, prepare owned storage, process a distinct borrowed source and release explicitly. Configuration revisions change only through Invalidate, never through processing. No GC finalizer releases graphics resources. Attached stages notify their owning composite when configuration changes.
End Rem
Type TSceneEffectStage Abstract
	Internal
	Field retainedStorage:Long
	Field owner:TCompositeNode
	Private
	Field revision:Long
	Public
	Rem
	bbdoc: Marks externally edited effect configuration as changed.
	about: Call after changing a shared raw effect description. This does not process pixels or allocate resources. Unattached consumers compare Revision to decide when to update; attached composites are notified automatically and reuse unchanged preceding stage outputs when their canvas and source remain valid.
	End Rem
	Method Invalidate()
		If owner Then
			owner.InvalidateStage(Self)
		End If

		revision :+ 1
	End Method
	Rem
	bbdoc: Returns the configuration revision for dependency tracking.
	returns: The configuration revision for dependency tracking.
	End Rem
	Method Revision:Long()
		Return revision
	End Method
	Rem
	bbdoc: Tests an optional group-local input restriction; defaults to accepting every point.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	returns: True when the point passes this input test, False otherwise.
	about: Attached composites intersect stage restrictions with their local clip for fresh picking and hover. Must not mutate the scene or start another traversal. Captured pointer delivery is unaffected.
	End Rem
	Method HitTestInputClip:Int(x:Float, y:Float)
		Return True
	End Method
	Rem
	bbdoc: Expands logical input bounds into caller storage; the output must contain the input.
	param: Finite logical input rectangle; may be the same object as output.
	param: Required reusable destination rectangle.
	about: Providers must accept aliased input/output, validate finite bounds, and leave output unchanged on failure. No graphics context is required.
	End Rem
	Method ExpandBounds(input:TSceneRect, output:TSceneRect) Abstract
	Rem
	bbdoc: Estimates the full replacement layout's owned texture bytes, excluding driver overhead.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Estimated owned texture bytes for the complete replacement layout, excluding driver overhead.
	about: Existing storage is accounted separately by the consumer when checking peak replacement memory. This query must not allocate textures.
	End Rem
	Method EstimateStorageBytes:Long(layout:TSceneStageLayout) Abstract
	Rem
	bbdoc: Estimates additional peak texture bytes needed during Prepare, above currently retained storage.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Additional peak texture bytes required during preparation; zero when retained storage can be reused.
	about: Defaults to a full candidate allocation. Providers returning zero must reuse existing textures. Must not allocate or mutate configuration.
	End Rem
	Method EstimatePreparationBytes:Long(layout:TSceneStageLayout)
		Return EstimateStorageBytes(layout)
	End Method
	Rem
	bbdoc: Prepares retained storage and validates effect support against its actual targets.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	about: Preserve caller state and previous storage on failure where possible. Identical preparation reuses textures. Unsupported effects must throw, never silently disappear. A live stage cannot migrate contexts before ReleaseResources.
	End Rem
	Method Prepare(layout:TSceneStageLayout) Abstract
	Rem
	bbdoc: Processes a same-size, same-format source into distinct borrowed output.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Preserve source pixels and caller state. Stable-layout updates must allocate no render images. The result expires on another update, changed preparation, release or context closure. A failed update leaves no usable current output.
	End Rem
	Method Update:TRenderImage(source:TRenderImage) Abstract
	Rem
	bbdoc: Processes an attached stage with the composite's borrowed capture context.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	param: Borrowed group capture context valid only during the current group draw.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Defaults to Update. Providers that capture scene sources override this hook; the context must not be retained. Standalone callers use Update only for stages supporting standalone processing.
	End Rem
	Method UpdateInGroup:TRenderImage(source:TRenderImage, context:TSceneGroupContext)
		Return Update(source)
	End Method
	Rem
	bbdoc: Releases owned resources, retaining configuration; repeated calls are harmless.
	End Rem
	Method ReleaseResources() Abstract
End Type

Private

Function CheckStageRect(rect:TSceneRect)
	If Not rect Then
		Throw "Max2D SceneEffects: rectangle is null"
	End If

	If IsNan(rect.x) Or IsInf(rect.x) Or IsNan(rect.y) Or IsInf(rect.y) Or IsNan(rect.width) Or IsInf(rect.width) Or IsNan(rect.height) Or IsInf(rect.height) Then
		Throw "Max2D SceneEffects: rectangle must be finite"
	End If

	If rect.width < 0 Or rect.height < 0 Then
		Throw "Max2D SceneEffects: rectangle dimensions must be nonnegative"
	End If
End Function

Public
