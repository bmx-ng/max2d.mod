SuperStrict
Framework Physics.Box2D
Import BRL.StandardIO
Import BRL.Math
Include "physics.bmx"
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Local t:TPinTable=New TPinTable
' The actual launcher must deliver the ball into the playfield.
t.charge=0.7; t.Launch()
Local entered:Int
For Local i:Int=0 Until 480
 t.Tick(False,False)
 Local p:b2Vec2=t.ball.GetPosition()
 If p.GetX()<10 And p.GetY()<10 Then entered=True
Next
Check(entered,"Launcher failed to enter playfield")
Check(t.gateClosed,"Launch gate did not close")
t.ball.SetXForm(New b2Vec2.Create(11.25,3.3),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,30))
For Local i:Int=0 Until 12
 t.Tick(False,False)
 Check(t.ball.GetPosition().GetY()<3.8,"Ball returned through launch gate")
Next
t.Spawn()
Check(Not t.gateClosed,"New ball did not reopen gate")
Print "PASS launch lane and one-way gate"
For Local i:Int=0 Until 12
 t.Tick(True,True)
Next
Check(Abs(t.joint[0].GetJointAngle())>44 And Abs(t.joint[1].GetJointAngle())>44,"Flippers did not rise within 100 ms")
Print "PASS fast flipper rise"
For Local i:Int=0 Until 90
 t.Tick(True,True)
Next
Print "Angles: "+t.joint[0].GetJointAngle()+", "+t.joint[1].GetJointAngle()
Check(t.joint[0].GetJointAngle() < -44 And t.joint[0].GetJointAngle()>-52,"Left flipper raised angle")
Check(t.joint[1].GetJointAngle() > 44 And t.joint[1].GetJointAngle()<52,"Right flipper raised angle")
For Local i:Int=0 Until 90
 t.Tick(False,False)
Next
Check(Abs(t.joint[0].GetJointAngle())<3 And Abs(t.joint[1].GetJointAngle())<3,"Flippers return")
Print "PASS motor limits and return"
' Fast ball must hit a thin rail rather than escape through it.
t.waiting=False; t.gameOver=False; t.saveTime=0
t.ball.SetXForm(New b2Vec2.Create(2,10),0); t.ball.SetLinearVelocity(New b2Vec2.Create(-30,0))
For Local i:Int=0 Until 30
 t.Tick(False,False)
 Check(t.ball.GetPosition().GetX()>0.7,"Ball tunneled through rail")
Next
Print "PASS fast rail collision"
' Contact-driven scoring and kick, with no fabricated callback.
Local before:Int=t.score
t.ball.SetXForm(New b2Vec2.Create(3.3,3.5),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,10))
For Local i:Int=0 Until 20
 t.Tick(False,False)
Next
Check(t.score>before,"Bumper contact did not score")
Check(t.ball.GetLinearVelocity().GetY()<0,"Bumper failed to kick ball outwards")
Print "PASS bumper scoring and impulse"
' Flipper strikes should impart upward momentum to a resting incoming ball.
For Local i:Int=0 Until 60
 t.Tick(False,False)
Next
t.ball.SetXForm(New b2Vec2.Create(4.7,17.0),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,1))
Local upward:Float
For Local i:Int=0 Until 25
 t.Tick(True,False)
 upward=Min(upward,t.ball.GetLinearVelocity().GetY())
Next
Check(upward < -12,"Flipper does not launch ball upwards")
Print "PASS flipper strike (upward velocity "+upward+")"
t.balls=1; t.waiting=False; t.saveTime=0
t.ball.SetXForm(New b2Vec2.Create(6,21),0); t.Tick(False,False)
Check(t.gameOver And t.balls=0,"Final drain did not end game")
t.Free()
Print "PASS drain and cleanup"
' Deterministic two-minute soak: exercise repeated games, motor reversals and
' collision response without tying the simulation to a display refresh rate.
t=New TPinTable
Local totalHits:Int
For Local tick:Int=0 Until 14400
 If t.gameOver Then totalHits:+t.hits; t.Free(); t=New TPinTable
 If t.waiting Then t.charge=0.7; t.Launch()
 Local p:b2Vec2=t.ball.GetPosition()
 t.Tick(p.GetY()>15 And p.GetX()<6 And (tick Mod 100)<35,p.GetY()>15 And p.GetX()>=6 And (tick Mod 100)<35)
 p=t.ball.GetPosition()
 Check(p.GetX()=p.GetX() And p.GetY()=p.GetY(),"Non-finite ball position")
 Check(p.GetX()>0 And p.GetX()<12.5,"Ball escaped side rails")
Next
totalHits:+t.hits
Print "Soak state: hits="+totalHits+" ball="+t.ball.GetPosition().GetX()+","+t.ball.GetPosition().GetY()+" velocity="+t.ball.GetLinearVelocity().GetX()+","+t.ball.GetLinearVelocity().GetY()
Check(totalHits>10,"Soak did not exercise table contacts")
t.Free()
Print "PASS two-minute physics soak: "+totalHits+" contacts"
