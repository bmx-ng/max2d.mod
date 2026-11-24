Rem
bbdoc: Pointer event kind; adapters inject Down, Move, Up and Cancel only.
End Rem
Enum EScenePointerKind
	Rem
	bbdoc: A pointer press begins.
	End Rem
 	Down
	Rem
	bbdoc: A pointer position or button state changes.
	End Rem
	Move
	Rem
	bbdoc: A pointer press ends.
	End Rem
	Up
	Rem
	bbdoc: A press is cancelled without a usable position.
	End Rem
	Cancel
	Rem
	bbdoc: Generated when an opted-in hover pointer enters the topmost target.
	End Rem
	Enter
	Rem
	bbdoc: Generated when an opted-in hover pointer leaves its target.
	End Rem
	Leave
	Rem
	bbdoc: Pointer capture has ended.
	End Rem
	CaptureLost
End Enum

Rem
bbdoc: Durable read-only pointer data copied from a callback event.
about: Retains target and current-target references. It has no dispatch-control methods.
End Rem
Type TScenePointerSnapshot
	Internal
	Field eventKind:EScenePointerKind
	Field device:Long, pointer:Long
	Field px:Float, py:Float
	Field eventButton:Int, eventButtons:Int
	Field targetNode:TSceneNode2D
	Field currentNode:TSceneNode
	Method CheckReadable()
	End Method

	Public
	Rem
	bbdoc: Returns the event kind.
	returns: The event kind.
	End Rem
	Method Kind:EScenePointerKind()
		CheckReadable()
		Return eventKind
	End Method

	Rem
	bbdoc: Returns the adapter-supplied device identifier.
	returns: The adapter-supplied device identifier.
	End Rem
	Method DeviceId:Long()
		CheckReadable()
		Return device
	End Method

	Rem
	bbdoc: Returns the adapter-supplied pointer identifier within its device.
	returns: The adapter-supplied pointer identifier within its device.
	End Rem
	Method PointerId:Long()
		CheckReadable()
		Return pointer
	End Method

	Rem
	bbdoc: Returns the virtual horizontal position; zero for Cancel and CaptureLost.
	returns: The virtual horizontal position; zero for Cancel and CaptureLost.
	End Rem
	Method ScreenX:Float()
		CheckReadable()
		Return px
	End Method

	Rem
	bbdoc: Returns the virtual vertical position; zero for Cancel and CaptureLost.
	returns: The virtual vertical position; zero for Cancel and CaptureLost.
	End Rem
	Method ScreenY:Float()
		CheckReadable()
		Return py
	End Method

	Rem
	bbdoc: Returns the changed button code supplied by the adapter.
	returns: The changed button code supplied by the adapter.
	End Rem
	Method Button:Int()
		CheckReadable()
		Return eventButton
	End Method

	Rem
	bbdoc: Returns the adapter-supplied current button state.
	returns: The adapter-supplied current button state.
	End Rem
	Method Buttons:Int()
		CheckReadable()
		Return eventButtons
	End Method

	Rem
	bbdoc: Returns the original target for this dispatch path.
	returns: The original target for this dispatch path.
	End Rem
	Method Target:TSceneNode2D()
		CheckReadable()
		Return targetNode
	End Method

	Rem
	bbdoc: Returns the node receiving this callback.
	returns: The node receiving this callback.
	End Rem
	Method CurrentTarget:TSceneNode()
		CheckReadable()
		Return currentNode
	End Method
End Type

