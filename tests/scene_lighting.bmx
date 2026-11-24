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
Import Max2D.SceneLighting
Import BRL.StandardIO

Import Max2D.LightingNative

Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks :+ 1
End Function
Function Near(actual:Int,expected:Int,message:String,tolerance:Int=3)
 Check(Abs(actual-expected)<=tolerance,message+": got "+actual+", expected "+expected)
End Function
Function Red:Int(pixel:Int)
 Return pixel Shr 16 & 255
End Function

Type TLightingArtwork Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  DrawRect(-16,-8,64,64)
 End Method
End Type

Type TTestLitCanvas Extends TLitCanvasNode
 Field paints:Int,fail:Int
 Method OnPaint() Override
  paints:+1
  SetColor(200,120,80);Max2D.Core.SetAlpha(0.5);DrawRect(-4,-3,16,16)
  If fail Then Throw "paint failure"
 End Method
End Type

Try
 Local stage:TSceneLightingStage = TSceneLightingStage.Create(2)
 stage.SetAmbient(255,255,255,0.1)
 stage.SetPointLight(0,16.5,24.5,24,255,0,0,0.6,1)
 stage.SetPointLight(1,16.5,24.5,24,0,0,255,0.4,2)
 Local revision:Long=stage.Revision()
 stage.SetAmbient(255,255,255,0.1)
 stage.SetPointLight(0,16.5,24.5,24,255,0,0,0.6,1)
 Check(stage.Revision()=revision,"identical stage settings preserve cached output revision")
 Local layout:TSceneStageLayout = TSceneStageLayout.Create(TSceneRect.Create(-16,-8,64,64))
 Check(stage.EstimateStorageBytes(layout)=64*64*4,"one output storage estimate")
 Local bounds:TSceneRect=TSceneRect.Create(-16,-8,64,64)
 stage.ExpandBounds(bounds,bounds)
 Check(bounds.x=-16 And bounds.y=-8 And bounds.width=64,"lighting leaves bounds unchanged")
 Local empty:TLitSpriteNode=TLitSpriteNode.Create(Null,TSceneLighting.Create(TLayerNode.Create()))
 Check(empty.GetSelfBounds(bounds) And bounds.width=0 And bounds.height=0,"null lit sprite has known empty bounds")
 Graphics(160,160)
 Local source:TRenderImage=CreateRenderImage(64,64,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetRenderImage(source); SetClsColor(0,0,0,0); Cls
  SetBlend(SOLIDBLEND); SetColor(200,150,100); DrawRect(0,0,56,64)
  SetAlpha(0.5); DrawRect(24,40,16,8)
 End Using
 Local original:TPixmap=ReadRenderImage(source)
 Local rejected:Int
 Try
  stage.Prepare(layout)
 Catch error:Object
  rejected=True
 End Try
?max2d_sdlgpu Or max2d_gl Or max2d_d3d9 Or max2d_d3d11
 Check(Not rejected,"lighting prepares with provider")
 Local output:TRenderImage=stage.Update(source)
 Local pixels:TPixmap=ReadRenderImage(output)
 Near(Red(pixels.ReadPixel(0,0)),20,"ambient red")
 Near(Red(pixels.ReadPixel(32,32)),140,"red light centre")
 Near(pixels.ReadPixel(32,32)&255,50,"blue light overlap")
 Near(pixels.ReadPixel(32,32) Shr 8 & 255,15,"independent green ambient")
 Near(Red(pixels.ReadPixel(44,32)),80,"linear half-radius attenuation")
 Near(pixels.ReadPixel(44,32)&255,20,"quadratic half-radius attenuation")
 Check(pixels.ReadPixel(60,32)=0,"transparent pixels stay transparent")
 Near(pixels.ReadPixel(32,44) Shr 24 & 255,128,"overlap preserves partial alpha",1)
 Check(ReadRenderImage(source).ReadPixel(32,44)=original.ReadPixel(32,44),"source unchanged")
 Check(TMax2DGraphics.Current().renderImage=Null,"target restored")
 ' No allocation for animated geometry, intensity or falloff.
 ResetMax2DStats()
 stage.SetPointLight(0,18,24,28,255,0,0,0.8,3)
 Check(stage.EstimatePreparationBytes(layout)=0,"light edit reuses output")
 stage.Prepare(layout)
 Check(stage.Update(source)=output,"stable borrowed output")
 Check(CaptureMax2DStats().textureCreations=0,"animated light settings allocate no textures")
 ' Invalid parameters retain the old settings.
 rejected=False; revision=stage.Revision()
 Try
  stage.SetPointLight(0,0,0,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And stage.Revision()=revision,"invalid radius preserves configuration revision")
 Local before:UInt=ReadRenderImage(stage.Update(source)).ReadPixel(32,32)
 stage.SetLightCount(2)
 Check(ReadRenderImage(stage.Update(source)).ReadPixel(32,32)=before,"same light count retains settings")
 stage.SetAmbient(255,255,255,1); stage.SetLightCount(0); stage.Prepare(layout)
 pixels=ReadRenderImage(stage.Update(source))
 Near(Red(pixels.ReadPixel(32,44)),Red(original.ReadPixel(32,44)),"neutral ambient preserves partial-alpha RGB")
 ' Intensities above one brighten dark artwork before SDR saturation.
 stage.SetAmbient(255,255,255,0); stage.SetLightCount(1)
 stage.SetPointLight(0,16.5,24.5,24,0,0,255,2,1); stage.Prepare(layout)
 Near(ReadRenderImage(stage.Update(source)).ReadPixel(32,32)&255,200,"intensity above one")
 ' Nonzero capture origin and resolution scale affect position/radius once.
 Local raw:TMax2DLighting=TMax2DLighting.Create(1)
 raw.SetAmbient(255,255,255,0)
 raw.SetPointLight(0,8.25,12.25,12,255,255,255,1,1)
 raw.Prepare(64,64)
 Near(Red(ReadRenderImage(raw.Update(source,-8,-4,2)).ReadPixel(32,32)),200,"scaled coordinate mapping")
 Local viewportX:Int,viewportY:Int,viewportW:Int,viewportH:Int
 SetRenderImage(source); SetVirtualResolution(32,32); SetViewport(2,3,20,21)
 raw.Update(output,-8,-4,2)
 GetViewport(viewportX,viewportY,viewportW,viewportH)
 Check(TMax2DGraphics.Current().renderImage=source And viewportX=2 And viewportY=3 And viewportW=20 And viewportH=21,"lighting restores selected target and viewport")
 SetVirtualResolution(64,64); SetViewport(0,0,64,64); SetRenderImage(Null)
 raw.Release()
 ' Cached world and a separate HUD; light-only edits must not recapture artwork.
 Local scene:TScene=TScene.Create()
 Local layer:TLayerNode=TLayerNode.Create(); scene.Root().AddChild(layer)
 Local group:TCompositeNode=TCompositeNode.Create(); layer.AddChild(group)
 group.SetPosition(16,8); group.SetCacheMode(ESceneCacheMode.Automatic)
 Local artwork:TLightingArtwork=New TLightingArtwork
 artwork.SetSelfBounds(TSceneRect.Create(-16,-8,64,64)); group.AddChild(artwork)
 Local attached:TSceneLightingStage=TSceneLightingStage.Create(1)
 attached.SetAmbient(255,255,255,0.1)
 attached.SetPointLight(0,16,24,24,255,80,30)
 group.SetStages([TSceneEffectStage(attached)])
 group.SetStorageLimitBytes(64*64*8)
 Local hud:TLightingArtwork=New TLightingArtwork
 hud.SetSelfBounds(TSceneRect.Create(-16,-8,64,64)); hud.SetPosition(96,8); layer.AddChild(hud)
 Local target:TRenderImage=CreateRenderImage(160,160,FILTEREDIMAGE)
 SetRenderImage(target); scene.Render()
 attached.SetPointLight(0,20,24,32,80,180,255,2,3)
 ResetMax2DStats(); scene.Render()
 Local stats:TSceneStats=scene.CaptureStats()
 Check(stats.Captures()=0 And stats.StagePasses()=1,"light animation reuses artwork capture")
 Check(CaptureMax2DStats().textureCreations=0,"composite warm lighting creates no textures")
 Check(ReadRenderImage(target).ReadPixel(90,30)=$ffffffff,"HUD remains unlit")
 SetRenderImage(Null); target.ReleaseFrames(); scene.Destroy()
 ' Individual receivers preserve lighting selection and painter order.
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetReceiverMask(1)
 Local other:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 other.SetReceiverMask(2)
 Local map:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 16
   map.WritePixel(x,y,$80ffffff)
  Next
 Next
 Local sprite:TImage=LoadImage(map,FILTEREDIMAGE)
 scene=TScene.Create(); layer=TLayerNode.Create(); scene.Root().AddChild(layer)
 Local environment:TSceneLighting=TSceneLighting.Create(layer)
 environment.SetAmbient(255,255,255,0)
 Local redLight:TPointLightNode=TPointLightNode.Create(100000)
 redLight.SetColor(255,0,0); redLight.SetReceiverMask(1); layer.AddChild(redLight)
 Local blueLight:TPointLightNode=TPointLightNode.Create(100000)
 blueLight.SetColor(0,0,255); blueLight.SetReceiverMask(2); layer.AddChild(blueLight)
 environment.SetLights([redLight,blueLight])
 Local first:TLitSpriteNode=TLitSpriteNode.Create(sprite,environment,material)
 group=TCompositeNode.Create(); group.SetCacheMode(ESceneCacheMode.Automatic); layer.AddChild(group)
 first.SetPosition(16,16); group.AddChild(first)
 Local second:TLitSpriteNode=TLitSpriteNode.Create(sprite,environment,other)
 second.SetPosition(20,20); group.AddChild(second)
 target=CreateRenderImage(64,64,FILTEREDIMAGE)
 SetRenderImage(target); SetClsColor(0,0,0,0); Cls
 environment.Prepare(); scene.Render()
 pixels=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(18,18)),255,"red-only receiver")
 Near(pixels.ReadPixel(18,18)&255,0,"excluded blue light")
 Near(Red(pixels.ReadPixel(22,22)),85,"transparent receiver painter order",4)
 Near(pixels.ReadPixel(22,22)&255,170,"transparent upper receiver light",4)
 Near(pixels.ReadPixel(22,22) Shr 24 & 255,192,"per-object coverage",2)
 environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged individual lighting preserves composite cache")
 redLight.SetIntensity(0.75); environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=1,"light change invalidates cached receivers")
 group.SetPosition(2,0); environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=1,"moving cached group updates world lighting placement")
 group.SetPosition(0,0)
 other.SetUnlit(True)
 Cls; environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=1,"shared material edits invalidate cached receiver")
 pixels=ReadRenderImage(target)
 Near(pixels.ReadPixel(18,18)&255,0,"material edit leaves other receiver independent")
 Near(pixels.ReadPixel(34,34) Shr 8 & 255,255,"unlit material bypasses dark ambient")
 other.SetUnlit(False); other.SetNormalMap(sprite)
 environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=1,"normal map edit invalidates cached receiver")
 environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged normal material preserves cache")
 blueLight.SetHeight(64); environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=1,"light height invalidates cached receiver")
 other.SetSpecular(0.5,16); environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=1,"specular edit invalidates cached receiver")
 other.SetSpecular(0.5,16); environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged specular material preserves cache")
 other.SetSpecularFromNormalAlpha(True);environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=1,"gloss mode invalidates cached receivers")
 other.SetSpecularFromNormalAlpha(True);environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged gloss mode retains cached receivers")
 SetRenderImage(Null); target.ReleaseFrames(); scene.Destroy(); sprite.ReleaseFrames()
 CheckNormalLighting()
 CheckSpecularLighting()
 CheckSpecularMapLighting()
 CheckDirectionalLighting()
 CheckTexturedLighting()
 CheckShadows()
 CheckConcaveShadows()
 CheckDirectionalShadows()
 CheckSelectiveCasterShadows()
 CheckIndependentShadows()
 CheckPairedLighting()
 CheckSpatialSelection()
 CheckLitCanvas()
 CheckTrimmedPatterns()
 CheckTrimmedLighting()
 CheckNativeLightGroups()
 CheckLightingAtlas()
 CheckGroupedShadowStorage()
 CheckGroupedPatterns()
 CheckCombinedAmbient()
 CheckLightGroupMaterials()
 CheckLightingRendererContract()
?Not max2d_sdlgpu And Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
 Check(rejected,"missing lighting provider rejected")
 Check(TMax2DGraphics.Current().renderImage=Null,"failed prepare restores target")
?
 stage.ReleaseResources(); stage.ReleaseResources(); source.ReleaseFrames()
 EndGraphics()
 Print "PASS: "+checks+" lighting checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics()
 EndWithCode(1)
End Try

Function CheckNormalLighting()
 Local map:TPixmap=CreatePixmap(32,32,PF_RGBA8888)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   map.WritePixel(x,y,$80ffffff)
  Next
 Next
 Local art:TImage=LoadImage(map,0)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   map.WritePixel(x,y,$ffff8080)
  Next
 Next
 Local normal:TImage=LoadImage(map,0)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(normal)
 Local revision:Long=material.Revision()
 material.SetNormalMap(normal); material.SetNormalStrength(1)
 Check(material.Revision()=revision,"unchanged normal settings preserve revision")
 Local failed:Int
 Try
  material.SetNormalStrength(-1)
 Catch error:Object
  failed=True
 End Try
 Check(failed And material.Revision()=revision,"invalid normal strength is atomic")
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0); light.SetLightHeight(0,0)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target); SetClsColor(0,0,0,0); SetColor(255,255,255); SetAlpha(1)
 light.SetPointLight(0,32.5,16.5,100000,255,255,255,1,1)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Local pixels:TPixmap=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(16,16)),255,"normal faces light")
 Near(pixels.ReadPixel(16,16) Shr 24 & 255,128,"normal light preserves coverage",1)
 light.SetPointLight(0,0.5,16.5,100000,255,255,255,1,1)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"normal faces away from light")
 light.SetPointLight(0,15.5,32.5,100000,255,255,255,1,1)
 Cls; light.DrawImage(art,0,0,0,-1,0,-1,1,0,32,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),255,"rotated normal follows receiver")
 light.SetPointLight(0,-0.5,16.5,100000,255,255,255,1,1)
 Cls; light.DrawImage(art,0,0,0,-1,-1,0,0,1,32,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),255,"mirrored normal follows receiver")
 light.SetPointLight(0,65.5,0.5,100000,255,255,255,1,1)
 Cls; light.DrawImage(art,0,0,0,-1,2,1,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),255,"inverse transpose handles shear and scale")
 material.SetNormalStrength(0)
 light.SetPointLight(0,16.5,16.5,100000,255,255,255,1,1); light.SetLightHeight(0,16)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),255,"zero normal strength faces elevated light")
 light.SetLightHeight(0,0)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"coincident zero-height light has finite zero diffuse")
 light.SetAmbient(255,255,255,0.25)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),64,"ambient independent of normals")
 material.SetNormalMap(Null)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),255,"cleared map restores flat model")
 material.SetNormalMap(normal); material.SetUnlit(True)
 light.SetAmbient(255,255,255,0)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),255,"core material unlit bypass")
 material.SetUnlit(False)
 ResetMax2DStats()
 light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Check(CaptureMax2DStats().textureCreations=0,"warm normal draws allocate no textures")
 SetRenderImage(Null); target.ReleaseFrames(); normal.ReleaseFrames(); art.ReleaseFrames()
