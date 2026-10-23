# Virtual joystick

`Max2D.VirtualJoystick` provides an analogue stick and onscreen action buttons for
touch-oriented Max2D games. It listens to BlitzMax touch events, so the control is
not coupled to a particular window or rendering backend.

```blitzmax
Framework Max2D.SDL3RenderMax2D
Import Max2D.VirtualJoystick

Graphics 1280, 720, 0, 0, GRAPHICS_FULLSCREEN_DESKTOP
SetVirtualResolution 480, 270, VIRTUAL_LETTERBOX

Local controls:TVirtualJoystick = TVirtualJoystick.Create(2)
controls.SetButtonLayout VIRTUAL_BUTTON_LAYOUT_DIAGONAL

While Not AppTerminate()
	' Update the game in virtual scene coordinates.
	playerX :+ controls.X() * speed
	If controls.ButtonHit(0) Then Fire()

	Cls
	DrawGame()

	' Render last, above the scene and its presentation bars.
	controls.Render()
	Flip
Wend

controls.Free()
```

## Floating and fixed sticks

By default, touch anywhere in the **left half of the window's safe area** to
place the stick beneath your thumb. The initial touch gives neutral input; drag
to move. The centre stays at that initial position until you lift your finger,
then the stick disappears. The next touch chooses a new centre.

A second finger can operate the action buttons without moving the stick's
centre. Buttons take priority if their circles overlap the activation area.
Once captured, the stick follows its finger even outside the activation area,
with output clamped to the normal range.

To retain the original, always-visible fixed stick:

```blitzmax
controls.SetStickFloating(False)
```

For a different activation rectangle, supply native output pixel coordinates:

```blitzmax
controls.SetStickActivationArea(0, 200, 600, 500)
```

`ResetStickActivationArea()` restores the automatic left-half safe area. A custom
area does not disable automatic button layout; update it yourself when the window
changes. Switching modes or activation areas releases the current stick touch.
Automatic layout changes (including rotation/resizing) also release a floating
stick, preventing its centre from jumping during the gesture.

`SetStick` sets the fixed home position and the radius used by both modes; it does
not turn off floating mode. Near an activation-area edge, the floating circle may
extend outside that area or be clipped by the window: its centre remains exactly
where the thumb landed.

## Layout and coordinates

The automatic layout uses the platform's safe interactive area. Controls avoid
display cutouts and system-reserved insets, but are otherwise allowed to occupy
the complete native window—including letterbox or pillarbox bars. This keeps the
game scene unobstructed and makes control size independent of the virtual scene's
scale.

Control geometry is expressed in native output pixels. Call `SetUIScale` to tune
the automatic size. `SetButtonLayout` accepts
`VIRTUAL_BUTTON_LAYOUT_HORIZONTAL`, `VIRTUAL_BUTTON_LAYOUT_VERTICAL`,
`VIRTUAL_BUTTON_LAYOUT_DIAGONAL` or `VIRTUAL_BUTTON_LAYOUT_GRID`. Button zero is
the primary button. Horizontal and vertical arrangements extend from the
lower-right corner. The diagonal arrangement spans the bottom and right edges,
keeping a two-button cluster out of the playfield, and is the default. Grid uses
two columns.

Use `SetStick` and `SetButton` for completely explicit positions. An explicit
position disables automatic layout until `SetAutomaticLayout(True)` is called.

`Render` saves and restores Max2D drawing state. Its circular geometry is cached,
so rendering does not rebuild trigonometric shape data each frame.

## Custom rendering

Input handling does not depend on `Render()`. You can omit that call and draw
sprites, meshes, outlines or animations using the exposed control state. The
built-in renderer also has configurable colours, idle/active opacity, radii and
button labels.

For example, this draws a simple alternative skin without changing input:

```blitzmax
Function DrawCustomControls(controls:TVirtualJoystick)
	If Not controls.visible Then Return
	controls.UpdateLayout()
	PushMax2DState()
	SetRenderImage(Null)
	SetNativeResolution()
	SetCamera(Null)
	SetOrigin(0, 0)
	SetTransform(0, 1, 1)
	SetHandle(0, 0)
	SetViewport(0, 0, NativeResolutionWidth(), NativeResolutionHeight())
	SetBlend(ALPHABLEND)

	Local stick:TVirtualStick = controls.stick
	If controls.stickEnabled And (Not controls.floatingStick Or stick.touchId <> -1) Then
		SetColor(255, 255, 255, 0.25)
		DrawOval(stick.centerX - stick.radius, stick.centerY - stick.radius, stick.radius * 2, stick.radius * 2)
		SetColor(80, 200, 255, 0.9)
		DrawOval(stick.knobX - stick.knobRadius, stick.knobY - stick.knobRadius, stick.knobRadius * 2, stick.knobRadius * 2)
	End If

	For Local button:TVirtualButton = EachIn controls.buttons
		If button.down Then SetColor(255, 200, 80) Else SetColor(180, 180, 200)
		DrawOval(button.centerX - button.radius, button.centerY - button.radius, button.radius * 2, button.radius * 2)
	Next
	PopMax2DState()
End Function
```

Replace the drawing calls with your artwork as needed. `centerX`/`centerY` and
`knobX`/`knobY` are centres in native output pixels, not scene/world coordinates.
Changing artwork does not change input geometry: buttons use circular hit areas,
and floating sticks start within their configured activation rectangle.

Hiding controls with `visible = False` only affects drawing; call `Disable()` to
stop input and release owned touches. A custom renderer should honour `visible`
itself, as the example above does.

## Input choices

Direct queries—`X`, `Y`, `ButtonDown` and `ButtonHit`—are the recommended API.
They coexist with a physical controller selected through `Pub.Joystick`.

For older code that expects the `Pub.Joystick` functions, call
`controls.SelectJoystickDriver()` explicitly. This changes the global joystick
driver, so the virtual and physical sources are not combined by that adapter.

The control installs its touch-event hook when created. Call `Free` when the
control is no longer needed, especially if controls are recreated between game
screens.
