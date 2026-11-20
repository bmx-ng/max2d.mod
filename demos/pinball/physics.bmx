' Table dimensions are physics units; positive Y points towards the drain.
' This binding exposes joint angles and motor speeds in degrees.
Const PHYSICS_DT:Float=1.0/120.0
Const BALL_RADIUS:Float=0.24
Type TPinRail
 Field x1:Float,y1:Float,x2:Float,y2:Float,active:Int
End Type
Type TPinTarget
 Field x:Float,y:Float,radius:Float,index:Int
 Field cooldown:Float,flash:Float,pending:Int,nx:Float,ny:Float
 Field passive:Int,passiveNX:Float,passiveNY:Float
End Type
Type TPinContacts Extends b2ContactListener
 Field table:TPinTable
 Method Add(point:b2ContactPoint) Override
  Local a:b2Shape=point.GetShape1(),b:b2Shape=point.GetShape2()
  Local target:TPinTarget
  If a.GetBody()=table.ball Then target=TPinTarget(b.GetUserData())
  If b.GetBody()=table.ball Then target=TPinTarget(a.GetUserData())
  If Not target Then
   Local other:b2Body
   If a.GetBody()=table.ball Then other=b.GetBody()
   If b.GetBody()=table.ball Then other=a.GetBody()
   If other And (other=table.flipper[0] Or other=table.flipper[1]) Then table.slingChain=0
   Return
  End If
  Local n:b2Vec2=point.GetNormal()
  target.nx=n.GetX(); target.ny=n.GetY()
  If a.GetBody()=table.ball Then target.nx=-target.nx; target.ny=-target.ny
  If target.index=3 Or target.index=4 Then
   Local faceX:Float=0.8661856
   If target.index=4 Then faceX=-faceX
   ' Only the long face pointing into the playfield is powered rubber.
   ' End caps and the back are solid, unpowered surfaces.
   If target.nx*faceX-target.ny*0.4997225<0.95 Then
    target.passive=True; target.passiveNX=target.nx; target.passiveNY=target.ny
    Return
   End If
  End If
  target.pending=True
 End Method
