SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.SceneEffects
Import BRL.StandardIO
Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Type TBox Extends TCustomDrawNode
 Field draws:Int,fail:Int
 Method OnDraw(context:TSceneDrawContext)
  draws:+1
  If fail Then Throw "intentional subtree failure"
  DrawRect(0,0,8,8)
 End Method
End Type
Type TCapture Extends TSceneRenderGroup
 Field source:TSceneNode2D, rejectedSource:TSceneNode2D
 Field reject:Int,expectFailure:Int
 Field guard:TBox
 Field borrowed:TSceneGroupContext
 Method OnRenderGroup(context:TSceneGroupContext)
  borrowed=context
  Local graphics:TMax2DGraphics=TMax2DGraphics.Current()
  Local state:TMax2DState=graphics.state,target:TRenderImage=graphics.renderImage
  Local depth:Int=graphics.saved.Count(),red:Int,green:Int,blue:Int
  GetColor(red,green,blue)
  If reject Then
   Local rejected:Int,count:Int
   If guard Then count=guard.draws
   Try
    context.RenderSubtree(rejectedSource)
   Catch error:Object
    rejected=True
   End Try
   Check(rejected,"invalid or cyclic source rejected")
   If guard Then Check(guard.draws=count,"cycle preflight rejects before drawing any source pixels")
  End If
  Local failed:Int
  Try
   context.RenderSubtree(source,4,6)
  Catch error:Object
   failed=True
   If Not expectFailure Then Throw error
  End Try
  Check(failed=expectFailure,"subtree failure propagated")
  Local r:Int,g:Int,b:Int
  GetColor(r,g,b)
  Check(graphics.state=state And graphics.renderImage=target And graphics.saved.Count()=depth,"capture restores state identity, target and stack")
  Check(r=red And g=green And b=blue,"capture restores tint")
 End Method
End Type
Function Render:TPixmap(scene:TScene,target:TRenderImage)
 SetRenderImage(target);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
 SetClsColor(0,0,0,0);Cls;scene.Render()
 Return ReadRenderImage(target)
End Function
Try
 Graphics(64,64)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local hidden:TSceneNode2D=New TSceneNode2D
 hidden.SetPosition(100,100);hidden.SetTint(255,0,0);hidden.SetVisible(False);layer.AddChild(hidden)
 Local source:TSceneNode2D=New TSceneNode2D
 source.SetPosition(8,10);source.SetTint(0,255,0);hidden.AddChild(source)
 Local box:TBox=New TBox
 box.SetSelfBounds(TSceneRect.Create(0,0,8,8));box.SetPosition(2,3);source.AddChild(box)
 Local probe:TCapture=New TCapture
 probe.SetPosition(40,40);probe.SetTint(0,0,255);probe.source=source;layer.AddChild(probe)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 Local pixels:TPixmap=Render(scene,target)
 Check((pixels.ReadPixel(16,21) & $ffffff)=$00ff00,"root/child transforms and offset apply, ancestor and consumer tint/placement excluded")
 Check((pixels.ReadPixel(12,17) Shr 24 & 255)=0 And box.draws=1,"source captured only once and edges remain clear")
 Local rejected:Int
 Try
  probe.borrowed.RenderSubtree(source)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"borrowed context rejects use outside callback")
 source.SetVisible(False);pixels=Render(scene,target)
 Check((pixels.ReadPixel(16,21) Shr 24 & 255)=0 And box.draws=1,"source visibility is respected")
 source.SetVisible(True);source.SetAlpha(0.5);pixels=Render(scene,target)
 Check(Abs((pixels.ReadPixel(16,21) Shr 24 & 255)-128)<=2,"source alpha is respected")
 source.SetAlpha(1)
 source.SetLocalTransform(TSceneTransform.Create(-1,0,0,1,30,10));pixels=Render(scene,target)
 Check((pixels.ReadPixel(26,21) & $ffffff)=$00ff00 And (pixels.ReadPixel(16,21) Shr 24 & 255)=0,"reflected source affine transform is isolated")
 source.SetTransform(8,10,0)
 probe.reject=True;probe.rejectedSource=probe;Render(scene,target)
 Local ancestor:TSceneNode2D=New TSceneNode2D
 layer.AddChild(ancestor)
 Local guard:TBox=New TBox
 guard.SetSelfBounds(TSceneRect.Create(0,0,8,8));ancestor.AddChild(guard)
 probe.guard=guard;probe.Reparent(ancestor)
 probe.rejectedSource=ancestor;Render(scene,target)
 Local detached:TSceneNode2D=New TSceneNode2D
 probe.rejectedSource=detached;Render(scene,target)
 detached.Destroy();Render(scene,target)
 probe.rejectedSource=Null;Render(scene,target)
 Local other:TScene=TScene.Create(),otherLayer:TLayerNode=TLayerNode.Create()
 other.Root().AddChild(otherLayer)
 Local foreign:TSceneNode2D=New TSceneNode2D
 otherLayer.AddChild(foreign);probe.rejectedSource=foreign;Render(scene,target);other.Destroy()
 probe.reject=False;box.fail=True;probe.expectFailure=True;Render(scene,target)
 box.fail=False;probe.expectFailure=False;pixels=Render(scene,target)
 Check((pixels.ReadPixel(16,21) Shr 24 & 255)>250,"capture recovers after child failure")
 Local nested:TCompositeNode=TCompositeNode.Create()
 nested.SetCacheMode(ESceneCacheMode.Automatic);hidden.AddChild(nested)
 box.Reparent(nested);box.SetPosition(0,0);nested.SetPosition(8,10)
 probe.source=nested;pixels=Render(scene,target)
 Check((pixels.ReadPixel(14,18) Shr 24 & 255)>250,"nested composite source renders")
 Local count:Int=box.draws
 Render(scene,target)
 Check(box.draws=count,"nested automatic composite reuses pixels")
 scene.ReleaseResources();Check(scene.RetainedStorageBytes()=0,"captured composite storage releases")
 Render(scene,target);Check(box.draws=count+1,"captured composite recreates resources")
 scene.Destroy();Check(scene.RetainedStorageBytes()=0,"destruction releases captured resources")
 SetRenderImage(Null);target.ReleaseFrames();EndGraphics()
 Print "PASS: "+checks+" subtree capture checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
