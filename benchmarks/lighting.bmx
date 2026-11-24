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
Import BRL.StandardIO
Import SDL3.SDL3
Import "timing.c"
Extern "C"
 Function max2d_bench_seconds:Double()
End Extern

' CPU frame timings include Flip(0) and any driver back-pressure, not GPU timestamps.
Graphics(800,600)
Flip(0) ' Set the presentation mode before creating D3D9 queries.
SetVirtualResolution(800,600)
Local frames:Int=60,warmup:Int=20,paired:Int,normalMapped:Int,patterns:Int,batchLimit:Int=16,gpu:Int
For Local arg:String=EachIn AppArgs
 If arg="--paired" Or arg="--grouped" Then paired=True
 If arg="--gpu" Then gpu=True
 If arg="--normal" Then normalMapped=True
 If arg="--patterns" Then patterns=True
 If arg="--batch-limit=8" Then batchLimit=8
 If arg="--batch-limit=16" Then batchLimit=16
 If arg="--quick" Then frames=5;warmup=3
Next
Local source:TRenderImage=CreateRenderImage(64,64,0)
SetRenderImage(source);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
SetClsColor(100,120,155,1);Cls
SetColor(180,200,225);DrawRect(3,3,58,58)
SetRenderImage(Null);SetVirtualResolution(800,600);SetViewport(0,0,800,600)
Local material:TMax2DLightingMaterial,normal:TImage
If normalMapped Then
 Local pixels:TPixmap=CreatePixmap(64,64,PF_RGBA8888)
 For Local y:Int=0 Until 64
  For Local x:Int=0 Until 64
   Local nx:Float=(x-31.5)/64,ny:Float=(y-31.5)/64,nz:Float=Sqr(1-nx*nx-ny*ny)
   pixels.WritePixel(x,y,Int($ff000000 | (UInt((nx*0.5+0.5)*255) Shl 16) | (UInt((ny*0.5+0.5)*255) Shl 8) | UInt((nz*0.5+0.5)*255)))
  Next
 Next
 normal=LoadImage(pixels,0)
 material=TMax2DLightingMaterial.Create();material.SetNormalMap(normal);material.SetSpecular(0.25,16)
End If
Local pattern:TImage,projection:TMax2DLightTexture
If patterns Then
 Local pixels:TPixmap=CreatePixmap(32,32,PF_RGBA8888)
 For Local y:Int=0 Until 32
  For Local x:Int=0 Until 32
   pixels.WritePixel(x,y,Int((UInt(64+x*6) Shl 24) | (UInt(100+y*5) Shl 16) | $0000c080))
  Next
 Next
 pattern=LoadImage(pixels,FILTEREDIMAGE)
 projection=TMax2DLightTexture.Create(pattern);projection.SetPlacement(360,300,0,0,17)
End If
Local walls:TMax2DLightOccluder[16]
For Local i:Int=0 Until walls.Length
 Local x:Float=80+(i Mod 4)*180,y:Float=70+(i/4)*130
 walls[i]=TMax2DLightOccluder.Create([x,y,x+24,y,x+24,y+24,x,y+24])
 walls[i].SetHeight(24)
