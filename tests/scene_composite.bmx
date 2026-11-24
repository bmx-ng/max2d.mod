SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.SceneEffects
Import BRL.StandardIO

Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks :+ 1
End Function
Type TBox Extends TCustomDrawNode
 Field draws:Int, fail:Int, updates:Int
 Field red:Int = 255, green:Int = 255, blue:Int = 255
 Method OnDraw(context:TSceneDrawContext)
  draws :+ 1
  If fail Then Throw "intentional child failure"
  context.SetColor(red,green,blue)
  DrawRect(0,0,20,20)
 End Method
 Method OnUpdate(dt:Double)
  updates :+ 1
 End Method
End Type
Type TFailStage Extends TSceneChainStage
 Field fail:Int
 Method Update:TRenderImage(source:TRenderImage) Override
  Local result:TRenderImage = Super.Update(source)
  If fail Then Throw "intentional stage failure"
  Return result
 End Method
End Type
Function Box:TBox(parent:TSceneNode,x:Float,y:Float)
 Local result:TBox = New TBox
 result.SetSelfBounds(TSceneRect.Create(0,0,20,20)); result.SetPosition(x,y)
 parent.AddChild(result)
 Return result
End Function
Function Render:TPixmap(scene:TScene,target:TRenderImage)
 SetRenderImage(target); SetVirtualResolution(128,96); SetViewport(0,0,128,96)
 SetClsColor(0,0,0,0); Cls
 scene.Render()
 Return ReadRenderImage(target)
End Function
Function Same:Int(a:TPixmap,b:TPixmap)
 For Local y:Int = 0 Until a.height
  For Local x:Int = 0 Until a.width
   If a.ReadPixel(x,y) <> b.ReadPixel(x,y) Then Return False
  Next
 Next
 Return True
