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
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Function Same:Int(a:TPixmap,b:TPixmap)
 For Local y:Int=0 Until a.height
  For Local x:Int=0 Until a.width
   If a.ReadPixel(x,y)<>b.ReadPixel(x,y) Then Return False
  Next
 Next
 Return True
End Function
Type TShadowArtwork Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  DrawRect(0,0,24,24)
 End Method
End Type
Try
 Graphics(160,160)
 For Local inner:Int=0 To 1
  Local stage:TSceneShadowStage=TSceneShadowStage.Create(8,-3,4)
  If inner Then stage=TSceneInnerShadowStage.Create(8,-3,4)
  Local bounds:TSceneRect=TSceneRect.Create(0,0,32,32)
  stage.ExpandBounds(bounds,bounds)
  Check(bounds.x=-21 And bounds.y=-18 And bounds.width=71 And bounds.height=72,"offset and blur padding accepts aliased bounds")
  Local layout:TSceneStageLayout=TSceneStageLayout.Create(TSceneRect.Create(0,0,32,32),2)
  Check(stage.EstimateStorageBytes(layout)=((3+inner)*64*64+32*32+2*16*16)*4,"helper and combined-output storage estimate")
  Local revision:Long=stage.Revision(),rejected:Int
  Try
   stage.SetShadowColor(0,0,0,2)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And stage.Revision()=revision,"invalid colour does not change stage")
  stage.SetPadding(1);rejected=False
  Local untouched:TSceneRect=TSceneRect.Create(1,2,3,4)
  Try
   stage.ExpandBounds(bounds,untouched)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And untouched.x=1 And untouched.width=3,"insufficient fixed padding rejects without changing output bounds")
  stage.ClearPadding()
  Check(stage.GetPadding()=-1,"automatic padding can be restored")
  stage.SetShadowColor(60,30,100,0.6)
  rejected=False
  Try
   stage.Prepare(layout)
  Catch error:Object
   rejected=True
  End Try
