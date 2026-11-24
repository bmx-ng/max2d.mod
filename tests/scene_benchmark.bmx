SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
Import SDL3.SDL3
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.SceneEffects
Import BRL.StandardIO

Extern "C"
 Function SDL_GetTicksNS:ULong()
End Extern

Global checksum:Double
Type TBenchNode Extends TSceneNode2D
 Field moves:Int
 Method OnUpdate(dt:Double) Override
  checksum:+dt
 End Method
 Method OnPointer(event:TScenePointerEvent) Override
  If event.Kind()=EScenePointerKind.Down Then event.CapturePointer(Self)
  If event.Kind()=EScenePointerKind.Move Then moves:+1
  event.Handle()
 End Method
End Type

Function Allocated:Long(stats:SGCStats Var)
 Return Long(stats.allocedBytesBeforeGC)+Long(stats.bytesAllocedSinceGC)
End Function

Function LogicStep(mode:Int,iteration:Int,scene:TScene,parent:TSceneNode2D,nodes:TBenchNode[])
 Local x:Float,y:Float
 Select mode
  Case 0,1
   scene.Update(0.001)
  Case 2
   parent.SetPosition(iteration Mod 2,0)
   For Local node:TBenchNode=EachIn nodes
    node.LocalToWorld(0,0,x,y)
    checksum:+x
   Next
  Case 3
   For Local i:Int=0 Until nodes.Length
    nodes[i].SetPosition((i Mod 100)*5+(iteration Mod 2),i/100*5)
    nodes[i].LocalToWorld(0,0,x,y)
    checksum:+x
   Next
  Case 4
   If scene.Pick(-10,-10) Then checksum:+1
  Case 5
   scene.DispatchPointer(EScenePointerKind.Move,0,0,iteration Mod 512,iteration Mod 512,0,1)
 End Select
End Function

Function LogicBench(count:Int)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Reserve(count+4); scene.ReservePointers(2); scene.Root().AddChild(layer)
 scene.SetInputClip(TSceneRect.Create(-20,-20,552,552))
 Local parent:TSceneNode2D=New TSceneNode2D
 parent.ReserveChildren(count); layer.AddChild(parent)
 Local nodes:TBenchNode[count]
 For Local i:Int=0 Until count
  nodes[i]=New TBenchNode
  nodes[i].SetPosition((i Mod 100)*5,i/100*5)
  nodes[i].SetHitRect(TSceneRect.Create(0,0,4,4)); nodes[i].SetInteractive(True)
  parent.AddChild(nodes[i])
 Next
 Local names:String[]=["update_idle","update_callbacks","parent_move_world_queries","all_nodes_move_world_queries","pick_miss","captured_pointer_move"]
 Local iterations:Int=3000000/count
 For Local mode:Int=0 Until names.Length
  If mode=1 Then
   For Local node:TBenchNode=EachIn nodes
    node.SetProcessing(True)
   Next
  End If
  If mode=5 Then
   parent.SetPosition(0,0); nodes[0].SetPosition(0,0)
   If scene.Pick(1,1)<>nodes[0] Then Throw "Benchmark capture target missing"
   scene.DispatchPointer(EScenePointerKind.Down,0,0,1,1,1,1)
  End If
  If mode=5 Then iterations=100000
  For Local warm:Int=0 Until 20
   LogicStep(mode,warm,scene,parent,nodes)
  Next
  If mode=5 And nodes[0].moves<>20 Then Throw "Benchmark capture was not exercised"
  For Local trial:Int=0 Until 3
   GCCollect()
   Local before:SGCStats,after:SGCStats
   GCGetStats(before)
   Local start:ULong=SDL_GetTicksNS()
   For Local iteration:Int=0 Until iterations
    LogicStep(mode,iteration,scene,parent,nodes)
   Next
   Local elapsed:ULong=SDL_GetTicksNS()-start
   GCGetStats(after)
   Print names[mode]+","+count+","+trial+","+iterations+","+Double(elapsed)/1000/iterations+",0,"+Double(Allocated(after)-Allocated(before))/iterations+","+(Long(after.GCCycleNo)-Long(before.GCCycleNo))+",0,0,0,0,0"
  Next
 Next
 scene.CancelInput(); scene.Destroy()
End Function

Function GraphicsStep(mode:Int,iteration:Int,scene:TScene,parent:TSceneNode2D,nodes:TSpriteNode[],image:TImage,bloom:TSceneBloomStage)
 Select mode
  Case 1
   For Local i:Int=0 Until nodes.Length
    DrawImage(image,(i Mod 100)*5,i/100*5)
   Next
   Return
  Case 3,5
   parent.SetPosition(iteration Mod 2,0)
  Case 4,7
   nodes[0].SetPosition(iteration Mod 2,0)
  Case 6
   bloom.SetIntensity(0.7+(iteration Mod 2)*0.1)
 End Select
 scene.Render()
End Function

