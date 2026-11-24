SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.Scene
Import BRL.StandardIO

Function Allocated:Long(stats:SGCStats Var)
 Return Long(stats.allocedBytesBeforeGC)+Long(stats.bytesAllocedSinceGC)
End Function
Function StepCase(kind:Int,scene:TScene)
 Select kind
  Case 1
   Local scope:TMax2DStateScope=ScopedMax2DState()
   scope.Close()
  Case 2,3,4
   scene.Render()
 End Select
 FlushMax2D()
End Function
Try
 Graphics(64,64)
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local pixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888);pixels.ClearPixels($ffffffff)
 Local image:TImage=LoadImage(pixels,0),target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
 Local names:String[]=["flush_only","state_scope","empty_scene","sprite_scene","eight_text_nodes"]
 Print "# isolated warmed allocation probes; rendering flushed each call; no timing claims"
 Print "case,trial,calls,managed_bytes_per_call,gc_cycles,new_textures,submissions_per_call"
 For Local kind:Int=0 To 4
  Local scene:TScene=TScene.Create()
  Local layer:TLayerNode=TLayerNode.Create()
  scene.Root().AddChild(layer)
  If kind=3 Then layer.AddChild(TSpriteNode.Create(image))
  If kind=4 Then
   For Local i:Int=0 Until 8
    Local label:TTextNode=TTextNode.Create("STATUS READY",GetImageFont())
    label.SetPosition(0,i*8);layer.AddChild(label)
   Next
  End If
  For Local trial:Int=1 To 3
   For Local warm:Int=0 Until 32
    StepCase(kind,scene)
   Next
   canvas.context.Read(canvas.context.target,0,0,1,1)
   GCCollect();ResetMax2DStats()
   Local before:SGCStats,after:SGCStats
   GCGetStats(before)
   For Local iteration:Int=0 Until 2000
    StepCase(kind,scene)
   Next
   GCGetStats(after)
   Local stats:TMax2DStats=CaptureMax2DStats()
   If stats.textureCreations Then Throw "warm allocation probe created textures"
   Print names[kind]+","+trial+",2000,"+Double(Allocated(after)-Allocated(before))/2000+","+(Long(after.GCCycleNo)-Long(before.GCCycleNo))+","+stats.textureCreations+","+Double(stats.submissions)/2000
  Next
  scene.Destroy()
 Next
 SetRenderImage(Null);target.ReleaseFrames();image.ReleaseFrames();canvas.context.DrainReleases()
 ' Default font frames belong to the canvas and are released with its context.
 EndGraphics()
 If Not canvas.context.frames.IsEmpty() Then Throw "context cleanup retained native frames"
 Print "# PASS: allocation probes and context cleanup"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
