SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
Import Max2D.GLProfiling
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
Import Max2D.D3DProfiling
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
Import Max2D.D3DProfiling
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.Lighting
Import Max2D.Profiling
Import SDL3.SDL3
Import BRL.StandardIO

Extern "C"
 Function SDL_GetTicksNS:ULong()
End Extern

Global forcePacked:Int

' Keep all native capabilities except independent specular sampling identical.
Type TMaterialRenderer Extends TMax2DLightingRenderer
 Field native:TMax2DLightingRenderer,limits:TMax2DLightingCapabilities
 Method Capabilities:TMax2DLightingCapabilities() Override;Return limits;End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override;Return native.Supports(canvas,draw);End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override;native.Draw(canvas,draw);End Method
 Method Release() Override;native.Release();End Method
End Type
Type TMaterialBackend Extends TMax2DLightingBackend
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Override
  Local result:TMaterialRenderer=New TMaterialRenderer
  result.native=CreateNativeMax2DLightingRenderer(context)
  If Not result.native Then Return Null
  result.limits=TMax2DLightingCapabilities.Create(1,result.native.Capabilities().MaximumLights(),True,True,True,True,True,True,True,True,True,True,True,Not forcePacked)
  Return result
 End Method
End Type

Function Require(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Allocated:Long(stats:SGCStats Var)
 Return Long(stats.allocedBytesBeforeGC)+Long(stats.bytesAllocedSinceGC)
End Function
Function Solid:TImage(size:Int,colour:Int)
 Local pix:TPixmap=CreatePixmap(size,size,PF_RGBA8888)
 pix.ClearPixels(colour)
 Return LoadImage(pix,0)
End Function

' Every mesh covers the same square with the same affine UV mapping.
Function Grid:TMesh2D(cells:Int)
 Local xy:Float[(cells+1)*(cells+1)*2],uv:Float[xy.Length],indices:Int[cells*cells*6]
 For Local y:Int=0 To cells
  For Local x:Int=0 To cells
   Local v:Int=(y*(cells+1)+x)*2
   uv[v]=Float(x)/cells;uv[v+1]=Float(y)/cells
   xy[v]=uv[v]*256;xy[v+1]=uv[v+1]*256
  Next
 Next
 For Local y:Int=0 Until cells
  For Local x:Int=0 Until cells
   Local k:Int=(y*cells+x)*6,a:Int=y*(cells+1)+x,b:Int=a+1,c:Int=a+cells+2,d:Int=c-1
   indices[k]=a;indices[k+1]=b;indices[k+2]=c
   indices[k+3]=a;indices[k+4]=c;indices[k+5]=d
  Next
 Next
 Return TMesh2D.Create(xy,indices,uv)
End Function

Type TMaterialWorkload
 Field art:TImage,normal:TImage,gloss:TImage,emission:TImage
 Field editPixels:TPixmap
 Field material:TMax2DLightingMaterial
 Field lighting:TMax2DLighting
 Field mesh:TMesh2D
 Field target:TRenderImage
 Field builder:TMax2DLightingMaterialMap
 Field packed:TImage
 Field canvas:TMax2DGraphics
 Field mode:Int,receivers:Int,triangles:Int,lightCount:Int,mapSize:Int,tick:Int,packing:Int
 Field baselineFrames:Int
 Field lightStats:TMax2DLightingStats=New TMax2DLightingStats

 Method Initialize(kind:Int,cells:Int,count:Int,lights:Int,size:Int,packOnly:Int=False)
  canvas=TMax2DGraphics.Current();baselineFrames=canvas.context.frames.Count()
  mode=kind;receivers=count;lightCount=lights;mapSize=size;packing=packOnly
  art=Solid(64,$ff608090);normal=Solid(size,$ff8080ff)
  gloss=Solid(size,$ff800000);emission=Solid(size,$ff2080c0)
  editPixels=CreatePixmap(size,size,PF_RGBA8888);editPixels.ClearPixels($ff800000)
  material=TMax2DLightingMaterial.Create();material.SetNormalMap(normal)
  material.SetSpecular(0.4,16);material.SetEmission(100,180,255,0.25)
  If mode=1 Or mode=3 Or mode=5 Then material.SetEmissionMap(emission)
  If mode=2 Or mode=3 Or mode=4 Then material.SetSpecularMap(gloss)
  If packing Then builder=TMax2DLightingMaterialMap.Create()
  If cells Then mesh=Grid(cells);triangles=cells*cells*2
  lighting=TMax2DLighting.Create(lights);lighting.SetLightBatching(True)
  lighting.SetAmbient(255,255,255,0.1)
  For Local i:Int=0 Until lights
   lighting.SetDirectionalLight(i,0.2,0.3,1,255,200,150,0.025)
  Next
  target=CreateRenderImage(256,256,0)
  SetRenderImage(target);SetVirtualResolution(256,256);SetViewport(0,0,256,256)
  SetClsColor(0,0,0,0);SetColor(255,255,255);SetAlpha(1)
 End Method

 Method Edit()
  tick:+1
  If mode=4 Or mode=5 Then
   ' A one-pixel change still invalidates the complete input for packing/upload.
   editPixels.WritePixel(0,0,$ff000000 | ((64+(tick Mod 128)) Shl 16))
   If mode=4 Then gloss.ReplacePixels(editPixels) Else emission.ReplacePixels(editPixels)
  End If
 End Method

 Method Draw()
  If packing Then
   Local previous:TImage=packed
   packed=builder.Update(normal,gloss)
   If previous Then Require(packed=previous,"same-size packing replaced output identity")
   Return
  End If
  Cls
  If mesh Then
   lighting.DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material)
  Else If receivers=1 Then
   SetScale(4,4)
   lighting.DrawImage(art,0,0,0,-1,4,0,0,4,0,0,material)
   SetScale(1,1)
  Else
   For Local i:Int=0 Until receivers
    lighting.DrawImage(art,(i Mod 4)*64,(i/4)*64,0,-1,1,0,0,1,0,0,material)
   Next
  End If
  FlushMax2D()
 End Method

 Method Drain()
  If Not packing Then canvas.context.Read(canvas.context.target,0,0,1,1)
 End Method

 Method CheckMeshPixels()
  If Not mesh Then Return
  Draw()
  Local actual:TPixmap=ReadRenderImage(target)
  Cls;SetScale(4,4)
  lighting.DrawImage(art,0,0,0,-1,4,0,0,4,0,0,material)
  SetScale(1,1)
  Local reference:TPixmap=ReadRenderImage(target)
  For Local y:Int=0 Until 256
   For Local x:Int=0 Until 256
    Local a:Int=actual.ReadPixel(x,y),b:Int=reference.ReadPixel(x,y)
    For Local shift:Int=0 To 24 Step 8
     Require(Abs((a Shr shift & 255)-(b Shr shift & 255))<=3,"subdivided mesh differs from sprite reference")
    Next
   Next
  Next
 End Method

 Method CheckMaterialPixels()
  If packing Or (mode<>2 And mode<>3 And mode<>4) Then Return
  Draw()
  Local actual:TPixmap=ReadRenderImage(target),saved:Int=forcePacked
  lighting.Release();forcePacked=Not saved
  Draw()
  Local reference:TPixmap=ReadRenderImage(target)
  lighting.Release();forcePacked=saved;material.ReleaseResources()
  For Local y:Int=0 Until 256
   For Local x:Int=0 Until 256
    For Local shift:Int=0 To 24 Step 8
     Require(Abs((actual.ReadPixel(x,y) Shr shift & 255)-(reference.ReadPixel(x,y) Shr shift & 255))<=3,"native specular differs from packed material")
    Next
   Next
  Next
 End Method

 Method Measure(trial:Int,frames:Int,warmup:Int,wantGpu:Int)
  For Local i:Int=0 Until warmup
   Edit();Draw()
  Next
  Drain()
  Local timer:TMax2DGpuTimer
  If wantGpu And Not packing Then timer=TMax2DGpuTimer.Create(128)
  GCCollect();ResetMax2DStats();lighting.ResetStats()
  Local before:SGCStats,after:SGCStats,heap:SGCStats
  Local editTime:ULong,drawTime:ULong,bytes:Long,cycles:Long
  Local gpuTotal:Long,gpuSamples:Int,gpuRejected:Int,gpuId:Long,gpuNanos:Long
  Local startInterval:ULong=SDL_GetTicksNS()
  For Local frame:Int=0 Until frames
   GCGetStats(before)
   Local start:ULong=SDL_GetTicksNS()
   Edit()
   Local edited:ULong=SDL_GetTicksNS(),timed:Int
   If timer Then
    timed=timer.Begin(frame)
    If Not timed Then gpuRejected:+1
   End If
   Draw()
   If timed Then timer.EndSample()
   Local drawn:ULong=SDL_GetTicksNS()
   GCGetStats(after)
   editTime:+edited-start;drawTime:+drawn-edited
   bytes:+Allocated(after)-Allocated(before);cycles:+Long(after.GCCycleNo)-Long(before.GCCycleNo)
   If timer Then
    While timer.Poll(gpuId,gpuNanos)
     gpuTotal:+gpuNanos;gpuSamples:+1
    Wend
   End If
  Next
  Drain()
  Local drained:ULong=SDL_GetTicksNS()-startInterval
  Local gpuMean:String="unavailable",pending:Int,discarded:Long
  If timer Then
   While timer.Poll(gpuId,gpuNanos)
    gpuTotal:+gpuNanos;gpuSamples:+1
   Wend
   pending=timer.Pending();discarded=timer.Discarded()
   If gpuSamples Then gpuMean=String(Double(gpuTotal)/gpuSamples/1000)
  End If
  Local stats:TMax2DStats=CaptureMax2DStats()
  lighting.CopyStats(lightStats)
  Require(stats.textureCreations=0,"warmed workload created textures")
  If mode<4 Then Require(stats.textureUpdates=0,"unchanged maps uploaded pixels")
  If Not packing Then
   Require(lightStats.GroupedPasses()>0,"native grouped path not exercised")
   Require(lightStats.OrdinaryLightPasses()=0,"unexpected ordinary fallback")
   Local units:Int=receivers
   If mesh Then units=1
   Local groupSize:Int=lightStats.MaximumGroupSize()
   Require(lightStats.GroupedPasses()=Long(frames)*units*((lightCount+groupSize-1)/groupSize),"unexpected per-receiver group count")
   Require(lightStats.AmbientPasses()=Long(frames)*units,"unexpected ambient count")
   Require(lightStats.CombinedAmbientPasses()=Long(frames)*units,"unexpected combined ambient count")
   If mode=4 Or mode=5 Then Require(stats.textureUpdates=frames,"edited shared map did not upload once per frame")
  Else
   Require(stats.textureUpdates=0,"CPU-only packing uploaded pixels")
  End If
  GCCollect();GCGetStats(heap)
  Local names:String[]=["uniform","emission","specular","both","edit_specular","edit_emission"]
  Print packing+","+names[mode]+","+trial+","+triangles+","+receivers+","+lightCount+","+mapSize+","+frames+","+Double(editTime)/1000/frames+","+Double(drawTime)/1000/frames+","+Double(drained)/1000/frames+","+Double(bytes)/frames+","+cycles+","+Double(stats.submissions)/frames+","+Double(lightStats.GroupedPasses())/frames+","+Double(lightStats.AmbientPasses())/frames+","+Double(lightStats.CombinedAmbientPasses())/frames+","+stats.textureCreations+","+stats.textureUpdates+","+stats.uploadedPixels+","+lightStats.RetainedShadowBytes()+","+lightStats.RetainedMapBytes()+","+(Long(heap.heapsize)-Long(heap.freeBytes))+","+wantGpu+","+(timer<>Null)+","+gpuSamples+","+pending+","+gpuRejected+","+discarded+","+gpuMean+","+forcePacked
  If timer Then timer.Release()
 End Method

 Method Release()
  lighting.Release();material.ReleaseResources()
  If builder Then builder.Release();packed=Null
  lighting.CopyStats(lightStats)
  Require(lightStats.RetainedShadowBytes()=0 And lightStats.RetainedMapBytes()=0,"lighting storage survived release")
  SetRenderImage(Null);target.ReleaseFrames()
  art.ReleaseFrames();normal.ReleaseFrames();gloss.ReleaseFrames();emission.ReleaseFrames()
  canvas.context.DrainReleases()
  Require(canvas.context.frames.Count()=baselineFrames,"native image frames survived workload cleanup: "+canvas.context.frames.Count()+" baseline "+baselineFrames)
 End Method
