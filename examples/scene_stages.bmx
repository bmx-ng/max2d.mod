SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.SceneEffects
Import BRL.StandardIO

Type TEmblem Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(35,175,240); DrawOval(0,0,120,120)
  context.SetColor(255,160,45); DrawRect(65,35,90,50)
  context.SetColor(245,245,255); DrawOval(25,25,35,35)
 End Method
End Type

Graphics(760,360)
Local scene:TScene = TScene.Create(), view:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(view)
Local emblem:TEmblem = New TEmblem
emblem.SetSelfBounds(TSceneRect.Create(0,0,155,120))
view.AddChild(emblem)

' Explicit scene capture for now; automatic composite nodes will build on stages.
Local effect:TMax2DSaturationEffect = CreateSaturationEffect(0)
Local stage:TSceneChainStage = TSceneChainStage.Create([TMax2DImageEffect(effect)],12,12,12,12)
Local bounds:TSceneRect = TSceneRect.Create(0,0,155,120)
stage.ExpandBounds(bounds,bounds)
Local layout:TSceneStageLayout = TSceneStageLayout.Create(bounds,2)
layout.CopyCanvasRect(bounds)
Local capture:TMax2DEffectLayer = New TMax2DEffectLayer
capture.Prepare(Int(bounds.width),Int(bounds.height),0,0,0,0,layout.ResolutionScale())
Local camera:TCamera2D = New TCamera2D
camera.offsetX = -bounds.x; camera.offsetY = -bounds.y
view.SetCamera(camera)
Using
 Local scope:TMax2DStateScope = capture.Capture()
Do
 scene.Render()
End Using
stage.Prepare(layout)
Local processed:TRenderImage = stage.Update(capture.Image())
Local applied:Long = stage.Revision(), saturated:Int
Local testMode:Int = AppArgs.Length > 1 And AppArgs[1] = "--test", frames:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 If KeyHit(KEY_SPACE) Then
  saturated = Not saturated
  effect.SetAmount(Float(saturated))
  stage.Invalidate()
 End If
 If applied <> stage.Revision() Then
  processed = stage.Update(capture.Image())
  applied = stage.Revision()
 End If
 SetClsColor(12,20,32); Cls
 SetColor(230,240,250)
 DrawText("SCENE EFFECT STAGES",40,25)
 DrawText("Shared scene capture",70,75)
 DrawText("Retained effect output",420,75)
 capture.Draw(70+bounds.x,110+bounds.y)
 capture.Draw(420+bounds.x,110+bounds.y,processed)
 DrawText("SPACE changes saturation; only the effect is processed again.",40,280)
 DrawText("Capture and textures are reused. ESC exits.",40,310)
 Flip
 frames :+ 1
 If testMode And frames = 3 Then Exit
Wend
stage.ReleaseResources(); capture.Release(); scene.Destroy()
EndGraphics
If testMode Then Print "PASS: scene stage example"
