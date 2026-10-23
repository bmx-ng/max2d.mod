SuperStrict

Framework Max2D.SDL3RenderMax2D
Import Max2D.VirtualJoystick
Import BRL.StandardIO

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function

Graphics 640, 480, 0
SetVirtualResolution(320, 240, VIRTUAL_LETTERBOX)
Local controls:TVirtualJoystick = TVirtualJoystick.Create(0)
controls.UpdateLayout()
Local sx:Int, sy:Int, sw:Int, sh:Int
GetWindowSafeArea(sx, sy, sw, sh)
Local x:Float = sx + sw * 0.25
Local y:Float = sy + sh * 0.25
Check(Not controls.TouchDown(1, sx + sw * 0.75, y), "Default area excludes right side")
Check(Not controls.TouchDown(1, sx - 1, y), "Default area excludes unsafe left inset")
Check(Not controls.TouchDown(1, x, sy + sh), "Default area excludes bottom boundary")
EmitEvent(TEvent.Create(EVENT_TOUCHDOWN, Null, 1, 0, Int(x * 10000 / NativeResolutionWidth()), Int(y * 10000 / NativeResolutionHeight())))
Check(controls.stick.touchId = 1, "Touch event captures default floating stick")
Check(Abs(controls.stick.centerX - x) < 1 And Abs(controls.stick.centerY - y) < 1, "Touch maps to native coordinates")
Check(controls.X() = 0 And controls.Y() = 0, "Event touchdown is neutral")
controls.Render()
Check(controls.stick.touchId = 1, "Rendering does not release active stick")
EmitEvent(TEvent.Create(EVENT_TOUCHUP, Null, 1))
Check(controls.stick.touchId = -1, "Touch release event clears stick")
SetClsColor(10, 20, 30)
Cls
controls.Render()
Local pixel:TPixmap = GrabPixmap(Int(x), Int(y), 1, 1)
Check((pixel.ReadPixel(0, 0) & $FFFFFF) = $0A141E, "Idle floating stick is hidden")
controls.TouchDown(2, x, y)
controls.SetUIScale(1.1)
controls.UpdateLayout()
Check(controls.stick.touchId = -1, "Layout change cancels floating gesture")
controls.Free()
EndGraphics()
Print "Max2D floating joystick window tests passed"
