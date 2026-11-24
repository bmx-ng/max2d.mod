SuperStrict
Rem
bbdoc: Optional asynchronous Direct3D 9 and 11 elapsed-GPU timer provider.
about: Import alongside the matching Max2D rendering backend. Uses timestamp and disjoint queries, a retained queue and nonblocking polling. Unreliable samples are discarded. Release and recreate timers after device reset or loss; no automatic query allocation occurs while measuring.
End Rem
Module Max2D.D3DProfiling
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Profiling
?win32
Import BRL.DXGraphics
Import "queries.cpp"
Private
Global timers:TList=New TList
Global activeTimer:TD3DGpuTimer
Type TD3DGpuTimer Extends TMax2DGpuTimer
 Field context:TMax2DContext
 Field graphics9:TD3D9Graphics,graphics11:TD3D11Graphics,generation:Int
 Field native:Byte Ptr,ids:Long[]
 Field head:Int,tail:Int,count:Int,active:Int,dropped:Long
 Method Check()
  If Not context Then Throw "Max2D Profiling: timer released"
  context.CheckOpen()
  If TMax2DGraphics.Current().context<>context Then Throw "Max2D Profiling: wrong graphics context"
  context.Activate()
  If graphics11 Then
   If graphics11.generation<>generation Or graphics11.DeviceStatus()<0 Then Invalidate()
  End If
 End Method
 Method Invalidate()
  dropped:+count;count=0
  If native Then
   ' Loss/reset invalidates even the active interval. EndSample still closes its logical scope.
   If active Then dropped:+1
   m2d_timer_free(native);native=Null
  End If
 End Method
 Method Begin:Int(sampleId:Long) Override
  Check()
  If activeTimer Then Throw "Max2D Profiling: overlapping GPU sample"
  If Not native Then Throw "Max2D Profiling: device changed; release and recreate timer"
  If count=ids.Length Then Return False
  context.Flush()
  Check()
  If Not native Then Throw "Max2D Profiling: device changed; release and recreate timer"
  If Not m2d_timer_begin(native,tail) Then
   Invalidate()
   Throw "Max2D Profiling: query start failed; release and recreate timer"
  End If
  ids[tail]=sampleId;active=True;activeTimer=Self
  Return True
 End Method
 Method EndSample() Override
  Check()
  If Not active Then Throw "Max2D Profiling: no active sample"
  context.Flush()
  Check()
  If native Then
   If m2d_timer_end(native,tail) Then
    tail=(tail+1) Mod ids.Length;count:+1
   Else
    Invalidate()
   End If
  End If
  active=False;activeTimer=Null
 End Method
 Method Poll:Int(sampleId:Long Var,nanoseconds:Long Var) Override
  Check()
  While count
   Local elapsed:Long
   Local result:Int=m2d_timer_poll(native,head,Varptr elapsed)
   If result=0 Then Return False
   If result=-2 Then
    Invalidate();Return False
   End If
   Local completedId:Long=ids[head]
   head=(head+1) Mod ids.Length;count:-1
   If result=1 Then
    sampleId=completedId;nanoseconds=elapsed;Return True
   End If
   dropped:+1
  Wend
  Return False
 End Method
 Method Pending:Int() Override
  Return count
 End Method
 Method Discarded:Long() Override
  Return dropped
 End Method
 Method Release() Override
  If Not context Then Return
  If Not context.closed Then
   Check()
   If active Then EndSample()
  End If
  If activeTimer=Self Then activeTimer=Null
  m2d_timer_free(native);native=Null
  timers.Remove(Self)
  If graphics9 Then
   Local found:Int
   For Local timer:TD3DGpuTimer=EachIn timers
    If timer.graphics9=graphics9 Then found=True;Exit
   Next
   If Not found Then graphics9.RemoveDeviceLostCallback(DeviceLost)
  End If
  context=Null;graphics9=Null;graphics11=Null;ids=Null;count=0;active=False
 End Method
 Function DeviceLost(obj:Object)
  For Local timer:TD3DGpuTimer=EachIn timers
   If timer.graphics9=obj Then timer.Invalidate()
  Next
 End Function
End Type
Type TD3DGpuTimerProvider Extends TMax2DGpuTimerProvider
 Method CreateTimer:TMax2DGpuTimer(context:TMax2DContext,capacity:Int) Override
  If Not TD3D9Graphics(context.graphics) And Not TD3D11Graphics(context.graphics) Then Return Null
  If activeTimer Then Throw "Max2D Profiling: cannot create during an active GPU sample"
  context.Activate()
  Local timer:TD3DGpuTimer=New TD3DGpuTimer
  timer.context=context
  If TD3D9Graphics(context.graphics) Then
   If TD3D9Graphics(context.graphics).DeviceStatus()<0 Then Return Null
   timer.graphics9=TD3D9Graphics(context.graphics)
   timer.native=m2d_timer_create9(timer.graphics9.GetDirect3DDevice(),capacity)
  Else
   If TD3D11Graphics(context.graphics).DeviceStatus()<0 Then Return Null
   timer.graphics11=TD3D11Graphics(context.graphics)
   timer.generation=timer.graphics11.generation
   timer.native=m2d_timer_create11(timer.graphics11.GetDirect3DDevice(),timer.graphics11.GetDeviceContext(),capacity)
  End If
  If Not timer.native Then Return Null
  timer.ids=New Long[capacity]
  If timer.graphics9 Then
   Local found:Int
   For Local existing:TD3DGpuTimer=EachIn timers
    If existing.graphics9=timer.graphics9 Then found=True;Exit
   Next
   If Not found Then timer.graphics9.AddDeviceLostCallback(TD3DGpuTimer.DeviceLost,timer.graphics9)
  End If
  timers.AddLast(timer)
  Return timer
 End Method
End Type
Extern "C"
 Function m2d_timer_create9:Byte Ptr(device:IDirect3DDevice9,capacity:Int)
 Function m2d_timer_create11:Byte Ptr(device:ID3D11Device,context:ID3D11DeviceContext,capacity:Int)
 Function m2d_timer_free(native:Byte Ptr)
 Function m2d_timer_begin:Int(native:Byte Ptr,index:Int)
 Function m2d_timer_end:Int(native:Byte Ptr,index:Int)
 Function m2d_timer_poll:Int(native:Byte Ptr,index:Int,nanos:Long Ptr)
End Extern
RegisterMax2DGpuTimerProvider(New TD3DGpuTimerProvider)
?
