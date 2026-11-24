Rem
bbdoc: Caller-owned rectangle used for scene bounds and layer clips.
End Rem
Type TSceneRect
	Rem
	bbdoc: Local or virtual left edge, according to the receiving API.
	End Rem
	Field x:Float
	Rem
	bbdoc: Local or virtual top edge, according to the receiving API.
	End Rem
	Field y:Float
	Rem
	bbdoc: Nonnegative width.
	End Rem
	Field width:Float
	Rem
	bbdoc: Nonnegative height.
	End Rem
	Field height:Float
	Rem
	bbdoc: Creates a finite rectangle with nonnegative dimensions.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	param: Width in logical units; nonnegative.
	param: Height in logical units; nonnegative.
	returns: A new #TSceneRect instance configured with the supplied settings.
	End Rem
	Function Create:TSceneRect(x:Float, y:Float, width:Float, height:Float)
		Local rect:TSceneRect = New TSceneRect
		SceneWriteRect(rect, x, y, width, height)
		SceneCheckRect(rect)
		Return rect
	End Function
End Type

Rem
bbdoc: A scene drawable referencing a shared Max2D image.
about: Image handles are respected. The node does not release the shared image. Children draw after the sprite, with optional stable z-index ordering.
End Rem
Type TSpriteNode Extends TSceneNode2D
	Internal
	Field image:TImage
	Field frame:Int
	Public
	Rem
	bbdoc: Creates an image node; Null draws nothing and accepts only frame zero.
	param: Borrowed image; its lifetime remains application-owned.
	param: Zero-based frame index in the supplied image.
	returns: A new #TSpriteNode instance configured with the supplied settings.
	End Rem
	Function Create:TSpriteNode(image:TImage, frame:Int = 0)
		Local node:TSpriteNode = New TSpriteNode
		node.SetImage(image)
		node.SetFrame(frame)
		Return node
	End Function
	Rem
	bbdoc: References a shared image and resets its frame to zero.
	param: Borrowed image; replacing it does not release the previous image.
	End Rem
	Method SetImage(value:TImage)
		CheckAlive()
		image = value
		frame = 0
		InvalidateBounds()
	End Method
	Rem
	bbdoc: Selects an existing zero-based image frame.
	param: Zero-based index of an existing image frame.
	End Rem
	Method SetFrame(value:Int)
		CheckAlive()
		If value < 0 Then
			Throw "Max2D Scene: negative sprite frame"
		End If

		If image Then
			If value >= image.sources.Length Then
				Throw "Max2D Scene: sprite frame outside image"
			End If
		Else
			If value <> 0 Then
				Throw "Max2D Scene: null sprite accepts only frame zero"
			End If
		End If

		frame = value
		InvalidateBounds()
	End Method
	Rem
	bbdoc: Fills logical image bounds relative to the shared image handle.
	param: Required reusable rectangle receiving local bounds when the result is True.
	returns: True when bounds are known and written to the destination; False when unknown.
	End Rem
	Method GetSelfBounds:Int(bounds:TSceneRect)
		CheckLive()
		If Not image Then
			Return Super.GetSelfBounds(bounds)
		End If

		SceneWriteRect(bounds, -image.handle_x, -image.handle_y, image.width, image.height)
		Return True
	End Method

	Internal
	Method DrawScene(context:TSceneDrawContext)
		If image Then
			DrawImage(image, 0, 0, frame)
		End If
	End Method
End Type

