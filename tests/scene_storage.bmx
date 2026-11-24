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
Function Check(ok:Int, message:String)
 If Not ok Then Throw message
 checks :+ 1
End Function

Type TFailingStorageStage Extends TSceneChainStage
 Field failPrepare:Int = True, failRelease:Int = True
 Method Prepare(layout:TSceneStageLayout) Override
  Super.Prepare(layout)
  If failPrepare Then Throw "intentional preparation failure"
 End Method
 Method ReleaseResources() Override
  If failRelease Then Throw "intentional release failure"
  Super.ReleaseResources()
 End Method
End Type

Try
 Graphics(128,128)
 Local scene:TScene = TScene.Create(), layer:TLayerNode = TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local first:TCompositeNode = TCompositeNode.Create(), second:TCompositeNode = TCompositeNode.Create()
 first.SetName("first panel"); second.SetName("second panel")
 first.SetCacheMode(ESceneCacheMode.Automatic); second.SetCacheMode(ESceneCacheMode.Automatic)
 first.SetCaptureRect(TSceneRect.Create(0,0,16,16)); second.SetCaptureRect(TSceneRect.Create(0,0,16,16))
 layer.AddChild(first); layer.AddChild(second)
 scene.SetStorageLimitBytes(1024)
 Local rejected:Int, message:String
 Try
  scene.Render()
 Catch error:Object
  rejected = True; message = error.ToString()
 End Try
 Check(rejected And message.Contains("second panel") And message.Contains("1024") And message.Contains("root/0/1"), "shared budget identifies rejected group and limit")
 Check(scene.RetainedStorageBytes() = 1024, "rejection leaves first group's storage charged")
 Local stats:TSceneStats = scene.CaptureStats()
 Check(Not stats.Completed() And stats.RetainedStorageBytes() = 1024 And stats.PeakStorageBytes() = 1024, "failure snapshot counts accepted reservations only")
 scene.SetStorageLimitBytes(2048); scene.Render(); scene.CopyStats(stats)
 Check(stats.Completed() And stats.RetainedStorageBytes() = 2048 And stats.PeakStorageBytes() = 2048, "two captures fit shared budget exactly")
 ResetMax2DStats(); scene.Render(); scene.CopyStats(stats)
 Check(stats.CacheHits() = 2 And stats.PeakStorageBytes() = 2048 And CaptureMax2DStats().textureCreations = 0, "warm caches retain accounting without allocations")
 rejected = False
 Try
  scene.SetStorageLimitBytes(100)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected And scene.GetStorageLimitBytes() = 2048, "cannot shrink budget below existing ownership")
 second.SetVisible(False); scene.Render()
 Check(scene.RetainedStorageBytes() = 2048, "hidden group stays charged")
 second.SetVisible(True)
 ' Final ownership would fit 3072, but replacement needs old 1024 plus new 2048.
 scene.SetStorageLimitBytes(3072)
 second.SetCaptureRect(TSceneRect.Create(0,0,32,16))
 ResetMax2DStats(); rejected = False
 Try
  scene.Render()
 Catch error:Object
  rejected = True
 End Try
 Check(rejected And CaptureMax2DStats().textureCreations = 0, "replacement peak rejected before allocating")
 Check(scene.RetainedStorageBytes() = 1024, "failed composite cleanup returns its previous reservation")
 scene.SetStorageLimitBytes(4096); scene.Render()
 Check(scene.RetainedStorageBytes() = 3072, "retry succeeds after failed preparation cleanup")
 second.SetCaptureRect(TSceneRect.Create(0,0,16,16)); scene.Render(); scene.CopyStats(stats)
 Check(stats.RetainedStorageBytes() = 2048 And stats.PeakStorageBytes() = 4096, "successful resize tracks peak separately from final ownership")
 first.SetStages([TSceneEffectStage(TSceneChainStage.Create(Null))]); scene.Render()
 Check(scene.RetainedStorageBytes() = 3072, "stage output charged in addition to captures")
 first.SetStages(Null)
 Check(scene.RetainedStorageBytes() = 2048, "removed stage immediately returns budget")
 layer.RemoveChild(second)
 Check(scene.RetainedStorageBytes() = 2048, "detached capture remains charged")
 scene.ReleaseResources()
 Check(scene.RetainedStorageBytes() = 0, "release includes detached registered storage")
 layer.AddChild(second); scene.Render()
 Check(scene.RetainedStorageBytes() = 2048, "released groups rebuild with fresh accounting")
 second.Destroy()
 Check(scene.RetainedStorageBytes() = 1024, "destroy returns group budget")
 layer.RemoveChild(first); scene.Destroy()
 Check(scene.RetainedStorageBytes() = 0, "scene destroy releases detached storage without destroying detached nodes")
 Local nextScene:TScene = TScene.Create(), nextLayer:TLayerNode = TLayerNode.Create()
 nextScene.Root().AddChild(nextLayer); nextLayer.AddChild(first); nextScene.Render()
 Check(nextScene.RetainedStorageBytes() = 1024, "released detached group reusable in another scene")
 Local outer:TCompositeNode = TCompositeNode.Create()
 outer.SetName("outer panel"); outer.SetCacheMode(ESceneCacheMode.Automatic)
 nextLayer.AddChild(outer); first.Reparent(outer)
 nextScene.SetStorageLimitBytes(2048); nextScene.Render(); nextScene.CopyStats(stats)
 Check(stats.RetainedStorageBytes() = 2048 And stats.Captures() = 1 And stats.CacheHits() = 1, "nested caches share the scene budget without double charging child storage")
 nextScene.ReleaseResources()
 Check(nextScene.RetainedStorageBytes() = 0, "nested release returns all ownership")
 nextScene.Destroy()
 Local failingScene:TScene = TScene.Create(), failingLayer:TLayerNode = TLayerNode.Create()
 failingScene.Root().AddChild(failingLayer)
 Local failingGroup:TCompositeNode = TCompositeNode.Create()
 failingGroup.SetCaptureRect(TSceneRect.Create(0,0,16,16)); failingLayer.AddChild(failingGroup)
 Local failingStage:TFailingStorageStage = New TFailingStorageStage
 failingGroup.SetStages([TSceneEffectStage(failingStage)])
 rejected = False
 Try
  failingScene.Render()
 Catch error:Object
  rejected = True
 End Try
 Check(rejected And failingScene.RetainedStorageBytes() = 2048, "failed custom cleanup retains full preparation reservation")
 failingStage.failPrepare = False; failingStage.failRelease = False
 failingScene.ReleaseResources()
 Check(failingScene.RetainedStorageBytes() = 0, "retrying custom cleanup returns retained reservation")
 failingScene.Render()
 Check(failingScene.RetainedStorageBytes() = 2048, "custom stage recovers after explicit cleanup")
 failingScene.Destroy(); EndGraphics
 Print "PASS: "+checks+" scene storage checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics
 EndWithCode(1)
End Try