End Function

Function CheckSpecularLighting()
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 Check(material.GetSpecularStrength()=0 And material.GetShininess()=32,"default material has no specular highlight")
 material.SetSpecular(0.5,32)
 Local revision:Long=material.Revision()
 material.SetSpecular(0.5,32)
 Check(material.Revision()=revision,"identical specular settings preserve revision")
 For Local i:Int=0 Until 2
  Local rejected:Int
  Try
   If i=0 Then material.SetSpecular(-1,32) Else material.SetSpecular(1,0)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And material.Revision()=revision,"invalid specular settings are atomic")
 Next
 Local map:TPixmap=CreatePixmap(32,32,PF_RGBA8888)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   Local pixel:Int=$80000000
   If x>=24 Then pixel=0
   map.WritePixel(x,y,pixel)
  Next
 Next
 Local art:TImage=LoadImage(map,0)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   map.WritePixel(x,y,$ffff8080)
  Next
 Next
 Local normal:TImage=LoadImage(map,0)
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0); light.SetLightHeight(0,16)
 light.SetPointLight(0,16.5,16.5,100000,255,128,0,1,1)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target); SetClsColor(0,0,0,0); SetColor(255,255,255); SetAlpha(1)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Local pixels:TPixmap=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(16,16)),128,"flat specular visible on black artwork")
 Near(pixels.ReadPixel(16,16) Shr 8 & 255,64,"specular takes light colour")
 Near(pixels.ReadPixel(16,16) Shr 24 & 255,128,"specular preserves partial alpha",1)
 Check(pixels.ReadPixel(28,16)=0,"specular cannot fill transparent pixels")
 material.SetSpecular(0.5,16)
 light.SetPointLight(0,32.5,16.5,100000,255,255,255,1,1)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),36,"broad highlight follows halfway vector")
 material.SetSpecular(0.5,64)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),1,"higher shininess narrows highlight")
 material.SetNormalMap(normal); material.SetSpecular(0.5,32)
 light.SetPointLight(0,16.5,16.5,100000,255,255,255,1,1)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"tilted normal redirects highlight")
 material.SetNormalStrength(0)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),128,"normal strength affects specular direction")
 material.SetReceiverMask(0)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"receiver mask excludes specular")
 material.SetReceiverMask(-1); light.SetLightHeight(0,0)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"zero light vector produces no specular")
 light.SetLightHeight(0,16); material.SetSpecular(0)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"zero strength disables highlight")
 SetRenderImage(Null); target.ReleaseFrames(); normal.ReleaseFrames(); art.ReleaseFrames()
End Function

Function CheckSpecularMapLighting()
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 Check(Not material.GetSpecularFromNormalAlpha(),"normal alpha is ignored by default")
 material.SetSpecularFromNormalAlpha(True)
 Local revision:Long=material.Revision()
 material.SetSpecularFromNormalAlpha(True)
 Check(material.Revision()=revision,"identical gloss mode retains revision")
 Local map:TPixmap=CreatePixmap(32,32,PF_RGBA8888)
 map.ClearPixels($80000000)
 Local art:TImage=LoadImage(map,0)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   Local alpha:Int=255
   If x<8 Then alpha=0 Else If x<16 Then alpha=128
   map.WritePixel(x,y,(alpha Shl 24)|$00ff8080)
  Next
 Next
 Local normal:TImage=LoadImage(map,0)
 material.SetNormalMap(normal);material.SetNormalStrength(0);material.SetSpecular(0.5,32)
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target);SetClsColor(0,0,0,0);SetColor(255,255,255);SetAlpha(1)
 For Local batching:Int=0 To 1
  light.SetLightBatching(batching)
  For Local count:Int=1 To 17 Step 8
   light.SetLightCount(count)
   For Local i:Int=0 Until count
    light.SetDirectionalLight(i,0,0,1,255,255,255,1.0/count)
   Next
   Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
   Local pixels:TPixmap=ReadRenderImage(target)
   Near(Red(pixels.ReadPixel(4,16)),0,"matte alpha suppresses highlight")
   Near(Red(pixels.ReadPixel(12,16)),64,"half gloss scales highlight",count+2)
   Near(Red(pixels.ReadPixel(20,16)),128,"full gloss keeps highlight",count+2)
   Near(pixels.ReadPixel(4,16) Shr 24 & 255,128,"matte material preserves receiver coverage",1)
   material.SetSpecularFromNormalAlpha(False)
   Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
   Near(Red(ReadRenderImage(target).ReadPixel(4,16)),128,"legacy normal alpha remains ignored",count+2)
   material.SetSpecularFromNormalAlpha(True)
  Next
 Next
 Local patternPixels:TPixmap=CreatePixmap(32,32,PF_RGBA8888)
 patternPixels.ClearPixels($ffffffff)
 Local pattern:TImage=LoadImage(patternPixels,0)
 Local texture:TMax2DLightTexture=TMax2DLightTexture.Create(pattern)
 texture.SetPlacement(32,32)
 light.SetLightCount(1);light.SetPointLight(0,16,16,100000);light.SetLightHeight(0,100000)
 light.SetLightTexture(0,texture)
 For Local batching:Int=0 To 1
  light.SetLightBatching(batching)
  Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
  Local pixels:TPixmap=ReadRenderImage(target)
  Near(Red(pixels.ReadPixel(4,16)),0,"patterned point respects matte gloss")
  Near(Red(pixels.ReadPixel(12,16)),64,"patterned point respects partial gloss")
  Near(Red(pixels.ReadPixel(20,16)),128,"patterned point retains full gloss")
 Next
 light.SetLightTexture(0,Null);pattern.ReleaseFrames()
 ' A matte normal texel must retain its diffuse normal, not erase the surface.
 map.ClearPixels($80404040);art.ReplacePixels(map)
 light.SetLightCount(1);light.SetDirectionalLight(0,0,0,1)
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(4,16)),64,"matte normal retains diffuse response")
 light.SetAmbient(255,255,255,1);light.SetLightCount(0)
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(4,16)),64,"gloss leaves ambient unchanged")
 light.SetAmbient(255,255,255,0);light.SetLightCount(1);light.SetDirectionalLight(0,0,0,1)
 material.SetNormalMap(Null)
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(4,16)),192,"gloss option without normal retains uniform specular")
 Local builder:TMax2DLightingMaterialMap=TMax2DLightingMaterialMap.Create(False)
 map.ClearPixels($ff800000)
 Local separateGloss:TImage=TImage.FromPixmap(map)
 Local packed:TImage=builder.Update(Null,separateGloss)
 material.SetNormalMap(packed)
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(4,16)),128,"separate gloss packs and renders")
 map.ClearPixels($ff000000);separateGloss.ReplacePixels(map)
 Check(builder.Update(Null,separateGloss)=packed,"edited separate gloss keeps image identity")
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(4,16)),64,"edited separate gloss refreshes GPU pixels")
 ResetMax2DStats()
 builder.Update(Null,separateGloss)
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Check(CaptureMax2DStats().textureCreations=0,"warm material packing and drawing create no textures")
 material.SetNormalMap(Null);builder.Release();separateGloss.ReleaseFrames()

 SetRenderImage(Null);light.Release();target.ReleaseFrames();normal.ReleaseFrames();art.ReleaseFrames()
End Function

Function CheckDirectionalLighting()
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0)
 light.SetDirectionalLight(0,1,0,0,255,255,255,0.5)
 Local revision:Long=light.Revision()
 light.SetDirectionalLight(0,2,0,0,255,255,255,0.5)
 Check(light.Revision()=revision,"direction magnitude does not change illumination")
 Local rejected:Int
 Try
  light.SetDirectionalLight(0,0,0,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And light.Revision()=revision,"zero direction rejected atomically")
 rejected=False
 Try
  light.SetLightHeight(0,12)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And light.Revision()=revision,"directional light has no point height")
 Local map:TPixmap=CreatePixmap(32,32,PF_RGBA8888)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   map.WritePixel(x,y,$80c8c8c8)
  Next
 Next
 Local art:TImage=LoadImage(map,0)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   map.WritePixel(x,y,$ffff8080)
  Next
 Next
 Local normal:TImage=LoadImage(map,0),material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(normal)
 Local target:TRenderImage=CreateRenderImage(32,32,0)
 SetRenderImage(target); SetClsColor(0,0,0,0); SetColor(255,255,255); SetAlpha(1)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,10000,-10000,material)
 Local pixels:TPixmap=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(2,2)),100,"directional normal response ignores receiver position")
 Near(Red(pixels.ReadPixel(28,28)),100,"directional response has no distance falloff")
 Near(pixels.ReadPixel(16,16) Shr 24 & 255,128,"directional light preserves coverage",1)
 light.SetDirectionalLight(0,-1,0,0,255,255,255,0.5)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"directional light rejects back-facing normal")
 light.SetDirectionalLight(0,0,0,1,255,255,255,0.5)
 material.SetNormalStrength(0); material.SetSpecular(0.5)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),164,"directional diffuse and specular share light direction")
 light.SetLightMask(0,2); material.SetReceiverMask(1)
 Cls; light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"directional receiver masks")
 light.SetLightMask(0,-1)
 Cls; light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),100,"flat receivers get uniform directional colour")
 light.SetPointLight(0,0,0,1,255,255,255,0.5)
 Cls; light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"slot switches from directional to point")
 light.SetDirectionalLight(0,1,0,0,255,255,255,0.5)
 Cls; light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),100,"slot switches back to directional")
 ' A point contribution narrows the viewport before a full-canvas directional pass.
 Local source:TRenderImage=CreateRenderImage(32,32,0)
 SetRenderImage(source); SetBlend(SOLIDBLEND); Cls; DrawImage(art,0,0)
 SetRenderImage(Null); SetBlend(ALPHABLEND)
 Local stage:TSceneLightingStage=TSceneLightingStage.Create(2)
 stage.SetAmbient(255,255,255,0)
 stage.SetPointLight(0,1.5,1.5,2,255,255,255,0.2)
 stage.SetDirectionalLight(1,0,0,1,255,255,255,0.25)
 revision=stage.Revision()
 stage.SetDirectionalLight(1,0,0,1,255,255,255,0.25)
 Check(stage.Revision()=revision,"unchanged directional stage preserves revision")
 stage.Prepare(TSceneStageLayout.Create(TSceneRect.Create(0,0,32,32)))
 pixels=ReadRenderImage(stage.Update(source))
 Near(Red(pixels.ReadPixel(28,28)),50,"directional stage restores full viewport after point pass")
 stage.ReleaseResources(); source.ReleaseFrames()
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local environment:TSceneLighting=TSceneLighting.Create(layer)
 environment.SetAmbient(255,255,255,0)
 Local parent:TSceneNode2D=New TSceneNode2D
 layer.AddChild(parent)
 Local sun:TDirectionalLightNode=TDirectionalLightNode.Create(1,0,0)
 sun.SetIntensity(0.5); parent.AddChild(sun)
 Local point:TPointLightNode=TPointLightNode.Create(1)
 point.SetIntensity(0); layer.AddChild(point)
 environment.SetLights([TLightNode2D(point),sun])
 material.SetNormalStrength(1); material.SetSpecular(0)
 Local receiver:TLitSpriteNode=TLitSpriteNode.Create(art,environment,material)
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetCacheMode(ESceneCacheMode.Automatic); layer.AddChild(group); group.AddChild(receiver)
 SetRenderImage(target); Cls; environment.Prepare(); scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),100,"mixed scene light list")
 environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged directional scene preserves capture")
 parent.SetPosition(100,100); sun.SetPosition(200,200)
 environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=0,"light translation does not invalidate directional receivers")
 parent.SetRotation(180)
 Cls; environment.Prepare(); scene.Render()
 Check(scene.CaptureStats().Captures()=1,"parent rotation invalidates directional shading")
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"direction follows parent rotation")
 parent.SetRotation(0); sun.SetEnabled(False)
 Cls; environment.Prepare(); scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"disabled directional light contributes nothing")
 sun.SetEnabled(True); parent.RemoveChild(sun)
 Cls; environment.Prepare(); scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(16,16)),0,"detached directional light contributes nothing")
 SetRenderImage(Null); scene.Destroy(); target.ReleaseFrames(); normal.ReleaseFrames(); art.ReleaseFrames()
End Function

