Private

Global scenePickDepth:Int

Function SceneRectContains:Int(rect:TSceneRect, x:Float, y:Float)
	Return x >= rect.x And y >= rect.y And Double(x) < Double(rect.x) + rect.width And Double(y) < Double(rect.y) + rect.height
End Function

Function SceneScreenMatrix:Int(scene:TScene, node:TSceneNode, matrix:SSceneMatrix Var)
	If scene.dead Or Not node Then
		Return False
	End If

	If node.ownerScene <> scene Then
		Return False
	End If

	Local current:TSceneNode = node
	While current
		If current.dead Or current.pendingDestroy Then
			Return False
		End If

		current = current.parentNode
	Wend

	Local layer:TLayerNode = node.Layer()
	If Not layer Then
		Return False
	End If

	Local spatial:TSceneNode2D = TSceneNode2D(node)
	If Not spatial Then
		spatial = node.SpatialParent()
	End If

	If spatial Then
		spatial.EnsureWorld()
		matrix.Product(layer.viewMatrix, spatial.worldMatrix)
	Else
		matrix = layer.viewMatrix
	End If

	Return True
End Function

Function PickScene:TSceneNode2D(scene:TScene, x:Float, y:Float)
	If Not scene.inputClip Then
		Return Null
	End If

	If Not SceneRectContains(scene.inputClip, x, y) Then
		Return Null
	End If

	Local outerBusy:Int = scene.busy
	scene.busy = True
	scenePickDepth :+ 1
	Local count:Int
	Try
		scene.EnsureWork(1)
		scene.work[0] = scene.rootNode
		scene.workCount = 1
		While scene.workCount
			scene.workCount :- 1
			Local node:TSceneNode = scene.work[scene.workCount]
			scene.work[scene.workCount] = Null
			If node.dead Or node.pendingDestroy Or Not node.inputEnabled Then
				Continue
			End If

			Local layer:TLayerNode = TLayerNode(node)
			If layer And layer.hasViewport Then
				If Double(x) < layer.clipX Or Double(y) < layer.clipY Or Double(x) >= Double(layer.clipX) + layer.clipW Or Double(y) >= Double(layer.clipY) + layer.clipH Then
					Continue
				End If
			End If

			Local spatial:TSceneNode2D = TSceneNode2D(node)
			If spatial Then
				If Not spatial.visible Or spatial.opacity = 0 Then
					Continue
				End If

				Local group:TSceneRenderGroup = TSceneRenderGroup(spatial)
				If group Then
					Local localX:Float, localY:Float
					If Not scene.ScreenToLocal(group, x, y, localX, localY) Then
						Continue
					End If

					If Not group.HitTestInputClip(localX, localY) Then
						Continue
					End If
				End If

				If spatial.interactive Then
					If count = scene.pickNodes.Length Then
						scene.pickNodes = scene.pickNodes[..SceneCapacity(count, count + 1)]
					End If

					scene.pickNodes[count] = spatial
					count :+ 1
				End If
			End If

			node.EnsureDrawOrder()
			scene.EnsureWork(scene.workCount + node.itemCount)
			For Local i:Int = node.itemCount - 1 To 0 Step -1
				Local index:Int = i
				If node.sortable Then
					index = node.drawOrder[i]
				End If

				scene.work[scene.workCount] = node.items[index]
				scene.workCount :+ 1
			Next
		Wend

		For Local i:Int = count - 1 To 0 Step -1
			Local node:TSceneNode2D = scene.pickNodes[i]
			Local lx:Float, ly:Float
			If scene.ScreenToLocal(node, x, y, lx, ly) Then
				If node.HitTestLocal(lx, ly) Then
					Return node
				End If
			End If
		Next
	Finally
		For Local i:Int = 0 Until count
			scene.pickNodes[i] = Null
		Next

		For Local i:Int = 0 Until scene.workCount
			scene.work[i] = Null
		Next

		scene.workCount = 0
		scenePickDepth :- 1
		scene.busy = outerBusy
	End Try

	Return Null
End Function

Public