Rem
bbdoc: A text drawable using an explicitly supplied shared image font.
End Rem
Type TTextNode Extends TSceneNode2D
	Internal
	Field text:String
	Field font:TImageFont
	Public
	Rem
	bbdoc: Creates a text node with a required font.
	param: Text to display at the node's local origin.
	param: Required shared image font; ownership remains with the application.
	returns: A new #TTextNode instance configured with the supplied settings.
	End Rem
	Function Create:TTextNode(text:String, font:TImageFont)
		Local node:TTextNode = New TTextNode
		node.SetFont(font)
		node.SetText(text)
		Return node
	End Function
	Rem
	bbdoc: Changes the text; the font's normal layout cache handles repeated strings.
	param: Text to display; changing it invalidates cached layout and bounds.
	End Rem
	Method SetText(value:String)
		CheckAlive()
		text = value
		InvalidateBounds()
	End Method
	Rem
	bbdoc: References a shared font; Null is rejected.
	param: Required shared image font; its lifetime remains application-owned.
	End Rem
	Method SetFont(value:TImageFont)
		CheckAlive()
		If Not value Then
			Throw "Max2D Scene: text requires a font"
		End If

		font = value
		InvalidateBounds()
	End Method
	Rem
	bbdoc: Fills the font layout's local ink bounds; first layout may allocate CPU resources.
	param: Required reusable rectangle receiving local bounds when the result is True.
	returns: True when bounds are known and written to the destination; False when unknown.
	End Rem
	Method GetSelfBounds:Int(bounds:TSceneRect)
		CheckLive()
		If Not text Or Not font Then
			Return Super.GetSelfBounds(bounds)
		End If

		Local layout:TTextLayout = font.Layout(text)
		SceneWriteRect(bounds, layout.boundsX, layout.boundsY, layout.boundsWidth, layout.boundsHeight)
		Return True
	End Method

	Internal
	Method DrawScene(context:TSceneDrawContext)
		If text And font Then
			SetImageFont(font)
			DrawText(text, 0, 0)
		End If
	End Method
End Type

Rem
bbdoc: A scene drawable referencing a shared Max2D triangle mesh.
End Rem
Type TMeshNode Extends TSceneNode2D
	Internal
	Field mesh:TMesh2D
	Field image:TImage
	Field frame:Int
	Public
	Rem
	bbdoc: Creates a shared mesh drawable with optional artwork and frame; Null mesh draws nothing.
	param: Borrowed triangle mesh with finite positions and valid UVs and indices.
	param: Borrowed image; its lifetime remains application-owned.
	param: Zero-based frame index in the supplied image.
	returns: A new #TMeshNode instance configured with the supplied settings.
	End Rem
	Function Create:TMeshNode(mesh:TMesh2D, image:TImage = Null, frame:Int = 0)
		Local node:TMeshNode = New TMeshNode
		node.SetMesh(mesh)
		node.SetImage(image)
		node.SetFrame(frame)
		Return node
	End Function

	Rem
	bbdoc: References a shared mesh without copying its vertices.
	param: Borrowed mesh geometry; Null disables geometry drawing.
	End Rem
	Method SetMesh(value:TMesh2D)
		CheckAlive()
		mesh = value
		InvalidateBounds()
	End Method

	Rem
	bbdoc: References optional shared mesh artwork and resets its frame to zero; Null restores filled drawing.
	param: Borrowed image; replacing it does not release the previous image.
	about: Textured drawing requires mesh UVs. Image handles do not affect geometry or bounds. This node does not own the image. Raw mesh/UV edits and image pixel edits require explicit invalidation of cached consumers; use InvalidateContent after geometry, UV or artwork changes.
	End Rem
	Method SetImage(value:TImage)
		CheckAlive()
		image = value
		frame = 0
		InvalidateContent()
	End Method

	Rem
	bbdoc: Selects an existing mesh artwork frame; Null artwork accepts only zero.
	param: Zero-based index of an existing image frame.
	End Rem
	Method SetFrame(value:Int)
		CheckAlive()
		If image Then
			image.CheckIndex(value)
		Else If value <> 0 Then
			Throw "Max2D Scene: null mesh image accepts only frame zero"
		End If

		If frame = value Then
			Return
		End If

		frame = value
		InvalidateContent()
	End Method
	
	Rem
	bbdoc: Fills bounds enclosing the mesh's vertices without allocating.
	param: Required reusable rectangle receiving local bounds when the result is True.
	returns: True when bounds are known and written to the destination; False when unknown.
	End Rem
	Method GetSelfBounds:Int(bounds:TSceneRect)
		CheckLive()
		If Not mesh Or mesh.xy.Length < 2 Then
			Return Super.GetSelfBounds(bounds)
		End If

		Local left:Float = mesh.xy[0], right:Float = left, top:Float = mesh.xy[1], bottom:Float = top
		For Local i:Int = 2 Until mesh.xy.Length Step 2
			left = Min(left, mesh.xy[i])
			right = Max(right, mesh.xy[i])
			top = Min(top, mesh.xy[i + 1])
			bottom = Max(bottom, mesh.xy[i + 1])
		Next

		SceneWriteRect(bounds, left, top, right - left, bottom - top)
		Return True
	End Method

	Internal
	Method DrawScene(context:TSceneDrawContext)
		If image Then
			If mesh Then
				DrawTexturedMesh(mesh, image, 0, 0, frame)
			End If
		Else
			If mesh Then
				DrawMesh(mesh)
			End If
		End If
	End Method