End Type
Type TPinTable
 Field world:b2World,ball:b2Body,flipper:b2Body[2],joint:b2RevoluteJoint[2]
 Field rails:TPinRail[]=New TPinRail[0],targets:TPinTarget[8],contacts:TPinContacts
 Field score:Int,balls:Int=3,waiting:Int=True,gameOver:Int,hits:Int,litMask:Int,surges:Int
 Field elapsed:Float,surge:Float,charge:Float,saveTime:Float,drainDelay:Float
 Field previousX:Float,previousY:Float,previousAngle:Float[2]
 Field gate:b2Shape,gateClosed:Int
 Field rolloverMask:Int,jackpots:Int,rolloverInside:Int[3],jackpotInside:Int
 Field jackpotTime:Float,jackpotFlash:Float,rolloverFlash:Float[3]
 Field forgeGate:b2Shape,forgeOutlet:b2Shape,forgeOpen:Int,forgeCharge:Int,forgeMask:Int,forgeCells:Int
 Field forgeTime:Float,forgeFlash:Float,forgeAnimation:Float,forgeSwitchInside:Int
 Field slingChain:Int
 Field maxSpeed:Float
 Method New()
  Local bounds:b2AABB=New b2AABB.Create(New b2Vec2.Create(-20,-20),New b2Vec2.Create(40,50))
  world=New b2World.Create(bounds,New b2Vec2.Create(0,12),False)
  world.SetContinuousPhysics(True)
  contacts=New TPinContacts; contacts.table=Self; world.SetContactListener(contacts)
  Rail(0.7,3,0.7,13)
  Rail(0.7,3,3,0.7); Rail(3,0.7,9,0.7); Rail(9,0.7,12,2.5)
  Rail(12,2.5,12,19.1); Rail(10.5,4,10.5,19.1); Rail(10.5,19.1,12,19.1)
  Rail(0.7,13,3.4,17); Rail(10.5,13,8.4,17)
  Rail(0.7,13,0.7,20); Rail(10.5,13,10.5,20)
  For Local i:Int=0 Until 8
   targets[i]=New TPinTarget; targets[i].index=i
  Next
  Bumper(0,3.3,5.0); Bumper(1,7.9,5.0); Bumper(2,5.6,8.0)
  targets[3].x=2.75; targets[3].y=14.1
  targets[4].x=8.85; targets[4].y=14.1
  Rail(2,12.8,3.5,15.4,3); Rail(8.1,15.4,9.6,12.8,4)
  MakeFlipper(0,3.4,17,20)
  MakeFlipper(1,8.4,17,160)
  Local gateDef:b2BodyDef=New b2BodyDef
  gateDef.SetPosition(New b2Vec2.Create(11.25,3.7)); gateDef.SetAngle(Float(ATan2(-0.6,1.5)))
  Local gateShape:b2PolygonDef=New b2PolygonDef
  gateShape.SetAsBox(Float(Sqr(1.5^2+0.6^2)/2),0.1); gateShape.SetFilterCategoryBits(2); gateShape.SetFilterMaskBits(0)
  gateShape.SetRestitution(0.55); gateShape.SetFriction(0.08)
  gate=world.CreateBody(gateDef).CreateShape(gateShape)
  MakeForge()
  Spawn()
 End Method
 Method MakeForge()
  Rail(0.7,6.5,2,7); Rail(1.5,11,2,10.6)
  Local def:b2BodyDef=New b2BodyDef
  def.SetPosition(New b2Vec2.Create(2,8.8))
  Local shape:b2PolygonDef=New b2PolygonDef
  shape.SetAsBox(0.1,1.8); shape.SetFilterCategoryBits(2); shape.SetRestitution(0.35)
  forgeGate=world.CreateBody(def).CreateShape(shape)
  ' Open a lower-left outlet with the shutter, so the reversed bottom slope
  ' drains the bay rather than collecting the ball against the outer wall.
  def=New b2BodyDef
  def.SetPosition(New b2Vec2.Create(1.1,11.2)); def.SetAngle(Float(ATan2(-0.4,0.8)))
  shape=New b2PolygonDef; shape.SetAsBox(Float(Sqr(0.8^2+0.4^2)/2),0.1)
  shape.SetFilterCategoryBits(2); shape.SetRestitution(0.35)
  forgeOutlet=world.CreateBody(def).CreateShape(shape)
  For Local i:Int=0 Until 3
   Local t:TPinTarget=targets[5+i]
   t.x=1.15; t.y=7.6+i*1.2
   def=New b2BodyDef; def.SetPosition(New b2Vec2.Create(t.x,t.y))
   shape=New b2PolygonDef
   ' Bevel the caps into the wall so a ball cannot perch behind a target.
   shape.SetVertices([New b2Vec2.Create(-0.45,-0.48),New b2Vec2.Create(0.12,-0.25),New b2Vec2.Create(0.12,0.25),New b2Vec2.Create(-0.45,0.48)])
   shape.SetFilterCategoryBits(2); shape.SetRestitution(0.6)
   world.CreateBody(def).CreateShape(shape).SetUserData(t)
  Next
 End Method
 Method SetForgeGate(open:Int)
  If forgeOpen=open Then Return
  forgeOpen=open
  Local filter:b2FilterData=forgeGate.GetFilterData()
  filter.maskBits=1
  If open Then filter.maskBits=0
  forgeGate.SetFilterData(filter); world.Refilter(forgeGate)
  forgeOutlet.SetFilterData(filter); world.Refilter(forgeOutlet)
 End Method
 Method HitForge(index:Int)
  If forgeTime<=0 Or (forgeMask & (1 Shl index)) Then Return
  forgeMask:|1 Shl index; score:+250
  If forgeMask=7 Then
   forgeTime=0; forgeCells:+1; forgeFlash=3; score:+2000
  End If
 End Method
 Method UpdateForge()
  forgeTime=Max(0,forgeTime-PHYSICS_DT); forgeFlash=Max(0,forgeFlash-PHYSICS_DT)
  Local p:b2Vec2=ball.GetPosition()
  Local inside:Int=(p.GetX()-3.2)^2+(p.GetY()-10.9)^2<0.65^2
  If forgeCharge=3 And Not waiting And Not gameOver And Not forgeSwitchInside And Crossed(3.2,10.9,0.65) Then
   forgeCharge=0; forgeMask=0; forgeTime=25; SetForgeGate(True)
  End If
  forgeSwitchInside=inside
  ' Leave the exit open after success/timeout until the ball is safely outside.
  If forgeOpen And forgeTime=0 And (p.GetX()>2.5 Or p.GetY()<6.5 Or p.GetY()>11.9) Then SetForgeGate(False)
  If forgeOpen Then forgeAnimation=Min(1,forgeAnimation+PHYSICS_DT*6) Else forgeAnimation=Max(0,forgeAnimation-PHYSICS_DT*6)
 End Method
 Method Rail(x1:Float,y1:Float,x2:Float,y2:Float,target:Int=-1)
  Local rail:TPinRail=New TPinRail
  rail.x1=x1; rail.y1=y1; rail.x2=x2; rail.y2=y2; rail.active=target>=0
  rails=rails[..rails.Length+1]; rails[rails.Length-1]=rail
  Local def:b2BodyDef=New b2BodyDef
  def.SetPosition(New b2Vec2.Create((x1+x2)/2,(y1+y2)/2)); def.SetAngle(Float(ATan2(y2-y1,x2-x1)))
  Local body:b2Body=world.CreateBody(def),shape:b2PolygonDef=New b2PolygonDef
  shape.SetAsBox(Float(Sqr((x2-x1)^2+(y2-y1)^2)/2),0.1)
  shape.SetFilterCategoryBits(2)
  shape.SetRestitution(0.55); shape.SetFriction(0.08)
  If target>=0 Then shape.SetRestitution(0)
  Local fixture:b2Shape=body.CreateShape(shape)
  If target>=0 Then fixture.SetUserData(targets[target])
 End Method
 Method Bumper(index:Int,x:Float,y:Float)
  Local target:TPinTarget=targets[index]
  target.x=x; target.y=y; target.radius=0.65
  Local def:b2BodyDef=New b2BodyDef
  def.SetPosition(New b2Vec2.Create(x,y))
  Local body:b2Body=world.CreateBody(def),shape:b2CircleDef=New b2CircleDef
  shape.SetFilterCategoryBits(2)
  shape.SetRadius(target.radius); shape.SetRestitution(0.85); shape.SetFriction(0.02)
  body.CreateShape(shape).SetUserData(target)
 End Method
 Method MakeFlipper(index:Int,x:Float,y:Float,angle:Float)
  Local def:b2BodyDef=New b2BodyDef
  def.SetPosition(New b2Vec2.Create(Float(x+Cos(angle)*1.05),Float(y+Sin(angle)*1.05)))
  def.SetAngle(angle); def.SetIsBullet(True)
  flipper[index]=world.CreateBody(def)
  Local shape:b2PolygonDef=New b2PolygonDef
  shape.SetFilterCategoryBits(4); shape.SetFilterMaskBits(1)
  shape.SetAsBox(1.05,0.16); shape.SetDensity(2); shape.SetFriction(0.35); shape.SetRestitution(0.25)
  flipper[index].CreateShape(shape); flipper[index].SetMassFromShapes()
  Local jd:b2RevoluteJointDef=New b2RevoluteJointDef
  jd.Initialize(world.GetGroundBody(),flipper[index],New b2Vec2.Create(x,y))
  jd.EnableMotor(True); jd.SetMaxMotorTorque(700); jd.EnableLimit(True)
  If index=0 Then jd.SetLowerAngle(-48); jd.SetUpperAngle(0) Else jd.SetLowerAngle(0); jd.SetUpperAngle(48)
  joint[index]=b2RevoluteJoint(world.CreateJoint(jd))
  previousAngle[index]=angle
 End Method
 Method SetGate(closed:Int)
  If gateClosed=closed Then Return
  gateClosed=closed
  Local filter:b2FilterData=gate.GetFilterData()
  filter.maskBits=0
  If closed Then filter.maskBits=1
  gate.SetFilterData(filter); world.Refilter(gate)
 End Method
 Method Spawn()
  SetGate(False)
  slingChain=0
  forgeTime=0; forgeSwitchInside=False
  SetForgeGate(False)
  jackpotInside=False
  For Local i:Int=0 Until 3
   rolloverInside[i]=False
  Next
  If ball Then world.DestroyBody(ball)
  Local def:b2BodyDef=New b2BodyDef
  def.SetPosition(New b2Vec2.Create(11.25,18.5)); def.SetIsBullet(True); def.SetLinearDamping(0.025)
  ball=world.CreateBody(def)
  Local shape:b2CircleDef=New b2CircleDef
  shape.SetRadius(BALL_RADIUS); shape.SetDensity(1); shape.SetFriction(0.12); shape.SetRestitution(0.4)
  ball.CreateShape(shape); ball.SetMassFromShapes()
  previousX=11.25; previousY=18.5; waiting=True; charge=0; drainDelay=0
 End Method
 Method Launch()
  If Not waiting Or gameOver Then Return
  ball.SetLinearVelocity(New b2Vec2.Create(0,-(23+charge*6)))
  waiting=False; charge=0; saveTime=5
 End Method
 ' Swept detection prevents a fast ball skipping thin rollover switches.
 Method Crossed:Int(x:Float,y:Float,radius:Float)
  Local p:b2Vec2=ball.GetPosition(),dx:Float=p.GetX()-previousX,dy:Float=p.GetY()-previousY
  Local fraction:Float=0,lengthSquared:Float=dx*dx+dy*dy
  If lengthSquared>0 Then fraction=Max(0,Min(1,((x-previousX)*dx+(y-previousY)*dy)/lengthSquared))
  Local ox:Float=previousX+fraction*dx-x,oy:Float=previousY+fraction*dy-y
  Return ox*ox+oy*oy<radius*radius
 End Method
 Method UpdateObjectives()
  jackpotTime=Max(0,jackpotTime-PHYSICS_DT); jackpotFlash=Max(0,jackpotFlash-PHYSICS_DT)
  Local p:b2Vec2=ball.GetPosition()
  For Local i:Int=0 Until 3
   rolloverFlash[i]=Max(0,rolloverFlash[i]-PHYSICS_DT)
   Local x:Float=3.4+i*2.2,inside:Int=(p.GetX()-x)^2+(p.GetY()-2.5)^2<0.55^2
   If Not waiting And Not gameOver And Not rolloverInside[i] And Crossed(x,2.5,0.55) Then
    If Not (rolloverMask & (1 Shl i)) And jackpotTime=0 Then
     rolloverMask:|1 Shl i; score:+150; rolloverFlash[i]=0.6
     If rolloverMask=7 Then rolloverMask=0; jackpotTime=15
    End If
   End If
   rolloverInside[i]=inside
  Next
  Local inside:Int=(p.GetX()-5.6)^2+(p.GetY()-11)^2<0.8^2
  If Not waiting And Not gameOver And jackpotTime>0 And Not jackpotInside And Crossed(5.6,11,0.8) Then
   score:+1000; jackpots:+1; jackpotTime=0; jackpotFlash=1.2
  End If
  jackpotInside=inside
 End Method
 Method Tick(left:Int,right:Int)
  elapsed:+PHYSICS_DT; surge=Max(0,surge-PHYSICS_DT); saveTime=Max(0,saveTime-PHYSICS_DT)
  For Local i:Int=0 Until 2
   previousAngle[i]=flipper[i].GetAngle()
   Local held:Int=left
   If i=1 Then held=right
   Local speed:Float=500
   joint[i].SetMaxMotorTorque(200)
   If held Then speed=-1200; joint[i].SetMaxMotorTorque(700)
   If held And Abs(joint[i].GetJointAngle())>46 Then speed=-25
   If i=1 Then speed=-speed
   joint[i].SetMotorSpeed(speed)
  Next
  Local p:b2Vec2=ball.GetPosition()
  previousX=p.GetX(); previousY=p.GetY()
  For Local t:TPinTarget=EachIn targets
   t.cooldown=Max(0,t.cooldown-PHYSICS_DT); t.flash=Max(0,t.flash-PHYSICS_DT)
  Next
  world.DoStep(PHYSICS_DT,10,6)
  ' Callbacks only queue events. Apply gameplay impulses after the world unlocks.
  For Local t:TPinTarget=EachIn targets
   If t.passive Then
    t.passive=False
    ' Box2D mixes restitution using the larger value, including the ball's.
    ' Remove that rebound on the unpowered back/caps; retain tangential motion.
    Local v:b2Vec2=ball.GetLinearVelocity(),outward:Float=v.GetX()*t.passiveNX+v.GetY()*t.passiveNY
    If outward>0 Then ball.SetLinearVelocity(New b2Vec2.Create(v.GetX()-outward*t.passiveNX,v.GetY()-outward*t.passiveNY))
   End If
   If t.pending Then
    t.pending=False
    If t.cooldown<=0 And Not waiting And Not gameOver Then
     t.cooldown=0.12; t.flash=0.45; hits:+1
     If t.index>=5 Then
      HitForge(t.index-5)
      Continue
     End If
     If t.index=0 And forgeTime=0 And forgeCharge<3 Then forgeCharge:+1
     Local award:Int=100
     If t.index>=3 Then award=50
     If surge>0 Then award:*2
     score:+award
     If t.index<3 Then litMask=litMask | (1 Shl t.index)
     If litMask=7 Then litMask=0; surge=10; surges:+1; score:+500
     Local v:b2Vec2=ball.GetLinearVelocity()
     Local outgoing:Float=v.GetX()*t.nx+v.GetY()*t.ny
     Local kickSpeed:Float=15
     If t.index=3 Or t.index=4 Then
      ' Repeated unattended sling exchanges must shed energy instead of
      ' forming a self-sustaining orbit through an open Forge target.
      slingChain:+1
      kickSpeed=Max(0,15-Max(0,slingChain-2)*3)
     Else
      slingChain=0
     End If
     Local kick:Float=Max(0,kickSpeed-outgoing)*ball.GetMass()
     ball.ApplyImpulse(New b2Vec2.Create(t.nx*kick,t.ny*kick),ball.GetWorldCenter())
    End If
   End If
  Next
  UpdateObjectives()
  UpdateForge()
  Local v:b2Vec2=ball.GetLinearVelocity(),speed:Float=Sqr(v.GetX()^2+v.GetY()^2)
  maxSpeed=Max(maxSpeed,speed)
  ' Bound pathological energy spikes while retaining ordinary flipper shots.
  If speed>32 Then ball.SetLinearVelocity(New b2Vec2.Create(v.GetX()*32/speed,v.GetY()*32/speed))
  p=ball.GetPosition()
  ' Close only after the whole launched ball has cleared the gate.
  If Not waiting And Not gateClosed And p.GetY()<2.95 Then SetGate(True)
  If Not waiting And Not gameOver Then
   If p.GetY()>20.5 Then
    If saveTime>0 Then
     Spawn(); Launch(); saveTime=0
    Else
     balls:-1
     If balls=0 Then gameOver=True Else Spawn()
    End If
   Else If p.GetX()>10.8 And p.GetY()>18 And speed<1 Then
    ' A weak launch may return to the shooter lane without losing a ball.
    waiting=True
   End If
  End If
 End Method
 Method Free()
  contacts.table=Null
  world.Free(); ball=Null; world=Null
 End Method
End Type
