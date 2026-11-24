SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.Lighting
Import BRL.StandardIO

Global checks:Int,allowAffine:Int,allowDeformed:Int,declineGroups:Int,rejectLast:Int,deformedDraws:Int,rejectAfterDraw:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Function Solid:TImage(colour:Int)
 Local pix:TPixmap=CreatePixmap(24,24,PF_RGBA8888);pix.ClearPixels(colour)
 Return LoadImage(pix,0)
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
Type TMeshProvider Extends TMax2DLightingRenderer
 Field native:TMax2DLightingRenderer,limits:TMax2DLightingCapabilities
 Method Capabilities:TMax2DLightingCapabilities() Override;Return limits;End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  If draw.mesh And Not limits.AffineMeshGeometry() Then
   If draw.mesh.indices.Length<>3 Then Throw "legacy mesh provider received multiple triangles"
  End If
  If draw.deformed And rejectAfterDraw And deformedDraws>0 Then Return False
  If rejectLast Then
   For Local i:Int=0 Until draw.count
    If draw.lights[i].x>=36 Then Return False
   Next
  End If
  If declineGroups Then Return False
  Return native.Supports(canvas,draw)
 End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  If draw.deformed Then deformedDraws:+1
  native.Draw(canvas,draw)
 End Method
 Method MapUploads:Long() Override;Return native.MapUploads();End Method
 Method MapCacheHits:Long() Override;Return native.MapCacheHits();End Method
 Method MapStorageBytes:Long() Override;Return native.MapStorageBytes();End Method
 Method Release() Override;native.Release();End Method
End Type
Type TMeshBackend Extends TMax2DLightingBackend
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Override
  Local result:TMeshProvider=New TMeshProvider
  result.native=CreateNativeMax2DLightingRenderer(context)
  result.limits=TMax2DLightingCapabilities.Create(1,result.native.Capabilities().MaximumLights(),True,True,True,True,True,True,True,True,allowAffine,allowDeformed)
  Return result
 End Method
