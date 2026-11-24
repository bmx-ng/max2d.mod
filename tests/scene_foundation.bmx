SuperStrict
Framework BRL.StandardIO
Import Max2D.Scene
Global checks:Int
Global events:String
Function Check(value:Int, message:String)
 If Not value Then Throw "FAIL: " + message
 checks :+ 1
End Function
Function Near(a:Double, b:Double)
 Check(Abs(a-b)<0.0001, "numeric result")
End Function
Type TProbe Extends TSceneNode2D
 Field updates:Int, fixedSteps:Int, releases:Int, deaths:Int
 Field action:Int, target:TSceneNode, destination:TSceneNode
 Method OnEnterScene()
  events :+ "E"+GetName()
 End Method
 Method OnReady()
  events :+ "R"+GetName()
 End Method
 Method OnExitScene()
  events :+ "X"+GetName()
 End Method
 Method OnReleaseResources()
  releases :+ 1
 End Method
 Method OnDestroy()
  deaths :+ 1
 End Method
 Method OnUpdate(dt:Double)
  updates :+ 1
  Select action
   Case 1
    destination.AddChild(target)
    Check(target.Parent()=Null, "addition deferred")
   Case 2
    target.Destroy()
   Case 3
    destination.RemoveChild(target)
    Check(target.Parent()=destination, "removal deferred")
    action=0
    Throw "callback error"
   Case 4
    target.Reparent(destination)
  End Select
  action=0
 End Method
 Method OnFixedUpdate(dt:Double)
  fixedSteps :+ 1
 End Method
End Type
Local scene:TScene=TScene.Create()
Local layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local a:TProbe=New TProbe, b:TProbe=New TProbe
a.SetName("a"); b.SetName("b")
a.AddChild(b)
layer.AddChild(a)
Check(events="EaEbRbRa", "enter parent first; ready child first")
events=""
layer.RemoveChild(a)
Check(events="XbXa", "exit children first")
events=""
layer.AddChild(a)
Check(events="EaEb", "ready once")
Local logic:TSceneNode=New TSceneNode
layer.AddChild(logic)
events=""
a.Reparent(logic)
Check(events="", "same scene reparent has no lifecycle")
Local snapshot:TSceneNode[]=a.Children()
snapshot[0]=Null
Check(a.ChildAt(0)=b, "children snapshot isolated")
Local caught:Int
Try
 b.AddChild(a)
Catch error:Object
 caught=True
End Try
Check(caught, "cycle rejected")
a.SetTransform(10,20,90,2,3,1,2)
Local x:Float,y:Float
a.LocalToWorld(1,2,x,y)
Near(x,10); Near(y,20)
b.SetPosition(4,5)
b.LocalToWorld(0,0,x,y)
Near(x,1); Near(y,26)
a.SetPosition(20,30)
b.LocalToWorld(0,0,x,y)
Near(x,11); Near(y,36)
Check(b.WorldToLocal(x,y,x,y), "inverse conversion")
Near(x,0); Near(y,0)
Local before:TSceneTransform=b.WorldTransform()
Local other:TSceneNode2D=New TSceneNode2D
other.SetTransform(42,15,-30,4,0.5)
layer.AddChild(other)
b.Reparent(other,True)
Local after:TSceneTransform=b.WorldTransform()
Near(before.xx,after.xx); Near(before.xy,after.xy)
Near(before.yx,after.yx); Near(before.yy,after.yy)
Near(before.tx,after.tx); Near(before.ty,after.ty)
caught=False
Try
 b.SetRotation(2)
Catch error:Object
 caught=True
End Try
Check(caught,"affine editing requires explicit reset")
a.SetScale(0,1)
caught=False
Try
 b.Reparent(a,True)
Catch error:Object
 caught=True
End Try
Check(caught And b.Parent()=other,"singular reparent is atomic")
x=77;y=88
Check(Not a.WorldToLocal(1,2,x,y),"singular inverse fails")
Near(x,77); Near(y,88)
b.SetTransform(0,0,0)
b.SetScale(-2,3)
b.CopyLocalTransform(after)
Near(after.xx,-2)
after.xx=999
b.CopyLocalTransform(after)
Near(after.xx,-2)
Local layer2:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer2)
caught=False
Try
 b.Reparent(layer2,True)
Catch error:Object
 caught=True
End Try
Check(caught And b.Parent()=other,"cross-layer preserve rejected")
a.SetProcessing(True); b.SetProcessing(True); b.SetFixedProcessing(True)
scene.Update(0.01)
Check(a.updates=1 And b.updates=1,"enabled processing")
scene.SetPaused(True)
b.SetProcessWhenPaused(True)
scene.Update(0.01); scene.FixedUpdate(0.01)
Check(a.updates=1 And b.updates=2 And b.fixedSteps=1,"pause and fixed callbacks")
scene.SetPaused(False)
Local added:TProbe=New TProbe
added.SetProcessing(True)
a.action=1; a.target=added; a.destination=layer
scene.Update(0.01)
Check(added.Parent()=layer And added.updates=0,"new child waits until next traversal")
a.action=2; a.target=added
scene.Update(0.01)
Check(added.updates=0 And added.deaths=1 And added.releases=1,"pending destroy skips update")
added.Destroy()
Check(added.deaths=1,"destroy idempotent")
a.action=3; a.target=b; a.destination=other
caught=False
Try
 scene.Update(0.01)
