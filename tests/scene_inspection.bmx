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

Type TDiagnosticBox Extends TCustomDrawNode
 Field draws:Int
 Method OnDraw(context:TSceneDrawContext)
  draws :+ 1
  DrawRect(0,0,20,20)
 End Method
End Type
Type TBrokenBounds Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
 End Method
 Method GetSelfBounds:Int(rect:TSceneRect) Override
  Throw "intentional debug bounds failure"
 End Method
End Type

Try
 Local scene:TScene = TScene.Create(), layer:TLayerNode = TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local group:TCompositeNode = TCompositeNode.Create()
 group.SetName("cached panel"); group.SetCacheMode(ESceneCacheMode.Automatic)
 group.SetPosition(20,20); layer.AddChild(group)
 Local box:TDiagnosticBox = New TDiagnosticBox
 box.SetName("button"); box.SetSelfBounds(TSceneRect.Create(0,0,20,20))
 box.SetInteractive(True); box.SetHitRect(TSceneRect.Create(-3,-3,26,26)); group.AddChild(box)
 Local description:String = scene.InspectTree()
 Check(description.Contains("root/0/0") And description.Contains("cached panel") And description.Contains("TCustomDrawNode"), "inspection names categories and paths without graphics")
 Check(description.Contains("boundsDirty=1") And description = scene.InspectTree(), "inspection does not resolve dirty caches")
 Check(box.draws = 0 And Not scene.CaptureStats().Completed(), "inspection does not draw or change render stats")
 Graphics(128,96)
 Local target:TRenderImage = CreateRenderImage(128,96,FILTEREDIMAGE)
 SetRenderImage(target); SetViewport(0,0,128,96)
 scene.SetInputClip(TSceneRect.Create(0,0,128,96))
 scene.Render(); scene.Render()
 Local before:TSceneStats = scene.CaptureStats()
 Local picked:TSceneNode2D = scene.Pick(25,25)
 Check(picked = box, "baseline picking")
 SetClsColor(8,12,16); Cls
 SetColor(23,45,67); SetAlpha(0.4); SetOrigin(7,9); SetBlend(LIGHTBLEND)
 scene.SetDebugOverlay(True); scene.Render()
 Local after:TSceneStats = scene.CaptureStats()
 Check(after.Captures() = 0 And after.CacheHits() = 1 And box.draws = 1, "overlay traverses cached children without recapturing or invoking drawing")
 Check(before.NodesVisited() = after.NodesVisited() And before.DrawVisits() = after.DrawVisits() And after.BoundsRebuilds() = before.BoundsRebuilds(), "overlay excluded from scene statistics")
 Local r:Int,g:Int,b:Int,ox:Float,oy:Float
 GetColor(r,g,b); GetOrigin(ox,oy)
 Check(r = 23 And g = 45 And b = 67 And Abs(GetAlpha()-0.4) < 0.00001 And GetBlend() = LIGHTBLEND And ox = 7 And oy = 9, "overlay restores caller state")
 Check(TMax2DGraphics.Current().renderImage = target And scene.Pick(25,25) = picked, "overlay preserves target and picking")
 Local pixels:TPixmap = ReadRenderImage(target)
 Local green:Int
 For Local y:Int = 15 Until 45
  For Local x:Int = 15 Until 45
   Local pixel:UInt = pixels.ReadPixel(x,y)
   If (pixel & $ffffff) = $3cff64 Then green :+ 1
  Next
 Next
 Check(green > 20, "hit outline appears around cached child")
 scene.SetDebugOverlay(False); SetOrigin(0,0); SetAlpha(1); SetBlend(ALPHABLEND); Cls
 scene.Render(); pixels = ReadRenderImage(target)
 Check(pixels.ReadPixel(17,17) = $ff080c10, "debug outlines were not baked into cached pixels")
 ' The final layer's viewport must not restrict earlier layers' overlay.
 Local other:TLayerNode = TLayerNode.Create(); scene.Root().AddChild(other)
 other.SetViewport(TSceneRect.Create(90,0,20,96))
 Local otherBox:TDiagnosticBox = New TDiagnosticBox
 otherBox.SetSelfBounds(TSceneRect.Create(0,0,20,20)); otherBox.SetPosition(95,20); other.AddChild(otherBox)
 scene.SetDebugOverlay(True); Cls; scene.Render(); pixels = ReadRenderImage(target)
 Check((pixels.ReadPixel(17,20) & $ffffff) = $3cff64, "overlay uses original viewport independently for each layer")
 Check(pixels.ReadPixel(115,20) = $ff080c10, "layer clip also clips overlay")
 group.SetLocalTransform(TSceneTransform.Create(-1,0.5,0,1,70,20))
 Local camera:TCamera2D = New TCamera2D
 camera.offsetX = 4; camera.offsetY = 6; layer.SetCamera(camera)
 Cls; scene.Render(); pixels = ReadRenderImage(target)
 green = 0
 For Local y:Int = 35 To 37
  For Local x:Int = 81 To 83
   If (pixels.ReadPixel(x,y) & $ffffff) = $3cff64 Then green :+ 1
  Next
 Next
 Check(green > 0 And scene.CaptureStats().Captures() = 0, "overlay follows shear negative scale and camera outside cached source")
 Local unknown:TCustomDrawNode = New TCustomDrawNode
 unknown.SetPosition(5,65); other.AddChild(unknown); other.ClearViewport()
 Cls; scene.Render(); pixels = ReadRenderImage(target)
 Check((pixels.ReadPixel(5,65) & $ffffff) = $ff3cdc, "unknown bounds marked at transformed origin")
 unknown.Destroy()
 Local broken:TBrokenBounds = New TBrokenBounds; layer.AddChild(broken)
 Local rejected:Int
 Try
  scene.Render()
 Catch error:Object
  rejected = True
 End Try
 Check(rejected And Not scene.CaptureStats().Completed() And TMax2DGraphics.Current().renderImage = target, "overlay failure restores target and reports incomplete render")
 broken.Destroy(); scene.SetDebugOverlay(False); scene.Render()
 Check(scene.CaptureStats().Completed(), "scene recovers after overlay failure")
 scene.Destroy(); SetRenderImage(Null); EndGraphics
 Print "PASS: "+checks+" scene inspection checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics
 EndWithCode(1)
End Try
