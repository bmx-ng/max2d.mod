Rem
bbdoc: Owns a retained node tree and application-driven update traversal.
about: This foundation requires no Graphics context. Update and FixedUpdate use retained work storage and commit queued structural changes at their boundary. Render uses the current Max2D target; Pick queries virtual coordinates; DispatchPointer routes application-supplied input. DispatchKey routes focused key input, and opted-in pointers support hover.
End Rem
Type TScene
	Internal
	Field debugOverlay:Int
	Field debugPass:TSceneDebugPass = New TSceneDebugPass
	Field culling:Int
	Field renderStats:TSceneStats = New TSceneStats
	Field rootNode:TSceneNode
	Field paused:Int, dead:Int, busy:Int, rendering:Int
	Field preparingRender:Int
	Field preparationEpoch:Long
	Field preparationGroups:TSceneRenderGroup
	Field renderPass:TSceneRenderPass = New TSceneRenderPass
	Field storageLimit:Long = 268435456
	Field storageBytes:Long
	Field resourceGroups:TSceneRenderGroup
	Field resourceContext:TMax2DContext
	Field work:TSceneNode[]
	Field workCount:Int
	Field pickNodes:TSceneNode2D[]
	Field inputClip:TSceneRect
	Field pointerEvent:TScenePointerEvent = New TScenePointerEvent
	Field pointerPath:TSceneNode[]
	Field pointers:TScenePointerState[]
	Field hovers:TSceneHoverState[]
	Field focused:TSceneNode2D
	Field focusChanging:Int
	Field keyEvent:TSceneKeyEvent = New TSceneKeyEvent
	Field keyPath:TSceneNode[]
	Field focusCandidates:TSceneNode2D[]
	Field commandNodes:TSceneNode[], commandParents:TSceneNode[]
	Field commandKinds:Int[], commandIndices:Int[], commandKeep:Int[]
	Field commandCount:Int
	Field discarded:Long

	Public
	Rem
	bbdoc: Creates a scene with an attached non-spatial root and retained traversal capacity.
	returns: A new #TScene instance configured with the supplied settings.
	End Rem
	Function Create:TScene()
		Local scene:TScene = New TScene
		scene.rootNode = New TSceneNode
		scene.rootNode.sceneRoot = True
		scene.rootNode.ownerScene = scene
		scene.rootNode.ready = True
		scene.Reserve()
		Return scene
	End Function
	Rem
	bbdoc: Returns the scene's attached root; spatial content belongs beneath a layer.
	returns: The scene's attached root; spatial content belongs beneath a layer.
	End Rem
	Method Root:TSceneNode()
		Return rootNode
	End Method
	Rem
	bbdoc: Reserves traversal and deferred-operation capacity without creating nodes.
	param: Nonnegative capacity for retained traversal and input-path storage; zero leaves it unchanged.
	param: Nonnegative deferred-operation capacity; zero leaves it unchanged.
	about: Capacity grows geometrically and is retained. Call during loading to avoid growth in update loops. Requires an idle live scene. Zero leaves that capacity unchanged.
	End Rem
	Method Reserve(nodeCapacity:Int = 64, operationCapacity:Int = 64)
		CheckIdle()
		If nodeCapacity < 0 Or operationCapacity < 0 Then
			Throw "Max2D Scene: negative reserve capacity"
		End If

		EnsureWork(nodeCapacity)
		EnsureCommands(operationCapacity)
		If nodeCapacity > pointerPath.Length Then
			pointerPath = pointerPath[..SceneCapacity(pointerPath.Length, nodeCapacity)]
		End If

		If nodeCapacity > keyPath.Length Then
			keyPath = keyPath[..SceneCapacity(keyPath.Length, nodeCapacity)]
		End If

		If nodeCapacity > focusCandidates.Length Then
			focusCandidates = focusCandidates[..SceneCapacity(focusCandidates.Length, nodeCapacity)]
		End If

		If nodeCapacity > pickNodes.Length Then
			pickNodes = pickNodes[..SceneCapacity(pickNodes.Length, nodeCapacity)]
		End If
	End Method
	Rem
	bbdoc: Drops idle traversal storage and shrinks attached child arrays to their current counts.
	about: This deliberate maintenance operation may allocate and cause later regrowth. It does not release application resources. Unused reference slots are cleared on normal use even without trimming.
	End Rem
	Method TrimStorage()
		CheckIdle()
		work = Null
		pickNodes = Null
		pointerPath = Null
		debugPass.work = Null
		commandNodes = Null
		commandParents = Null
		commandKinds = Null
		commandIndices = Null
		commandKeep = Null
		TrimScenePointers(Self)
		TrimSceneHover(Self)
		keyPath = Null
		focusCandidates = Null
		TrimChildren(rootNode)
	End Method
	Rem
	bbdoc: Enables scene pause; opted-in nodes may continue updating.
	param: True to pause ordinary scene updates, False to resume them.
	End Rem
	Method SetPaused(value:Int)
		CheckAlive()
		paused = value <> 0
	End Method
	Rem
	bbdoc: Runs enabled variable-step callbacks parent first, then commits structural changes.
	param: Finite nonnegative elapsed seconds supplied by the application.
	about: Stable traversal and node movement allocate no framework objects after capacity is prepared. A callback exception aborts traversal but queued cleanup still commits before the exception is rethrown.
	End Rem
	Method Update(dt:Double)
		Process(dt, False)
	End Method
	Rem
	bbdoc: Runs one application-supplied fixed step without owning a clock or accumulator.
	param: Finite nonnegative step duration in seconds.
	End Rem
	Method FixedUpdate(dt:Double)
		Process(dt, True)
	End Method
	Rem
	bbdoc: Sets the scene-wide estimated texture-storage budget in bytes; defaults to 256 MiB.
	param: Positive texture-storage budget in bytes.
	about: Requires an idle scene and a positive limit at least as large as currently charged storage. Includes registered composite captures, stage buffers and replacement reservations, including hidden and detached groups. Excludes shared application assets and driver overhead. No automatic eviction occurs. Each composite also enforces its own limit.
	End Rem
	Method SetStorageLimitBytes(value:Long)
		CheckIdle()
		If value < 1 Or value < storageBytes Then
			Throw "Max2D Scene: storage limit must cover currently retained resources (" + storageBytes + " bytes)"
		End If

		storageLimit = value
	End Method
	Rem
	bbdoc: Returns the shared texture-storage budget in bytes.
	returns: The shared texture-storage budget in bytes.
	End Rem
	Method GetStorageLimitBytes:Long()
		Return storageLimit
	End Method
	Rem
	bbdoc: Returns current estimated registered texture storage, including outstanding preparation reservations.
	returns: Current estimated registered texture storage, including outstanding preparation reservations.
	about: Updated by allocation, release and destruction, independently of the last render snapshot. Detached groups remain charged until their resources are released.
	End Rem
	Method RetainedStorageBytes:Long()
		Return storageBytes
	End Method

	Rem
	bbdoc: Invokes resource-release hooks children first, preserving node membership and configuration.
	about: Requires an idle scene. Continues cleanup after a hook fails, then rethrows the first error. Hooks may queue tree changes, which commit after the release traversal. Also releases registered resources retained by detached groups; their nodes remain caller-owned.
	End Rem
	Method ReleaseResources()
		CheckIdle()
		busy = True
		Local error:Object
		rootNode.Notify(5, error)
		ReleaseRegisteredResources(error, True)
		Complete(error)
		If Not error Then
			resourceContext = Null
		End If

		If error Then
			Throw error
		End If
	End Method
	Rem
	bbdoc: Recursively destroys the attached tree; repeated calls are harmless.
	about: Detached subtrees remain caller-owned. During callbacks destruction commits at the boundary and suppresses subsequent updates immediately.
	End Rem
	Method Destroy()
		If preparingRender Then
			Throw "Max2D Scene: destruction during render preparation"
		End If

		If dead Or rootNode.pendingDestroy Then
			Return
		End If

		CheckAlive()
		If busy Then
			Enqueue(4, rootNode, Null, 0, False)
			rootNode.MarkPending(True)
		Else
			RunChange(4, rootNode, Null, 0, False)
		End If
	End Method
	Rem
	bbdoc: Returns the cumulative number of queued operations discarded because their nodes were destroyed or pending destruction.
	returns: The cumulative number of queued operations discarded because their nodes were destroyed or pending destruction.
	End Rem
	Method DiscardedOperations:Long()
		Return discarded
	End Method

	Rem
	bbdoc: Draws the tree on the current Max2D target, preserving caller state and viewport.
	about: Uses insertion or opted-in stable z order, inherited tint/alpha and layer cameras. Does not clear, flip or update. Scene mutation during drawing is rejected. One outer drawing scope allocates per call; per-node scene draw state is reused.
	End Rem
	Method Render()
		CheckIdle()
		renderStats.Reset()
		renderStats.storagePeak = storageBytes
		Try
			If resourceContext And resourceContext.closed Then
				ReleaseResources()
			End If

			If resourceContext And resourceContext <> TMax2DGraphics.Current().context Then
				Throw "Max2D Scene: release resources before changing graphics contexts"
			End If

			preparationEpoch :+ 1
			preparingRender = True
			Try
				Local group:TSceneRenderGroup = preparationGroups
				While group
					group.PrepareRenderDependencies(preparationEpoch)
					group = group.preparationNext
				Wend
			Finally
				preparingRender = False
			End Try

			RenderScene(Self)
		Finally
			renderStats.storageRetained = storageBytes
		End Try
	End Method

	Rem
	bbdoc: Copies the interactive outer clip in scene virtual coordinates.
	param: Finite scene virtual-surface rectangle, copied by this call; dimensions must be nonnegative. Null disables picking.
	about: Required before Pick can return a target. Independent of the current drawing target or viewport. Null clears the clip and disables picking.
	End Rem
	Method SetInputClip(rect:TSceneRect)
		CheckAlive()
		If Not rect Then
			inputClip = Null
			Return
		End If

		SceneCheckRect(rect)
		If Not inputClip Then
			inputClip = New TSceneRect
		End If

		SceneWriteRect(inputClip, rect.x, rect.y, rect.width, rect.height)
	End Method
	Rem
	bbdoc: Maps attached node-local coordinates to scene virtual coordinates, including the layer camera.
	param: Attached node whose local coordinate system is used.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	param: Receives horizontal virtual-surface output coordinate.
	param: Receives vertical virtual-surface output coordinate.
	returns: True when conversion succeeds; False leaves the output coordinates unchanged.
	about: Works for non-spatial nodes using their inherited transform. Does not clip. False leaves outputs unchanged when detached, in another scene, pending destruction or unmappable. Requires no Graphics context.
	End Rem
	Method LocalToScreen:Int(node:TSceneNode, x:Float, y:Float, screenX:Float Var, screenY:Float Var)
		Local matrix:SSceneMatrix
		If Not SceneScreenMatrix(Self, node, matrix) Then
			Return False
		End If

		Return MapPoint(matrix, x, y, screenX, screenY)
	End Method
	Rem
	bbdoc: Maps scene virtual coordinates to attached node-local coordinates.
	param: Attached node whose local coordinate system is used.
	param: Finite horizontal coordinate in scene virtual-surface units.
	param: Finite vertical coordinate in scene virtual-surface units.
	param: Receives horizontal node-local output coordinate.
	param: Receives vertical node-local output coordinate.
	returns: True when conversion succeeds; False leaves the output coordinates unchanged.
	about: Does not clip; singular or unavailable mappings return False and leave outputs unchanged. Convert native window input with Max2D's WindowToVirtual first.
	End Rem
	Method ScreenToLocal:Int(node:TSceneNode, x:Float, y:Float, localX:Float Var, localY:Float Var)
		Local matrix:SSceneMatrix, inverse:SSceneMatrix
		If Not SceneScreenMatrix(Self, node, matrix) Then
			Return False
		End If

		If Not inverse.Inverse(matrix) Then
			Return False
		End If

		Return MapPoint(inverse, x, y, localX, localY)
	End Method
	Rem
	bbdoc: Returns the topmost interactive node under a scene virtual point, or Null.
	param: Finite horizontal coordinate in scene virtual-surface units.
	param: Finite vertical coordinate in scene virtual-surface units.
	returns: The topmost interactive node under a scene virtual point, or Null.
	about: Requires SetInputClip. Respects layer clips, inherited visibility/opacity, stable drawing order and local hit shapes. Singular mappings cannot be picked. Does not dispatch events. Retained traversal storage avoids allocations after warmup; requires an idle scene.
	End Rem
	Method Pick:TSceneNode2D(x:Float, y:Float)
		CheckIdle()
		Return PickScene(Self, x, y)
	End Method

	Rem
	bbdoc: Routes a native Down, Move, Up or Cancel using scene virtual coordinates and a device/pointer ID pair.
	param: Pointer event kind: Down, Move, Up or Cancel.
	param: Adapter-supplied device identifier, stable across events for that device.
	param: Adapter-supplied pointer identifier within the device, stable for a press or touch.
	param: Finite horizontal coordinate in scene virtual-surface units.
	param: Finite vertical coordinate in scene virtual-surface units.
	param: Changed button code from the input adapter; zero when no button changes.
	param: Current button-state bit mask supplied by the input adapter.
	returns: True when the dispatched main event was handled, False otherwise.
	about: Returns whether the main event was handled. Call from an idle scene; nested dispatch is rejected. Pointer capture delivers outside input clips. Structural changes commit after dispatch. Cancel ignores coordinates. Enter/Leave are generated for opted-in hover pointers and cannot be injected.
	End Rem
	Method DispatchPointer:Int(kind:EScenePointerKind, deviceId:Long, pointerId:Long, x:Float, y:Float, button:Int = 0, buttons:Int = 0)
		CheckIdle()
		Return DispatchScenePointer(Self, kind, deviceId, pointerId, x, y, button, buttons)
	End Method
	Rem
	bbdoc: Cancels all active pointer presses and captures, for example on application focus loss.
	about: Requires an idle scene. Continues cleanup after callback failure, then rethrows the first error. Also clears keyboard focus and remembered hover positions, preserving hover opt-in configuration.
	End Rem
	Method CancelInput()
		CheckIdle()
		busy = True
		Local error:Object
		CancelScenePointers(Self, Null, error)
		ClearSceneHover(Self, Null, error)
		ClearSceneFocus(Self, Null, error)
		Complete(error)
		If error Then
			Throw error
		End If
	End Method
	Rem
	bbdoc: Preallocates retained pointer records for simultaneous presses without creating per-event objects.
	param: Nonnegative minimum retained capacity; existing storage is not reduced.
	about: Call during loading. Records are reused after Up or Cancel. Capacity also grows automatically when needed.
	End Rem
	Method ReservePointers(capacity:Int = 8)
		CheckIdle()
		If capacity < 0 Then
			Throw "Max2D Scene: negative pointer capacity"
		End If

		EnsureScenePointers(Self, capacity)
	End Method

	Rem
	bbdoc: Enables hover for one device/pointer pair, normally a mouse or pen; disabled by default.
	param: Adapter-supplied device identifier, stable across events for that device.
	param: Adapter-supplied pointer identifier within the device, stable for a press or touch.
	param: True to enable hover tracking for this device/pointer pair, False to disable it.
	about: Subsequent pointer events supply its position. Enter/Leave target only the topmost picked node and do not bubble. Captured pointers suspend hover; Update reconciles stationary pointers. Requires an idle scene.
	End Rem
	Method SetPointerHover(deviceId:Long, pointerId:Long, enabled:Int = True)
		CheckIdle()
		ConfigureSceneHover(Self, deviceId, pointerId, enabled)
	End Method
	Rem
	bbdoc: Gives keyboard focus to an eligible attached focusable node, or clears it with Null.
	param: Eligible attached focusable node, or Null to clear keyboard focus.
	about: May be called from input callbacks. Nested focus changes from focus notifications are rejected. Focus does not automatically follow pointer presses.
	End Rem
	Method SetFocus(node:TSceneNode2D)
		CheckAlive()
		Local outerBusy:Int = busy
		busy = True
		Local error:Object
		Try
			ChangeSceneFocus(Self, node)
		Catch caught:Object
			error = caught
		End Try

		If Not outerBusy Then
			Complete(error)
		End If

		If error Then
			Throw error
		End If
	End Method
	Rem
	bbdoc: Returns the current keyboard focus, or Null.
	returns: The current keyboard focus, or Null.
	End Rem
	Method FocusedNode:TSceneNode2D()
		Return focused
	End Method
	Rem
	bbdoc: Moves focus in explicit focus order with insertion-order ties, wrapping at either end.
	param: True to visit the previous eligible focus target, False to visit the next.
	about: Requires an idle scene. Reverse visits the preceding eligible node. No candidate clears focus.
	End Rem
	Method FocusNext(reverse:Int = False)
		CheckIdle()
		NavigateSceneFocus(Self, reverse)
	End Method
	Rem
	bbdoc: Routes a physical key Down or Up through the focused node's ancestor path.
	param: Physical key event kind: Down or Up.
	param: Physical key code supplied by the input adapter.
	param: Bitwise combination of SCENE_MOD modifier flags; zero means no modifiers.
	param: True for an operating-system key repeat, False for an initial press.
	returns: True when the dispatched main event was handled, False otherwise.
	about: Returns whether handled. Modifiers use SCENE_MOD constants; repeated distinguishes key repeat. Does not poll keys, compose text or perform automatic Tab navigation. Requires an idle scene.
	End Rem
	Method DispatchKey:Int(kind:ESceneKeyKind, key:Int, modifiers:Int = 0, repeated:Int = False)
		CheckIdle()
		Return DispatchSceneKey(Self, kind, key, modifiers, repeated)
	End Method

	Rem
	bbdoc: Returns an allocated developer-readable snapshot of the attached tree without requiring Graphics.
	returns: An allocated developer-readable snapshot of the attached tree without requiring Graphics.
	about: Lists child-index paths, names, built-in node categories, lifecycle/input state, cached bounds and dirty flags. Does not invoke drawing or bounds callbacks, rebuild caches, read GPU pixels or alter statistics. Custom subclasses are identified by their nearest built-in category and diagnostic name. Requires an idle live scene.
	End Rem
	Method InspectTree:String()
		CheckIdle()
		Return InspectSceneTree(Self)
	End Method
	Rem
	bbdoc: Enables a diagnostic overlay drawn after scene content; disabled by default.
	param: True to enable the scene diagnostic overlay, False to disable it.
	about: Cyan outlines content bounds, yellow outlines output bounds, green shows eligible rectangular hit regions and magenta crosses mark unknown bounds. Uses live transforms and layer clips, including descendants of cached composites. Custom hit tests are represented by their declared rectangle or self bounds, not their exact shape. Preserves caller drawing state and does not change picking. Overlay work is excluded from scene counters but appears in backend drawing statistics. Bounds queries can warm caches; debug rendering is not a performance benchmark.
	End Rem
	Method SetDebugOverlay(enabled:Int)
		CheckIdle()
		debugOverlay = enabled <> 0
	End Method
	Rem
	bbdoc: Returns whether the diagnostic overlay is enabled.
	returns: Whether the diagnostic overlay is enabled.
	End Rem
	Method GetDebugOverlay:Int()
		Return debugOverlay
	End Method

	Rem
	bbdoc: Enables conservative offscreen subtree culling; disabled by default.
	param: True to enable conservative offscreen subtree culling, False to disable it.
	about: Requires accurate drawing bounds. Unknown bounds keep rendering. Does not suppress updates or input. Custom draw callbacks must not rely on running when their declared output is offscreen.
	End Rem
	Method SetCulling(enabled:Int)
		CheckAlive()
		culling = enabled <> 0
	End Method
	Rem
	bbdoc: Allocates a read-only snapshot of the most recent render's scene traversal statistics.
	returns: A new independent statistics snapshot.
	End Rem
	Method CaptureStats:TSceneStats()
		Local result:TSceneStats = New TSceneStats
		CopyStats(result)
		Return result
	End Method
	Rem
	bbdoc: Copies render statistics into a reusable destination without allocating.
	param: Required reusable destination scene-statistics snapshot.
	about: Before the first render counts are zero and Completed is False. A failed render leaves partial counts with Completed False. These are scene traversal counts, not backend draw calls or GPU timings.
	End Rem
	Method CopyStats(output:TSceneStats)
		If Not output Then
			Throw "Max2D Scene: statistics destination is null"
		End If

		renderStats.CopyTo(output)
	End Method

	Internal
	Method ReleaseRegisteredResources(error:Object Var, detachedOnly:Int = False)
		Local group:TSceneRenderGroup = resourceGroups
		While group
			Local following:TSceneRenderGroup = group.resourceNext
			If Not detachedOnly Or group.ownerScene <> Self Then
				Try
					group.OnReleaseResources()
				Catch caught:Object
					If Not error Then
						error = caught
					End If
				End Try
			End If

			group = following
		Wend
	End Method

	Method CheckAlive()
		If dead Or Not rootNode Then
			Throw "Max2D Scene: scene is not live"
		End If

		If rendering Then
			Throw "Max2D Scene: scene mutation during drawing is not allowed"
		End If

		If scenePickDepth Then
			Throw "Max2D Scene: mutation during picking is not allowed"
		End If

		If sceneBoundsDepth Then
			Throw "Max2D Scene: mutation during bounds calculation is not allowed"
		End If
	End Method

	Method CheckIdle()
		CheckAlive()
		If busy Or preparingRender Then
			Throw "Max2D Scene: operation requires an idle scene"
		End If
	End Method

	Method EnsureWork(capacity:Int)
		If capacity > work.Length Then
			work = work[..SceneCapacity(work.Length, capacity)]
		End If
	End Method

	Method EnsureCommands(capacity:Int)
		If capacity <= commandNodes.Length Then
			Return
		End If

		Local size:Int = SceneCapacity(commandNodes.Length, capacity)
		commandNodes = commandNodes[..size]
		commandParents = commandParents[..size]
		commandKinds = commandKinds[..size]
		commandIndices = commandIndices[..size]
		commandKeep = commandKeep[..size]
	End Method

	Method Enqueue(kind:Int, node:TSceneNode, parent:TSceneNode, index:Int, keep:Int)
		EnsureCommands(commandCount + 1)
		commandKinds[commandCount] = kind
		commandNodes[commandCount] = node
		commandParents[commandCount] = parent
		commandIndices[commandCount] = index
		commandKeep[commandCount] = keep
		commandCount :+ 1
	End Method

	Method Process(dt:Double, fixed:Int)
		CheckIdle()
		SceneCheckFinite(dt)
		If dt < 0 Then
			Throw "Max2D Scene: elapsed time must be nonnegative"
		End If

		busy = True
		Local error:Object
		Try
			EnsureWork(1)
			work[0] = rootNode
			workCount = 1
			While workCount
				workCount :- 1
				Local node:TSceneNode = work[workCount]
				work[workCount] = Null
				If node.dead Or node.pendingDestroy Then
					Continue
				End If

				If Not paused Or node.processPaused Then
					If fixed Then
						If node.fixedProcessing Then
							node.OnFixedUpdate(dt)
						End If
					Else
						If node.processing Then
							node.OnUpdate(dt)
						End If
					End If
				End If

				If node.pendingDestroy Then
					Continue
				End If

				EnsureWork(workCount + node.itemCount)
				For Local i:Int = node.itemCount - 1 To 0 Step -1
					work[workCount] = node.items[i]
					workCount :+ 1
				Next
			Wend
		Catch caught:Object
			error = caught
		End Try

		Complete(error)
		If error Then
			Throw error
		End If
	End Method

	Method Complete(error:Object Var)
		' Clear even unvisited nodes when a callback throws.
		For Local i:Int = 0 Until workCount
			work[i] = Null
		Next

		workCount = 0
		ReconcileScenePointers(Self, error)
		ReconcileSceneFocus(Self, error)
		ReconcileSceneHover(Self, error)
		Local cursor:Int
		While cursor < commandCount And cursor < 100000
			Local node:TSceneNode = commandNodes[cursor], parent:TSceneNode = commandParents[cursor]
			Local kind:Int = commandKinds[cursor], index:Int = commandIndices[cursor], keep:Int = commandKeep[cursor]
			commandNodes[cursor] = Null
			commandParents[cursor] = Null
			cursor :+ 1
			If node.dead Or (node.pendingDestroy And kind <> 4) Or (parent And (parent.dead Or parent.pendingDestroy)) Then
				discarded :+ 1
				Continue
			End If

			Try
				ApplyChange(kind, node, parent, index, keep)
			Catch caught:Object
				If Not error Then
					error = caught
				End If
			End Try

			ReconcileScenePointers(Self, error)
			ReconcileSceneFocus(Self, error)
			ReconcileSceneHover(Self, error)
		Wend

		If cursor < commandCount Then
			If Not error Then
				error = "Max2D Scene: structural callback limit exceeded"
			End If

			For Local i:Int = cursor Until commandCount
				If commandKinds[i] = 4 And Not commandNodes[i].dead Then
					commandNodes[i].MarkPending(False)
				End If

				commandNodes[i] = Null
				commandParents[i] = Null
			Next
		End If

		commandCount = 0
		busy = False
		If rootNode.dead Then
			ReleaseRegisteredResources(error)
			dead = True
			work = Null
			pickNodes = Null
			pointerPath = Null
			commandNodes = Null
			commandParents = Null
			commandKinds = Null
			commandIndices = Null
			commandKeep = Null
			pointers = Null
			hovers = Null
			keyPath = Null
			focusCandidates = Null
		End If
	End Method