Function CheckTexturedLighting()
 Local pixels:TPixmap=CreatePixmap(32,32,PF_RGBA8888)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   pixels.WritePixel(x,y,$ffc8c8c8)
  Next
 Next
 Local art:TImage=LoadImage(pixels,0)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   Local colour:Int=$ffff0000
   If x>=16 Then colour=$8000ff00
   If y<8 Then colour=$ff0000ff
   pixels.WritePixel(x,y,Int(colour))
  Next
 Next
 Local pattern:TImage=LoadImage(pixels,0),texture:TMax2DLightTexture=TMax2DLightTexture.Create(pattern)
 texture.SetPlacement(32,32)
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0);light.SetPointLight(0,16,16,100000,255,255,255,1,1)
 light.SetLightTexture(0,texture)
 Local revision:Long=light.Revision()
 light.SetLightTexture(0,texture)
 Check(light.Revision()=revision,"unchanged light texture preserves revision")
 Local target:TRenderImage=CreateRenderImage(32,32,0)
 SetRenderImage(target);SetColor(255,255,255);SetAlpha(1);SetClsColor(0,0,0,0);SetBlend(ALPHABLEND)
 Cls;light.DrawImage(art,0,0)
 pixels=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(8,16)),200,"textured light multiplies source by pattern RGB")
 Near((pixels.ReadPixel(24,16) Shr 8)&255,100,"pattern alpha modulates illumination")
 Near(pixels.ReadPixel(24,16) Shr 24 & 255,255,"pattern alpha preserves receiver coverage")
 Near(Red(pixels.ReadPixel(24,16)),0,"pattern colour excludes other channels")
 Local region:TImage=CreateImageView(pattern,0,8,16,24)
 texture.SetImage(region)
 Cls;light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(24,16)),200,"third texture samples only its atlas region")
 texture.SetImage(pattern)
 texture.SetPlacement(16,16)
 Cls;light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(2,16)),0,"outside projected rectangle is dark")
 texture.SetPlacement(32,32,0,0,180)
 Cls;light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(24,16)),200,"pattern rotation changes independent placement")
 texture.SetPlacement(32,32,8,0)
 Cls;light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(2,16)),0,"pattern offset leaves uncovered region")
 texture.SetPlacement(32,32)
 Local rejected:Int,prior:Long=texture.Revision()
 Try
  texture.SetPlacement(0,32)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And texture.Revision()=prior,"invalid texture placement rejected atomically")
 rejected=False
 Try
  light.SetDirectionalLight(0,0,0,1)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"directional switch requires removal of point pattern")
 ' Three independent images: artwork, upward normal, red/green pattern.
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   pixels.WritePixel(x,y,$ff8080ff)
  Next
 Next
 Local normal:TImage=LoadImage(pixels,0),material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(normal);material.SetSpecular(0.5,32)
 light.SetLightHeight(0,100000)
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(8,16)),255,"textured normal and specular response")
 material.SetNormalStrength(0);material.SetSpecular(0)
 light.SetLightMask(0,2);material.SetReceiverMask(1)
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(8,16)),0,"textured receiver mask")
 light.SetLightMask(0,-1);material.SetReceiverMask(-1)
 ' A render-image pattern exercises premultiplied decoding and GL target orientation.
 Local rendered:TRenderImage=CreateRenderImage(32,32,0)
 SetRenderImage(rendered);Cls;DrawImage(pattern,0,0)
 texture.SetImage(rendered)
 SetRenderImage(target);Cls;light.DrawImage(art,0,0)
 Near((ReadRenderImage(target).ReadPixel(24,16) Shr 8)&255,100,"render-image pattern unpremultiplies before modulation")
 Near(ReadRenderImage(target).ReadPixel(8,4)&255,200,"render-image pattern preserves vertical orientation")
 rejected=False
 texture.SetImage(target)
 Try
  light.DrawImage(art,0,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"third texture rejects render-target feedback")
 Check(GetBlend()=ALPHABLEND,"failed textured draw restores blend")
 texture.SetImage(pattern)
 Cls;light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(8,16)),200,"textured drawing recovers after feedback rejection")
 light.SetLightTexture(0,Null)
 Cls;light.DrawImage(art,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(24,16)),200,"clearing pattern restores analytic lighting")
 ' Cached receiver invalidation observes shared texture edits without new arrays.
 SetRenderImage(Null)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local environment:TSceneLighting=TSceneLighting.Create(layer),lamp:TPointLightNode=TPointLightNode.Create(100000)
 lamp.SetPosition(16,16);lamp.SetFalloff(1);lamp.SetTexture(texture);layer.AddChild(lamp)
 environment.SetAmbient(255,255,255,0);environment.SetLights([lamp])
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
 group.AddChild(TLitSpriteNode.Create(art,environment))
 SetRenderImage(target);Cls;environment.Prepare();scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(8,16)),200,"scene point projects shared pattern")
 environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged textured lighting keeps cached capture")
 texture.SetPlacement(32,32,0,0,180)
 Cls;environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=1,"shared placement edits invalidate cached receiver")
 Near(Red(ReadRenderImage(target).ReadPixel(24,16)),200,"cached receiver reflects rotated pattern")
 texture.Invalidate();environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=1,"explicit pixel invalidation reaches cached receiver")
 Local before:TMax2DStats=CaptureMax2DStats()
 For Local i:Int=0 Until 4
  environment.Prepare();scene.Render()
 Next
 Check(CaptureMax2DStats().textureCreations=before.textureCreations,"warm textured scene creates no textures")
 SetRenderImage(Null);scene.Destroy()
 texture.SetPlacement(32,32)
 Local stage:TSceneLightingStage=TSceneLightingStage.Create(1)
 stage.SetAmbient(255,255,255,0);stage.SetPointLight(0,16,16,100000,255,255,255,1,1);stage.SetLightTexture(0,texture)
 SetRenderImage(rendered);SetBlend(SOLIDBLEND);DrawImage(art,0,0);SetBlend(ALPHABLEND);SetRenderImage(Null)
 Local stageVersion:Long=stage.Revision()
 texture.Invalidate();stage.SetLightTexture(0,texture)
 Check(stage.Revision()<>stageVersion,"shared texture setter invalidates flattened stage")
 stage.Prepare(TSceneStageLayout.Create(TSceneRect.Create(0,0,32,32)))
 pixels=ReadRenderImage(stage.Update(rendered))
 Near(Red(pixels.ReadPixel(8,16)),200,"flattened stage projects pattern")
 Near((pixels.ReadPixel(24,16) Shr 8)&255,100,"flattened stage applies pattern alpha")
 stage.ReleaseResources();target.ReleaseFrames();rendered.ReleaseFrames();art.ReleaseFrames();region.ReleaseFrames();pattern.ReleaseFrames();normal.ReleaseFrames()
End Function

Function CheckShadows()
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0.1)
 light.SetPointLight(0,8,32,128,255,255,255,1,1)
 Local wall:TMax2DLightOccluder=TMax2DLightOccluder.Create([24.0,20.0,28.0,20.0,28.0,44.0,24.0,44.0])
 light.SetOccluders([wall]);light.SetLightShadows(0,True,256)
 Local source:TImage=CreateImage(64,64,1,0)
 Local pix:TPixmap=LockImage(source)
 For Local y:Int=0 Until 64
  For Local x:Int=0 Until 64
   pix.WritePixel(x,y,$ffffffff)
  Next
 Next
 UnlockImage(source)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
 SetColor(255,255,255);SetAlpha(1);SetBlend(ALPHABLEND)
 light.DrawImage(source,0,0)
 Local result:TPixmap=ReadRenderImage(target)
 Near(Red(result.ReadPixel(48,32)),26,"occluder leaves only ambient in shadow",2)
 Check(Red(result.ReadPixel(16,32))>210,"near side remains illuminated")
 Check(Red(result.ReadPixel(40,2))>120,"outside shadow remains illuminated")
 Near(Int(result.ReadPixel(48,32) Shr 24 & 255),255,"shadow preserves coverage")
 Check(TMax2DGraphics.Current().renderImage=target And GetBlend()=ALPHABLEND,"shadow mask restores drawing state")
 ResetMax2DStats();light.DrawImage(source,0,0)
 Check(CaptureMax2DStats().textureCreations=0,"warm shadows reuse images")
 wall.SetHeight(32);light.SetLightHeight(0,128);light.DrawImage(source,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(32,32)),26,"finite point shadow covers projected top",2)
 Check(Red(ReadRenderImage(target).ReadPixel(48,32))>150,"finite point shadow ends beyond projected top")
 light.SetPointLight(0,26,32,128,255,255,255,1,1);light.DrawImage(source,0,0)
 Check(Red(ReadRenderImage(target).ReadPixel(48,32))>150,"point above finite footprint does not black out whole mask")
 wall.SetHeight(-1);light.SetPointLight(0,8,32,128,255,255,255,1,1);light.DrawImage(source,0,0)
 light.ResetStats();light.SetPointLight(0,10000,10000,128);light.DrawImage(source,0,0)
 Local work:TMax2DLightingStats=light.CaptureStats()
 Check(work.LightTests()=1 And work.BoundsRejects()=1 And work.LightPasses()=0 And work.ShadowRequests()=0,"diagnostics record culled light without shadow work")
 light.ResetStats();light.SetLightMask(0,0);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ExcludedLights()=1,"diagnostics count mask exclusion before bounds test")
 light.SetLightMask(0,-1);light.SetPointLight(0,8,32,128,255,255,255,1,1);light.DrawImage(source,0,0)
 Local hard:TPixmap=ReadRenderImage(target)
 light.SetLightShadowSoftness(0,4);light.DrawImage(source,0,0)
 Local soft:TPixmap=ReadRenderImage(target),changed:Int,intermediate:Int
 For Local y:Int=0 Until 64
  For Local x:Int=0 Until 64
   Local a:Int=Red(hard.ReadPixel(x,y)),b:Int=Red(soft.ReadPixel(x,y))
   If Abs(a-b)>3 Then changed:+1
   If a<30 And b>35 Then intermediate:+1
  Next
 Next
 Check(changed>0 And intermediate>0,"soft filter adds intermediate shadow-edge coverage")
 Near(Red(soft.ReadPixel(48,32)),26,"soft shadow keeps deep interior dark",2)
 Check((soft.ReadPixel(48,32) Shr 24 & 255)=255,"soft shadow preserves receiver alpha")
 ResetMax2DStats();light.SetLightShadowSoftness(0,2);light.DrawImage(source,0,0)
 light.SetLightShadowSoftness(0,0);light.DrawImage(source,0,0)
 Check(CaptureMax2DStats().textureCreations=0,"softness changes reuse prepared images")
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),Red(hard.ReadPixel(48,32)),"zero softness restores hard mask",1)
 Local softVersion:Long=light.Revision(),badSoftness:Int
 Try
  light.SetLightShadowSoftness(0,5)
 Catch error:Object
  badSoftness=True
 End Try
 Check(badSoftness And light.Revision()=softVersion,"invalid softness rejected atomically")
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetReceiveShadows(False)
 light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 Check(Red(ReadRenderImage(target).ReadPixel(48,32))>170,"receiver can bypass shadows")
 wall.SetCasterMask(2);light.SetLightShadows(0,True,256,1)
 light.DrawImage(source,0,0)
 Check(Red(ReadRenderImage(target).ReadPixel(48,32))>170,"caster mask independent of receiver mask")
 wall.SetCasterMask(1);wall.SetEnabled(False);light.DrawImage(source,0,0)
 Check(Red(ReadRenderImage(target).ReadPixel(48,32))>170,"disabled caster does not block")
 wall.SetEnabled(True);light.DrawImage(source,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"caster edit rebuilds retained mask",2)
 Local version:Long=wall.Revision(),rejected:Int
 Try
  wall.SetPolygon([0.0,0.0,20.0,20.0,0.0,20.0,20.0,0.0])
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And wall.Revision()=version,"self-intersecting geometry rejected atomically")
 wall.SetPolygon([24.0,44.0,28.0,44.0,28.0,20.0,24.0,20.0])
 light.DrawImage(source,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"either polygon winding casts",2)
 light.SetPointLight(0,26,32,128);light.DrawImage(source,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(16,32)),26,"light inside opaque polygon is blocked",2)
 light.SetPointLight(0,8,32,128)
 Local pattern:TMax2DLightTexture=TMax2DLightTexture.Create(source)
 pattern.SetPlacement(256,256);light.SetLightTexture(0,pattern)
 material.SetReceiveShadows(True);material.SetSpecular(0.5,16)
 light.SetLightShadowSoftness(0,4)
 light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"pattern and specular respect shadows",2)
 Check(Red(ReadRenderImage(target).ReadPixel(16,32))>200,"combined pattern leaves lit side bright")
 ResetMax2DStats();light.SetPointLight(0,9,32,128);light.DrawImage(source,0,0)
 Check(CaptureMax2DStats().textureCreations=0,"moving light reuses shadow image")
 SetRenderImage(Null)
 Local captured:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(captured);SetBlend(SOLIDBLEND);DrawImage(source,0,0);SetRenderImage(Null)
 light.Prepare(64,64)
 Near(Red(ReadRenderImage(light.Update(captured)).ReadPixel(48,32)),26,"flattened lighting receives shadows",2)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local environment:TSceneLighting=TSceneLighting.Create(layer)
 environment.SetAmbient(255,255,255,0.1)
 Local lamp:TPointLightNode=TPointLightNode.Create(128)
 lamp.SetPosition(8,32);lamp.SetFalloff(1);lamp.SetShadows(True,256);layer.AddChild(lamp)
 environment.SetLights([lamp])
 Local caster:TLightOccluderNode=TLightOccluderNode.Create([0.0,0.0,4.0,0.0,4.0,24.0,0.0,24.0])
 caster.SetPosition(24,20);layer.AddChild(caster);environment.SetOccluders([caster])
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
 group.AddChild(TLitSpriteNode.Create(source,environment))
 SetRenderImage(target);SetBlend(ALPHABLEND);environment.Prepare();scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"scene caster projects transformed geometry",2)
 environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged shadowed scene preserves cache")
 lamp.SetShadowSoftness(4);environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=1,"softness edit invalidates cached receiver")
 environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged soft shadows retain scene cache")
 caster.SetPosition(24,70);environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=1,"moving caster invalidates cached receivers")
 Check(Red(ReadRenderImage(target).ReadPixel(48,32))>170,"moving caster changes shadow")
 caster.SetPosition(24,20);caster.SetScale(0,0);environment.Prepare();scene.Render()
 Check(Red(ReadRenderImage(target).ReadPixel(48,32))>170,"collapsed caster does not block")
 caster.SetScale(1,1);environment.Prepare();scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"restored caster casts again",2)
 caster.SetEnabled(False);environment.Prepare();scene.Render()
 Check(Red(ReadRenderImage(target).ReadPixel(48,32))>170,"disabled scene caster stops casting")
 caster.SetEnabled(True);caster.SetPolygon([0.0,0.0,4.0,0.0,4.0,24.0,0.0,24.0]);environment.Prepare();scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"replacing registered polygon updates lighting",2)
 SetRenderImage(Null);environment.ReleaseResources();scene.Destroy();captured.ReleaseFrames()
 Local stripes:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 16
   Local value:UInt=$ffffffff
   If x Mod 2 Then value=$ff202020
   stripes.WritePixel(x,y,Int(value))
  Next
 Next
 Local stripeImage:TImage=LoadImage(stripes,0)
 pattern.SetImage(stripeImage);pattern.SetPlacement(64,64)
 light.SetOccluders(Null);light.SetLightShadowSoftness(0,0)
 SetRenderImage(target);light.DrawImage(source,0,0);hard=ReadRenderImage(target)
 light.SetLightShadowSoftness(0,4);light.DrawImage(source,0,0);soft=ReadRenderImage(target)
 Local differences:Int
 For Local y:Int=8 Until 56
  For Local x:Int=0 Until 30
   If Abs(Red(hard.ReadPixel(x,y))-Red(soft.ReadPixel(x,y)))>2 Then differences:+1
  Next
 Next
 Check(differences=0,"shadow filtering preserves sharp projected pattern")
 SetRenderImage(Null);stripeImage.ReleaseFrames()
 light.Release();light.Release();target.ReleaseFrames();source.ReleaseFrames()
End Function

