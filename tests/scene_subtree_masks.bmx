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
 Field draws:Int,fail:Int,size:Int=8
 Method OnDraw(context:TSceneDrawContext)
  draws:+1
  If fail Then Throw "intentional mask drawing failure"
  DrawRect(0,0,size,size)
 End Method
End Type
Function Box:TBox(parent:TSceneNode,size:Int,x:Float=0,y:Float=0)
 Local result:TBox=New TBox
 result.size=size;result.SetSelfBounds(TSceneRect.Create(0,0,size,size));result.SetPosition(x,y)
 parent.AddChild(result)
 Return result
End Function
Function Group:TCompositeNode(parent:TSceneNode)
 Local result:TCompositeNode=TCompositeNode.Create()
 result.SetCacheMode(ESceneCacheMode.Automatic);result.SetCaptureRect(TSceneRect.Create(0,0,32,32));parent.AddChild(result)
 Return result
End Function
Function Render:TPixmap(scene:TScene,target:TRenderImage)
 SetRenderImage(target);SetVirtualResolution(96,64);SetViewport(0,0,96,64)
 SetClsColor(0,0,0,0);Cls;scene.Render()
 Return ReadRenderImage(target)
End Function
Function Alpha:Int(pixels:TPixmap,x:Int,y:Int)
 Return pixels.ReadPixel(x,y) Shr 24 & 255