End Type
Try
 Graphics(64,64)
 RegisterMax2DLightingBackend(New TMeshBackend)
 Check(Not TMax2DLightingCapabilities.Create(1,16,True,True,True,True,True,True,True,True).AffineMeshGeometry(),"existing providers default to triangle-only")
 Check(Not TMax2DLightingCapabilities.Create(1,16,True,True,True,True,True,True,True,True,True).DeformedMeshGeometry(),"existing affine providers default to no deformation")
 Local rejected:Int
 Try
  TMax2DLightingCapabilities.Create(1,16,False,False,False,False,False,False,False,False,True)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"affine capability requires mesh capability")
 rejected=False
 Try
  TMax2DLightingCapabilities.Create(1,16,True,True,True,True,True,True,True,True,False,True)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"deformed capability requires affine capability")
 For Local mode:Int=0 To 1
 allowDeformed=False
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
 SetClsColor(20,30,40,0.3)
 Local art:TImage=Solid($906080a0),normal:TImage=Solid($ffb080ed),gloss:TImage=Solid($ff800000),emission:TImage=Solid($8020a0ff)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(normal);material.SetSpecular(0.4,16)
 Local reference:TMax2DLighting=TMax2DLighting.Create(17),optimized:TMax2DLighting=TMax2DLighting.Create(17)
 For Local light:TMax2DLighting=EachIn [reference,optimized]
  light.SetLightBatching(True);light.SetAmbient(255,255,255,0.1)
  For Local i:Int=0 Until 17
   light.SetPointLight(i,20+i,18,100,255,180,120,0.025,1);light.SetLightHeight(i,24)
  Next
 Next
 Local mesh:TMesh2D=TMesh2D.Create([0.0,0.0,12.0,0.0,24.0,0.0,0.0,24.0,12.0,24.0,24.0,24.0],[0,1,4,0,4,3,1,2,5,1,5,4],[0.0,0.0,0.5,0.0,1.0,0.0,0.0,1.0,0.5,1.0,1.0,1.0])
 ' Instantiate independent sessions with immutable capabilities.
 allowAffine=False;reference.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 allowAffine=True;allowDeformed=mode;optimized.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Local capacity:Int=optimized.CaptureStats().MaximumGroupSize()
 For Local variant:Int=0 Until 26
  Local units:Int=1
  mesh.xy=[0.0,0.0,12.0,0.0,24.0,0.0,0.0,24.0,12.0,24.0,24.0,24.0]
  mesh.uv=[0.0,0.0,0.5,0.0,1.0,0.0,0.0,1.0,0.5,1.0,1.0,1.0]
  mesh.indices=[0,1,4,0,4,3,1,2,5,1,5,4]
  If variant=1 Then material.SetSpecularMap(gloss)
  If variant=2 Then material.SetEmission(100,180,255,0.3);material.SetEmissionMap(emission)
  If variant=3 Then
   For Local light:TMax2DLighting=EachIn [reference,optimized]
    light.SetOccluders([TMax2DLightOccluder.Create([24.0,20.0,28.0,20.0,28.0,30.0,24.0,30.0])])
    light.SetLightShadows(0,True,128);light.SetLightShadowSoftness(0,2)
    light.SetLightTexture(0,TMax2DLightTexture.Create(emission))
   Next
  End If
  If variant=4 Then mesh.xy[2]=13;units=4
  If variant=5 Then mesh.indices[3]=0;mesh.indices[4]=1;mesh.indices[5]=4;units=2
  If variant=6 Then mesh.uv[2]=0.6;units=4
  If variant=7 Then mesh.indices=[4,1,0,3,4,0,5,2,1,4,5,1]
  If variant=8 Then
   For Local i:Int=0 Until mesh.xy.Length Step 2
    mesh.xy[i]=-mesh.xy[i]+24
   Next
  End If
  If variant=10 Then
   For Local i:Int=0 Until mesh.xy.Length Step 2
    mesh.xy[i]:+1
   Next
  End If
  ' Two affine sections with independent normal-map bases.
  If variant>=12 Then
   mesh.xy[5]=6;mesh.xy[11]=30;units=2
  End If
  ' Overlap across sections is legal: section order retains painter order.
  If variant=13 Then mesh.xy[4]=0;mesh.xy[10]=0
  ' Interleaved sections cannot be reordered to combine matching bases.
  If variant=14 Then mesh.indices=[0,1,4,1,2,5,0,4,3,1,5,4];units=4
  ' Raw UV edits can also produce two independently mapped sections.
  If variant=15 Then mesh.uv[2]=0.25;mesh.uv[8]=0.25
  ' Degenerate geometry remains an individual triangle.
  If variant=16 Then mesh.xy[2]=0;mesh.xy[3]=0;units=4
  If variant=17 Then mesh.indices=[4,1,0,3,4,0,5,2,1,4,5,1]
  If variant=18 Then
   For Local i:Int=0 Until mesh.xy.Length Step 2
    mesh.xy[i]=-mesh.xy[i]+24
   Next
  End If
  SetCamera(Null);ResetCoordinates();SetOrigin(0,0);SetVirtualResolution(64,64)
  SetRotation(0);SetScale(1,1);SetHandle(0,0);SetAlpha(1);SetColor(255,255,255);SetViewport(0,0,64,64)
  If variant=9 Or variant=19 Then SetRotation(13);SetScale(0.8,1.1);SetHandle(3,5);SetAlpha(0.65);SetColor(190,220,160);SetViewport(8,10,40,38)
  If variant=20 Then
   Local camera:TCamera2D=New TCamera2D
   camera.x=20;camera.y=20;camera.offsetX=26;camera.offsetY=24;camera.zoom=1.2;camera.rotation=17
   SetCamera(camera)
  End If
  If variant=21 Then TransformCoordinates(0.8,0.2,-0.1,1.1,4,7);SetOrigin(2,3)
  If variant=22 Then SetVirtualResolution(48,56)
  If variant=23 Then SetVirtualResolution(80,64,VIRTUAL_LETTERBOX)
  If variant=24 Then SetScale(0,1)
  If variant=25 Then
   For Local i:Int=0 Until mesh.uv.Length Step 2
    mesh.uv[i]:/65536
   Next
  End If
  ' Repeat unchanged geometry, then compare raw edits on the next variant.
  For Local repeat:Int=0 To 1
   reference.ResetStats();optimized.ResetStats()
   Cls;reference.DrawMesh(mesh,art,16,16,0,-1,0.8,0.2,-0.1,1.2,4,7,material)
   Local wanted:TPixmap=ReadRenderImage(target)
   Cls;optimized.DrawMesh(mesh,art,16,16,0,-1,0.8,0.2,-0.1,1.2,4,7,material)
   Check(Same(wanted,ReadRenderImage(target)),"affine/triangle pixel parity variant "+variant)
   Local expectedUnits:Int=units
   If mode And variant<>5 And variant<>13 And variant<>16 And variant<>24 And variant<>25 Then expectedUnits=1
   Check(optimized.CaptureStats().GroupedPasses()=expectedUnits*((17+capacity-1)/capacity),"affine/fallback group count variant "+variant)
   Check(reference.CaptureStats().GroupedPasses()=4*((17+capacity-1)/capacity),"legacy provider remains per triangle")
  Next
 Next
 mesh.uv=[0.0,0.0,0.5,0.0,1.0,0.0,0.0,1.0,0.5,1.0,1.0,1.0]
 ' A bent strip with eight affine sections and 128 triangles. Column order
 ' deliberately keeps each section contiguous, without changing painter order.
 Local gridXY:Float[162],gridUV:Float[162],gridIndices:Int[384]
 For Local col:Int=0 To 8
  For Local row:Int=0 To 8
   Local v:Int=(col*9+row)*2
   gridXY[v]=col*3;gridXY[v+1]=row*3+(col Mod 2)*2
   gridUV[v]=Float(col)/8;gridUV[v+1]=Float(row)/8
  Next
 Next
 For Local col:Int=0 Until 8
  For Local row:Int=0 Until 8
   Local a:Int=col*9+row,b:Int=a+9,k:Int=(col*8+row)*6
   gridIndices[k]=a;gridIndices[k+1]=b;gridIndices[k+2]=b+1
   gridIndices[k+3]=a;gridIndices[k+4]=b+1;gridIndices[k+5]=a+1
  Next
 Next
 Local strip:TMesh2D=TMesh2D.Create(gridXY,gridIndices,gridUV)
 SetCamera(Null);ResetCoordinates();SetOrigin(0,0);SetVirtualResolution(64,64)
 SetRotation(0);SetScale(1,1);SetHandle(0,0);SetAlpha(0.75);SetViewport(0,0,64,64)
 For Local repeat:Int=0 Until 3
  If repeat=2 Then
   For Local row:Int=0 To 8
    strip.xy[(4*9+row)*2+1]:+1
   Next
  End If
  reference.ResetStats();optimized.ResetStats()
  Cls;reference.DrawMesh(strip,art,16,16,0,-1,1,0,0,1,0,0,material)
  Local wanted:TPixmap=ReadRenderImage(target)
  Cls;optimized.DrawMesh(strip,art,16,16,0,-1,1,0,0,1,0,0,material)
  Check(Same(wanted,ReadRenderImage(target)),"bent strip parity after warm/raw-edit draw "+repeat)
  Check(optimized.CaptureStats().GroupedPasses()=(8-7*mode)*((17+capacity-1)/capacity),"bent strip groups eight sections")
  Check(reference.CaptureStats().GroupedPasses()=128*((17+capacity-1)/capacity),"bent strip legacy triangle count")
 Next
 ' Return to smaller arrays after growing retained section storage.
 Cls;reference.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Local smaller:TPixmap=ReadRenderImage(target)
 Cls;optimized.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Check(Same(smaller,ReadRenderImage(target)),"smaller mesh after retained storage growth")
 ' An opting-in provider may still reject a material/group at Supports.
 declineGroups=True;reference.ResetStats();optimized.ResetStats()
 Cls;reference.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Local declined:TPixmap=ReadRenderImage(target)
 Cls;optimized.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Check(Same(declined,ReadRenderImage(target)),"declined sections preserve ordinary fallback pixels")
 Check(optimized.CaptureStats().GroupedPasses()=0,"declined sections never submit native groups")
 declineGroups=False
 ' Rejection of the last group must happen before any deformed submission.
 rejectLast=True;deformedDraws=0
 Cls;reference.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Local rejectedLast:TPixmap=ReadRenderImage(target)
 Cls;optimized.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Check(Same(rejectedLast,ReadRenderImage(target)),"late group rejection preserves fallback pixels")
 Check(deformedDraws=0,"late rejection never partially draws the deformed receiver")
 rejectLast=False
 If mode Then
  rejectAfterDraw=True;deformedDraws=0;rejected=False
  Local previousBlend:Int=GetBlend()
  Try
   optimized.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And deformedDraws=1,"changed support after submission throws without fallback redraw")
  Check(GetBlend()=previousBlend,"failed deformed draw restores blend")
  rejectAfterDraw=False
  Cls;reference.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
  Local recovered:TPixmap=ReadRenderImage(target)
  Cls;optimized.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
  Check(Same(recovered,ReadRenderImage(target)),"deformed drawing recovers after provider failure")
 End If
 ' Releasing analysis and recreating it must not change output or retain a mesh.
 optimized.Release();allowAffine=True
 Cls;optimized.DrawMesh(mesh,art,16,16,0,-1,0.8,0.2,-0.1,1.2,4,7,material)
 Check(optimized.CaptureStats().GroupedPasses()>0,"released analysis recreates")
 ' Invalid UV edits must fail before drawing, even after a warm accepted cache.
 mesh.uv[2]=0;mesh.uv[3]=0;rejected=False;optimized.ResetStats()
 Try
  optimized.DrawMesh(mesh,art,16,16)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And optimized.CaptureStats().AmbientPasses()=0,"invalid raw edit rejected before submission")
 ' A failure late in analysis must not leave a reusable partially filled cache.
 mesh.uv[2]=0.5;mesh.uv[10]=1;mesh.uv[11]=0
 For Local attempt:Int=0 To 1
  rejected=False;optimized.ResetStats()
  Try
   optimized.DrawMesh(mesh,art,16,16)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And optimized.CaptureStats().AmbientPasses()=0,"repeated late singular UV edit rejected before drawing")
 Next
 mesh.uv[11]=1
 Cls;reference.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Local repaired:TPixmap=ReadRenderImage(target)
 Cls;optimized.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Check(Same(repaired,ReadRenderImage(target)),"repaired geometry recreates complete cached mappings")
 For Local attempt:Int=0 To 1
  rejected=False;optimized.ResetStats()
  Try
   optimized.DrawMesh(mesh,art,16,16,0,-1,3.0e38,0,0,1)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And optimized.CaptureStats().AmbientPasses()=0,"cached mappings still validate changed lighting transform")
 Next
 ' Select a small light outside the first triangle's extrapolated image bounds.
 mesh.xy[4]=40;mesh.xy[10]=40
 For Local light:TMax2DLighting=EachIn [reference,optimized]
  For Local i:Int=0 Until 17
   light.SetPointLight(i,52,38,9,255,180,120,0,1)
  Next
  light.SetPointLight(16,52,38,9,255,180,120,1,1)
 Next
 Cls;reference.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Local distant:TPixmap=ReadRenderImage(target)
 Cls;optimized.ResetStats();optimized.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material)
 Check(Same(distant,ReadRenderImage(target)),"complete deformed bounds retain distant selected light")
 If mode Then Check(optimized.CaptureStats().GroupedPasses()=1,"distant selected light uses whole receiver")
 ' Ambient-only whole mesh requires no native light groups.
 Cls;reference.DrawMesh(mesh,art,16,16,0,0,1,0,0,1,0,0,material)
 Local ambientOnly:TPixmap=ReadRenderImage(target)
 Cls;optimized.ResetStats();optimized.DrawMesh(mesh,art,16,16,0,0,1,0,0,1,0,0,material)
 Check(Same(ambientOnly,ReadRenderImage(target)) And optimized.CaptureStats().GroupedPasses()=0,"deformed ambient-only parity")
 reference.Release();optimized.Release();material.ReleaseResources()
 SetRenderImage(Null);target.ReleaseFrames();art.ReleaseFrames();normal.ReleaseFrames();gloss.ReleaseFrames();emission.ReleaseFrames()
 Next
 EndGraphics
 Print "PASS: "+checks+" affine mesh checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