End Type

Try
 Local frames:Int=30,warmup:Int=8,trials:Int=3,gpu:Int,mapSize:Int=64
 For Local arg:String=EachIn AppArgs
  If arg="--quick" Then frames=3;warmup=2;trials=1
  If arg="--gpu" Then gpu=True
  If arg="--packed" Then forcePacked=True
  If arg="--large-maps" Then mapSize=256
 Next
 Graphics(320,320);Flip(0)
 RegisterMax2DLightingBackend(New TMaterialBackend)
 Print "# material_geometry: fixed 256x256 coverage; "+mapSize+"x"+mapSize+" shared maps; directional lights; grouped rendering"
 Print "# packing rows time CPU builder only; draw_us includes lazy material packing on render rows; no presentation in measured interval"
 Print "packing,case,trial,triangles,receivers,lights,map_size,frames,edit_us,draw_us,drained_us,managed_bytes_per_frame,gc_cycles,submissions_per_frame,groups_per_frame,ambient_per_frame,combined_ambient_per_frame,new_textures,texture_updates,uploaded_pixels,shadow_bytes,light_atlas_bytes,used_heap_after_gc,gpu_requested,gpu_supported,gpu_samples,gpu_pending,gpu_rejected,gpu_discarded,gpu_us,forced_packing"
 For Local lights:Int=EachIn [1,17]
  For Local geometry:Int=0 To 5
   Local cells:Int,receivers:Int=1
   If geometry=1 Then receivers=16
   If geometry>=2 Then cells=1 Shl (geometry-2)
   For Local mode:Int=0 To 5
    Local workload:TMaterialWorkload=New TMaterialWorkload
    workload.Initialize(mode,cells,receivers,lights,mapSize)
    workload.CheckMeshPixels();workload.CheckMaterialPixels()
    For Local trial:Int=1 To trials
     workload.Measure(trial,frames,warmup,gpu)
    Next
    workload.Release()
   Next
  Next
 Next
 For Local size:Int=EachIn [64,256]
  For Local mode:Int=EachIn [2,4]
   Local workload:TMaterialWorkload=New TMaterialWorkload
   workload.Initialize(mode,0,0,0,size,True)
   For Local trial:Int=1 To trials
    workload.Measure(trial,frames,warmup,False)
   Next
   workload.Release()
  Next
 Next
 EndGraphics
 Print "# benchmark complete; all workload native-frame and lighting-storage cleanup checks passed"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics
 EndWithCode(1)
End Try