End Function
Try
 Graphics(96,64)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer);scene.SetInputClip(TSceneRect.Create(0,0,96,64))
 Local hidden:TSceneNode2D=New TSceneNode2D
 hidden.SetVisible(False);hidden.SetTint(255,0,0);hidden.SetPosition(100,100);layer.AddChild(hidden)
 Local source:TBox=Box(hidden,8,4,6)
 Local outer:TCompositeNode=Group(layer),consumer:TCompositeNode=Group(outer)
 Local art:TBox=Box(consumer,32)
 art.SetInteractive(True)
 Local mask:TSceneSubtreeMaskStage=TSceneSubtreeMaskStage.Create(source)
 consumer.SetStages([TSceneEffectStage(mask)])
 Local target:TRenderImage=CreateRenderImage(96,64,0)
 Local pixels:TPixmap=Render(scene,target)
 Check(Alpha(pixels,6,8)>250 And Alpha(pixels,20,8)=0,"live mask captures isolated source alpha")
 Check(scene.Pick(20,8)=art,"live masks leave picking unchanged")
 Check(scene.RetainedStorageBytes()=32*32*4*4,"two mask targets plus two composite captures charged")
 Local draws:Int=art.draws,sourceDraws:Int=source.draws
 Render(scene,target)
 Check(art.draws=draws And source.draws=sourceDraws And scene.CaptureStats().Captures()=0,"warm enclosing cache skips mask and content work")
 Local before:SGCStats,after:SGCStats
 For Local i:Int=0 Until 10
  scene.Render();TMax2DGraphics.Current().context.Flush()
 Next
 GCCollect();GCGetStats(before)
 For Local i:Int=0 Until 100
  scene.Render();TMax2DGraphics.Current().context.Flush()
 Next
 GCGetStats(after)
 Local allocated:ULongInt=(after.allocedBytesBeforeGC+after.bytesAllocedSinceGC)-(before.allocedBytesBeforeGC+before.bytesAllocedSinceGC)
 Print "100 cached live-mask frames: "+allocated+" managed bytes"
 Check(allocated=3200,"warm dependency preparation adds no allocations beyond scene scope links")
 source.SetPosition(20,4);pixels=Render(scene,target)
 Check(Alpha(pixels,22,6)>250 And Alpha(pixels,6,8)=0,"source placement invalidates a cached ancestor")
 Check(art.draws=draws,"source edits retain captured consumer artwork")
 sourceDraws=source.draws;hidden.SetPosition(-100,-100);hidden.SetTint(0,0,255);Render(scene,target)
 Check(source.draws=sourceDraws And scene.CaptureStats().Captures()=0,"source ancestors are excluded from dependencies")
 source.SetAlpha(0.5);pixels=Render(scene,target)
 Check(Abs(Alpha(pixels,22,6)-128)<=2,"source alpha updates coverage")
 source.SetVisible(False);pixels=Render(scene,target)
 Check(Alpha(pixels,22,6)=0,"source visibility updates coverage")
 source.SetVisible(True);source.SetAlpha(1);mask.SetInverted(True);pixels=Render(scene,target)
 Check(Alpha(pixels,22,6)=0 And Alpha(pixels,6,8)>250,"inverse live mask")
 mask.SetInverted(False);mask.SetOffset(-16,2);pixels=Render(scene,target)
 Check(Alpha(pixels,6,8)>250 And Alpha(pixels,22,6)=0,"mask offset maps source into consumer coordinates")
 mask.SetOffset(0,0)
 consumer.SetResolutionScale(2);pixels=Render(scene,target)
 Check(Alpha(pixels,22,6)>250 And Alpha(pixels,6,8)=0,"resolution scale preserves logical mask alignment")
 consumer.SetResolutionScale(1)
 hidden.RemoveChild(source);pixels=Render(scene,target)
 Check(Alpha(pixels,22,6)=0,"detached source becomes empty coverage")
 mask.SetInverted(True);pixels=Render(scene,target)
 Check(Alpha(pixels,22,6)>250,"detached inverse source retains artwork")
 mask.SetInverted(False);hidden.AddChild(source);pixels=Render(scene,target)
 Check(Alpha(pixels,22,6)>250,"reattached source refreshes")
 Local foreignScene:TScene=TScene.Create(),foreignLayer:TLayerNode=TLayerNode.Create()
 foreignScene.Root().AddChild(foreignLayer)
 hidden.RemoveChild(source);foreignLayer.AddChild(source);pixels=Render(scene,target)
 Check(Alpha(pixels,22,6)=0,"other-scene source supplies empty coverage")
 foreignLayer.RemoveChild(source);hidden.AddChild(source);foreignScene.Destroy()
 pixels=Render(scene,target);Check(Alpha(pixels,22,6)>250,"source returning from another scene refreshes")
 Local rejected:Int
 Try
  mask.SetSource(outer)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"source replacement rejects ancestor cycle")
 pixels=Render(scene,target);Check(Alpha(pixels,22,6)>250,"rejected replacement preserves source")
 Local cyc:TSceneSubtreeMaskStage=TSceneSubtreeMaskStage.Create(consumer)
 rejected=False
 Try
  consumer.SetStages([TSceneEffectStage(cyc)])
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"stage attachment rejects self cycle")
 pixels=Render(scene,target);Check(Alpha(pixels,22,6)>250,"rejected stage list preserves old mask")
 Local nested:TCompositeNode=Group(hidden),innerSource:TBox=Box(hidden,8,2,2)
 Local nestedArt:TBox=Box(nested,32)
 Local innerMask:TSceneSubtreeMaskStage=TSceneSubtreeMaskStage.Create(innerSource)
 nested.SetStages([TSceneEffectStage(innerMask)]);mask.SetSource(nested)
 pixels=Render(scene,target)
 Check(Alpha(pixels,4,4)>250 And Alpha(pixels,22,6)=0,"mask source can itself be masked")
 nested.SetCacheMode(ESceneCacheMode.None);Render(scene,target)
 Local continuousDraws:Int=nestedArt.draws
 Render(scene,target)
 Check(nestedArt.draws>continuousDraws,"continuous source refreshes cached consumers")
 nested.SetCacheMode(ESceneCacheMode.Automatic)
 innerSource.SetPosition(16,16);pixels=Render(scene,target)
 Check(Alpha(pixels,18,18)>250 And Alpha(pixels,4,4)=0,"dependency order propagates nested source changes through caches")
 rejected=False
 Try
  innerMask.SetSource(consumer)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"indirect dependency cycle rejected at configuration")
 Local second:TCompositeNode=Group(layer)
 second.SetPosition(40,0);Box(second,32)
 Local secondMask:TSceneSubtreeMaskStage=TSceneSubtreeMaskStage.Create(nested)
 second.SetStages([TSceneEffectStage(secondMask)]);pixels=Render(scene,target)
 Check(Alpha(pixels,58,18)>250,"multiple consumers may borrow one source")
 innerSource.SetPosition(4,4);pixels=Render(scene,target)
 Check(Alpha(pixels,6,6)>250 And Alpha(pixels,46,6)>250 And Alpha(pixels,18,18)=0,"shared source edit refreshes both consumers")
 nested.SetOpacity(0.5);pixels=Render(scene,target)
 Check(Abs(Alpha(pixels,6,6)-128)<=2,"source composite presentation invalidates consumers")
 nested.SetOpacity(1)
 innerSource.fail=True;innerSource.InvalidateContent();rejected=False
 Try
  Render(scene,target)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And TMax2DGraphics.Current().renderImage=target And TMax2DGraphics.Current().saved.Count()=0,"failed source drawing restores caller state")
 innerSource.fail=False;pixels=Render(scene,target)
 Check(Alpha(pixels,6,6)>250 And Alpha(pixels,46,6)>250,"source failure can retry without further invalidation")
 innerSource.Destroy();pixels=Render(scene,target)
 Check(Alpha(pixels,6,6)=0 And Alpha(pixels,46,6)=0,"destroyed borrowed source becomes empty without stale pixels")
 ' A later reparent can create a cycle that did not exist at configuration time.
 Local branch:TSceneNode2D=New TSceneNode2D
 hidden.AddChild(branch);Box(branch,8);mask.SetSource(branch)
 consumer.Reparent(branch)
 draws=nestedArt.draws;rejected=False
 Try
  Render(scene,target)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And nestedArt.draws=draws And scene.CaptureStats().Captures()=0,"structural cycle is rejected before scene captures")
 consumer.Reparent(outer);Render(scene,target)
 consumer.SetStorageLimitBytes(32*32*4*3-1);rejected=False
 Try
  Render(scene,target)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"mask targets obey composite storage budget")
 consumer.SetStorageLimitBytes(67108864);Render(scene,target)
 scene.ReleaseResources();Check(scene.RetainedStorageBytes()=0,"all owned mask storage explicitly releases")
 Render(scene,target);Check(scene.RetainedStorageBytes()>0,"mask storage recreates after release")
 scene.ReleaseResources();SetRenderImage(Null);target.ReleaseFrames();EndGraphics()
 Graphics(96,64);target=CreateRenderImage(96,64,0)
 pixels=Render(scene,target)
 Check(Alpha(pixels,2,2)>250,"live mask recreates after graphics-context replacement")
 consumer.SetStages(Null);mask.SetSource(source)
 Render(scene,target);Check(scene.CaptureStats().Completed(),"removing mask unregisters dependency preparation")
 scene.Destroy();Check(scene.RetainedStorageBytes()=0,"scene destruction releases storage and preparation registrations")
 SetRenderImage(Null);target.ReleaseFrames();EndGraphics()
 Print "PASS: "+checks+" live subtree mask checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
