# Paired point-light prototype — 2026-11-22

The opt-in `SetLightBatching(True)` path combines two eligible flat point lights
per direct-light pass. Normal/specular materials, directional lights, projected
patterns and other unsupported cases continue to use the ordinary path. See
[lighting eligibility and usage](../../docs/lighting.md#grouped-lighting).

## Metal comparison

Captured on macOS 27.0.1, SDL3 GPU/Metal, with the same lighting workload as the
[independent-shadow results](lighting-independent-shadows-2026-11-22.md).
Each run uses 20 warmup frames and 60 measured frames per case. Three sequential
baseline/paired comparisons cover all 24 workload cases. These are exploratory
CPU measurements, not GPU timestamps or a statistical performance guarantee.

For 16 lights, 16 casters, 64 receivers, filtered shadows and one moving light:

| Per-frame metric | Ordinary | Paired |
| --- | ---: | ---: |
| Direct-light passes | 479.83 | 247.93 |
| Max2D geometry submissions | 547.83 | 315.93 |
| Shadow rebuilds | 1 | 1 |
| Caster tests | 16 | 16 |
| Blur passes | 2 | 2 |
| Warm texture creations | 0 | 0 |
| Retained shadow textures | 12 MiB | 12 MiB |
| Median of three mean CPU drawing times | 1.205 ms | 0.979 ms |

Direct-light passes decrease by 48.3%; geometry submissions decrease by 42.3%.
The median CPU drawing time decreases by 18.8%. Each paired run improved this
case's drawing time, by approximately 16–19%. Total CPU frame means remain near
8.3 ms: presentation pacing absorbs the saved time. This establishes reduced
work and CPU headroom, not a measured frame-rate increase.

| Run | Ordinary drawing mean | Paired drawing mean | Raw CSV |
| --- | ---: | ---: | --- |
| 1 | 1.212 ms | 0.979 ms | [Ordinary](lighting-metal-baseline-1-2026-11-22.csv), [paired](lighting-metal-paired-1-2026-11-22.csv) |
| 2 | 1.205 ms | 1.011 ms | [Ordinary](lighting-metal-baseline-2-2026-11-22.csv), [paired](lighting-metal-paired-2-2026-11-22.csv) |
| 3 | 1.070 ms | 0.862 ms | [Ordinary](lighting-metal-baseline-3-2026-11-22.csv), [paired](lighting-metal-paired-3-2026-11-22.csv) |

Drawing time includes light movement, scene drawing, HUD work and any driver
back-pressure before `Flip(0)`. Geometry submissions are Max2D counters, not
guaranteed native GPU draw calls. All 24 cases in each Metal run created zero
textures after warmup. Shadow work and retained texture storage match between
ordinary and paired runs.

## Other backends

A single macOS OpenGL comparison showed the same work-count reductions, but
CPU drawing time increased from 2.556 to 3.100 ms in the largest moving case.
Total frame time decreased from 8.314 to 5.315 ms, with a large change in time
spent presenting. This split is sensitive to driver back-pressure and pacing;
one run does not establish a dependable speedup on this backend.
[Ordinary CSV](lighting-opengl-baseline-2026-11-22.csv),
[paired CSV](lighting-opengl-paired-2026-11-22.csv).

## Scope

Pairing uses the existing three-texture shader ABI: artwork plus two independent
shadow masks. It needs no shadow atlas. A retained selection array avoids
per-frame selection objects; this is not a measurement of all process allocations.

Ordinary targets preserve per-light clamping and destination alpha. Floating-point
targets preserve HDR range. Separate normalized blending can differ by a few
rounding units. The image regressions compare transformed, translucent, hard/soft
shadowed and shadow-bypassing receivers, odd light counts, fallback materials,
additive render-image artwork and HDR output where supported.

The option remains disabled by default. The next useful investigation is larger
light groups and advanced-material support, guided by backend-specific timings.
Fewer passes alone do not guarantee faster drawing on every driver.

## Validation

The lighting regression suite passes all 254 checks on macOS Metal/OpenGL,
Linux Vulkan/OpenGL, and Windows D3D9/D3D11. The SDL renderer's six capability
and rejection checks also pass. Shader package generation reproduces all
checked-in sources and embedded assets, including the new paired package.

All 24 quick benchmark cases complete in ordinary and paired modes on Linux
Vulkan and Windows D3D9/D3D11, with zero warm texture creations. Both Windows
backends also pass the light-lab smoke test. VM timings are not used for the
performance claims above.
