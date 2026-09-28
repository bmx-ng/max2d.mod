SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import "gl_timing.c"
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
Import "timing.c"
?
Import Max2D.ScalableFont
Import BRL.StandardIO
Extern "C"
 Function max2d_bench_renderer:Byte Ptr(renderer:Byte Ptr)
 Function max2d_bench_seconds:Double()
End Extern

' Optional arguments: measured frames (default 120), absolute font path.
Global measuredFrames:Int=120
If AppArgs.Length>1 Then measuredFrames=Int(AppArgs[1])
If measuredFrames<10 Then Throw "Use at least 10 measured frames"
Global scalable:TScalableImageFont
If AppArgs.Length>2 Then
 scalable=LoadScalableImageFont(AppArgs[2],18)
 If Not scalable Then Throw "Cannot load font"
End If

Type TWorkload
 Field images:TImage[]
 Field atlas:TTextureAtlas
 Field edit:TPixmap
 Field target:TRenderImage
 Field mode:Int
 Method Setup(which:Int)
  mode=which
  edit=CreatePixmap(16,16,PF_RGBA8888)
  edit.ClearPixels($ffffffff)
  images=New TImage[64]
  atlas=TTextureAtlas.Create(512,DYNAMICIMAGE|FILTEREDIMAGE)
  For Local i:Int=0 Until 64
   If mode=0 Then
    images[i]=TImage.FromPixmap(edit.Copy(),FILTEREDIMAGE)
   Else
    images[i]=atlas.AddPixmap(edit,String(i))
   End If
  Next
  If mode=6 Or mode=7 Then target=CreateRenderImage(256,256,FILTEREDIMAGE)
  If mode=8 Then SetImageFont(scalable)
 End Method
 Method Draw(frame:Int)
  Cls
  Select mode
   Case 0,1
    For Local i:Int=0 Until 4096
     DrawImage(images[i Mod 64],(i*17) Mod 624,(i*13) Mod 464)
    Next
   Case 2,3
    For Local i:Int=0 Until 80
     Local label:String="Label "+i
     If mode=3 Then label:+" frame "+frame
     DrawText(label,(i Mod 8)*80,(i/8)*24)
    Next
   Case 4,5
    edit.ClearPixels($ff000000 | ((frame*127)&$ffffff))
    atlas.UpdatePixmap("0",edit)
    If mode=5 Then atlas.UpdatePixmap("1",edit)
    DrawImage(images[0],0,0); DrawImage(images[1],20,0)
   Case 6,7
    For Local i:Int=0 Until 8
     SetRenderImage(target)
     Cls
     DrawImage(images[i],0,0)
     SetRenderImage(Null)
     If mode=7 Then SetBlend(SOLIDBLEND)
     DrawImage(target,(i Mod 4)*128,(i/4)*128)
     SetBlend(ALPHABLEND)
    Next
   Case 8
    SetVirtualResolution(640.0/Float(1+frame Mod 4),480.0/Float(1+frame Mod 4))
    DrawText("Scalable text AV office 0123456789",0,0)
  End Select
 End Method
End Type

Function RunCase(name:String,mode:Int)
 Local graphics:TGraphics=Graphics(640,480,0,0)
 If Not graphics Then Throw "Cannot create graphics"
?max2d_gl
 Print "# "+name+" renderer="+String.FromUTF8String(max2d_bench_renderer(Null))
?Not max2d_gl
 Print "# "+name+" renderer="+String.FromUTF8String(max2d_bench_renderer(TSDLRenderContext(TMax2DGraphics.Current().context).renderer.rendererPtr))
?
 Local work:TWorkload=New TWorkload
 work.Setup(mode)
 For Local i:Int=0 Until 20
  work.Draw(i); Flip(0)
 Next
 Local times:Double[]=New Double[measuredFrames]
 GCCollect(); FlushMax2D()
 Local heap:Long=Long(GCMemAlloced())
 Local stats:TMax2DStats=Max2DStats()
 Local submissions:Long=stats.submissions,uploads:Long=stats.uploadedPixels,updates:Long=stats.textureUpdates,creations:Long=stats.textureCreations
 Local drawSeconds:Double,flipSeconds:Double
 For Local i:Int=0 Until measuredFrames
  Local start:Double=max2d_bench_seconds()
  work.Draw(i+20); FlushMax2D()
  Local submitted:Double=max2d_bench_seconds()
  Flip(0)
  Local finished:Double=max2d_bench_seconds()
  drawSeconds:+submitted-start; flipSeconds:+finished-submitted
  times[i]=(finished-start)*1000
 Next
 Local submissionDelta:Long=stats.submissions-submissions,uploadDelta:Long=stats.uploadedPixels-uploads
 Local updateDelta:Long=stats.textureUpdates-updates,creationDelta:Long=stats.textureCreations-creations
 GCCollect(); FlushMax2D()
 Local heapDelta:Long=Long(GCMemAlloced())-heap
 times.Sort()
 Print name+","+measuredFrames+","+(drawSeconds*1000/measuredFrames)+","+(flipSeconds*1000/measuredFrames)+","+times[measuredFrames/2]+","+times[Min(measuredFrames-1,Int(Ceil(measuredFrames*0.95))-1)]+","+submissionDelta+","+updateDelta+","+uploadDelta+","+creationDelta+","+heapDelta
 graphics.Close()
 If Not TMax2DGraphics(graphics).context.frames.IsEmpty() Then Throw "Closed context retained native frames"
End Function

' Repeated windows share one source but own independent native resources.
Function ResourceCycles()
 Local image:TImage=CreateImage(32,32)
 Local firstHeap:Long
 For Local cycle:Int=0 Until 12
  Local a:TGraphics=Graphics(160,120,0,0)
  DrawImage(image,0,0); Flip(0)
  Local b:TGraphics=CreateGraphics(160,120,0,0,0,-1,-1)
  SetGraphics(b)
  DrawImage(image,0,0); Flip(0)
  SetGraphics(a); DrawImage(image,0,0); Flip(0)
  a.Close(); b.Close()
  If Not TMax2DGraphics(a).context.frames.IsEmpty() Or Not TMax2DGraphics(b).context.frames.IsEmpty() Then Throw "Native frame registry leaked"
  a=Null; b=Null
  GCCollect()
  Local heap:Long=Long(GCMemAlloced())
  If cycle=0 Then firstHeap=heap
  Print "# resource_cycle="+cycle+" gc_heap_bytes="+heap+" delta_from_first="+(heap-firstHeap)+" closed_context_frames=0"
 Next
 image.ReleaseFrames()
End Function

Try
 Print "case,frames,draw_submit_mean_ms,present_mean_ms,frame_median_ms,frame_p95_ms,submissions,updates,uploaded_pixels,creations,gc_heap_delta_bytes"
 RunCase("sprites_separate",0)
 RunCase("sprites_atlas",1)
 RunCase("text_cached",2)
 RunCase("text_changing",3)
 RunCase("atlas_one_edit",4)
 RunCase("atlas_two_edits",5)
 RunCase("target_alpha",6)
 RunCase("target_solid",7)
 If scalable Then RunCase("text_density_changes",8)
 ResourceCycles()
 Print "# benchmark complete"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
