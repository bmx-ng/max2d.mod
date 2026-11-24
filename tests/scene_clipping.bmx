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
Type TClipArtwork Extends TCustomDrawNode
 Field moves:Int
 Method OnDraw(context:TSceneDrawContext)
  DrawRect(0,0,20,20)
 End Method
 Method OnPointer(event:TScenePointerEvent)
  If event.Kind()=EScenePointerKind.Down Then event.CapturePointer(Self)
  If event.Kind()=EScenePointerKind.Move Then moves:+1
 End Method
End Type
Type TGuardClip Extends TSceneRenderGroup
 Field mutate:Int
 Method HitTestInputClip:Int(x:Float,y:Float) Override
  If mutate Then SetPosition(99,99)
  Return True
 End Method
 Method OnRenderGroup(context:TSceneGroupContext) Override
 End Method
End Type
Function Render:TPixmap(scene:TScene,target:TRenderImage)
 SetRenderImage(target);SetVirtualResolution(96,96);SetViewport(0,0,96,96)
 SetClsColor(0,0,0,0);Cls;scene.Render()
 Return ReadRenderImage(target)
End Function
Try
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer);scene.SetInputClip(TSceneRect.Create(0,0,96,96))
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetPosition(20,20);group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
 Local box:TClipArtwork=New TClipArtwork
 box.SetInteractive(True);box.SetSelfBounds(TSceneRect.Create(0,0,20,20));group.AddChild(box)
 Local clip:TSceneRect=TSceneRect.Create(2.25,3.25,7.5,6.5),copy:TSceneRect=New TSceneRect
 group.SetClipRect(clip);clip.width=0
 Check(group.CopyClipRect(copy) And copy.x=2 And copy.y=3 And copy.width=8 And copy.height=7,"copied and outward-rounded clip")
 Check(scene.Pick(22,23)=box,"inclusive rounded left/top")
 Check(scene.Pick(29.9,29.9)=box,"inside rounded right/bottom")
 Check(scene.Pick(30,25)=Null And scene.Pick(25,30)=Null,"exclusive right/bottom")
 Check(scene.Pick(21,25)=Null,"clipped child cannot be picked")
 group.SetInteractive(True);group.SetHitRect(TSceneRect.Create(0,0,20,20))
 Check(scene.Pick(21,25)=Null,"clip also restricts group hit shape")
 group.SetInteractive(False)
 scene.DispatchPointer(EScenePointerKind.Down,1,1,25,25)
 scene.DispatchPointer(EScenePointerKind.Move,1,1,80,80)
 Check(box.moves=1,"captured pointer continues beyond clip")
 scene.DispatchPointer(EScenePointerKind.Up,1,1,80,80)
 Local rejected:Int
 Try
  clip.width=-1
  group.SetClipRect(clip)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And scene.Pick(25,25)=box,"invalid replacement preserves existing clip")
 Local guard:TGuardClip=New TGuardClip
 layer.AddChild(guard);guard.mutate=True;rejected=False
 Try
  scene.Pick(25,25)
 Catch error:Object
  rejected=True
 End Try
 guard.mutate=False
 Check(rejected And scene.Pick(25,25)=box,"clip callbacks reject mutation and picking recovers")
 guard.Destroy()
 group.SetLocalTransform(TSceneTransform.Create(-1,0.3,0.2,1,60,20))
 Local x:Float,y:Float
 scene.LocalToScreen(group,5,5,x,y)
 Check(scene.Pick(x,y)=box,"reflection and shear use local clip")
 scene.LocalToScreen(group,1,5,x,y)
 Check(scene.Pick(x,y)=Null,"transformed outside point rejected")
 Local camera:TCamera2D=New TCamera2D
 camera.x=60;camera.y=20;camera.offsetX=48;camera.offsetY=48;camera.zoom=2;camera.rotation=25
 layer.SetCamera(camera)
 scene.LocalToScreen(group,5,5,x,y)
 Check(scene.Pick(x,y)=box,"camera and affine clip compose for picking")
 scene.LocalToScreen(group,1,5,x,y)
 Check(scene.Pick(x,y)=Null,"camera preserves local clip rejection")
 layer.SetCamera(Null)
 group.SetTransform(20,20,0,0,1)
 Check(scene.Pick(25,25)=Null,"singular clipped group rejects input")
 group.SetTransform(20,20,0)
 Graphics(96,96)
 Local target:TRenderImage=CreateRenderImage(96,96,0)
 Local pixels:TPixmap=Render(scene,target)
 Check(pixels.ReadPixel(25,25)=$ffffffff,"clip retains interior drawing")
 Check(pixels.ReadPixel(21,25)=0 And pixels.ReadPixel(30,25)=0,"clip removes outside drawing")
 Render(scene,target)
 Check(scene.CaptureStats().Captures()=0,"unchanged clip reuses cached pixels")
 group.SetResolutionScale(2);pixels=Render(scene,target)
 Check(pixels.ReadPixel(25,25)=$ffffffff And pixels.ReadPixel(21,25)=0 And pixels.ReadPixel(30,25)=0,"higher capture resolution retains logical clipping edges")
 Check(scene.Pick(22,23)=box And scene.Pick(30,25)=Null,"capture resolution does not change picking edges")
 group.SetResolutionScale(1)
 group.SetClipRect(TSceneRect.Create(4,4,3,3));Render(scene,target)
 Check(scene.CaptureStats().Captures()=1 And scene.Pick(23,25)=Null,"clip edit invalidates source and picking")
 Local outer:TCompositeNode=TCompositeNode.Create()
 outer.SetCacheMode(ESceneCacheMode.Automatic);layer.RemoveChild(group);outer.AddChild(group);layer.AddChild(outer)
 outer.SetClipRect(TSceneRect.Create(25,25,10,10))
 pixels=Render(scene,target)
 Check(scene.Pick(24,25)=Null And scene.Pick(25,25)=box,"nested clips intersect for picking")
 Check(pixels.ReadPixel(24,25)=0 And pixels.ReadPixel(25,25)=$ffffffff,"nested clips intersect for rendering")
 Render(scene,target);Check(scene.CaptureStats().Captures()=0,"nested warm caches reuse output")
 group.SetClipRect(TSceneRect.Create(4,4,4,4));Render(scene,target)
 Check(scene.CaptureStats().Captures()=2,"inner clip edit invalidates enclosing capture")
 outer.ClearCaptureRect();group.SetClipRect(TSceneRect.Create(4.5,4.5,0,4))
 pixels=Render(scene,target)
 Check(scene.Pick(25,25)=Null And pixels.ReadPixel(25,25)=0,"zero-width fractional clip has no drawing or input")
 group.SetCaptureRect(TSceneRect.Create(4,4,3,3))
 Check(Not group.CopyClipRect(copy) And scene.Pick(21,25)=box,"capture-only replacement restores unrestricted picking")
 group.ClearCaptureRect();Render(scene,target)
 Check(scene.Pick(21,25)=box,"clearing capture restores ordinary input")
 scene.ReleaseResources()
 Check(scene.RetainedStorageBytes()=0,"clip storage participates in explicit release")
 Render(scene,target);Check(scene.CaptureStats().Captures()=2,"released clipped composites recreate captures")
 scene.Destroy();SetRenderImage(Null);target.ReleaseFrames();EndGraphics()
 Print "PASS: "+checks+" scene clipping checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
