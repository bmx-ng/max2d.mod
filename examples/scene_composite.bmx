SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.SceneEffects
Import Max2D.ScalableFont
Import BRL.FileSystem
Import Pub.StdC
Import BRL.StandardIO

Type TDisc Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  DrawOval(0,0,100,100)
 End Method
End Type
Function Disc:TDisc(parent:TSceneNode,x:Float,y:Float,r:Int,g:Int,b:Int)
 Local node:TDisc = New TDisc
 node.SetSelfBounds(TSceneRect.Create(0,0,100,100))
 node.SetInteractive(True); node.SetHitRect(TSceneRect.Create(8,8,84,84))
 node.SetPosition(x,y); node.SetTint(r,g,b); parent.AddChild(node)
 Return node
End Function

AppTitle = "Max2D Scene / Composite caches"
Graphics(960,600)
SetVirtualResolution(960,600,VIRTUAL_LETTERBOX)
Local path:String
?osx
path = "/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
path = getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TImageFont = TImageFont.DefaultFont(), title:TImageFont = font
If FileType(path) = FILETYPE_FILE Then
 font = LoadScalableImageFont(path,18); title = LoadScalableImageFont(path,30)
End If
Local scene:TScene = TScene.Create(), layer:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(layer)
scene.SetStorageLimitBytes(32*1024*1024)
scene.SetInputClip(TSceneRect.Create(0,0,960,600))
Local ordinary:TSceneNode2D = New TSceneNode2D
ordinary.SetAlpha(0.6)
Local flattened:TCompositeNode = TCompositeNode.Create(), effected:TCompositeNode = TCompositeNode.Create()
flattened.SetName("Flattened circles"); effected.SetName("Effect circles")
flattened.SetOpacity(0.6); effected.SetOpacity(0.6)
flattened.SetCacheMode(ESceneCacheMode.Automatic); effected.SetCacheMode(ESceneCacheMode.Automatic)
flattened.SetResolutionScale(2); effected.SetResolutionScale(2)
Local saturation:TMax2DSaturationEffect = CreateSaturationEffect(0)
Local stage:TSceneChainStage = TSceneChainStage.Create([TMax2DImageEffect(saturation)],4,4,4,4)
effected.SetStages([TSceneEffectStage(stage)])
Local bloom:TSceneBloomStage = TSceneBloomStage.Create(0.4,8,1)
Local resolution:Int = 2
Local bloomEnabled:Int
Local groups:TSceneNode2D[] = [ordinary,TSceneNode2D(flattened),TSceneNode2D(effected)]
Local moving:TDisc[3]
For Local i:Int = 0 Until groups.Length
 layer.AddChild(groups[i])
 Disc(groups[i],-75,-55,35,185,245)
 Disc(groups[i],-20,-25,255,155,45)
 moving[i] = Disc(groups[i],-45,-10,190,95,235)
Next
Local stats:TSceneStats = New TSceneStats
Local animated:Int, cached:Int = True, coloured:Int, frames:Int
Local testMode:Int = AppArgs.Length > 1 And AppArgs[1] = "--test"
Local start:Int = MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 If KeyHit(KEY_D) Then scene.SetDebugOverlay(Not scene.GetDebugOverlay())
 If KeyHit(KEY_I) Then Print scene.InspectTree()
 If KeyHit(KEY_S) Then
  resolution = 3-resolution
  flattened.SetResolutionScale(resolution); effected.SetResolutionScale(resolution)
 End If
 If KeyHit(KEY_O) Then bloom.SetOpaqueBackground(Not bloom.GetOpaqueBackground())
 If KeyHit(KEY_B) Then
  bloomEnabled = Not bloomEnabled
  If bloomEnabled Then
   effected.SetStages([TSceneEffectStage(bloom)])
  Else
   effected.SetStages([TSceneEffectStage(stage)])
  End If
 End If
 If KeyHit(KEY_A) Then animated = Not animated
 If KeyHit(KEY_SPACE) Then
  coloured = Not coloured; saturation.SetAmount(Float(coloured)); stage.Invalidate()
 End If
 If KeyHit(KEY_C) Then
  cached = Not cached
  Local mode:ESceneCacheMode = ESceneCacheMode.None
  If cached Then mode = ESceneCacheMode.Automatic
  flattened.SetCacheMode(mode); effected.SetCacheMode(mode)
 End If
 If KeyHit(KEY_R) Then scene.ReleaseResources()
 Local t:Float = (MilliSecs()-start)*0.001
 If bloomEnabled Then bloom.SetIntensity(Float(1+Sin(t*100)*0.75))
 For Local i:Int = 0 Until groups.Length
  groups[i].SetTransform(170+310*i,280,Float(Sin(t*35)*12))
  If animated Then moving[i].SetPosition(Float(-45+Sin(t*90)*20),-10)
 Next
 SetClsColor(10,18,29); Cls
 scene.Render(); scene.CopyStats(stats)
 SetColor(230,240,250); SetAlpha(1); SetImageFont(title)
 DrawText("COMPOSITE CACHES",35,28)
 SetImageFont(font)
 If scene.GetDebugOverlay() Then
  DrawText("Bounds: cyan content / yellow output / green hit / magenta unknown",35,78)
 Else
  DrawText("Parent motion reuses pixels. Child motion invalidates captures.",35,78)
 End If
 DrawText("Per-draw alpha",95,145)
 DrawText("Flattened opacity",395,145)
 DrawText("Flattened + effect",705,145)
 DrawText("Captures: "+stats.Captures()+"    Cache hits: "+stats.CacheHits()+"    Stage updates: "+stats.StagePasses(),35,435)
 Local cacheLabel:String = "every render"
 If cached Then cacheLabel = "automatic"
 Local animationLabel:String = "off"
 If animated Then animationLabel = "on"
 DrawText("Cache: "+cacheLabel+"    Child animation: "+animationLabel+"    Resolution: "+resolution+"x",35,465)
 DrawText("Texture KiB: "+stats.RetainedStorageBytes()/1024+"    Peak: "+stats.PeakStorageBytes()/1024+"    Budget: "+scene.GetStorageLimitBytes()/1024,35,495)
 DrawText("A: animate child    C: cache mode    SPACE: saturation    B: bloom    R: release",35,530)
 DrawText("D: bounds    I: inspect tree    S: resolution    O: opaque bloom    ESC: exit",35,555)
 Flip
 frames :+ 1
 If testMode And frames = 3 Then Exit
Wend
scene.Destroy(); EndGraphics
If testMode Then Print "PASS: composite example"
