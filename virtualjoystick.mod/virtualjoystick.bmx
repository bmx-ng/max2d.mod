SuperStrict

Rem
bbdoc: Safe-area-aware onscreen joystick and buttons for Max2D applications.
End Rem
Module Max2D.VirtualJoystick
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Core
Import BRL.Event
Import BRL.Hook
Import BRL.Math
Import Pub.Joystick

Const VIRTUAL_AXIS_X:Int = 1 Shl JOY_X
Const VIRTUAL_AXIS_Y:Int = 1 Shl JOY_Y
Const VIRTUAL_AXIS_XY:Int = VIRTUAL_AXIS_X | VIRTUAL_AXIS_Y
Const VIRTUAL_BUTTON_LAYOUT_HORIZONTAL:Int = 0
Const VIRTUAL_BUTTON_LAYOUT_VERTICAL:Int = 1
Const VIRTUAL_BUTTON_LAYOUT_DIAGONAL:Int = 2
Const VIRTUAL_BUTTON_LAYOUT_GRID:Int = 3

Private
Global _circleMesh:TMesh2D
Global _driver:TVirtualJoystickDriver = New TVirtualJoystickDriver

Function CircleMesh:TMesh2D()
	If _circleMesh Then Return _circleMesh
	Const segments:Int = 48
	Local xy:Float[] = New Float[(segments + 1) * 2]
	Local indices:Int[] = New Int[segments * 3]
	For Local index:Int = 0 Until segments
		Local angle:Float = Float(index) * 360.0 / segments
		xy[(index + 1) * 2] = Cos(angle)
		xy[(index + 1) * 2 + 1] = Sin(angle)
		indices[index * 3] = 0
		indices[index * 3 + 1] = index + 1
		indices[index * 3 + 2] = (index + 1) Mod segments + 1
	Next
	_circleMesh = TMesh2D.Create(xy, indices)
	Return _circleMesh
End Function

Function DrawControlCircle(x:Float, y:Float, radius:Float, red:Int, green:Int, blue:Int, alpha:Float)
	If radius <= 0 Or alpha <= 0 Then Return
	SetColor(red, green, blue, alpha)
	SetTransform(0, radius, radius)
	DrawMesh(CircleMesh(), x, y)
End Function
Public

Rem
bbdoc: One circular onscreen action button.
End Rem
Type TVirtualButton
	Field centerX:Float
	Field centerY:Float
	Field radius:Float
	Field touchId:Int = -1
	Field down:Int
	Field hits:Int
	Field label:String

	Method Contains:Int(x:Float, y:Float)
		Local dx:Float = x - centerX, dy:Float = y - centerY
		Return dx * dx + dy * dy <= radius * radius
	End Method

	Method TouchDown:Int(id:Int, x:Float, y:Float)
		If touchId <> -1 Or Not Contains(x, y) Then Return False
		touchId = id
		down = True
		hits :+ 1
		Return True
	End Method

	Method TouchUp:Int(id:Int)
		If touchId <> id Then Return False
		touchId = -1
		down = False
		Return True
	End Method

	Method Hit:Int()
		Local result:Int = hits
		hits = 0
		Return result
	End Method

	Method Cancel()
		touchId = -1
		down = False
	End Method
End Type

