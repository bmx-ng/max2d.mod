SuperStrict
Framework BRL.StandardIO
Include "../demos/ecs_swarm/swarm.bmx"
Global checks:Int
Function Check(value:Int,message:String)
 If Not value Then Throw message
 checks:+1
End Function
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local swarm:TSwarm=TSwarm.Create(layer,2)
Local first:ULong=swarm.Spawn(100,200,20,0,1)
Local view:TSwarmView=swarm.views[0]
Check(first<>0 And swarm.count=1,"spawn creates entity and binds view")
swarm.Step(0.1)
Local x:Float,y:Float
view.GetPosition(x,y)
Check(Abs(x-102)<0.001 And y=200,"ECS motion reaches presentation")
Local second:ULong=swarm.Spawn(200,200,0,0,0.05)
Check(swarm.Spawn(0,0,0,0)=0,"capacity rejects without growth")
swarm.Step(0.1)
Check(Not swarm.world.IsAlive(second) And swarm.count=1,"expiry deletes entity and unbinds view")
swarm.world.DeleteEntity(first);swarm.Sync()
Check(swarm.count=0 And Not view.Parent(),"external deletion detaches view")
Local replacement:ULong=swarm.Spawn(300,250,0,0)
Check(replacement<>first And swarm.views[0]=view,"recycled entity reuses managed view")
swarm.Sync();view.GetPosition(x,y)
Check(x=300 And y=250,"replacement has fresh presentation")
For Local i:Int=0 Until 1000
 swarm.Step(0)
Next
Check(swarm.count=1 And swarm.views[0]=view,"warm iteration retains view")
swarm.world.RemoveComponent(replacement,swarm.body);swarm.Sync()
Check(swarm.count=0 And Not view.Parent(),"component removal releases presentation binding")
swarm.Close();swarm.Close()
Check(swarm.count=0 And Not view.Parent(),"ordered cleanup is idempotent")
scene.Destroy()
Print "PASS: "+checks+" ECS scene integration checks"