Rem
bbdoc: Borrowed pointer event valid only during its callback.
about: Do not retain this object. Copy creates a durable snapshot. Handle stops propagation and suppresses application fallback; StopPropagation only stops further path visits.
End Rem
Type TScenePointerEvent Extends TScenePointerSnapshot
	Internal
	Field active:Int, handled:Int, stopped:Int, releaseRequested:Int
	Field owner:TScene
	Field state:TScenePointerState
	Method CheckReadable()
		If Not active Then
			Throw "Max2D Scene: pointer event is no longer active"
		End If
	End Method

	Public
	Rem
	bbdoc: Allocates a durable copy of this callback's pointer data and node references.
	returns: A new durable event snapshot retaining its node references.
	End Rem
	Method Copy:TScenePointerSnapshot()
		CheckReadable()
		Local result:TScenePointerSnapshot = New TScenePointerSnapshot
		result.eventKind = eventKind
		result.device = device
		result.pointer = pointer
		result.px = px
		result.py = py
		result.eventButton = eventButton
		result.eventButtons = eventButtons
		result.targetNode = targetNode
		result.currentNode = currentNode
		Return result
	End Method
	Rem
	bbdoc: Converts the event position to an attached node's current local coordinates.
	param: Attached node whose local coordinate system is used.
	param: Receives finite horizontal coordinate in node-local units.
	param: Receives finite vertical coordinate in node-local units.
	returns: True when conversion succeeds; False leaves the output coordinates unchanged.
	about: Cancel and CaptureLost have no position and return False without changing outputs.
	End Rem
	Method PositionIn:Int(node:TSceneNode, x:Float Var, y:Float Var)
		CheckReadable()
		If eventKind = EScenePointerKind.Cancel Or eventKind = EScenePointerKind.CaptureLost Then
			Return False
		End If

		Return owner.ScreenToLocal(node, px, py, x, y)
	End Method
	Rem
	bbdoc: Captures this pointer for the current receiver during its Down callback.
	param: The current eligible interactive receiver of this Down callback.
	about: The receiver must be an eligible interactive spatial node. Another node's existing capture cannot be stolen. Multiple device/pointer pairs have independent captures.
	End Rem
	Method CapturePointer(node:TSceneNode2D)
		CheckReadable()
		If eventKind <> EScenePointerKind.Down Or Not state Then
			Throw "Max2D Scene: capture requires a Down callback"
		End If

		If Not node Or currentNode <> node Then
			Throw "Max2D Scene: only the current receiver can capture itself"
		End If

		If Not ScenePointerEligible(owner, node) Then
			Throw "Max2D Scene: capture target is not eligible"
		End If

		If state.capture And state.capture <> node Then
			Throw "Max2D Scene: pointer is already captured"
		End If

		state.capture = node
	End Method
	Rem
	bbdoc: Releases capture owned by the current receiver after this event path finishes.
	about: CaptureLost is then routed to the former owner. Up and Cancel release automatically.
	End Rem
	Method ReleasePointer()
		CheckReadable()
		If Not state Or Not state.capture Or state.capture <> currentNode Then
			Throw "Max2D Scene: receiver does not own capture"
		End If

		releaseRequested = True
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

Type TScenePointerState
	Field active:Int
	Field device:Long, pointer:Long
	Field pressed:TSceneNode2D, capture:TSceneNode2D
	Method Clear()
		active = False
		pressed = Null
		capture = Null
	End Method
End Type

Function EnsureScenePointers(scene:TScene, capacity:Int)
	If capacity <= scene.pointers.Length Then
		Return
	End If

	Local old:Int = scene.pointers.Length
	scene.pointers = scene.pointers[..SceneCapacity(old, capacity)]
	For Local i:Int = old Until scene.pointers.Length
		scene.pointers[i] = New TScenePointerState
	Next
End Function

Function TrimScenePointers(scene:TScene)
	Local count:Int
	For Local i:Int = 0 Until scene.pointers.Length
		Local state:TScenePointerState = scene.pointers[i]
		If state.active Then
			scene.pointers[count] = state
			count :+ 1
		End If
	Next

	scene.pointers = scene.pointers[..count]
End Function

Function FindScenePointer:TScenePointerState(scene:TScene, device:Long, pointer:Long)
	For Local state:TScenePointerState = EachIn scene.pointers
		If state.active And state.device = device And state.pointer = pointer Then
			Return state
		End If
	Next

	Return Null
End Function

Function AcquireScenePointer:TScenePointerState(scene:TScene, device:Long, pointer:Long)
	Local result:TScenePointerState
	For Local state:TScenePointerState = EachIn scene.pointers
		If Not state.active Then result = state; Exit
	Next

	If Not result Then
		Local old:Int = scene.pointers.Length
		EnsureScenePointers(scene, old + 1)
		result = scene.pointers[old]
	End If

	result.active = True
	result.device = device
	result.pointer = pointer
	Return result
