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
Function Same:Int(a:TPixmap,b:TPixmap)
 For Local y:Int=0 Until a.height
  For Local x:Int=0 Until a.width
   For Local shift:Int=0 To 24 Step 8
    If Abs((a.ReadPixel(x,y) Shr shift & 255)-(b.ReadPixel(x,y) Shr shift & 255))>2 Then Return False
   Next
  Next
 Next
 Return True
End Function
Type TImageOnlyRenderer Extends TMax2DLightingRenderer
 Field limits:TMax2DLightingCapabilities=TMax2DLightingCapabilities.Create(1,16,True,True,True,True,True,True,True)
 Method Capabilities:TMax2DLightingCapabilities() Override;Return limits;End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  If draw.mesh Then Throw "mesh sent to legacy image-only provider"
  Return False
 End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  Throw "declined provider must not draw"
 End Method
End Type
Type TImageOnlyBackend Extends TMax2DLightingBackend
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Override
  Return New TImageOnlyRenderer
 End Method
End Type
Try
 Graphics(64,64)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
 SetClsColor(0,0,0,0)
 Local pixels:TPixmap=CreatePixmap(24,24,PF_RGBA8888)
 pixels.ClearPixels($ff807050)
 Local art:TImage=LoadImage(pixels,0)
 pixels.ClearPixels($ffb080ed)
 Local normals:TImage=LoadImage(pixels,0)
 Local mesh:TMesh2D=TMesh2D.Create([0.0,0.0,24.0,0.0,24.0,24.0,0.0,24.0],[0,1,2,0,2,3],[0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0])
 Local lighting:TMax2DLighting=TMax2DLighting.Create(2)
 lighting.SetAmbient(255,255,255,0.15)
 lighting.SetPointLight(0,28,16,60,255,150,90,0.7,1)
 lighting.SetLightHeight(0,16)
 lighting.SetDirectionalLight(1,0.3,-0.2,1,90,150,255,0.25)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 Local reference:TPixmap,actual:TPixmap
 For Local variant:Int=0 Until 8
  SetRotation(0);SetScale(1,1)
  SetImageHandle(art,0,0);SetColor(255,255,255);SetAlpha(1)
  If variant>=1 Then material.SetNormalMap(normals);material.SetSpecular(0.3,16)
  If variant>=2 Then material.SetEmission(70,120,240,0.15)
  If variant=3 Then SetColor(180,220,150);SetAlpha(0.6)
  If variant=5 Then
   lighting.SetLightTexture(0,TMax2DLightTexture.Create(normals))
   lighting.SetOccluders([TMax2DLightOccluder.Create([24.0,20.0,28.0,20.0,28.0,36.0,24.0,36.0])]);lighting.SetLightShadows(0,True,256)
  End If
  If variant=6 Then art.SetTrim(0,4,4,16,16)
  If variant=7 Then material.SetUnlit(True)
  If variant=4 Then SetRotation(15);SetScale(1.1,0.8)
  lighting.SetLightBatching(False)
  Cls;lighting.DrawImage(art,16,16,0,-1,1,0,0,1,0,0,material);reference=ReadRenderImage(target)
  SetImageHandle(art,7,9);lighting.SetLightBatching(True);lighting.ResetStats()
  Cls;lighting.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material);actual=ReadRenderImage(target)
  Check(Same(reference,actual),"lit mesh/sprite parity "+variant)
  If variant=7 Then
   Check(lighting.GetLightBatching() And lighting.CaptureStats().GroupedPasses()=0,"unlit mesh bypasses lighting")
  Else
   Check(lighting.GetLightBatching() And lighting.CaptureStats().GroupedPasses()=1,"affine mesh groups ambient and lights once")
  End If
 Next
 lighting.SetLightTexture(0,Null);lighting.SetLightShadows(0,False);material.SetUnlit(False)
 art.SetTrim(0,0,0,24,24)
 SetRotation(0);SetScale(1,1);SetColor(255,255,255);SetAlpha(1)
 material.SetNormalMap(Null);material.SetSpecular(0);material.SetEmission(0,0,0,0)
 ' A uniform texture allows a geometry-independent reference for world-space illumination.
 Local large:TPixmap=CreatePixmap(64,64,PF_RGBA8888);large.ClearPixels($ff807050)
 Local backdrop:TImage=LoadImage(large,0)
 lighting.SetLightBatching(False)
 Cls;lighting.DrawImage(backdrop,0,0);reference=ReadRenderImage(target)
 mesh.xy[2]=32;mesh.xy[4]=20;mesh.xy[5]=30
 Cls;lighting.DrawMesh(mesh,art,16,16);actual=ReadRenderImage(target)
 For Local y:Int=20 To 36 Step 8
  For Local x:Int=20 To 32 Step 6
   For Local shift:Int=0 To 24 Step 8
    Check(Abs((actual.ReadPixel(x,y) Shr shift & 255)-(reference.ReadPixel(x,y) Shr shift & 255))<=2,"deformed triangle keeps world light placement")
   Next
  Next
 Next
 ' The drawing handle and lighting transform are independent of the camera.
 SetHandle(3,5)
 Cls;lighting.DrawMesh(mesh,art,19,21,0,-1,0.8,0.2,-0.1,1.2,4,7);reference=ReadRenderImage(target)
 SetHandle(0,0)
 Cls;lighting.DrawMesh(mesh,art,16,16,0,-1,0.8,0.2,-0.1,1.2,4,7);actual=ReadRenderImage(target)
 Check(Same(reference,actual),"drawing handle included before affine lighting transform")
 Cls;lighting.DrawImage(backdrop,0,0);reference=ReadRenderImage(target)
 Local rejected:Int
 mesh.uv[6]=1;mesh.uv[7]=1
 Cls
 Try
  lighting.DrawMesh(mesh,art,16,16)
 Catch error:Object
  rejected=True
 End Try
 actual=ReadRenderImage(target)
 Check(rejected And actual.ReadPixel(20,20)=0,"later singular triangle rejected before any submission")
 mesh.uv[6]=0;mesh.uv[7]=1
 lighting.SetLightBatching(True)
 rejected=False
 Try
  lighting.DrawMesh(mesh,target)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And lighting.GetLightBatching(),"feedback failure restores mesh mode and batching")
 Cls;lighting.DrawImage(backdrop,0,0);actual=ReadRenderImage(target)
 Check(Same(reference,actual),"sprite drawing recovers after failed mesh submission")
 ' Cross the eight/sixteen-light boundaries with a deformed normal-mapped receiver.
 Local native:TMax2DLightingRenderer=CreateNativeMax2DLightingRenderer(TMax2DGraphics.Current().context)
 Check(native.Capabilities().MeshGeometry(),"native provider advertises mesh geometry")
 Local capacity:Int=native.Capabilities().MaximumLights();native.Release()
 Local grouped:TMax2DLighting=TMax2DLighting.Create(17)
 grouped.SetAmbient(255,255,255,0.1)
 material.SetNormalMap(normals);material.SetSpecular(0.2,16);material.SetEmission(90,60,120,0.1)
 For Local count:Int=EachIn [1,8,9,16,17]
  For Local i:Int=0 Until 17
   Local intensity:Float=0
   If i<count Then intensity=0.035
   grouped.SetPointLight(i,20+i,12,100,255,180,140,intensity,1);grouped.SetLightHeight(i,20)
  Next
  For Local limit:Int=EachIn [8,16]
   grouped.SetLightBatchLimit(limit)
   grouped.SetLightBatching(False);Cls;grouped.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material);reference=ReadRenderImage(target)
   grouped.SetLightBatching(True);grouped.ResetStats()
   Cls;grouped.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material);actual=ReadRenderImage(target)
   Local difference:Int,alphaSame:Int=True
   For Local y:Int=0 Until 64
    For Local x:Int=0 Until 64
     Local a:UInt=actual.ReadPixel(x,y),b:UInt=reference.ReadPixel(x,y)
     If (a Shr 24)<>(b Shr 24) Then alphaSame=False
     For Local shift:Int=0 Until 24 Step 8
      difference=Max(difference,Abs(Int(a Shr shift & 255)-Int(b Shr shift & 255)))
     Next
    Next
   Next
   Check(difference<=count/2+1 And alphaSame,"grouped deformed mesh parity count "+count+" limit "+limit+" error "+difference)
   Check(grouped.CaptureStats().GroupedPasses()=((count+Min(capacity,limit)-1)/Min(capacity,limit)),"mesh pass count follows light groups")
   Check(grouped.CaptureStats().CombinedAmbientPasses()=1,"ambient combined once for the deformed mesh")
  Next
 Next
 ResetMax2DStats();Cls;grouped.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material);FlushMax2D()
 Check(CaptureMax2DStats().textureCreations=0,"warm grouped mesh creates no textures")
 grouped.Release();material.SetNormalMap(Null);material.SetSpecular(0);material.SetEmission(0,0,0,0)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local environment:TSceneLighting=TSceneLighting.Create(layer)
 environment.SetAmbient(255,255,255,0.5)
 Local group:TCompositeNode=TCompositeNode.Create();group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
 Local node:TLitMeshNode=TLitMeshNode.Create(mesh,art,environment,material)
 node.SetPosition(16,16);group.AddChild(node)
 environment.Prepare();Cls;scene.Render();reference=ReadRenderImage(target)
 environment.Prepare();Cls;scene.Render()
 Check(scene.CaptureStats().Captures()=0,"lit mesh cached after warm draw")
 material.SetEmission(255,60,0,0.3);environment.Prepare();Cls;scene.Render();actual=ReadRenderImage(target)
 Check(scene.CaptureStats().Captures()=1 And Not Same(reference,actual),"material edit invalidates lit mesh cache")
 mesh.xy[0]=4;node.InvalidateContent();environment.Prepare();Cls;scene.Render()
 Check(scene.CaptureStats().Captures()=1,"geometry edit invalidates lit mesh cache")
 ResetMax2DStats();environment.Prepare();Cls;scene.Render();FlushMax2D()
 Check(CaptureMax2DStats().textureCreations=0 And scene.CaptureStats().Captures()=0,"warm lit mesh cache creates no textures")
 Local bounds:TSceneRect=New TSceneRect
 node.GetSelfBounds(bounds);Check(bounds.x=0 And bounds.width=32 And bounds.height=30,"lit mesh bounds ignore image handles")
 node.SetImage(Null);environment.Prepare();Cls;scene.Render();actual=ReadRenderImage(target)
 Check(actual.ReadPixel(20,20)=0,"null artwork clears cached receiver")
 RegisterMax2DLightingBackend(New TImageOnlyBackend)
 Local fallback:TMax2DLighting=TMax2DLighting.Create(1)
 fallback.SetAmbient(255,255,255,0.2);fallback.SetPointLight(0,25,20,80,255,180,100,0.3,1)
 fallback.SetLightBatching(False);Cls;fallback.DrawMesh(mesh,art,16,16);reference=ReadRenderImage(target)
 fallback.SetLightBatching(True);fallback.ResetStats();Cls;fallback.DrawMesh(mesh,art,16,16);actual=ReadRenderImage(target)
 Check(Same(reference,actual) And fallback.CaptureStats().GroupedPasses()=0,"legacy provider falls back without receiving mesh requests")
 fallback.Release()
 Local request:TMax2DLightingDraw=New TMax2DLightingDraw
 request.mesh=mesh;request.ClearImages();Check(Not request.mesh,"borrowed mesh cleared after submission")
 scene.Destroy();environment.ReleaseResources();lighting.Release()
 SetRenderImage(Null);target.ReleaseFrames();art.ReleaseFrames();normals.ReleaseFrames();backdrop.ReleaseFrames();EndGraphics()
 Print "PASS: "+checks+" lighting mesh checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndWithCode(1)
End Try