End Type

Rem
bbdoc: Base for application drawing in node-local coordinates.
about: Use the supplied context for colour and alpha so inherited values are respected. Geometry uses ordinary Max2D draw calls. Do not change target, canvas, viewport, presentation or scene state, clear, or flip from OnDraw. Balance any drawing scopes before returning.
End Rem
Type TCustomDrawNode Extends TSceneNode2D
	Internal
	Field knownBounds:Int
	Field boundsX:Float, boundsY:Float, boundsW:Float, boundsH:Float
	Public
	Rem
	bbdoc: Copies declared local drawing bounds.
	param: Finite node-local rectangle, copied by this call; dimensions must be nonnegative.
	End Rem
	Method SetSelfBounds(rect:TSceneRect)
		CheckAlive()
		SceneCheckRect(rect)
		boundsX = rect.x
		boundsY = rect.y
		boundsW = rect.width
		boundsH = rect.height
		knownBounds = True
		InvalidateBounds()
	End Method

	Rem
	bbdoc: Marks this node's own drawing bounds as unknown.
	End Rem
	Method ClearSelfBounds()
		CheckAlive()
		knownBounds = False
		InvalidateBounds()
	End Method

	Rem
	bbdoc: Fills declared bounds or returns False without changing the output when unknown.
	param: Required reusable rectangle receiving local bounds when the result is True.
	returns: True when bounds are known and written to the destination; False when unknown.
	about: Aggregate queries cache this result. Overrides should call InvalidateContent when their underlying application data changes.
	End Rem
	Method GetSelfBounds:Int(bounds:TSceneRect)
		CheckLive()
		If Not knownBounds Then
			Return False
		End If

		SceneWriteRect(bounds, boundsX, boundsY, boundsW, boundsH)
		Return True
	End Method

	Rem
	bbdoc: Override to draw locally with a borrowed context valid only during this callback.
	param: Borrowed draw context valid only during this callback; do not retain it.
	End Rem
	Method OnDraw(context:TSceneDrawContext)
	End Method

	Internal
	Method DrawScene(context:TSceneDrawContext)
		OnDraw(context)
	End Method
End Type

Rem
bbdoc: Borrowed custom-drawing context applying inherited tint and alpha.
about: Do not retain this object after OnDraw. Colour and alpha calls are relative to inherited values, not cumulative with earlier calls in the callback.
End Rem
Type TSceneDrawContext
	Internal
	Field active:Int
	Field canvas:TMax2DGraphics
	Field red:Float, green:Float, blue:Float, alpha:Float
	Public
	Rem
	bbdoc: Multiplies supplied RGB channels by this node's inherited tint.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	End Rem
	Method SetColor(red:Int, green:Int, blue:Int)
		If Not active Then
			Throw "Max2D Scene: draw context is no longer active"
		End If

		SceneCheckColor(red, green, blue)
		Local state:TMax2DState = canvas.state
		state.red = Int(red * Self.red + 0.5)
		state.green = Int(green * Self.green + 0.5)
		state.blue = Int(blue * Self.blue + 0.5)
		state.colorByteAlpha = 255
	End Method

	Rem
	bbdoc: Multiplies supplied opacity by this node's inherited alpha.
	param: Opacity multiplier in the inclusive range 0..1.
	End Rem
	Method SetAlpha(alpha:Float)
		If Not active Then
			Throw "Max2D Scene: draw context is no longer active"
		End If

		SceneCheckAlpha(alpha)
		canvas.state.alpha = alpha * Self.alpha
	End Method