Function CheckDirectionalShadows()
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0.1);light.SetDirectionalLight(0,-1,0,1,255,255,255,0.8)
 light.SetLightShadows(0,True,256)
 Local wall:TMax2DLightOccluder=TMax2DLightOccluder.Create([24.0,20.0,28.0,20.0,28.0,44.0,24.0,44.0])
 light.SetOccluders([wall])
 Local source:TRenderImage=CreateRenderImage(64,64,0),target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(source);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
 SetClsColor(255,255,255,1);Cls
 SetRenderImage(target);SetColor(255,255,255);SetAlpha(1);SetBlend(ALPHABLEND)
 Local rejected:Int
 Try
  light.DrawImage(source,0,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"directional shadows require explicit bounds")
 Check(TMax2DGraphics.Current().renderImage=target And GetBlend()=ALPHABLEND,"missing bounds preserve target and blend")
 light.SetDirectionalShadowBounds(0,0,8,56,48);light.DrawImage(source,0,0)
 Local pixels:TPixmap=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(48,32)),26,"directional shadow extends opposite source vector",2)
 Near(Red(pixels.ReadPixel(16,32)),230,"source-facing side stays illuminated",2)
 Near(Red(pixels.ReadPixel(60,32)),230,"outside shadow bounds remains illuminated",2)
 Near(Red(pixels.ReadPixel(26,32)),26,"directional caster footprint blocks light",2)
 Near(Int(pixels.ReadPixel(48,32) Shr 24 & 255),255,"directional shadow preserves alpha")
 ResetMax2DStats();wall.SetHeight(12)
 light.DrawImage(source,0,0);pixels=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(36,32)),26,"finite caster projects twelve-unit shadow",2)
 Near(Red(pixels.ReadPixel(48,32)),230,"finite caster ends shadow",2)
 light.SetDirectionalLight(0,-1,0,3,255,255,255,0.8)
 light.DrawImage(source,0,0);pixels=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(36,32)),230,"higher sun shortens shadow",2)
 Near(Red(pixels.ReadPixel(30,32)),26,"higher sun retains short shadow",2)
 Check(CaptureMax2DStats().textureCreations=0,"height and elevation reuse shadow textures")
 Local heightVersion:Long=wall.Revision()
 wall.SetHeight(12)
 Check(wall.Revision()=heightVersion,"unchanged height preserves revision")
 rejected=False
 Try
  wall.SetHeight(-2)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And wall.GetHeight()=12 And wall.Revision()=heightVersion,"invalid caster height is atomic")
 wall.SetHeight(0);light.DrawImage(source,0,0);pixels=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(30,32)),230,"zero height has no extrusion",2)
 Near(Red(pixels.ReadPixel(26,32)),26,"zero height retains footprint",2)
 wall.SetHeight(-1);light.SetDirectionalLight(0,-1,0,1,255,255,255,0.8)
 Local diagnostics:TMax2DLightingStats=New TMax2DLightingStats
 light.ResetStats();light.DrawImage(source,0,0);light.CopyStats(diagnostics)
 Check(diagnostics.ReceiverDraws()=1 And diagnostics.LightTests()=1 And diagnostics.LightPasses()=1,"lighting diagnostics count receiver and direct pass")
 Check(diagnostics.ShadowRebuilds()=1 And diagnostics.ShadowCacheHits()=0 And diagnostics.OccluderTests()=1,"lighting diagnostics count rebuilt mask and caster work")
 Check(diagnostics.RetainedShadowBytes()=256*256*4,"lighting diagnostics estimate hard shadow memory")
 light.ResetStats();light.DrawImage(source,0,0);light.CopyStats(diagnostics)
 Check(diagnostics.ShadowCacheHits()=1 And diagnostics.ShadowRebuilds()=0 And diagnostics.OccluderTests()=0,"lighting diagnostics distinguish warm mask reuse")
 Local detached:TMax2DLightingStats=light.CaptureStats()
 light.ResetStats();light.CopyStats(diagnostics)
 Check(diagnostics.LightPasses()=0 And detached.LightPasses()=1 And diagnostics.RetainedShadowBytes()>0,"reset preserves storage and detached snapshots")
 Local version:Long=light.Revision()
 light.SetDirectionalShadowBounds(0,0,8,56,48)
 Check(version=light.Revision(),"unchanged directional bounds preserve revision")
 rejected=False
 Try
  light.SetDirectionalShadowBounds(0,0,0,0,48)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And version=light.Revision(),"invalid directional bounds rejected atomically")
 ResetMax2DStats();light.SetDirectionalLight(0,1,0,1,255,255,255,0.8);light.DrawImage(source,0,0)
 pixels=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(16,32)),26,"reversing direction reverses shadow",2)
 Near(Red(pixels.ReadPixel(48,32)),230,"reversed source side is illuminated",2)
 Check(CaptureMax2DStats().textureCreations=0,"direction changes reuse shadow storage")
 light.SetDirectionalLight(0,0,0,1,255,255,255,0.8);light.DrawImage(source,0,0)
 pixels=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(26,32)),26,"vertical light blocks caster footprint",2)
 Near(Red(pixels.ReadPixel(48,32)),230,"vertical light has no lateral shadow",2)
 light.SetDirectionalLight(0,-1,0,1,255,255,255,0.8)
 wall.SetPolygon([-24.0,20.0,-20.0,20.0,-20.0,44.0,-24.0,44.0]);light.DrawImage(source,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"caster outside bounds casts into shadow rectangle",2)
 wall.SetPolygon([24.0,20.0,28.0,20.0,28.0,44.0,24.0,44.0])
 light.SetLightShadows(0,True,256,2);wall.SetCasterMask(1);light.DrawImage(source,0,0)
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),230,"directional caster mask selects blockers",2)
 light.ResetStats()
 wall.SetCasterMask(2);light.SetLightShadowSoftness(0,4);light.DrawImage(source,0,0)
 light.CopyStats(diagnostics)
 Check(diagnostics.FilterPasses()=2 And diagnostics.RetainedShadowBytes()=256*256*12,"diagnostics count filtered mask passes and retained storage")
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"filtered directional shadow keeps interior",2)
 Near(Red(ReadRenderImage(target).ReadPixel(60,32)),230,"filtered shadow leaves outside bounds unshadowed",2)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetReceiveShadows(False);light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),230,"material bypasses directional shadows",2)
 material.SetReceiveShadows(True);material.SetNormalMap(source);material.SetNormalStrength(0);material.SetSpecular(0.5,16)
 light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"directional shadows block normal/specular contributions",2)
 Check(Red(ReadRenderImage(target).ReadPixel(16,32))>150,"directional normal/specular material remains lit outside shadow")
 SetRenderImage(Null);light.Prepare(64,64)
 Near(Red(ReadRenderImage(light.Update(source)).ReadPixel(48,32)),26,"flattened directional lighting receives shadows",2)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local environment:TSceneLighting=TSceneLighting.Create(layer)
 environment.SetAmbient(255,255,255,0.1)
 Local sun:TDirectionalLightNode=TDirectionalLightNode.Create(-1,0,1)
 sun.SetIntensity(0.8);sun.SetShadowBounds(0,8,56,48);sun.SetShadows(True,256);layer.AddChild(sun)
 environment.SetLights([TLightNode2D(sun)])
 Local caster:TLightOccluderNode=TLightOccluderNode.Create([24.0,20.0,28.0,20.0,28.0,44.0,24.0,44.0])
 layer.AddChild(caster);environment.SetOccluders([caster])
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
 group.AddChild(TLitSpriteNode.Create(source,environment))
 SetRenderImage(target);environment.Prepare();scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),26,"scene directional shadow matches core",2)
 environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged directional shadow retains cache")
 caster.SetHeight(12);environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=1,"caster height invalidates scene cache")
 Near(Red(ReadRenderImage(target).ReadPixel(48,32)),230,"scene finite height shortens shadow",2)
 caster.SetPolygon([24.0,20.0,28.0,20.0,28.0,44.0,24.0,44.0])
 Check(caster.GetHeight()=12,"polygon replacement preserves caster height")
 caster.SetHeight(-1);environment.Prepare();scene.Render()
 sun.SetPosition(100,100);environment.Prepare();scene.Render()
 Check(scene.CaptureStats().Captures()=0,"sun translation leaves explicit world shadow bounds unchanged")
 sun.SetRotation(180);environment.Prepare();scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(16,32)),26,"scene transform rotates shadow direction",2)
 Check(scene.CaptureStats().Captures()=1,"direction transform invalidates receiver cache")
 sun.SetShadowBounds(32,8,24,48);environment.Prepare();scene.Render()
 Near(Red(ReadRenderImage(target).ReadPixel(16,32)),230,"moving shadow bounds updates cached receiver",2)
 environment.ResetStats()
 Check(environment.CaptureStats().LightPasses()=0,"scene lighting exposes reset statistics")
 light.Release();light.CopyStats(diagnostics)
 Check(diagnostics.RetainedShadowBytes()=0,"released shadow storage disappears from diagnostics")
 SetRenderImage(Null);environment.ReleaseResources();scene.Destroy();light.Release();source.ReleaseFrames();target.ReleaseFrames()
End Function

Function CheckIndependentShadows()
 Local light:TMax2DLighting=TMax2DLighting.Create(2)
 For Local i:Int=0 Until 2
  light.SetPointLight(i,8+i*40,32,128)
  light.SetLightShadows(i,True,64)
 Next
 Local wall:TMax2DLightOccluder=TMax2DLightOccluder.Create([24.0,20.0,28.0,20.0,28.0,44.0,24.0,44.0])
 light.SetOccluders([wall])
 Local source:TRenderImage=CreateRenderImage(64,64,0),target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(source);SetVirtualResolution(64,64);SetViewport(0,0,64,64);SetClsColor(255,255,255,1);Cls
 SetRenderImage(target);SetColor(255,255,255);SetAlpha(1);SetBlend(ALPHABLEND)
 light.DrawImage(source,0,0)
 light.ResetStats();ResetMax2DStats()
 light.SetPointLight(0,9,32,128);light.DrawImage(source,0,0)
 Local work:TMax2DLightingStats=light.CaptureStats()
 Check(work.ShadowRebuilds()=1 And work.ShadowCacheHits()=1,"moving one light preserves other shadow masks")
 Check(CaptureMax2DStats().textureCreations=0,"independent invalidation reuses textures")
 light.ResetStats();light.SetAmbient(50,60,70,0.3)
 light.SetPointLight(0,9,32,128,200,100,50,0.7,3)
 light.SetLightMask(1,3);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=0 And light.CaptureStats().ShadowCacheHits()=2,"ambient colour energy falloff and receiver masks preserve geometry masks")
 light.ResetStats();light.SetLightHeight(0,200);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=1,"point height invalidates only its light")
 light.ResetStats();light.SetLightShadowSoftness(1,2);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=1 And light.CaptureStats().FilterPasses()=2,"softness edit rebuilds only selected light")
 light.ResetStats();wall.SetHeight(20);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=2,"caster within both point regions invalidates both shadows")
 Local pattern:TMax2DLightTexture=TMax2DLightTexture.Create(source)
 light.ResetStats();light.SetLightTexture(1,pattern);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=1,"pattern assignment invalidates only owning light")
 light.ResetStats();pattern.SetPlacement(48,48);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=1,"shared pattern edits invalidate its owning light")
 light.SetLightTexture(1,Null);light.DrawImage(source,0,0)
 light.ResetStats();light.SetDirectionalLight(0,-1,0,1);light.SetDirectionalShadowBounds(0,0,0,64,64);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=1,"light kind change preserves unrelated masks")
 light.ResetStats();light.SetDirectionalLight(0,-1,0,1,100,120,140,0.6);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=0,"directional colour change preserves masks")
 light.ResetStats();light.SetDirectionalLight(0,1,0,1);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=1,"direction change invalidates one mask")
 light.ResetStats();light.SetDirectionalShadowBounds(0,-8,-8,80,80);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=1,"bounds change invalidates one mask")
 light.ResetStats();light.SetLightCount(3);light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=0,"adding disabled slot preserves existing masks")
 light.ResetStats();light.Release();light.DrawImage(source,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=2,"release rebuilds active masks on next draw")
 SetRenderImage(Null);light.Release();source.ReleaseFrames();target.ReleaseFrames()
End Function

Function CheckPairedLighting()
 Local source:TImage=CreateImage(64,64,1,0)
 Local pixels:TPixmap=LockImage(source)
 For Local y:Int=0 Until 64
  For Local x:Int=0 Until 64
   Local alpha:Int=255-(x/16)*85
   pixels.WritePixel(x,y,Int((UInt(alpha) Shl 24) | $00dcb48c))
  Next
 Next
 UnlockImage(source)
 Local reference:TRenderImage=CreateRenderImage(64,64,0),paired:TRenderImage=CreateRenderImage(64,64,0)
 Local light:TMax2DLighting=TMax2DLighting.Create(5)
 Local wall:TMax2DLightOccluder=TMax2DLightOccluder.Create([25.0,20.0,29.0,20.0,29.0,44.0,25.0,44.0])
 light.SetOccluders([wall]);light.SetAmbient(255,255,255,0.15)
 Check(Not light.GetLightBatching(),"light pairing is opt-in")
 For Local variant:Int=0 Until 17
  Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
  If variant=4 Or variant=10 Or variant=11 Or variant>=15 Then material.SetSpecular(0.3,16)
  If variant=5 Or variant=9 Or variant>=11 Then material.SetNormalMap(source)
  If variant=8 Then material.SetReceiveShadows(False)
  For Local i:Int=0 Until 5
   light.SetPointLight(i,12+i*8,32,100,255,220-i*20,170+i*15,0.8,1)
   light.SetLightShadows(i,(variant>0 And variant<9) Or variant>=15,128)
   If (variant>1 And variant<9) Or variant>=15 Then light.SetLightShadowSoftness(i,2)
  Next
  If variant=3 Then light.SetPointLight(2,28,32,100,255,255,255,2,1)
  If variant=11 Then light.SetPointLight(1,20,32,100,255,255,255,2,1)
  If variant=11 Then light.SetDirectionalLight(2,0.4,-0.3,1,255,255,255,0.5)
  If variant=6 Or variant=16 Then light.SetDirectionalLight(2,0,0,1,255,255,255,0.5);light.SetDirectionalShadowBounds(2,0,0,64,64)
  Local baselinePasses:Long
  For Local mode:Int=0 To 1
   Local output:TRenderImage=reference
   If mode Then output=paired
   SetRenderImage(output);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
   SetClsColor(15,30,45,0.6);Cls;SetColor(230,210,190);SetAlpha(0.65);SetBlend(ALPHABLEND)
   light.SetLightBatching(mode);light.ResetStats()
   If variant=7 Or variant=12 Or variant=13 Or variant=15 Then
    Local sx:Float=0.7,ox:Float=12
    If variant=13 Or variant=15 Then sx=-0.7;ox=52
    SetOrigin(ox,3);SetRotation(17);SetScale(sx,0.8)
    light.DrawImage(source,0,0,0,-1,Float(Cos(17)*sx),Float(-Sin(17)*0.8),Float(Sin(17)*sx),Float(Cos(17)*0.8),ox,3,material)
    SetOrigin(0,0);SetRotation(0);SetScale(1,1)
   Else If variant=14 Then
    light.DrawImage(source,0,0,0,-1,0,0,0,0,0,0,material)
   Else
    light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
   End If
   Local work:TMax2DLightingStats=light.CaptureStats()
   Check(work.LightContributions()=5,"direct-light contribution count is independent of grouping")
   If Not mode Then
    baselinePasses=work.LightPasses()
   Else
    Check(work.GroupedPasses()=1 And work.LightPasses()=1 And work.PairedPasses()=0 And baselinePasses=5,"native renderer combines five shadowed or unshadowed contributions")
   End If
  Next
  Local expected:TPixmap=ReadRenderImage(reference),actual:TPixmap=ReadRenderImage(paired)
  Local maximum:Int,alphaSame:Int=True
  For Local y:Int=0 Until 64
   For Local x:Int=0 Until 64
    Local a:UInt=expected.ReadPixel(x,y),b:UInt=actual.ReadPixel(x,y)
    If (a Shr 24)<>(b Shr 24) Then alphaSame=False
    For Local shift:Int=0 To 16 Step 8
     maximum=Max(maximum,Abs(Int(a Shr shift & 255)-Int(b Shr shift & 255)))
    Next
   Next
  Next
  Local tolerance:Int=5
  Check(maximum<=tolerance,"grouped lighting matches reference RGB variant "+variant+" error "+maximum)
  Check(alphaSame,"paired lighting preserves reference alpha")
 Next
 ResetMax2DStats();light.DrawImage(source,0,0)
 Check(CaptureMax2DStats().textureCreations=0,"warm paired drawing reuses textures")
 Local additiveSource:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(additiveSource);SetClsColor(0,0,0,0.25);Cls
 SetColor(255,255,255);SetAlpha(1)
 SetBlend(CreateBlendMode(BLEND_ONE,BLEND_ONE,BLEND_OP_ADD,BLEND_ZERO,BLEND_ONE));DrawRect(0,0,64,64)
 light.SetLightCount(2);light.SetAmbient(255,255,255,0)
 For Local i:Int=0 Until 2
  light.SetPointLight(i,32,32,100000,255,255,255,0.8,1);light.SetLightShadows(i,False)
 Next
 Local referenceRed:Int
 For Local mode:Int=0 To 1
  SetRenderImage(paired);SetClsColor(0,0,0,1);Cls;SetBlend(ALPHABLEND)
  light.SetLightBatching(mode);light.DrawImage(additiveSource,0,0)
  Local value:Int=Red(ReadRenderImage(paired).ReadPixel(0,0))
  If Not mode Then referenceRed=value Else Check(Abs(value-referenceRed)<=2,"paired lighting preserves per-light clamping for additive source artwork")
 Next
 SetRenderImage(Null);additiveSource.ReleaseFrames()
 If Max2DSupportsRenderImage(64,64,0,PF_RGBA16F) Then
  Local hdr:TRenderImage=CreateRenderImage(64,64,0,PF_RGBA16F)
  light.SetLightCount(2);light.SetAmbient(255,255,255,0.2)
  For Local i:Int=0 Until 2
   light.SetPointLight(i,32,32,100000,255,255,255,0.8,1);light.SetLightShadows(i,False)
  Next
  Local baseline:Float
  For Local mode:Int=0 To 1
   SetRenderImage(hdr);SetClsColor(0,0,0,1);Cls;SetColor(255,255,255);SetAlpha(1)
   light.SetLightBatching(mode);light.DrawImage(source,0,0)
   Local data:TTextureData=ReadRenderTextureData(hdr),value:Float
   MemCopy(Varptr value,data.Level().Data(),4)
   If Not mode Then baseline=value Else Check(value>1 And Abs(value-baseline)<0.005,"paired lighting preserves HDR target range")
  Next
  light.SetLightCount(5)
  For Local i:Int=0 Until 5
   light.SetPointLight(i,12+i*8,32,100,255,220-i*20,170+i*15,0.8+i*0.2,1)
   light.SetLightShadows(i,False)
  Next
  light.SetDirectionalLight(2,0.4,-0.3,1,255,255,255,0.8)
  Local hdrMaterial:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
  hdrMaterial.SetNormalMap(source);hdrMaterial.SetSpecular(0.3,16)
  For Local shadowMode:Int=0 To 1
   For Local i:Int=0 Until 5
    light.SetLightShadows(i,shadowMode,128)
    If shadowMode Then light.SetLightShadowSoftness(i,2)
   Next
   If shadowMode Then light.SetDirectionalShadowBounds(2,0,0,64,64)
  Local referenceData:TTextureData
  For Local mode:Int=0 To 1
   SetRenderImage(hdr);SetClsColor(0,0,0,1);Cls
   light.SetLightBatching(mode);light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,hdrMaterial)
   Local data:TTextureData=ReadRenderTextureData(hdr)
   If Not mode Then
    referenceData=data
   Else
    Local expected:Float Ptr=Float Ptr(referenceData.Level().Data()),actual:Float Ptr=Float Ptr(data.Level().Data())
    Local maximum:Float
    For Local component:Int=0 Until 64*64*4
     maximum=Max(maximum,Abs(expected[component]-actual[component])/Max(1.0:Float,Abs(expected[component])))
    Next
    Check(maximum<0.006,"native normal/specular calculation matches floating-point reference: "+maximum)
   End If
  Next
  Next
  SetRenderImage(paired);light.ResetStats();light.DrawImage(hdr,0,0)
  Check(light.CaptureStats().PairedPasses()=0,"floating-point source uses ordinary path")
  SetRenderImage(Null);hdr.ReleaseFrames()
 End If
 SetRenderImage(Null);light.Release();source.ReleaseFrames();reference.ReleaseFrames();paired.ReleaseFrames()
 SetColor(255,255,255);SetAlpha(1)
