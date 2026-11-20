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
t.ball.SetXForm(New b2Vec2.Create(2,6),0); t.ball.SetLinearVelocity(New b2Vec2.Create(-30,0))
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
t.ball.SetXForm(New b2Vec2.Create(4.7,FLIPPER_Y),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,1))
Local upward:Float
For Local i:Int=0 Until 25
 t.Tick(True,False)
 upward=Min(upward,t.ball.GetLinearVelocity().GetY())
Next
Check(upward < -12,"Flipper does not launch ball upwards")
Print "PASS flipper strike (upward velocity "+upward+")"
t.balls=1; t.waiting=False; t.saveTime=0
t.ball.SetXForm(New b2Vec2.Create(6,23),0); t.Tick(False,False)
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
 t.Tick(p.GetY()>FLIPPER_Y-2 And p.GetX()<6 And (tick Mod 100)<35,p.GetY()>FLIPPER_Y-2 And p.GetX()>=6 And (tick Mod 100)<35)
 p=t.ball.GetPosition()
 Check(p.GetX()=p.GetX() And p.GetY()=p.GetY(),"Non-finite ball position")
 Check(p.GetX()>0 And p.GetX()<12.5,"Ball escaped side rails")
Next
totalHits:+t.hits
Print "Soak state: hits="+totalHits+" ball="+t.ball.GetPosition().GetX()+","+t.ball.GetPosition().GetY()+" velocity="+t.ball.GetLinearVelocity().GetX()+","+t.ball.GetLinearVelocity().GetY()
Check(totalHits>10,"Soak did not exercise table contacts")
t.Free()
Print "PASS two-minute physics soak: "+totalHits+" contacts"

' Strike both slingshots on the active face, the back, and the bottom end cap.
For Local side:Int=0 Until 2
 For Local surface:Int=0 Until 3
  t=New TPinTable; t.waiting=False; t.saveTime=0
  Local sign:Float=1,cx:Float=2.75,cy:Float=14.1,nx:Float=0.8661856,ny:Float=-0.4997225
  If side=1 Then sign=-1; cx=8.85
  nx:*sign
  If surface=1 Then nx=-nx; ny=-ny
  If surface=2 Then cx=3.5; cy=15.4; nx=0.4997225; ny=0.8661856
  If surface=2 And side=1 Then cx=8.1; nx=-nx
  t.ball.SetXForm(New b2Vec2.Create(cx+nx*0.7,cy+ny*0.7),0)
  t.ball.SetLinearVelocity(New b2Vec2.Create(-nx*6,-ny*6))
  Local touched:Int
  For Local i:Int=0 Until 12
   t.Tick(False,False)
   If t.hits>0 Then touched=True
  Next
  Local v:b2Vec2=t.ball.GetLinearVelocity()
  If surface=0 Then
   Check(touched And v.GetX()*nx+v.GetY()*ny>10,"Slingshot face failed to kick")
  Else
   Check(Not touched And t.score=0,"Slingshot back or cap awarded a hit")
   Check(v.GetX()*nx+v.GetY()*ny<2,"Slingshot back or cap bounced the ball")
  End If
  t.Free()
 Next
Next
Print "PASS both slingshot faces, backs and bottom caps"

t=New TPinTable; t.waiting=False
For Local i:Int=0 Until 3
 t.ball.SetXForm(New b2Vec2.Create(3.4+i*2.2,2.5),0)
 t.ball.SetLinearVelocity(New b2Vec2.Create(0,0)); t.Tick(False,False)
 Local earned:Int=t.score
 For Local j:Int=0 Until 5
  t.Tick(False,False)
 Next
 Check(t.score=earned,"Rollover repeated while occupied")
Next
Check(t.jackpotTime>14 And t.score=450,"Rollover bank did not arm jackpot")
t.ball.SetXForm(New b2Vec2.Create(5.6,11),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,0)); t.Tick(False,False)
Check(t.jackpots=1 And t.score=1450 And t.jackpotTime=0,"Jackpot collection")
For Local i:Int=0 Until 5
 t.Tick(False,False)
Next
Check(t.score=1450,"Jackpot awarded twice")
t.jackpotTime=PHYSICS_DT; t.Tick(False,False); t.Tick(False,False)
Check(t.jackpotTime=0 And t.jackpots=1,"Jackpot expiry")
' Explicitly exercise a segment that crosses a switch between sample points.
t.previousX=2.5; t.previousY=2.5; t.ball.SetXForm(New b2Vec2.Create(4.3,2.5),0)
Check(t.Crossed(3.4,2.5,0.55),"Swept rollover missed")
t.Free()
Print "PASS rollover bank, jackpot collection, expiry and swept switches"