Next
Local snapshot:TMax2DLightingStats=New TMax2DLightingStats
Print "grouped,batch_limit,normal_mapped,patterns,lights,receivers,casters,shadows,resolution,softness,moving,frames,mean_cpu_ms,mean_draw_cpu_ms,mean_present_cpu_ms,light_tests,light_passes,ambient_passes,combined_ambient_passes,lighting_submissions,light_contributions,grouped_passes,grouped_light_contributions,ordinary_light_passes,maximum_group_size,group_support_checks,group_support_rejections,paired_passes,bounds_rejects,shadow_rebuilds,shadow_hits,caster_tests,filter_passes,shadow_bytes,map_uploads,map_hits,map_bytes,texture_creations,submissions,gpu_requested,gpu_supported,gpu_samples,gpu_pending,gpu_rejected,gpu_discarded,mean_gpu_ms"
For Local lightCount:Int=EachIn [1,4,8,9,16]
 For Local receivers:Int=1 To 64 Step 63
  For Local mode:Int=0 To 2
   For Local moving:Int=0 To 1
    Local lighting:TMax2DLighting=TMax2DLighting.Create(lightCount)
    lighting.SetLightBatching(paired);lighting.SetLightBatchLimit(batchLimit)
    lighting.SetAmbient(255,255,255,0.12);lighting.SetOccluders(walls)
    Local softness:Float
    If mode=2 Then softness=3
    For Local i:Int=0 Until lightCount
     lighting.SetPointLight(i,100+(i Mod 4)*180,80+(i/4)*130,220,255,190,110,0.5)
     If projection Then lighting.SetLightTexture(i,projection)
     If mode Then lighting.SetLightShadows(i,True,256);lighting.SetLightShadowSoftness(i,softness)
    Next
    Local timer:TMax2DGpuTimer
    If gpu Then timer=TMax2DGpuTimer.Create(128)
    Local gpuTotal:Long,gpuSamples:Int,gpuRejected:Int,gpuId:Long,gpuNanos:Long
    Local elapsed:Double,drawElapsed:Double,presentElapsed:Double
    For Local frame:Int=-warmup Until frames
     If frame=0 Then lighting.ResetStats();ResetMax2DStats()
     Local start:Double=max2d_bench_seconds()
     If moving Then lighting.SetPointLight(0,Float(100+Sin((frame+warmup)*3)*40),80,220,255,190,110,0.5)
     Local timed:Int
     If timer And frame>=0 Then
      timed=timer.Begin(frame)
      If Not timed Then gpuRejected:+1
     End If
     SetClsColor(14,18,26);Cls;SetColor(255,255,255)
     If receivers=1 Then
      SetScale(12,8)
      lighting.DrawImage(source,0,0,0,-1,12,0,0,8,0,0,material)
      SetScale(1,1)
     Else
      SetScale(1.5,1)
      For Local i:Int=0 Until receivers
       lighting.DrawImage(source,(i Mod 8)*96,(i/8)*64,0,-1,1.5,0,0,1,-(i Mod 8)*48,0,material)
      Next
      SetScale(1,1)
     End If
     ' HUD remains unlit and is included in frame timing and renderer submissions.
     DrawText("Lighting stress: "+lightCount+" lights / "+receivers+" receivers / mode "+mode+" / moving "+moving,8,540)
     DrawText("Modes: 0 no shadows, 1 hard, 2 filtered. CSV is written to stdout.",8,560)
     If timed Then timer.EndSample()
     Local beforePresent:Double=max2d_bench_seconds()
     Flip(0)
     Local finished:Double=max2d_bench_seconds()
     If timer Then
      While timer.Poll(gpuId,gpuNanos)
       gpuTotal:+gpuNanos;gpuSamples:+1
      Wend
     End If
     If frame>=0 Then
      elapsed:+finished-start;drawElapsed:+beforePresent-start;presentElapsed:+finished-beforePresent
     End If
    Next
    Local gpuMean:String="unavailable",pending:Int,discarded:Long
    If timer Then
     While timer.Poll(gpuId,gpuNanos)
      gpuTotal:+gpuNanos;gpuSamples:+1
     Wend
     pending=timer.Pending()
     discarded=timer.Discarded()
     If gpuSamples Then gpuMean=String(Double(gpuTotal)/gpuSamples/1000000.0)
    End If
    lighting.CopyStats(snapshot)
    Local render:TMax2DStats=CaptureMax2DStats()
    Print paired+","+batchLimit+","+normalMapped+","+patterns+","+lightCount+","+receivers+",16,"+(mode<>0)+",256,"+softness+","+moving+","+frames+","+(elapsed*1000/frames)+","+(drawElapsed*1000/frames)+","+(presentElapsed*1000/frames)+","+snapshot.LightTests()+","+snapshot.LightPasses()+","+snapshot.AmbientPasses()+","+snapshot.CombinedAmbientPasses()+","+(snapshot.LightPasses()+snapshot.AmbientPasses()-snapshot.CombinedAmbientPasses())+","+snapshot.LightContributions()+","+snapshot.GroupedPasses()+","+snapshot.GroupedLightContributions()+","+snapshot.OrdinaryLightPasses()+","+snapshot.MaximumGroupSize()+","+snapshot.GroupSupportChecks()+","+snapshot.GroupSupportRejections()+","+snapshot.PairedPasses()+","+snapshot.BoundsRejects()+","+snapshot.ShadowRebuilds()+","+snapshot.ShadowCacheHits()+","+snapshot.OccluderTests()+","+snapshot.FilterPasses()+","+snapshot.RetainedShadowBytes()+","+snapshot.MapUploads()+","+snapshot.MapCacheHits()+","+snapshot.RetainedMapBytes()+","+render.textureCreations+","+render.submissions+","+gpu+","+(timer<>Null)+","+gpuSamples+","+pending+","+gpuRejected+","+discarded+","+gpuMean
    If timer Then timer.Release()
    lighting.Release()
   Next
  Next
 Next
Next
If normal Then normal.ReleaseFrames()
If pattern Then pattern.ReleaseFrames()
source.ReleaseFrames();EndGraphics
