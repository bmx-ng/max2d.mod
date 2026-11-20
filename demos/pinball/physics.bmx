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
End Type
Type TPinContacts Extends b2ContactListener
 Field table:TPinTable
 Method Add(point:b2ContactPoint) Override
  Local a:b2Shape=point.GetShape1(),b:b2Shape=point.GetShape2()
  Local target:TPinTarget
  If a.GetBody()=table.ball Then target=TPinTarget(b.GetUserData())
  If b.GetBody()=table.ball Then target=TPinTarget(a.GetUserData())
  If Not target Then Return
  Local n:b2Vec2=point.GetNormal()
  target.nx=n.GetX(); target.ny=n.GetY()
  If a.GetBody()=table.ball Then target.nx=-target.nx; target.ny=-target.ny
  target.pending=True
 End Method
End Type
Type TPinTable
 Field world:b2World,ball:b2Body,flipper:b2Body[2],joint:b2RevoluteJoint[2]
 Field rails:TPinRail[]=New TPinRail[0],targets:TPinTarget[5],contacts:TPinContacts
 Field score:Int,balls:Int=3,waiting:Int=True,gameOver:Int,hits:Int,litMask:Int,surges:Int
 Field elapsed:Float,surge:Float,charge:Float,saveTime:Float,drainDelay:Float
 Field previousX:Float,previousY:Float,previousAngle:Float[2]
 Field gate:b2Shape,gateClosed:Int
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
  For Local i:Int=0 Until 5
   targets[i]=New TPinTarget; targets[i].index=i
  Next
  Bumper(0,3.3,5.0); Bumper(1,7.9,5.0); Bumper(2,5.6,8.0)
  targets[3].x=2.75; targets[3].y=14.1
  targets[4].x=8.85; targets[4].y=14.1
  Rail(2,12.8,3.5,15.4,3); Rail(8.1,15.4,9.6,12.8,4)
  MakeFlipper(0,3.4,17,20)
  MakeFlipper(1,8.4,17,160)
  Local gateDef:b2BodyDef=New b2BodyDef
  gateDef.SetPosition(New b2Vec2.Create(11.25,4))
  Local gateShape:b2PolygonDef=New b2PolygonDef
  gateShape.SetAsBox(0.75,0.1); gateShape.SetFilterCategoryBits(2); gateShape.SetFilterMaskBits(0)
  gateShape.SetRestitution(0.55); gateShape.SetFriction(0.08)
  gate=world.CreateBody(gateDef).CreateShape(gateShape)
  Spawn()
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
   If t.pending Then
    t.pending=False
    If t.cooldown<=0 And Not waiting And Not gameOver Then
     t.cooldown=0.12; t.flash=0.45; hits:+1
     Local award:Int=100
     If t.index>=3 Then award=50
     If surge>0 Then award:*2
     score:+award
     If t.index<3 Then litMask=litMask | (1 Shl t.index)
     If litMask=7 Then litMask=0; surge=10; surges:+1; score:+500
     Local v:b2Vec2=ball.GetLinearVelocity()
     Local outgoing:Float=v.GetX()*t.nx+v.GetY()*t.ny
     Local kick:Float=Max(0,15-outgoing)*ball.GetMass()
     ball.ApplyImpulse(New b2Vec2.Create(t.nx*kick,t.ny*kick),ball.GetWorldCenter())
    End If
   End If
  Next
  Local v:b2Vec2=ball.GetLinearVelocity(),speed:Float=Sqr(v.GetX()^2+v.GetY()^2)
  maxSpeed=Max(maxSpeed,speed)
  ' Bound pathological energy spikes while retaining ordinary flipper shots.
  If speed>32 Then ball.SetLinearVelocity(New b2Vec2.Create(v.GetX()*32/speed,v.GetY()*32/speed))
  p=ball.GetPosition()
  ' Close only after the whole launched ball has cleared the gate.
  If Not waiting And Not gateClosed And p.GetY()<3.5 Then SetGate(True)
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
