Rem
bbdoc: Physical key action supplied by an application adapter.
End Rem
Enum ESceneKeyKind
	Rem
	bbdoc: Key press or repeated press.
	End Rem
	Down
	Rem
	bbdoc: Key release.
	End Rem
	Up
End Enum
Rem
bbdoc: Shift modifier bit for scene key events.
End Rem
Const SCENE_MOD_SHIFT:Int = 1
Rem
bbdoc: Control modifier bit for scene key events.
End Rem
Const SCENE_MOD_CONTROL:Int = 2
Rem
bbdoc: Alt modifier bit for scene key events.
End Rem
Const SCENE_MOD_ALT:Int = 4
Rem
bbdoc: Meta/Command modifier bit for scene key events.
End Rem
Const SCENE_MOD_META:Int = 8

Rem
bbdoc: Durable read-only key event data, retaining its target references.
End Rem
Type TSceneKeySnapshot
	Internal
	Field eventKind:ESceneKeyKind
	Field keyCode:Int, modifierBits:Int, repeat:Int
	Field targetNode:TSceneNode2D, currentNode:TSceneNode
	Method CheckReadable()
	End Method

	Public
	Rem
	bbdoc: Returns Down or Up.
	returns: Down or Up.
	End Rem
	Method Kind:ESceneKeyKind()
		CheckReadable()
		Return eventKind
	End Method

	Rem
	bbdoc: Returns the adapter's physical key code.
	returns: The adapter's physical key code.
	End Rem
	Method Key:Int()
		CheckReadable()
		Return keyCode
	End Method

	Rem
	bbdoc: Returns the supplied modifier bit mask.
	returns: The supplied modifier bit mask.
	End Rem
	Method Modifiers:Int()
		CheckReadable()
		Return modifierBits
	End Method

	Rem
	bbdoc: Returns whether this is a repeated press.
	returns: Whether this is a repeated press.
	End Rem
	Method Repeated:Int()
		CheckReadable()
		Return repeat
	End Method

	Rem
	bbdoc: Returns the focused target at dispatch start.
	returns: The focused target at dispatch start.
	End Rem
	Method Target:TSceneNode2D()
		CheckReadable()
		Return targetNode
	End Method

	Rem
	bbdoc: Returns the receiver of this callback.
	returns: The receiver of this callback.
	End Rem
	Method CurrentTarget:TSceneNode()
		CheckReadable()
		Return currentNode
	End Method
End Type

Rem
bbdoc: Borrowed key event valid only during its callback; Copy provides durable data.
End Rem
Type TSceneKeyEvent Extends TSceneKeySnapshot
	Internal
	Field active:Int, handled:Int, stopped:Int
	Method CheckReadable()
		If Not active Then
			Throw "Max2D Scene: key event is no longer active"
		End If
	End Method

	Public
	Rem
	bbdoc: Allocates a durable snapshot of this callback's key data and node references.
	returns: A new durable event snapshot retaining its node references.
	End Rem
	Method Copy:TSceneKeySnapshot()
		CheckReadable()
		Local result:TSceneKeySnapshot = New TSceneKeySnapshot
		result.eventKind = eventKind
		result.keyCode = keyCode
		result.modifierBits = modifierBits
		result.repeat = repeat
		result.targetNode = targetNode
		result.currentNode = currentNode
		Return result
	End Method

	Rem
	bbdoc: Marks the event handled and stops further path visits.
	End Rem
	Method Handle()
		CheckReadable()
		handled = True
		stopped = True
	End Method

	Rem
	bbdoc: Stops further path visits without marking the event handled.
	End Rem
	Method StopPropagation()
		CheckReadable()
		stopped = True
	End Method
End Type

Private

Type TSceneHoverState
	Field enabled:Int, positioned:Int
	Field device:Long, pointer:Long
	Field x:Float, y:Float
	Field target:TSceneNode2D
End Type

Function ConfigureSceneHover(scene:TScene, device:Long, pointer:Long, enabled:Int)
	Local record:TSceneHoverState
	For Local item:TSceneHoverState = EachIn scene.hovers
		If item.enabled And item.device = device And item.pointer = pointer Then record = item; Exit
	Next

	If record Then
		If enabled Then
			Return
		End If

		scene.busy = True
		record.enabled = False
		record.positioned = False
		Local error:Object
		SetSceneHoverTarget(scene, record, Null, error)
		scene.Complete(error)
		If error Then
			Throw error
		End If

		Return
	End If

	If Not enabled Then
		Return
	End If

	For Local item:TSceneHoverState = EachIn scene.hovers
		If Not item.enabled Then record = item; Exit
	Next

	If Not record Then
		Local old:Int = scene.hovers.Length
		scene.hovers = scene.hovers[..SceneCapacity(old, old + 1)]
		For Local i:Int = old Until scene.hovers.Length
			scene.hovers[i] = New TSceneHoverState
		Next

		record = scene.hovers[old]
	End If

	record.enabled = True
	record.positioned = False
	record.device = device
	record.pointer = pointer