End Type

Private

Function SceneCapacity:Int(current:Int, requested:Int)
	Local size:Int = Max(8, current)
	While size < requested
		If size > 1073741823 Then
			Return requested
		End If

		size :* 2
	Wend

	Return size
End Function

Function TrimChildren(node:TSceneNode)
	If node.items.Length <> node.itemCount Then
		node.items = node.items[..node.itemCount]
	End If

	If node.sortable Then
		node.drawOrder = node.drawOrder[..node.itemCount]
		node.orderScratch = node.orderScratch[..node.itemCount]
	Else
		node.drawOrder = Null
		node.orderScratch = Null
	End If

	node.orderDirty = True
	For Local i:Int = 0 Until node.itemCount
		TrimChildren(node.items[i])
	Next
End Function

Function RunChange(kind:Int, node:TSceneNode, parent:TSceneNode, index:Int, keep:Int)
	Local scene:TScene = node.ownerScene
	If Not scene And parent Then
		scene = parent.ownerScene
	End If

	If Not scene Then
		ApplyChange(kind, node, parent, index, keep)
		Return
	End If

	scene.CheckIdle()
	scene.busy = True
	Local error:Object
	Try
		ApplyChange(kind, node, parent, index, keep)
	Catch caught:Object
		error = caught
	End Try

	scene.Complete(error)
	If error Then
		Throw error
	End If
