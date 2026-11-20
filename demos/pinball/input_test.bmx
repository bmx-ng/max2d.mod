SuperStrict
Framework Max2D.Core
Import Max2D.VirtualJoystick
Import BRL.StandardIO
Include "input.bmx"
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Local c:TPinControls=New TPinControls
c.Layout(1000,880)
Check(c.TouchDown(1,180,836),"Left flipper touch")
Check(c.TouchDown(2,405,836),"Right flipper touch")
Check(c.ButtonDown(0) And c.ButtonDown(1),"Both flippers must hold independently")
c.TouchUp(1)
Check(Not c.ButtonDown(0) And c.ButtonDown(1),"Lifting left must preserve right")
Check(c.TouchDown(3,575,595),"Launcher rectangle corner must accept touch")
Check(c.ButtonHit(2)=1 And c.ButtonHit(2)=0,"Launcher hit must be consumed once")
c.TouchUp(3)
Check(Not c.ButtonDown(2),"Launcher releases")
Check(c.TouchDown(4,910,760),"Pause rectangle edge")
Check(c.ButtonHit(3)=1,"Pause hit")
c.CancelTouches()
For Local i:Int=0 Until 4
 Check(Not c.ButtonDown(i),"Cancel clears held input")
Next
c.Layout(2000,1760)
Check(c.TouchDown(5,360,1672),"High DPI left flipper touch")
c.TouchUp(5)
c.Layout(1400,880)
Check(c.TouchDown(6,380,836),"Letterbox offset touch")
c.TouchUp(6)
Check(Not c.TouchDown(7,180,836),"Letterbox bar must not activate a flipper")
c.Free()
Print "PASS: independent flippers, rectangular launcher/pause, release, high DPI and letterboxing"