End Function

Function TrimSceneHover(scene:TScene)
	Local count:Int
	For Local record:TSceneHoverState = EachIn scene.hovers
		If record.enabled Then scene.hovers[count] = record; count :+ 1
	Next

	scene.hovers = scene.hovers[..count]
End Function

Function UpdateSceneHoverPosition(scene:TScene, device:Long, pointer:Long, kind:EScenePointerKind, x:Float, y:Float)
	For Local record:TSceneHoverState = EachIn scene.hovers
		If Not record.enabled Or record.device <> device Or record.pointer <> pointer Then
			Continue
		End If

		record.positioned = kind <> EScenePointerKind.Cancel
		If record.positioned Then record.x = x; record.y = y

		Return
	Next
End Function

Function SetSceneHoverTarget(scene:TScene, record:TSceneHoverState, target:TSceneNode2D, error:Object Var)
	If record.target = target Then
		Return
	End If

	Local previous:TSceneNode2D = record.target
	record.target = target
	Try
		RouteScenePointer(scene, Null, previous, EScenePointerKind.Leave, record.device, record.pointer, record.x, record.y, 0, 0)
	Catch caught:Object
		If Not error Then
			error = caught
		End If
	End Try

	If target Then
		Try
			If ScenePointerEligible(scene, target) Then
				RouteScenePointer(scene, Null, target, EScenePointerKind.Enter, record.device, record.pointer, record.x, record.y, 0, 0)
			Else
				record.target = Null
			End If
		Catch caught:Object
			If Not error Then
				error = caught
			End If
		End Try
	End If
End Function

Function ClearSceneHover(scene:TScene, branch:TSceneNode, error:Object Var)
	For Local record:TSceneHoverState = EachIn scene.hovers
		If Not record.enabled Then
			Continue
		End If

		If Not branch Then
			record.positioned = False
		End If

		If Not branch Or SceneInsideBranch(record.target, branch) Then
			SetSceneHoverTarget(scene, record, Null, error)
		End If
	Next
End Function

Function ReconcileSceneHover(scene:TScene, error:Object Var)
	For Local record:TSceneHoverState = EachIn scene.hovers
		If Not record.enabled Then
			Continue
		End If

		Local capture:TScenePointerState = FindScenePointer(scene, record.device, record.pointer)
		If capture And capture.capture Then
			Continue
		End If

		Local target:TSceneNode2D
		Try
			If record.positioned And Not scene.rootNode.pendingDestroy And Not scene.rootNode.dead Then
				target = PickScene(scene, record.x, record.y)
			End If
		Catch caught:Object
			If Not error Then
				error = caught
			End If
		End Try

		SetSceneHoverTarget(scene, record, target, error)
	Next
End Function

Function SceneFocusEligible:Int(scene:TScene, node:TSceneNode2D)
	Return node And node.focusable And SceneInputEligible(scene, node)
End Function

Function ChangeSceneFocus(scene:TScene, node:TSceneNode2D)
	If scene.focusChanging Then
		Throw "Max2D Scene: nested focus notification is not allowed"
	End If

	If node And Not SceneFocusEligible(scene, node) Then
		Throw "Max2D Scene: focus target is not eligible"
	End If

	If scene.focused = node Then
		Return
	End If

	Local previous:TSceneNode2D = scene.focused
	scene.focused = Null
	scene.focusChanging = True
	Local error:Object
	Try
		If previous Then
			Try
				previous.OnFocusLost()
			Catch caught:Object
				error = caught
			End Try
		End If

		If node And SceneFocusEligible(scene, node) Then
			scene.focused = node
			Try
				node.OnFocusGained()
			Catch caught:Object
				If Not error Then
					error = caught
				End If
			End Try
		End If
	Finally
		scene.focusChanging = False
	End Try

	If error Then
		Throw error
	End If
End Function

Function ClearSceneFocus(scene:TScene, branch:TSceneNode, error:Object Var)
	If Not scene.focused Then
		Return
	End If

	If branch And Not SceneInsideBranch(scene.focused, branch) Then
		Return
	End If

	Try
		ChangeSceneFocus(scene, Null)
	Catch caught:Object
		If Not error Then
			error = caught
		End If
	End Try
End Function

Function ReconcileSceneFocus(scene:TScene, error:Object Var)
	If Not scene.focused Then
		Return
	End If

	Local eligible:Int
	Try
		eligible = SceneFocusEligible(scene, scene.focused)
	Catch caught:Object
		If Not error Then
			error = caught
		End If
	End Try

	If Not eligible Then
		ClearSceneFocus(scene, Null, error)
	End If
End Function

