Rem
bbdoc: Provider base for an isolated rendering boundary, with ordinary scene ownership and input.
about: The renderer invokes OnRenderGroup instead of drawing this node's descendants directly. Providers can capture children through the borrowed context, then present their output. Ordinary applications should use Max2D.SceneEffects.TCompositeNode. This base owns no graphics resources.
End Rem
Type TSceneRenderGroup Extends TSceneNode2D Abstract
	Internal
	Field preparationEnabled:Int
	Field preparationScene:TScene
	Field preparationPrevious:TSceneRenderGroup, preparationNext:TSceneRenderGroup
	Field resourceScene:TScene
	Field resourcePrevious:TSceneRenderGroup, resourceNext:TSceneRenderGroup
	Field chargedBytes:Long
	Field groupContext:TSceneGroupContext = New TSceneGroupContext
	Field outputRect:TSceneRect
	Field continuousChildren:Int
	Method LinkRenderPreparation(scene:TScene)
		If preparationScene Then
			If preparationPrevious Then
				preparationPrevious.preparationNext = preparationNext
			Else
				preparationScene.preparationGroups = preparationNext
			End If

			If preparationNext Then
				preparationNext.preparationPrevious = preparationPrevious
			End If
		End If

		preparationScene = Null;preparationPrevious = Null;preparationNext = Null
		If scene And preparationEnabled Then
			preparationScene = scene;preparationNext = scene.preparationGroups
			If preparationNext Then
				preparationNext.preparationPrevious = Self
			End If

			scene.preparationGroups = Self
		End If
	End Method

	Public
	Rem
	bbdoc: Enables this provider's dependency preparation before scene drawing; disabled by default.
	param: True to enable pre-draw dependency preparation for this provider, False to disable it.
	about: Membership follows scene attachment without per-frame tree scanning. Must not change during preparation. Does not allocate graphics resources.
	End Rem
	Method SetRenderPreparation(enabled:Int)
		CheckGroupMutable()
		preparationEnabled = enabled <> 0
		LinkRenderPreparation(Scene())
	End Method
	Rem
	bbdoc: Resolves provider dependencies before any scene pixels are submitted.
	param: The render-attempt identifier supplied to PrepareRenderDependencies; not an application frame counter.
	about: Called only for opted-in groups, including hidden groups. epoch identifies this render attempt within the scene. Providers may invalidate output and dependent caches, but must not draw, change tree structure, change preparation membership or start scene traversal. The hook runs before normal rendering mutation guards; exceptions abort the render. The default does nothing.
	End Rem
	Method PrepareRenderDependencies(epoch:Long)
	End Method
	Rem
	bbdoc: Resolves a same-scene source subtree once per render attempt and returns whether it needs continuous rendering.
	param: Required source subtree attached to this provider's scene.
	param: The render-attempt identifier supplied to PrepareRenderDependencies; not an application frame counter.
	returns: True if any source render group requires continuous rendering, False otherwise.
	about: Provider helper for use only inside PrepareRenderDependencies with its supplied epoch. Resolves opted-in descendant providers before querying continuous-render requirements. Overlapping sources share results; failed or cyclic traversals are not cached. Attachment changes discard results. Does not capture pixels or allocate per-call storage.
	End Rem
	Method PrepareSourceDependencies:Int(source:TSceneNode, epoch:Long)
		Local scene:TScene = Scene()
		If Not scene Or Not scene.preparingRender Or scene.preparationEpoch <> epoch Then
			Throw "Max2D Scene: source preparation requires the current dependency phase"
		End If

		If Not source Or source.Scene() <> scene Then
			Throw "Max2D Scene: source preparation requires a same-scene subtree"
		End If

		Return ScenePrepareSourceDependencies(source, epoch)
	End Method
	Rem
	bbdoc: Provider hook reducing registered storage after successful preparation or resource release.
	param: Remaining owned texture bytes, no greater than the most recent reservation; report zero after release.
	about: May only reduce the most recent reservation; use context.ReserveStorageBytes before allocation. Report zero only after owned resources are released. Callable during release, including destruction. Partial release failures may conservatively retain their charge.
	End Rem
	Method ReportStorageBytes(value:Long)
		If value < 0 Or value > chargedBytes Then
			Throw "Max2D Scene: storage report exceeds reservation"
		End If

		If Not resourceScene Then
			Return
		End If

		resourceScene.storageBytes :- chargedBytes - value
		chargedBytes = value
		If value = 0 Then
			If resourcePrevious Then
				resourcePrevious.resourceNext = resourceNext
			Else
				resourceScene.resourceGroups = resourceNext
			End If

			If resourceNext Then
				resourceNext.resourcePrevious = resourcePrevious
			End If

			resourceScene = Null; resourcePrevious = Null; resourceNext = Null
		End If
	End Method
	Rem
	bbdoc: Renders this boundary; restore all drawing state and target changes before returning.
	param: Borrowed group capture context valid only during the current group draw.
	about: Providers may capture children using context.RenderChildren. Do not mutate scene state, retain the context, change canvas or call scene.Render recursively. Release owned resources in OnReleaseResources.
	End Rem
	Method OnRenderGroup(context:TSceneGroupContext) Abstract
	Rem
	bbdoc: Tests whether a local point may reach this rendering group or its descendants during picking.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	returns: True when the point passes this input test, False otherwise.
	about: Defaults to True. Override for a clipping or masking boundary. The scene converts the pointer to this group's local coordinates before calling; singular transforms reject the branch. Applies to fresh picking and hover, not delivery to an already captured pointer. Must not mutate the scene or start another traversal.
	End Rem
	Method HitTestInputClip:Int(x:Float, y:Float)
		Return True
	End Method
	Rem
	bbdoc: Returns whether this group's output must be rebuilt each render.
	returns: Whether this group's output must be rebuilt each render.
	about: Bounds caches retain this flag, including visible descendants. Call InvalidateContent when it changes. Must be a read-only query.
	End Rem
	Method RequiresContinuousRender:Int()
		Return False
	End Method
	Rem
	bbdoc: Fills local output bounds from known or unknown content bounds.
	param: True when content bounds are known, False when descendants have unknown bounds.
	param: Caller-supplied local content bounds, meaningful when known is True.
	param: Required reusable destination rectangle.
	returns: True when output bounds are known and written; False when the output cannot be bounded.
	about: Providers may replace unknown content with an explicit capture region. Read-only; do not mutate the tree. Returning False leaves bounds unknown. Default output equals content.
	End Rem
	Method MeasureGroupOutput:Int(known:Int, content:TSceneRect, output:TSceneRect)
		If Not known Then
			Return False
		End If

		SceneWriteRect(output, content.x, content.y, content.width, content.height)
		Return True
	End Method
	Rem
	bbdoc: Returns the revision of local content, excluding this group's own placement.
	returns: The revision of local content, excluding this group's own placement.
	about: Includes descendant drawing changes. Inherited tint and alpha are supplied separately by the rendering context. External shared-resource edits require InvalidateContent.
	End Rem
	Method ContentRevision:Long()
		Return contentVersion
	End Method
	Rem
	bbdoc: Reports whether a visible descendant requests continuous rendering.
	returns: True if a visible descendant requests continuous rendering, False otherwise.
	End Rem
	Method HasContinuousChildren:Int()
		CheckLive()
		sceneBoundsDepth :+ 1
		Try
			EnsureBounds()
			Return continuousChildren
		Finally
			sceneBoundsDepth :- 1
		End Try
	End Method
	Rem
	bbdoc: Provider guard for configuration setters; rejects changes during scene preparation, rendering or queries.
	End Rem
	Method CheckGroupMutable()
		CheckAlive()
		If ownerScene And ownerScene.preparingRender Then
			Throw "Max2D Scene: group configuration during render preparation"
		End If
	End Method
	Rem
	bbdoc: Invalidates output bounds and enclosing captures while preserving the local source revision.
	about: Use after effect changes that can alter padding without changing child drawing.
	End Rem
	Method InvalidateOutputBounds()
		CheckAlive()
		boundsDirty = True; visualVersion :+ 1
		If parentNode Then
			parentNode.InvalidateBounds()
		End If
	End Method
	Rem
	bbdoc: Invalidates enclosing captures after presentation-only changes such as flattened opacity.
	End Rem
	Method InvalidatePresentation()
		CheckAlive(); visualVersion :+ 1
		If parentNode Then
			parentNode.InvalidateBounds()
		End If
	End Method
