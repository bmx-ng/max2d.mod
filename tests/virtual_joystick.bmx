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
controls.SetStick(100, 100, 50, 20)
controls.SetButton(0, 240, 100, 30)
controls.SetButton(1, 310, 100, 30)

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

controls.stick.axes = VIRTUAL_AXIS_X
Check(controls.TouchDown(40, 100, 125), "X-only stick captures")
Near(controls.X(), 0.0, "X-only stick X")
Near(controls.Y(), 0.0, "Disabled Y axis")
controls.CancelTouches()
Check(Not controls.ButtonDown(1), "Cancelling clears all buttons")

controls.Free()
Print "Max2D virtual joystick tests passed"
