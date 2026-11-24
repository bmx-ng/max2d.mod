# Elapsed-GPU profiling smoke test

Release build on macOS arm64, desktop OpenGL, 2026-11-22. Command:

```sh
lighting-gpu-benchmark --quick --grouped --gpu
```

The [raw CSV](lighting-gpu-gl-smoke-2026-11-22.csv) records 60 lighting workloads,
including 1/4/8/9/16 lights, one or 64 receivers, static/moving lights, and
unshadowed/hard/filtered shadows. All 60 rows completed all five requested GPU
samples with zero pending results and zero rejected starts. CPU draw and
presentation timings remain separate columns. This checks timer integration and
sample accounting; five samples are insufficient for performance conclusions.

The timer regression also checks FIFO sample IDs, queue saturation, overlapping
timer rejection, query reuse, active release and release after graphics closure.
The SDL GPU configuration verifies an explicit unsupported result; its 60-case
benchmark also reports zero GPU samples and `unavailable` GPU duration in every
row. These tests do
not establish timer support or performance on Windows, Linux or other GPUs.

Subsequent Windows coverage is recorded separately in the [Direct3D smoke report](lighting-gpu-d3d-smoke-2026-11-22.md).
