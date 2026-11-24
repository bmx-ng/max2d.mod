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
Function Near(value:Int,expected:Int,message:String)
 Check(Abs(value-expected)<=3,message+": "+value+" expected "+expected)
End Function
Function Draw:TPixmap(light:TMax2DLighting,material:TMax2DLightingMaterial,art:TImage,target:TRenderImage,batch:Int,readPixels:Int=True)
 SetRenderImage(target);SetVirtualResolution(16,16);SetViewport(0,0,16,16)
 SetColor(255,255,255);SetAlpha(1);SetClsColor(0,0,0,0);Cls
 light.SetLightBatching(batch);light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
 If readPixels Then Return ReadRenderImage(target)
 Return Null
End Function
Try
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 Check(material.GetEmissionIntensity()=0,"emission disabled by default")
 material.SetEmission(255,128,0,0.5)
 Local revision:Long=material.Revision()
 material.SetEmission(255,128,0,0.5)
 Check(material.Revision()=revision,"identical emission preserves revision")
 Check(material.GetEmissionRed()=255 And material.GetEmissionGreen()=128 And material.GetEmissionBlue()=0 And material.GetEmissionIntensity()=0.5,"emission getters")
 For Local variant:Int=0 Until 4
  Local rejected:Int
  Try
   Select variant
    Case 0;material.SetEmission(-1,0,0)
    Case 1;material.SetEmission(0,256,0)
    Case 2;material.SetEmission(0,0,256)
    Case 3;material.SetEmission(0,0,0,-1)
   End Select
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And material.Revision()=revision,"invalid emission preserves material")
 Next
 Graphics(16,16)
 Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 pixels.ClearPixels($ffc89664)
 For Local y:Int=0 Until 16
  pixels.WritePixel(14,y,$80c89664);pixels.WritePixel(15,y,$00c89664)
 Next
 Local art:TImage=LoadImage(pixels,0)
 Local target:TRenderImage=CreateRenderImage(16,16,0)
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetAmbient(255,255,255,0)
 light.SetDirectionalLight(0,0,0,1,255,255,255,0.1)
 material.SetReceiverMask(0)
 pixels=Draw(light,material,art,target,False)
 Near(pixels.ReadPixel(4,4) Shr 16 & 255,100,"emission survives darkness and receiver mask")
 Near(pixels.ReadPixel(4,4) Shr 8 & 255,38,"emission colour multiplies source")
 Near(pixels.ReadPixel(4,4) & 255,0,"emission blue is zero")
 Near(pixels.ReadPixel(14,4) Shr 16 & 255,100,"emission retains straight colour at partial coverage")
 Near(pixels.ReadPixel(14,4) Shr 24 & 255,128,"emission preserves alpha")
 Check(pixels.ReadPixel(15,4)=0,"emission does not reveal transparent artwork")
 material.SetReceiverMask(-1)
 light.SetAmbient(255,255,255,0.1)
 Local reference:TPixmap=Draw(light,material,art,target,False)
 Near(reference.ReadPixel(4,4) Shr 16 & 255,140,"ambient emission and direct light add")
 light.ResetStats();pixels=Draw(light,material,art,target,True)
 Check(light.CaptureStats().CombinedAmbientPasses()=1,"native combined pass includes emission")
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 16
   For Local shift:Int=0 To 24 Step 8
    Near(pixels.ReadPixel(x,y) Shr shift & 255,reference.ReadPixel(x,y) Shr shift & 255,"native emission parity")
   Next
  Next
 Next
 ResetMax2DStats();Draw(light,material,art,target,True)
 Check(CaptureMax2DStats().textureCreations=0,"warm emission creates no textures")
 material.SetUnlit(True);pixels=Draw(light,material,art,target,True)
 Near(pixels.ReadPixel(4,4) Shr 16 & 255,200,"unlit bypasses emission and illumination")
 material.SetUnlit(False);material.SetEmission(255,255,255,0)
 pixels=Draw(light,material,art,target,True)
 Near(pixels.ReadPixel(4,4) Shr 16 & 255,40,"zero emission restores original lighting")
 If Max2DSupportsRenderImage(16,16,0,PF_RGBA16F) Then
  Local hdr:TRenderImage=CreateRenderImage(16,16,0,PF_RGBA16F)
  material.SetEmission(255,255,255,2)
  Local expected:Float
  For Local batch:Int=0 To 1
   Draw(light,material,art,hdr,batch,False)
   Local data:TTextureData=ReadRenderTextureData(hdr)
   Local values:Float Ptr=Float Ptr(data.Level().Data())
   Local value:Float=values[(4*16+4)*4]
   Check(value>1.5,"HDR retains overbright emission")
   If batch Then Check(Abs(value-expected)<0.01,"HDR native/fallback emission parity") Else expected=value
  Next
  SetRenderImage(target);hdr.ReleaseFrames()
 End If
 material.SetEmission(255,255,255,0)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local environment:TSceneLighting=TSceneLighting.Create(layer)
 environment.SetAmbient(255,255,255,0)
 Local group:TCompositeNode=TCompositeNode.Create()
 group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
 group.AddChild(TLitSpriteNode.Create(art,environment,material))
 environment.Prepare();Cls;scene.Render()
 environment.Prepare();Cls;scene.Render()
 Check(scene.CaptureStats().Captures()=0,"unchanged material preserves cache")
 material.SetEmission(255,0,0,0.5)
 environment.Prepare();Cls;scene.Render()
 Check(scene.CaptureStats().Captures()=1,"emission edit invalidates receiver cache")
 pixels=ReadRenderImage(target)
 Near(pixels.ReadPixel(4,4) Shr 16 & 255,100,"cached receiver shows emission")
 material.SetEmission(255,0,0,0.5)
 environment.Prepare();Cls;scene.Render()
 Check(scene.CaptureStats().Captures()=0,"identical emission preserves cached receiver")
 scene.Destroy();environment.ReleaseResources();light.Release()
 SetRenderImage(Null);target.ReleaseFrames();art.ReleaseFrames();EndGraphics()
 Print "PASS: "+checks+" emission checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
