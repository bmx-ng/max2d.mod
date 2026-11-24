# Sixteen-light native groups — 22 November 2026

## Scope

Native grouping now supports up to sixteen eligible lights per receiver on
supported backends. Native D3D9 retains eight: compiling the larger shader
exceeds its temporary-register budget. Other backends fall back to eight if
sixteen-light shader creation fails. Groups of eight or fewer use the smaller
shader, and a single eligible light now includes ambient composition.

Batching remains opt-in. `SetLightBatchLimit(8)` allows applications to compare
the smaller capacity against the default request of sixteen. Changing the limit
releases renderer-owned atlas storage; configure it during setup or profiling,
rather than every frame. Shadow masks remain cached.

The shared atlas remains 2048 × 2048 (16 MiB), with maps up to 512 × 512.
Native parameter transport increases from 64 to 128 vectors. Public image-effect
package limits are unchanged. Selection and parameter arrays remain retained.

## Submission counts

Metal, normal/specular materials and projected patterns, static unshadowed case:

| Lights | Receivers | Eight-light limit | Sixteen-light limit |
| --- | --- | --- | --- |
| 1 | 1 | 1 | 1 |
| 8 | 1 | 1 | 1 |
| 9 | 1 | 2 | 1 |
| 16 | 1 | 2 | 1 |
| 9 | 64 | 64 | 64 |
| 16 | 64 | 88 | 64 |

Counts include ambient composition and exclude shadow preparation and the HUD.
Receiver bounds reject irrelevant lights, which explains why nine lights do not
require a second group in the 64-receiver workload. Sixteen lights reduce that
workload's submissions by 27.3%. Light contributions and shadow rebuild counts
match between capacities across all 60 workloads. Warm texture creations are zero.

## Timing limits

Four full Metal runs used 20 warm-up frames and 60 measured frames per workload,
with capacities ordered 8, 16, 16, 8. Each run covers 60 combinations: 1/4/8/9/16
lights, one/64 receivers, static/moving lights and absent/hard/filtered shadows.
No builds or VM tests ran during these measurements.

For sixteen static lights and 64 receivers, mean CPU draw times were:

| Shadows | Eight, run 1 | Sixteen, run 1 | Sixteen, run 2 | Eight, run 2 |
| --- | --- | --- | --- | --- |
| None | 0.098 ms | 0.097 ms | 0.079 ms | 0.097 ms |
| Hard | 0.103 ms | 0.301 ms | 0.099 ms | 0.103 ms |
| Filtered | 0.133 ms | 0.355 ms | 0.115 ms | 0.130 ms |

These timings do not establish a consistent speedup: the first sixteen-light
run was slower in the shadowed cases. CPU draw timing includes driver backpressure
and is not a GPU timestamp. Presentation is synchronized. The stable result is
the reduction in submissions, not a proportional frame-rate improvement.
Profile both capacities on the intended hardware and workload.

Raw measurements: [eight, run 1](lighting-capacity-metal-8-1.csv),
[sixteen, run 1](lighting-capacity-metal-16-1.csv),
[sixteen, run 2](lighting-capacity-metal-16-2.csv),
[eight, run 2](lighting-capacity-metal-8-2.csv).

## Correctness coverage

The lighting suite checks capacities 1, 8 and 16; counts 0, 1, 4, 8, 9, 16 and
17; ordinary-versus-grouped pixels and alpha; normal/specular materials;
projected patterns; filtered shadows; atlas rollover; warm allocations; and
shadow-mask retention when changing capacity. Shader source and embedded-asset
reproduction also passes for both variants.

| Configuration | Native capacity | Lighting checks |
| --- | ---: | ---: |
| macOS SDL GPU / Metal | 16 | 641 passed |
| macOS native OpenGL | 16 | 641 passed |
| Ubuntu SDL GPU / Vulkan | 16 | 641 passed |
| Ubuntu native OpenGL | 16 | 641 passed |
| Windows native D3D11 | 16 | 641 passed |
| Windows native D3D9 | 8 | 641 passed |

Ubuntu SDL renderer compatibility also passes its six supported-path checks.
Vulkan, D3D11 and D3D9 each completed both capacities across all 60 quick benchmark
workloads, with matching contributions and no warm texture creations. Submissions
never increase at the larger requested limit; D3D9's counts are identical because
both requests use its eight-light capacity. VM timings are validation data, not
hardware performance comparisons.