End Function

Function ApplyChange(kind:Int, node:TSceneNode, parent:TSceneNode, index:Int, keep:Int)
	Local error:Object
	Select kind
		Case 1, 3
			parent.CheckAdd(node, index, kind = 3)
			If kind = 3 And node.parentNode = parent Then
				Return
			End If

			If node.ownerScene And parent.ownerScene And node.ownerScene <> parent.ownerScene Then
				Throw "Max2D Scene: detach before moving between scenes"
			End If

			Local replacement:SSceneMatrix
			If keep Then
				Local spatial:TSceneNode2D = TSceneNode2D(node)
				If Not spatial Then
					Throw "Max2D Scene: preserve-world requires a spatial node"
				End If

				If node.Layer() <> parent.Layer() Then
					Throw "Max2D Scene: preserve-world cannot cross layers"
				End If

				spatial.EnsureWorld()
				Local destination:TSceneNode2D = TSceneNode2D(parent)
				If Not destination Then
					destination = parent.SpatialParent()
				End If

				If destination Then
					destination.EnsureWorld()
					Local inverse:SSceneMatrix
					If Not inverse.Inverse(destination.worldMatrix) Then
						Throw "Max2D Scene: new parent transform is singular"
					End If

					replacement.Product(inverse, spatial.worldMatrix)
				Else
					replacement = spatial.worldMatrix
				End If
			End If

			parent.ReserveChildren(parent.itemCount + 1)
			Local oldScene:TScene = node.ownerScene, newScene:TScene = parent.ownerScene
			If oldScene Then
				CancelScenePointers(oldScene, node, error)
				ClearSceneHover(oldScene, node, error)
				If oldScene <> newScene Then
					ClearSceneFocus(oldScene, node, error)
				End If
			End If

			If oldScene <> newScene And oldScene Then
				node.Notify(3, error)
			End If

			node.Unlink()
			parent.Link(node, index)
			If keep Then
				Local spatial:TSceneNode2D = TSceneNode2D(node)
				spatial.localMatrix = replacement
				spatial.affine = True
				spatial.DirtyWorld()
			End If

			If oldScene <> newScene Then
				node.SetScene(newScene)
				If newScene Then node.Notify(1, error); node.Notify(2, error)
			End If
		Case 2
			node.CheckAlive()
			If node.parentNode <> parent Then
				Throw "Max2D Scene: queued removal parent changed"
			End If

			If node.ownerScene Then
				CancelScenePointers(node.ownerScene, node, error)
				ClearSceneHover(node.ownerScene, node, error)
				ClearSceneFocus(node.ownerScene, node, error)
				node.Notify(3, error)
			End If

			node.Unlink()
			node.SetScene(Null)
		Case 4
			If node.dead Then
				Return
			End If

			node.MarkPending(True)
			If node.ownerScene Then
				CancelScenePointers(node.ownerScene, node, error)
				ClearSceneHover(node.ownerScene, node, error)
				ClearSceneFocus(node.ownerScene, node, error)
				node.Notify(3, error)
			End If

			node.FinishDestroy(error)
	End Select

	If error Then
		Throw error
	End If
End Function

Public
