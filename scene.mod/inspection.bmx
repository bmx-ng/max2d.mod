Private

Function SceneDebugKind:String(node:TSceneNode)
	If TSceneRenderGroup(node) Then
		Return "TSceneRenderGroup"
	End If

	If TSpriteNode(node) Then
		Return "TSpriteNode"
	End If

	If TTextNode(node) Then
		Return "TTextNode"
	End If

	If TMeshNode(node) Then
		Return "TMeshNode"
	End If

	If TCustomDrawNode(node) Then
		Return "TCustomDrawNode"
	End If

	If TLayerNode(node) Then
		Return "TLayerNode"
	End If

	If TSceneNode2D(node) Then
		Return "TSceneNode2D"
	End If

	Return "TSceneNode"
End Function

Function SceneDebugPath:String(node:TSceneNode)
	Local path:String
	While node.parentNode
		Local parent:TSceneNode = node.parentNode
		For Local i:Int = 0 Until parent.itemCount
			If parent.items[i] = node Then
				path = "/" + i + path
				Exit
			End If
		Next

		node = parent
	Wend

	Return "root" + path
End Function

Function SceneDebugBounds:String(bounds:SSceneBounds)
	If Not bounds.known Then
		Return "unknown"
	End If

	If Not bounds.hasArea Then
		Return "empty"
	End If

	Return "[" + bounds.left + "," + bounds.top + " " + (bounds.right - bounds.left) + "x" + (bounds.bottom - bounds.top) + "]"
End Function

Function InspectSceneTree:String(scene:TScene)
	Local result:String = "Scene retained=" + scene.storageBytes + " budget=" + scene.storageLimit + " bytes~n"
	Local work:TSceneNode[] = New TSceneNode[16]
	Local count:Int = 1
	work[0] = scene.rootNode
	While count
		count :- 1
		Local node:TSceneNode = work[count]
		work[count] = Null
		result :+ SceneDebugPath(node) + " " + SceneDebugKind(node) + " name=~q" + node.label.Replace("~n", "\\n").Replace("~r", "\\r").Replace("~q", "'") + "~q"
		result :+ " attached=" + (node.ownerScene = scene) + " ready=" + node.ready + " pending=" + node.pendingDestroy
		result :+ " update=" + node.processing + " fixed=" + node.fixedProcessing + " input=" + node.inputEnabled + " boundsDirty=" + node.boundsDirty
		Local spatial:TSceneNode2D = TSceneNode2D(node)
		If spatial Then
			result :+ " visible=" + spatial.visible + " alpha=" + spatial.opacity + " interactive=" + spatial.interactive + " focusable=" + spatial.focusable + " worldDirty=" + spatial.worldDirty
		End If

		result :+ " cachedContent=" + SceneDebugBounds(node.contentBounds) + " cachedOutput=" + SceneDebugBounds(node.outputBounds)
		Local group:TSceneRenderGroup = TSceneRenderGroup(node)
		If group Then
			result :+ " textureBytes=" + group.chargedBytes
		End If

		result :+ "~n"
		If count + node.itemCount > work.Length Then
			work = work[..SceneCapacity(work.Length, count + node.itemCount)]
		End If

		For Local i:Int = node.itemCount - 1 To 0 Step -1
			work[count] = node.items[i]
			count :+ 1
		Next
	Wend

	Return result
End Function