Rem
bbdoc: One circular onscreen analogue stick.
End Rem
Type TVirtualStick
	Field centerX:Float
	Field centerY:Float
	Field radius:Float
	Field knobRadius:Float
	Field knobX:Float
	Field knobY:Float
	Field touchId:Int = -1
	Field axes:Int = VIRTUAL_AXIS_XY

	Method SetPosition(x:Float, y:Float, radius:Float, knobRadius:Float)
		Local active:Int = touchId <> -1
		Local oldX:Float = X(), oldY:Float = Y()
		centerX = x; centerY = y
		Self.radius = Max(1.0, radius)
		Self.knobRadius = Max(1.0, Min(knobRadius, Self.radius))
		If active Then
			knobX = centerX + oldX * Self.radius
			knobY = centerY + oldY * Self.radius
		Else
			knobX = centerX; knobY = centerY
		End If
	End Method

	Method Contains:Int(x:Float, y:Float)
		Local dx:Float = x - centerX, dy:Float = y - centerY
		Return dx * dx + dy * dy <= radius * radius
	End Method

	Method TouchDown:Int(id:Int, x:Float, y:Float)
		If touchId <> -1 Or Not Contains(x, y) Then Return False
		touchId = id
		Move(id, x, y)
		Return True
	End Method

	Method Move:Int(id:Int, x:Float, y:Float)
		If touchId <> id Then Return False
		Local dx:Float = x - centerX, dy:Float = y - centerY
		Local distance:Float = Sqr(dx * dx + dy * dy)
		If distance > radius And distance > 0 Then
			dx :* radius / distance
			dy :* radius / distance
		End If
		If Not (axes & VIRTUAL_AXIS_X) Then dx = 0
		If Not (axes & VIRTUAL_AXIS_Y) Then dy = 0
		knobX = centerX + dx; knobY = centerY + dy
		Return True
	End Method

	Method TouchUp:Int(id:Int)
		If touchId <> id Then Return False
		Cancel()
		Return True
	End Method

	Method Cancel()
		touchId = -1
		knobX = centerX; knobY = centerY
	End Method

	Method X:Float()
		If Not (axes & VIRTUAL_AXIS_X) Or radius <= 0 Then Return 0
		Return (knobX - centerX) / radius
	End Method

	Method Y:Float()
		If Not (axes & VIRTUAL_AXIS_Y) Or radius <= 0 Then Return 0
		Return (knobY - centerY) / radius
	End Method
End Type

