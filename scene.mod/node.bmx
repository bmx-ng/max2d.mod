Rem
bbdoc: A retained scene-tree node with explicit lifecycle and optional processing.
about: Removing a child detaches it for reuse; Destroy recursively ends its lifetime. Application images and other shared resources are not owned by this base type. Children and snapshot queries allocate only when explicitly requested; indexed traversal reuses retained storage.
End Rem
Type TSceneNode
	Internal
	Field inputEnabled:Int = True
	Field parentNode:TSceneNode
	Field ownerScene:TScene
	Field items:TSceneNode[]
	Field itemCount:Int
	Field label:String
	Field ready:Int, dead:Int, pendingDestroy:Int, sceneRoot:Int
	Field processing:Int, fixedProcessing:Int, processPaused:Int
	Field renderRed:Float, renderGreen:Float, renderBlue:Float, renderAlpha:Float
	Field renderLayer:TLayerNode
	Field sortable:Int, orderDirty:Int = True
	Field drawOrder:Int[], orderScratch:Int[]
	Field boundsDirty:Int = True, boundsResolving:Int
	Field contentBounds:SSceneBounds, outputBounds:SSceneBounds
	Field contentVersion:Long
	Field visualVersion:Long
	Field sourcePreparationEpoch:Long
	Field sourcePreparationContinuous:Int, sourcePreparationResolving:Int
	Field uncachedSubtree:Int
	Field renderMatrix:SSceneMatrix

	Public
	Rem
	bbdoc: Sets an optional diagnostic name; names need not be unique.
	param: Diagnostic name; it need not be unique.
	End Rem
	Method SetName(name:String)
		CheckAlive()
		label = name
	End Method
	Rem
	bbdoc: Returns this node's diagnostic name.
	returns: This node's diagnostic name.
	End Rem
	Method GetName:String()
		Return label
	End Method
	Rem
	bbdoc: Returns the committed parent, or Null when detached.
	returns: The committed parent, or Null when detached.
	End Rem
	Method Parent:TSceneNode()
		Return parentNode
	End Method
	Rem
	bbdoc: Returns the attached scene, or Null when detached.
	returns: The attached scene, or Null when detached.
	End Rem
	Method Scene:TScene()
		Return ownerScene
	End Method
	Rem
	bbdoc: Returns the committed number of children without allocating.
	returns: The committed number of children without allocating.
	End Rem
	Method ChildCount:Int()
		Return itemCount
	End Method
	Rem
	bbdoc: Returns a committed child by zero-based index without allocating.
	param: Zero-based committed child index, from zero to ChildCount()-1.
	returns: A committed child by zero-based index without allocating.
	End Rem
	Method ChildAt:TSceneNode(index:Int)
		If index < 0 Or index >= itemCount Then
			Throw "Max2D Scene: child index outside range"
		End If

		Return items[index]
	End Method
	Rem
	bbdoc: Allocates a detached array containing the committed children.
	returns: A new array of borrowed child references in committed insertion order.
	about: Editing the array does not alter the tree. The array retains its node references until released; prefer ChildCount and ChildAt in hot loops.
	End Rem
	Method Children:TSceneNode[]()
		Return items[..itemCount]
	End Method
	Rem
	bbdoc: Reserves child capacity without creating child objects or changing membership.
	param: Nonnegative minimum retained capacity; existing storage is not reduced.
	about: Capacity grows geometrically when necessary and is retained after removals. Unused slots contain Null.
	End Rem
	Method ReserveChildren(capacity:Int)
		CheckAlive()
		If capacity < 0 Then
			Throw "Max2D Scene: negative child capacity"
		End If

		If capacity <= items.Length Then
			If sortable Then
				EnsureOrderCapacity(items.Length)
			End If

			Return
		End If

		Local size:Int = Max(4, items.Length)
		While size < capacity
			If size > 1073741823 Then size = capacity; Exit

			size :* 2
		Wend

		items = items[..size]
		If sortable Then
			EnsureOrderCapacity(size)
		End If
	End Method
	Rem
	bbdoc: Enables stable z-index drawing order for this parent's direct children.
	param: True to enable stable sibling z-order sorting, False to disable it.
	about: Disabled by default. Non-spatial children have z-index zero. Sorting keeps each subtree together and does not change ChildAt, Children, lifecycle or update order. Storage is retained between rebuilds.
	End Rem
	Method SetSortableChildren(enabled:Int)
		CheckAlive()
		If sortable = (enabled <> 0) Then
			Return
		End If

		sortable = enabled <> 0
		orderDirty = True
		InvalidateBounds()
		If sortable Then
			EnsureOrderCapacity(items.Length)
		End If
	End Method

	Rem
	bbdoc: Adds an unparented child at an index, or appends with index -1.
	param: Required unparented child to attach.
	param: Insertion index, or -1 to append.
	about: Structural changes requested during scene callbacks commit at the traversal boundary. Invalid parents, cycles and duplicate ownership are rejected.
	End Rem
	Method AddChild(child:TSceneNode, index:Int = -1)
		CheckAdd(child, index, False)
		If ownerScene And ownerScene.busy Then
			ownerScene.Enqueue(1, child, Self, index, False)
		Else
			RunChange(1, child, Self, index, False)
		End If
	End Method
	Rem
	bbdoc: Detaches a direct child without destroying it or releasing its resources.
	param: Required direct child to detach without destroying it.
	End Rem
	Method RemoveChild(child:TSceneNode)
		If ownerScene And ownerScene.preparingRender Then
			Throw "Max2D Scene: structural mutation during render preparation"
		End If

		CheckAlive()
		If Not child Or child.parentNode <> Self Then
			Throw "Max2D Scene: node is not a direct child"
		End If

		child.CheckAlive()
		If ownerScene And ownerScene.busy Then
			ownerScene.Enqueue(2, child, Self, 0, False)
		Else
			RunChange(2, child, Self, 0, False)
		End If
	End Method
	Rem
	bbdoc: Moves this node to another parent, optionally preserving its world affine transform.
	param: New parent in the same scene; must not be Null.
	param: True to preserve the world affine transform, False to retain the local transform.
	about: Preserve-world requires a spatial node, an invertible new spatial parent and the same layer. It can retain shear. Cross-scene moves require explicit detach then attach outside callbacks. Queued operations preserve the world transform as it exists at commit time.
	End Rem
	Method Reparent(parent:TSceneNode, preserveWorld:Int = False)
		If ownerScene And ownerScene.preparingRender Then
			Throw "Max2D Scene: structural mutation during render preparation"
		End If

		CheckAlive()
		If Not parent Then
			Throw "Max2D Scene: new parent is null"
		End If

		parent.CheckAdd(Self, -1, True)
		If parentNode = parent Then
			Return
		End If

		If ownerScene And parent.ownerScene And ownerScene <> parent.ownerScene Then
			Throw "Max2D Scene: detach before moving between scenes"
		End If

		Local scene:TScene = ownerScene
		If Not scene Then
			scene = parent.ownerScene
		End If

		If scene And scene.busy Then
			scene.Enqueue(3, Self, parent, -1, preserveWorld)
		Else
			RunChange(3, Self, parent, -1, preserveWorld)
		End If
	End Method
	Rem
	bbdoc: Recursively destroys this subtree and releases its owned resources.
	about: Repeated calls are harmless. Pending destruction suppresses further updates in the active traversal. Shared application resources are not automatically released. The scene root is destroyed through TScene.Destroy.
	End Rem
	Method Destroy()
		If ownerScene And ownerScene.preparingRender Then
			Throw "Max2D Scene: structural mutation during render preparation"
		End If

		If dead Or pendingDestroy Then
			Return
		End If

		CheckAlive()
		If sceneRoot Then
			Throw "Max2D Scene: destroy the scene instead of its root"
		End If

		If ownerScene And ownerScene.busy Then
			ownerScene.Enqueue(4, Self, Null, 0, False)
			MarkPending(True)
		Else
			RunChange(4, Self, Null, 0, False)
		End If
	End Method
	Rem
	bbdoc: Enables or disables variable-step update callbacks; disabled by default.
	param: True to enable variable-step update callbacks, False to disable it.
	End Rem
	Method SetProcessing(enabled:Int)
		CheckAlive()
		processing = enabled <> 0
	End Method
	Rem
	bbdoc: Enables or disables fixed-step update callbacks; disabled by default.
	param: True to enable fixed-step update callbacks, False to disable it.
	End Rem
	Method SetFixedProcessing(enabled:Int)
		CheckAlive()
		fixedProcessing = enabled <> 0
	End Method
	Rem
	bbdoc: Allows this node's enabled update callbacks while its scene is paused.
	param: True to enable updates for this node while its scene is paused, False to disable it.
	End Rem
	Method SetProcessWhenPaused(enabled:Int)
		CheckAlive()
		processPaused = enabled <> 0
	End Method

	Rem
	bbdoc: Called parent first when this subtree enters a scene.
	End Rem
	Method OnEnterScene()
	End Method

	Rem
	bbdoc: Called children first after initial attachment, once per node lifetime.
	End Rem
	Method OnReady()
	End Method

	Rem
	bbdoc: Called children first before scene membership is removed.
	End Rem
	Method OnExitScene()
	End Method

	Rem
	bbdoc: Called children first when destruction completes.
	End Rem
	Method OnDestroy()
	End Method

	Rem
	bbdoc: Receives a variable time step in seconds when processing is enabled.
	param: Finite nonnegative elapsed time in seconds, supplied by the application.
	End Rem
	Method OnUpdate(dt:Double)
	End Method

	Rem
	bbdoc: Receives one application-supplied fixed time step in seconds.
	param: Finite nonnegative elapsed time in seconds, supplied by the application.
	End Rem
	Method OnFixedUpdate(dt:Double)
	End Method
	Rem
	bbdoc: Releases resources owned by a custom node without destroying shared assets.
	about: Called by scene resource release and before OnDestroy. Custom implementations should be idempotent; no GC finalizer invokes it.
	End Rem
	Method OnReleaseResources()
	End Method

	Rem
	bbdoc: Receives a borrowed pointer event on the ancestor capture phase, from root towards target.
	param: Borrowed pointer event valid only during this callback; use Copy to retain a snapshot.
	End Rem
	Method OnPointerCapture(event:TScenePointerEvent)
	End Method
	Rem
	bbdoc: Receives a borrowed pointer event at its target.
	param: Borrowed pointer event valid only during this callback; use Copy to retain a snapshot.
	End Rem
	Method OnPointer(event:TScenePointerEvent)
	End Method
	Rem
	bbdoc: Receives a borrowed pointer event on the ancestor bubble phase, towards the root.
	param: Borrowed pointer event valid only during this callback; use Copy to retain a snapshot.
	End Rem
	Method OnPointerBubble(event:TScenePointerEvent)
	End Method

	Rem
	bbdoc: Enables input throughout this branch; disabled branches cannot be picked or focused.
	param: True to enable input routing and picking throughout this branch, False to disable it.
	about: Drawing and updating are unaffected. Existing interactions are reconciled at the next update or input boundary.
	End Rem
	Method SetInputEnabled(enabled:Int)
		CheckAlive(); inputEnabled = enabled <> 0
	End Method
	Rem
	bbdoc: Receives a borrowed key event on the ancestor capture phase.
	param: Borrowed key event valid only during this callback; use Copy to retain a snapshot.
	End Rem
	Method OnKeyCapture(event:TSceneKeyEvent)
	End Method
	Rem
	bbdoc: Receives a borrowed key event at the focused target.
	param: Borrowed key event valid only during this callback; use Copy to retain a snapshot.
	End Rem
	Method OnKey(event:TSceneKeyEvent)
	End Method
	Rem
	bbdoc: Receives a borrowed key event on the ancestor bubble phase.
	param: Borrowed key event valid only during this callback; use Copy to retain a snapshot.
	End Rem
	Method OnKeyBubble(event:TSceneKeyEvent)
	End Method

	Internal
	Method EnsureOrderCapacity(capacity:Int)
		If capacity <= drawOrder.Length Then
			Return
		End If

		Local size:Int = SceneCapacity(drawOrder.Length, capacity)
		drawOrder = drawOrder[..size]
		orderScratch = orderScratch[..size]
	End Method

	Method EnsureDrawOrder()
		If sortable And orderDirty Then
			SceneSortChildren(Self)
		End If
	End Method

	Method InvalidateBounds()
		Local node:TSceneNode = Self
		While node
			node.boundsDirty = True
			node.contentVersion :+ 1
			node.visualVersion :+ 1
			node = node.parentNode
		Wend
	End Method

	Method EnsureBounds()
		If boundsDirty Then
			SceneMeasureBounds(Self)
		End If
	End Method

	Method CheckLive()
		If dead Or pendingDestroy Then
			Throw "Max2D Scene: node is destroyed or pending destruction"
		End If
	End Method

	Method CheckAlive()
		CheckLive()
		If scenePickDepth Then
			Throw "Max2D Scene: mutation during picking is not allowed"
		End If

		If sceneBoundsDepth Then
			Throw "Max2D Scene: mutation during bounds calculation is not allowed"
		End If

		If ownerScene And ownerScene.rendering Then
			Throw "Max2D Scene: scene mutation during drawing is not allowed"
		End If
	End Method

	Method CheckAdd(child:TSceneNode, index:Int, moving:Int)
		If ownerScene And ownerScene.preparingRender Then
			Throw "Max2D Scene: structural mutation during render preparation"
		End If

		CheckAlive()
		If Not child Then
			Throw "Max2D Scene: child is null"
		End If

		child.CheckAlive()
		If child.sceneRoot Then
			Throw "Max2D Scene: scene roots cannot be parented"
		End If

		If index < -1 Or index > itemCount Then
			Throw "Max2D Scene: invalid insertion index"
		End If

		If Not moving And child.parentNode Then
			Throw "Max2D Scene: child already has a parent"
		End If

		Local ancestor:TSceneNode = Self
		While ancestor
			If ancestor = child Then
				Throw "Max2D Scene: parenting would create a cycle"
			End If

			ancestor = ancestor.parentNode
		Wend

		If TLayerNode(child) And Not sceneRoot Then
			Throw "Max2D Scene: layers must be direct scene-root children"
		End If

		If ownerScene And Not sceneRoot And Not Layer() And child.HasSpatial() Then
			Throw "Max2D Scene: spatial nodes require a layer"
		End If

		If sceneRoot And Not TLayerNode(child) And child.HasSpatial() Then
			Throw "Max2D Scene: spatial nodes require a layer"
		End If
	End Method

	Method HasSpatial:Int()
		If TSceneNode2D(Self) Then
			Return True
		End If

		For Local i:Int = 0 Until itemCount
			If items[i].HasSpatial() Then
				Return True
			End If
		Next

		Return False
	End Method

	Method Layer:TLayerNode()
		Local current:TSceneNode = Self
		While current
			If TLayerNode(current) Then
				Return TLayerNode(current)
			End If

			current = current.parentNode
		Wend

		Return Null
	End Method

	Method SpatialParent:TSceneNode2D()
		Local current:TSceneNode = parentNode
		While current
			If TLayerNode(current) Then
				Return Null
			End If

			If TSceneNode2D(current) Then
				Return TSceneNode2D(current)
			End If

			current = current.parentNode
		Wend

		Return Null
	End Method

	Method DirtyWorld()
		Local spatial:TSceneNode2D = TSceneNode2D(Self)
		If spatial Then
			If spatial.worldDirty Then
				Return
			End If

			spatial.worldDirty = True
		End If

		For Local i:Int = 0 Until itemCount
			items[i].DirtyWorld()
		Next
	End Method

	Method MarkPending(value:Int)
		MarkPendingBranch(value)
		If parentNode Then
			parentNode.InvalidateBounds()
		End If
	End Method

	Method MarkPendingBranch(value:Int)
		pendingDestroy = value
		boundsDirty = True
		For Local i:Int = 0 Until itemCount
			items[i].MarkPendingBranch(value)
		Next
	End Method

	Method Link(child:TSceneNode, index:Int)
		If index = -1 Then
			index = itemCount
		End If

		ReserveChildren(itemCount + 1)
		For Local i:Int = itemCount Until index Step -1
			items[i] = items[i - 1]
		Next

		items[index] = child
		itemCount :+ 1
		child.parentNode = Self
		child.DirtyWorld()
		orderDirty = True
		InvalidateBounds()
	End Method

	Method Unlink()
		If Not parentNode Then
			Return
		End If

		Local parent:TSceneNode = parentNode, index:Int
		While parent.items[index] <> Self
			index :+ 1
		Wend

		For Local i:Int = index Until parent.itemCount - 1
			parent.items[i] = parent.items[i + 1]
		Next

		parent.itemCount :- 1
		parent.items[parent.itemCount] = Null
		parent.orderDirty = True
		parent.InvalidateBounds()
		parentNode = Null
		ClearRenderLayer()
		DirtyWorld()
	End Method

	Method ClearRenderLayer()
		renderLayer = Null
		For Local i:Int = 0 Until itemCount
			items[i].ClearRenderLayer()
		Next
	End Method

	Method SetScene(scene:TScene)
		Local group:TSceneRenderGroup = TSceneRenderGroup(Self)
		If group Then
			group.LinkRenderPreparation(scene)
		End If

		ownerScene = scene
		sourcePreparationEpoch = 0
		For Local i:Int = 0 Until itemCount
			items[i].SetScene(scene)
		Next
	End Method

	Method Notify(kind:Int, error:Object Var)
		If (kind = 1 Or kind = 2) And pendingDestroy Then
			Return
		End If

		If kind = 1 Then
			Try
				OnEnterScene()
			Catch caught:Object
				If Not error Then
					error = caught
				End If
			End Try
		End If

		For Local i:Int = 0 Until itemCount
			items[i].Notify(kind, error)
		Next

		Try
			Select kind
				Case 2
					If Not ready And Not pendingDestroy Then ready = True; OnReady()
				Case 3
					OnExitScene()
				Case 5
					OnReleaseResources()
			End Select
		Catch caught:Object
			If Not error Then
				error = caught
			End If
		End Try
	End Method

	Method FinishDestroy(error:Object Var)
		While itemCount
			items[itemCount - 1].FinishDestroy(error)
		Wend

		Local group:TSceneRenderGroup = TSceneRenderGroup(Self)
		If group Then
			group.LinkRenderPreparation(Null)
		End If

		Unlink()
		ownerScene = Null
		dead = True
		pendingDestroy = False
		items = Null
		drawOrder = Null
		orderScratch = Null
		Try
			OnReleaseResources()
		Catch caught:Object
			If Not error Then
				error = caught
			End If
		End Try

		Try
			OnDestroy()
		Catch caught:Object
			If Not error Then
				error = caught
			End If
		End Try
	End Method