End Function

' Deliberately rejecting/failing provider: verifies negotiation without pretending
' to implement a native grouped shader. Existing image tests exercise real draws.
Type TLightingProbeBackend Extends TMax2DLightingBackend
 Field created:Int,released:Int,mode:Int
 Field last:TLightingProbeRenderer
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Override
  created:+1
  last=New TLightingProbeRenderer;last.owner=Self
  Return last
 End Method
End Type
Type TLightingProbeRenderer Extends TMax2DLightingRenderer
 Field owner:TLightingProbeBackend
 Field attempts:String,draws:Int
 Field borrowed:TMax2DLightingDraw
 Field capturedKey:Object,capturedRevision:Long
 Field limits:TMax2DLightingCapabilities=TMax2DLightingCapabilities.Create(2,4,True,True,True,True,True)
 Method Capabilities:TMax2DLightingCapabilities() Override
  If owner.mode=2 Then Return New TMax2DLightingCapabilities
  Return limits
 End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  attempts:+draw.count+","
  If owner.mode=4 Then Throw "injected support failure"
  Return (owner.mode=1 Or owner.mode=3) And draw.count=3
 End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  draws:+1
  If owner.mode=3 Then
   capturedKey=draw.lights[0].mapKey;capturedRevision=draw.lights[0].mapRevision
   Return
  End If
  ' The test retains this reference only to inspect cleanup after the injected failure.
  borrowed=draw
  Check(draw.count=3 And draw.normalMap<>Null And Abs(draw.specularStrength-0.4)<0.00001,"renderer receives complete material and accepted prefix")
  Check(draw.lights[0].x=10 And draw.lights[1].x=20 And draw.lights[2].x=30,"renderer preserves selected light order")
  Local light:TMax2DLightingDrawLight=draw.lights[0]
  Check(light.shadowed And light.hasMap And light.map<>Null,"accepted group resolves shadow before submission")
  Check(light.mapKey<>Null And light.mapRevision>0,"resolved map exposes pixel cache identity")
  Check(Abs(light.mapXX*light.x+light.mapXY*light.y+light.mapTX-0.5)<0.00001,"resolved shadow maps lighting coordinates")
  Throw "injected lighting submission failure"
 End Method
 Method Release() Override
  owner.released:+1
 End Method
End Type

Function CheckLightingRendererContract()
 Local rejected:Int
 Try
  TMax2DLightingCapabilities.Create(3,2)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"renderer rejects inconsistent group limits")
 rejected=False
 Try
  RegisterMax2DLightingBackend(Null)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"renderer rejects null registration")
 Check(Not TMax2DLightingCapabilities.Create(1,8).SpecularMaps(),"existing providers default to no gloss-map support")
 Local request:TMax2DLightingDraw=New TMax2DLightingDraw
 request.Reserve(4)
 Local record:TMax2DLightingDrawLight=request.lights[0]
 request.Reserve(2)
 Check(request.lights.Length=4 And request.lights[0]=record,"group storage reuses capacity and records")
 Local backend:TLightingProbeBackend=New TLightingProbeBackend
 RegisterMax2DLightingBackend(backend);RegisterMax2DLightingBackend(backend)
 backend.mode=2;rejected=False
 Try
  CreateMax2DLightingRenderer(TMax2DGraphics.Current().context)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And backend.created=1 And backend.released=1,"invalid renderer capabilities release failed session: "+rejected+" / "+backend.created+" / "+backend.released)
 backend.mode=0
 Local source:TImage=CreateImage(32,32,1,0)
 Local pixels:TPixmap=LockImage(source)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   pixels.WritePixel(x,y,$ff8080ff)
  Next
 Next
 UnlockImage(source)
 Local target:TRenderImage=CreateRenderImage(32,32,0)
 Local light:TMax2DLighting=TMax2DLighting.Create(5)
 For Local i:Int=0 Until 5
  light.SetPointLight(i,10+i*10,16,100,255,255,255,0.1)
 Next
 light.SetAmbient(255,255,255,0)
 SetRenderImage(target);SetVirtualResolution(32,32);SetViewport(0,0,32,32)
 SetClsColor(0,0,0,1);SetColor(255,255,255);SetAlpha(1);SetBlend(SOLIDBLEND);Cls
 light.DrawImage(source,0,0)
 Local expected:UInt=ReadRenderImage(target).ReadPixel(16,16)
 Cls;light.SetLightBatching(True);light.ResetStats();light.DrawImage(source,0,0)
 Check(Abs(Red(ReadRenderImage(target).ReadPixel(16,16))-Red(Int(expected)))<=3,"declining provider preserves paired fallback pixels")
 Check(backend.created=2 And backend.last.attempts="4,3,2,3,2,","group negotiation tries ordered prefixes and registers once")
 Local stats:TMax2DLightingStats=light.CaptureStats()
 Check(stats.LightContributions()=5 And stats.GroupedPasses()=2 And stats.LightPasses()=3,"group diagnostics distinguish contributions from passes")
 Check(stats.GroupedLightContributions()=4 And stats.OrdinaryLightPasses()=1 And stats.MaximumGroupSize()=2,"diagnostics distinguish paired fallback from ordinary tail")
 Check(stats.GroupSupportChecks()=7 And stats.GroupSupportRejections()=5,"diagnostics count rejected native prefixes and accepted paired checks")
 Local copied:TMax2DLightingStats=New TMax2DLightingStats
 light.CopyStats(copied)
 light.ResetStats()
 Local reset:TMax2DLightingStats=light.CaptureStats()
 Check(reset.GroupedLightContributions()=0 And reset.OrdinaryLightPasses()=0 And reset.MaximumGroupSize()=0 And reset.GroupSupportChecks()=0 And reset.GroupSupportRejections()=0,"reset clears group diagnostics")
 Check(copied.GroupedLightContributions()=4 And copied.OrdinaryLightPasses()=1 And copied.MaximumGroupSize()=2 And copied.GroupSupportChecks()=7 And copied.GroupSupportRejections()=5,"copied group diagnostics remain detached after reset")

 backend.mode=1;backend.last.attempts=""
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(source);material.SetSpecular(0.4)
 light.SetLightShadows(0,True,64)
 light.ResetStats();rejected=False
 Local failure:String
 Try
  light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 Catch error:Object
  failure=error.ToString()
  rejected=failure="injected lighting submission failure"
 End Try
 Check(rejected And backend.last.attempts="4,3," And backend.last.draws=1,"submission error propagates without retrying or fallback: "+failure+" / "+backend.last.attempts+" / "+backend.last.draws)
 Check(GetBlend()=SOLIDBLEND And TMax2DGraphics.Current().renderImage=target,"failed grouped submission restores caller state")
 Check(backend.last.borrowed.source=Null And backend.last.borrowed.normalMap=Null And backend.last.borrowed.count=0 And backend.last.borrowed.lights[0].map=Null And backend.last.borrowed.lights[0].mapKey=Null,"failed submission clears borrowed image references")
 Check(light.CaptureStats().LightContributions()=0 And light.CaptureStats().GroupedPasses()=0,"failed group does not increment completed work")
 light.CopyStats(copied)
 Check(copied.GroupSupportChecks()=2 And copied.GroupSupportRejections()=1 And copied.GroupedLightContributions()=0 And copied.MaximumGroupSize()=0,"failed draw retains negotiation counts without completed groups")
 backend.mode=4;light.ResetStats();rejected=False
 Try
  light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 Catch error:Object
  rejected=error.ToString()="injected support failure"
 End Try
 light.CopyStats(copied)
 Check(rejected And copied.GroupSupportChecks()=1 And copied.GroupSupportRejections()=0 And copied.GroupedPasses()=0,"throwing Supports counts a check without rejection or completed draw")

 light.Release();light.Release()
 Check(backend.released=2,"processor releases renderer session exactly once")
 backend.mode=0;light.DrawImage(source,0,0)
 Check(backend.created=3,"release allows lazy renderer recreation")
 backend.mode=3;light.SetLightCount(3)
 light.SetLightShadows(0,False)
 Local pattern:TMax2DLightTexture=TMax2DLightTexture.Create(source)
 light.SetLightTexture(0,pattern)
 light.DrawImage(source,0,0)
 Local key:Object=backend.last.capturedKey,revision:Long=backend.last.capturedRevision
 Check(key=pattern And revision>0,"projected map supplies its own cache identity")
 pattern.SetPlacement(40,50,3,4,20)
 light.DrawImage(source,0,0)
 Check(backend.last.capturedKey=key And backend.last.capturedRevision=revision,"projection placement preserves pixel revision")
 pattern.Invalidate();light.DrawImage(source,0,0)
 Check(backend.last.capturedRevision>revision,"explicit pixel edits invalidate shared map storage")
 light.SetLightTexture(0,Null);light.SetLightShadows(0,True,64)
 light.DrawImage(source,0,0)
 key=backend.last.capturedKey;revision=backend.last.capturedRevision
 light.DrawImage(source,0,0)
 Check(backend.last.capturedKey=key And backend.last.capturedRevision=revision,"cached shadows preserve pixel identity and revision")
 light.SetPointLight(0,11,16,100,255,255,255,0.1)
 light.DrawImage(source,0,0)
 Check(backend.last.capturedKey=key And backend.last.capturedRevision>revision,"rebuilt shadows advance pixel revision")
 SetRenderImage(Null);light.Release();source.ReleaseFrames();target.ReleaseFrames()
End Function

Function CheckNativeLightGroups()
 Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 16
   pixels.WritePixel(x,y,$b0b09070)
  Next
 Next
 Local source:TImage=LoadImage(pixels,0)
 Local reference:TRenderImage=CreateRenderImage(16,16,0),output:TRenderImage=CreateRenderImage(16,16,0)
 Local light:TMax2DLighting=TMax2DLighting.Create()
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(source);material.SetSpecular(0.1,8)
 light.SetAmbient(255,255,255,0.1)
 Local rejected:Int
 Try
  light.SetLightBatchLimit(0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And light.GetLightBatchLimit()=16,"invalid batch limit preserves default")
 Print "Native light capacity: "+NativeLightCapacity()
 For Local requested:Int=EachIn [1,8,16]
 light.SetLightBatchLimit(requested)
 Local capacity:Int=NativeLightCapacity(requested)
 Check(light.GetLightBatchLimit()=requested And capacity<=requested,"requested batch limit is retained and bounds native capacity")
 For Local count:Int=EachIn [0,1,4,8,9,16,17]
  light.SetLightCount(count)
  For Local i:Int=0 Until count
   light.SetPointLight(i,8+i Mod 3,8,100,80+i*10,240-i*7,150,0.08,1)
  Next
  For Local mode:Int=0 To 1
   Local target:TRenderImage=reference
   If mode Then target=output
   SetRenderImage(target);SetVirtualResolution(16,16);SetViewport(0,0,16,16)
   SetClsColor(20,30,40,0.7);Cls;SetColor(255,255,255);SetAlpha(1);SetBlend(ALPHABLEND)
   light.SetLightBatching(mode);light.ResetStats()
   light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
   Local stats:TMax2DLightingStats=light.CaptureStats()
   Check(stats.LightContributions()=count,"native group boundary preserves contribution count")
   If mode Then Check(stats.CombinedAmbientPasses()=(count>0),"single or multiple native lights include ambient")
   If mode Then Check(stats.LightPasses()=(count+capacity-1)/capacity,"native group boundary follows negotiated capacity")
   If mode Then
    Check(stats.GroupedLightContributions()=count And stats.OrdinaryLightPasses()=0 And stats.MaximumGroupSize()=Min(count,capacity),"native diagnostics report actual group use")
    Check(stats.GroupSupportChecks()=stats.GroupedPasses() And stats.GroupSupportRejections()=0,"supported native groups need one support check per pass")
   Else
    Check(stats.GroupedLightContributions()=0 And stats.OrdinaryLightPasses()=count And stats.MaximumGroupSize()=0 And stats.GroupSupportChecks()=0 And stats.GroupSupportRejections()=0,"disabled batching reports ordinary work without negotiation")
   End If

  Next
  Local a:TPixmap=ReadRenderImage(reference),b:TPixmap=ReadRenderImage(output)
  Local error:Int,alphaSame:Int=True
  For Local y:Int=0 Until 16
   For Local x:Int=0 Until 16
    Local expected:UInt=a.ReadPixel(x,y),actual:UInt=b.ReadPixel(x,y)
    If (expected Shr 24)<>(actual Shr 24) Then alphaSame=False
    For Local shift:Int=0 To 16 Step 8
     error=Max(error,Abs(Int(expected Shr shift & 255)-Int(actual Shr shift & 255)))
    Next
   Next
  Next
  Check(error<=count/2+1 And alphaSame,"native groups preserve image and coverage across buffer boundaries: "+count+" / "+error)
 Next
 Next
 SetRenderImage(Null);light.Release();source.ReleaseFrames();reference.ReleaseFrames();output.ReleaseFrames()