End Type

Rem
bbdoc: Borrowed render-group context for local subtree capture and diagnostics.
about: Valid only during OnRenderGroup. Child rendering inherits tint and per-draw alpha, and uses the currently selected target and viewport. Layer-camera and ancestor transforms remain outside the capture.
End Rem
Type TSceneGroupContext
	Internal
	Field active:Int, capturing:Int
	Field scene:TScene
	Field node:TSceneRenderGroup
	Field canvas:TMax2DGraphics
	Field pass:TSceneRenderPass = New TSceneRenderPass
	Public
	Rem
	bbdoc: Renders children in group-local coordinates translated by the supplied offset.
	param: Finite horizontal offset in capture-local logical units.
	param: Finite vertical offset in capture-local logical units.
	about: Select and clear a capture target first. Its current virtual resolution and viewport define the capture. Caller target and state are restored even if a child throws. Nested groups use independent retained traversal storage.
	End Rem
	Method RenderChildren(offsetX:Float = 0, offsetY:Float = 0)
		CheckActive(); SceneCheckFinite(offsetX); SceneCheckFinite(offsetY)
		If capturing Then
			Throw "Max2D Scene: recursive capture of the same render group"
		End If

		Local scope:TSceneStateScope = pass.scope
		scope.Open(TMax2DGraphics.Current())
		capturing = True
		scene.renderStats.captures :+ 1
		Try
			pass.Run(scene, canvas, scope, node, offsetX, offsetY)
		Finally
			Try
				scope.Close()
			Finally
				capturing = False
			End Try
		End Try
	End Method
	Rem
	bbdoc: Renders a selected same-scene subtree in its parent's local coordinates onto the current target.
	param: Required source subtree attached to this group's scene; ownership is unchanged.
	param: Finite horizontal offset in capture-local logical units.
	param: Finite vertical offset in capture-local logical units.
	about: Provider capture primitive. Includes the source node's local transform, tint, alpha and visibility, then its descendants. Ancestor transforms, tint, visibility, camera and viewport are excluded. offsetX/Y translate the isolated result. Select and clear a target first; this method does neither. Restores caller drawing state and target on success or failure. Does not change ownership, input routing or normal scene visibility, and does not track cache dependencies. Rejects detached/destroyed sources and subtrees containing an active render group before drawing. The context is borrowed only during OnRenderGroup.
	End Rem
	Method RenderSubtree(source:TSceneNode2D, offsetX:Float = 0, offsetY:Float = 0)
		CheckActive(); SceneCheckFinite(offsetX); SceneCheckFinite(offsetY)
		If capturing Then
			Throw "Max2D Scene: recursive capture of the same render group"
		End If

		If Not source Then
			Throw "Max2D Scene: subtree source is null"
		End If

		source.CheckLive()
		If source.ownerScene <> scene Then
			Throw "Max2D Scene: subtree source must belong to the same scene"
		End If

		CheckSubtreeCapture(source)
		Local scope:TSceneStateScope = pass.scope
		scope.Open(canvas)
		capturing = True
		scene.renderStats.captures :+ 1
		Try
			pass.Run(scene, canvas, scope, node, offsetX, offsetY, source)
		Finally
			Try
				scope.Close()
			Finally
				capturing = False
			End Try
		End Try
	End Method
	Rem
	bbdoc: Binds lazily allocated scene resources to the current graphics context.
	about: Call before allocating provider resources. Scene.ReleaseResources permits migration to another context.
	End Rem
	Method BindResources()
		CheckActive()
		If node.resourceScene And node.resourceScene <> scene Then
			Throw "Max2D Scene: release composite resources before moving to another scene: " + node.GetName()
		End If

		If scene.resourceContext And scene.resourceContext <> canvas.context Then
			Throw "Max2D Scene: release resources before changing graphics contexts"
		End If

		scene.resourceContext = canvas.context
	End Method
	Rem
	bbdoc: Reserves this group's total peak texture bytes before preparation.
	param: Total peak texture bytes for this group, including retained and candidate allocations.
	about: Includes existing and candidate storage. Checks the shared scene budget before allocation, then updates its peak counter. After successful preparation call node.ReportStorageBytes with final ownership; release paths must report released resources. No allocation or traversal is needed for bookkeeping.
	End Rem
	Method ReserveStorageBytes(peak:Long)
		CheckActive(); BindResources()
		If peak < node.chargedBytes Then
			Throw "Max2D Scene: storage reservation must include retained resources"
		End If

		Local others:Long = scene.storageBytes - node.chargedBytes
		If peak > scene.storageLimit Or others > scene.storageLimit - peak Then
			Local label:String = node.GetName()
			If Not label Then
				label = "unnamed composite"
			End If

			Local path:String
			Local current:TSceneNode = node
			While current.parentNode
				Local parent:TSceneNode = current.parentNode
				For Local index:Int = 0 Until parent.itemCount
					If parent.items[index] = current Then
						path = "/" + index + path
						Exit
					End If
				Next

				current = parent
			Wend

			label :+ " at root" + path
			Throw "Max2D Scene: storage budget exceeded by '" + label + "' (group peak " + peak + " bytes, other groups " + others + " bytes, scene limit " + scene.storageLimit + " bytes)"
		End If

		If peak > 0 And Not node.resourceScene Then
			node.resourceScene = scene; node.resourceNext = scene.resourceGroups
			If scene.resourceGroups Then
				scene.resourceGroups.resourcePrevious = node
			End If

			scene.resourceGroups = node
		End If

		node.chargedBytes = peak; scene.storageBytes = others + peak
		scene.renderStats.storagePeak = Max(scene.renderStats.storagePeak, scene.storageBytes)
	End Method
	Rem
	bbdoc: Copies inherited RGB multipliers and per-draw alpha without allocating.
	param: Receives red multiplier in the range 0..1.
	param: Receives green multiplier in the range 0..1.
	param: Receives blue multiplier in the range 0..1.
	param: Receives opacity multiplier in the inclusive range 0..1.
	End Rem
	Method GetTint(red:Float Var, green:Float Var, blue:Float Var, alpha:Float Var)
		CheckActive()
		red = node.renderRed; green = node.renderGreen; blue = node.renderBlue; alpha = node.renderAlpha
	End Method
	Rem
	bbdoc: Records presentation of a cached result without recapturing children.
	End Rem
	Method RecordCacheHit()
		CheckActive(); scene.renderStats.cacheHits :+ 1
	End Method
	Rem
	bbdoc: Records one completed effect-stage update, regardless of its internal passes.
	End Rem
	Method RecordStagePass()
		CheckActive(); scene.renderStats.stagePasses :+ 1
	End Method

	Private
	Method CheckSubtreeCapture(source:TSceneNode)
		Local group:TSceneRenderGroup = TSceneRenderGroup(source)
		If group And group.groupContext.active Then
			Throw "Max2D Scene: subtree capture contains an active render group"
		End If

		For Local i:Int = 0 Until source.itemCount
			CheckSubtreeCapture(source.items[i])
		Next
	End Method

	Method CheckActive()
		If Not active Or Not scene Or TMax2DGraphics.selected <> canvas Then
			Throw "Max2D Scene: render-group context is not active on this canvas"
		End If
	End Method
End Type

Private
Function ScenePrepareSourceDependencies:Int(node:TSceneNode, epoch:Long)
	If node.sourcePreparationResolving Then
		Throw "Max2D Scene: cyclic source preparation dependency"
	End If

	If node.sourcePreparationEpoch = epoch Then
		Return node.sourcePreparationContinuous
	End If

	node.sourcePreparationResolving = True
	Local continuous:Int
	Try
		Local group:TSceneRenderGroup = TSceneRenderGroup(node)
		If group Then
			If group.preparationEnabled Then
				group.PrepareRenderDependencies(epoch)
			End If

			continuous = group.RequiresContinuousRender()
		End If

		For Local i:Int = 0 Until node.itemCount
			If ScenePrepareSourceDependencies(node.items[i], epoch) Then
				continuous = True
			End If
		Next

		node.sourcePreparationContinuous = continuous
		node.sourcePreparationEpoch = epoch
	Finally
		node.sourcePreparationResolving = False
	End Try

	Return continuous
End Function

Public
