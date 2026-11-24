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

Type TGlowRect Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  DrawRect(0,0,32,32)
 End Method
End Type

Try
 Local stage:TSceneBloomStage = TSceneBloomStage.Create(0.25,8,1)
 Check(Not stage.GetOpaqueBackground(), "scene bloom defaults to transparent")
 Local rect:TSceneRect = TSceneRect.Create(0,0,32,32)
 stage.ExpandBounds(rect,rect)
 Check(rect.x = -18 And rect.width = 68, "logical bloom padding")
 Local layout:TSceneStageLayout = TSceneStageLayout.Create(TSceneRect.Create(0,0,32,32),2)
 ' Radius 16 pixels needs two levels: 64, 32, 16 plus 16 scratch.
 Check(stage.EstimateStorageBytes(layout) = (3*64*64+32*32+2*16*16)*4, "pyramid storage estimate")
 Graphics(128,128)
 Local source:TRenderImage = CreateRenderImage(64,64,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope = ScopedMax2DState()
 Do
  SetRenderImage(source); SetClsColor(0,0,0,0); Cls
  SetColor(255,255,255); DrawRect(24,24,16,16)
  SetBlend(SOLIDBLEND); SetAlpha(0.5); SetColor(255,80,30); DrawRect(28,28,4,4)
 End Using
 Local rejected:Int
 Try
  stage.Prepare(layout)
 Catch error:Object
  rejected = True
 End Try
?max2d_gl Or max2d_sdlgpu Or max2d_d3d9 Or max2d_d3d11
 Check(Not rejected, "bloom prepares with provider")
 Local result:TRenderImage = stage.Update(source)
 Local raw:TMax2DBloom = CreateBloom(0.25,16,1)
 Check(raw.GetOpaqueBackground(), "standalone bloom retains opaque default")
 raw.SetOpaqueBackground(False)
 raw.Prepare(64,64,2,PF_RGBA8888)
 Local expected:TPixmap = ReadRenderImage(raw.Update(source)), actual:TPixmap = ReadRenderImage(result)
 Local same:Int = True
 For Local y:Int = 0 Until 64
  For Local x:Int = 0 Until 64
   If expected.ReadPixel(x,y) <> actual.ReadPixel(x,y) Then same = False
  Next
 Next
 Check(same, "adapter matches existing bloom at scaled radius")
 Check((actual.ReadPixel(0,0) Shr 24 & 255) = 0, "unused padded canvas remains transparent")
 Check((ReadRenderImage(source).ReadPixel(0,0) Shr 24 & 255) = 0, "source transparency preserved")
 Local halo:Int
 For Local y:Int = 12 Until 52
  For Local x:Int = 12 Until 52
   If x >= 24 And x < 40 And y >= 24 And y < 40 Then Continue
   Local pixel:UInt = actual.ReadPixel(x,y)
   If (pixel Shr 24 & 255) > 0 And (pixel & $ffffff) <> 0 Then halo = True
  Next
 Next
 Check(halo, "transparent halo carries colour and alpha outside source")
 Local background:TRenderImage = CreateRenderImage(64,64,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope = ScopedMax2DState()
 Do
  SetRenderImage(background); SetClsColor(30,80,120); Cls
  SetBlend(ALPHABLEND); DrawImage(result,0,0)
 End Using
 Check(ReadRenderImage(background).ReadPixel(0,0) = $ff1e5078, "transparent padding leaves coloured background intact")
 stage.SetIntensity(0); stage.Prepare(layout)
 Local zero:TPixmap = ReadRenderImage(stage.Update(source))
 ' A zero effect must match an ordinary source copy. Compare identical sampling
 ' paths, so byte-target filtering/unpremultiplication precision cancels out.
 Using
  Local scope:TMax2DStateScope = ScopedMax2DState()
 Do
  SetRenderImage(background); SetVirtualResolution(64,64); SetViewport(0,0,64,64)
  SetCamera(Null); ResetCoordinates(); SetTransform(0,1,1); SetOrigin(0,0); SetHandle(0,0)
  SetColor(255,255,255); SetAlpha(1); SetBlend(SOLIDBLEND)
  DrawImage(source,0,0)
 End Using
 Local copied:TPixmap = ReadRenderImage(background)
 same = True
 For Local y:Int = 0 Until 64
  For Local x:Int = 0 Until 64
   If zero.ReadPixel(x,y) <> copied.ReadPixel(x,y) Then same = False
  Next
 Next
 Check(same, "zero bloom matches ordinary source copy including partial alpha")
 stage.SetOpaqueBackground(True); stage.Prepare(layout)
 Check((ReadRenderImage(stage.Update(source)).ReadPixel(0,0) Shr 24 & 255) = 255, "explicit opaque mode fills padding")
 stage.SetOpaqueBackground(False)
 ResetMax2DStats()
 stage.SetIntensity(0.5)
 Check(stage.EstimatePreparationBytes(layout) = 0, "intensity reuses storage")
 stage.Prepare(layout)
 Check(stage.Update(source) = result And CaptureMax2DStats().textureCreations = 0, "warm effect edit allocates no textures")
 stage.SetRadius(2)
 Check(stage.EstimatePreparationBytes(layout) > 0, "pyramid change accounts for replacement storage")
 stage.Prepare(layout); stage.Update(source)
 raw.Release()
 Local scene:TScene = TScene.Create()
 Local layer:TLayerNode = TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local group:TCompositeNode = TCompositeNode.Create()
 group.SetCacheMode(ESceneCacheMode.Automatic)
 layer.AddChild(group)
 Local box:TGlowRect = New TGlowRect
 box.SetSelfBounds(TSceneRect.Create(0,0,32,32)); group.AddChild(box)
 Local attached:TSceneBloomStage = TSceneBloomStage.Create(0.25,8,1)
 group.SetStages([TSceneEffectStage(attached)])
 Local bounds:TSceneRect = TSceneRect.Create(0,0,32,32)
 attached.ExpandBounds(bounds,bounds)
 Local tight:TSceneStageLayout = TSceneStageLayout.Create(bounds)
 group.SetStorageLimitBytes(tight.EstimateImageBytes()+attached.EstimateStorageBytes(tight))
 scene.Render()
 attached.SetIntensity(0.5)
 ResetMax2DStats()
 scene.Render()
 Local stats:TSceneStats = scene.CaptureStats()
 Check(stats.Captures() = 0 And stats.StagePasses() = 1, "intensity reuses composite source at exact storage budget")
 Check(CaptureMax2DStats().textureCreations = 0, "composite intensity change allocates no textures")
 attached.SetOpaqueBackground(True)
 scene.Render(); scene.CopyStats(stats)
 Check(stats.Captures() = 0 And stats.StagePasses() = 1, "composition mode reuses captured source")
 group.SetStorageLimitBytes(67108864)
 attached.SetRadius(12)
 scene.Render(); scene.CopyStats(stats)
 Check(stats.Captures() = 1, "radius padding change recaptures composite")
 scene.Destroy()
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
 Check(rejected, "missing bloom provider rejected during preparation")
 Check(TMax2DGraphics.Current().renderImage = Null, "failure restores target")
?
 stage.ReleaseResources(); stage.ReleaseResources()
 EndGraphics()
 Print "PASS: " + checks + " scene bloom checks"
Catch error:Object
 Print "FAIL: " + error.ToString()
 EndGraphics
 EndWithCode(1)
End Try
