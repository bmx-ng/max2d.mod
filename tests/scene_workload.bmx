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
Import Max2D.SceneLighting
Import BRL.StandardIO

Extern "C"
 Function SDL_GetTicksNS:ULong()
End Extern

Function Require(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Allocated:Long(stats:SGCStats Var)
 Return Long(stats.allocedBytesBeforeGC)+Long(stats.bytesAllocedSinceGC)
End Function

Global allocationDetail:Int
Global receiverBytes:Long,bloomBytes:Long,maskBytes:Long,maskPrepareBytes:Long

Type TMeasuredReceiver Extends TLitSpriteNode
 Method OnDraw(context:TSceneDrawContext) Override
  If Not allocationDetail Then Super.OnDraw(context);Return
  Local before:SGCStats,after:SGCStats
  GCGetStats(before);Super.OnDraw(context);GCGetStats(after)
  receiverBytes:+Allocated(after)-Allocated(before)
 End Method
End Type
Type TMeasuredBloom Extends TSceneBloomStage
 Method Update:TRenderImage(source:TRenderImage) Override
  If Not allocationDetail Then Return Super.Update(source)
  Local before:SGCStats,after:SGCStats
  GCGetStats(before)
  Local result:TRenderImage=Super.Update(source)
  GCGetStats(after);bloomBytes:+Allocated(after)-Allocated(before)
  Return result
 End Method
End Type
Type TMeasuredMask Extends TSceneAlphaMaskStage
 Method Prepare(layout:TSceneStageLayout) Override
  If Not allocationDetail Then Super.Prepare(layout);Return
  Local before:SGCStats,after:SGCStats
  GCGetStats(before);Super.Prepare(layout);GCGetStats(after)
  maskPrepareBytes:+Allocated(after)-Allocated(before)
 End Method
 Method Update:TRenderImage(source:TRenderImage) Override
  If Not allocationDetail Then Return Super.Update(source)
  Local before:SGCStats,after:SGCStats
  GCGetStats(before)
  Local result:TRenderImage=Super.Update(source)
  GCGetStats(after);maskBytes:+Allocated(after)-Allocated(before)
  Return result
 End Method
End Type

Type TWorkload
 Field scene:TScene=TScene.Create()
 Field world:TLayerNode=TLayerNode.Create(),hud:TLayerNode=TLayerNode.Create()
 Field background:TCompositeNode=TCompositeNode.Create(),group:TCompositeNode=TCompositeNode.Create()
 Field lighting:TSceneLighting
 Field lights:TPointLightNode[8]
 Field sprites:TLitSpriteNode[128]
 Field mask:TSceneAlphaMaskStage
 Field maskRect:TSceneRect=TSceneRect.Create(0,0,512,320)
 Field camera:TCamera2D=New TCamera2D
 Field images:TImage[4]
 Field target:TRenderImage
 Field stats:TSceneStats=New TSceneStats
 Field lightStats:TMax2DLightingStats=New TMax2DLightingStats
 Field tick:Int
 Field retained:Long=-1,shadowRetained:Long=-1,mapRetained:Long=-1

 Method Initialize()
  scene.Reserve(1400);scene.SetInputClip(TSceneRect.Create(0,0,640,480))
  scene.Root().AddChild(world);scene.Root().AddChild(hud)
  target=CreateRenderImage(640,480,0)
  Local pix:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
  pix.ClearPixels($ff7f9fbf);images[0]=LoadImage(pix,0)
  pix.ClearPixels($ff253140);images[1]=LoadImage(pix,0)
  For Local y:Int=0 Until 16
   For Local x:Int=0 Until 16
    pix.WritePixel(x,y,$ff000000 | ((96+x*4) Shl 16) | ((96+y*4) Shl 8) | 240)
   Next
  Next
  images[2]=LoadImage(pix,FILTEREDIMAGE)
  For Local y:Int=0 Until 16
   For Local x:Int=0 Until 16
    Local alpha:Int=Int(Max(0.0,Min(1.0,(8-Sqr((x-7.5)*(x-7.5)+(y-7.5)*(y-7.5)))/2))*255)
    pix.WritePixel(x,y,(alpha Shl 24) | $ffffff)
   Next
  Next
  images[3]=LoadImage(pix,FILTEREDIMAGE)
  mask=New TMeasuredMask;mask.SetMask(images[3],maskRect);mask.SetInputMask(pix,64)
  background.SetCaptureRect(TSceneRect.Create(0,0,640,400));background.SetCacheMode(ESceneCacheMode.Automatic)
  world.AddChild(background)
  For Local i:Int=0 Until 1000
   Local tile:TSpriteNode=TSpriteNode.Create(images[1])
   tile.SetPosition((i Mod 40)*16,(i/40)*16);background.AddChild(tile)
  Next
  lighting=TSceneLighting.Create(world);lighting.SetAmbient(160,180,220,0.2)
  lighting.SetLightBatching(True);lighting.SetSpatialSelection(True)
  Local registered:TLightNode2D[8]
  For Local i:Int=0 Until 8
   lights[i]=TPointLightNode.Create(220);lights[i].SetPosition(48+(i Mod 4)*145,90+(i/4)*180)
   lights[i].SetColor(120+(i Mod 3)*60,160,240-(i Mod 3)*60);lights[i].SetIntensity(1.4)
   If i<2 Then lights[i].SetShadows(True,128)
   world.AddChild(lights[i]);registered[i]=lights[i]
  Next
  lighting.SetLights(registered)
  Local casters:TLightOccluderNode[4]
  For Local i:Int=0 Until 4
   casters[i]=TLightOccluderNode.Create([0.0,0.0,12.0,0.0,12.0,60.0,0.0,60.0])
   casters[i].SetPosition(100+i*120,150);world.AddChild(casters[i])
  Next
  lighting.SetOccluders(casters)
  group.SetPosition(32,48);group.SetClipRect(TSceneRect.Create(0,0,512,320))
  group.SetCacheMode(ESceneCacheMode.Automatic)
  Local bloom:TMeasuredBloom=New TMeasuredBloom
  bloom.SetThreshold(0.3);bloom.SetRadius(4);bloom.SetIntensity(0.5)
  group.SetStages([TSceneEffectStage(bloom),TSceneEffectStage(mask)])
  world.AddChild(group)
  Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
  material.SetNormalMap(images[2]);material.SetSpecular(0.3,16)
  For Local i:Int=0 Until sprites.Length
   sprites[i]=New TMeasuredReceiver
   sprites[i].InitializeLighting(lighting,material);sprites[i].SetImage(images[0])
   sprites[i].SetPosition((i Mod 16)*32,(i/16)*38);sprites[i].SetInteractive(True)
   group.AddChild(sprites[i])
  Next
  For Local i:Int=0 Until 8
   Local label:TTextNode=TTextNode.Create("STATUS READY",GetImageFont())
   label.SetPosition(12+(i Mod 4)*155,420+(i/4)*24);hud.AddChild(label)
  Next
 End Method

 Method Edit(mode:Int)
  tick:+1
  Local t:Float=tick*0.017
  If mode=1 Or mode=3 Then
   maskRect.x=Float(Sin(t*55)*24);mask.SetMaskRect(maskRect)
  End If
  If mode=2 Or mode=3 Then
   For Local i:Int=0 Until lights.Length
    lights[i].SetPosition(48+(i Mod 4)*145+Float(Sin(t*40+i*45)*24),90+(i/4)*180+Float(Cos(t*35+i*30)*18))
   Next
  End If
  If mode=3 Then
   For Local i:Int=0 Until 16
    sprites[i].SetPosition(i*32,Float(Sin(t*70+i*20)*6))
   Next
   camera.x=Float(Sin(t*12)*8);world.SetCamera(camera)
  End If
  scene.Update(1.0/60)
 End Method

 Method Frame(mode:Int)
  Edit(mode);lighting.Prepare();scene.Pick(296,208)
  Cls;scene.Render();FlushMax2D()
 End Method

 Method Measure(phase:String,name:String,mode:Int,block:Int,frames:Int)
  If phase="trial" Then
   For Local warm:Int=0 Until 30
    Frame(mode)
   Next
  End If
  If mode=0 Then Require(scene.Pick(296,208)<>Null,"masked picking did not reach a receiver")
  Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
  canvas.context.Read(canvas.context.target,0,0,1,1)
  GCCollect();ResetMax2DStats();lighting.ResetStats()
  Local before:SGCStats,after:SGCStats,heap:SGCStats,afterEdit:SGCStats,afterPrepare:SGCStats,afterPick:SGCStats
  Local updateTime:ULong,prepareTime:ULong,pickTime:ULong,renderTime:ULong
  Local updateBytes:Long,prepareBytes:Long,pickBytes:Long,renderBytes:Long
  Local bytes:Long,cycles:Long,captures:Long,stages:Long,hits:Long
  receiverBytes=0;bloomBytes=0;maskBytes=0;maskPrepareBytes=0
  Local intervalStart:ULong=SDL_GetTicksNS()
  For Local frame:Int=0 Until frames
   GCGetStats(before)
   Local start:ULong=SDL_GetTicksNS()
   Edit(mode)
   Local edited:ULong=SDL_GetTicksNS()
   GCGetStats(afterEdit)
   Local prepareStart:ULong=SDL_GetTicksNS()
   lighting.Prepare()
   Local prepared:ULong=SDL_GetTicksNS()
   GCGetStats(afterPrepare)
   Local pickStart:ULong=SDL_GetTicksNS()
   scene.Pick(296,208)
   Local picked:ULong=SDL_GetTicksNS()
   GCGetStats(afterPick)
   Local renderStart:ULong=SDL_GetTicksNS()
   Cls;scene.Render();FlushMax2D()
   Local rendered:ULong=SDL_GetTicksNS()
   GCGetStats(after)
   updateTime:+edited-start;prepareTime:+prepared-prepareStart;pickTime:+picked-pickStart;renderTime:+rendered-renderStart
   updateBytes:+Allocated(afterEdit)-Allocated(before);prepareBytes:+Allocated(afterPrepare)-Allocated(afterEdit)
   pickBytes:+Allocated(afterPick)-Allocated(afterPrepare);renderBytes:+Allocated(after)-Allocated(afterPick)
   bytes:+Allocated(after)-Allocated(before);cycles:+Long(after.GCCycleNo)-Long(before.GCCycleNo)
   scene.CopyStats(stats);captures:+stats.Captures();stages:+stats.StagePasses();hits:+stats.CacheHits()
  Next
  canvas.context.Read(canvas.context.target,0,0,1,1)
  Local drained:ULong=SDL_GetTicksNS()-intervalStart
  Local gpu:TMax2DStats=CaptureMax2DStats()
  lighting.CopyStats(lightStats)
  Require(gpu.textureCreations=0,"warm workload created textures")
  If mode=0 Then Require(captures=0 And stages=0 And hits=frames*2,"cached workload did not reuse both composites")
  If mode=1 Then Require(captures=0 And stages=frames,"mask edits did not reuse source")
  If mode>=2 Then
   Require(captures=frames And stages=frames*2,"lighting/combined path did not recapture exactly one group")
   Require(lightStats.GroupedPasses()>0 And lightStats.ShadowRebuilds()>0,"grouped lights/shadows not exercised")
  End If
  Local sceneBytes:Long=scene.RetainedStorageBytes(),shadowBytes:Long=lightStats.RetainedShadowBytes(),mapBytes:Long=lightStats.RetainedMapBytes()
  If retained<0 Then retained=sceneBytes;shadowRetained=shadowBytes;mapRetained=mapBytes
  Require(sceneBytes=retained And shadowBytes=shadowRetained And mapBytes=mapRetained,"retained GPU storage changed after warmup")
  Require(updateBytes+prepareBytes+pickBytes+renderBytes=bytes,"allocation phases do not sum to total")
  If allocationDetail Then Require(receiverBytes+bloomBytes+maskBytes+maskPrepareBytes<=renderBytes,"render attribution overlaps")
  GCCollect();GCGetStats(heap)
  Print phase+","+name+","+block+","+frames+","+Double(updateTime)/1000/frames+","+Double(prepareTime)/1000/frames+","+Double(pickTime)/1000/frames+","+Double(renderTime)/1000/frames+","+Double(drained)/1000/frames+","+Double(bytes)/frames+","+cycles+","+gpu.textureCreations+","+gpu.textureUpdates+","+Double(gpu.submissions)/frames+","+Double(captures)/frames+","+Double(stages)/frames+","+Double(hits)/frames+","+Double(lightStats.GroupedPasses())/frames+","+Double(lightStats.ShadowRebuilds())/frames+","+sceneBytes+","+shadowBytes+","+mapBytes+","+Long(heap.heapsize)+","+(Long(heap.heapsize)-Long(heap.freeBytes))+","+Double(updateBytes)/frames+","+Double(prepareBytes)/frames+","+Double(pickBytes)/frames+","+Double(renderBytes)/frames+","+allocationDetail+","+Double(receiverBytes)/frames+","+Double(bloomBytes)/frames+","+Double(maskBytes)/frames+","+Double(renderBytes-receiverBytes-bloomBytes-maskBytes-maskPrepareBytes)/frames+","+Double(maskPrepareBytes)/frames
 End Method

 Method Release()
  scene.Destroy();lighting.ReleaseResources()
  Require(scene.RetainedStorageBytes()=0,"scene cleanup left charged storage")
  lighting.CopyStats(lightStats)
  Require(lightStats.RetainedShadowBytes()=0 And lightStats.RetainedMapBytes()=0,"lighting cleanup left retained storage")
  SetRenderImage(Null);target.ReleaseFrames()
  For Local image:TImage=EachIn images
   image.ReleaseFrames()
  Next
 End Method
End Type

Try
 Local quick:Int,trialsOnly:Int
 For Local arg:String=EachIn AppArgs
  If arg="--quick" Then quick=True
  If arg="--trials-only" Then trialsOnly=True
  If arg="--allocation-detail" Then allocationDetail=True
 Next
 Local frames:Int=120,trials:Int=3,blocks:Int=20,soakFrames:Int=3000
 If quick Then frames=5;trials=1;blocks=2;soakFrames=5
 If trialsOnly Then blocks=0
 Graphics(640,480)
?max2d_gl
 Print "# backend=OpenGL"
?Not max2d_gl
 Print "# backend=SDL3GPU/"+SDLGPUMax2DDriverName()
?
 Print "# sprites=1000 background + 128 lit; lights=8; shadow lights=2; casters=4; HUD labels=8; target=640x480"
 Print "phase,case,block,frames,update_us,prepare_us,pick_us,render_submit_us,drained_us,managed_bytes_per_frame,gc_cycles,new_textures,texture_updates,batches_per_frame,captures_per_frame,stages_per_frame,hits_per_frame,groups_per_frame,shadow_rebuilds_per_frame,scene_bytes,shadow_bytes,map_bytes,heap_bytes,used_heap_after_gc,update_bytes_per_frame,prepare_bytes_per_frame,pick_bytes_per_frame,render_bytes_per_frame,allocation_detail,receiver_bytes_per_frame,bloom_bytes_per_frame,mask_bytes_per_frame,other_render_bytes_per_frame,mask_prepare_bytes_per_frame"
 Local workload:TWorkload=New TWorkload
 workload.Initialize()
 SetRenderImage(workload.target);SetVirtualResolution(640,480);SetViewport(0,0,640,480);SetClsColor(10,15,24)
 Local names:String[]=["cached","mask_only","lights_only","combined"]
 For Local mode:Int=0 Until 4
  For Local trial:Int=0 Until trials
   workload.Measure("trial",names[mode],mode,trial,frames)
  Next
 Next
 For Local block:Int=0 Until blocks
  workload.Measure("soak","combined",3,block,soakFrames)
 Next
 workload.Release();EndGraphics()
 Print "# PASS: combined workload invariants and cleanup"
Catch error:Object
 Print "# FAIL: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
