SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import SDL3.SDL3
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
?
Import Max2D.SceneEffects
Import BRL.StandardIO

Extern "C"
 Function SDL_GetTicksNS:ULong()
End Extern

' Time only outermost dependency calls: nested sources must not count twice.
' This deliberately includes clock overhead and excludes the scene registry loop.
Global preparationNS:ULong,preparationDepth:Int,artworkDraws:Long
Type TConsumerArtwork Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext) Override
  artworkDraws:+1
  DrawRect(0,0,256,256)
 End Method
End Type
Type TMeasuredComposite Extends TCompositeNode
 Method PrepareRenderDependencies(epoch:Long) Override
  Local outer:Int=preparationDepth=0,start:ULong
  If outer Then start=SDL_GetTicksNS()
  preparationDepth:+1
  Try
   Super.PrepareRenderDependencies(epoch)
  Finally
   preparationDepth:-1
   If outer Then preparationNS:+SDL_GetTicksNS()-start
  End Try
 End Method
End Type

Function Allocated:Long(stats:SGCStats Var)
 Return Long(stats.allocedBytesBeforeGC)+Long(stats.bytesAllocedSinceGC)
End Function

Function Composite:TMeasuredComposite()
 Local node:TMeasuredComposite=New TMeasuredComposite
 node.SetCacheMode(ESceneCacheMode.Automatic)
 node.SetCaptureRect(TSceneRect.Create(0,0,256,256))
 Return node
End Function

Function Fill:TSpriteNode[](parent:TSceneNode2D,count:Int,image:TImage)
 Local nodes:TSpriteNode[count]
 parent.ReserveChildren(count)
 For Local i:Int=0 Until count
  nodes[i]=TSpriteNode.Create(image)
  nodes[i].SetPosition((i Mod 64)*4,(i/64)*4)
  parent.AddChild(nodes[i])
 Next
 Return nodes
End Function

Function Artwork(parent:TSceneNode2D,image:TImage)
 Local node:TConsumerArtwork=New TConsumerArtwork
 node.SetSelfBounds(TSceneRect.Create(0,0,256,256));parent.AddChild(node)
End Function

Function Edit(mode:Int,frame:Int,parent:TSceneNode2D,nodes:TSpriteNode[],camera:TCamera2D,layer:TLayerNode)
 Select mode
  Case 1
   parent.SetPosition(frame Mod 2,0)
  Case 2
   camera.x=frame Mod 2;layer.SetCamera(camera)
  Case 3
   nodes[0].SetAlpha(0.75+0.25*(frame Mod 2))
  Case 4
   For Local node:TSpriteNode=EachIn nodes
    node.SetAlpha(0.75+0.25*(frame Mod 2))
   Next
 End Select
End Function