End Function
Try
 Local scene:TScene = TScene.Create(), layer:TLayerNode = TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local group:TCompositeNode = TCompositeNode.Create()
 group.SetPosition(30,25); layer.AddChild(group)
 Local one:TBox = Box(group,-10,-5), two:TBox = Box(group,0,0)
 Local bounds:TSceneRect = New TSceneRect
 Check(group.GetContentBounds(bounds) And bounds.x = -10 And bounds.y = -5 And bounds.width = 30 And bounds.height = 25, "automatic negative content bounds without graphics")
 Local padding:TSceneChainStage = TSceneChainStage.Create(Null,3,4,5,6)
 group.SetStages([TSceneEffectStage(padding)])
 Check(group.GetOutputBounds(bounds) And bounds.x = -13 And bounds.y = -9 And bounds.width = 38 And bounds.height = 35, "output padding distinct from content")
 Local outer:TSceneNode2D = New TSceneNode2D
 layer.AddChild(outer)
 Local other:TCompositeNode = TCompositeNode.Create()
 outer.AddChild(other)
 Local rejected:Int
 Try
  other.SetStages([TSceneEffectStage(padding)])
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "stage cannot belong to two composites")
 rejected = False
 Try
  group.SetStages([TSceneEffectStage(padding),TSceneEffectStage(padding)])
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "duplicate attachment rejected")
 other.Destroy()
 Graphics(128,96)
 Local target:TRenderImage = CreateRenderImage(128,96,FILTEREDIMAGE)
 Local pixels:TPixmap = Render(scene,target)
 ' Filtered edge coverage may lose a few alpha units across capture/copy/presentation.
 ' Keep interior coverage exact and allow only the edge's alpha to vary.
 Local corner:Int=pixels.ReadPixel(49,44)
 Check(pixels.ReadPixel(21,21) = $ffffffff And (corner & $ffffff) = $ffffff And ((corner Shr 24) & 255) >= 251, "capture/presentation restore negative origin: "+pixels.ReadPixel(21,21)+", "+corner)
 Check(pixels.ReadPixel(19,19) = 0 And pixels.ReadPixel(50,45) = 0, "padding does not move source")
 Local stats:TSceneStats = scene.CaptureStats()
 Check(stats.Captures() = 1 And stats.StagePasses() = 1, "captures and stage diagnostics")
 group.SetCacheMode(ESceneCacheMode.Automatic)
 Local reference:TPixmap = Render(scene,target)
 ResetMax2DStats()
 pixels = Render(scene,target); scene.CopyStats(stats)
 Check(Same(reference,pixels), "automatic cache matches uncached pixels")
 Check(stats.Captures() = 0 And stats.StagePasses() = 0 And stats.CacheHits() = 1, "warm cache performs no processing")
 Check(CaptureMax2DStats().textureCreations = 0, "warm cache allocates no textures")
 one.SetProcessing(True); scene.Update(0.1)
 Check(one.updates = 1, "cached children still update")
 group.SetPosition(40,25)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 0, "moving composite reuses local pixels")
 Local camera:TCamera2D = New TCamera2D
 camera.x = 2; layer.SetCamera(camera)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 0, "layer camera change reuses local pixels")
 layer.SetCamera(Null)
 group.SetOpacity(0.5)
 pixels = Render(scene,target); scene.CopyStats(stats)
 Local edge:Int = Int((pixels.ReadPixel(31,21) Shr 24) & 255), overlap:Int = Int((pixels.ReadPixel(41,26) Shr 24) & 255)
 Check(Abs(edge-128) <= 1 And overlap = edge, "flattened opacity applied once across overlap ("+edge+","+overlap+")")
 Check(stats.Captures() = 0, "opacity changes presentation only")
 group.SetOpacity(1); group.SetAlpha(0.5)
 pixels = Render(scene,target); scene.CopyStats(stats)
 edge = Int((pixels.ReadPixel(31,21) Shr 24) & 255); overlap = Int((pixels.ReadPixel(41,26) Shr 24) & 255)
 Check(Abs(edge-128) <= 1 And overlap > edge+50, "inherited alpha remains per draw")
 Check(stats.Captures() = 1, "alpha invalidates captured pixels")
 group.SetAlpha(1)
 one.SetTint(255,0,0)
 pixels = Render(scene,target)
 Check(pixels.ReadPixel(31,21) = $ffff0000, "descendant tint invalidates cache")
 one.SetPosition(-8,-5)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1, "descendant transform invalidates cache")
 group.SetSortableChildren(True)
 one.SetZIndex(1)
 pixels = Render(scene,target)
 Check(pixels.ReadPixel(41,26) = $ffff0000, "sorting invalidates capture and preserves drawing order")
 one.SetZIndex(-1)
 pixels = Render(scene,target)
 Check(pixels.ReadPixel(41,26) = $ffffffff, "z-index changes invalidate enclosing capture")
 padding.Invalidate()
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 0 And stats.StagePasses() = 1, "attached stage revision reuses source capture")

 ' A changed suffix must preserve earlier results without changing rendered pixels.
 Local middle:TSceneChainStage = TSceneChainStage.Create(Null)
 Local last:TFailStage = New TFailStage
 group.SetStages([TSceneEffectStage(padding),TSceneEffectStage(middle),TSceneEffectStage(last)])
 Render(scene,target)
 last.Invalidate(); ResetMax2DStats()
 pixels = Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 0 And stats.StagePasses() = 1, "final stage edit reuses prefix")
 Check(CaptureMax2DStats().textureCreations = 0, "suffix refresh reuses textures")
 group.InvalidateEffects(); reference = Render(scene,target); scene.CopyStats(stats)
 Check(Same(reference,pixels) And stats.StagePasses() = 3, "suffix output matches explicit full refresh")
 last.fail = True; last.Invalidate()
 rejected = False
 Try
  Render(scene,target)
 Catch error:Object
  rejected = error.ToString() = "intentional stage failure"
 End Try
 Check(rejected And scene.RetainedStorageBytes() = 0 And TMax2DGraphics.Current().renderImage = target, "failed suffix releases prefix and restores target")
 last.fail = False; last.Invalidate()
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1 And stats.StagePasses() = 3, "failed suffix recovers with full capture and processing")
 last.Invalidate(); middle.Invalidate(); last.Invalidate()
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 0 And stats.StagePasses() = 2, "multiple edits retain earliest dirty stage")
 padding.Invalidate()
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 0 And stats.StagePasses() = 3, "first-stage edit refreshes every successor")
 one.InvalidateContent()
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1 And stats.StagePasses() = 3, "source change refreshes entire chain")
 group.SetResolutionScale(2)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1 And stats.StagePasses() = 3, "canvas change refreshes entire chain")
 group.SetResolutionScale(1)
 Render(scene,target)
 group.SetStages([TSceneEffectStage(last),TSceneEffectStage(middle),TSceneEffectStage(padding)])
 pixels = Render(scene,target); scene.CopyStats(stats)
 Check(stats.StagePasses() = 3, "reordering stages discards prefix")
 group.InvalidateEffects(); reference = Render(scene,target)
 Check(Same(reference,pixels), "reordered output matches full refresh")
 scene.ReleaseResources()
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1 And stats.StagePasses() = 3, "release discards all prefix outputs")
 group.SetStages([TSceneEffectStage(padding)])
 Render(scene,target)

 Local parent:TCompositeNode = TCompositeNode.Create()
 parent.SetCacheMode(ESceneCacheMode.Automatic)
 layer.AddChild(parent)
 group.Reparent(parent)
 Render(scene,target)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 0 And stats.CacheHits() = 1, "nested unchanged cache skips descendant traversal")
 padding.Invalidate()
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1 And stats.StagePasses() = 1, "child effect refreshes parent capture but reuses child source")
 group.SetPosition(45,25)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1 And stats.CacheHits() = 1, "child placement rebuilds enclosing capture only")
 group.SetOpacity(0.5)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1 And stats.CacheHits() = 1, "nested opacity rebuilds enclosing capture only")
 group.SetOpacity(1)
 group.SetCacheMode(ESceneCacheMode.None)
 Render(scene,target)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 2, "uncached descendant cannot be frozen by cached ancestor")
 group.SetCacheMode(ESceneCacheMode.Automatic)
 group.SetVisible(False)
 Render(scene,target)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 0, "hidden subtree no longer forces capture")
 group.SetVisible(True)
 parent.SetTint(0,255,0)
 pixels = Render(scene,target)
 Check((pixels.ReadPixel(46,26) & $00ffffff) = $0000ff00, "inherited tint captured once through nested groups")
 parent.SetTint(255,255,255)
 group.Reparent(layer)
 parent.Destroy()

 Local unknown:TBox = New TBox
 group.AddChild(unknown)
 rejected = False
 Try
  Render(scene,target)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected And Not scene.CaptureStats().Completed(), "unknown content requires explicit capture region")
 Check(TMax2DGraphics.Current().renderImage = target, "failed render restores parent target")
 group.SetCaptureRect(TSceneRect.Create(0,0,10,10))
 pixels = Render(scene,target)
 Check(pixels.ReadPixel(46,26) = $ffffffff And pixels.ReadPixel(56,26) = 0, "fixed capture clips before processing")
 unknown.Destroy(); group.ClearCaptureRect()
 one.fail = True; one.InvalidateContent()
 rejected = False
 Try
  Render(scene,target)
 Catch error:Object
  rejected = String(error) = "intentional child failure"
 End Try
 Check(rejected And TMax2DGraphics.Current().renderImage = target, "child exception restores capture and outer target")
 one.fail = False; one.InvalidateContent()
 Render(scene,target)
 Check(scene.CaptureStats().Completed(), "failed capture can recover")
 group.SetStorageLimitBytes(1)
 rejected = False
 Try
  Render(scene,target)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "resource limit checked before capture allocation")
 group.SetStorageLimitBytes(67108864)
 Render(scene,target)
 scene.ReleaseResources()
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1, "explicit resource release invalidates pixels")
 group.SetStages(Null)
 other = TCompositeNode.Create(); other.SetStages([TSceneEffectStage(padding)])
 other.Destroy()
 Check(True, "removed stage can be reused and destroyed elsewhere")

 group.SetResolutionScale(2)
 pixels = Render(scene,target)
 Check(pixels.ReadPixel(46,26) = $ffffffff, "resolution changes preserve logical placement")
 group.SetLocalTransform(TSceneTransform.Create(-1,0.25,0.2,1,70,25))
 layer.SetViewport(TSceneRect.Create(10,10,90,65))
 group.SetCacheMode(ESceneCacheMode.None)
 reference = Render(scene,target)
 group.SetCacheMode(ESceneCacheMode.Automatic)
 pixels = Render(scene,target)
 Check(Same(reference,pixels), "cache parity under shear negative scale and layer clipping")
 pixels = Render(scene,target)
 Check(Same(reference,pixels), "warm transformed output preserves clipping")
 group.SetTransform(45,25,0)
 layer.ClearViewport()
