' Deterministic integration checks using the same component as the interactive demo.
Function WorkshopCheck(condition:Int, message:String)
 If Not condition Then Throw "FAIL: "+message
End Function

Function RunWorkshopTests(scene:TScene, layer:TLayerNode, reactors:TWorkshopReactor[])
 Local stats:TSceneStats = New TSceneStats
 scene.Render(); scene.CopyStats(stats)
 WorkshopCheck(stats.Captures() = 3,"cold capture")
 scene.Update(0.1); scene.Render(); scene.CopyStats(stats)
 WorkshopCheck(stats.Captures() = 1,"only rotating source recaptures")
 WorkshopCheck(stats.StagePasses() = 2,"pulse and spin process effects")
 WorkshopCheck(stats.CacheHits() = 1,"moving subtree reuses output")
 For Local reactor:TWorkshopReactor = EachIn reactors
  reactor.SetMode(REACTOR_STILL)
 Next
 scene.Render()
 scene.Render(); scene.CopyStats(stats)
 WorkshopCheck(stats.Captures() = 0 And stats.CacheHits() = 3,"still components reuse outputs")
 reactors[0].SetPower(5)
 scene.Render(); scene.CopyStats(stats)
 WorkshopCheck(stats.Captures() = 0 And stats.StagePasses() = 1 And stats.CacheHits() = 2,"power affects only one effect")
 Local retained:Long = scene.RetainedStorageBytes()
 reactors[1].SetResolution(2)
 scene.Render(); scene.CopyStats(stats)
 WorkshopCheck(stats.Captures() = 1,"resolution recaptures one source")
 WorkshopCheck(scene.RetainedStorageBytes() > retained,"higher resolution reserves more storage")
 reactors[2].SetCached(False)
 scene.Render()
 scene.Render(); scene.CopyStats(stats)
 WorkshopCheck(stats.Captures() = 1,"uncached source draws each frame")
 reactors[2].SetCached(True)
 scene.Render()
 layer.RemoveChild(reactors[0]); layer.AddChild(reactors[0])
 scene.Render(); scene.CopyStats(stats)
 WorkshopCheck(stats.Captures() = 0,"reattachment retains source")
 scene.ReleaseResources()
 WorkshopCheck(scene.RetainedStorageBytes() = 0,"explicit release empties scene storage")
 scene.Render(); scene.CopyStats(stats)
 WorkshopCheck(stats.Captures() = 3,"released components rebuild")
 Print "PASS: Reactor Workshop capture, effect, isolation and resource checks"
End Function