End Type

Rem
bbdoc: A root-level scene layer establishing a separate world coordinate space.
about: Layers have independent camera snapshots and virtual-surface clips. They establish transform boundaries and may only attach directly to the scene root.
End Rem
Type TLayerNode Extends TSceneNode
	Internal
	Field viewMatrix:SSceneMatrix
	Field hasViewport:Int
	Field clipX:Int, clipY:Int, clipW:Int, clipH:Int
	Public
	Rem
	bbdoc: Creates an identity layer view.
	End Rem
	Method New()
		viewMatrix.xx = 1
		viewMatrix.yy = 1
	End Method
	Rem
	bbdoc: Copies camera values into the layer view; Null restores identity.
	param: Camera values to copy; Null restores the identity view. Later camera edits require another SetCamera call.
	about: Editing the supplied camera later does not change this layer. Camera offsets are absolute virtual-surface coordinates, independent of the viewport.
	End Rem
	Method SetCamera(camera:TCamera2D)
		CheckAlive()
		Local candidate:SSceneMatrix
		candidate.xx = 1
		candidate.yy = 1
		If camera Then
			camera.Validate()
			Local c:Double = Cos(camera.rotation), s:Double = Sin(camera.rotation)
			candidate.xx = camera.zoom * c
			candidate.xy = camera.zoom * s
			candidate.yx = -camera.zoom * s
			candidate.yy = camera.zoom * c
			candidate.tx = camera.offsetX - candidate.xx * camera.x - candidate.xy * camera.y
			candidate.ty = camera.offsetY - candidate.yx * camera.x - candidate.yy * camera.y
			candidate.Validate()
		End If

		viewMatrix = candidate
	End Method
	Rem
	bbdoc: Copies a virtual-surface viewport, intersected with the caller's clip during rendering.
	param: Finite scene virtual-surface rectangle, copied by this call; dimensions must be nonnegative.
	about: Fractional edges round outward to integer virtual coordinates. This clips drawing without relocating the layer camera.
	End Rem
	Method SetViewport(rect:TSceneRect)
		CheckAlive()
		SceneCheckRect(rect)
		Local left:Double = Floor(rect.x), top:Double = Floor(rect.y)
		Local right:Double = Ceil(Double(rect.x) + rect.width), bottom:Double = Ceil(Double(rect.y) + rect.height)
		If left < -2147483648.0 Or top < -2147483648.0 Or right > 2147483647.0 Or bottom > 2147483647.0 Or right - left > 2147483647.0 Or bottom - top > 2147483647.0 Then
			Throw "Max2D Scene: viewport outside integer range"
		End If

		clipX = Int(left)
		clipY = Int(top)
		clipW = Int(right - left)
		clipH = Int(bottom - top)
		If rect.width = 0 Then
			clipW = 0
		End If

		If rect.height = 0 Then
			clipH = 0
		End If

		hasViewport = True
	End Method
	Rem
	bbdoc: Uses the caller's full clip for this layer.
	End Rem
	Method ClearViewport()
		CheckAlive()
		hasViewport = False
	End Method
	Rem
	bbdoc: Creates a detached layer without graphics resources.
	returns: A new #TLayerNode instance configured with the supplied settings.
	End Rem
	Function Create:TLayerNode()
		Return New TLayerNode
	End Function
