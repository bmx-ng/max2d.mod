SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import Max2D.Scene
Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw "FAIL: "+message
 checks :+ 1
End Function
Type TBox Extends TCustomDrawNode
 Field draws:Int,updates:Int,fail:Int
 Method OnDraw(context:TSceneDrawContext)
  draws :+ 1
  If fail Then Throw "draw failure"
  context.SetColor(240,190,90)
  DrawRect(0,0,20,20)
 End Method
 Method OnUpdate(dt:Double)
  updates :+ 1
 End Method
End Type
Function Box:TBox(parent:TSceneNode,x:Float,y:Float)
 Local node:TBox=New TBox
 node.SetPosition(x,y); node.SetSelfBounds(TSceneRect.Create(0,0,20,20))
 node.SetInteractive(True); node.SetProcessing(True)
 parent.AddChild(node)
 Return node
End Function
Function SamePixels:Int(a:TPixmap,b:TPixmap)
 If a.width<>b.width Or a.height<>b.height Then Return False
 For Local y:Int=0 Until a.height
  For Local x:Int=0 Until a.width
   If a.ReadPixel(x,y)<>b.ReadPixel(x,y) Then Return False
  Next
 Next
 Return True
End Function
Graphics 320,240
SetVirtualResolution(320,240)
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local stats:TSceneStats=New TSceneStats
scene.CopyStats(stats)
Check(Not stats.Completed() And stats.NodesVisited()=0,"statistics start empty")
Local group:TSceneNode2D=New TSceneNode2D
group.SetPosition(500,0); layer.AddChild(group)
Local off:TBox=Box(group,0,0), visible:TBox=Box(layer,40,40)
scene.Render(); scene.CopyStats(stats)
Check(off.draws=1 And stats.CulledSubtrees()=0 And stats.DrawVisits()=3,"culling defaults off")
scene.SetCulling(True)
SetClsColor(0,0,0); Cls(); scene.Render(); scene.CopyStats(stats)
Check(stats.Completed() And stats.NodesVisited()=4 And stats.DrawVisits()=1 And stats.CulledSubtrees()=1,"offscreen subtree pruned once")
Check(off.draws=1,"offscreen child callback skipped")
Check(stats.BoundsRebuilds()=3 And stats.BoundsTests()=2,"cold bounds diagnostics")
scene.Render(); scene.CopyStats(stats)
Check(stats.BoundsRebuilds()=0 And stats.WorldRebuilds()=0,"warm caches reused")
scene.Update(0)
Check(off.updates=1,"culled branches still update")
scene.SetInputClip(TSceneRect.Create(0,0,1000,1000))
Check(scene.Pick(510,10)=off,"render culling does not alter picking")
Local snapshot:TSceneStats=scene.CaptureStats()
group.SetPosition(100,0); scene.Render(); scene.CopyStats(stats)
Check(stats.CulledSubtrees()=0 And off.draws=2 And stats.WorldRebuilds()=2,"moving subtree into view resolves descendant matrices")
Check(snapshot.CulledSubtrees()=1,"stats snapshot detached")
group.SetPosition(500,0); off.ClearSelfBounds()
scene.Render(); scene.CopyStats(stats)
Check(stats.UnknownBounds()=2 And off.draws=3,"unknown descendant prevents group and self culling")
off.SetSelfBounds(TSceneRect.Create(0,0,20,20))
group.SetVisible(False); scene.Render(); scene.CopyStats(stats)
Check(stats.HiddenSubtrees()=1 And stats.CulledSubtrees()=0,"hidden branch counted separately")
group.SetVisible(True)
layer.SetViewport(TSceneRect.Create(0,0,0,100)); scene.Render(); scene.CopyStats(stats)
Check(stats.ClippedSubtrees()=2 And stats.DrawVisits()=0,"empty layer clip prunes each spatial root")
layer.ClearViewport()
Local camera:TCamera2D=New TCamera2D
camera.x=500; layer.SetCamera(camera)
scene.Render(); scene.CopyStats(stats)
Check(stats.CulledSubtrees()=1 And off.draws=4,"camera participates in culling")
layer.SetCamera(Null)
SetViewport(0,0,30,30); scene.Render(); scene.CopyStats(stats)
Check(stats.CulledSubtrees()=2,"caller viewport participates")
SetViewport(0,0,320,240)
visible.SetPosition(319,40); scene.Render(); scene.CopyStats(stats)
Check(stats.DrawVisits()=1,"clip-edge overlap retained")
visible.SetPosition(320,40); scene.Render(); scene.CopyStats(stats)
Check(stats.DrawVisits()=1,"clip-edge uncertainty retained")
visible.SetPosition(350,40); scene.Render(); scene.CopyStats(stats)
Check(stats.DrawVisits()=0,"clearly outside clip culled")
visible.SetPosition(40,40); visible.fail=True
Local failed:Int
Try
 scene.Render()
Catch error:Object
 failed=True
End Try
scene.CopyStats(stats)
Check(failed And Not stats.Completed() And stats.DrawVisits()=1,"failed render reports partial statistics")
visible.fail=False
scene.Render(); scene.CopyStats(stats)
Check(stats.Completed(),"render recovers after failure")
' Compare complete rendered pixels for nested rotated/sheared geometry and clips.
Local extra:TSceneNode2D=New TSceneNode2D
extra.SetLocalTransform(TSceneTransform.Create(1,0.2,-0.3,1,150,120)); layer.AddChild(extra)
For Local i:Int=0 Until 20
 Local node:TBox=Box(extra,i*27-240,(i Mod 3)*24)
 node.SetRotation(i*13); node.SetScale(-1,1.3)
Next
layer.SetViewport(TSceneRect.Create(10.5,11.5,280,200))
scene.SetCulling(False); Cls(); scene.Render()
Local baseline:TPixmap=GrabPixmap(0,0,320,240)
scene.SetCulling(True); Cls(); scene.Render()
Local culled:TPixmap=GrabPixmap(0,0,320,240)
Check(SamePixels(baseline,culled),"culling preserves rendered pixels under shear/rotation/negative scale/clipping")
layer.ClearViewport()
' Compare allocation against the existing per-render outer state scope.
scene.SetCulling(False); scene.Render()
Local s0:SGCStats,s1:SGCStats
GCCollect(); GCGetStats(s0)
For Local i:Int=0 Until 100
 scene.Render(); scene.CopyStats(stats)
Next
GCGetStats(s1)
Local disabled:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
scene.SetCulling(True); scene.Render()
GCCollect(); GCGetStats(s0)
For Local i:Int=0 Until 100
 scene.Render(); scene.CopyStats(stats)
Next
GCGetStats(s1)
Local enabled:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
Print "100 renders: culling off "+disabled+" bytes; on "+enabled+" bytes"
Check(enabled<=disabled,"warm culling and stats copying add no allocations")
scene.Destroy(); EndGraphics()
Print "PASS: "+checks+" scene culling checks"