End Type

Private

Function SceneCheckColor(red:Int, green:Int, blue:Int)
	If red < 0 Or red > 255 Or green < 0 Or green > 255 Or blue < 0 Or blue > 255 Then
		Throw "Max2D Scene: tint channels must be 0..255"
	End If
End Function

Function SceneCheckAlpha(alpha:Float)
	SceneCheckFinite(alpha)
	If alpha < 0 Or alpha > 1 Then
		Throw "Max2D Scene: alpha must be 0..1"
	End If
End Function

Function SceneCheckRect(rect:TSceneRect)
	If Not rect Then
		Throw "Max2D Scene: rectangle is null"
	End If

	SceneCheckFinite(rect.x)
	SceneCheckFinite(rect.y)
	SceneCheckFinite(rect.width)
	SceneCheckFinite(rect.height)
	If rect.width < 0 Or rect.height < 0 Then
		Throw "Max2D Scene: negative rectangle dimensions"
	End If
End Function

Function SceneWriteRect(rect:TSceneRect, x:Float, y:Float, width:Float, height:Float)
	If Not rect Then
		Throw "Max2D Scene: bounds destination is null"
	End If

	rect.x = x
	rect.y = y
	rect.width = width
	rect.height = height
End Function

Function RenderScene(scene:TScene)
	Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
	Local scope:TSceneStateScope = scene.renderPass.scope
	scope.Open(canvas)
	scene.busy = True
	scene.rendering = True
	Try
		scene.renderPass.Run(scene, canvas, scope)
		If scene.debugOverlay Then
			scene.debugPass.Run(scene, scope)
		End If
	Finally
		Try
			If TMax2DGraphics.selected <> canvas And Not canvas.context.closed Then
				SetGraphics(canvas)
			End If

			scope.Close()
		Finally
			scene.rendering = False
			scene.busy = False
		End Try
	End Try

	scene.renderStats.completed = True
End Function


' Retained only by an internal rendering boundary; never returned to callers.
' Public scopes remain one-shot handles, including after an outer unwind.
Type TSceneStateScope Extends TMax2DStateScope
	Field snapshot:TMax2DSavedState = New TMax2DSavedState
	Field original:TMax2DState
	Method Open(owner:TMax2DGraphics)
		If canvas Then
			Throw "Max2D Scene: drawing boundary is already active"
		End If

		owner.CaptureState(snapshot)
		original = owner.state
		snapshot.active = True
		snapshot.scoped = True
		owner.saved.AddLast(snapshot)
		entry = snapshot
		canvas = owner
	End Method

	Method Close() Override
		Local owner:TMax2DGraphics = canvas
		Local restore:Int = owner And entry And entry.active And Not owner.context.closed
		Try
			Super.Close()
		Finally
			' Restore into the original object: the retained snapshot must never become
			' mutable canvas state, particularly when this scene moves between canvases.
			If restore And owner.state = snapshot.state Then
				snapshot.state.CopyTo(original)
				owner.state = original
			End If

			original = Null
			snapshot.font = Null
			snapshot.target = Null
		End Try
	End Method
End Type

