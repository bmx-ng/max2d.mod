# Native light groups — 2026-11-22

The native renderer evaluates up to eight unshadowed point/directional lights
per direct-light pass, with flat, normal-mapped or specular receivers. Enable it
with `SetLightBatching(True)`. Existing paired and ordinary paths handle
unsupported groups. See [eligibility and usage](../../docs/lighting.md#grouped-lighting).

## Normal/specular workload

Measured on macOS 27.0.1 with SDL3 GPU/Metal. Each case uses 20 warmup frames and
60 measured frames. Three sequential ordinary/grouped comparisons use the same
binary and `--normal`; grouped runs add `--grouped`. The workload supplies a
procedural normal map with specular strength 0.25 and shininess 16.

For 16 lights, 64 receivers, no shadows and one moving light:

| Per-frame metric | Ordinary | Native grouped |
| --- | ---: | ---: |
| Direct-light contributions | 479.83 | 479.83 |
| Direct-light passes | 479.83 | 87.93 |
| Max2D geometry submissions | 544.83 | 152.93 |
| Warm texture creations | 0 | 0 |
| Retained shadow storage | 0 | 0 |
| Median of three mean CPU drawing times | 0.622 ms | 0.386 ms |

This reduces direct-light passes by 81.7%, geometry submissions by 71.9%, and
median CPU drawing time by 38.0% in this workload. The absolute CPU saving is
approximately 0.236 ms per frame. Total frame means remain near 8.33 ms, so this
is additional headroom rather than a measured frame-rate improvement.

| Run | Ordinary drawing mean | Grouped drawing mean | Raw CSV |
| --- | ---: | ---: | --- |
| 1 | 0.622 ms | 0.386 ms | [Ordinary](lighting-native-normal-baseline-1-2026-11-22.csv), [grouped](lighting-native-normal-grouped-1-2026-11-22.csv) |
| 2 | 0.679 ms | 0.422 ms | [Ordinary](lighting-native-normal-baseline-2-2026-11-22.csv), [grouped](lighting-native-normal-grouped-2-2026-11-22.csv) |
| 3 | 0.547 ms | 0.349 ms | [Ordinary](lighting-native-normal-baseline-3-2026-11-22.csv), [grouped](lighting-native-normal-grouped-3-2026-11-22.csv) |

These timings include CPU drawing and any driver back-pressure before `Flip(0)`;
they are not GPU timestamps. Geometry submissions are Max2D counters rather than
guaranteed native draw calls. Do not compare absolute timings with earlier runs
under different desktop conditions. Each comparison here uses the same workload
and implementation with grouping enabled or disabled.

All 24 cases in each run create zero textures after warmup. The shadowed
normal/specular cases retain their ordinary pass counts: this tranche does not
combine their shadows. No shadowed-material performance improvement is claimed;
the corresponding raw timings are included in each CSV for comparison.

## Scope and image compatibility

This is a dedicated light-buffer implementation using shared native shader
transport. Public effect-package parameter limits remain unchanged. Receiver
and light descriptions are retained; native queued draws capture their uniform
values. No per-frame selection arrays are created after capacity has stabilized.

The initial native path uses source artwork plus its normal map. Shadow and
projected-pattern groups use the existing fallback paths. Ambient is still a
separate draw. Floating-point source artwork also retains the ordinary path;
byte artwork can produce HDR values on floating-point targets.

Grouped sums round differently from repeated normalized blending. Image checks
allow up to five byte levels for five-light groups, while retaining the existing
three-level tolerance for paired compatibility. Alpha must match exactly. A
floating-point normal/specular comparison separates lighting-calculation
accuracy from normalized blending quantization. Tests also cover transformed,
mirrored and near-singular normal mappings, mixed point/directional lights,
intensities above one, and groups of 0, 1, 2, 8, 9 and 17 lights.

The next rendering step is shared shadow storage so shadowed normal/specular
receivers can use these groups. The current measurements do not predict that
future path's performance.

## Validation

All 344 lighting checks pass on macOS Metal/OpenGL, Linux Vulkan/OpenGL and
Windows D3D9/D3D11. The SDL renderer's six capability/rejection checks also pass.
Both native-lighting and public shader-package reproduction tests pass.

All 24 benchmark workloads complete for flat and normal/specular artwork in
ordinary and grouped modes on Linux Vulkan and Windows D3D9/D3D11, with equal
contribution counts and zero warm texture creations. VM timings are not used
for the performance claims above.

Native shader handles are resolved through the context cache for submission so
D3D11 device recreation cannot leave a session using its earlier cached handle.
