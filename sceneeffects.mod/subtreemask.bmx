Rem
bbdoc: Masks composite output with the live alpha of a borrowed scene subtree.
about: Attach through TCompositeNode.SetStages. The source's local transform, tint, alpha and visibility apply; ancestors are excluded. Source-parent coordinates map to consumer-local coordinates plus an optional offset. Sources stay caller-owned and render normally unless hidden through an ancestor. Detached or other-scene sources supply empty coverage. Bounds and picking are unchanged; no GPU readback occurs. Two retained full-canvas images participate in composite and scene budgets.
End Rem
Type TSceneSubtreeMaskStage Extends TSceneEffectStage
	Internal
	Field sourceNode:TSceneNode2D
	Private
	Field offsetX:Float, offsetY:Float, inverted:Int
	Field buffers:TMax2DEffectBuffers
	Field prepared:TSceneStageLayout
	Field canvas:TSceneRect = New TSceneRect
	Field observedRevision:Long
	Field observedAvailable:Int, observed:Int
	Public
	Rem
	bbdoc: Creates a live mask referencing a required subtree without changing its ownership.
	param: Required borrowed source subtree; ownership remains with the caller.
	param: True for inverse cutout, False to retain coverage inside the mask.
	returns: A new #TSceneSubtreeMaskStage instance configured with the supplied settings.
	about: Detached sources may be configured before scene assembly. Cycles are checked on attachment and source replacement, and again before rendering if tree changes introduce a cycle.
	End Rem
	Function Create:TSceneSubtreeMaskStage(source:TSceneNode2D, inverted:Int = False)
		Local result:TSceneSubtreeMaskStage = New TSceneSubtreeMaskStage
		result.SetSource(source);result.inverted = inverted <> 0
		Return result
	End Function
	Rem
	bbdoc: Replaces the borrowed source, rejecting a dependency cycle before changing configuration.
	param: Required borrowed source subtree; ownership remains with the caller.
	End Rem
	Method SetSource(source:TSceneNode2D)
		If owner Then
			owner.CheckGroupMutable()
		End If

		If Not source Then
			Throw "Max2D SceneEffects: subtree mask source is null"
		End If

		If owner Then
			CheckMaskDependencyPath(owner, source, Null, 0)
		End If

		Invalidate();sourceNode = source;observed = False
	End Method
	Rem
	bbdoc: Translates source-parent coordinates into consumer-local coordinates without recapturing consumer artwork.
	param: Finite horizontal coordinate in consumer-local logical units.
	param: Finite vertical coordinate in consumer-local logical units.
	End Rem
	Method SetOffset(x:Float, y:Float)
		If owner Then
			owner.CheckGroupMutable()
		End If

		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then
			Throw "Max2D SceneEffects: mask offset must be finite"
		End If

		If x = offsetX And y = offsetY Then
			Return
		End If

		Invalidate();offsetX = x;offsetY = y
	End Method
	Rem
	bbdoc: Chooses ordinary masking or inverse cutout; empty inverse coverage retains the artwork.
	param: True for inverse cutout, False for normal alpha masking.
	End Rem
	Method SetInverted(value:Int)
		If owner Then
			owner.CheckGroupMutable()
		End If

		If inverted = (value <> 0) Then
			Return
		End If

		Invalidate();inverted = value <> 0
	End Method
	Rem
	bbdoc: Preserves bounds; mask coverage is clipped to the composite's existing canvas.
	param: Finite logical input rectangle; may be the same object as output.
	param: Required reusable destination rectangle.
	End Rem
	Method ExpandBounds(input:TSceneRect, output:TSceneRect)
		CheckStageRect(input)
		If Not output Then
			Throw "Max2D SceneEffects: bounds destination is null"
		End If

		CopyStageRect(input, output)
	End Method
	Rem
	bbdoc: Estimates two full-canvas targets; borrowed source resources have their own owners.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Estimated owned texture bytes for the complete replacement layout, excluding driver overhead.
	End Rem
	Method EstimateStorageBytes:Long(layout:TSceneStageLayout)
		If Not layout Then
			Throw "Max2D SceneEffects: layout is null"
		End If

		Return layout.EstimateImageBytes(2)
	End Method
	Rem
	bbdoc: Returns zero extra storage when the current pixel layout can be reused.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Additional peak texture bytes required during preparation; zero when retained storage can be reused.
	End Rem
	Method EstimatePreparationBytes:Long(layout:TSceneStageLayout) Override
		If Reuses(layout) Then
			Return 0
		End If

		Return EstimateStorageBytes(layout)
	End Method
	Rem
	bbdoc: Prepares coverage/output storage and validates actual target alpha-blend support.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	End Rem
	Method Prepare(layout:TSceneStageLayout)
		EstimateStorageBytes(layout)
		If Not owner Then
			Throw "Max2D SceneEffects: live subtree masks require an owning composite"
		End If

		If Reuses(layout) Then
			CheckBlend(buffers.Image(0));prepared = layout;layout.CopyCanvasRect(canvas)
			Return
		End If

		Local candidate:TMax2DEffectBuffers = New TMax2DEffectBuffers
		Try
			candidate.Prepare(layout.PixelWidth(), layout.PixelHeight(), 2, -1, layout.PixelFormat())
			CheckBlend(candidate.Image(0))
			If buffers Then
				buffers.Release()
			End If
		Catch error:Object
			candidate.Release();Throw error
		End Try

		buffers = candidate;prepared = layout;layout.CopyCanvasRect(canvas)
	End Method
	Rem
	bbdoc: Rejects standalone processing; live masks need the composite's capture context.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	returns: No result; always throws because this stage requires UpdateInGroup.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		Throw "Max2D SceneEffects: live subtree masks require UpdateInGroup"
	End Method
	Rem
	bbdoc: Captures live source alpha and applies it to a distinct output, restoring caller state.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	param: Borrowed group capture context valid only during the current group draw.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Stable layouts reuse targets. Source edits require normal scene invalidation; shared raw artwork changes require InvalidateContent on source nodes. A missing source produces empty coverage. No input mask is inferred from captured pixels.
	End Rem
	Method UpdateInGroup:TRenderImage(source:TRenderImage, context:TSceneGroupContext) Override
		If Not prepared Or Not buffers Then
			Throw "Max2D SceneEffects: prepare subtree mask before update"
		End If

		Local output:TRenderImage = buffers.Image(0), coverage:TRenderImage = buffers.Image(1)
		If Not source Or source = output Or source = coverage Then
			Throw "Max2D SceneEffects: subtree mask target alias"
		End If

		If source.width <> prepared.PixelWidth() Or source.height <> prepared.PixelHeight() Or source.sources[0].targetFormat <> prepared.PixelFormat() Then
			Throw "Max2D SceneEffects: subtree mask source differs from layout"
		End If

		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			SetRenderImage(coverage)
			SetVirtualResolution(canvas.width, canvas.height);SetViewport(0, 0, Int(canvas.width), Int(canvas.height))
			SetCamera(Null);ResetCoordinates();SetAffineTransform(1, 0, 0, 1);SetOrigin(0, 0);SetHandle(0, 0)
			SetClsColor(0, 0, 0, 0);Cls
			If SourceAvailable() Then
				context.RenderSubtree(sourceNode, offsetX - canvas.x, offsetY - canvas.y)
			End If

			SetRenderImage(output)
			SetVirtualResolution(output.width, output.height);SetViewport(0, 0, output.width, output.height)
			SetCamera(Null);ResetCoordinates();SetAffineTransform(1, 0, 0, 1);SetOrigin(0, 0);SetHandle(0, 0)
			SetColor(255, 255, 255);SetAlpha(1);SetBlend(SOLIDBLEND)
			DrawImage(source, source.handle_x, source.handle_y)
			If inverted Then ApplyLayerInverseAlphaMask(coverage) Else ApplyLayerAlphaMask(coverage)
		Finally
			scope.Close()
		End Try

		Return output
	End Method
	Rem
	bbdoc: Releases only stage-owned targets, retaining the borrowed source and configuration.
	End Rem
	Method ReleaseResources()
		If buffers Then
			buffers.Release()
		End If

		buffers = Null;prepared = Null
	End Method

	Internal
	Method ValidateOwner(consumer:TCompositeNode)
		If Not sourceNode Then
			Throw "Max2D SceneEffects: subtree mask source is not configured"
		End If

		CheckMaskDependencyPath(consumer, sourceNode, Null, 0)
	End Method

	Method ResolveDependency(epoch:Long)
		Local available:Int = SourceAvailable(), continuous:Int
		If available Then
			continuous = owner.PrepareSourceDependencies(sourceNode, epoch)
		End If

		Local revision:Long = sourceNode.VisualRevision()
		If Not observed Or available <> observedAvailable Or revision <> observedRevision Or continuous Then
			Invalidate()
			observed = True;observedAvailable = available;observedRevision = revision
		End If
	End Method

	Private
	Method SourceAvailable:Int()
		Return owner And owner.Scene() And sourceNode.Scene() = owner.Scene()
	End Method

	Method Reuses:Int(layout:TSceneStageLayout)
		Return buffers And prepared And layout And prepared.PixelWidth() = layout.PixelWidth() And prepared.PixelHeight() = layout.PixelHeight() And prepared.PixelFormat() = layout.PixelFormat()
	End Method

	Method CheckBlend(target:TRenderImage)
		Local graphics:TMax2DGraphics = TMax2DGraphics.Current(), previous:TRenderImage = graphics.renderImage
		Try
			SetRenderImage(target)
			If inverted Then
				If Not Max2DSupportsLayerInverseAlpha() Then
					Throw "Max2D SceneEffects: inverse alpha masks unsupported"
				End If
			Else
				If Not Max2DSupportsLayerAlpha() Then
					Throw "Max2D SceneEffects: alpha masks unsupported"
				End If
			End If
		Finally
			If Not graphics.context.closed Then
				graphics.SetRenderImage(previous)
			End If
		End Try
	End Method
End Type

Private
Function CheckMaskDependencyPath(target:TCompositeNode, node:TSceneNode, path:TSceneNode[], depth:Int)
	If Not node Then
		Return
	End If

	If node = target Then
		Throw "Max2D SceneEffects: cyclic subtree mask dependency"
	End If

	For Local i:Int = 0 Until depth
		If path[i] = node Then
			Throw "Max2D SceneEffects: cyclic subtree mask dependency"
		End If
	Next

	If depth = path.Length Then
		path = path[..Max(16, path.Length * 2)]
	End If

	path[depth] = node
	Local group:TCompositeNode = TCompositeNode(node)
	If group Then
		group.CheckMaskPath(target, path, depth + 1)
	End If

	For Local i:Int = 0 Until node.ChildCount()
		CheckMaskDependencyPath(target, node.ChildAt(i), path, depth + 1)
	Next

	path[depth] = Null
End Function

Public