Function NavigateSceneFocus(scene:TScene, reverse:Int)
	scene.busy = True
	Local error:Object
	ReconcileSceneFocus(scene, error)
	scene.Complete(error)
	If error Then
		Throw error
	End If

	Local count:Int, currentIndex:Int = -1
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

			Local spatial:TSceneNode2D = TSceneNode2D(node)
			If spatial Then
				If Not spatial.visible Or spatial.opacity = 0 Then
					Continue
				End If

				If SceneFocusEligible(scene, spatial) Then
					If count = scene.focusCandidates.Length Then
						scene.focusCandidates = scene.focusCandidates[..SceneCapacity(count, count + 1)]
					End If

					scene.focusCandidates[count] = spatial
					If spatial = scene.focused Then
						currentIndex = count
					End If

					count :+ 1
				End If
			End If

			scene.EnsureWork(scene.workCount + node.itemCount)
			For Local i:Int = node.itemCount - 1 To 0 Step -1
				scene.work[scene.workCount] = node.items[i]
				scene.workCount :+ 1
			Next
		Wend

		Local first:Int = -1, nextIndex:Int = -1
		For Local i:Int = 0 Until count
			If first < 0 Then
				first = i
			Else If SceneFocusBefore(scene.focusCandidates, i, first, reverse) Then
				first = i
			End If

			If currentIndex >= 0 Then
				If SceneFocusBefore(scene.focusCandidates, currentIndex, i, reverse) Then
					If nextIndex < 0 Then
						nextIndex = i
					Else If SceneFocusBefore(scene.focusCandidates, i, nextIndex, reverse) Then
						nextIndex = i
					End If
				End If
			End If
		Next

		If nextIndex < 0 Then
			nextIndex = first
		End If

		Local target:TSceneNode2D
		If nextIndex >= 0 Then
			target = scene.focusCandidates[nextIndex]
		End If
		' Clear traversal references before focus callbacks can queue mutations.
		For Local i:Int = 0 Until count
			scene.focusCandidates[i] = Null
		Next

		count = 0
		scene.SetFocus(target)
	Finally
		For Local i:Int = 0 Until count
			scene.focusCandidates[i] = Null
		Next

		For Local i:Int = 0 Until scene.workCount
			scene.work[i] = Null
		Next

		scene.workCount = 0
	End Try
End Function

Function SceneFocusBefore:Int(nodes:TSceneNode2D[], a:Int, b:Int, reverse:Int)
	If nodes[a].focusOrder = nodes[b].focusOrder Then
		If reverse Then
			Return a > b
		End If

		Return a < b
	End If

	If reverse Then
		Return nodes[a].focusOrder > nodes[b].focusOrder
	End If

	Return nodes[a].focusOrder < nodes[b].focusOrder
End Function

Function SceneInputPathEnabled:Int(node:TSceneNode)
	While node
		If Not node.inputEnabled Then
			Return False
		End If

		node = node.parentNode
	Wend

	Return True
End Function

Function VisitSceneKey(event:TSceneKeyEvent, node:TSceneNode, phase:Int)
	If node.dead Or node.pendingDestroy Or Not SceneInputPathEnabled(node) Then
		Return
	End If

	event.currentNode = node
	event.active = True
	Try
		Select phase
			Case 0
				node.OnKeyCapture(event)
			Case 1
				node.OnKey(event)
			Case 2
				node.OnKeyBubble(event)
		End Select
	Finally
		event.active = False
	End Try
End Function

Function DispatchSceneKey:Int(scene:TScene, kind:ESceneKeyKind, key:Int, modifiers:Int, repeated:Int)
	If kind <> ESceneKeyKind.Down And kind <> ESceneKeyKind.Up Then
		Throw "Max2D Scene: invalid key kind"
	End If

	scene.busy = True
	Local error:Object
	scene.Complete(error)
	If error Then
		Throw error
	End If

	Local event:TSceneKeyEvent = scene.keyEvent
	Local current:TSceneNode = scene.focused
	Local count:Int, handled:Int
	scene.busy = True
	Try
		While current
			If count = scene.keyPath.Length Then
				scene.keyPath = scene.keyPath[..SceneCapacity(count, count + 1)]
			End If

			scene.keyPath[count] = current
			count :+ 1
			current = current.parentNode
		Wend

		If count Then
			event.eventKind = kind
			event.keyCode = key
			event.modifierBits = modifiers
			event.repeat = repeated <> 0
			event.targetNode = scene.focused
			event.handled = False
			event.stopped = False
			For Local i:Int = count - 1 To 1 Step -1
				VisitSceneKey(event, scene.keyPath[i], 0)
				If event.stopped Then
					Exit
				End If
			Next

			If Not event.stopped Then
				VisitSceneKey(event, scene.keyPath[0], 1)
			End If

			If Not event.stopped Then
				For Local i:Int = 1 Until count
					VisitSceneKey(event, scene.keyPath[i], 2)
					If event.stopped Then
						Exit
					End If
				Next
			End If

			handled = event.handled
		End If
	Catch caught:Object
		error = caught
	Finally
		event.active = False
		event.targetNode = Null
		event.currentNode = Null
		For Local i:Int = 0 Until count
			scene.keyPath[i] = Null
		Next
	End Try

	scene.Complete(error)
	If error Then
		Throw error
	End If

	Return handled
End Function

Public
