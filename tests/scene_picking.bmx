SuperStrict
Framework BRL.StandardIO
Import Max2D.Scene

Global checks:Int
Function Check(ok:Int, message:String)
 If Not ok Then Throw "FAIL: "+message
 checks :+ 1
End Function
Type TShape Extends TCustomDrawNode
 Field calls:Int, mode:Int
 Method HitTestLocal:Int(x:Float,y:Float)
  calls :+ 1
  If mode=1 Then SetPosition(10,20)
  If mode=2 Then Scene().Pick(x,y)
  If mode=3 Then Throw "application hit failure"
  If mode=4 Then Return x*x+y*y < 100
  Return Super.HitTestLocal(x,y)
 End Method
End Type
Function Shape:TShape(parent:TSceneNode)
 Local node:TShape=New TShape
 node.SetSelfBounds(TSceneRect.Create(0,0,100,100)); node.SetInteractive(True)
 parent.AddChild(node)
 Return node
End Function
Local scene:TScene=TScene.Create(), layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local a:TShape=Shape(layer), b:TShape=Shape(layer)
Check(scene.Pick(20,20)=Null,"input clip is required")
Local clip:TSceneRect=TSceneRect.Create(0,0,500,500)
scene.SetInputClip(clip); clip.width=0
Check(scene.Pick(20,20)=b,"copied input clip and last sibling wins")
Check(a.calls=0,"covered node callback is not evaluated")
Check(scene.Pick(100,20)=Null,"exclusive right edge")
Check(scene.Pick(0,0)=b,"inclusive left/top")
b.SetInteractive(False)
Check(scene.Pick(20,20)=a,"noninteractive node does not block")
b.SetInteractive(True); b.SetVisible(False)
Check(scene.Pick(20,20)=a,"hidden node excluded")
b.SetVisible(True); b.SetAlpha(0)
Check(scene.Pick(20,20)=a,"zero alpha excluded")
b.SetAlpha(1)
layer.SetSortableChildren(True); a.SetZIndex(10)
Check(scene.Pick(20,20)=a,"z order used")
a.SetZIndex(0)
Check(scene.Pick(20,20)=b,"equal z preserves insertion")
Local child:TShape=Shape(a)
a.SetZIndex(10)
Check(scene.Pick(20,20)=child,"child draws above parent")
a.SetVisible(False)
Check(scene.Pick(20,20)=b,"hidden ancestor excludes descendants")
a.SetVisible(True); a.SetInteractive(False)
Check(scene.Pick(20,20)=child,"noninteractive parent allows descendants")
a.SetAlpha(0)
Check(scene.Pick(20,20)=b,"transparent ancestor excludes descendants")
a.SetAlpha(1); a.SetScale(0,1)
Check(scene.Pick(20,20)=b,"singular ancestor excludes hits")
a.SetScale(1,1)
layer.SetViewport(TSceneRect.Create(10.5,10.5,20,20))
Check(scene.Pick(10,10)=child,"layer clip uses renderer outward rounding")
Check(scene.Pick(31,20)=Null,"layer clip excludes right edge")
layer.ClearViewport()
scene.SetInputClip(TSceneRect.Create(15,15,10,10))
Check(scene.Pick(14,20)=Null And scene.Pick(25,20)=Null,"outer clip applied")
scene.SetInputClip(TSceneRect.Create(-1000,-1000,2000,2000))
Local camera:TCamera2D=New TCamera2D
camera.rotation=25; camera.x=10; camera.y=20; camera.zoom=2; camera.offsetX=100; camera.offsetY=150
layer.SetCamera(camera); camera.zoom=10
Local x:Float,y:Float,u:Float,v:Float
a.SetTransform(40,50,30,2,-3,4,5)
child.SetLocalTransform(TSceneTransform.Create(1,0.3,0.2,1,7,8))
Check(scene.LocalToScreen(child,20,25,x,y),"forward nested affine conversion")
Check(scene.ScreenToLocal(child,x,y,u,v) And Abs(u-20)<0.001 And Abs(v-25)<0.001,"inverse camera/rotation/shear/pivot conversion")
Check(scene.Pick(x,y)=child,"transformed hit")
Local logic:TSceneNode=New TSceneNode
child.AddChild(logic)
Check(scene.LocalToScreen(logic,20,25,u,v) And Abs(u-x)<0.001 And Abs(v-y)<0.001,"nonspatial inherited transform")
Check(scene.LocalToScreen(layer,10,20,u,v) And u=100 And v=150,"camera snapshot and layer conversion")
Check(Not scene.LocalToScreen(scene.Root(),0,0,u,v),"root has no layer mapping")
Local other:TScene=TScene.Create()
u=123; v=456
Check(Not other.ScreenToLocal(child,0,0,u,v) And u=123 And v=456,"foreign scene preserves outputs")
child.SetTransform(0,0,0,0,1)
Check(Not scene.ScreenToLocal(child,0,0,u,v) And u=123 And v=456,"singular mapping preserves outputs")
a.RemoveChild(child)
Check(Not scene.LocalToScreen(child,0,0,u,v),"detached conversion fails")
child.Destroy(); other.Destroy()
a.SetTransform(0,0,0,1,1); a.SetZIndex(0); layer.SetCamera(Null)
b.ClearSelfBounds()
Check(scene.Pick(20,20)=Null,"unknown self bounds do not hit")
b.SetHitRect(TSceneRect.Create(10,10,20,20))
Check(scene.Pick(20,20)=b,"explicit rectangle supports unknown drawing bounds")
b.ClearHitRect()
Check(scene.Pick(20,20)=Null,"clearing hit rectangle restores unknown miss")
b.SetSelfBounds(TSceneRect.Create(0,0,100,100))
For Local mode:Int=1 To 3
 b.mode=mode
 Local failed:Int
 Try
  scene.Pick(20,20)
 Catch error:Object
  failed=True
 End Try
 Check(failed,"callback mutation/reentry/error rejected")
 b.mode=0
 Check(scene.Pick(20,20)=b,"picking recovers after callback failure")
Next
b.mode=4
Check(scene.Pick(3,4)=b And scene.Pick(20,20)=Null,"custom local shape")
b.mode=0
Local front:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(front)
Local c:TShape=Shape(front)
Check(scene.Pick(20,20)=c,"later layer above earlier layer")
front.SetViewport(TSceneRect.Create(0,0,0,100))
Check(scene.Pick(20,20)=b,"empty layer clip misses")
front.ClearViewport()
scene.Reserve(1024)
For Local i:Int=0 Until 1000
 Local node:TShape=Shape(front)
 node.SetPosition(200+i,200)
Next
scene.Pick(20,20)
Local s0:SGCStats,s1:SGCStats
GCCollect(); GCGetStats(s0)
For Local i:Int=0 Until 100
 Check(scene.Pick(20,20)=c,"stable warm pick")
Next
GCGetStats(s1)
Local allocated:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
Print "100 picks through 1,002 interactive targets: "+allocated+" GC bytes"
Check(allocated=0,"warm picking allocates no objects")
scene.TrimStorage()
Check(scene.Pick(20,20)=c,"picking after trimming")
scene.SetInputClip(Null)
Check(scene.Pick(20,20)=Null,"cleared input clip disables picking")
scene.Destroy()
Print "PASS: "+checks+" scene picking checks"
