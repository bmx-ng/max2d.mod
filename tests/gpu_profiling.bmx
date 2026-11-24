SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLProfiling
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3DProfiling
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3DProfiling
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
Import Max2D.Profiling
?
Import BRL.StandardIO
Function Check(value:Int,message:String)
 If Not value Then Throw message
End Function
Try
 Graphics(64,64)
 Flip(1)
 Local timer:TMax2DGpuTimer=TMax2DGpuTimer.Create(2)
 If Not timer Then
  Print "PASS: GPU timer unavailable for this context (explicit unsupported result)"
  EndGraphics();End
 End If
 Check(timer.Discarded()=0,"initial discarded count")
 Local id:Long=-1,elapsed:Long=-1
 Check(Not timer.Poll(id,elapsed) And id=-1 And elapsed=-1,"empty poll preserves outputs")
 Local other:TMax2DGpuTimer=TMax2DGpuTimer.Create(1)
 Check(timer.Begin(10),"begin accepted")
 Local rejected:Int
 Try
  other.Begin(99)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"overlapping timers rejected")
 SetColor(255,0,0);DrawRect(0,0,32,32);timer.EndSample()
 Flip(1)
 Check(timer.Begin(11),"second begin accepted")
 DrawRect(32,32,32,32);timer.EndSample()
 Check(Not timer.Begin(12) And timer.Pending()=2,"full queue preserves pending samples")
 Local received:Int,lastId:Long=9,deadline:Int=MilliSecs()+3000
 While received+timer.Discarded()<2 And MilliSecs()<deadline
  If timer.Poll(id,elapsed) Then
   Print "sample="+id+" gpu_ns="+elapsed
   Check(id>lastId And id<=11 And elapsed>=0,"results retain FIFO IDs and nonnegative GPU times")
   lastId=id
   received:+1
  Else
   Flip(1)
  End If
 Wend
 Check(received+timer.Discarded()=2 And timer.Pending()=0,"queued results complete or are explicitly discarded")
 Print "completed="+received+" discarded="+timer.Discarded()
 Check(timer.Begin(12),"ring slot reused");DrawRect(0,0,16,16);timer.EndSample()
 Flip(1)
 other.Release();Check(timer.Begin(13),"active release sample accepted");DrawRect(0,0,8,8);timer.Release();timer.Release()
?max2d_d3d9
 ' Two timers share one reset callback. Release the first registration, then reset.
 Local first:TMax2DGpuTimer=TMax2DGpuTimer.Create(1)
 Local survivor:TMax2DGpuTimer=TMax2DGpuTimer.Create(1)
 first.Release()
 Check(survivor.Begin(30),"reset sample accepted");DrawRect(0,0,8,8);survivor.EndSample()
 TMax2DGraphics.selected.Resize(80,80)
 id=-1;elapsed=-1
 Check(Not survivor.Poll(id,elapsed) And id=-1 And elapsed=-1,"reset discards pending timing")
 Check(survivor.Discarded()=1 And survivor.Pending()=0,"reset accounting")
 rejected=False
 Try
  survivor.Begin(31)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"reset requires timer recreation")
 survivor.Release()
?max2d_d3d11 And d3d11_recovery_test
 Local lost:TMax2DGpuTimer=TMax2DGpuTimer.Create(2)
 Check(lost.Begin(30),"loss sample accepted");DrawRect(0,0,8,8);lost.EndSample()
 Flip(1)
 Check(lost.Begin(31),"active loss sample accepted")
 D3D11TestRemoved=True
 DrawRect(0,0,8,8);lost.EndSample()
 id=-1;elapsed=-1
 Check(Not lost.Poll(id,elapsed) And id=-1 And elapsed=-1,"replacement discards pending timing")
 Check(lost.Discarded()=2 And lost.Pending()=0,"replacement and active sample accounting")
 rejected=False
 Try
  lost.Begin(32)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"replacement requires timer recreation")
 lost.Release()
?
 Flip(1)
 Local closed:TMax2DGpuTimer=TMax2DGpuTimer.Create()
 Check(closed.Begin(20),"context-close sample accepted");closed.EndSample()
 EndGraphics();closed.Release()
 Print "PASS: GPU profiling"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
