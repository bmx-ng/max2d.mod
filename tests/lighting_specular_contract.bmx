SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.Lighting
Import BRL.StandardIO

Global checks:Int,mode:Int,independentDraws:Int,packedDraws:Int
Global expectedNormal:TImage,expectedSpecular:TImage
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Type TProbeRenderer Extends TMax2DLightingRenderer
 Field native:TMax2DLightingRenderer
 Field limits:TMax2DLightingCapabilities=TMax2DLightingCapabilities.Create(1,1,True,True,True,True,True,True,True,True,True,True,True,True)
 Method Capabilities:TMax2DLightingCapabilities() Override;Return limits;End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  If draw.specularMap Then
   Check(draw.specularMap=expectedSpecular And draw.normalMap=expectedNormal,"original maps reach independent provider")
   Check(Not draw.specularFromNormalAlpha,"separate map overrides normal alpha")
   If mode=1 Or (mode=3 And draw.lights[0].red<0.5) Then Return False
   Return True
  End If
  Return native.Supports(canvas,draw)
 End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  If draw.specularMap Then
   independentDraws:+1
   Check(draw.specularMap=expectedSpecular And draw.normalMap=expectedNormal,"original maps survive group negotiation")
   If mode=2 Then Throw "intentional provider draw failure"
   ' Contract probe: no sampling, so the locked gloss detects accidental CPU packing.
  Else
   packedDraws:+1
   Check(draw.normalMap<>Null And draw.normalMap<>expectedNormal And draw.specularFromNormalAlpha,"fallback receives packed normals")
   native.Draw(canvas,draw)
  End If
 End Method
 Method Release() Override;native.Release();End Method
End Type
Type TProbeBackend Extends TMax2DLightingBackend
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Override
  Local renderer:TProbeRenderer=New TProbeRenderer
  renderer.native=CreateNativeMax2DLightingRenderer(context,1)
  Return renderer
 End Method
End Type
Function Solid:TImage(colour:Int)
 Local p:TPixmap=CreatePixmap(16,16,PF_RGBA8888);p.ClearPixels(colour)
 Return LoadImage(p,0)
End Function
Function Render(light:TMax2DLighting,art:TImage,material:TMax2DLightingMaterial,mesh:TMesh2D,geometry:Int)
 If geometry Then light.DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material) Else light.DrawImage(art,0,0,0,-1,1,0,0,1,0,0,material)
End Function
Try
 Check(Not TMax2DLightingCapabilities.Create(1,1).MappedSpecular(),"legacy capability defaults false")
 Local failed:Int
 Try
  TMax2DLightingCapabilities.Create(1,1,False,False,False,False,False,False,False,False,False,False,False,True)
 Catch error:Object
  failed=True
 End Try
 Check(failed,"mapped specular requires specular support")
 Graphics(32,32)
 RegisterMax2DLightingBackend(New TProbeBackend)
 Local target:TRenderImage=CreateRenderImage(32,32,0)
 SetRenderImage(target);SetVirtualResolution(32,32);SetViewport(0,0,32,32)
 Local art:TImage=Solid($ff000000),normal:TImage=Solid($008080ff),gloss:TImage=Solid($ff800000)
 expectedSpecular=gloss
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetSpecular(0.5,16);material.SetSpecularFromNormalAlpha(True);material.SetSpecularMap(gloss)
 Local light:TMax2DLighting=TMax2DLighting.Create(3)
 light.SetLightBatching(True)
 light.SetAmbient(255,255,255,0)
 For Local i:Int=0 Until 3
  light.SetDirectionalLight(i,0,0,1,255,255,255,0.2)
 Next
 Local mesh:TMesh2D=TMesh2D.Create([0.0,0.0,16.0,0.0,16.0,16.0,0.0,16.0],[0,1,2,0,2,3],[0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0])
 For Local normals:Int=0 To 1
  expectedNormal=Null
  If normals Then expectedNormal=normal
  material.SetNormalMap(expectedNormal)
  For Local geometry:Int=0 To 2
   mesh.xy[4]=16
   If geometry=2 Then mesh.xy[4]=14
   mode=0;independentDraws=0;packedDraws=0;material.ReleaseResources()
   LockImage(gloss,0,True,False)
   Try
    Render(light,art,material,mesh,geometry)
    Check(independentDraws=3 And packedDraws=0,"all groups bypass packing")
   Finally
    UnlockImage(gloss)
   End Try
   mode=1;independentDraws=0;packedDraws=0;Cls
   Render(light,art,material,mesh,geometry)
   Check(independentDraws=0 And packedDraws=3,"rejection retries all groups packed")
   Check((ReadRenderImage(target).ReadPixel(8,8) Shr 16 & 255)>20,"packed fallback produces specular light")
   mode=3;independentDraws=0;packedDraws=0
   light.SetDirectionalLight(1,0,0,1,64,255,255,0.2)
   Render(light,art,material,mesh,geometry)
   Check(independentDraws=2 And packedDraws=1,"mixed groups restore original representation")
   light.SetDirectionalLight(1,0,0,1,255,255,255,0.2)
   mode=2;failed=False;independentDraws=0;packedDraws=0;SetBlend(SOLIDBLEND)
   Try
    Render(light,art,material,mesh,geometry)
   Catch error:Object
    failed=True
   End Try
   Check(failed And independentDraws=1 And packedDraws=0,"draw failure never retries partial work")
   Check(GetBlend()=SOLIDBLEND,"draw failure restores blend")
   mode=0;independentDraws=0
   Render(light,art,material,mesh,geometry)
   Check(independentDraws=3,"drawing recovers after provider failure")
  Next
 Next
 Local draw:TMax2DLightingDraw=New TMax2DLightingDraw
 draw.specularMap=gloss;draw.specularFrame=4;draw.ClearImages()
 Check(Not draw.specularMap And draw.specularFrame=0,"clear releases borrowed specular reference")
 light.Release();material.ReleaseResources();SetRenderImage(Null);target.ReleaseFrames()
 art.ReleaseFrames();normal.ReleaseFrames();gloss.ReleaseFrames();expectedNormal=Null;expectedSpecular=Null
 EndGraphics
 Print "lighting_specular_contract: "+checks+" checks passed"
Catch error:Object
 Print "FAIL: "+error.ToString()
 End
End Try
