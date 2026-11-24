SuperStrict
Rem
bbdoc: Optional asynchronous elapsed-GPU profiling contract.
about: Import a backend provider, then create a timer after Graphics. Unsupported contexts return Null. Results measure an elapsed command interval, not CPU time, presentation latency or pure GPU busy time. Timers are explicitly owned, rendering-thread-only resources; release before closing Graphics. No implicit instrumentation is added to normal rendering.
End Rem
Module Max2D.Profiling
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Core

Rem
bbdoc: Retained queue of asynchronous elapsed-GPU samples for one graphics context.
about: Begin and End bracket flushed Max2D drawing. Regions cannot overlap, even across timers in one context. Poll completed samples in submission order. Do not change graphics contexts or present inside a region. Use Try/Finally to End an accepted region and Release the timer. No method waits for a result; a full queue rejects Begin until samples are polled.
End Rem
Type TMax2DGpuTimer Abstract
 Rem
 bbdoc: Creates a context-owned timer with the requested queue capacity, or Null when unsupported.
 about: Requires current Max2D Graphics. Capacity must be 1..4096. Creation allocates CPU/native query storage; warm Begin, End and Poll reuse it. Backend providers are optional imports.
 End Rem
 Function Create:TMax2DGpuTimer(capacity:Int=8)
  If capacity<1 Or capacity>4096 Then Throw "Max2D Profiling: capacity must be 1..4096"
  Local context:TMax2DContext=TMax2DGraphics.Current().context
  context.CheckOpen()
  For Local provider:TMax2DGpuTimerProvider=EachIn providers
   Local timer:TMax2DGpuTimer=provider.CreateTimer(context,capacity)
   If timer Then Return timer
  Next
  Return Null
 End Function
 Rem
 bbdoc: Starts a sample carrying an application ID; returns False when the queue is full.
 about: A False result starts no region and must not be followed by End. Nested or overlapping regions throw. ID values need not be unique.
 End Rem
 Method Begin:Int(sampleId:Long) Abstract
 Rem
 bbdoc: Flushes Max2D drawing and ends the active sample without waiting for completion.
 End Rem
 Method EndSample() Abstract
 Rem
 bbdoc: Returns the oldest completed sample in nanoseconds, or False if none is ready.
 about: False preserves both output variables. A zero duration is valid because clock precision varies. Read results several frames later and keep regions short to avoid native timer overflow.
 End Rem
 Method Poll:Int(sampleId:Long Var,nanoseconds:Long Var) Abstract
 Rem
 bbdoc: Returns submitted samples awaiting polling; excludes an active unfinished region.
 End Rem
 Method Pending:Int() Abstract
 Rem
 bbdoc: Returns the cumulative number of samples discarded because their timing was unreliable or the device changed.
 about: Poll skips invalid samples without modifying outputs for them. Deliberately releasing pending samples is not counted. Providers without disjoint detection return zero.
 End Rem
 Method Discarded:Long()
  Return 0
 End Method
 Rem
 bbdoc: Releases queries and discards pending results; repeated calls are harmless.
 about: An active region is ended before release. After context closure, provider-owned native references are released without submitting drawing. No GL/GPU calls occur from a finalizer.
 End Rem
 Method Release() Abstract
End Type

Rem
bbdoc: Backend registration contract for optional GPU timers.
End Rem
Type TMax2DGpuTimerProvider Abstract
 Rem
 bbdoc: Creates a timer for a supported context, otherwise returns Null.
 End Rem
 Method CreateTimer:TMax2DGpuTimer(context:TMax2DContext,capacity:Int) Abstract
End Type
Private
Global providers:TList=New TList
Public
Rem
bbdoc: Registers an immutable backend provider once during module initialization.
End Rem
Function RegisterMax2DGpuTimerProvider(provider:TMax2DGpuTimerProvider)
 If Not provider Then Throw "Max2D Profiling: provider is null"
 For Local registered:TMax2DGpuTimerProvider=EachIn providers
  If registered=provider Then Return
 Next
 providers.AddLast(provider)
End Function
