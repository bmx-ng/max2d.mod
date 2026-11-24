# GPU profiling

`Max2D.Profiling` provides an optional, rendering-thread-only elapsed-GPU timer.
It adds no instrumentation to ordinary rendering. Import a provider and create a
timer after opening Graphics. `TMax2DGpuTimer.Create()` returns `Null` if the
current context has no supported provider.

| Backend | Provider status |
| --- | --- |
| Desktop OpenGL | `Max2D.GLProfiling`; requires `ARB_timer_query` or `EXT_timer_query` and a nonzero elapsed counter. |
| SDL3 GPU (Metal/Vulkan/D3D12) | Unsupported: the bundled SDL GPU API does not expose timestamp queries. |
| Direct3D 9/11 | `Max2D.D3DProfiling`; requires timestamp, frequency and disjoint query support from the device. |
| SDL renderer | No provider implemented. |

The OpenGL implementation is BlitzMax using the existing GLEW bindings. It owns
a fixed ring of native query objects. It never calls `glFinish` or waits for a
query result. Direct3D uses a BlitzMax queue with a native query-call bridge.
`EndSample` flushes the measured drawing and submits the query;
`Poll` checks availability before reading a completed result.

```blitzmax
Import Max2D.GLProfiling ' Alongside the OpenGL rendering backend.

' After Graphics:
Local timer:TMax2DGpuTimer = TMax2DGpuTimer.Create(8)
Local frameId:Long
' Each frame:
Local accepted:Int
If timer Then accepted = timer.Begin(frameId)
Try
    lighting.Prepare()
    scene.Render()
Finally
    If accepted Then timer.EndSample()
End Try

Local sampleId:Long, nanoseconds:Long
If timer Then
    While timer.Poll(sampleId, nanoseconds)
        Print sampleId + ": " + (Double(nanoseconds)/1000000.0) + " ms"
    Wend
End If
frameId :+ 1

' Before EndGraphics:
If timer Then timer.Release()
```

Keep the timer across frames. Poll results several frames later; the sample ID
identifies the frame or section measured. `Begin` returns False when all slots
are occupied and starts no region. Do not call `EndSample` for that rejected
sample. `Pending` counts ended samples awaiting polling. `Poll` returns False
without modifying output variables when no result is ready. It consumes completed
samples in submission order. A zero duration is valid at finite timer precision.

Elapsed regions cannot overlap, even across separate timers on one context.
Do not switch contexts or present inside a region. Release is idempotent and ends
an active region before deleting queries. After context closure, Direct3D releases
its remaining COM references without submitting drawing; OpenGL forgets names
already destroyed with the context. No graphics calls occur from a GC finalizer:
release timers explicitly, preferably before closing Graphics.

## Direct3D reliability and device changes

Import `Max2D.D3DProfiling` alongside either Direct3D backend. The provider does
not choose or change the rendering backend. Use one measured interval per frame
(or less), matching the Direct3D 11 disjoint-query guidance.

`Discarded()` reports the cumulative count of unreliable samples, including
samples invalidated by device changes. `Poll` consumes and skips disjoint results;
it can return False with fewer pending samples and unchanged output variables.
A discarded sample is never reported as zero time. Other providers return zero
when they have no disjoint detection. Explicitly releasing unread samples does
not increase this counter.

A Direct3D 9 reset releases query objects through the existing device-loss
callback, so a timer cannot prevent the reset. Direct3D 11 timers detect device
failure or replacement when used. Both discard outstanding samples and require
`Release` followed by `Create` after recovery; `Begin` on an invalidated timer
throws. `EndSample` can still close an active logical region invalidated by loss.
Recovery deliberately does not allocate replacement query objects inside a
measured frame. Query errors also invalidate the timer.

Direct3D 9 can reset when the presentation mode changes. Select the desired
`Flip` synchronization mode before creating timers, and recreate them after a
reset such as resizing the window. Pending work is submitted once at `EndSample`;
`Poll` does not request a flush or wait.

See Microsoft's [Direct3D 9 queries](https://learn.microsoft.com/en-us/windows/win32/direct3d9/queries)
and [Direct3D 11 query types](https://learn.microsoft.com/en-us/windows/win32/api/d3d11/ne-d3d11-d3d11_query)
for query semantics and disjoint intervals.

## Interpreting the numbers

These are elapsed GPU command intervals, not CPU submission time, presentation
latency or a measure of GPU busy time alone. GPU scheduling and starvation can
influence an interval. Keep regions short to avoid hardware counter overflow;
timer precision is implementation-dependent. Beginning and ending a sample
forces Max2D batch boundaries, so profiling can alter batching and submission
cost. Compare the same workload and instrumentation boundaries.

OpenGL semantics are defined by the
[EXT timer-query specification](https://registry.khronos.org/OpenGL/extensions/EXT/EXT_timer_query.txt).
SDL's query API work can be followed in its
[upstream query discussion](https://github.com/libsdl-org/SDL/issues/11696);
a GPU fence or CPU stopwatch is not a substitute for elapsed GPU timestamps.

## Lighting benchmark

Build `benchmarks/lighting.bmx` with `-ud max2d_gl`, `-ud max2d_d3d9` or
`-ud max2d_d3d11` and run with `--gpu`.
The measured region includes clear, receiver lighting, shadow work and the HUD;
it excludes presentation. GPU warm-up samples are not collected. Added CSV fields
report whether profiling was requested/supported, completed sample count, pending
samples, rejected starts, discarded samples and the mean GPU milliseconds of completed samples.
`unavailable` means no completed GPU measurement, never zero cost.

Polling does not block, including at the end of a workload. Pending samples are
discarded when its timer is released; treat rows with incomplete samples as
incomplete evidence. Do not compare GPU means with different sample coverage.
CPU columns retain their own meaning and include instrumentation in the measured
drawing path. Query polling and timer construction/release are outside those CPU
intervals. `--quick` is a functional smoke test, not a performance conclusion.