' Each rendering boundary retains its own traversal storage and drawing state.
Type TSceneRenderPass
	Field scope:TSceneStateScope = New TSceneStateScope
	Field work:TSceneNode[]
	Field workCount:Int
	Field drawState:TMax2DState = New TMax2DState
	Field context:TSceneDrawContext = New TSceneDrawContext
	Method EnsureWork(count:Int)
		If count > work.Length Then
			work = work[..SceneCapacity(work.Length, count)]
		End If
	End Method

	Method Run(scene:TScene, canvas:TMax2DGraphics, scope:TMax2DStateScope, boundary:TSceneRenderGroup = Null, offsetX:Float = 0, offsetY:Float = 0, sourceRoot:TSceneNode2D = Null)
		context.canvas = canvas
		Local baseMatrix:SSceneMatrix
		baseMatrix.xx = 1
		baseMatrix.yy = 1
		baseMatrix.tx = offsetX
		baseMatrix.ty = offsetY
		Try
			If sourceRoot Then
				EnsureWork(1)
				work[0] = sourceRoot
				workCount = 1
			Else If boundary Then
				EnsureWork(boundary.itemCount)
				boundary.EnsureDrawOrder()
				For Local i:Int = boundary.itemCount - 1 To 0 Step -1
					Local index:Int = i
					If boundary.sortable Then
						index = boundary.drawOrder[i]
					End If

					work[workCount] = boundary.items[index]
					workCount :+ 1
				Next
			Else
				EnsureWork(1)
				work[0] = scene.rootNode
				workCount = 1
			End If

			Local stackDepth:Int = canvas.saved.Count()
			While workCount
				workCount :- 1
				Local node:TSceneNode = work[workCount]
				work[workCount] = Null
				scene.renderStats.visited :+ 1
				If node.dead Or node.pendingDestroy Then
					Continue
				End If

				node.renderRed = 1
				node.renderGreen = 1
				node.renderBlue = 1
				node.renderAlpha = 1
				node.renderLayer = Null
				node.renderMatrix = baseMatrix
				If node.parentNode And node <> sourceRoot Then
					node.renderRed = node.parentNode.renderRed
					node.renderGreen = node.parentNode.renderGreen
					node.renderBlue = node.parentNode.renderBlue
					node.renderAlpha = node.parentNode.renderAlpha
					node.renderLayer = node.parentNode.renderLayer
					If node.parentNode <> boundary Then
						node.renderMatrix = node.parentNode.renderMatrix
					End If
				End If

				If TLayerNode(node) Then node.renderLayer = TLayerNode(node); node.renderMatrix = node.renderLayer.viewMatrix

				Local spatial:TSceneNode2D = TSceneNode2D(node)
				If spatial Then
					If Not spatial.visible Or spatial.opacity = 0 Then
						scene.renderStats.hidden :+ 1
						Continue
					End If

					node.renderRed :* spatial.tintRed / 255.0
					node.renderGreen :* spatial.tintGreen / 255.0
					node.renderBlue :* spatial.tintBlue / 255.0
					node.renderAlpha :* spatial.opacity
					spatial.EnsureWorld()
					Local matrix:SSceneMatrix
					matrix.Product(node.renderMatrix, spatial.localMatrix)
					node.renderMatrix = matrix
					Local x:Int = scope.entry.x, y:Int = scope.entry.y, w:Int = scope.entry.w, h:Int = scope.entry.h
					Local layer:TLayerNode = node.renderLayer
					If Not boundary And layer And layer.hasViewport Then
						Local right:Long = Min(Long(x) + w, Long(layer.clipX) + layer.clipW)
						Local bottom:Long = Min(Long(y) + h, Long(layer.clipY) + layer.clipH)
						x = Max(x, layer.clipX)
						y = Max(y, layer.clipY)
						w = Int(Max(0:Long, right - x))
						h = Int(Max(0:Long, bottom - y))
					End If

					If scene.culling Then
						If w <= 0 Or h <= 0 Then
							scene.renderStats.clipped :+ 1
							Continue
						End If

						If SceneCullBranch(scene, spatial, matrix, x, y, w, h) Then
							scene.renderStats.culled :+ 1
							Continue
						End If
					End If

					PrepareSceneDrawing(drawState, matrix, node)
					canvas.state = drawState
					canvas.imageFont = scope.entry.font
					Local view:TMax2DView = canvas.context.view
					If view.x <> x Or view.y <> y Or view.w <> w Or view.h <> h Then
						SetViewport(x, y, w, h)
					End If

					If w > 0 And h > 0 Then
						context.red = node.renderRed
						context.green = node.renderGreen
						context.blue = node.renderBlue
						context.alpha = node.renderAlpha
						context.active = True
						Try
							scene.renderStats.drawVisits :+ 1
							Local group:TSceneRenderGroup = TSceneRenderGroup(spatial)
							If group Then
								group.groupContext.active = True
								group.groupContext.scene = scene
								group.groupContext.node = group
								group.groupContext.canvas = canvas
								Try
									group.OnRenderGroup(group.groupContext)
								Finally
									group.groupContext.active = False
									group.groupContext.scene = Null
									group.groupContext.canvas = Null
								End Try
							Else
								spatial.DrawScene(context)
							End If
						Finally
							context.active = False
						End Try

						If TMax2DGraphics.selected <> canvas Or canvas.renderImage <> scope.entry.target Then
							Throw "Max2D Scene: draw callback changed canvas or target"
						End If

						If view.x <> x Or view.y <> y Or view.w <> w Or view.h <> h Or view.width <> scope.entry.width Or view.height <> scope.entry.height Or view.presentation <> scope.entry.presentation Then
							Throw "Max2D Scene: draw callback changed viewport or presentation"
						End If

						If canvas.saved.Count() <> stackDepth Then
							Throw "Max2D Scene: draw callback left unbalanced drawing scopes"
						End If
					End If
				End If

				If TSceneRenderGroup(node) Then
					Continue
				End If

				EnsureWork(workCount + node.itemCount)
				node.EnsureDrawOrder()
				For Local i:Int = node.itemCount - 1 To 0 Step -1
					Local index:Int = i
					If node.sortable Then
						index = node.drawOrder[i]
					End If

					work[workCount] = node.items[index]
					workCount :+ 1
				Next
			Wend
		Finally
			context.active = False
			context.canvas = Null
			For Local i:Int = 0 Until workCount
				work[i] = Null
			Next

			workCount = 0
		End Try
	End Method
