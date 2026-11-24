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
Type TMaskArtwork Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  DrawRect(-4,-4,24,24)
 End Method
End Type
Function Render:TPixmap(scene:TScene,target:TRenderImage)
 SetRenderImage(target);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
 SetClsColor(0,0,0,0);Cls;scene.Render()
 Return ReadRenderImage(target)
End Function
Function CheckMaskCaller(target:TRenderImage)
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local red:Int,green:Int,blue:Int,x:Int,y:Int,w:Int,h:Int
 GetColor(red,green,blue);GetViewport(x,y,w,h)
 Check(canvas.renderImage=target And canvas.context.view.width=80 And canvas.context.view.height=90,"mask restores target and virtual dimensions")
 Check(x=3 And y=4 And w=50 And h=60,"mask restores caller clip")
 Check(red=23 And green=45 And blue=67 And Abs(GetAlpha()-0.4)<0.001,"mask restores caller colour")
 Check(GetCamera().x=17 And GetRotation()=31 And canvas.saved.Count()=1,"mask restores transforms and balances state stack")
End Function
Try
 Graphics(64,64)
 Local mask:TImage=CreateImage(2,2,1,DYNAMICIMAGE)
 Local pixels:TPixmap=LockImage(mask)
 pixels.WritePixel(0,0,$ffffffff);pixels.WritePixel(1,0,$00ffffff)
 pixels.WritePixel(0,1,$80ffffff);pixels.WritePixel(1,1,$ffffffff)
 Local snapshot:TPixmap=pixels.Copy()
 UnlockImage(mask);SetImageHandle(mask,1,1)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer);scene.SetInputClip(TSceneRect.Create(0,0,64,64))
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetCacheMode(ESceneCacheMode.Automatic);group.SetPosition(20,20);layer.AddChild(group)
 Local artwork:TMaskArtwork=New TMaskArtwork
 artwork.SetSelfBounds(TSceneRect.Create(-4,-4,24,24));artwork.SetInteractive(True);group.AddChild(artwork)
 Local region:TSceneRect=TSceneRect.Create(0,0,16,16)
 Local stage:TSceneAlphaMaskStage=TSceneAlphaMaskStage.Create(mask,region)
 group.SetStages([TSceneEffectStage(stage)]);region.width=0
 Check(scene.Pick(32,24)=artwork,"visual mask leaves picking unchanged by default")
 stage.SetInputMask(snapshot,200);snapshot.WritePixel(0,0,0)
 Check(scene.Pick(24,24)=artwork,"CPU snapshot is copied")
 Check(scene.Pick(32,24)=Null And scene.Pick(24,32)=Null,"alpha threshold rejects transparent and partial input")
 Check(scene.Pick(32,32)=artwork And scene.Pick(19,24)=Null,"opaque input and zero outside coverage")
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 pixels=Render(scene,target)
 Check((pixels.ReadPixel(24,24) Shr 24 & 255)>245,"opaque coverage renders")
 ' D3D9 filtered intermediate copies can leave two alpha units at the immediate edge.
 Check((pixels.ReadPixel(32,24) Shr 24 & 255)=0 And pixels.ReadPixel(18,24)=0 And (pixels.ReadPixel(19,24) Shr 24 & 255)<=2,"transparent interior and outside coverage erase: "+pixels.ReadPixel(32,24)+" / "+pixels.ReadPixel(19,24))
 Check(Abs((pixels.ReadPixel(24,32) Shr 24 & 255)-128)<5,"partial coverage preserves alpha")
 Check(scene.RetainedStorageBytes()=24*24*4*3,"capture and two mask targets are budgeted")
 Render(scene,target);Check(scene.CaptureStats().Captures()=0 And scene.CaptureStats().StagePasses()=0,"automatic mask cache reused")
 stage.Invalidate();ResetMax2DStats();Render(scene,target)
 Local stats:TMax2DStats=CaptureMax2DStats()
 Check(scene.CaptureStats().Captures()=0 And scene.CaptureStats().StagePasses()=1,"mask invalidation reprocesses without recapturing")
 ' Render helper performs one deliberate readback for assertions.
 Check(stats.textureCreations=0 And stats.readbacks=1,"warm mask update allocates no textures or extra readbacks")
 ' Direct updates must restore a non-default caller view even after failure.
 Local saved:TMax2DStateScope=ScopedMax2DState()
 Local input:TRenderImage=CreateRenderImage(24,24,0)
 Local camera:TCamera2D=New TCamera2D;camera.x=17;camera.zoom=2
 SetRenderImage(target);SetVirtualResolution(80,90);SetViewport(3,4,50,60)
 SetCamera(camera);SetColor(23,45,67);SetAlpha(0.4);SetRotation(31)
 stage.Update(input)
 CheckMaskCaller(target)
 LockImage(mask)
 Local failed:Int
 Try
  stage.Update(input)
 Catch error:Object
  failed=True
 Finally
  UnlockImage(mask)
 End Try
 Check(failed,"locked mask fails during coverage drawing")
 CheckMaskCaller(target)
 stage.Update(input);CheckMaskCaller(target)
 ' Returned output can also be the caller target; its custom view must survive.
 Local output:TRenderImage=stage.Update(input)
 SetRenderImage(output);SetVirtualResolution(80,90);SetViewport(3,4,50,60)
 stage.Update(input);CheckMaskCaller(output)
 LockImage(mask);failed=False
 Try
  stage.Update(input)
 Catch error:Object
  failed=True
 Finally
  UnlockImage(mask)
 End Try
 Check(failed,"selected-output mask failure reached")
 CheckMaskCaller(output)
 stage.Update(input);CheckMaskCaller(output)
 input.ReleaseFrames();saved.Close();stage.Invalidate()
 group.SetResolutionScale(2);pixels=Render(scene,target)
 Check((pixels.ReadPixel(24,24) Shr 24 & 255)>245 And pixels.ReadPixel(18,24)=0 And (pixels.ReadPixel(19,24) Shr 24 & 255)<=2,"logical mask placement survives resolution change: "+pixels.ReadPixel(19,24))
 stage.SetMaskRect(TSceneRect.Create(8,0,16,16));pixels=Render(scene,target)
 Check(pixels.ReadPixel(24,24)=0 And (pixels.ReadPixel(32,24) Shr 24 & 255)>245,"moving mask updates pixels in local coordinates")
 Check(scene.CaptureStats().Captures()=0 And scene.CaptureStats().StagePasses()=1,"moving mask reuses unchanged child capture")
 stage.SetMask(mask,TSceneRect.Create(0,0,16,16),True)
 Check(scene.Pick(32,24)=artwork,"replacement clears old input snapshot")
 pixels=LockImage(mask);stage.SetInputMask(pixels,200);UnlockImage(mask)
 pixels=Render(scene,target)
 Check((pixels.ReadPixel(24,24) Shr 24 & 255)<5 And (pixels.ReadPixel(32,24) Shr 24 & 255)>245,"inverse mask cuts opaque texels")
 Check((pixels.ReadPixel(19,24) Shr 24 & 255)>245,"inverse retains outside rectangle")
 Check(scene.Pick(24,24)=Null And scene.Pick(32,24)=artwork And scene.Pick(19,24)=artwork,"inverse input follows explicit snapshot")
 group.SetClipRect(TSceneRect.Create(0,0,16,16))
 Check(scene.Pick(19,24)=Null,"rectangle and alpha input restrictions intersect")
 group.SetLocalTransform(TSceneTransform.Create(-1,0.2,0.3,1,40,20))
 Local x:Float,y:Float
 scene.LocalToScreen(group,12,4,x,y);Check(scene.Pick(x,y)=artwork,"alpha input under affine transform")
 scene.LocalToScreen(group,4,4,x,y);Check(scene.Pick(x,y)=Null,"affine masked point rejected")
 Local rejected:Int
 Try
  stage.SetInputMask(Null,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And scene.Pick(x,y)=Null,"invalid input replacement preserves prior policy")
 stage.SetMaskRect(TSceneRect.Create(8,0,16,16))
 scene.LocalToScreen(group,12,4,x,y)
 Check(scene.Pick(x,y)=Null,"moving mask retains and remaps CPU coverage")
 stage.SetInverted(False)
 Check(scene.Pick(x,y)=artwork,"inversion changes retain input snapshot")
 stage.SetMaskRect(TSceneRect.Create(0,0,0,16))
 Check(scene.Pick(x,y)=Null,"zero-area normal mask rejects coverage")
 stage.SetInverted(True)
 Check(scene.Pick(x,y)=artwork,"zero-area inverse mask accepts coverage")
 stage.SetInputMask(Null);Check(scene.Pick(x,y)=artwork,"input mask can be disabled")
 scene.ReleaseResources();Check(scene.RetainedStorageBytes()=0,"mask storage explicitly released")
 Render(scene,target);Check(scene.CaptureStats().Captures()=1,"mask storage recreates after release")
 group.SetStages(Null);Check(scene.RetainedStorageBytes()=16*16*4*4,"removing mask releases its targets")
 scene.Destroy();SetRenderImage(Null);target.ReleaseFrames();EndGraphics()
 Print "PASS: "+checks+" scene alpha mask checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