?max2d_gl Or max2d_sdlgpu Or max2d_d3d9 Or max2d_d3d11
 Local colour:TMax2DColorizeEffect = CreateColorizeEffect(0,255,0)
 Local chain:TSceneChainStage = TSceneChainStage.Create([TMax2DImageEffect(colour)],2,2,2,2)
 group.SetStages([TSceneEffectStage(chain)])
 pixels = Render(scene,target)
 Check(pixels.ReadPixel(46,26) = $ff00ff00, "shader stage processes composite capture")
 colour.SetColor(0,0,255); chain.Invalidate()
 pixels = Render(scene,target)
 Check(pixels.ReadPixel(46,26) = $ff0000ff, "shared effect edits invalidate attached composite")
 group.SetStages([TSceneEffectStage(TSceneChainStage.Create([TMax2DImageEffect(CreateOutlineEffect(4))],4,4,4,4))])
 group.SetResolutionScale(1); group.SetPosition(-21,20)
 scene.SetCulling(False); reference = Render(scene,target)
 scene.SetCulling(True); pixels = Render(scene,target)
 Check(Same(reference,pixels) And (pixels.ReadPixel(0,25) & $ff000000) <> 0, "offscreen source retains onscreen effect halo during culling")
 group.SetResolutionScale(1); group.SetPosition(45,25)
 Local maskPixels:TPixmap = CreatePixmap(2,2,PF_RGBA8888)
 maskPixels.ClearPixels($ffffffff); maskPixels.WritePixel(0,0,0)
 Local maskImage:TImage = LoadImage(maskPixels,0)
 Local bloom:TSceneBloomStage = TSceneBloomStage.Create(0.3,4,0.5)
 Local maskStage:TSceneAlphaMaskStage = TSceneAlphaMaskStage.Create(maskImage,TSceneRect.Create(-8,-8,32,32))
 group.SetStages([TSceneEffectStage(bloom),TSceneEffectStage(maskStage)])
 reference = Render(scene,target)
 maskStage.SetMaskRect(TSceneRect.Create(0,0,24,24)); ResetMax2DStats()
 pixels = Render(scene,target); scene.CopyStats(stats)
 Check(Not Same(reference,pixels), "moving final mask visibly changes bloom output")
 Check(stats.Captures() = 0 And stats.StagePasses() = 1 And CaptureMax2DStats().textureCreations = 0, "moving mask retains bloom output and textures")
 group.InvalidateEffects(); reference = Render(scene,target)
 Check(Same(reference,pixels), "retained bloom and edited mask match full processing pixel for pixel")
 bloom.SetRadius(8)
 pixels = Render(scene,target); scene.CopyStats(stats)
 Check(stats.Captures() = 1 And stats.StagePasses() = 2, "stage padding change rebuilds canvas and whole chain")
 group.InvalidateEffects(); reference = Render(scene,target)
 Check(Same(reference,pixels), "expanded bloom output matches full processing")
 group.SetStages(Null); maskImage.ReleaseFrames()
 group.SetResolutionScale(2)