End Function

Function ScenePointerEligible:Int(scene:TScene, node:TSceneNode2D)
	If Not node Or Not node.interactive Then
		Return False
	End If

	Return SceneInputEligible(scene, node)
End Function

Function SceneInputEligible:Int(scene:TScene, node:TSceneNode2D)
	If Not node Or node.ownerScene <> scene Then
		Return False
	End If

	Local current:TSceneNode = node
	While current
		If current.dead Or current.pendingDestroy Or Not current.inputEnabled Then
			Return False
		End If

		Local spatial:TSceneNode2D = TSceneNode2D(current)
		If spatial And (Not spatial.visible Or spatial.opacity = 0) Then
			Return False
		End If

		current = current.parentNode
	Wend

	Local x:Float, y:Float
	Return scene.ScreenToLocal(node, 0, 0, x, y)
End Function

Function RouteScenePointer:Int(scene:TScene, state:TScenePointerState, target:TSceneNode2D, kind:EScenePointerKind, device:Long, pointer:Long, x:Float, y:Float, button:Int, buttons:Int)
	If Not target Then
		Return False
	End If

	Local event:TScenePointerEvent = scene.pointerEvent
	Local count:Int
	Local current:TSceneNode = target
	While current
		If count = scene.pointerPath.Length Then
			scene.pointerPath = scene.pointerPath[..SceneCapacity(count, count + 1)]
		End If

		scene.pointerPath[count] = current
		count :+ 1
		current = current.parentNode
	Wend

	event.owner = scene
	event.state = state
	event.targetNode = target
	event.eventKind = kind
	event.device = device
	event.pointer = pointer
	event.px = x
	event.py = y
	event.eventButton = button
	event.eventButtons = buttons
	event.handled = False
	event.stopped = False
	event.releaseRequested = False
	Local handled:Int, releaseCapture:Int
	Try
		If kind = EScenePointerKind.Enter Or kind = EScenePointerKind.Leave Then
			VisitScenePointer(event, target, 1)
		Else
			For Local i:Int = count - 1 To 1 Step -1
				VisitScenePointer(event, scene.pointerPath[i], 0)
				If event.stopped Then
					Exit
				End If
			Next

			If Not event.stopped Then
				VisitScenePointer(event, target, 1)
			End If

			If Not event.stopped Then
				For Local i:Int = 1 Until count
					VisitScenePointer(event, scene.pointerPath[i], 2)
					If event.stopped Then
						Exit
					End If
				Next
			End If
		End If

		handled = event.handled
		releaseCapture = event.releaseRequested
	Finally
		event.active = False
		event.owner = Null
		event.state = Null
		event.targetNode = Null
		event.currentNode = Null
		For Local i:Int = 0 Until count
			scene.pointerPath[i] = Null
		Next
	End Try

	If releaseCapture And state Then
		LoseSceneCapture(scene, state)
	End If

	Return handled
End Function

Function VisitScenePointer(event:TScenePointerEvent, node:TSceneNode, phase:Int)
	If node.dead Then
		Return
	End If

	If event.eventKind <> EScenePointerKind.Cancel And event.eventKind <> EScenePointerKind.CaptureLost And event.eventKind <> EScenePointerKind.Leave Then
		If Not SceneInputPathEnabled(node) Then
			Return
		End If
	End If

	If node.pendingDestroy And event.eventKind <> EScenePointerKind.Cancel And event.eventKind <> EScenePointerKind.CaptureLost And event.eventKind <> EScenePointerKind.Leave Then
		Return
	End If

	event.currentNode = node
	event.active = True
	Try
		Select phase
			Case 0
				node.OnPointerCapture(event)
			Case 1
				node.OnPointer(event)
			Case 2
				node.OnPointerBubble(event)
		End Select
	Finally
		event.active = False
	End Try
End Function