?max2d_gl Or max2d_sdlgpu Or max2d_d3d9 Or max2d_d3d11
  Check(Not rejected,"shadow preparation with provider")
  Local source:TRenderImage=CreateRenderImage(64,64,FILTEREDIMAGE)
  Local reference:TRenderImage=CreateRenderImage(64,64,FILTEREDIMAGE)
  SetRenderImage(source);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
  SetClsColor(0,0,0,0);Cls;SetColor(210,160,100);SetBlend(SOLIDBLEND);SetAlpha(1)
  DrawRect(20,20,24,24);SetAlpha(0.5);DrawRect(28,28,6,6)
  SetRenderImage(Null);SetAlpha(0.7);SetColor(23,45,67);SetBlend(LIGHTBLEND)
  Local original:TPixmap=ReadRenderImage(source),presentedSource:TPixmap
  Local result:TRenderImage=stage.Update(source)
  Check(GetBlend()=LIGHTBLEND And TMax2DGraphics.Current().renderImage=Null And Abs(GetAlpha()-0.7)<0.00001,"update restores caller state")
  Local raw:TMax2DShadow,rawInner:TMax2DInnerShadow,mask:TRenderImage
  If inner Then
   rawInner=CreateInnerShadow(16,-6,8);rawInner.Prepare(64,64,2);mask=rawInner.Update(source)
  Else
   raw=CreateShadow(16);raw.Prepare(64,64,2);mask=raw.Update(source)
  End If
  Using
   Local scope:TMax2DStateScope=ScopedMax2DState()
  Do
   SetRenderImage(reference);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
   SetOrigin(0,0);SetHandle(0,0);SetClsColor(0,0,0,0);Cls;SetBlend(ALPHABLEND)
   If Not inner Then
    SetColor(60,30,100);SetAlpha(0.6);DrawImage(mask,-6,8)
   End If
   SetColor(255,255,255);SetAlpha(1);DrawImage(source,0,0)
   If inner Then
    presentedSource=ReadRenderImage(reference)
    SetColor(60,30,100);SetAlpha(0.6);DrawImage(mask,0,0)
   End If
  End Using
  Local actual:TPixmap=ReadRenderImage(result)
  Check(Same(actual,ReadRenderImage(reference)),"stage matches manual source-plus-shadow composition at scale two")
  Check(Same(original,ReadRenderImage(source)),"source pixels unchanged")
  Check(actual.ReadPixel(0,0)=0,"padding remains transparent")
  If inner Then
   Local contained:Int=True
   For Local y:Int=0 Until 64
    For Local x:Int=0 Until 64
     If (presentedSource.ReadPixel(x,y) Shr 24 & 255)=0 And actual.ReadPixel(x,y)<>0 Then contained=False
    Next
   Next
   Check(contained,"inner output stays within ordinary source presentation coverage")
  End If
  ResetMax2DStats();stage.SetShadowColor(0,0,0,0)
  Check(stage.EstimatePreparationBytes(layout)=0,"colour edits reuse layout")
  rejected=False
  Try
   stage.Update(source)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected,"processing requires prepare after configuration changes")
  stage.Prepare(layout)
  Check(stage.Update(source)=result And CaptureMax2DStats().textureCreations=0,"warm preparation and update reuse textures")
  ' Compare the zero-opacity stage with ordinary source presentation using the
  ' same byte-target sampling, retaining exact equality on every backend.
  Using
   Local scope:TMax2DStateScope=ScopedMax2DState()
  Do
   SetRenderImage(reference);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
   SetCamera(Null);ResetCoordinates();SetTransform(0,1,1);SetOrigin(0,0);SetHandle(0,0)
   SetClsColor(0,0,0,0);Cls;SetBlend(ALPHABLEND)
   SetColor(255,255,255);SetAlpha(1);DrawImage(source,0,0)
  End Using
  Check(Same(ReadRenderImage(reference),ReadRenderImage(result)),"zero opacity matches ordinary source presentation")
  rejected=False
  Try
   stage.Update(result)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected,"output feedback rejected")
  If raw Then raw.Release()
  If rawInner Then rawInner.Release()
  SetRenderImage(Null);source.ReleaseFrames();reference.ReleaseFrames()
  Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
  scene.Root().AddChild(layer)
  Local group:TCompositeNode=TCompositeNode.Create()
  group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
  Local box:TShadowArtwork=New TShadowArtwork
  box.SetSelfBounds(TSceneRect.Create(0,0,24,24));group.AddChild(box)
  Local attached:TSceneShadowStage=TSceneShadowStage.Create(4,3,3)
  If inner Then attached=TSceneInnerShadowStage.Create(4,3,3)
  group.SetStages([TSceneEffectStage(attached)])
  bounds=TSceneRect.Create(0,0,24,24);attached.ExpandBounds(bounds,bounds)
  Local tight:TSceneStageLayout=TSceneStageLayout.Create(bounds)
  group.SetStorageLimitBytes(tight.EstimateImageBytes()+attached.EstimateStorageBytes(tight))
  scene.Render();scene.Render()
  Check(scene.CaptureStats().StagePasses()=0,"unchanged automatic cache skips shadow processing")
  attached.SetShadowColor(50,20,10,0.7);ResetMax2DStats();scene.Render()
  Check(scene.CaptureStats().Captures()=0 And scene.CaptureStats().StagePasses()=1 And CaptureMax2DStats().textureCreations=0,"colour change reprocesses without recapture at exact budget")
  group.SetStorageLimitBytes(67108864);attached.SetOffset(-9,4);scene.Render()
  Check(scene.CaptureStats().Captures()=1,"changed offset padding recaptures artwork")
  attached.SetPadding(32)
  group.SetCaptureRect(TSceneRect.Create(0,0,24,24));scene.Render()
  attached.SetOffset(4,-6);ResetMax2DStats();scene.Render()
  Check(scene.CaptureStats().Captures()=0 And scene.CaptureStats().StagePasses()=1 And CaptureMax2DStats().textureCreations=0,"fixed capture reuses artwork while shadow offset changes")
  scene.Destroy()
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
  Check(rejected And TMax2DGraphics.Current().renderImage=Null,"missing provider rejects during prepare and restores target")
?
  stage.ReleaseResources();stage.ReleaseResources()
 Next
 EndGraphics
 Print "PASS: "+checks+" scene shadow checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics
 EndWithCode(1)
End Try