End Type

Rem
bbdoc: A scene node with retained inline local and world affine transforms.
about: Position, rotation and scale setters allocate no matrices. World transforms resolve lazily. Non-spatial ancestors preserve the transform chain; layers start a new coordinate space. Raw affine matrices preserve shear and use an explicit reset through SetTransform before component rotation, scale or pivot editing.
End Rem
Type TSceneNode2D Extends TSceneNode
	Internal
	Field localMatrix:SSceneMatrix, worldMatrix:SSceneMatrix
	Field worldDirty:Int = True
	Field px:Float, py:Float, angle:Float, sx:Float = 1, sy:Float = 1, pivotX:Float, pivotY:Float
	Field affine:Int
	Field visible:Int = True
	Field tintRed:Int = 255, tintGreen:Int = 255, tintBlue:Int = 255
	Field opacity:Float = 1
	Field zIndex:Int
	Field measureRect:TSceneRect
	Field focusable:Int, focusOrder:Int
	Field interactive:Int, hasHitRect:Int
	Field hitRect:TSceneRect
	Public
	Rem
	bbdoc: Creates a detached spatial node with identity transforms.
	End Rem
	Method New()
		localMatrix.xx = 1
		localMatrix.yy = 1
		worldMatrix = localMatrix
	End Method
	Rem
	bbdoc: Changes position without allocating; raw affine mode edits matrix translation.
	param: Finite horizontal coordinate in parent-local units.
	param: Finite vertical coordinate in parent-local units.
	End Rem
	Method SetPosition(x:Float, y:Float)
		CheckAlive()
		SceneCheckFinite(x)
		SceneCheckFinite(y)
		If affine Then
			If localMatrix.tx = x And localMatrix.ty = y Then
				Return
			End If

			localMatrix.tx = x
			localMatrix.ty = y
			TransformChanged()
		Else
			If px = x And py = y Then
				Return
			End If

			Local candidate:SSceneMatrix = localMatrix
			candidate.tx = x - candidate.xx * pivotX - candidate.xy * pivotY
			candidate.ty = y - candidate.yx * pivotX - candidate.yy * pivotY
			candidate.Validate()
			localMatrix = candidate
			px = x
			py = y
			TransformChanged()
		End If
	End Method
	Rem
	bbdoc: Copies position to caller variables without allocating.
	param: Receives horizontal position in parent-local units.
	param: Receives vertical position in parent-local units.
	End Rem
	Method GetPosition(x:Float Var, y:Float Var)
		CheckLive()
		If affine Then
			Local a:Float = Float(localMatrix.tx), b:Float = Float(localMatrix.ty)
			SceneCheckFinite(a)
			SceneCheckFinite(b)
			x = a
			y = b
		Else
			x = px
			y = py
		End If
	End Method
	Rem
	bbdoc: Sets clockwise rotation in degrees in component mode.
	param: Finite clockwise rotation in degrees.
	End Rem
	Method SetRotation(degrees:Float)
		CheckComponents()
		SetTransform(px, py, degrees, sx, sy, pivotX, pivotY)
	End Method
	Rem
	bbdoc: Sets component scale; negative and zero scales are supported.
	param: Horizontal scale multiplier; zero and negative values are supported.
	param: Vertical scale multiplier; zero and negative values are supported.
	End Rem
	Method SetScale(x:Float, y:Float)
		CheckComponents()
		SetTransform(px, py, angle, x, y, pivotX, pivotY)
	End Method
	Rem
	bbdoc: Sets the local pivot in component mode without changing position.
	param: Horizontal pivot coordinate in node-local units.
	param: Vertical pivot coordinate in node-local units.
	End Rem
	Method SetPivot(x:Float, y:Float)
		CheckComponents()
		SetTransform(px, py, angle, sx, sy, x, y)
	End Method
	Rem
	bbdoc: Atomically replaces the local transform with position, rotation, scale and pivot components.
	param: Finite horizontal coordinate in parent-local units.
	param: Finite vertical coordinate in parent-local units.
	param: Finite clockwise rotation in degrees.
	param: Horizontal scale multiplier; zero and negative values are supported.
	param: Vertical scale multiplier; zero and negative values are supported.
	param: Horizontal pivot coordinate in node-local units.
	param: Vertical pivot coordinate in node-local units.
	about: Composition is translation times rotation times scale times negative-pivot translation. This explicitly leaves raw affine mode. Invalid values leave the previous transform unchanged.
	End Rem
	Method SetTransform(x:Float, y:Float, rotation:Float, scaleX:Float = 1, scaleY:Float = 1, pivotX:Float = 0, pivotY:Float = 0)
		CheckAlive()
		SceneCheckFinite(x)
		SceneCheckFinite(y)
		SceneCheckFinite(rotation)
		SceneCheckFinite(scaleX)
		SceneCheckFinite(scaleY)
		SceneCheckFinite(pivotX)
		SceneCheckFinite(pivotY)
		If Not affine And px = x And py = y And angle = rotation And sx = scaleX And sy = scaleY And Self.pivotX = pivotX And Self.pivotY = pivotY Then
			Return
		End If

		Local candidate:SSceneMatrix
		Local c:Double = Cos(rotation), s:Double = Sin(rotation)
		candidate.xx = c * scaleX
		candidate.xy = -s * scaleY
		candidate.yx = s * scaleX
		candidate.yy = c * scaleY
		candidate.tx = x - candidate.xx * pivotX - candidate.xy * pivotY
		candidate.ty = y - candidate.yx * pivotX - candidate.yy * pivotY
		candidate.Validate()
		localMatrix = candidate
		affine = False
		px = x
		py = y
		angle = rotation
		sx = scaleX
		sy = scaleY
		Self.pivotX = pivotX
		Self.pivotY = pivotY
		TransformChanged()
	End Method
	Rem
	bbdoc: Copies a finite affine snapshot, preserving shear and entering raw affine mode.
	param: Required finite affine snapshot; copied rather than retained.
	about: SetPosition remains available; SetTransform explicitly restores component editing. The supplied object is not retained.
	End Rem
	Method SetLocalTransform(transform:TSceneTransform)
		CheckAlive()
		If Not transform Then
			Throw "Max2D Scene: local transform is null"
		End If

		Local candidate:SSceneMatrix
		candidate.xx = transform.xx
		candidate.xy = transform.xy
		candidate.yx = transform.yx
		candidate.yy = transform.yy
		candidate.tx = transform.tx
		candidate.ty = transform.ty
		candidate.Validate()
		localMatrix = candidate
		affine = True
		TransformChanged()
	End Method
	Rem
	bbdoc: Returns an allocated, detached local-transform snapshot.
	returns: An allocated, detached local-transform snapshot.
	End Rem
	Method LocalTransform:TSceneTransform()
		Local result:TSceneTransform = New TSceneTransform
		CopyLocalTransform(result)
		Return result
	End Method
	Rem
	bbdoc: Returns an allocated, detached world-transform snapshot.
	returns: An allocated, detached world-transform snapshot.
	End Rem
	Method WorldTransform:TSceneTransform()
		Local result:TSceneTransform = New TSceneTransform
		CopyWorldTransform(result)
		Return result
	End Method
	Rem
	bbdoc: Fills an existing local-transform snapshot without allocation.
	param: Required reusable destination transform snapshot.
	End Rem
	Method CopyLocalTransform(output:TSceneTransform)
		CheckLive()
		localMatrix.CopyTo(output)
	End Method
	Rem
	bbdoc: Resolves and fills an existing world-transform snapshot without allocation.
	param: Required reusable destination transform snapshot.
	End Rem
	Method CopyWorldTransform(output:TSceneTransform)
		CheckLive()
		EnsureWorld()
		worldMatrix.CopyTo(output)
	End Method
	Rem
	bbdoc: Maps local coordinates to layer-world coordinates without allocating.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	param: Receives horizontal layer-world output coordinate.
	param: Receives vertical layer-world output coordinate.
	returns: True when conversion succeeds; False leaves the output coordinates unchanged.
	about: False means the result cannot be represented as finite Float outputs; output variables remain unchanged. Does not require Graphics or scene attachment.
	End Rem
	Method LocalToWorld:Int(x:Float, y:Float, worldX:Float Var, worldY:Float Var)
		CheckLive()
		EnsureWorld()
		Return MapPoint(worldMatrix, x, y, worldX, worldY)
	End Method
	Rem
	bbdoc: Maps layer-world coordinates to local coordinates without allocating.
	param: Finite horizontal coordinate in layer-world units.
	param: Finite vertical coordinate in layer-world units.
	param: Receives horizontal node-local output coordinate.
	param: Receives vertical node-local output coordinate.
	returns: True when conversion succeeds; False leaves the output coordinates unchanged.
	about: Singular transforms return False with unchanged outputs. Does not require Graphics or scene attachment.
	End Rem
	Method WorldToLocal:Int(x:Float, y:Float, localX:Float Var, localY:Float Var)
		CheckLive()
		EnsureWorld()
		Local inverse:SSceneMatrix
		If Not inverse.Inverse(worldMatrix) Then
			Return False
		End If

		Return MapPoint(inverse, x, y, localX, localY)
	End Method
	Rem
	bbdoc: Shows or hides this entire visual subtree; updates are unaffected.
	param: True to draw this subtree, False to hide it without stopping updates.
	End Rem
	Method SetVisible(value:Int)
		CheckAlive()
		If visible = (value <> 0) Then
			Return
		End If

		visible = value <> 0
		InvalidateBounds()
	End Method
	Rem
	bbdoc: Sets RGB tint channels from 0 to 255, multiplied through spatial ancestors.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	End Rem
	Method SetTint(red:Int, green:Int, blue:Int)
		CheckAlive()
		SceneCheckColor(red, green, blue)
		If tintRed = red And tintGreen = green And tintBlue = blue Then
			Return
		End If

		tintRed = red
		tintGreen = green
		tintBlue = blue
		InvalidateBounds()
	End Method
	Rem
	bbdoc: Sets opacity from zero to one, multiplied into each descendant's drawing.
	param: Opacity multiplier in the inclusive range 0..1.
	about: This is per-draw opacity, not flattened group opacity.
	End Rem
	Method SetAlpha(alpha:Float)
		CheckAlive()
		SceneCheckAlpha(alpha)
		If opacity = alpha Then
			Return
		End If

		opacity = alpha
		InvalidateBounds()
	End Method
	Rem
	bbdoc: Fills local self bounds; plain spatial nodes have empty bounds.
	param: Required reusable rectangle receiving local bounds when the result is True.
	returns: True when bounds are known and written to the destination; False when unknown.
	about: False means unknown; descendants are not included. The caller supplies reusable storage.
	End Rem
	Method GetSelfBounds:Int(bounds:TSceneRect)
		CheckLive()
		SceneWriteRect(bounds, 0, 0, 0, 0)
		Return True
	End Method

	Rem
	bbdoc: Sets this node's z-index within a parent that enables child sorting.
	param: Sibling drawing order; lower values draw first when the parent enables sorting.
	about: Lower values draw first. Equal values retain committed child insertion order. This does not move the node outside its parent subtree or layer.
	End Rem
	Method SetZIndex(value:Int)
		CheckAlive()
		If zIndex = value Then
			Return
		End If

		zIndex = value
		If parentNode Then
			parentNode.orderDirty = True
		End If

		parentNode.InvalidateBounds()
	End Method
	Rem
	bbdoc: Fills cached local bounds enclosing this node's visible drawing and descendants.
	param: Required reusable rectangle receiving local bounds when the result is True.
	returns: True when bounds are known and written to the destination; False when unknown.
	about: Returns False without changing the output if any contributing bounds are unknown. Hidden, zero-alpha and pending-destroy subtrees contribute nothing. Ancestor visibility, the node's own transform, cameras and viewport clips do not affect these local bounds. Custom bounds callbacks must not mutate the scene.
	End Rem
	Method GetContentBounds:Int(bounds:TSceneRect)
		CheckLive()
		If Not bounds Then
			Throw "Max2D Scene: bounds destination is null"
		End If

		sceneBoundsDepth :+ 1
		Try
			EnsureBounds()
			Return contentBounds.CopyTo(bounds)
		Finally
			sceneBoundsDepth :- 1
		End Try
	End Method
	Rem
	bbdoc: Fills local output bounds, including expansion declared by render groups.
	param: Required reusable rectangle receiving local bounds when the result is True.
	returns: True when bounds are known and written to the destination; False when unknown.
	about: Unknown bounds leave the output unchanged. Hit bounds are independent of effect expansion.
	End Rem
	Method GetOutputBounds:Int(bounds:TSceneRect)
		CheckLive()
		If Not bounds Then
			Throw "Max2D Scene: bounds destination is null"
		End If

		sceneBoundsDepth :+ 1
		Try
			EnsureBounds()
			Return outputBounds.CopyTo(bounds)
		Finally
			sceneBoundsDepth :- 1
		End Try
	End Method
	Rem
	bbdoc: Returns the tracked visual revision of this isolated subtree, including its own placement.
	returns: The tracked visual revision of this isolated subtree, including its own placement.
	about: Intended for render dependencies. Includes descendant content and render-group presentation changes, but excludes ancestor transforms and tint. External shared-resource edits still require InvalidateContent. Scene attachment must be checked separately.
	End Rem
	Method VisualRevision:Long()
		Return visualVersion
	End Method
	Rem
	bbdoc: Invalidates cached bounds for this node and its ancestors after external content changes.
	about: Call after changing custom drawing data, shared image handles, mesh vertices or font metrics without a node setter. Notify every node that references a changed shared resource. Normal node setters invalidate automatically.
	End Rem
	Method InvalidateContent()
		CheckAlive()
		InvalidateBounds()
	End Method

	Internal
	Method TransformChanged()
		visualVersion :+ 1
		DirtyWorld()
		If parentNode Then
			parentNode.InvalidateBounds()
		End If
	End Method

	Public
	Rem
	bbdoc: Enables this node as a pointer-picking target; disabled by default.
	param: True to enable pointer picking for this node without disabling descendants, False to disable it.
	about: Does not disable interactive descendants.
	End Rem
	Method SetInteractive(enabled:Int)
		CheckAlive()
		interactive = enabled <> 0
	End Method
	Rem
	bbdoc: Copies an explicit local hit rectangle, independent of drawing bounds.
	param: Finite node-local rectangle, copied by this call; dimensions must be nonnegative.
	End Rem
	Method SetHitRect(rect:TSceneRect)
		CheckAlive()
		SceneCheckRect(rect)
		If Not hitRect Then
			hitRect = New TSceneRect
		End If

		SceneWriteRect(hitRect, rect.x, rect.y, rect.width, rect.height)
		hasHitRect = True
	End Method
	Rem
	bbdoc: Uses this node's self bounds for default hit testing again.
	End Rem
	Method ClearHitRect()
		CheckAlive()
		hasHitRect = False
	End Method
	Rem
	bbdoc: Tests local coordinates against the explicit hit rectangle or known self bounds.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	returns: True when the point passes this input test, False otherwise.
	about: Left/top edges are included; right/bottom are excluded. Unknown or empty bounds miss. Override for a custom shape. Picking callbacks must not mutate the scene or start another traversal.
	End Rem
	Method HitTestLocal:Int(x:Float, y:Float)
		CheckLive()
		If hasHitRect Then
			Return SceneRectContains(hitRect, x, y)
		End If

		If Not measureRect Then
			measureRect = New TSceneRect
		End If

		If Not GetSelfBounds(measureRect) Then
			Return False
		End If

		SceneCheckRect(measureRect)
		Return SceneRectContains(measureRect, x, y)
	End Method

	Internal

	Public
	Rem
	bbdoc: Opts this node into keyboard focus; pointer interactivity is independent.
	param: True to enable keyboard focus for this node, False to disable it.
	End Rem
	Method SetFocusable(enabled:Int)
		CheckAlive()
		focusable = enabled <> 0
	End Method
	Rem
	bbdoc: Sets keyboard navigation order; equal values use tree insertion order, independent of z-index.
	param: Keyboard focus order; lower values are visited first.
	End Rem
	Method SetFocusOrder(order:Int)
		CheckAlive()
		focusOrder = order
	End Method
	Rem
	bbdoc: Called when this node receives keyboard focus.
	End Rem
	Method OnFocusGained()
	End Method
	Rem
	bbdoc: Called when this node loses keyboard focus, including before removal or destruction.
	End Rem
	Method OnFocusLost()
	End Method

	Internal

	Method DrawScene(context:TSceneDrawContext)
	End Method

	Method CheckComponents()
		CheckAlive()
		If affine Then
			Throw "Max2D Scene: use SetTransform to leave raw affine mode"
		End If
	End Method

	Method EnsureWorld()
		If Not worldDirty Then
			Return
		End If

		Local spatial:TSceneNode2D = SpatialParent()
		If spatial Then
			spatial.EnsureWorld()
			Local candidate:SSceneMatrix
			candidate.Product(spatial.worldMatrix, localMatrix)
			worldMatrix = candidate
		Else
			worldMatrix = localMatrix
		End If

		worldDirty = False
		If ownerScene And ownerScene.rendering Then
			ownerScene.renderStats.worldRebuilds :+ 1
		End If
	End Method
End Type

Private

Function MapPoint:Int(matrix:SSceneMatrix, x:Float, y:Float, outX:Float Var, outY:Float Var)
	If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then
		Return False
	End If

	Local a:Float = Float(matrix.xx * x + matrix.xy * y + matrix.tx)
	Local b:Float = Float(matrix.yx * x + matrix.yy * y + matrix.ty)
	If IsNan(a) Or IsInf(a) Or IsNan(b) Or IsInf(b) Then
		Return False
	End If

	outX = a
	outY = b
	Return True
End Function

Public