End Function

Function CheckLightingAtlas()
 Local page:TMax2DLightingAtlas=New TMax2DLightingAtlas
 page.Prepare(16,8,4)
 Local source:TRenderImage=CreateRenderImage(8,8,0)
 Local other:TRenderImage=CreateRenderImage(8,8,0)
 Local request:TMax2DLightingDraw=New TMax2DLightingDraw
 request.Reserve(2)
 Local first:TMax2DLightingDrawLight=request.lights[0],second:TMax2DLightingDrawLight=request.lights[1]
 first.map=source;first.mapKey=New TMax2DLightingDraw;first.mapRevision=1
 second.map=other;second.mapKey=New TMax2DLightingDraw;second.mapRevision=1
 Local scope:TMax2DStateScope=ScopedMax2DState()
 Try
  SetRenderImage(source);SetClsColor(180,90,40,0.5);Cls
  SetRenderImage(other);SetClsColor(20,80,210,1);Cls
  SetRenderImage(Null)
  Local expected:Int=ReadRenderImage(source).ReadPixel(2,2)
  SetColor(33,55,77);SetAlpha(0.25);SetBlend(LIGHTBLEND)
  Local a:TMax2DLightingAtlasTile=page.Resolve(first)
  Local b:TMax2DLightingAtlasTile=page.Resolve(second)
  Check(a And b And a.x=0 And b.x=8,"atlas places adjacent maps without overlap")
  Local pixels:TPixmap=ReadRenderImage(page.image)
  Near(Red(pixels.ReadPixel(2,2)),Red(expected),"atlas preserves partial-alpha colour",1)
  Near(pixels.ReadPixel(2,2) Shr 24 & 255,expected Shr 24 & 255,"atlas preserves map alpha",1)
  Check(pixels.ReadPixel(10,2)=ReadRenderImage(other).ReadPixel(2,2),"atlas preserves neighbouring map")
  Check(TMax2DGraphics.Current().renderImage=Null And GetBlend()=LIGHTBLEND And GetAlpha()=0.25,"atlas restores target blend and alpha")
  ResetMax2DStats()
  For Local i:Int=0 Until 100
   page.Resolve(first);page.Resolve(second)
  Next
  Check(page.uploads=2 And page.hits=200,"warm atlas reuses unchanged maps")
  Local stats:TMax2DStats=CaptureMax2DStats()
  Check(stats.textureCreations=0,"warm atlas creates no textures")
  SetRenderImage(source);SetClsColor(240,100,30,1);Cls;SetRenderImage(Null)
  first.mapRevision:+1
  Check(page.Resolve(first)=a And page.uploads=3,"changed mask refreshes its existing tile")
  pixels=ReadRenderImage(page.image)
  Check(pixels.ReadPixel(2,2)=ReadRenderImage(source).ReadPixel(2,2),"atlas refreshes edited pixels")
  Check(pixels.ReadPixel(10,2)=ReadRenderImage(other).ReadPixel(2,2),"refresh leaves neighbour unchanged")
  first.mapKey=New TMax2DLightingDraw
  Check(page.Resolve(first)=Null And page.uploads=3 And page.count=2,"full atlas rejects new identity without eviction")
  first.mapKey=a.key;first.mapXX=0.5;first.mapClamp=True
  Check(page.Resolve(first)=a And page.uploads=3,"placement and sampling edits do not upload pixels")
  request.ClearImages()
  Check(Not first.mapKey And Not second.mapKey,"request cleanup releases map identities")
  SetRenderImage(page.image)
  Local rejected:Int
  Try
   page.Release()
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And page.image<>Null,"atlas rejects release while selected")
  SetRenderImage(Null)
 Finally
  scope.Close()
  page.Release();page.Release();source.ReleaseFrames();other.ReleaseFrames()
 End Try
End Function

Function CheckGroupedShadowStorage()
 Local source:TImage=CreateImage(32,32,1,0)
 Local pixels:TPixmap=LockImage(source)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   pixels.WritePixel(x,y,$b08080ff)
  Next
 Next
 UnlockImage(source)
 Local output:TRenderImage=CreateRenderImage(32,32,0)
 Local light:TMax2DLighting=TMax2DLighting.Create(8)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(source);material.SetSpecular(0.2,16)
 light.SetAmbient(255,255,255,0.1)
 light.SetOccluders([TMax2DLightOccluder.Create([14.0,8.0,17.0,8.0,17.0,24.0,14.0,24.0])])
 For Local i:Int=0 Until 8
  light.SetPointLight(i,4+i,16,100,255,220,180,0.04)
  light.SetLightShadows(i,True,128)
  light.SetLightShadowSoftness(i,2)
 Next
 SetRenderImage(output);SetVirtualResolution(32,32);SetViewport(0,0,32,32)
 SetColor(255,255,255);SetAlpha(1);SetBlend(ALPHABLEND);SetClsColor(0,0,0,0.6);Cls
 light.SetLightBatching(True)
 light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 Local work:TMax2DLightingStats=light.CaptureStats()
 Check(work.MapUploads()=8 And work.LightPasses()=1,"eight shadowed normal/specular lights share one pass")
 Check(work.RetainedMapBytes()=2048*2048*4,"atlas storage is reported separately from masks")
 light.ResetStats();ResetMax2DStats()
 light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 work=light.CaptureStats()
 Check(work.MapUploads()=0 And work.MapCacheHits()=8 And work.ShadowRebuilds()=0,"unchanged receivers reuse all atlas tiles")
 Check(CaptureMax2DStats().textureCreations=0,"warm grouped shadows create no textures")
 light.SetPointLight(0,6,16,100,255,220,180,0.04);light.ResetStats()
 light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 work=light.CaptureStats()
 Check(work.MapUploads()=1 And work.MapCacheHits()=7 And work.ShadowRebuilds()=1,"moving one light copies only its rebuilt mask")
 light.SetLightShadows(0,True,1024);light.ResetStats()
 light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
 work=light.CaptureStats()
 Check(work.LightContributions()=8 And work.LightPasses()=2 And work.MapUploads()=0,"oversized shadow falls back while following lights remain grouped")
 light.Release();light.SetLightCount(24)
 For Local i:Int=0 Until 24
  light.SetPointLight(i,4+i Mod 8,16,100,255,220,180,0.02)
  light.SetLightShadows(i,True,512)
 Next
 Local hdr:TRenderImage
 If Max2DSupportsRenderImage(32,32,0,PF_RGBA16F) Then hdr=CreateRenderImage(32,32,0,PF_RGBA16F)
 For Local hdrMode:Int=0 To 1
  If hdrMode And Not hdr Then Continue
  If hdrMode Then SetRenderImage(hdr) Else SetRenderImage(output)
  Local reference:TPixmap,referenceFloat:TTextureData
  For Local mode:Int=0 To 2
   Cls;light.SetLightBatching(mode<>0);light.ResetStats();ResetMax2DStats()
   light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
   If mode Then
    work=light.CaptureStats()
    Check(work.LightContributions()=24 And work.LightPasses()=(24+NativeLightCapacity()-1)/NativeLightCapacity(),"atlas capacity rollover keeps ordered groups")
    If mode=2 Then Check(CaptureMax2DStats().textureCreations=0,"capacity rollover reuses allocated atlas storage")
   End If
   If hdrMode Then
    Local actual:TTextureData=ReadRenderTextureData(hdr)
    If mode=0 Then
     referenceFloat=actual
    Else
     Local a:Float Ptr=Float Ptr(referenceFloat.Level().Data()),b:Float Ptr=Float Ptr(actual.Level().Data())
     Local maximum:Float
     For Local i:Int=0 Until 32*32*4
      maximum=Max(maximum,Abs(a[i]-b[i]))
     Next
     Check(maximum<0.006,"HDR atlas rollover preserves submitted groups without normalized rounding: "+maximum)
    End If
   Else
    Local actual:TPixmap=ReadRenderImage(output)
    If mode=0 Then
     reference=actual
    Else
     Local maximum:Int,alphaSame:Int=True
     For Local y:Int=0 Until 32
      For Local x:Int=0 Until 32
       Local a:UInt=reference.ReadPixel(x,y),b:UInt=actual.ReadPixel(x,y)
       If a Shr 24<>b Shr 24 Then alphaSame=False
       For Local shift:Int=0 To 16 Step 8
        maximum=Max(maximum,Abs(Int(a Shr shift & 255)-Int(b Shr shift & 255)))
       Next
      Next
     Next
     ' Ordinary normalized fragment output and repeated alpha blending each
     ' quantize. Allow one channel level per light; HDR above checks the math.
     Check(maximum<=24 And alphaSame,"normalized atlas rollover preserves coverage and bounded rounding: "+maximum)
    End If
   End If
  Next
 Next
 SetRenderImage(Null)
 If hdr Then hdr.ReleaseFrames()
 SetRenderImage(Null);light.Release();source.ReleaseFrames();output.ReleaseFrames()
End Function

Function CheckGroupedPatterns()
 Local pixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
 For Local y:Int=0 Until 8
  For Local x:Int=0 Until 8
   Local colour:UInt=$00ff00ff
   If x Mod 3=1 Then colour=$8000ff40
   If x Mod 3=2 Then colour=$ffff8000
   If y<2 Then colour=$c00040ff
   pixels.WritePixel(x,y,Int(colour))
  Next
 Next
 Local filtered:TImage=LoadImage(pixels,FILTEREDIMAGE),nearest:TImage=LoadImage(pixels,0)
 Local coverage:TImage=TImage.FromPixmap(pixels,FILTEREDIMAGE,PF_A8)
 Local view:TImage=CreateImageView(filtered,1,0,6,8)
 Local rendered:TRenderImage=CreateRenderImage(8,8,FILTEREDIMAGE)
 SetRenderImage(rendered);SetVirtualResolution(8,8);SetViewport(0,0,8,8)
 SetColor(255,255,255);SetAlpha(1);SetClsColor(0,0,0,0);Cls;SetBlend(ALPHABLEND);DrawImage(filtered,0,0)
 For Local y:Int=0 Until 8
  For Local x:Int=0 Until 8
   pixels.WritePixel(x,y,$b08080ff)
  Next
 Next
 Local art:TImage=LoadImage(pixels,FILTEREDIMAGE)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(art);material.SetSpecular(0.2,16)
 Local reference:TRenderImage=CreateRenderImage(32,32,0),output:TRenderImage=CreateRenderImage(32,32,0)
 For Local variant:Int=0 Until 6
  Local pattern:TImage=filtered
  If variant=1 Then pattern=nearest
  If variant=2 Then pattern=rendered
  If variant=3 Then pattern=view
  If variant=4 Then pattern=coverage
  Local texture:TMax2DLightTexture=TMax2DLightTexture.Create(pattern)
  texture.SetPlacement(22,26,1,-2,23)
  Local light:TMax2DLighting=TMax2DLighting.Create(5)
  light.SetAmbient(255,255,255,0.1)
  light.SetOccluders([TMax2DLightOccluder.Create([14.0,8.0,17.0,8.0,17.0,24.0,14.0,24.0])])
  For Local i:Int=0 Until 5
   light.SetPointLight(i,12+i*2,16,100,255,240,200,0.35)
   If i<3 Then light.SetLightTexture(i,texture)
   If variant=5 Then light.SetLightShadows(i,True,128);light.SetLightShadowSoftness(i,2)
  Next
  For Local mode:Int=0 To 1
   If mode Then SetRenderImage(output) Else SetRenderImage(reference)
   SetVirtualResolution(32,32);SetViewport(0,0,32,32);SetClsColor(10,20,30,0.6);Cls
   SetColor(230,210,190);SetAlpha(0.8);SetBlend(ALPHABLEND)
   SetScale(4,4)
   light.SetLightBatching(mode);light.DrawImage(art,0,0,0,-1,4,0,0,4,0,0,material)
   SetScale(1,1)
  Next
  Local a:TPixmap=ReadRenderImage(reference),b:TPixmap=ReadRenderImage(output)
  Local maximum:Int,alphaSame:Int=True
  For Local y:Int=0 Until 32
   For Local x:Int=0 Until 32
    Local expected:UInt=a.ReadPixel(x,y),actual:UInt=b.ReadPixel(x,y)
    If expected Shr 24<>actual Shr 24 Then alphaSame=False
    For Local shift:Int=0 To 16 Step 8
     maximum=Max(maximum,Abs(Int(expected Shr shift & 255)-Int(actual Shr shift & 255)))
    Next
   Next
  Next
  Check(maximum<=5 And alphaSame,"grouped projected pattern matches reference variant "+variant+": "+maximum)
  Local work:TMax2DLightingStats=light.CaptureStats()
  Check(work.GroupedPasses()=1,"pattern and analytic lights share one native group")
  If variant<5 Then Check(work.MapUploads()=1,"shared projected image occupies one atlas tile")
  light.ResetStats();ResetMax2DStats()
  texture.SetPlacement(24,20,-2,1,-13)
  light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
  work=light.CaptureStats()
  If variant<5 Then
   Check(work.MapUploads()=0,"projected placement changes reuse cached pixels")
  Else
   Check(work.MapUploads()=3 And work.ShadowRebuilds()=3,"pattern placement refreshes only its three combined shadow maps")
  End If
  Check(CaptureMax2DStats().textureCreations=0,"warm projected groups reuse textures")
  If variant<5 Then
   texture.Invalidate();light.ResetStats()
   light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
   Check(light.CaptureStats().MapUploads()=1,"shared pattern invalidation uploads once")
  End If
  If variant=0 Then
   texture.SetImage(output)
   Local rejected:Int
   Try
    light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
   Catch error:Object
    rejected=True
   End Try
   Check(rejected And TMax2DGraphics.Current().renderImage=output And GetBlend()=ALPHABLEND,"grouped pattern feedback rejects and restores state")
   Local mipmapped:TImage=LoadImage(pixels,FILTEREDIMAGE | MIPMAPPEDIMAGE)
   texture.SetImage(mipmapped);light.ResetStats()
   light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
   work=light.CaptureStats()
   Check(work.LightContributions()=5 And work.LightPasses()=4 And work.MapUploads()=0,"mipmapped patterns keep ordered fallback with analytic grouping")
   mipmapped.ReleaseFrames()
  End If
  light.Release()
 Next
 SetRenderImage(Null);reference.ReleaseFrames();output.ReleaseFrames();rendered.ReleaseFrames()
 filtered.ReleaseFrames();nearest.ReleaseFrames();coverage.ReleaseFrames();art.ReleaseFrames()