Function Measure(kind:String,count:Int,consumers:Int,depth:Int,mode:Int,image:TImage,frames:Int)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Reserve(count+consumers*2+depth*2+8);scene.Root().AddChild(layer)
 Local camera:TCamera2D=New TCamera2D
 layer.SetCamera(camera)
 Local parent:TSceneNode2D,nodes:TSpriteNode[]
 If kind="mask" Then
  Local hidden:TSceneNode2D=New TSceneNode2D
  hidden.SetVisible(False);layer.AddChild(hidden)
  parent=New TSceneNode2D;hidden.AddChild(parent)
  nodes=Fill(parent,count,image)
  Local source:TSceneNode2D=parent
  For Local i:Int=1 Until depth
   Local link:TMeasuredComposite=Composite()
   Artwork(link,image);hidden.AddChild(link)
   link.SetStages([TSceneEffectStage(TSceneSubtreeMaskStage.Create(source))])
   source=link
  Next
  For Local i:Int=0 Until consumers
   Local consumer:TMeasuredComposite=Composite()
   Artwork(consumer,image);layer.AddChild(consumer)
   consumer.SetStages([TSceneEffectStage(TSceneSubtreeMaskStage.Create(source))])
  Next
 Else
  If kind="cached" Then parent=Composite() Else parent=New TSceneNode2D
  layer.AddChild(parent);nodes=Fill(parent,count,image)
 End If
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current(),stats:TSceneStats=New TSceneStats
 For Local frame:Int=0 Until 12
  Edit(mode,frame,parent,nodes,camera,layer);Cls;scene.Render();FlushMax2D()
  canvas.context.Read(canvas.context.target,0,0,1,1)
 Next
 Local retained:Long=scene.RetainedStorageBytes(),warmArtworkDraws:Long=artworkDraws
 For Local trial:Int=0 Until 3
  GCCollect();ResetMax2DStats()
  Local editNS:ULong,submitNS:ULong,prepNS:ULong,drainedNS:ULong,bytes:Long
  Local captures:Long,stages:Long,hits:Long,peak:Long
  Local before:SGCStats,after:SGCStats
  For Local frame:Int=0 Until frames
   preparationNS=0;GCGetStats(before)
   Local start:ULong=SDL_GetTicksNS()
   Edit(mode,frame,parent,nodes,camera,layer)
   Local edited:ULong=SDL_GetTicksNS()
   Cls;scene.Render();FlushMax2D()
   Local submitted:ULong=SDL_GetTicksNS()
   GCGetStats(after)
   editNS:+edited-start;submitNS:+submitted-edited;prepNS:+preparationNS
   bytes:+Allocated(after)-Allocated(before)
   Local sampleX:Int
   If mode=2 Then sampleX=Min(count,64)*4-1
   Local sample:TPixmap=canvas.context.Read(canvas.context.target,sampleX,0,1,1)
   If mode=2 Then
    Local rgb:Int=sample.ReadPixel(0,0) & $ffffff
    If (frame Mod 2=0 And rgb<>$ffffff) Or (frame Mod 2=1 And rgb<>0) Then Throw "Camera movement did not move rendered artwork"
   End If
   drainedNS:+SDL_GetTicksNS()-start
   scene.CopyStats(stats)
   If Not stats.Completed() Then Throw "Incomplete scaling frame"
   captures:+stats.Captures();stages:+stats.StagePasses();hits:+stats.CacheHits()
   peak=Max(peak,stats.PeakStorageBytes())
  Next
  Local gpu:TMax2DStats=CaptureMax2DStats()
  If gpu.textureCreations<>0 Then Throw "Warm scaling trial allocated textures"
  If scene.RetainedStorageBytes()<>retained Then Throw "Warm storage changed"
  If kind="cached" Then
   If mode<3 And captures<>0 Then Throw "Stable cached artwork recaptured"
   If mode>=3 And captures<>frames Then Throw "Edited cached artwork did not recapture"
  End If
  If kind="mask" Then
   If artworkDraws<>warmArtworkDraws Then Throw "Mask edit recaptured consumer artwork"
   If captures<>stages Then Throw "Mask source capture count differs from stage updates"
   If mode=0 And stages<>0 Then Throw "Stable mask updated"
   If mode=3 And stages<>Long(frames)*(consumers+depth-1) Then Throw "Mask dependency edit did not propagate"
  End If
  Local names:String[]=["idle","parent_move","camera_move","leaf_edit","all_edit"]
  Print kind+","+count+","+consumers+","+depth+","+names[mode]+","+trial+","+frames+","+Double(editNS)/1000/frames+","+Double(submitNS)/1000/frames+","+Double(prepNS)/1000/frames+","+Double(drainedNS)/1000/frames+","+Double(bytes)/frames+","+Double(gpu.submissions)/frames+","+Double(captures)/frames+","+Double(stages)/frames+","+Double(hits)/frames+","+retained+","+peak+","+gpu.textureCreations
 Next
 scene.Destroy()
 If scene.RetainedStorageBytes()<>0 Then Throw "Scaling scene leaked resource charges"
End Function

Local frames:Int=40
If AppArgs.Length>1 Then frames=Int(AppArgs[1])
If frames<2 Or frames Mod 2 Then Throw "Frame count must be positive, even and at least two"
Graphics(320,320)
?max2d_gl
Print "# backend=OpenGL"
?Not max2d_gl
Print "# backend=SDL3GPU/"+SDLGPUMax2DDriverName()
?
Local target:TRenderImage=CreateRenderImage(280,280,FILTEREDIMAGE)
SetRenderImage(target);SetVirtualResolution(280,280);SetViewport(0,0,280,280)
SetClsColor(0,0,0);SetBlend(ALPHABLEND);SetColor(255,255,255);SetAlpha(1)
Local pixels:TPixmap=CreatePixmap(4,4,PF_RGBA8888)
pixels.ClearPixels($ffffffff)
Local image:TImage=LoadImage(pixels,0)
Print "kind,nodes,consumers,depth,change,trial,frames,edit_us,submit_us,prepare_us,drained_us,managed_bytes_per_frame,batches_per_frame,captures_per_frame,stages_per_frame,hits_per_frame,retained_bytes,peak_bytes,new_textures"
For Local count:Int=EachIn [16,256,4096]
 For Local kind:String=EachIn ["ordinary","cached"]
  For Local mode:Int=0 Until 5
   Measure(kind,count,0,0,mode,image,frames)
  Next
 Next
 For Local consumers:Int=EachIn [1,4,16]
  Measure("mask",count,consumers,1,0,image,frames)
  Measure("mask",count,consumers,1,3,image,frames)
 Next
Next
For Local depth:Int=EachIn [4,16]
 Measure("mask",256,1,depth,0,image,frames)
 Measure("mask",256,1,depth,3,image,frames)
Next
SetRenderImage(Null);target.ReleaseFrames();image.ReleaseFrames();EndGraphics()
Print "# PASS: warm counters, invalidation, stable storage and cleanup"
