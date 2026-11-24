SuperStrict
Framework BRL.StandardIO
Import Max2D.Scene

Global checks:Int
Function Check(ok:Int, message:String)
 If Not ok Then Throw "FAIL: "+message
 checks :+ 1
End Function
Function Rect(rect:TSceneRect,x:Float,y:Float,w:Float,h:Float)
 Check(Abs(rect.x-x)<0.001 And Abs(rect.y-y)<0.001 And Abs(rect.width-w)<0.001 And Abs(rect.height-h)<0.001,"bounds rectangle")
End Function
Type TMeasured Extends TCustomDrawNode
 Field measures:Int, mode:Int
 Field width:Float=10, height:Float=20
 Method GetSelfBounds:Int(bounds:TSceneRect)
  measures :+ 1
  Select mode
   Case 1
    Return False
   Case 2
    SetPosition(10,20)
   Case 3
    Return GetContentBounds(bounds)
  End Select
  bounds.x=0; bounds.y=0; bounds.width=width; bounds.height=height
  Return True
 End Method
End Type

Local group:TSceneNode2D=New TSceneNode2D
Local logic:TSceneNode=New TSceneNode
Local shape:TMeasured=New TMeasured
Local bounds:TSceneRect=New TSceneRect
Local output:TSceneRect=New TSceneRect
group.AddChild(logic); logic.AddChild(shape)
shape.SetPosition(5,7)
Check(group.GetContentBounds(bounds),"known child through nonspatial node")
Rect(bounds,5,7,10,20)
Check(shape.measures=1,"initial measurement")
group.GetContentBounds(bounds); group.GetOutputBounds(output)
Check(shape.measures=1,"unchanged queries reuse bounds")
Rect(output,5,7,10,20)
group.SetTransform(900,700,44,0,0)
group.GetContentBounds(bounds)
Rect(bounds,5,7,10,20)
Check(shape.measures=1,"own world transform does not alter local content bounds")
shape.SetTransform(50,30,90,2,3,1,2)
group.GetContentBounds(bounds)
Rect(bounds,-4,28,60,20)
Check(shape.measures=1,"moving child reuses its local content bounds")
shape.SetTransform(0,0,0,-2,3)
group.GetContentBounds(bounds)
Rect(bounds,-20,0,20,60)
shape.SetScale(0,1)
group.GetContentBounds(bounds)
Rect(bounds,0,0,0,0)
shape.SetLocalTransform(TSceneTransform.Create(1,0.5,0.25,1,3,4))
group.GetContentBounds(bounds)
Rect(bounds,3,4,20,22.5)
Local other:TCustomDrawNode=New TCustomDrawNode
other.SetSelfBounds(TSceneRect.Create(-10,-5,2,3))
group.AddChild(other)
group.GetContentBounds(bounds)
Rect(bounds,-10,-5,33,31.5)
other.ClearSelfBounds()
bounds.x=123; bounds.width=456
Check(Not group.GetContentBounds(bounds),"unknown descendant propagates")
Check(bounds.x=123 And bounds.width=456,"unknown query leaves output unchanged")
other.SetVisible(False)
Check(group.GetContentBounds(bounds),"hidden unknown child excluded")
Rect(bounds,3,4,20,22.5)
' A hidden dirty child must still invalidate clean ancestors when it changes.
other.SetSelfBounds(TSceneRect.Create(100,100,5,5))
group.GetContentBounds(bounds)
other.SetVisible(True)
group.GetContentBounds(bounds)
Rect(bounds,3,4,102,101)
other.SetAlpha(0)
group.GetContentBounds(bounds)
Rect(bounds,3,4,20,22.5)
other.SetAlpha(1)
group.GetContentBounds(bounds)
Rect(bounds,3,4,102,101)
group.RemoveChild(other)
group.GetContentBounds(bounds)
Rect(bounds,3,4,20,22.5)
Local elsewhere:TSceneNode2D=New TSceneNode2D
shape.Reparent(elsewhere)
group.GetContentBounds(bounds)
Rect(bounds,0,0,0,0)
elsewhere.GetContentBounds(bounds)
Rect(bounds,3,4,20,22.5)
shape.SetTransform(0,0,0)
shape.width=40; shape.InvalidateContent()
elsewhere.GetContentBounds(bounds)
Rect(bounds,0,0,40,20)
For Local mode:Int=2 To 3
 shape.mode=mode; shape.InvalidateContent()
 Local caught:Int
 Try
  elsewhere.GetContentBounds(bounds)
 Catch error:Object
  caught=True
 End Try
 Check(caught,"mutating or recursive bounds callbacks rejected")
 shape.mode=0; shape.InvalidateContent()
 Check(elsewhere.GetContentBounds(bounds),"bounds recovery after callback failure")