End Function

Function CheckCombinedAmbient()
 Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 16
   pixels.WritePixel(x,y,Int((UInt(x*17) Shl 24) | $00c08040))
  Next
 Next
 Local art:TImage=LoadImage(pixels,0),mip:TImage=LoadImage(pixels,FILTEREDIMAGE | MIPMAPPEDIMAGE)
 Local pattern:TMax2DLightTexture=TMax2DLightTexture.Create(mip)
 Local reference:TRenderImage=CreateRenderImage(32,32,0),output:TRenderImage=CreateRenderImage(32,32,0)
 For Local variant:Int=0 Until 8
  If variant=7 Then
   If Not Max2DSupportsRenderImage(32,32,0,PF_RGBA16F) Then Continue
   SetRenderImage(Null);reference.ReleaseFrames();output.ReleaseFrames()
   reference=CreateRenderImage(32,32,0,PF_RGBA16F);output=CreateRenderImage(32,32,0,PF_RGBA16F)
  End If
  Local light:TMax2DLighting=TMax2DLighting.Create(9)
  light.SetAmbient(180,220,255,0.4)
  If variant=0 Then light.SetAmbient(255,255,255,0)
  If variant=1 Or variant=7 Then light.SetAmbient(255,220,180,3)
  For Local i:Int=0 Until 9
   light.SetPointLight(i,8+i,16,60,180,210,255,0.12)
  Next
  If variant=4 Then light.SetLightCount(1)
  If variant=5 Then light.SetLightTexture(0,pattern)
  If variant=6 Then light.SetLightTexture(8,pattern)
  Local receiverMask:Int=-1
  If variant=3 Then receiverMask=0
  For Local mode:Int=0 To 1
   If mode Then SetRenderImage(output) Else SetRenderImage(reference)
   SetVirtualResolution(32,32);SetViewport(0,0,32,32)
   SetClsColor(70,40,100,0.35);Cls
   SetColor(220,200,180);SetAlpha(0.65);SetBlend(ALPHABLEND)
   DrawImage(art,3,5)
   SetViewport(6,3,19,25);SetScale(1.5,1.5);SetBlend(SOLIDBLEND)
   light.SetLightBatching(mode);light.ResetStats()
   light.DrawImage(art,4,4,0,receiverMask,1.5,0,0,1.5)
   SetScale(1,1);SetViewport(0,0,32,32)
   Local work:TMax2DLightingStats=light.CaptureStats()
   Local combined:Int=mode And (variant<3 Or variant=4 Or variant>=6)
   Check(work.AmbientPasses()=1 And work.CombinedAmbientPasses()=combined,"ambient is composed once, variant "+variant+" mode "+mode)
   Check(GetBlend()=SOLIDBLEND,"combined ambient restores blend")
   If mode And variant=2 Then Check(work.LightPasses()=(9+NativeLightCapacity()-1)/NativeLightCapacity() And work.LightContributions()=9,"ambient is composed once across negotiated groups")
  Next
  If variant=7 Then
   Local expected:TTextureData=ReadRenderTextureData(reference),actual:TTextureData=ReadRenderTextureData(output)
   Local a:Float Ptr=Float Ptr(expected.Level().Data()),b:Float Ptr=Float Ptr(actual.Level().Data())
   Local maximum:Float
   For Local i:Int=0 Until 32*32*4
    maximum=Max(maximum,Abs(a[i]-b[i]))
   Next
   Check(maximum<0.012,"HDR combined ambient preserves overbright transparent composition: "+maximum)
  Else
  Local a:TPixmap=ReadRenderImage(reference),b:TPixmap=ReadRenderImage(output)
  Local maximum:Int,alphaSame:Int=True
  For Local y:Int=0 Until 32
   For Local x:Int=0 Until 32
    Local expected:UInt=a.ReadPixel(x,y),actual:UInt=b.ReadPixel(x,y)
    If expected Shr 24<>actual Shr 24 Then alphaSame=False
    For Local shift:Int=0 To 16 Step 8
     maximum=Max(maximum,Abs(Int(expected Shr shift & 255)-Int(actual Shr shift & 255)))
    Next
   Next
  Next
  ' Nine direct contributions plus ambient undergo repeated normalized rounding.
  Check(maximum<=12 And alphaSame,"combined ambient matches ordinary composition, variant "+variant+": "+maximum)
  End If
  light.ResetStats()
  Check(light.CaptureStats().AmbientPasses()=0 And light.CaptureStats().CombinedAmbientPasses()=0,"ambient counters reset")
  light.Release()
 Next
 SetRenderImage(Null);reference.ReleaseFrames();output.ReleaseFrames();art.ReleaseFrames();mip.ReleaseFrames()
End Function


Function NativeLightCapacity:Int(limit:Int=16)
 Local renderer:TMax2DLightingRenderer=CreateNativeMax2DLightingRenderer(TMax2DGraphics.Current().context,limit)
 If Not renderer Then Throw "Missing native lighting renderer"
 Local capacity:Int=renderer.Capabilities().MaximumLights()
 renderer.Release()
 Return capacity
End Function

Function CheckLightGroupMaterials()
 Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 16
   pixels.WritePixel(x,y,Int((UInt(80+x*9) Shl 24) | $00a08060))
  Next
 Next
 Local source:TImage=LoadImage(pixels,FILTEREDIMAGE)
 Local texture:TMax2DLightTexture=TMax2DLightTexture.Create(source)
 texture.SetPlacement(25,22,1,-2,17)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(source);material.SetSpecular(0.15,16)
 Local reference:TRenderImage=CreateRenderImage(16,16,0),output:TRenderImage=CreateRenderImage(16,16,0)
 For Local shadowed:Int=0 To 1
 For Local count:Int=EachIn [1,4,8,9,16]
  Local light:TMax2DLighting=TMax2DLighting.Create(count)
  light.SetAmbient(220,200,180,0.15)
  light.SetOccluders([TMax2DLightOccluder.Create([7.0,5.0,9.0,5.0,9.0,12.0,7.0,12.0])])
  For Local i:Int=0 Until count
   light.SetPointLight(i,4+i Mod 8,8,40,220,240,255,0.08)
   light.SetLightTexture(i,texture)
   If shadowed Then light.SetLightShadows(i,True,128);light.SetLightShadowSoftness(i,2)
  Next
  For Local limit:Int=EachIn [0,8,16]
   If limit Then SetRenderImage(output) Else SetRenderImage(reference)
   SetVirtualResolution(16,16);SetViewport(0,0,16,16);SetClsColor(40,20,60,0.45);Cls
   SetColor(230,210,190);SetAlpha(0.8);SetBlend(ALPHABLEND)
   light.SetLightBatching(limit<>0)
   If limit Then light.SetLightBatchLimit(limit)
   light.ResetStats();light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
   If Not limit Then Continue
   Local work:TMax2DLightingStats=light.CaptureStats(),capacity:Int=NativeLightCapacity(limit)
   Check(work.LightPasses()=(count+capacity-1)/capacity And work.LightContributions()=count And work.CombinedAmbientPasses()=1,"patterned material follows selected light capacity")
   Check(work.ShadowRebuilds()=0,"changing native capacity preserves prepared shadow masks")
   Local a:TPixmap=ReadRenderImage(reference),b:TPixmap=ReadRenderImage(output)
   Local maximum:Int,alphaSame:Int=True
   For Local y:Int=0 Until 16
    For Local x:Int=0 Until 16
     Local expected:UInt=a.ReadPixel(x,y),actual:UInt=b.ReadPixel(x,y)
     If expected Shr 24<>actual Shr 24 Then alphaSame=False
     For Local shift:Int=0 To 16 Step 8
      maximum=Max(maximum,Abs(Int(expected Shr shift & 255)-Int(actual Shr shift & 255)))
     Next
    Next
   Next
   Check(maximum<=count+2 And alphaSame,"grouped patterned/shadowed material matches ordinary: "+count+"/"+limit+"/"+shadowed+" error "+maximum)
   light.ResetStats();ResetMax2DStats()
   light.DrawImage(source,0,0,0,-1,1,0,0,1,0,0,material)
   Check(light.CaptureStats().MapUploads()=0 And CaptureMax2DStats().textureCreations=0,"warm material groups reuse maps and textures")
  Next
  light.Release()
 Next
 Next
 SetRenderImage(Null);source.ReleaseFrames();reference.ReleaseFrames();output.ReleaseFrames()
End Function

Function CheckTrimmedLighting()
 Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 pixels.ClearPixels(0)
 For Local y:Int=3 Until 13
  For Local x:Int=4 Until 12
   pixels.WritePixel(x,y,$b08080ff)
  Next
 Next
 Local atlas:TTextureAtlas=TTextureAtlas.Create(64,FILTEREDIMAGE)
 Local trimmed:TImage=atlas.AddPixmap(pixels,"trim",True)
 Local full:TImage=LoadImage(pixels,FILTEREDIMAGE)
 full.handle_x=2;full.handle_y=1;trimmed.handle_x=2;trimmed.handle_y=1
 Local light:TMax2DLighting=TMax2DLighting.Create(3)
 light.SetAmbient(255,255,255,0.2)
 For Local i:Int=0 Until 3
  light.SetPointLight(i,5+i*4,6,40,255,180,100,0.15)
 Next
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetSpecular(0.2,8)
 Local output:TRenderImage=CreateRenderImage(16,16)
 For Local grouped:Int=0 Until 2
  light.SetLightBatching(grouped)
  Local reference:TPixmap
  For Local variant:Int=0 Until 2
   Local source:TImage=full
   If variant Then source=trimmed
   material.SetNormalMap(source)
   SetRenderImage(output);SetVirtualResolution(16,16);SetViewport(0,0,16,16)
   ResetCoordinates();SetScale(1,1);SetRotation(0);SetColor(255,255,255);SetAlpha(1);SetClsColor(0,0,0,0);Cls
   light.DrawImage(source,2,1,0,-1,1,0,0,1,0,0,material)
   Local result:TPixmap=ReadRenderImage(output)
   If Not variant Then
    reference=result
   Else
    Local same:Int=True
    For Local y:Int=0 Until 16
     For Local x:Int=0 Until 16
      If reference.ReadPixel(x,y)<>result.ReadPixel(x,y) Then same=False
     Next
    Next
    Check(same,"trimmed artwork and normal map match full logical image: "+grouped)
    If grouped Then Check(light.CaptureStats().GroupedPasses()>0,"trimmed receivers use native groups")
   End If
  Next
 Next
 light.Release();SetRenderImage(Null);output.ReleaseFrames()
End Function

Function CheckTrimmedPatterns()
 Local artwork:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 artwork.ClearPixels($b0c0a080)
 Local source:TImage=LoadImage(artwork,0)
 Local output:TRenderImage=CreateRenderImage(16,16)
 For Local filtered:Int=0 To 1
  Local flags:Int
  If filtered Then flags=FILTEREDIMAGE
  Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
  pixels.ClearPixels(0)
  For Local y:Int=3 Until 13
   For Local x:Int=4 Until 12
    pixels.WritePixel(x,y,$c0d06020)
   Next
  Next
  Local atlas:TTextureAtlas=TTextureAtlas.Create(64,flags)
  Local trimmed:TImage=atlas.AddPixmap(pixels,"pattern",True)
  Local full:TImage=LoadImage(pixels,flags)
  trimmed.handle_x=5;trimmed.handle_y=2
  full.handle_x=5;full.handle_y=2
  Local animation:TImage=TImage.Animation([trimmed,trimmed],[100,100])
  Local fullPattern:TMax2DLightTexture=TMax2DLightTexture.Create(full)
  Local trimPattern:TMax2DLightTexture=TMax2DLightTexture.Create(animation,1)
  fullPattern.SetPlacement(23,21,1,-2,17)
  trimPattern.SetPlacement(23,21,1,-2,17)
  Check(trimPattern.GetImage()=animation And trimPattern.GetFrame()=1,"projected trim retains original animation binding")
  For Local shadow:Int=0 To 2
   For Local grouped:Int=0 To 1
    Local light:TMax2DLighting=TMax2DLighting.Create(3)
    light.SetAmbient(255,255,255,0.1);light.SetLightBatching(grouped)
    light.SetOccluders([TMax2DLightOccluder.Create([7.0,5.0,9.0,5.0,9.0,12.0,7.0,12.0])])
    For Local i:Int=0 Until 3
     light.SetPointLight(i,5+i*3,8,30,255,240,200,0.2)
     If shadow Then light.SetLightShadows(i,True,128)
     If shadow=2 Then light.SetLightShadowSoftness(i,2)
    Next
    Local before:TPixmap
    For Local edit:Int=0 To 1
     For Local y:Int=3 Until 13
      For Local x:Int=4 Until 12
       If edit Then pixels.WritePixel(x,y,$a020b0f0) Else pixels.WritePixel(x,y,$c0d06020)
      Next
     Next
     full.ReplacePixels(pixels);trimmed.ReplacePixels(pixels)
     fullPattern.Invalidate();trimPattern.Invalidate()
     Local reference:TPixmap
     For Local variant:Int=0 To 1
      Local pattern:TMax2DLightTexture=fullPattern
      If variant Then pattern=trimPattern
      For Local i:Int=0 Until 3
       light.SetLightTexture(i,pattern)
      Next
      SetRenderImage(output);SetVirtualResolution(16,16);SetViewport(0,0,16,16)
      ResetCoordinates();SetScale(1,1);SetRotation(0);SetColor(255,255,255);SetAlpha(1)
      SetClsColor(0,0,0,0);Cls
      light.ResetStats();light.DrawImage(source,0,0)
      Local result:TPixmap=ReadRenderImage(output)
      If Not variant Then
       reference=result
      Else
       Local same:Int=True,changed:Int=False
       For Local y:Int=0 Until 16
        For Local x:Int=0 Until 16
         If reference.ReadPixel(x,y)<>result.ReadPixel(x,y) Then same=False
         If before Then
          If before.ReadPixel(x,y)<>result.ReadPixel(x,y) Then changed=True
         End If
        Next
       Next
       Check(same,"trimmed projected pattern matches full image: "+filtered+"/"+shadow+"/"+grouped+"/"+edit)
       If edit Then Check(changed,"projected pixel edit changes rendered illumination") Else before=result
       If grouped Then Check(light.CaptureStats().GroupedPasses()>0,"trimmed patterns keep grouped lighting")
       light.ResetStats();ResetMax2DStats()
       light.DrawImage(source,0,0);TMax2DGraphics.Current().context.Flush()
       Local stats:TMax2DStats=CaptureMax2DStats()
       Check(light.CaptureStats().MapUploads()=0 And light.CaptureStats().ShadowRebuilds()=0 And stats.textureCreations=0 And stats.textureUpdates=0 And stats.readbacks=0,"warm trimmed patterns reuse sampling, atlas and shadows")
      End If
     Next
    Next
    ' Keep the same description bound while clearing its stored footprint.
    pixels.ClearPixels(0);trimmed.ReplacePixels(pixels);trimPattern.Invalidate()
    SetRenderImage(output);Cls;light.ResetStats()
    light.DrawImage(source,0,0)
    Local cleared:TPixmap=ReadRenderImage(output)
    Local refreshed:TMax2DLightingStats=light.CaptureStats()
    If grouped Then Check(refreshed.MapUploads()>0,"same-binding invalidation refreshes native tiles")
    If shadow Then Check(refreshed.ShadowRebuilds()=3,"same-binding invalidation refreshes shadow patterns")
    light.SetLightCount(0)
    Cls;light.DrawImage(source,0,0)
    Local ambient:TPixmap=ReadRenderImage(output)
    Local clearSame:Int=True
    For Local y:Int=0 Until 16
     For Local x:Int=0 Until 16
      If cleared.ReadPixel(x,y)<>ambient.ReadPixel(x,y) Then clearSame=False
     Next
    Next
    Check(clearSame,"cleared trimmed pattern leaves ambient only without stale atlas margins")
    light.Release()
   Next
  Next
 Next
 SetRenderImage(Null);output.ReleaseFrames();source.ReleaseFrames()
