SuperStrict

Framework Max2D.Core
Import Max2D.VirtualJoystick
Import BRL.StandardIO

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function

Function Near(actual:Float, expected:Float, message:String)
	Check(Abs(actual - expected) < 0.001, message + ": " + actual + " / " + expected)
End Function

Local controls:TVirtualJoystick = TVirtualJoystick.Create(2, "Test controls")
controls.SetButtonLayout(VIRTUAL_BUTTON_LAYOUT_HORIZONTAL)
controls.SetButtonLayout(VIRTUAL_BUTTON_LAYOUT_VERTICAL)
controls.SetButtonLayout(VIRTUAL_BUTTON_LAYOUT_DIAGONAL)
controls.SetButtonLayout(VIRTUAL_BUTTON_LAYOUT_GRID)
Local rejectedLayout:Int
Try
	controls.SetButtonLayout(99)
Catch error:Object
	rejectedLayout = True
End Try
Check(rejectedLayout, "Unknown automatic layout is rejected")
controls.SetStickFloating(False)
controls.SetStick(100, 100, 50, 20)
controls.SetButton(0, 240, 100, 30)
controls.SetButton(1, 310, 100, 30)
controls.SetButtonLabel(0, "LEFT")
Check(controls.buttons[0].label = "LEFT", "Button label is configurable")

Check(controls.TouchDown(10, 125, 75), "Stick captures a touch")
Near(controls.X(), 0.5, "Stick X")
Near(controls.Y(), -0.5, "Stick Y")
Check(controls.TouchMove(10, 200, 100), "Captured stick moves")
Near(controls.X(), 1.0, "Stick clamps to its radius")
Near(controls.Y(), 0.0, "Clamped stick Y")

Check(controls.TouchDown(20, 240, 100), "First button captures a second touch")
Check(controls.ButtonDown(0), "First button is down")
Check(controls.ButtonHit(0) = 1, "First button reports one hit")
Check(controls.ButtonHit(0) = 0, "Button hits are consumed")
Check(controls.TouchDown(30, 310, 100), "Second button supports multitouch")
Check(controls.ButtonDown(1), "Second button is down")

Check(controls.TouchUp(10), "Stick releases")
Near(controls.X(), 0.0, "Released stick X")
Near(controls.Y(), 0.0, "Released stick Y")
Check(controls.TouchUp(20), "First button releases")
Check(Not controls.ButtonDown(0), "First button is up")

controls.SetStickEnabled(False)
Check(Not controls.TouchDown(35, 100, 100), "Disabled stick does not capture touches")
Near(controls.X(), 0.0, "Disabled stick X")
Near(controls.Y(), 0.0, "Disabled stick Y")
controls.SetStickEnabled(True)

controls.stick.axes = VIRTUAL_AXIS_X
Check(controls.TouchDown(40, 100, 125), "X-only stick captures")
Near(controls.X(), 0.0, "X-only stick X")
Near(controls.Y(), 0.0, "Disabled Y axis")
controls.CancelTouches()
Check(Not controls.ButtonDown(1), "Cancelling clears all buttons")

controls.Free()

Local floating:TVirtualJoystick = TVirtualJoystick.Create(1)
Check(floating.floatingStick, "Floating mode is the default")
floating.SetStick(100, 100, 50, 20)
floating.SetStickActivationArea(20, 30, 300, 400)
floating.SetButton(0, 240, 100, 30)
Check(Not floating.TouchDown(1, 19, 80), "Outside activation area is ignored")
Check(Not floating.TouchDown(1, 320, 80), "Activation right edge is excluded")
Check(floating.TouchDown(1, 40, 200), "Floating stick activates away from its home circle")
Near(floating.stick.centerX, 40, "Floating centre X")
Near(floating.stick.centerY, 200, "Floating centre Y")
Near(floating.X(), 0, "Initial floating X is neutral")
Near(floating.Y(), 0, "Initial floating Y is neutral")
Check(Not floating.TouchDown(2, 100, 200), "Another finger cannot relocate the stick")
Check(Not floating.TouchDown(1, 240, 100), "Owned touch cannot also capture a button")
Check(Not floating.TouchMove(2, 10, 10), "Unowned movement is ignored")
Check(floating.TouchMove(1, 500, 200), "Owned touch moves beyond activation area")
Near(floating.X(), 1, "Floating output clamps")
Near(floating.stick.centerX, 40, "Dragging leaves centre anchored")
Check(floating.TouchDown(2, 240, 100), "Buttons remain available during stick drag")
Check(Not floating.TouchUp(3), "Unowned release is ignored")
Check(floating.TouchUp(1), "Floating touch releases")
Near(floating.X(), 0, "Released floating output is neutral")
Check(Not floating.TouchDown(3, 240, 100), "Occupied button area does not activate stick")
floating.TouchUp(2)
Check(floating.TouchDown(3, 240, 100), "Button takes priority over floating area")
Check(floating.stick.touchId = -1, "Button touch does not capture stick")
floating.TouchUp(3)
Check(floating.TouchDown(4, 80, 300), "Next gesture chooses a new centre")
Near(floating.stick.centerY, 300, "New gesture centre")
floating.SetStickFloating(False)
Check(floating.stick.touchId = -1, "Mode change releases touch")
Near(floating.stick.centerX, 100, "Fixed mode restores configured position")
Check(Not floating.TouchDown(5, 80, 300), "Fixed mode rejects distant touches")
Check(floating.TouchDown(5, 125, 100), "Fixed mode still uses original circle")
Near(floating.X(), 0.5, "Fixed initial displacement retained")
floating.SetStickFloating()
floating.stick.axes = VIRTUAL_AXIS_X
floating.TouchDown(6, 60, 200)
floating.TouchMove(6, 60, 250)
Near(floating.Y(), 0, "Floating axis restriction")
floating.Disable()
Check(floating.stick.touchId = -1, "Disable releases floating stick")
Near(floating.Y(), 0, "Disable clears output")
floating.Enable()
floating.TouchDown(7, 60, 200)
floating.OnEvent(TEvent.Create(EVENT_APPSUSPEND))
Check(floating.stick.touchId = -1, "Suspend releases floating touch")
floating.Free()
Print "Max2D virtual joystick tests passed"
