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

## Input choices

Direct queries—`X`, `Y`, `ButtonDown` and `ButtonHit`—are the recommended API.
They coexist with a physical controller selected through `Pub.Joystick`.

For older code that expects the `Pub.Joystick` functions, call
`controls.SelectJoystickDriver()` explicitly. This changes the global joystick
driver, so the virtual and physical sources are not combined by that adapter.

The control installs its touch-event hook when created. Call `Free` when the
control is no longer needed, especially if controls are recreated between game
screens.