Rem
bbdoc: A safe-area-aware onscreen joystick with an analogue stick and action buttons.
about: Coordinates and rendering use native output pixels, independently of the game's virtual resolution. The control listens to backend-neutral BlitzMax touch events but does not replace the active physical joystick driver.
End Rem
Type TVirtualJoystick
	Field name:String = "Max2D virtual joystick"
	Field stick:TVirtualStick = New TVirtualStick
	Field buttons:TVirtualButton[] = New TVirtualButton[0]
	Field visible:Int = True
	Field enabled:Int = True
	Field automaticLayout:Int = True
	Field buttonLayout:Int = VIRTUAL_BUTTON_LAYOUT_DIAGONAL
	Field uiScale:Float = 1.0
	Field margin:Float = 42.0
	Field baseRadius:Float = 82.0
	Field knobRadius:Float = 34.0
	Field buttonRadius:Float = 46.0
	Field buttonGap:Float = 18.0
	Field idleAlpha:Float = 0.48
	Field activeAlpha:Float = 0.82
	Field baseRed:Int = 72
	Field baseGreen:Int = 92
	Field baseBlue:Int = 122
	Field knobRed:Int = 76
	Field knobGreen:Int = 174
	Field knobBlue:Int = 240
	Field buttonRed:Int = 245
	Field buttonGreen:Int = 166
	Field buttonBlue:Int = 35
	Field _hooked:Int
	Field _freed:Int
	Field _safeX:Int = -1
	Field _safeY:Int = -1
	Field _safeWidth:Int = -1
	Field _safeHeight:Int = -1

	Function Create:TVirtualJoystick(buttonCount:Int = 2, name:String = "Max2D virtual joystick")
		Local joystick:TVirtualJoystick = New TVirtualJoystick
		joystick.name = name
		For Local index:Int = 0 Until Max(0, buttonCount)
			joystick.AddButton()
		Next
		Return joystick
	End Function

	Method New()
		_driver.Add(Self)
		Enable()
	End Method

	Rem
	bbdoc: Adds an automatically positioned action button and returns its zero-based index.
	End Rem
	Method AddButton:Int(label:String = "")
		Local button:TVirtualButton = New TVirtualButton
		button.label = label
		buttons :+ [button]
		InvalidateLayout()
		Return buttons.Length - 1
	End Method

	Rem
	bbdoc: Uses explicit native-overlay geometry and disables automatic layout.
	End Rem
	Method SetStick(x:Float, y:Float, radius:Float, knobRadius:Float, axes:Int = VIRTUAL_AXIS_XY)
		automaticLayout = False
		stick.axes = axes
		stick.SetPosition(x, y, radius, knobRadius)
	End Method

	Rem
	bbdoc: Uses explicit native-overlay geometry for an action button and disables automatic layout.
	End Rem
	Method SetButton(index:Int, x:Float, y:Float, radius:Float)
		If index < 0 Or index >= buttons.Length Then Throw "Max2D virtual joystick: button index out of range"
		automaticLayout = False
		buttons[index].centerX = x; buttons[index].centerY = y
		buttons[index].radius = Max(1.0, radius)
	End Method

	Method SetAutomaticLayout(value:Int = True)
		automaticLayout = value <> 0
		InvalidateLayout()
	End Method

	Method SetUIScale(scale:Float)
		uiScale = Max(0.1, scale)
		InvalidateLayout()
	End Method

	Rem
	bbdoc: Selects a horizontal, vertical, diagonal or compact-grid automatic button arrangement.
	about: Horizontal and vertical arrangements extend from the lower-right corner. The diagonal spans the bottom and right edges, while the grid uses two columns.
	End Rem
	Method SetButtonLayout(layout:Int)
		If layout < VIRTUAL_BUTTON_LAYOUT_HORIZONTAL Or layout > VIRTUAL_BUTTON_LAYOUT_GRID Then
			Throw "Max2D virtual joystick: unknown button layout"
		End If
		buttonLayout = layout
		InvalidateLayout()
	End Method

	Method InvalidateLayout()
		_safeWidth = -1; _safeHeight = -1
	End Method

	Rem
	bbdoc: Updates automatically positioned controls from the current window safe area.
	End Rem
	Method UpdateLayout()
		If Not automaticLayout Then Return
		Local x:Int, y:Int, width:Int, height:Int
		GetWindowSafeArea(x, y, width, height)
		If width <= 0 Or height <= 0 Then Return
		If x = _safeX And y = _safeY And width = _safeWidth And height = _safeHeight Then Return
		_safeX = x; _safeY = y; _safeWidth = width; _safeHeight = height
		Local scale:Float = Max(0.68, Min(1.8, Float(Min(width, height)) / 720.0)) * uiScale
		Local edge:Float = margin * scale
		Local stickRadius:Float = baseRadius * scale
		stick.SetPosition(x + edge + stickRadius, y + height - edge - stickRadius, stickRadius, knobRadius * scale)
		Local radius:Float = buttonRadius * scale
		Local spacing:Float = radius * 2 + buttonGap * scale
		For Local index:Int = 0 Until buttons.Length
			Local column:Int, row:Int
			Select buttonLayout
				Case VIRTUAL_BUTTON_LAYOUT_HORIZONTAL
					column = index
				Case VIRTUAL_BUTTON_LAYOUT_VERTICAL
					row = index
				Case VIRTUAL_BUTTON_LAYOUT_DIAGONAL
					column = buttons.Length - 1 - index
					row = index
				Case VIRTUAL_BUTTON_LAYOUT_GRID
					column = index Mod 2
					row = index / 2
			End Select
			buttons[index].centerX = x + width - edge - radius - column * spacing
			buttons[index].centerY = y + height - edge - radius - row * spacing
			buttons[index].radius = radius
		Next
	End Method

	Method Enable()
		If _hooked Then
			enabled = True
			Return
		End If
		AddHook EmitEventHook, EventHook, Self, 0
		_hooked = True
		enabled = True
	End Method

	Method Disable()
		enabled = False
		CancelTouches()
	End Method

	Method Free()
		If _freed Then Return
		If _hooked Then RemoveHook EmitEventHook, EventHook, Self
		_hooked = False
		CancelTouches()
		_driver.Remove(Self)
		_freed = True
	End Method

	Function EventHook:Object(id:Int, data:Object, context:Object)
		Local joystick:TVirtualJoystick = TVirtualJoystick(context)
		Local event:TEvent = TEvent(data)
		If joystick And event Then joystick.OnEvent(event)
		Return data
	End Function

	Method OnEvent(event:TEvent)
		If Not enabled Or _freed Then Return
		Select event.id
			Case EVENT_TOUCHDOWN, EVENT_TOUCHMOVE
				UpdateLayout()
				Local x:Float = NativeResolutionWidth() * event.x / 10000.0
				Local y:Float = NativeResolutionHeight() * event.y / 10000.0
				If event.id = EVENT_TOUCHDOWN Then
					TouchDown(event.data, x, y)
				Else
					TouchMove(event.data, x, y)
				End If
			Case EVENT_TOUCHUP
				TouchUp(event.data)
			Case EVENT_APPSUSPEND, EVENT_APPTERMINATE
				CancelTouches()
		End Select
	End Method

	Rem
	bbdoc: Begins a touch using native output coordinates and reports whether a control captured it.
	End Rem
	Method TouchDown:Int(id:Int, x:Float, y:Float)
		If Not enabled Then Return False
		UpdateLayout()
		If stick.TouchDown(id, x, y) Then Return True
		For Local button:TVirtualButton = EachIn buttons
			If button.TouchDown(id, x, y) Then Return True
		Next
		Return False
	End Method

	Method TouchMove:Int(id:Int, x:Float, y:Float)
		Return stick.Move(id, x, y)
	End Method

	Method TouchUp:Int(id:Int)
		If stick.TouchUp(id) Then Return True
		For Local button:TVirtualButton = EachIn buttons
			If button.TouchUp(id) Then Return True
		Next
		Return False
	End Method

	Method CancelTouches()
		stick.Cancel()
		For Local button:TVirtualButton = EachIn buttons
			button.Cancel()
		Next
	End Method

	Method X:Float()
		Return stick.X()
	End Method

	Method Y:Float()
		Return stick.Y()
	End Method

	Method ButtonDown:Int(index:Int)
		If index < 0 Or index >= buttons.Length Then Return False
		Return buttons[index].down
	End Method

	Method ButtonHit:Int(index:Int)
		If index < 0 Or index >= buttons.Length Then Return 0
		Return buttons[index].Hit()
	End Method

	Method Flush()
		For Local button:TVirtualButton = EachIn buttons
			button.hits = 0
		Next
	End Method

	Rem
	bbdoc: Explicitly makes the Max2D virtual joystick collection the Pub.Joystick source.
	about: This is optional. Direct X, Y, ButtonDown and ButtonHit methods coexist with physical joystick drivers without selecting this adapter.
	End Rem
	Method SelectJoystickDriver:TJoystickDriver()
		Return GetJoystickDriver(_driver.GetName())
	End Method

	Rem
	bbdoc: Draws the controls over the complete native window, including usable presentation bars.
	about: Drawing state and the previous render target are restored before returning.
	End Rem
	Method Render()
		If Not visible Or _freed Then Return
		UpdateLayout()
		PushMax2DState()
		SetRenderImage(Null)
		SetNativeResolution()
		SetCamera(Null)
		SetOrigin(0, 0)
		SetViewport(0, 0, NativeResolutionWidth(), NativeResolutionHeight())
		SetBlend(ALPHABLEND)
		Local stickAlpha:Float = idleAlpha
		If stick.touchId <> -1 Then stickAlpha = activeAlpha
		DrawControlCircle(stick.centerX, stick.centerY, stick.radius, baseRed, baseGreen, baseBlue, stickAlpha)
		DrawControlCircle(stick.centerX, stick.centerY, stick.radius * 0.78, 18, 25, 36, stickAlpha * 0.55)
		DrawControlCircle(stick.knobX, stick.knobY, stick.knobRadius, knobRed, knobGreen, knobBlue, stickAlpha)
		For Local button:TVirtualButton = EachIn buttons
			Local alpha:Float = idleAlpha
			If button.down Then alpha = activeAlpha
			DrawControlCircle(button.centerX, button.centerY, button.radius, buttonRed, buttonGreen, buttonBlue, alpha)
			DrawControlCircle(button.centerX, button.centerY, button.radius * 0.72, 18, 25, 36, alpha * 0.42)
		Next
		PopMax2DState()
	End Method