End Type

Function PrepareSceneDrawing(state:TMax2DState, matrix:SSceneMatrix, node:TSceneNode)
	SceneCheckFinite(Float(matrix.xx))
	SceneCheckFinite(Float(matrix.xy))
	SceneCheckFinite(Float(matrix.yx))
	SceneCheckFinite(Float(matrix.yy))
	SceneCheckFinite(Float(matrix.tx))
	SceneCheckFinite(Float(matrix.ty))
	state.red = Int(node.renderRed * 255 + 0.5)
	state.green = Int(node.renderGreen * 255 + 0.5)
	state.blue = Int(node.renderBlue * 255 + 0.5)
	state.alpha = node.renderAlpha
	state.colorByteAlpha = 255
	state.clsByteAlpha = 255
	state.clsRed = 0
	state.clsGreen = 0
	state.clsBlue = 0
	state.clsAlpha = 1
	state.blend = ALPHABLEND
	state.lineWidth = 1
	state.rotation = 0
	state.scaleX = 1
	state.scaleY = 1
	state.ix = 1
	state.iy = 0
	state.jx = 0
	state.jy = 1
	state.originX = 0
	state.originY = 0
	state.handleX = 0
	state.handleY = 0
	state.coordXX = matrix.xx
	state.coordXY = matrix.xy
	state.coordYX = matrix.yx
	state.coordYY = matrix.yy
	state.coordTX = matrix.tx
	state.coordTY = matrix.ty
	state.camera = Null
	state.cameraXX = 1
	state.cameraXY = 0
	state.cameraYX = 0
	state.cameraYY = 1
	state.cameraTX = 0
	state.cameraTY = 0
End Function

Public