Catch error:Object
 caught=True
End Try
Check(caught And b.Parent()=Null And b.Scene()=Null,"exception commits queued removal")
scene.Update(0.01)
scene.ReleaseResources()
Check(a.releases=1,"release keeps live nodes")
scene.Destroy(); scene.Destroy()
Check(a.deaths=1 And b.deaths=0,"detached nodes remain caller owned")
b.Destroy()
Type TDestroyOnEnter Extends TSceneNode
 Field readied:Int, destroyed:Int
 Method OnEnterScene()
  Destroy()
 End Method
 Method OnReady()
  readied :+ 1
 End Method
 Method OnDestroy()
  destroyed :+ 1
 End Method
End Type
Local enterScene:TScene=TScene.Create()
Local enterDestroy:TDestroyOnEnter=New TDestroyOnEnter
enterScene.Root().AddChild(enterDestroy)
Check(enterDestroy.readied=0 And enterDestroy.destroyed=1,"destroy on enter skips ready")
enterScene.Destroy()

Type TThrowingNode Extends TSceneNode
 Field exits:Int, released:Int, destroyed:Int
 Method OnEnterScene()
  Throw "enter failed"
 End Method
 Method OnExitScene()
  exits :+ 1
  Throw "exit failed"
 End Method
 Method OnReleaseResources()
  released :+ 1
  Throw "release failed"
 End Method
 Method OnDestroy()
  destroyed :+ 1
 End Method
End Type
Local failingScene:TScene=TScene.Create()
Local throwing:TThrowingNode=New TThrowingNode
caught=False
Try
 failingScene.Root().AddChild(throwing)
Catch error:Object
 caught=True
End Try
Check(caught And throwing.Scene()=failingScene,"enter exception leaves committed attachment")
caught=False
Try
 failingScene.Destroy()
Catch error:Object
 caught=True
End Try
Check(caught And throwing.Parent()=Null And throwing.Scene()=Null,"exit exception completes destruction")
Check(throwing.exits=1 And throwing.released=1 And throwing.destroyed=1,"throwing hooks do not skip cleanup")
failingScene.Destroy()
' A later destruction discards an earlier queued move safely.
Local conflict:TScene=TScene.Create()
Local cl:TLayerNode=TLayerNode.Create()
conflict.Root().AddChild(cl)
Local queueMove:TProbe=New TProbe, queueDestroy:TProbe=New TProbe
cl.AddChild(queueMove); cl.AddChild(queueDestroy)
queueMove.SetProcessing(True); queueDestroy.SetProcessing(True)
Local victim:TSceneNode=New TSceneNode, destination:TSceneNode=New TSceneNode
cl.AddChild(victim); cl.AddChild(destination)
queueMove.action=4; queueMove.target=victim; queueMove.destination=destination
queueDestroy.action=2; queueDestroy.target=victim
conflict.Update(0)
Check(conflict.DiscardedOperations()=1 And victim.Parent()=Null,"pending destroy wins queued conflict")
caught=False
Try
 conflict.Update(-1)
Catch error:Object
 caught=True
End Try
Check(caught,"negative time rejected")
conflict.Update(0)
conflict.Destroy()

' Allocate all nodes, snapshots and capacity before measuring cumulative GC bytes.
Local perf:TScene=TScene.Create()
Local pl:TLayerNode=TLayerNode.Create()
perf.Root().AddChild(pl)
Const COUNT:Int=1000
Local nodes:TSceneNode2D[]=New TSceneNode2D[COUNT]
pl.ReserveChildren(COUNT)
perf.Reserve(COUNT+2,64)
For Local i:Int=0 Until COUNT
 nodes[i]=New TSceneNode2D
 pl.AddChild(nodes[i])
Next
Local output:TSceneTransform=New TSceneTransform
For Local i:Int=0 Until COUNT
 nodes[i].CopyWorldTransform(output)
Next
perf.Update(0.016)
Local s0:SGCStats,s1:SGCStats
GCGetStats(s0)
For Local frame:Int=0 Until 100
 For Local i:Int=0 Until COUNT
  nodes[i].SetPosition(frame,i)
  nodes[i].CopyWorldTransform(output)
 Next
 perf.Update(0.016)
Next
GCGetStats(s1)
Local allocated:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
Print "Warm traversal: "+allocated+" GC bytes for 100,000 node movements and transform queries"
Check(allocated=0,"warmed movement, world queries and traversal allocate zero bytes")
Local mover:TProbe=New TProbe
mover.SetProcessing(True)
pl.AddChild(mover)
Local left:TSceneNode=New TSceneNode, right:TSceneNode=New TSceneNode
pl.AddChild(left); pl.AddChild(right)
left.ReserveChildren(1); right.ReserveChildren(1)
Local moving:TSceneNode=New TSceneNode
left.AddChild(moving)
mover.target=moving
perf.Update(0.016)
GCGetStats(s0)
For Local frame:Int=0 Until 1000
 mover.action=4
 If frame Mod 2 Then mover.destination=left Else mover.destination=right
 perf.Update(0.016)
Next
GCGetStats(s1)
allocated=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
Print "Warm deferred reparent: "+allocated+" GC bytes for 1,000 operations"
Check(allocated=0,"warmed deferred reparent allocates zero bytes")
perf.TrimStorage()
perf.Update(0.016)
perf.Destroy()
Print "PASS: "+checks+" scene foundation checks"