Type TSceneDebugPass
	Field scope:TSceneStateScope = New TSceneStateScope
	Field work:TSceneNode[]
	Field rect:TSceneRect = New TSceneRect
	Method Run(scene:TScene, outer:TMax2DStateScope)
		scope.Open(TMax2DGraphics.Current())
		Local oldBounds:Long = scene.renderStats.boundsRebuilds, oldWorld:Long = scene.renderStats.worldRebuilds
		Local count:Int
		sceneBoundsDepth :+ 1
		Try
			SetCamera(Null)
			ResetCoordinates()
			SetAffineTransform(1, 0, 0, 1)
			SetOrigin(0, 0)
			SetHandle(0, 0)
			SetRotation(0)
			SetScale(1, 1)
			SetBlend(ALPHABLEND)
			SetAlpha(1)
			SetLineWidth(1)
			If work.Length = 0 Then
				work = New TSceneNode[64]
			End If

			work[0] = scene.rootNode
			count = 1
			While count
				count :- 1
				Local node:TSceneNode = work[count]
				work[count] = Null
				If node.dead Or node.pendingDestroy Then
					Continue
				End If

				Local spatial:TSceneNode2D = TSceneNode2D(node)
				If spatial Then
					If Not spatial.visible Or spatial.opacity = 0 Then
						Continue
					End If

					Local matrix:SSceneMatrix
					If SceneScreenMatrix(scene, node, matrix) Then
						Local x:Int = outer.entry.x, y:Int = outer.entry.y, w:Int = outer.entry.w, h:Int = outer.entry.h
						Local layer:TLayerNode = node.Layer()
						If layer And layer.hasViewport Then
							Local right:Long = Min(Long(x) + w, Long(layer.clipX) + layer.clipW)
							Local bottom:Long = Min(Long(y) + h, Long(layer.clipY) + layer.clipH)
							x = Max(x, layer.clipX)
							y = Max(y, layer.clipY)
							w = Int(Max(0:Long, right - x))
							h = Int(Max(0:Long, bottom - y))
						End If

						SetViewport(x, y, w, h)
						If w > 0 And h > 0 Then
							spatial.EnsureBounds()
							SetColor(40, 210, 255)
							If spatial.contentBounds.CopyTo(rect) Then
								Outline(matrix, rect)
							End If

							SetColor(255, 210, 40)
							If spatial.outputBounds.CopyTo(rect) Then
								Outline(matrix, rect)
							End If

							If Not spatial.contentBounds.known Or Not spatial.outputBounds.known Then
								SetColor(255, 60, 220)
								DrawLine(Float(matrix.tx) - 4, Float(matrix.ty), Float(matrix.tx) + 4, Float(matrix.ty))
								DrawLine(Float(matrix.tx), Float(matrix.ty) - 4, Float(matrix.tx), Float(matrix.ty) + 4)
							End If

							Local input:Int = spatial.interactive And scene.inputClip <> Null
							Local ancestor:TSceneNode = node
							While input And ancestor
								input = ancestor.inputEnabled
								ancestor = ancestor.parentNode
							Wend

							If input Then
								Local known:Int
								If spatial.hasHitRect Then
									SceneWriteRect(rect, spatial.hitRect.x, spatial.hitRect.y, spatial.hitRect.width, spatial.hitRect.height)
									known = True
								Else
									known = spatial.GetSelfBounds(rect)
								End If

								If known Then
									SceneCheckRect(rect)
									Local hitX:Double = Max(Double(x), Floor(Double(scene.inputClip.x))), hitY:Double = Max(Double(y), Floor(Double(scene.inputClip.y)))
									Local hitRight:Double = Min(Double(x) + w, Ceil(Double(scene.inputClip.x) + scene.inputClip.width))
									Local hitBottom:Double = Min(Double(y) + h, Ceil(Double(scene.inputClip.y) + scene.inputClip.height))
									If hitRight > hitX And hitBottom > hitY Then
										SetViewport(Int(hitX), Int(hitY), Int(hitRight - hitX), Int(hitBottom - hitY))
										SetColor(60, 255, 100)
										Outline(matrix, rect)
									End If
								End If
							End If
						End If
					End If
				End If

				If count + node.itemCount > work.Length Then
					work = work[..SceneCapacity(work.Length, count + node.itemCount)]
				End If

				For Local i:Int = node.itemCount - 1 To 0 Step -1
					work[count] = node.items[i]
					count :+ 1
				Next
			Wend
		Finally
			For Local i:Int = 0 Until count
				work[i] = Null
			Next

			sceneBoundsDepth :- 1
			scene.renderStats.boundsRebuilds = oldBounds
			scene.renderStats.worldRebuilds = oldWorld
			scope.Close()
		End Try
	End Method

	Method Outline(matrix:SSceneMatrix, rect:TSceneRect)
		If rect.width = 0 Or rect.height = 0 Then
			Return
		End If

		Local x:Double = rect.x, y:Double = rect.y, right:Double = x + rect.width, bottom:Double = y + rect.height
		Local ax:Float = Float(matrix.xx * x + matrix.xy * y + matrix.tx), ay:Float = Float(matrix.yx * x + matrix.yy * y + matrix.ty)
		Local bx:Float = Float(matrix.xx * right + matrix.xy * y + matrix.tx), by:Float = Float(matrix.yx * right + matrix.yy * y + matrix.ty)
		Local cx:Float = Float(matrix.xx * right + matrix.xy * bottom + matrix.tx), cy:Float = Float(matrix.yx * right + matrix.yy * bottom + matrix.ty)
		Local dx:Float = Float(matrix.xx * x + matrix.xy * bottom + matrix.tx), dy:Float = Float(matrix.yx * x + matrix.yy * bottom + matrix.ty)
		SceneCheckFinite(ax)
		SceneCheckFinite(ay)
		SceneCheckFinite(bx)
		SceneCheckFinite(by)
		SceneCheckFinite(cx)
		SceneCheckFinite(cy)
		SceneCheckFinite(dx)
		SceneCheckFinite(dy)
		DrawLine(ax, ay, bx, by)
		DrawLine(bx, by, cx, cy)
		DrawLine(cx, cy, dx, dy)
		DrawLine(dx, dy, ax, ay)
	End Method
End Type

Public
