SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
Import Max2D.SceneEffects

' Move the mouse to change shadow direction. Escape closes the example.
Type TShadowCard Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(90,180,220)
  DrawRect(0,0,160,100)
  context.SetColor(235,245,255)
  DrawOval(48,18,64,64)
 End Method
End Type
Graphics(720,360)
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local stages:TSceneShadowStage[]=[TSceneShadowStage.Create(8,8,8),TSceneShadowStage(TSceneInnerShadowStage.Create(8,8,8))]
For Local i:Int=0 Until 2
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetPosition(100+i*340,120)
 group.SetCacheMode(ESceneCacheMode.Automatic)
 ' Fixed stage padding and capture bounds keep the canvas stable during animation.
 stages[i].SetPadding(50)
 group.SetCaptureRect(TSceneRect.Create(0,0,160,100))
 group.SetStages([TSceneEffectStage(stages[i])]);layer.AddChild(group)
 Local card:TShadowCard=New TShadowCard
 card.SetSelfBounds(TSceneRect.Create(0,0,160,100));group.AddChild(card)
 stages[i].SetShadowColor(10,20,35,0.7)
Next
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 Local dx:Float=(MouseX()-360)/24.0,dy:Float=(MouseY()-180)/12.0
 For Local stage:TSceneShadowStage=EachIn stages
  stage.SetOffset(dx,dy)
 Next
 SetClsColor(45,55,70);Cls
 scene.Render()
 SetColor(255,255,255);SetAlpha(1);SetBlend(ALPHABLEND)
 DrawText("Outer shadow + source",100,65)
 DrawText("Source + inner shadow",440,65)
 DrawText("Move the mouse to change the shadow direction",100,290)
 Flip
Wend
scene.Destroy()
EndGraphics
