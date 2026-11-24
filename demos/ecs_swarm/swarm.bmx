' Flecs owns numeric simulation state; this application owns the scene-node pool.
Import Ecs.Flecs
Import Max2D.Scene

Struct SSwarmBody
 Field x:Float,y:Float,vx:Float,vy:Float
 Field remaining:Float
 Field slot:Int
End Struct

Type TSwarmView Extends TCustomDrawNode
 Method New()
  SetSelfBounds(TSceneRect.Create(-8,-6,16,12))
 End Method
 Method OnDraw(context:TSceneDrawContext) Override
  context.SetColor(70,210,245)
  DrawOval(-6,-6,12,12)
  context.SetColor(230,250,255)
  DrawRect(0,-2,8,4)
 End Method
End Type

Type TSwarm
 Field world:TEcsWorld
 Field body:SEcsComponent
 Field query:TEcsQuery
 Field layer:TLayerNode
 Field views:TSwarmView[]
 Field entities:ULong[]
 Field count:Int

 Function Create:TSwarm(layer:TLayerNode,capacity:Int=512)
  If Not layer Or capacity<1 Then Throw "Swarm requires a layer and positive capacity"
  Local swarm:TSwarm=New TSwarm
  swarm.layer=layer
  swarm.world=TEcsWorld.Create()
  swarm.body=swarm.world.RegisterComponent("SwarmBody",SizeOf(SSwarmBody),AlignOf(SSwarmBody))
  swarm.query=swarm.world.CreateQuery([swarm.body])
  swarm.views=New TSwarmView[capacity]
  swarm.entities=New ULong[capacity]
  For Local i:Int=0 Until capacity
   swarm.views[i]=New TSwarmView
  Next
  Return swarm
 End Function

 Method Spawn:ULong(x:Float,y:Float,vx:Float,vy:Float,lifetime:Float=12)
  If Not world Then Throw "Swarm is closed"
  If lifetime<=0 Then Throw "Lifetime must be positive"
  For Local i:Int=0 Until entities.Length
   If entities[i] Then Continue
   Local value:SSwarmBody
   value.x=x;value.y=y;value.vx=vx;value.vy=vy;value.remaining=lifetime;value.slot=i
   Local entity:ULong=world.NewEntity()
   world.SetComponent(entity,body,Varptr value)
   entities[i]=entity;count:+1
   views[i].SetPosition(x,y)
   layer.AddChild(views[i])
   Return entity
  Next
  Return 0
 End Method

 ' Call outside scene traversal. Structural ECS changes wait until iteration ends.
 Method Step(dt:Float)
  If Not world Then Throw "Swarm is closed"
  If Not (dt>=0 And dt<=Float(0.1)) Then Throw "Step must be between zero and 0.1 seconds"
  Local it:TEcsQueryIter=query.Iter()
  While it.Advance()
   Local values:SSwarmBody Ptr
   it.Component(body,0,Varptr values)
   For Local i:Int=0 Until it.Count()
    values[i].remaining:-dt
    If values[i].remaining<=0 Then
     world.QueueDelete(it.Entity(i))
     Continue
    End If
    values[i].x:+values[i].vx*dt;values[i].y:+values[i].vy*dt
    If values[i].x<24 Then values[i].x=24;values[i].vx=Abs(values[i].vx)
    If values[i].x>876 Then values[i].x=876;values[i].vx=-Abs(values[i].vx)
    If values[i].y<140 Then values[i].y=140;values[i].vy=Abs(values[i].vy)
    If values[i].y>596 Then values[i].y=596;values[i].vy=-Abs(values[i].vy)
   Next
  Wend
  world.FlushCommands()
  Sync()
 End Method

 Method Sync()
  If Not world Then Throw "Swarm is closed"
  ' Full generation-bearing IDs prevent recycled Flecs IDs retaining old views.
  For Local i:Int=0 Until entities.Length
   If Not entities[i] Then Continue
   If Not world.IsAlive(entities[i]) Then
    layer.RemoveChild(views[i]);entities[i]=0;count:-1
   Else If Not world.HasComponent(entities[i],body) Then
    layer.RemoveChild(views[i]);entities[i]=0;count:-1
   End If
  Next
  Local it:TEcsQueryIter=query.Iter()
  While it.Advance()
   Local values:SSwarmBody Ptr
   it.Component(body,0,Varptr values)
   For Local i:Int=0 Until it.Count()
    Local slot:Int=values[i].slot
    If slot<0 Or slot>=entities.Length Then Continue
    If entities[slot]<>it.Entity(i) Then Continue
    views[slot].SetPosition(values[i].x,values[i].y)
    views[slot].SetRotation(Float(ATan2(values[i].vy,values[i].vx)))
   Next
  Wend
 End Method

 Method Close()
  If Not world Then Return
  For Local i:Int=0 Until entities.Length
   views[i].Destroy()
  Next
  ' Explicitly release queries before their world, then clear native handles so
  ' the wrapper finalizers cannot release them a second time.
  bmx_ecs_query_destroy(query.worldPtr,query.queryPtr)
  query.queryPtr=Null;query.worldPtr=Null;query=Null
  ecs_fini(world.worldPtr)
  world.worldPtr=Null;world=Null
  views=Null;entities=Null;layer=Null;count=0
 End Method
End Type
