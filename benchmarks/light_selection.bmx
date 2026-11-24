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
Import "timing.c"
Extern "C"
 Function max2d_bench_seconds:Double()
End Extern

' CPU light setup and draw time, including submission/back-pressure; no Flip or GPU timestamps.
Graphics(640,480)
Local pixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
pixels.ClearPixels($ffb09070)
Local source:TImage=LoadImage(pixels,0)
Local output:TRenderImage=CreateRenderImage(64,64)
SetRenderImage(output);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
Print "lights,receivers,moving,spatial,mean_setup_draw_cpu_ms,light_tests,node_tests,spatial_rejects,rebuilds"
For Local count:Int=EachIn [32,256,1024]
 For Local moving:Int=0 To 1
  For Local indexed:Int=0 To 1
   Local lighting:TMax2DLighting=TMax2DLighting.Create(count)
   lighting.SetSpatialSelection(indexed);lighting.SetLightBatching(True)
   For Local i:Int=0 Until count
    Local cell:Int=(i*73) Mod count
    lighting.SetPointLight(i,(cell Mod 32)*80,(cell/32)*80,24,255,200,140,0.2)
   Next
   Local elapsed:Double
   For Local frame:Int=0 Until 40
    If frame=10 Then lighting.ResetStats()
    Local started:Double=max2d_bench_seconds()
    If moving Then
     For Local i:Int=0 Until count
      Local cell:Int=(i*73) Mod count
      lighting.SetPointLight(i,(cell Mod 32)*80+(frame Mod 2),(cell/32)*80,24,255,200,140,0.2)
     Next
    End If
    Cls
    For Local receiver:Int=0 Until 64
     Local x:Float=(receiver Mod 8)*80,y:Float=(receiver/8)*80
     lighting.DrawImage(source,0,0,0,-1,1,0,0,1,x,y)
    Next
    TMax2DGraphics.Current().context.Flush()
    If frame>=10 Then elapsed:+max2d_bench_seconds()-started
   Next
   Local stats:TMax2DLightingStats=lighting.CaptureStats()
   Print count+",64,"+moving+","+indexed+","+(elapsed*1000/30)+","+(stats.LightTests()/30)+","+(stats.SelectionNodeTests()/30)+","+(stats.SpatialRejects()/30)+","+(stats.SelectionRebuilds()/30)
   lighting.Release()
  Next
 Next
Next
SetRenderImage(Null);output.ReleaseFrames();EndGraphics
