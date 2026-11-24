Private

' Bounds callbacks are read-only, including queries on detached trees.
Global sceneBoundsDepth:Int

Struct SSceneBounds
	Field known:Int, hasArea:Int, cullSafe:Int
	Field left:Double, top:Double, right:Double, bottom:Double

	Method Empty()
		known = True
		hasArea = False
		cullSafe = True
		left = 0
		top = 0
		right = 0
		bottom = 0
	End Method

	Method Include(rect:SSceneBounds)
		cullSafe = cullSafe And rect.cullSafe
		If Not rect.known Then known = False; Return

		If Not rect.hasArea Then
			Return
		End If

		If Not hasArea Then
			left = rect.left
			top = rect.top
			right = rect.right
			bottom = rect.bottom
			hasArea = True
		Else
			left = Min(left, rect.left)
			top = Min(top, rect.top)
			right = Max(right, rect.right)
			bottom = Max(bottom, rect.bottom)
		End If
	End Method

	Method FromRect(rect:TSceneRect)
		SceneCheckRect(rect)
		Empty()
		If rect.width = 0 Or rect.height = 0 Then
			Return
		End If

		hasArea = True
		left = rect.x
		top = rect.y
		right = Double(rect.x) + rect.width
		bottom = Double(rect.y) + rect.height
		cullSafe = Max(Max(Abs(left), Abs(top)), Max(Abs(right), Abs(bottom))) <= 1000000
	End Method

	Method Transformed:SSceneBounds(matrix:SSceneMatrix)
		Local result:SSceneBounds
		result.Empty()
		result.known = known
		result.cullSafe = cullSafe And Max(Max(Abs(matrix.xx), Abs(matrix.xy)), Max(Abs(matrix.yx), Abs(matrix.yy))) <= 1000000 And Max(Abs(matrix.tx), Abs(matrix.ty)) <= 1000000
		If Not known Or Not hasArea Then
			Return result
		End If

		Local x0:Double = matrix.xx * left + matrix.xy * top + matrix.tx
		Local y0:Double = matrix.yx * left + matrix.yy * top + matrix.ty
		Local x1:Double = matrix.xx * right + matrix.xy * top + matrix.tx
		Local y1:Double = matrix.yx * right + matrix.yy * top + matrix.ty
		Local x2:Double = matrix.xx * left + matrix.xy * bottom + matrix.tx
		Local y2:Double = matrix.yx * left + matrix.yy * bottom + matrix.ty
		Local x3:Double = matrix.xx * right + matrix.xy * bottom + matrix.tx
		Local y3:Double = matrix.yx * right + matrix.yy * bottom + matrix.ty
		SceneCheckFinite(x0)
		SceneCheckFinite(y0)
		SceneCheckFinite(x1)
		SceneCheckFinite(y1)
		SceneCheckFinite(x2)
		SceneCheckFinite(y2)
		SceneCheckFinite(x3)
		SceneCheckFinite(y3)
		result.left = Min(Min(x0, x1), Min(x2, x3))
		result.top = Min(Min(y0, y1), Min(y2, y3))
		result.right = Max(Max(x0, x1), Max(x2, x3))
		result.bottom = Max(Max(y0, y1), Max(y2, y3))
		result.hasArea = result.right > result.left And result.bottom > result.top
		Return result
	End Method

	Method CopyTo:Int(rect:TSceneRect)
		If Not known Then
			Return False
		End If

		Local x:Float, y:Float, width:Float, height:Float
		If hasArea Then
			x = Float(left)
			y = Float(top)
			width = Float(right - left)
			height = Float(bottom - top)
			SceneCheckFinite(x)
			SceneCheckFinite(y)
			SceneCheckFinite(width)
			SceneCheckFinite(height)
		End If

		SceneWriteRect(rect, x, y, width, height)
		Return True
	End Method
End Struct

Function SceneMeasureBounds(node:TSceneNode)
	If node.boundsResolving Then
		Throw "Max2D Scene: recursive bounds query"
	End If

	node.boundsResolving = True
	Try
		Local result:SSceneBounds
		result.Empty()
		node.uncachedSubtree = False
		Local spatial:TSceneNode2D = TSceneNode2D(node)
		If Not node.dead And Not node.pendingDestroy Then
			Local contributes:Int = True
			If spatial Then
				contributes = spatial.visible And spatial.opacity > 0
			End If

			If contributes Then
				If spatial Then
					If Not spatial.measureRect Then
						spatial.measureRect = New TSceneRect
					End If

					If spatial.GetSelfBounds(spatial.measureRect) Then
						result.FromRect(spatial.measureRect)
					Else
						result.known = False
					End If
				End If

				For Local i:Int = 0 Until node.itemCount
					Local child:TSceneNode = node.items[i]
					child.EnsureBounds()
					Local childBounds:SSceneBounds = child.outputBounds
					node.uncachedSubtree :| child.uncachedSubtree
					Local childSpatial:TSceneNode2D = TSceneNode2D(child)
					If childSpatial Then
						childBounds = childBounds.Transformed(childSpatial.localMatrix)
					End If

					result.Include(childBounds)
				Next
			End If
		End If

		node.contentBounds = result
		node.outputBounds = result
		Local group:TSceneRenderGroup = TSceneRenderGroup(node)
		If group Then
			group.continuousChildren = False
		End If

		If group And Not node.dead And Not node.pendingDestroy And spatial.visible And spatial.opacity > 0 Then
			group.continuousChildren = node.uncachedSubtree
			node.uncachedSubtree :| group.RequiresContinuousRender()
			If Not group.outputRect Then
				group.outputRect = New TSceneRect
			End If

			result.CopyTo(spatial.measureRect)
			If group.MeasureGroupOutput(result.known, spatial.measureRect, group.outputRect) Then
				node.outputBounds.FromRect(group.outputRect)
				node.outputBounds.cullSafe :& result.cullSafe
			Else
				node.outputBounds.known = False
			End If
		End If

		node.boundsDirty = False
		If node.ownerScene And node.ownerScene.rendering Then
			node.ownerScene.renderStats.boundsRebuilds :+ 1
		End If
	Finally
		node.boundsResolving = False
	End Try
End Function

Function SceneNodeZ:Int(node:TSceneNode)
	Local spatial:TSceneNode2D = TSceneNode2D(node)
	If spatial Then
		Return spatial.zIndex
	End If

	Return 0
End Function

Function SceneSortChildren(node:TSceneNode)
	node.EnsureOrderCapacity(node.items.Length)
	Local source:Int[] = node.drawOrder, destination:Int[] = node.orderScratch
	Local count:Int = node.itemCount
	For Local i:Int = 0 Until count
		source[i] = i
	Next

	Local width:Int = 1
	While width < count
		Local start:Int
		While start < count
			Local middle:Int = start + Min(width, count - start)
			Local finish:Int = middle + Min(width, count - middle)
			Local left:Int = start, right:Int = middle
			For Local output:Int = start Until finish
				Local takeLeft:Int = right >= finish
				If left < middle And right < finish Then
					takeLeft = SceneNodeZ(node.items[source[left]]) <= SceneNodeZ(node.items[source[right]])
				End If

				If left < middle And takeLeft Then
					destination[output] = source[left]
					left :+ 1
				Else
					destination[output] = source[right]
					right :+ 1
				End If
			Next

			start = finish
		Wend

		Local swap:Int[] = source
		source = destination
		destination = swap
		If width > count / 2 Then
			Exit
		End If

		width :* 2
	Wend

	node.drawOrder = source
	node.orderScratch = destination
	node.orderDirty = False
End Function

Public