Function GraphicsBench(count:Int,image:TImage)
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local target:TRenderImage=CreateRenderImage(512,512,FILTEREDIMAGE)
 SetRenderImage(target); SetVirtualResolution(512,512); SetViewport(0,0,512,512)
 SetClsColor(0,0,0); SetBlend(ALPHABLEND); SetColor(255,255,255); SetAlpha(1)
 Local names:String[]=["render_empty","immediate_sprites","scene_static","scene_parent_move","scene_one_child_move","cached_parent_move","bloom_parameter","bloom_source_move"]
 For Local mode:Int=0 Until names.Length
  Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
  scene.Reserve(count+4); scene.Root().AddChild(layer)
  Local parent:TSceneNode2D
  Local bloom:TSceneBloomStage
  If mode>=5 Then
   Local composite:TCompositeNode=TCompositeNode.Create()
   composite.SetCacheMode(ESceneCacheMode.Automatic)
   composite.SetCaptureRect(TSceneRect.Create(0,0,500,Float((count+99)/100*5)))
   If mode>=6 Then
    bloom=TSceneBloomStage.Create(0.3,4,0.7)
    composite.SetStages([TSceneEffectStage(bloom)])
   End If
   parent=composite
  Else
   parent=New TSceneNode2D
  End If
  layer.AddChild(parent); parent.ReserveChildren(count)
  Local nodes:TSpriteNode[count]
  For Local i:Int=0 Until count
   nodes[i]=TSpriteNode.Create(image); nodes[i].SetPosition((i Mod 100)*5,i/100*5)
   If mode<>0 And mode<>1 Then parent.AddChild(nodes[i])
  Next
  Local stats:TSceneStats=New TSceneStats
  For Local warm:Int=0 Until 12
   Cls; GraphicsStep(mode,warm,scene,parent,nodes,image,bloom); FlushMax2D()
   canvas.context.Read(canvas.context.target,0,0,1,1)
  Next
  For Local trial:Int=0 Until 3
   GCCollect(); ResetMax2DStats()
   Local cpu:ULong,total:ULong,bytes:Long,collections:Long,captures:Long,stages:Long,hits:Long
   Local before:SGCStats,after:SGCStats
   Local frames:Int=60
   For Local frame:Int=0 Until frames
    GCGetStats(before)
    Local start:ULong=SDL_GetTicksNS()
    Cls; GraphicsStep(mode,frame,scene,parent,nodes,image,bloom); FlushMax2D()
    cpu:+SDL_GetTicksNS()-start
    GCGetStats(after)
    bytes:+Allocated(after)-Allocated(before)
    collections:+Long(after.GCCycleNo)-Long(before.GCCycleNo)
    ' Drain outside the submit/allocation interval; readback itself allocates.
    canvas.context.Read(canvas.context.target,0,0,1,1)
    total:+SDL_GetTicksNS()-start
    scene.CopyStats(stats)
    captures:+stats.Captures(); stages:+stats.StagePasses(); hits:+stats.CacheHits()
   Next
   Local gpu:TMax2DStats=CaptureMax2DStats()
   If gpu.textureCreations<>0 Then Throw "Warm benchmark unexpectedly created textures"
   If mode=5 And (captures<>0 Or hits<>frames) Then Throw "Cached movement did not reuse output"
   If mode=6 And (captures<>0 Or stages<>frames) Then Throw "Bloom parameter path did not reuse source"
   If mode=7 And (captures<>frames Or stages<>frames) Then Throw "Bloom source path did not recapture"
   Print names[mode]+","+count+","+trial+","+frames+","+Double(cpu)/1000/frames+","+Double(total)/1000/frames+","+Double(bytes)/frames+","+collections+","+gpu.textureCreations+","+Double(gpu.submissions)/frames+","+Double(captures)/frames+","+Double(stages)/frames+","+Double(hits)/frames
  Next
  If mode=0 Or mode=1 Then
   For Local node:TSpriteNode=EachIn nodes
    node.Destroy()
   Next
  End If
  scene.Destroy()
 Next
 SetRenderImage(Null); target.ReleaseFrames()
End Function

Print "case,nodes,trial,iterations,submit_us,drained_us,managed_bytes_per_op,gc_cycles_in_interval,new_textures,batches_per_frame,captures_per_frame,stages_per_frame,hits_per_frame"
For Local count:Int=EachIn [1000,10000]
 LogicBench(count)
Next
If AppArgs.Length>1 And AppArgs[1]="--logic" Then
 Print "# checksum="+checksum
 End
End If
Graphics(640,480)
?max2d_gl
Print "# backend=OpenGL"
?Not max2d_gl
Print "# backend=SDL3GPU/"+SDLGPUMax2DDriverName()
?
Local pixels:TPixmap=CreatePixmap(4,4,PF_RGBA8888)
pixels.ClearPixels($ffffffff)
Local image:TImage=LoadImage(pixels,0)
For Local count:Int=EachIn [1000,10000]
 GraphicsBench(count,image)
Next
image.ReleaseFrames(); EndGraphics()
Print "# checksum="+checksum