End Function

Function CheckLitCanvas()
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local lighting:TSceneLighting=TSceneLighting.Create(layer)
 lighting.SetAmbient(255,255,255,1)
 Local canvas:TTestLitCanvas=New TTestLitCanvas
 canvas.InitializeLighting(lighting);canvas.SetCanvas(-4,-3,16,16);canvas.SetPosition(8,8)
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group);group.AddChild(canvas)
 Local target:TRenderImage=CreateRenderImage(32,32)
 SetRenderImage(target);SetVirtualResolution(32,32);SetViewport(0,0,32,32);SetClsColor(0,0,0,0);Cls
 lighting.Prepare();scene.Render()
 Local pixels:TPixmap=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(6,6)),200,"lit canvas retains capture offset and colour")
 Near(pixels.ReadPixel(6,6) Shr 24 & 255,128,"lit canvas preserves alpha")
 Check(canvas.paints=1,"canvas captures once")
 lighting.SetAmbient(255,0,0,1);lighting.Prepare();Cls;scene.Render()
 Check(canvas.paints=1,"light changes refresh enclosing cache without repainting")
 pixels=ReadRenderImage(target)
 Near(pixels.ReadPixel(6,6)&255,0,"canvas uses changed environment")
 canvas.SetPosition(10,8);lighting.Prepare();scene.Render()
 Check(canvas.paints=1,"receiver movement reuses capture")
 canvas.InvalidateCanvas();lighting.Prepare();scene.Render()
 Check(canvas.paints=2,"paint invalidation reaches enclosing automatic cache")
 canvas.GetMaterial().SetUnlit(True);lighting.Prepare();Cls;scene.Render()
 pixels=ReadRenderImage(target)
 Near(pixels.ReadPixel(8,6)&255,80,"unlit canvas bypasses lighting")
 Check(canvas.paints=2,"material edits reuse capture")
 scene.ReleaseResources();lighting.Prepare();scene.Render()
 Check(canvas.paints=3,"resource release recaptures canvas")
 canvas.fail=True;canvas.InvalidateCanvas();lighting.Prepare()
 Local rejected:Int
 Try
  scene.Render()
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And TMax2DGraphics.Current().renderImage=target,"paint failure restores caller target")
 canvas.fail=False;scene.Render()
 Check(canvas.paints=5,"failed capture retries on next render")
 canvas.GetMaterial().SetUnlit(False);canvas.GetMaterial().SetReceiverMask(2)
 lighting.SetAmbient(255,255,255,0)
 Local lamp:TPointLightNode=TPointLightNode.Create(10000)
 lamp.SetColor(255,0,0);lamp.SetReceiverMask(1);layer.AddChild(lamp)
 lighting.SetLights([TLightNode2D(lamp)])
 lighting.Prepare();Cls;scene.Render();pixels=ReadRenderImage(target)
 Near(Red(pixels.ReadPixel(8,6)),0,"canvas respects receiver mask")
 canvas.GetMaterial().SetReceiverMask(1);lighting.Prepare();Cls
 ResetMax2DStats();scene.Render();pixels=ReadRenderImage(target)
 Check(Red(pixels.ReadPixel(8,6))>150,"canvas receives selected light")
 Check(canvas.paints=5 And CaptureMax2DStats().textureCreations=0,"material changes reuse canvas storage and paint")
 scene.Destroy();lighting.ReleaseResources();SetRenderImage(Null);target.ReleaseFrames()
End Function

Function CheckSpatialSelection()
 Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 pixels.ClearPixels($c0908070)
 Local source:TImage=LoadImage(pixels,0),output:TRenderImage=CreateRenderImage(16,16)
 Local lighting:TMax2DLighting=TMax2DLighting.Create(256)
 lighting.SetAmbient(255,255,255,0.2);lighting.SetLightBatching(True)
 For Local i:Int=0 Until 256
  Local column:Int=(i*73) Mod 256
  lighting.SetPointLight(i,column*80,0,30,255,180,120,0.1)
 Next
 lighting.SetDirectionalLight(17,0,0,1,80,120,255,0.1)
 For Local change:Int=0 Until 7
  Select change
   Case 1
    lighting.SetPointLight(80,8,8,25,0,255,0,0.4)
   Case 2
    lighting.SetLightMask(80,0)
   Case 3
    lighting.SetDirectionalLight(80,0,0,1,255,0,0,0.3)
   Case 4
    lighting.SetLightCount(128)
   Case 5
    For Local i:Int=0 Until 20
     lighting.SetPointLight(i,8,8,25,100+i*5,220-i*5,120,0.02)
    Next
   Case 6
    lighting.SetPointLight(2,8,8,25,20,40,80,0)
  End Select
  Local reference:TPixmap
  For Local mode:Int=0 To 1
   lighting.SetSpatialSelection(mode);lighting.ResetStats()
   SetRenderImage(output);SetVirtualResolution(16,16);SetViewport(0,0,16,16)
   SetClsColor(20,30,40,0.4);Cls;SetColor(255,255,255);SetAlpha(0.8)
   lighting.DrawImage(source,0,0)
   Local result:TPixmap=ReadRenderImage(output)
   If Not mode Then
    reference=result
   Else
    Local same:Int=True
    For Local y:Int=0 Until 16
     For Local x:Int=0 Until 16
      If result.ReadPixel(x,y)<>reference.ReadPixel(x,y) Then same=False
     Next
    Next
    Check(same,"spatial selection preserves pixels and slot order after edit "+change)
    Local stats:TMax2DLightingStats=lighting.CaptureStats()
    Check(stats.LightTests()<24 And stats.SpatialRejects()>100,"spatial selection prunes distant shuffled slots")
    If change=2 Or change=6 Then Check(stats.SelectionRebuilds()=0,"mask and colour/intensity changes reuse spatial hierarchy") Else Check(stats.SelectionRebuilds()=1,"geometry and count edits rebuild spatial hierarchy")
    lighting.ResetStats();lighting.DrawImage(source,0,0)
    Check(lighting.CaptureStats().SelectionRebuilds()=0,"warm selection reuses hierarchy")
    Local copied:TMax2DLightingStats=lighting.CaptureStats()
    lighting.ResetStats()
    Check(copied.SelectionNodeTests()>0 And copied.SpatialRejects()>0 And lighting.CaptureStats().SelectionNodeTests()=0,"selection diagnostics copy and reset independently")
   End If
  Next
 Next
 lighting.Release();SetRenderImage(Null);output.ReleaseFrames()
End Function

Function CheckSelectiveCasterShadows()
 Local lighting:TMax2DLighting=TMax2DLighting.Create(3)
 lighting.SetAmbient(255,255,255,0.1);lighting.SetLightBatching(True)
 For Local i:Int=0 Until 2
  lighting.SetPointLight(i,16+i*192,32,64,255,220,180,0.4)
  lighting.SetLightShadows(i,True,64,1 Shl i)
  lighting.SetLightShadowSoftness(i,2)
 Next
 lighting.SetDirectionalLight(2,-1,-1,1,180,200,255,0.2)
 lighting.SetLightShadows(2,True,64,4);lighting.SetDirectionalShadowBounds(2,0,0,256,64)
 Local wall:TMax2DLightOccluder=TMax2DLightOccluder.Create([24.0,20.0,28.0,20.0,28.0,44.0,24.0,44.0])
 lighting.SetOccluders([wall])
 Local pixels:TPixmap=CreatePixmap(256,64,PF_RGBA8888);pixels.ClearPixels($ffffffff)
 Local source:TImage=LoadImage(pixels,0),target:TRenderImage=CreateRenderImage(256,64)
 SetRenderImage(target);SetVirtualResolution(256,64);SetViewport(0,0,256,64)
 SetColor(255,255,255);SetAlpha(1);SetClsColor(0,0,0,0);Cls
 lighting.DrawImage(source,0,0)
 Local expected:Int[]=[2,3,2,1,0,0,0,1,2,1,1,1]
 For Local change:Int=0 Until expected.Length
  Select change
   Case 0
    wall.SetHeight(20)
   Case 1
    wall.SetPolygon([216.0,20.0,220.0,20.0,220.0,44.0,216.0,44.0])
   Case 2
    wall.SetCasterMask(2)
   Case 3
    wall.SetEnabled(False)
   Case 4
    wall.SetPolygon([1000.0,20.0,1004.0,20.0,1004.0,44.0,1000.0,44.0])
   Case 5
    wall.SetEnabled(True)
   Case 6
    wall.SetPolygon([24.0,20.0,28.0,20.0,28.0,44.0,24.0,44.0])
   Case 7
    wall.SetCasterMask(1)
   Case 8
    wall.SetCasterMask(4)
   Case 9
    wall.SetEnabled(False)
   Case 10
    wall.SetPolygon([-60.0,-60.0,-56.0,-60.0,-56.0,-36.0,-60.0,-36.0])
    wall.SetHeight(-1);wall.SetEnabled(True)
   Case 11
    wall.SetHeight(30)
  End Select
  lighting.ResetStats();Cls;lighting.DrawImage(source,0,0)
  Local work:TMax2DLightingStats=lighting.CaptureStats()
  Check(work.ShadowRebuilds()=expected[change],"selective caster rebuild count "+change+": "+work.ShadowRebuilds())
  Check(work.ShadowCacheHits()=3-expected[change],"unaffected caster masks remain cached "+change)
  Check(work.MapUploads()=expected[change],"only changed shadow tiles upload "+change)
  Local actual:TPixmap=ReadRenderImage(target)
  ' Explicit list replacement forces all masks to rebuild as a reference.
  lighting.SetOccluders([wall]);Cls;lighting.DrawImage(source,0,0)
  Local reference:TPixmap=ReadRenderImage(target),same:Int=True
  For Local y:Int=0 Until 64
   For Local x:Int=0 Until 256
    If actual.ReadPixel(x,y)<>reference.ReadPixel(x,y) Then same=False
   Next
  Next
  Check(same,"selective shadows equal full rebuild after caster edit "+change)
 Next
 lighting.Release();SetRenderImage(Null);target.ReleaseFrames()
End Function

Function CheckConcaveShadows()
 Local outline:Float[]=[16.0,16.0,48.0,16.0,48.0,24.0,24.0,24.0,24.0,48.0,16.0,48.0]
 Local concave:TMax2DLightOccluder=TMax2DLightOccluder.Create(outline)
 Local top:TMax2DLightOccluder=TMax2DLightOccluder.Create([16.0,16.0,48.0,16.0,48.0,24.0,16.0,24.0])
 Local leg:TMax2DLightOccluder=TMax2DLightOccluder.Create([16.0,24.0,24.0,24.0,24.0,48.0,16.0,48.0])
 Local pixels:TPixmap=CreatePixmap(64,64,PF_RGBA8888)
 pixels.ClearPixels($ffffffff)
 Local art:TImage=TImage.FromPixmap(pixels)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0.1);light.SetDirectionalLight(0,0,0,1);light.SetLightShadows(0,True,256)
 light.SetDirectionalShadowBounds(0,0,0,64,64)
 SetRenderImage(target);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
 SetClsColor(0,0,0,0);SetColor(255,255,255);SetAlpha(1)
 For Local winding:Int=0 To 2
  If winding=1 Then
   Local reversed:Float[12]
   For Local i:Int=0 Until 6
    reversed[i*2]=outline[(5-i)*2];reversed[i*2+1]=outline[(5-i)*2+1]
   Next
   concave.SetPolygon(reversed)
  End If
  If winding=2 Then
   Local mirrored:TMax2DLightOccluder=TMax2DLightOccluder.Create(outline)
   mirrored.SetTransformFrom(concave,-1,0,0,1,64,0);concave=mirrored
   mirrored=TMax2DLightOccluder.Create(outline)
   mirrored.SetTransformFrom(top,-1,0,0,1,64,0);top=mirrored
   mirrored=TMax2DLightOccluder.Create(outline)
   mirrored.SetTransformFrom(leg,-1,0,0,1,64,0);leg=mirrored
  End If
  For Local height:Int=-1 To 8
   If height>0 And height<8 Then Continue
   concave.SetHeight(height);top.SetHeight(height);leg.SetHeight(height)
   For Local mode:Int=0 Until 5
    Select mode
     Case 0;light.SetDirectionalLight(0,-1,0,1)
     Case 1;light.SetDirectionalLight(0,0,0,1)
     Case 2;light.SetPointLight(0,40,40,128);light.SetLightHeight(0,16)
     Case 3;light.SetPointLight(0,20,20,128);light.SetLightHeight(0,16)
     Case 4;light.SetPointLight(0,24,32,128);light.SetLightHeight(0,16)
    End Select
    For Local soft:Int=0 To 1
     light.SetLightShadowSoftness(0,soft*2)
     light.SetOccluders([top,leg]);Cls;light.DrawImage(art,0,0)
     Local expected:TPixmap=ReadRenderImage(target)
     light.SetOccluders([concave]);Cls;light.DrawImage(art,0,0)
     Local actual:TPixmap=ReadRenderImage(target),difference:Int
     For Local y:Int=2 Until 64 Step 4
      For Local x:Int=2 Until 64 Step 4
       difference=Max(difference,Abs(Red(actual.ReadPixel(x,y))-Red(expected.ReadPixel(x,y))))
      Next
     Next
     Check(difference<=3,"concave shadow matches convex union: winding="+winding+" height="+height+" mode="+mode+" soft="+soft+" difference="+difference)
    Next
   Next
  Next
 Next
 light.ResetStats();ResetMax2DStats();Cls;light.DrawImage(art,0,0)
 Check(light.CaptureStats().ShadowRebuilds()=0 And CaptureMax2DStats().textureCreations=0,"warm concave shadows reuse masks and textures")
 SetRenderImage(Null);light.Release();target.ReleaseFrames();art.ReleaseFrames()
End Function
