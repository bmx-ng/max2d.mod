# State-reuse release validation — 23 November 2026

The state-allocation changes through `e4210ae` pass the selected cross-platform
regression suite and two full local soaks. This tranche adds Direct3D profiles to
four new regression tests; it changes no renderer or public API implementation.

## Platform and lifecycle coverage

| Environment | Backends | Test runs |
| --- | --- | ---: |
| Ubuntu 25.10 arm64 VM, Parallels | SDL GPU, OpenGL | 16 passed |
| Windows 11 VM, x64 builds, Parallels | Direct3D 9, Direct3D 11 | 16 passed |

Each backend ran `effect_capture_state`, `layer_operation_state`,
`effect_processor_state`, `lighting_shadow_state`, `composition_helpers`,
`scene_alpha_masks`, `bloom_pipeline` and `scaled_blur`. Together they cover
state/view restoration, stale handles, outer unwinding, nested captures, context
recreation, injected failures and retry, masks, soft shadows, and native bloom/blur
pixels. The processor test's injected provider is a copy stub; native pixel suites
are separate. VM runs establish functional portability, not native-device speed.

The first Windows launch used the Parallels service session and could not create a
graphics context. All recorded passing Direct3D runs used the logged-in desktop.
The temporary one-off desktop task was removed afterwards.

- [Platform results](2026-11-23-state-release-validation-platforms.csv)

## Long local soaks

On macOS arm64, macOS 27.0.1 (26A434), Metal and OpenGL each completed the full
20 × 3,000-frame combined soak: **60,000 frames per backend**, in addition to
three 120-frame trials of each workload case.

| Measurement | Metal | OpenGL |
| --- | ---: | ---: |
| Managed bytes per combined frame, every block | 224 | 224 |
| Used managed heap after GC, every block | 1,572,864 | 1,585,152 |
| Scene resource charge, every block | 6,088,640 | 6,088,640 |
| Shadow resource charge, every block | 131,072 | 131,072 |
| Light-map resource charge, every block | 16,777,216 | 16,777,216 |
| New textures after warmup | 0 | 0 |

All resource, capture/stage-count and cleanup assertions pass. Post-GC used heap
and retained resource charges are constant across all 20 blocks. These soaks ran
while Windows validation was active and are used for stability, not timing claims.

- [Metal soak CSV](2026-11-23-state-release-validation-sdlgpu-soak.csv)
- [OpenGL soak CSV](2026-11-23-state-release-validation-gl-soak.csv)

## Timing comparison

After VM test work finished, the archived
[material-refresh baseline](2026-11-23-material-refresh.md) executables were
compared with the current capture-state executables on the same host. No detailed
allocation instrumentation was enabled. Each backend ran three alternating pairs:
before/after, after/before, before/after. Each invocation contains three 120-frame
trials per case, giving nine trial averages per version/case. No rendering changes
were made for the comparison. Recorded draw batches, captures, stages, grouped
lighting, shadow rebuilds and resource charges match between versions.

The table reports the median **CPU render-submission interval** in microseconds,
including clear, scene rendering and flush. These are medians of trial averages,
not individual-frame percentile statistics or GPU execution times.

| Backend | Case | Before, µs | After, µs | Change |
| --- | --- | ---: | ---: | ---: |
| Metal | cached | 3.67 | 3.33 | -9.2% |
| Metal | mask_only | 8.63 | 7.80 | -9.6% |
| Metal | lights_only | 108.46 | 101.53 | -6.4% |
| Metal | combined | 104.99 | 99.04 | -5.7% |
| OpenGL | cached | 12.03 | 11.68 | -2.9% |
| OpenGL | mask_only | 84.03 | 79.32 | -5.6% |
| OpenGL | lights_only | 767.54 | 766.19 | -0.2% |
| OpenGL | combined | 786.28 | 762.11 | -3.1% |

Metal's combined CPU interval is consistently lower in this sample: before spans
103.23–108.18 µs, after 98.01–102.00 µs. That is evidence of a modest CPU benefit
for this workload, alongside the established 11,504 → 224 bytes/frame allocation
reduction. OpenGL's combined ranges overlap broadly (753.15–892.49 versus
742.25–867.56 µs), so its 3.1% median difference does not establish a repeatable
improvement.

The broader GPU-drained interval includes update, preparation, picking, rendering
and the final readback wait. Its combined medians fall from 445.77 to 433.24 µs
on Metal and 810.45 to 791.41 µs on OpenGL, but ranges overlap. Cached drained
medians rise slightly. There is **no general frame-rate or GPU-speed claim** from
these short measurements. The VMs remained running but their test jobs were idle;
thermal and desktop scheduling variation were not controlled experimentally.

- [Metal before](2026-11-23-state-release-validation-sdlgpu-before.csv),
  [Metal after](2026-11-23-state-release-validation-sdlgpu-after.csv)
- [OpenGL before](2026-11-23-state-release-validation-gl-before.csv),
  [OpenGL after](2026-11-23-state-release-validation-gl-after.csv)
- [Executable SHA-256 manifest](2026-11-23-state-release-validation-binaries.sha256)

The timing CSVs append `pair` to preserve invocation grouping. The older baseline
has fewer attribution columns; all timing rows are from runs without detailed
instrumentation. Use `scene_workload --trials-only` for timing trials and no options
for the full soak. Build with `-ud max2d_sdlgpu` or `-ud max2d_gl`. Windows test
commands and supported profiles are in the [test guide](../../../tests/README.md#state-reuse-validation-on-windows).

## Assessment

The allocation work has met this validation gate. Remaining 224-byte recapture
bookkeeping preserves independent public handles and entries; cached and mask-only
frames use 32 bytes. Further changes should be justified by an application profile.
A renewed scene/lighting/effects survey is now more useful than continuing to
optimize these small bookkeeping allocations in isolation.