Function LoseSceneCapture(scene:TScene, state:TScenePointerState)
	Local target:TSceneNode2D = state.capture
	state.capture = Null
	If target Then
		RouteScenePointer(scene, state, target, EScenePointerKind.CaptureLost, state.device, state.pointer, 0, 0, 0, 0)
	End If
End Function

Function CancelScenePointer:Int(scene:TScene, state:TScenePointerState, error:Object Var)
	If Not state.active Then
		Return False
	End If

	Local handled:Int
	Local target:TSceneNode2D = state.capture
	If Not target Then
		target = state.pressed
	End If

	Try
		handled = RouteScenePointer(scene, state, target, EScenePointerKind.Cancel, state.device, state.pointer, 0, 0, 0, 0)
	Catch caught:Object
		If Not error Then
			error = caught
		End If
	End Try

	Try
		LoseSceneCapture(scene, state)
	Catch caught:Object
		If Not error Then
			error = caught
		End If
	End Try

	state.Clear()
	Return handled
End Function

Function SceneInsideBranch:Int(node:TSceneNode, branch:TSceneNode)
	While node
		If node = branch Then
			Return True
		End If

		node = node.parentNode
	Wend

	Return False
End Function

Function CancelScenePointers(scene:TScene, branch:TSceneNode, error:Object Var)
	For Local state:TScenePointerState = EachIn scene.pointers
		If Not state.active Then
			Continue
		End If

		If Not branch Or SceneInsideBranch(state.pressed, branch) Or SceneInsideBranch(state.capture, branch) Then
			CancelScenePointer(scene, state, error)
		End If
	Next
End Function

Function ReconcileScenePointers(scene:TScene, error:Object Var)
	For Local state:TScenePointerState = EachIn scene.pointers
		If Not state.active Then
			Continue
		End If

		Local eligible:Int
		Try
			eligible = (Not state.pressed Or ScenePointerEligible(scene, state.pressed)) And (Not state.capture Or ScenePointerEligible(scene, state.capture))
		Catch caught:Object
			If Not error Then
				error = caught
			End If
		End Try

		If Not eligible Then
			CancelScenePointer(scene, state, error)
		End If
	Next
End Function

Function DispatchScenePointer:Int(scene:TScene, kind:EScenePointerKind, device:Long, pointer:Long, x:Float, y:Float, button:Int, buttons:Int)
	If kind <> EScenePointerKind.Down And kind <> EScenePointerKind.Move And kind <> EScenePointerKind.Up And kind <> EScenePointerKind.Cancel Then
		Throw "Max2D Scene: only Down, Move, Up and Cancel can be injected"
	End If

	If kind <> EScenePointerKind.Cancel Then SceneCheckFinite(x); SceneCheckFinite(y)

	Local error:Object, handled:Int
	UpdateSceneHoverPosition(scene, device, pointer, kind, x, y)
	scene.busy = True
	ReconcileScenePointers(scene, error)
	scene.Complete(error)
	If error Then
		Throw error
	End If

	Local state:TScenePointerState = FindScenePointer(scene, device, pointer)
	If kind = EScenePointerKind.Down And state Then
		Throw "Max2D Scene: pointer already has an active press"
	End If

	Local target:TSceneNode2D
	If kind <> EScenePointerKind.Cancel Then
		If state And state.capture Then
			target = state.capture
		Else
			target = scene.Pick(x, y)
		End If
	End If

	If kind = EScenePointerKind.Down And target Then
		state = AcquireScenePointer(scene, device, pointer)
		state.pressed = target
	End If

	scene.busy = True
	Try
		If kind = EScenePointerKind.Cancel Then
			If state Then
				handled = CancelScenePointer(scene, state, error)
			End If
		Else
			handled = RouteScenePointer(scene, state, target, kind, device, pointer, x, y, button, buttons)
			If kind = EScenePointerKind.Up And state Then
				LoseSceneCapture(scene, state)
				state.Clear()
			End If
		End If
	Catch caught:Object
		If Not error Then
			error = caught
		End If

		If state Then
			CancelScenePointer(scene, state, error)
		End If
	End Try

	scene.Complete(error)
	If error Then
		Throw error
	End If

	Return handled
End Function

Public
