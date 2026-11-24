SuperStrict
Framework BRL.StandardIO
Import Max2D.SceneAnimation
Global checks:Int
Function Check(value:Int,message:String)
 If Not value Then Throw message
 checks:+1
End Function
Function At(node:TSceneNode2D,x:Float,y:Float)
 Local actualX:Float,actualY:Float
 node.GetPosition(actualX,actualY)
 Check(Abs(actualX-x)<0.001 And Abs(actualY-y)<0.001,"position")
End Function
Try
 Local scene:TScene=TScene.Create()
 Local target:TSceneNode2D=New TSceneNode2D
 Local layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer);layer.AddChild(target)
 Local tween:TSceneTweenNode=New TSceneTweenNode
 target.AddChild(tween)
 tween.Position(0,0,100,50,2,1).Position(100,50,200,0,1,3)
 Check(tween.Duration()=4,"duration includes delay")
 tween.Play();At(target,0,0)
 scene.Update(0.5);At(target,0,0)
 scene.Update(1.5);At(target,50,25)
 tween.Seek(3.5);At(target,150,25)
 tween.Seek(0);At(target,0,0)
 scene.Update(20);At(target,200,0);Check(Not tween.IsPlaying(),"large delta completes once")
 tween.Play();scene.SetPaused(True);scene.Update(2);At(target,0,0)
 tween.SetProcessWhenPaused(True);scene.Update(2);At(target,50,25)
 scene.SetPaused(False)
 tween.Pause();scene.Update(2);At(target,50,25)
 tween.Resume();scene.Update(0.5);At(target,75,37.5)
 target.RemoveChild(tween);scene.Update(10);At(target,75,37.5)
 target.AddChild(tween);scene.Update(0.5);At(target,100,50)
 tween.Stop();At(target,100,50)
 tween.Clear();Check(tween.Duration()=0,"clear releases configuration")
 tween.Position(0,0,100,0,1,0,ESceneEase.InQuad)
 tween.SetLoop(True,True);tween.Play()
 scene.Update(0.5);At(target,25,0)
 scene.Update(1);At(target,25,0)
 scene.Update(1000.5);At(target,0,0)
 tween.Seek(1);At(target,100,0)
 tween.Pause();tween.SetLoop(True);tween.Seek(1);At(target,0,0)
 tween.SetSpeed(2);tween.Resume();scene.Update(0.25);At(target,25,0)
 tween.SetSpeed(0);scene.Update(1);At(target,25,0)
 tween.Clear();tween.SetLoop(False);tween.SetSpeed(1)
 For Local ease:ESceneEase=EachIn ESceneEase.Values()
  tween.Clear();tween.Position(0,0,100,0,1,0,ease);tween.Play()
  tween.Seek(0);At(target,0,0);tween.Seek(1);At(target,100,0)
 Next
 tween.Clear()
 tween.Position(0,0,100,0,4).Position(200,0,300,0,1,2)
 tween.Play();tween.Seek(1);At(target,25,0)
 tween.Seek(2);At(target,200,0);tween.Seek(3);At(target,300,0)
 tween.Seek(1);At(target,25,0)
 tween.Pause()
 Local rejected:Int
 Try
  tween.Position(0,0,1,1,1,1)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"reject unordered property tracks")
 rejected=False
 Try
  tween.Alpha(-1,1,1)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"reject invalid opacity")
 rejected=False
 Try
  tween.Position(0,0,1,1,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"reject zero duration")
 tween.Clear();tween.Rotation(0,720,2).Scale(1,1,-1,2,2).Alpha(1,0,2)
 tween.Play();scene.Update(1);Check(tween.IsPlaying(),"parallel transform and opacity tracks")
 Local matrix:TSceneTransform=target.LocalTransform()
 Check(Abs(matrix.xx)<0.0001 And Abs(matrix.yy-1.5)<0.0001,"rotation and scale use component setters")
 scene.Destroy();Check(Not tween.IsPlaying(),"parent destruction stops timeline")
 rejected=False
 Try
  tween.Play()
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"destroyed timeline cannot restart")
 Print "PASS: scene animation "+checks+" checks"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