?
 scene.SetCulling(True)
 group.SetPosition(500,500)
 Render(scene,target); scene.CopyStats(stats)
 Check(stats.CulledSubtrees() > 0 And stats.Captures() = 0, "output bounds cull composite before capture")
 group.SetPosition(45,25)
 Render(scene,target)
 Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
 For Local i:Int = 0 Until 100
  scene.Render(); canvas.context.Flush()
 Next
 Local before:SGCStats, after:SGCStats
 GCCollect(); GCGetStats(before)
 For Local i:Int = 0 Until 100
  scene.Render(); canvas.context.Flush()
 Next
 GCGetStats(after)
 Local small:ULongInt = (after.allocedBytesBeforeGC+after.bytesAllocedSinceGC)-(before.allocedBytesBeforeGC+before.bytesAllocedSinceGC)
 For Local i:Int = 0 Until 1000
  Box(group,0,0)
 Next
 scene.Render(); canvas.context.Flush()
 GCCollect(); GCGetStats(before)
 For Local i:Int = 0 Until 100
  scene.Render(); canvas.context.Flush()
 Next
 GCGetStats(after)
 Local large:ULongInt = (after.allocedBytesBeforeGC+after.bytesAllocedSinceGC)-(before.allocedBytesBeforeGC+before.bytesAllocedSinceGC)
 Print "100 cached renders: small "+small+" GC bytes; 1,000 extra children "+large+" GC bytes"
 Check(small = large, "cached subtree size adds no warm allocation")
?max2d_d3d9 Or max2d_d3d11
 ' Native Direct3D providers currently support one live window.
 rejected = False
 Try
  canvas.driver.CreateGraphics(128,96,0,0,0,-1,-1)
 Catch error:Object
  rejected = error.ToString().Contains("only one window")
 End Try
 Check(rejected, "native Direct3D rejects a second live window explicitly")
?Not max2d_d3d9 And Not max2d_d3d11
 Local otherGraphics:TGraphics = CreateGraphics(128,96,0,0,0,-1,-1)
 SetGraphics(otherGraphics)
 rejected = False
 Try
  scene.Render()
 Catch error:Object
  rejected = True
 End Try
 Check(rejected And Not scene.CaptureStats().Completed(), "live context migration requires resource release and leaves failed stats")
 SetGraphics(canvas)
 scene.ReleaseResources()
 SetGraphics(otherGraphics)
 scene.Render()
 Check(scene.CaptureStats().Captures() = 1, "released scene can prepare on another live context")
 scene.ReleaseResources()
 SetGraphics(canvas)
 CloseGraphics(otherGraphics)
?
 Render(scene,target)
 SetRenderImage(Null); target.ReleaseFrames()
 EndGraphics
 Graphics(128,96)
 scene.Render()
 Check(scene.CaptureStats().Completed(), "closed context resources recreated on next render")
 scene.Destroy(); EndGraphics
 Print "PASS: "+checks+" scene composite checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndGraphics
 EndWithCode(1)
End Try
