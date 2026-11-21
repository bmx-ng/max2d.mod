SuperStrict
Framework Max2D.Core
Import Max2D.VirtualJoystick
Import BRL.StandardIO
Include "model.bmx"
Include "input.bmx"
Function Check(value:Int,message:String)
 If Not value Then Throw message
End Function
Local c:TVirtualJoystick=TVirtualJoystick.Create(3)
c.SetStickActivationArea(0,0,500,500)
c.SetStick(100,100,50,20)
c.SetButton(0,600,400,32); c.SetButton(1,680,400,32); c.SetButton(2,760,400,32)
Local g:TAfterlight=New TAfterlight
g.LoadRoom(1)
Local dx:Int,dy:Int
Check(c.TouchDown(10,100,100),"Floating stick capture")
ResolveDirection(0,0,c.X(),c.Y(),dx,dy)
Check(dx=0 And dy=0,"Initial touch must not move")
c.TouchMove(10,150,100)
ResolveDirection(0,0,c.X(),c.Y(),dx,dy); g.Move(dx,dy)
Check(g.px=3 And g.py=7,"Touch moved right")
c.TouchMove(10,100,50)
ResolveDirection(0,0,c.X(),c.Y(),dx,dy); g.Move(dx,dy); g.Move(dx,dy)
Check(g.bx=3 And g.by=4,"Touch pushes battery into socket")
Check(c.TouchDown(20,680,400),"Second finger captures undo")
If c.ButtonHit(1) Then g.Undo()
Check(g.by=5,"Touch undo restores battery")
Check(Not c.ButtonHit(1),"Button hit consumed exactly once")
c.TouchUp(20); c.TouchUp(10)
ResolveDirection(0,0,c.X(),c.Y(),dx,dy)
Check(dx=0 And dy=0,"Lifting finger stops movement")
g.px=7; g.py=5
Check(c.TouchDown(30,600,400),"Action button capture")
If c.ButtonHit(0) Then g.Act()
Check(g.mirror[0]=1,"Touch rotates mirror")
c.CancelTouches()
Check(Not c.ButtonDown(0) And c.X()=0 And c.Y()=0,"Cancelled touches release controls")
ResolveDirection(1,1,0,0,dx,dy)
Check(dx=1 And dy=0,"Keyboard diagonal resolves to a cardinal step")
c.Free()
Print "PASS: floating joystick, battery pushing, multitouch undo, action, release and cancellation"