Next
shape.width=-1; shape.InvalidateContent()
Local caught:Int
Try
 elsewhere.GetContentBounds(bounds)
Catch error:Object
 caught=True
End Try
Check(caught,"negative custom bounds rejected")
shape.width=10; shape.InvalidateContent()
Check(elsewhere.GetContentBounds(bounds),"retry after invalid bounds")
Local scene:TScene=TScene.Create()
Local layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer); layer.AddChild(elsewhere)
Local camera:TCamera2D=New TCamera2D
camera.zoom=5; layer.SetCamera(camera)
layer.SetViewport(TSceneRect.Create(1,2,3,4))
elsewhere.GetContentBounds(bounds)
Rect(bounds,0,0,10,20)
Local blocker:TSceneNode2D=New TSceneNode2D
layer.AddChild(blocker)
blocker.SetVisible(False)
elsewhere.Reparent(blocker)
elsewhere.GetContentBounds(bounds)
Rect(bounds,0,0,10,20)
blocker.GetContentBounds(bounds)
Rect(bounds,0,0,0,0)
' Explicit pending destruction must be reflected before deferred commit.
Type TDestroyProbe Extends TSceneNode
 Field victim:TSceneNode, parent:TSceneNode2D, result:TSceneRect
 Method OnUpdate(dt:Double)
  victim.Destroy()
  Check(parent.GetContentBounds(result),"pending destruction bounds known")
  Rect(result,0,0,0,0)
  SetProcessing(False)
 End Method
End Type
blocker.SetVisible(True)
Local destroyer:TDestroyProbe=New TDestroyProbe
destroyer.victim=shape; destroyer.parent=elsewhere; destroyer.result=bounds
destroyer.SetProcessing(True); scene.Root().AddChild(destroyer)
scene.Update(0)
scene.Destroy()
group.Destroy(); other.Destroy()

' Rebuild aggregate bounds repeatedly using retained rectangles and inline values.
Local perf:TSceneNode2D=New TSceneNode2D
Local nodes:TMeasured[]=New TMeasured[1000]
perf.ReserveChildren(nodes.Length)
For Local i:Int=0 Until nodes.Length
 nodes[i]=New TMeasured
 nodes[i].SetPosition(i,0)
 perf.AddChild(nodes[i])
Next
perf.GetContentBounds(bounds)
Local s0:SGCStats,s1:SGCStats
GCGetStats(s0)
For Local frame:Int=0 Until 100
 For Local i:Int=0 Until nodes.Length
  nodes[i].SetPosition(i,frame)
 Next
 perf.GetContentBounds(bounds)
Next
GCGetStats(s1)
Local allocated:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
Print "Moving subtree bounds: "+allocated+" GC bytes for 100,000 movements and 100 aggregate rebuilds"
Check(allocated=0,"warm aggregate bounds allocate zero bytes")
Check(nodes[0].measures=1,"moving descendants reuse self measurements")
GCGetStats(s0)
For Local frame:Int=0 Until 100
 nodes[frame].width=frame+1
 nodes[frame].InvalidateContent()
 perf.GetContentBounds(bounds)
Next
GCGetStats(s1)
allocated=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
Check(allocated=0,"warm content invalidation allocates zero bytes")
perf.Destroy()
Print "PASS: "+checks+" scene bounds checks"
