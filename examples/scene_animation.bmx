SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SceneAnimation

Type TBadge Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext) Override
  context.SetColor(255,255,255)
  DrawOval(-22,-22,44,44)
  context.SetColor(20,30,48)
  DrawRect(-3,-16,6,19)
 End Method
End Type

AppTitle="Max2D Scene / Reusable timelines"
Graphics(900,520)
SetVirtualResolution(900,520,VIRTUAL_LETTERBOX)
Local scene:TScene=TScene.Create()
Local layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local tweens:TSceneTweenNode[]=New TSceneTweenNode[4]
Local names:String[]=["LINEAR","SMOOTH STEP","EASE IN","EASE OUT"]
Local curves:ESceneEase[]=[ESceneEase.Linear,ESceneEase.SmoothStep,ESceneEase.InQuad,ESceneEase.OutQuad]
For Local i:Int=0 Until 4
 Local badge:TBadge=New TBadge
 badge.SetSelfBounds(TSceneRect.Create(-22,-22,44,44))
 badge.SetTint(90+i*45,220-i*30,255-i*20)
 layer.AddChild(badge)
 Local tween:TSceneTweenNode=New TSceneTweenNode
 badge.AddChild(tween)
 tween.Position(250,170+i*80,790,170+i*80,2,0.4,curves[i])
 tween.Rotation(0,360,2,0.4,curves[i])
 tween.Scale(0.7,0.7,1.25,1.25,2,0.4,curves[i])
 tween.Alpha(0.35,1,2,0.4,curves[i])
 tween.SetLoop(True,True);tween.Play()
 tweens[i]=tween
Next
Local last:Int=MilliSecs(),paused:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 Local now:Int=MilliSecs(),dt:Double=Min(0.1,Max(0.0,Double(now-last)/1000))
 last=now
 If KeyHit(KEY_SPACE) Then paused=Not paused;scene.SetPaused(paused)
 If KeyHit(KEY_R) Then
  For Local tween:TSceneTweenNode=EachIn tweens
   tween.Play()
  Next
 End If
 scene.Update(dt)
 SetClsColor(12,19,32);Cls()
 SetColor(230,240,255);DrawText("REUSABLE SCENE TIMELINES",40,34)
 SetColor(150,173,200);DrawText("Position + rotation + scale + opacity | delayed start, ping-pong loop",40,66)
 DrawText("SPACE: pause scene    R: restart    ESC: exit",40,92)
 If paused Then DrawText("PAUSED",760,34)
 For Local i:Int=0 Until 4
  SetColor(80,104,134);DrawText(names[i],40,164+i*80)
  SetColor(32,47,67);DrawRect(240,168+i*80,560,4)
 Next
 scene.Render();Flip(1)
Wend
scene.Destroy();EndGraphics()
