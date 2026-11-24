# Direct3D elapsed-GPU profiling smoke test

Release x64 executables in the Windows 11 Parallels VM, 2026-11-22. Each backend
ran the lighting benchmark with:

```sh
lighting-benchmark --quick --normal --patterns --grouped --gpu
```

Both providers reported support in all 60 workloads. Each workload requested
five samples, covering 1/4/8/9/16 lights, one or 64 receivers, static/moving lights,
and unshadowed/hard/filtered shadows. Normal materials and projected light
textures were enabled. The requested batch limit was 16; D3D9 retains its
existing eight-light shader limit.

| Backend | Requested | Completed | Pending at release | Discarded as unreliable | Rejected starts | Rows with all five completed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| [D3D9 CSV](lighting-gpu-d3d9-smoke-2026-11-22.csv) | 300 | 88 | 211 | 1 | 0 | 16 |
| [D3D11 CSV](lighting-gpu-d3d11-smoke-2026-11-22.csv) | 300 | 78 | 222 | 0 | 0 | 0 |

Every row accounts for all five requested samples. Polling never waits at the end
of a workload: pending samples are released, and rows without a completed sample
report `unavailable`. The D3D9 unreliable sample was omitted from the mean and
included in `gpu_discarded`.

These are integration and accounting checks, **not performance comparisons**.
Five-frame workloads provide incomplete coverage, and a virtual graphics driver's
timestamps should not be treated as measurements of native hardware rendering
cost. In particular, do not compare these GPU means between backends or against
the earlier macOS OpenGL run. Use longer repeated runs on the target hardware,
with matching sample coverage, for performance work.

## Timer regression coverage

Both Direct3D configurations passed the shared timer regression: FIFO IDs among
valid results, nonnegative durations, full-queue rejection, overlapping-region
rejection, retained slot reuse, active release, repeated release and release
after closing Graphics.

Additional lifetime checks passed:

- D3D9 window resizing invalidates pending samples, releases queries before reset,
  and requires timer recreation. Releasing the first of two timers preserves the
  remaining timer's shared device-loss callback.
- D3D11 failure detection injected with `d3d11_recovery_test` triggers real device
  replacement during an active region. Both the older pending sample and the
  active region are counted as discarded. The invalidated timer rejects new
  samples, and a fresh timer can be created afterward.

The shared regression runner enables the D3D11 recovery flag automatically for
this test. Normal application and benchmark builds do not include that flag.
