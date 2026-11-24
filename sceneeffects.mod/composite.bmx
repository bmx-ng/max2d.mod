Rem
bbdoc: Controls whether a composite captures every render or reuses unchanged pixels.
End Rem
Enum ESceneCacheMode
 None
 Automatic
End Enum

Rem
bbdoc: Isolates a scene subtree into a retained image, with optional effect stages and caching.
about: Always creates a rendering boundary, even without stages. SetAlpha remains inherited per-draw alpha; SetOpacity fades the flattened result once. Content and effects are tracked through setters and explicit invalidation. Scene.ReleaseResources and Destroy release owned captures and stage storage. Shared application images remain caller-owned.
End Rem
Type TCompositeNode Extends TSceneRenderGroup
	Private
	Field stages:TSceneEffectStage[]
	Field stageOutputs:TRenderImage[]
	Field dirtyStage:Int
	Field mode:ESceneCacheMode
	Field groupOpacity:Float = 1
	Field clipInput:Int
	Field fixedRect:TSceneRect
	Field scale:Int = 1, format:Int = PF_RGBA8888
	Field limit:Long = 67108864
	Field capture:TMax2DEffectLayer = New TMax2DEffectLayer
	Field layout:TSceneStageLayout
	Field output:TRenderImage
	Field sourceValid:Int
	Field valid:Int, prepareNeeded:Int = True
	Field appliedRevision:Long
	Field red:Float, green:Float, blue:Float, alpha:Float
	Field rectangle:TSceneRect = New TSceneRect
	Field expanded:TSceneRect = New TSceneRect
	Field canvasRect:TSceneRect = New TSceneRect
	Field dependencyEpoch:Long = -1
	Field dependencyScene:TScene
	Field resolvingDependencies:Int
	Field retainedBytes:Long
	Public
	Rem
	bbdoc: Creates a detached composite without graphics resources; default cache mode is None.
	returns: A new #TCompositeNode instance configured with the supplied settings.
	End Rem
	Function Create:TCompositeNode()
		Return New TCompositeNode
	End Function
	Rem
	bbdoc: Copies and takes ownership of an ordered stage list; Null clears the list.
	param: Ordered stages transferred to this composite; Null clears the stage chain.
	about: Rejects duplicate stages and stages attached elsewhere before changing ownership. Removed stages release storage and become reusable. Retained instances keep ownership. Applications must not manually prepare, update or release attached stages.
	End Rem
	Method SetStages(values:TSceneEffectStage[])
		CheckGroupMutable()
		For Local i:Int = 0 Until values.Length
			If Not values[i] Then
				Throw "Max2D SceneEffects: null composite stage"
			End If

			If values[i].owner And values[i].owner <> Self Then
				Throw "Max2D SceneEffects: stage already belongs to another composite"
			End If

			Local mask:TSceneSubtreeMaskStage = TSceneSubtreeMaskStage(values[i])
			If mask Then
				mask.ValidateOwner(Self)
			End If

			For Local j:Int = 0 Until i
				If values[i] = values[j] Then
					Throw "Max2D SceneEffects: duplicate composite stage"
				End If
			Next
		Next

		Local replacement:TSceneEffectStage[] = values[..]
		InvalidateEffects()
		' Keep the old ownership list intact if a custom provider cannot release.
		For Local stage:TSceneEffectStage = EachIn stages
			If Not ContainsStage(replacement, stage) Then
				stage.ReleaseResources()
				retainedBytes :- stage.retainedStorage; stage.retainedStorage = 0
				ReportStorageBytes(retainedBytes)
			End If
		Next

		For Local stage:TSceneEffectStage = EachIn stages
			If Not ContainsStage(replacement, stage) Then
				stage.owner = Null
			End If
		Next

		stages = replacement
		stageOutputs = New TRenderImage[stages.Length]
		For Local stage:TSceneEffectStage = EachIn stages
			stage.owner = Self
		Next

		Local hasDependencies:Int
		For Local stage:TSceneEffectStage = EachIn stages
			If TSceneSubtreeMaskStage(stage) Then
				hasDependencies = True
			End If
		Next

		SetRenderPreparation(hasDependencies)
	End Method
	Rem
	bbdoc: Resolves live mask sources before rendering, including inside cached ancestors.
	param: The render-attempt identifier supplied to PrepareRenderDependencies; not an application frame counter.
	about: Dependency cycles introduced through later tree changes abort the render before drawing. Source changes invalidate processing while retaining this composite's captured artwork.
	End Rem
	Method PrepareRenderDependencies(epoch:Long) Override
		If resolvingDependencies Then
			Throw "Max2D SceneEffects: cyclic subtree mask dependency"
		End If

		If dependencyScene = Scene() And dependencyEpoch = epoch Then
			Return
		End If

		resolvingDependencies = True
		Try
			For Local stage:TSceneEffectStage = EachIn stages
				Local mask:TSceneSubtreeMaskStage = TSceneSubtreeMaskStage(stage)
				If mask Then
					mask.ResolveDependency(epoch)
				End If
			Next

			dependencyScene = Scene();dependencyEpoch = epoch
		Finally
			resolvingDependencies = False
		End Try
	End Method

	Internal
	Method CheckMaskPath(target:TCompositeNode, path:TSceneNode[], depth:Int)
		For Local stage:TSceneEffectStage = EachIn stages
			Local mask:TSceneSubtreeMaskStage = TSceneSubtreeMaskStage(stage)
			If mask Then
				CheckMaskDependencyPath(target, mask.sourceNode, path, depth)
			End If
		Next
	End Method

	Public
	Rem
	bbdoc: Chooses per-render capture or automatic reuse; both modes have identical composition semantics.
	param: None to recapture each render, or Automatic to reuse output until invalidated.
	about: Automatic ancestors still refresh when a visible descendant composite uses None.
	End Rem
	Method SetCacheMode(value:ESceneCacheMode)
		CheckGroupMutable()
		If value <> ESceneCacheMode.None And value <> ESceneCacheMode.Automatic Then
			Throw "Max2D SceneEffects: invalid cache mode"
		End If

		If mode = value Then
			Return
		End If

		mode = value; InvalidateContent(); valid = False
	End Method
	Rem
	bbdoc: Sets flattened opacity from zero to one without rebuilding this composite's pixels.
	param: Flattened group opacity in the inclusive range 0..1.
	End Rem
	Method SetOpacity(value:Float)
		CheckGroupMutable()
		If IsNan(value) Or IsInf(value) Or value < 0 Or value > 1 Then
			Throw "Max2D SceneEffects: opacity must be 0..1"
		End If

		If groupOpacity = value Then
			Return
		End If

		groupOpacity = value; InvalidatePresentation()
	End Method
	Rem
	bbdoc: Copies a fixed logical capture region, allowing children with unknown bounds.
	param: Finite group-local rectangle, copied by this call; dimensions must be nonnegative.
	about: Content is clipped to this region, rounded outward to logical pixels, before processing. Stage padding is added outside it. Zero-area regions produce no output. This capture-only operation leaves picking unrestricted, including when replacing SetClipRect; use SetClipRect to clip both drawing and picking.
	End Rem
	Method SetCaptureRect(rect:TSceneRect)
		CheckGroupMutable(); CheckStageRect(rect)
		If Not fixedRect Then
			fixedRect = New TSceneRect
		End If

		CopyStageRect(rect, fixedRect)
		clipInput = False
		sourceValid = False; InvalidateEffects()
	End Method
	Rem
	bbdoc: Clips child drawing and fresh pointer picking to a copied group-local rectangle.
	param: Finite group-local rectangle, copied by this call; dimensions must be nonnegative.
	about: Uses retained offscreen capture, including on backends without shaders. Edges round outward to whole logical units for both drawing and picking; left/top are included and right/bottom excluded. Zero width or height rejects all input and output. Rotation, shear, reflection and camera transforms apply to the completed rectangle. Stage effects run after clipping and may extend outside it; put an effected subtree inside a separate clipped composite to clip the final effect. Captured pointers continue outside the clip. Automatic caching, resolution, storage limits and explicit resource release work as for other composites. SetCaptureRect replaces this with capture-only clipping; ClearCaptureRect removes both restrictions.
	End Rem
	Method SetClipRect(rect:TSceneRect)
		SetCaptureRect(rect)
		clipInput = True
	End Method
	Rem
	bbdoc: Copies the effective local input clip, or returns False without changing output when no input clip is configured.
	param: Required reusable destination rectangle.
	returns: True when a configured clip was copied; False leaves output unchanged.
	about: Returns the outward-rounded logical rectangle used by picking. Does not allocate. This is distinct from effect-expanded output bounds.
	End Rem
	Method CopyClipRect:Int(output:TSceneRect)
		If Not clipInput Or Not fixedRect Then
			Return False
		End If

		If Not output Then
			Throw "Max2D SceneEffects: clip destination is null"
		End If

		Local x:Float = Float(Floor(Double(fixedRect.x))), y:Float = Float(Floor(Double(fixedRect.y)))
		Local w:Float, h:Float
		If fixedRect.width > 0 Then
			w = Float(Ceil(Double(fixedRect.x) + fixedRect.width) - x)
		End If

		If fixedRect.height > 0 Then
			h = Float(Ceil(Double(fixedRect.y) + fixedRect.height) - y)
		End If

		output.x = x;output.y = y;output.width = w;output.height = h
		Return True
	End Method
	Rem
	bbdoc: Restricts this group and its descendants to the local rectangle and attached stage input masks.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	returns: True when the point passes this input test, False otherwise.
	End Rem
	Method HitTestInputClip:Int(x:Float, y:Float) Override
		If clipInput And fixedRect Then
			If fixedRect.width = 0 Or fixedRect.height = 0 Then
				Return False
			End If

			If Double(x) < Floor(Double(fixedRect.x)) Or Double(y) < Floor(Double(fixedRect.y)) Or Double(x) >= Ceil(Double(fixedRect.x) + fixedRect.width) Or Double(y) >= Ceil(Double(fixedRect.y) + fixedRect.height) Then
				Return False
			End If
		End If

		For Local stage:TSceneEffectStage = EachIn stages
			If Not stage.HitTestInputClip(x, y) Then
				Return False
			End If
		Next

		Return True
	End Method
	Rem
	bbdoc: Restores automatic capture sizing from known descendant output bounds and removes input clipping.
	End Rem
	Method ClearCaptureRect()
		CheckGroupMutable(); fixedRect = Null; clipInput = False; sourceValid = False; InvalidateEffects()
	End Method
	Rem
	bbdoc: Selects positive integer pixels per logical unit; defaults to one.
	param: Positive integer number of pixels per logical unit.
	End Rem
	Method SetResolutionScale(value:Int)
		CheckGroupMutable()
		If value < 1 Then
			Throw "Max2D SceneEffects: resolution scale must be positive"
		End If

		If scale = value Then
			Return
		End If

		scale = value; InvalidateEffects()
	End Method
	Rem
	bbdoc: Selects RGBA8888, RGBA16F or RGBA32F capture and stage storage, subject to backend support.
	param: Render-image format: PF_RGBA8888, PF_RGBA16F or PF_RGBA32F, subject to backend support.
	End Rem
	Method SetPixelFormat(value:Int)
		CheckGroupMutable()
		If value <> PF_RGBA8888 And value <> PF_RGBA16F And value <> PF_RGBA32F Then
			Throw "Max2D SceneEffects: invalid composite format"
		End If

		If format = value Then
			Return
		End If

		format = value; InvalidateEffects()
	End Method
	Rem
	bbdoc: Sets a positive per-composite texture-storage limit in bytes; defaults to 64 MiB.
	param: Positive texture-storage budget in bytes.
	about: Checks source plus all stage estimates, including old and replacement storage during layout changes. Excludes driver overhead and nested composites, which have their own limits. The scene also enforces its shared budget.
	End Rem
	Method SetStorageLimitBytes(value:Long)
		CheckGroupMutable()
		If value < 1 Then
			Throw "Max2D SceneEffects: storage limit must be positive"
		End If

		limit = value; InvalidateEffects()
	End Method
	Rem
	bbdoc: Invalidates processing after external raw-effect edits and notifies enclosing composites.
	about: Reuses captured content when source dependencies and the capture layout are unchanged. Explicit invalidation refreshes every stage. Tracked stage setters invalidate that stage and its successors, retaining earlier results when the canvas is unchanged.
	End Rem
	Method InvalidateEffects()
		InvalidateOutputBounds(); prepareNeeded = True; valid = False
		dirtyStage = 0
	End Method
	Rem
	bbdoc: Invalidates an attached stage and its successors; called by TSceneEffectStage.Invalidate.
	param: Stage to invalidate, together with all following stages.
	about: Applications should invalidate the stage itself so its configuration revision also advances. Unknown stages conservatively invalidate the entire chain.
	End Rem
	Method InvalidateStage(stage:TSceneEffectStage)
		InvalidateOutputBounds(); prepareNeeded = True; valid = False
		For Local i:Int = 0 Until stages.Length
			If stages[i] = stage Then
				dirtyStage = Min(dirtyStage, i)
				Return
			End If
		Next

		dirtyStage = 0
	End Method
	Rem
	bbdoc: Reports uncached rendering to the scene's retained dependency calculation.
	returns: True when this group requires rendering on every frame, False when its output may be cached.
	End Rem
	Method RequiresContinuousRender:Int() Override
		Return mode = ESceneCacheMode.None
	End Method
	Rem
	bbdoc: Computes capture output bounds including all ordered stage padding.
	param: True when content bounds are known, False when descendants have unknown bounds.
	param: Caller-supplied local content bounds, meaningful when known is True.
	param: Required reusable destination rectangle.
	returns: True when output bounds are known and written; False when the output cannot be bounded.
	End Rem
	Method MeasureGroupOutput:Int(known:Int, content:TSceneRect, result:TSceneRect) Override
		If fixedRect Then
			CopyStageRect(fixedRect, result)
		Else
			If Not known Then
				Return False
			End If

			CopyStageRect(content, result)
		End If

		If result.width = 0 Or result.height = 0 Then
			Return True
		End If

		For Local stage:TSceneEffectStage = EachIn stages
			CopyStageRect(result, expanded)
			stage.ExpandBounds(expanded, result)
			CheckStageRect(result)
			If result.x > expanded.x Or result.y > expanded.y Or Double(result.x) + result.width < Double(expanded.x) + expanded.width Or Double(result.y) + result.height < Double(expanded.y) + expanded.height Then
				Throw "Max2D SceneEffects: stage must contain its input bounds"
			End If
		Next

		Return True
	End Method
	Rem
	bbdoc: Captures or reuses local pixels, then presents the flattened result under the current scene transform.
	param: Borrowed group capture context valid only during the current group draw.
	about: Invoked by scene rendering. Failed work is invalidated and owned resources are released; stale output is never presented.
	End Rem
	Method OnRenderGroup(context:TSceneGroupContext) Override
		If groupOpacity = 0 Then
			Return
		End If

		context.BindResources()
		Local r:Float, g:Float, b:Float, a:Float
		context.GetTint(r, g, b, a)
		Local currentRevision:Long = ContentRevision()
		Local refreshSource:Int = Not sourceValid Or mode = ESceneCacheMode.None Or currentRevision <> appliedRevision Or r <> red Or g <> green Or b <> blue Or a <> alpha
		If Not refreshSource Then
			refreshSource = HasContinuousChildren()
		End If

		Local refresh:Int = Not valid Or refreshSource
		Try
			If refresh Then
				valid = False
				If Not GetOutputBounds(rectangle) Then
					Throw "Max2D SceneEffects: automatic capture requires known bounds or SetCaptureRect"
				End If

				If rectangle.width = 0 Or rectangle.height = 0 Then
					output = Null; sourceValid = False
				Else
					Local x:Double = Floor(Double(rectangle.x)), y:Double = Floor(Double(rectangle.y))
					Local w:Double = Ceil(Double(rectangle.x) + rectangle.width) - x, h:Double = Ceil(Double(rectangle.y) + rectangle.height) - y
					Local changed:Int = Not layout
					If layout Then
						changed = x <> canvasRect.x Or y <> canvasRect.y Or w <> canvasRect.width Or h <> canvasRect.height Or scale <> layout.ResolutionScale() Or format <> layout.PixelFormat()
					End If

					If changed Then
						refreshSource = True; dirtyStage = 0
					End If

					If changed Or prepareNeeded Then
						Local candidate:TSceneStageLayout = layout
						If changed Then
							candidate = TSceneStageLayout.Create(rectangle, scale, format)
						End If

						Local bytes:Long = candidate.EstimateImageBytes()
						For Local stage:TSceneEffectStage = EachIn stages
							Local additional:Long = stage.EstimateStorageBytes(candidate)
							If additional < 0 Or additional > limit Or bytes > limit - additional Then
								Throw "Max2D SceneEffects: composite storage limit exceeded"
							End If

							bytes :+ additional
						Next

						Local peak:Long = retainedBytes
						If Not layout Or changed Then
							Local extra:Long = candidate.EstimateImageBytes()
							If extra > limit Or peak > limit - extra Then
								Throw "Max2D SceneEffects: composite replacement storage limit exceeded"
							End If

							peak :+ extra
						End If

						For Local i:Int = dirtyStage Until stages.Length
							Local stage:TSceneEffectStage = stages[i]
							Local extra:Long = stage.EstimatePreparationBytes(candidate)
							If extra < 0 Or extra > limit Or peak > limit - extra Then
								Throw "Max2D SceneEffects: composite replacement storage limit exceeded"
							End If

							peak :+ extra
						Next

						If bytes > limit Or peak > limit Then
							Throw "Max2D SceneEffects: composite storage limit exceeded"
						End If

						context.ReserveStorageBytes(peak)
						retainedBytes = peak
						candidate.CopyCanvasRect(canvasRect)
						capture.Prepare(Int(canvasRect.width), Int(canvasRect.height), 0, 0, 0, 0, scale, format)
						For Local i:Int = dirtyStage Until stages.Length
							Local stage:TSceneEffectStage = stages[i]
							stage.Prepare(candidate)
							stage.retainedStorage = stage.EstimateStorageBytes(candidate)
						Next

						layout = candidate; retainedBytes = bytes; prepareNeeded = False
						ReportStorageBytes(bytes)
					End If

					If refreshSource Then
						sourceValid = False
						Local scope:TMax2DStateScope = capture.Capture()
						Try
							If fixedRect Then
								Local clipX:Int = Int(Floor(Double(fixedRect.x)) - canvasRect.x), clipY:Int = Int(Floor(Double(fixedRect.y)) - canvasRect.y)
								Local clipW:Int = Int(Ceil(Double(fixedRect.x) + fixedRect.width) - Floor(Double(fixedRect.x)))
								Local clipH:Int = Int(Ceil(Double(fixedRect.y) + fixedRect.height) - Floor(Double(fixedRect.y)))
								SetViewport(clipX, clipY, clipW, clipH)
							End If

							context.RenderChildren(-canvasRect.x, -canvasRect.y)
						Finally
							scope.Close()
						End Try

						sourceValid = True
					End If

					If refreshSource Then
						dirtyStage = 0
					End If

					output = capture.Image()
					If dirtyStage > 0 Then
						output = stageOutputs[dirtyStage - 1]
					End If

					For Local i:Int = dirtyStage Until stages.Length
						Local stage:TSceneEffectStage = stages[i]
						Local source:TRenderImage = output
						output = stage.UpdateInGroup(source, context)
						If Not output Or output = source Then
							Throw "Max2D SceneEffects: stage output must be distinct"
						End If

						If output.width <> layout.PixelWidth() Or output.height <> layout.PixelHeight() Or output.sources[0].targetFormat <> format Then
							Throw "Max2D SceneEffects: stage output does not match canvas"
						End If

						stageOutputs[i] = output
						context.RecordStagePass()
					Next
				End If

				dirtyStage = stages.Length
				appliedRevision = currentRevision; red = r; green = g; blue = b; alpha = a; valid = True
			Else
				context.RecordCacheHit()
			End If

			If output Then
				SetColor(255, 255, 255); TMax2DGraphics.Current().state.alpha = groupOpacity
				capture.Draw(canvasRect.x, canvasRect.y, output)
			End If
		Catch error:Object
			Try
				OnReleaseResources()
			Catch cleanupError:Object
				' Preserve the rendering error; subsequent explicit cleanup may retry.
			End Try

			Throw error
		End Try
	End Method
	Rem
	bbdoc: Releases captures and all attached stage storage, retaining configuration and ownership.
	End Rem
	Method OnReleaseResources() Override
		sourceValid = False; valid = False; output = Null; prepareNeeded = True; dirtyStage = 0
		For Local i:Int = 0 Until stageOutputs.Length
			stageOutputs[i] = Null
		Next

		Local failure:Object
		For Local stage:TSceneEffectStage = EachIn stages
			Try
				stage.ReleaseResources()
				stage.retainedStorage = 0
			Catch error:Object
				If Not failure Then
					failure = error
				End If
			End Try
		Next

		Try
			capture.Release()
		Catch error:Object
			If Not failure Then
				failure = error
			End If
		End Try

		If Not failure Then
			layout = Null; retainedBytes = 0
			ReportStorageBytes(0)
		End If

		If failure Then
			Throw failure
		End If
	End Method
	Rem
	bbdoc: Detaches stage configurations after resource cleanup during destruction.
	End Rem
	Method OnDestroy() Override
		For Local stage:TSceneEffectStage = EachIn stages
			stage.owner = Null
		Next

		stages = Null; stageOutputs = Null
	End Method
End Type

Private
Function CopyStageRect(source:TSceneRect, destination:TSceneRect)
	destination.x = source.x; destination.y = source.y; destination.width = source.width; destination.height = source.height
End Function

Function ContainsStage:Int(stages:TSceneEffectStage[], value:TSceneEffectStage)
	For Local stage:TSceneEffectStage = EachIn stages
		If stage = value Then
			Return True
		End If
	Next

	Return False
End Function

Public
