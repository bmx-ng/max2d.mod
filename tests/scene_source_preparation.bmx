SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.SceneEffects
Import BRL.StandardIO
Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Type TSourceProbe Extends TSceneRenderGroup
 Field queries:Int,continuous:Int,fail:Int
 Method RequiresContinuousRender:Int() Override
  queries:+1
  If fail Then Throw "injected source preparation failure"
  Return continuous
 End Method
 Method OnRenderGroup(context:TSceneGroupContext) Override
 End Method
End Type
Type TPreparationProbe Extends TSceneRenderGroup
 Field source:TSceneNode,overlap:TSceneNode
 Field continuous:Int,overlapContinuous:Int
 Field retry:TSourceProbe,retries:Int
 Method PrepareRenderDependencies(epoch:Long) Override
  Try
   continuous=PrepareSourceDependencies(source,epoch)
  Catch error:Object
   If Not retry Then Throw error
   retry.fail=False;retries:+1
   continuous=PrepareSourceDependencies(source,epoch)
  End Try
  If overlap Then overlapContinuous=PrepareSourceDependencies(overlap,epoch)
 End Method
 Method OnRenderGroup(context:TSceneGroupContext) Override
 End Method
End Type
Function MakeHidden:TSceneNode2D(scene:TScene)
 Local layer:TLayerNode=TLayerNode.Create(),hidden:TSceneNode2D=New TSceneNode2D
 scene.Root().AddChild(layer);layer.AddChild(hidden);hidden.SetVisible(False)
 Return hidden
End Function
Try
 Graphics(32,32)
 Local scene:TScene=TScene.Create(),hidden:TSceneNode2D=MakeHidden(scene)
 Local branch:TSceneNode2D=New TSceneNode2D
 Local first:TSourceProbe=New TSourceProbe,second:TSourceProbe=New TSourceProbe
 hidden.AddChild(branch);branch.AddChild(first);branch.AddChild(second)
 Local a:TPreparationProbe=New TPreparationProbe,b:TPreparationProbe=New TPreparationProbe
 hidden.AddChild(a);hidden.AddChild(b)
 a.source=branch;a.overlap=first;b.source=branch;b.overlap=second
 a.SetRenderPreparation(True);b.SetRenderPreparation(True)
 scene.Render()
 Check(first.queries=1 And second.queries=1,"shared and overlapping sources query each node once per epoch")
 Check(Not a.continuous And Not b.continuous,"stable source requirement shared")
 second.continuous=True;scene.Render()
 Check(first.queries=2 And second.queries=2,"a new render revisits source nodes")
 Check(a.continuous And b.continuous And b.overlapContinuous,"continuous descendant reaches every consumer")
 second.continuous=False;scene.Render()
 Check(Not a.continuous And Not b.continuous,"continuous results do not persist into another epoch")
 b.source=first;b.overlap=branch
 scene.Render()
 Check(first.queries=4 And second.queries=4,"descendant-first overlap also visits each node once")
 b.source=branch;b.overlap=second
 Local rejected:Int
 Try
  a.PrepareSourceDependencies(branch,1)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"provider helper rejects calls outside preparation")
 second.fail=True;rejected=False
 Try
  scene.Render()
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And Not scene.CaptureStats().Completed(),"source preparation failure aborts render")
 Local queries:Int=first.queries
 second.fail=False;scene.Render()
 Check(first.queries=queries+1 And scene.CaptureStats().Completed(),"retry after failure uses a fresh epoch")
 ' The most recently registered consumer runs first and retries within the epoch.
 second.fail=True;b.retry=second;queries=first.queries
 scene.Render()
 Check(b.retries=1 And first.queries=queries+1,"same-epoch retry reuses only successfully completed child walks")
 Check(Not a.continuous And Not b.continuous,"same-epoch failed source is retried to completion")
 b.retry=Null
 a.source=a;rejected=False
 Try
  scene.Render()
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And scene.CaptureStats().Captures()=0,"recursive source preparation rejects cycles before capture")
 a.source=branch;scene.Render()
 Check(scene.CaptureStats().Completed(),"cycle rejection clears in-progress state")
 ' Equal epoch values in independent scenes must never share prepared results.
 Local fresh:TScene=TScene.Create(),freshHidden:TSceneNode2D=MakeHidden(fresh)
 Local freshSource:TSourceProbe=New TSourceProbe,freshOwner:TPreparationProbe=New TPreparationProbe
 freshHidden.AddChild(freshSource);freshHidden.AddChild(freshOwner)
 freshOwner.source=freshSource;freshOwner.SetRenderPreparation(True);fresh.Render()
 Check(freshSource.queries=1,"source prepared in first scene epoch")
 Local destination:TScene=TScene.Create(),destinationHidden:TSceneNode2D=MakeHidden(destination)
 Local destinationOwner:TPreparationProbe=New TPreparationProbe
 destinationHidden.AddChild(destinationOwner);destinationOwner.source=freshSource
 freshHidden.RemoveChild(freshSource);destinationHidden.AddChild(freshSource)
 freshSource.continuous=True;destinationOwner.SetRenderPreparation(True);destination.Render()
 Check(freshSource.queries=2 And destinationOwner.continuous,"scene transfer resets equal-epoch memoisation")
 destinationHidden.RemoveChild(freshSource);freshHidden.AddChild(freshSource)
 fresh.Render();Check(freshSource.queries=3,"detach and reattach prepares again")
 freshSource.Destroy();freshOwner.SetRenderPreparation(False)
 fresh.Render();Check(fresh.CaptureStats().Completed(),"destroyed source leaves no traversal registry entries")
 scene.Destroy();fresh.Destroy();destination.Destroy();EndGraphics()
 Print "PASS: "+checks+" source preparation checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