End Type

Private
Type TVirtualJoystickDriver Extends TJoystickDriver
	Field joysticks:TVirtualJoystick[] = New TVirtualJoystick[0]

	Method Add(joystick:TVirtualJoystick)
		joysticks :+ [joystick]
	End Method

	Method Remove(joystick:TVirtualJoystick)
		For Local index:Int = 0 Until joysticks.Length
			If joysticks[index] <> joystick Then Continue
			Local remaining:TVirtualJoystick[] = joysticks[..index]
			remaining :+ joysticks[index + 1..]
			joysticks = remaining
			Return
		Next
	End Method

	Method At:TVirtualJoystick(port:Int)
		If port < 0 Or port >= joysticks.Length Then Return Null
		Return joysticks[port]
	End Method

	Method GetName:String() Override
		Return "Max2D Virtual Joystick"
	End Method
	Method JoyCount:Int() Override
		Return joysticks.Length
	End Method
	Method JoyName:String(port:Int) Override
		Local joystick:TVirtualJoystick = At(port); If joystick Then Return joystick.name
	End Method
	Method JoyButtonCaps:Int(port:Int) Override
		Local joystick:TVirtualJoystick = At(port); If Not joystick Then Return 0
		Local result:Int
		For Local index:Int = 0 Until Min(joystick.buttons.Length, 32)
			result :| 1 Shl index
		Next
		Return result
	End Method
	Method JoyAxisCaps:Int(port:Int) Override
		Local joystick:TVirtualJoystick = At(port); If joystick Then Return joystick.stick.axes
	End Method
	Method JoyDown:Int(button:Int, port:Int = 0) Override
		Local joystick:TVirtualJoystick = At(port); If joystick Then Return joystick.ButtonDown(button)
	End Method
	Method JoyHit:Int(button:Int, port:Int = 0) Override
		Local joystick:TVirtualJoystick = At(port); If joystick Then Return joystick.ButtonHit(button)
	End Method
	Method JoyX:Float(port:Int = 0) Override
		Local joystick:TVirtualJoystick = At(port); If joystick Then Return joystick.X()
	End Method
	Method JoyY:Float(port:Int = 0) Override
		Local joystick:TVirtualJoystick = At(port); If joystick Then Return joystick.Y()
	End Method
	Method JoyZ:Float(port:Int = 0) Override; Return 0; End Method
	Method JoyR:Float(port:Int = 0) Override; Return 0; End Method
	Method JoyU:Float(port:Int = 0) Override; Return 0; End Method
	Method JoyV:Float(port:Int = 0) Override; Return 0; End Method
	Method JoyYaw:Float(port:Int = 0) Override; Return 0; End Method
	Method JoyPitch:Float(port:Int = 0) Override; Return 0; End Method
	Method JoyRoll:Float(port:Int = 0) Override; Return 0; End Method
	Method JoyHat:Float(port:Int = 0) Override; Return -1; End Method
	Method JoyWheel:Float(port:Int = 0) Override; Return 0; End Method
	Method JoyType:Int(port:Int = 0) Override; Return At(port) <> Null; End Method
	Method JoyXDir:Int(port:Int = 0) Override; Return Direction(JoyX(port)); End Method
	Method JoyYDir:Int(port:Int = 0) Override; Return Direction(JoyY(port)); End Method
	Method JoyZDir:Int(port:Int = 0) Override; Return 0; End Method
	Method JoyUDir:Int(port:Int = 0) Override; Return 0; End Method
	Method JoyVDir:Int(port:Int = 0) Override; Return 0; End Method
	Method FlushJoy(portMask:Int = ~0) Override
		For Local index:Int = 0 Until Min(joysticks.Length, 32)
			If portMask & (1 Shl index) Then joysticks[index].Flush()
		Next
	End Method
	Method Direction:Int(value:Float)
		If value < -0.333333 Then Return -1
		If value > 0.333333 Then Return 1
		Return 0
	End Method
End Type