' Charge with real core collisions; the activation shot is separate.
t=New TPinTable; t.waiting=False
For Local shot:Int=0 Until 3
 t.targets[0].cooldown=0
 t.ball.SetXForm(New b2Vec2.Create(3.3,3.5),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,10))
 For Local i:Int=0 Until 20
  t.Tick(False,False)
 Next
Next
Check(t.forgeCharge=3 And Not t.forgeOpen,"Forge must charge before opening")
' Closed shutter blocks entry.
t.ball.SetXForm(New b2Vec2.Create(2.8,8.8),0); t.ball.SetLinearVelocity(New b2Vec2.Create(-10,0))
For Local i:Int=0 Until 10
 t.Tick(False,False)
 Check(t.ball.GetPosition().GetX()>2.2,"Closed Forge shutter allowed entry")
Next
t.ball.SetXForm(New b2Vec2.Create(3.2,10.9),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,0)); t.Tick(False,False)
Check(t.forgeOpen And t.forgeTime>24,"Forge activation shot")
Local forgeStartScore:Int=t.score
For Local target:Int=0 Until 3
 t.ball.SetXForm(New b2Vec2.Create(2.8,7.6+target*1.2),0); t.ball.SetLinearVelocity(New b2Vec2.Create(-10,0))
 For Local i:Int=0 Until 18
  t.Tick(False,False)
 Next
Next
Check(t.forgeMask=7 And t.forgeCells=1 And t.score=forgeStartScore+2750,"Forge target bank completion")
t.HitForge(0)
Check(t.score=forgeStartScore+2750,"Completed Forge awarded twice")
' Do not close the exit around a ball still in the bay.
t.forgeTime=0; t.SetForgeGate(True)
t.ball.SetXForm(New b2Vec2.Create(1.7,9.4),0); t.UpdateForge()
Check(t.forgeOpen,"Forge trapped ball after completion")
t.ball.SetXForm(New b2Vec2.Create(3,9.4),0); t.UpdateForge()
Check(Not t.forgeOpen,"Forge failed to close once clear")
t.forgeTime=PHYSICS_DT; t.SetForgeGate(True); t.UpdateForge(); t.UpdateForge()
Check(t.forgeTime=0 And Not t.forgeOpen And t.forgeCells=1,"Forge timeout")
t.forgeTime=10; t.SetForgeGate(True); t.Spawn()
Check(t.forgeTime=0 And Not t.forgeOpen And t.forgeCells=1,"Forge drain reset must preserve earned cells")
t.Free()
Print "PASS Forge charge, activation, shutter, target bank, safe closure and reset"

' A stationary ball on each former horizontal ledge must roll out unaided.
For Local ledge:Int=0 Until 2
 t=New TPinTable; t.waiting=False; t.saveTime=0
 Local x:Float=1.3,y:Float=6.1
 If ledge=1 Then y=9.5; t.SetForgeGate(True); t.forgeTime=10
 t.ball.SetXForm(New b2Vec2.Create(x,y),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,0))
 Local escaped:Int
 For Local i:Int=0 Until 360
  t.Tick(False,False)
  If t.ball.GetPosition().GetX()>2.5 Or (ledge=1 And t.ball.GetPosition().GetY()>11.9) Then escaped=True
 Next
 Check(escaped,"Ball stuck on Forge ledge "+ledge)
 t.Free()
Next
t=New TPinTable; t.waiting=False; t.saveTime=0; t.SetGate(True)
t.ball.SetXForm(New b2Vec2.Create(11.25,3.1),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,0))
Local leftLane:Int
For Local i:Int=0 Until 360
 t.Tick(False,False)
 If t.ball.GetPosition().GetX()<10.2 Then leftLane=True
Next
Check(leftLane,"Ball stuck on launch gate")
t.Free()
Print "PASS stationary balls roll off Forge ledges and launch gate"

' Keep the Forge open throughout: its timeout must not be the escape route.
For Local seed:Int=0 Until 40
 t=New TPinTable; t.waiting=False; t.saveTime=0
 t.SetForgeGate(True); t.forgeTime=100; t.forgeMask=7
 Local vx:Float=-12+Float(seed Mod 8)*3,vy:Float=-6+Float(seed/8)*3
 t.ball.SetXForm(New b2Vec2.Create(3,11),0); t.ball.SetLinearVelocity(New b2Vec2.Create(vx,vy))
 Local returned:Int
 For Local tick:Int=0 Until 960
  t.Tick(False,False)
  If t.ball.GetPosition().GetY()>FLIPPER_Y-1.3 Then returned=True; Exit
 Next
 Check(returned,"Open Forge orbit did not return to flippers: "+seed)
 Check(t.forgeOpen And t.forgeTime>90,"Orbit escaped by closing the Forge")
 t.Free()
