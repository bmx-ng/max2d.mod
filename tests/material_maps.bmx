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
 checks:+1
End Function
Function Near(value:Int,wanted:Int,message:String)
 Check(Abs(value-wanted)<=3,message+": "+value+" expected "+wanted)
End Function
Function Solid:TPixmap(width:Int,height:Int,colour:Int)
 Local p:TPixmap=CreatePixmap(width,height,PF_RGBA8888)
 For Local y:Int=0 Until height
  For Local x:Int=0 Until width
   p.WritePixel(x,y,colour)
  Next
 Next
 Return p
End Function
Try
 Graphics(32,32)
 Local target:TRenderImage=CreateRenderImage(32,32,0)
 SetRenderImage(target);SetVirtualResolution(32,32);SetViewport(0,0,32,32)
 SetClsColor(0,0,0,0);SetColor(255,255,255);SetAlpha(1)
 Local art:TImage=LoadImage(Solid(16,16,$80ffffff),0)
 Local black:TImage=LoadImage(Solid(16,16,$80000000),0)
 Local pix:TPixmap=Solid(16,16,$ff000000)
 For Local y:Int=0 Until 16
  For Local x:Int=8 Until 16
   pix.WritePixel(x,y,$80ff0000)
  Next
 Next
 Local emission:TImage=LoadImage(pix,0)
 Local gloss:TImage=LoadImage(pix,0)
 Local normals:TImage=LoadImage(Solid(16,16,$008080ff),0)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 Check(Not material.GetEmissionMap() And Not material.GetSpecularMap(),"maps disabled by default")
 material.SetEmission(255,255,255,1);material.SetEmissionMap(emission)
 Local revision:Long=material.Revision()
 material.SetEmissionMap(emission);Check(material.Revision()=revision,"identical emission map preserves revision")
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0)
 light.SetDirectionalLight(0,0,0,1,255,255,255,0)
 Local mesh:TMesh2D=TMesh2D.Create([0.0,0.0,16.0,0.0,16.0,16.0,0.0,16.0],[0,1,2,0,2,3],[0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0])
 ' Unselected direct-light maps must not be read, packed or validated by drawing.
 ' Holding the gloss lock makes any accidental packing fail.
 Local deferred:TMax2DLighting=TMax2DLighting.Create(1)
 Local deferredMaterial:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 deferredMaterial.SetSpecular(0.5,16);deferredMaterial.SetSpecularMap(gloss)
 deferred.SetAmbient(255,255,255,0.25)
 For Local batch:Int=0 To 1
  deferred.SetLightBatching(batch)
  For Local geometry:Int=0 To 2
   mesh.xy[4]=16
   If geometry=2 Then mesh.xy[4]=14
   deferredMaterial.ReleaseResources()
   Local locked:TPixmap=LockImage(gloss,0,True,False)
   Try
    For Local excluded:Int=0 To 3
     deferred.SetLightCount(1);deferredMaterial.SetReceiverMask(-1)
     deferred.SetDirectionalLight(0,0,0,1,255,255,255,1)
     Select excluded
      Case 0
       deferred.SetLightCount(0)
      Case 1
       deferredMaterial.SetReceiverMask(0)
      Case 2
       deferred.SetDirectionalLight(0,0,0,1,255,255,255,0)
      Case 3
       deferred.SetPointLight(0,1000,1000,10,255,255,255,1)
     End Select
     deferred.ResetStats();Cls
     If geometry Then deferred.DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,deferredMaterial) Else deferred.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,deferredMaterial)
     Near(ReadRenderImage(target).ReadPixel(4,8) Shr 16 & 255,64,"unselected specular map preserves ambient")
     Check(deferred.CaptureStats().LightPasses()=0,"unselected material submits no direct light")
    Next
    deferred.SetDirectionalLight(0,0,0,1,255,255,255,1)
    Local failed:Int
    SetBlend(SOLIDBLEND)
    Try
     If geometry Then deferred.DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,deferredMaterial) Else deferred.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,deferredMaterial)
    Catch error:Object
     failed=True
    End Try
    Check(failed And GetBlend()=SOLIDBLEND,"selected locked map is rejected and blend restored")
   Finally
    UnlockImage(gloss)
   End Try
   Cls
   If geometry Then deferred.DrawMesh(mesh,black,0,0,0,-1,1,0,0,1,0,0,deferredMaterial) Else deferred.DrawImage(black,0,0,0,-1,1,0,0,1,0,0,deferredMaterial)
   Near(ReadRenderImage(target).ReadPixel(12,8) Shr 16 & 255,128,"first selected draw resolves gloss and recovers")
  Next
 Next
 mesh.xy[4]=16;SetBlend(ALPHABLEND)
 deferred.Release();deferredMaterial.ReleaseResources()
 For Local batch:Int=0 To 1
  light.SetLightBatching(batch)
  For Local geometry:Int=0 To 1
   Cls
   If geometry Then light.DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material) Else light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
   Local actual:TPixmap=ReadRenderImage(target)
   Near(actual.ReadPixel(4,8) Shr 16 & 255,0,"dark emission area stays dark")
   Near(actual.ReadPixel(12,8) Shr 16 & 255,128,"emission RGB and alpha modulate source")
   Near(actual.ReadPixel(12,8) & 65535,0,"emission map preserves colour")
   Near(actual.ReadPixel(12,8) Shr 24 & 255,128,"emission map does not change coverage")
  Next
 Next
 ' An atlas subregion and trimmed logical frame keep receiver-relative UVs.
 Local atlas:TImage=LoadImage(Solid(16,8,$ffff0000),0)
 Local view:TImage=TImage.View(atlas,8,0,8,8)
 view.SetTrim(0,2,0,4,8);material.SetEmissionMap(view)
 Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Local sampled:TPixmap=ReadRenderImage(target)
 Near(sampled.ReadPixel(1,8) Shr 16 & 255,0,"trimmed emission margin stays dark")
 Near(sampled.ReadPixel(8,8) Shr 16 & 255,255,"different-size atlas emission covers logical receiver")
 Local feedbackRejected:Int
 material.SetEmissionMap(target)
 Try
  light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Catch error:Object
  feedbackRejected=True
 End Try
 Check(feedbackRejected,"emission cannot sample selected target")
 material.SetEmissionMap(emission);Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(ReadRenderImage(target).ReadPixel(12,8) Shr 16 & 255,128,"emission drawing recovers after feedback rejection")
 view.ReleaseFrames();atlas.ReleaseFrames()
 material.SetEmissionMap(Null);Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 Near(ReadRenderImage(target).ReadPixel(4,8) Shr 16 & 255,255,"null map restores uniform emission")
 material.SetEmission(255,255,255,0);material.SetSpecular(0.5,16);material.SetSpecularMap(gloss)
 revision=material.Revision();material.SetSpecularMap(gloss)
 Check(material.Revision()=revision And material.GetSpecularMap()=gloss,"identical specular map preserves configuration")
 light.SetDirectionalLight(0,0,0,1,255,255,255,1)
 For Local batch:Int=0 To 1
  light.SetLightBatching(batch)
  For Local normal:Int=0 To 1
   If normal Then material.SetNormalMap(normals);material.SetSpecularFromNormalAlpha(True)
   For Local geometry:Int=0 To 1
    Cls
    If geometry Then light.DrawMesh(mesh,black,0,0,0,-1,1,0,0,1,0,0,material) Else light.DrawImage(black,0,0,0,-1,1,0,0,1,0,0,material)
    Local actual:TPixmap=ReadRenderImage(target)
    Near(actual.ReadPixel(4,8) Shr 16 & 255,0,"separate specular map matte area")
    Near(actual.ReadPixel(12,8) Shr 16 & 255,128,"specular map overrides normal alpha and uses red")
    Near(actual.ReadPixel(12,8) Shr 24 & 255,128,"specular map keeps source coverage")
   Next
  Next
  material.SetNormalMap(Null)
 Next
 ' Both maps together combine emission/ambient when the group needs no light maps.
 material.SetEmission(255,255,255,0.25);material.SetEmissionMap(emission)
 light.SetLightBatching(True);light.ResetStats();Cls
 light.DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material);ReadRenderImage(target)
 Check(light.CaptureStats().GroupedPasses()=1 And light.CaptureStats().CombinedAmbientPasses()=1,"mapped emission combines with grouped lights")
 ResetMax2DStats();Cls;light.DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material);FlushMax2D()
 Check(CaptureMax2DStats().textureCreations=0,"warm material maps allocate no textures")
 Local rejected:Int,wrong:TImage=LoadImage(Solid(8,8,$ff8080ff),0)
 revision=material.Revision()
 Try
  material.SetNormalMap(wrong)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And Not material.GetNormalMap() And material.Revision()=revision,"invalid packing dimensions preserve configuration")
 rejected=False
 Try
  material.SetSpecularMap(gloss,1)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And material.GetSpecularFrame()=0,"invalid map frame preserves state")
 pix=Solid(16,16,$ff800000);gloss.ReplacePixels(pix)
 Check(material.Revision()>revision,"specular pixel edits advance revision")
 material.SetEmission(255,255,255,0);Cls;light.DrawImage(black,0,0,0,-1,1,0,0,1,0,0,material)
 Near(ReadRenderImage(target).ReadPixel(12,8) Shr 16 & 255,64,"specular edit refreshes retained packed image")
 material.ReleaseResources();Cls;light.DrawImage(black,0,0,0,-1,1,0,0,1,0,0,material)
 Near(ReadRenderImage(target).ReadPixel(12,8) Shr 16 & 255,64,"released map storage recreates with preserved settings")
 If Max2DSupportsRenderImage(16,16,0,PF_RGBA16F) Then
  Local hdr:TRenderImage=CreateRenderImage(16,16,0,PF_RGBA16F)
  SetRenderImage(hdr);SetVirtualResolution(16,16);SetViewport(0,0,16,16)
  material.SetEmission(255,255,255,8);material.SetSpecular(0)
  light.SetDirectionalLight(0,0,0,1,255,255,255,0)
  For Local batch:Int=0 To 1
   light.SetLightBatching(batch);Cls;light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
   Local data:TTextureData=ReadRenderTextureData(hdr),values:Float Ptr=Float Ptr(data.Level().Data())
   Check(values[(8*16+12)*4]>1.9,"mapped emission retains HDR range")
  Next
  SetRenderImage(target);SetVirtualResolution(32,32);SetViewport(0,0,32,32);hdr.ReleaseFrames()
 End If
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local environment:TSceneLighting=TSceneLighting.Create(layer)
 environment.SetAmbient(255,255,255,0);environment.SetLightBatching(True)
 Local group:TCompositeNode=TCompositeNode.Create();group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
 material.SetEmission(255,255,255,1);material.SetSpecular(0)
 Local node:TLitMeshNode=TLitMeshNode.Create(mesh,art,environment,material);group.AddChild(node)
 environment.Prepare();Cls;scene.Render()
 environment.Prepare();Cls;scene.Render();Check(scene.CaptureStats().Captures()=0,"material maps cache after warm render")
 emission.ReplacePixels(Solid(16,16,$ff00ff00))
 environment.Prepare();Cls;scene.Render()
 Check(scene.CaptureStats().Captures()=1,"emission pixel edit invalidates scene cache")
 Near(ReadRenderImage(target).ReadPixel(4,8) Shr 8 & 255,255,"scene uses edited emission pixels")
 material.InvalidateMaps();environment.Prepare();Cls;scene.Render()
 Check(scene.CaptureStats().Captures()=1,"explicit map invalidation refreshes cache")
 scene.Destroy();environment.ReleaseResources();material.ReleaseResources();light.Release()
 SetRenderImage(Null);target.ReleaseFrames();art.ReleaseFrames();black.ReleaseFrames();emission.ReleaseFrames();gloss.ReleaseFrames();normals.ReleaseFrames();wrong.ReleaseFrames();EndGraphics()
 Print "PASS: "+checks+" material map checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndWithCode(1)
End Try