Next
' A real flipper contact restores the normal sling kick for the next shot.
t=New TPinTable; t.waiting=False; t.slingChain=7
t.ball.SetXForm(New b2Vec2.Create(4.7,FLIPPER_Y),0); t.ball.SetLinearVelocity(New b2Vec2.Create(0,1))
For Local i:Int=0 Until 12
 t.Tick(True,False)
Next
Check(t.slingChain=0,"Flipper contact did not restore slingshots")
t.Free()
Print "PASS 40 open-Forge orbit escapes and flipper reset"

' The lower-left outlet stays open until a departing ball has cleared it.
t=New TPinTable; t.waiting=False; t.SetForgeGate(True)
t.ball.SetXForm(New b2Vec2.Create(1.1,11.2),0); t.UpdateForge()
Check(t.forgeOpen,"Forge outlet closed on departing ball")
t.ball.SetXForm(New b2Vec2.Create(1.1,12),0); t.UpdateForge()
Check(Not t.forgeOpen,"Forge outlet did not close after ball cleared")
t.Free()
Print "PASS Forge lower-left outlet clearance"

' Real downward passages through all four safe lanes complete a word once.
t=New TPinTable; t.waiting=False
For Local lane:Int=0 Until 4
 If lane>0 Then t.SetLaneControls(False,True); t.SetLaneControls(False,False)
 t.ball.SetXForm(New b2Vec2.Create(t.laneX[lane],LETTER_LANE_Y-0.3),0)
 t.ball.SetLinearVelocity(New b2Vec2.Create(0,6))
 For Local i:Int=0 Until 8
  t.Tick(False,False)
 Next
 If lane<3 Then Check(t.letterMask=(1 Shl (lane+1))-1,"Letter lane did not light: "+lane)
Next
Check(t.wordsCompleted=1 And t.letterMask=0 And t.score=1000,"FLUX word reward/reset")
' Upward crossings and stationary balls cannot score.
t.previousX=t.laneX[0]; t.previousY=LETTER_LANE_Y+0.3; t.ball.SetXForm(New b2Vec2.Create(t.laneX[0],LETTER_LANE_Y-0.3),0)
t.UpdateLetterLanes(); Check(t.letterMask=0,"Upward lane crossing scored")
t.previousY=LETTER_LANE_Y; t.ball.SetXForm(New b2Vec2.Create(t.laneX[0],LETTER_LANE_Y),0)
t.UpdateLetterLanes(); Check(t.letterMask=0,"Stationary lane scored")
t.selectedLetter=0
' Swept crossings still light a lane even when both samples are far away.
t.previousY=LETTER_LANE_Y-0.8; t.ball.SetXForm(New b2Vec2.Create(t.laneX[0],LETTER_LANE_Y+0.7),0)
t.UpdateLetterLanes(); Check(t.letterMask=1,"Fast lane crossing missed")
t.UpdateLetterLanes(); Check(t.letterMask=1 And t.score=1000,"Lit lane repeated bonus")
' Left/right move only the selection; collected letters stay put.
t.SetLaneControls(True,False); Check(t.selectedLetter=3 And t.letterMask=1,"Left selection wrap must preserve collected letters")
t.SetLaneControls(True,False); Check(t.selectedLetter=3,"Held flipper shifted twice")
t.SetLaneControls(False,False); t.SetLaneControls(False,True)
Check(t.selectedLetter=0 And t.letterMask=1,"Right selection wrap")
t.SetLaneControls(False,False); t.SetLaneControls(True,True)
Check(t.selectedLetter=0,"Simultaneous flippers must cancel selection shift")
t.SetLaneControls(False,False); t.SetLaneControls(True,False,False)
Check(t.selectedLetter=0,"Paused input shifted selection")
t.SetLaneControls(True,False); Check(t.selectedLetter=0,"Resume fabricated a fresh press")
t.SetLaneControls(False,False); t.SetLaneControls(False,True)
t.UpdateLetterLanes()
Check(t.letterMask=3,"Same lane failed to catch newly selected L")
t.Spawn(); Check(t.letterMask=3 And t.wordsCompleted=1,"Letter progress lost across balls")
t.Free()
Print "PASS FLUX lanes, swept/downward detection, bonus, edge controls and persistence"
