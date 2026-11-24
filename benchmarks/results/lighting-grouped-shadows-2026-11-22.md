# Grouped shadows — 2026-11-22

The native renderer now applies up to eight point/directional lights with hard
or filtered shadows to flat, normal-mapped or specular receivers in one direct
pass. Shadow maps up to 512×512 share a retained atlas. Enable the path with
`SetLightBatching(True)`; ordinary drawing remains the default and comparison
reference. See [usage and limits](../../docs/lighting.md#grouped-lighting).

## Work counts

Measured on macOS 27.0.1 with SDL3 GPU/Metal. Each case has 20 warmup frames and
60 measured frames. Three sequential ordinary/grouped comparisons use the same
binary with `--normal`; grouped runs also use `--grouped`. No VM build or test
was running during these measurements. The procedural material uses a normal
map, specular strength 0.25 and shininess 16.

For 16 lights, 64 receivers, 256×256 shadow maps and one moving light:

| Per-frame metric | Ordinary | Native grouped |
| --- | ---: | ---: |
| Direct-light contributions | 479.83 | 479.83 |
| Direct-light passes | 479.83 | 87.93 |
| Geometry submissions, hard shadows | 545.83 | 154.93 |
| Geometry submissions, filtered shadows | 547.83 | 156.93 |
| Shadow rebuilds | 1 | 1 |
| Atlas tile copies | 0 | 1 |
| Warm texture creations | 0 | 0 |
| Retained shadow masks, hard / filtered | 4 / 12 MiB | 4 / 12 MiB |
| Additional retained atlas | 0 | 16 MiB |

Direct-light passes fall by **81.7%**. Geometry submissions include mask work,
the additional tile copy and the unlit HUD; they are Max2D counters, not a
promise about backend draw calls. Singleton groups still take the ordinary
path. Static shadow workloads perform zero atlas uploads after warmup. Moving
only the first light causes exactly one mask rebuild and one tile copy per
frame, independently of the receiver count.

## CPU drawing measurements

| Run | Hard ordinary | Hard grouped | Filtered ordinary | Filtered grouped | Raw CSV |
| --- | ---: | ---: | ---: | ---: | --- |
| 1 | 0.250 ms | 0.116 ms | 0.462 ms | 0.578 ms | [baseline](lighting-grouped-shadows-normal-baseline-1-2026-11-22.csv), [grouped](lighting-grouped-shadows-normal-grouped-1-2026-11-22.csv) |
| 2 | 0.615 ms | 0.245 ms | 1.144 ms | 0.491 ms | [baseline](lighting-grouped-shadows-normal-baseline-2-2026-11-22.csv), [grouped](lighting-grouped-shadows-normal-grouped-2-2026-11-22.csv) |
| 3 | 0.690 ms | 0.242 ms | 1.379 ms | 0.729 ms | [baseline](lighting-grouped-shadows-normal-baseline-3-2026-11-22.csv), [grouped](lighting-grouped-shadows-normal-grouped-3-2026-11-22.csv) |

Median drawing means were **0.615 → 0.242 ms** for hard shadows and
**1.144 → 0.578 ms** for filtered shadows. These suggest additional CPU headroom,
but timings varied substantially: the first filtered-shadow comparison was
slower with grouping. Treat these as indicative measurements, not a guaranteed
speedup. The pass and upload reductions were consistent across all three runs.

Total frame means remained near 8.33 ms. The drawing interval includes driver
back-pressure before presentation; it is not GPU execution time. These results
do not establish a frame-rate improvement. Compare modes within these runs;
absolute timings from earlier reports used different desktop conditions.

All 24 cases in each full run preserve contribution counts and create zero warm
textures. The raw files include static/moving lights, one/64 receivers, four/16
lights, and absent/hard/filtered shadows.

## Storage and compatibility

The atlas is allocated on the first eligible shadowed draw and retained by the
renderer session. Its tile records and light parameters are reused. Unchanged
maps do not generate copy geometry. A full page discards tile assignments
between groups, preserving the GPU allocation; workloads beyond page capacity
can incur repeated uploads. `MapUploads()`, `MapCacheHits()` and
`RetainedMapBytes()` expose this behavior alongside the existing shadow stats.

The native shader uses artwork, a normal map and the shared atlas. Each texel
fetch is clamped to its own tile, including bilinear neighbours. Directional
edge clamping and transparent point-map bounds retain their original semantics.
Public image-effect package ABIs and limits are unchanged.

Larger shadow maps, projected patterns and floating-point source artwork retain
ordered compatibility paths. Byte artwork can still produce HDR lighting on
floating-point targets. Ambient remains a separate pass, and flattened `Update`
continues to use ordinary drawing.

Repeated 8-bit blending and grouped sums round differently, particularly with
many dim lights. Tests allow bounded channel differences and require exact
normalized destination alpha. Floating-point comparisons separately verify the
lighting calculation and atlas rollover without that normalized quantization.

## Validation

All **391 lighting checks** pass on macOS Metal/OpenGL, Linux Vulkan/OpenGL and
Windows D3D9/D3D11. SDL renderer capability/rejection checks also pass. Native
shader generation reproduces all six sources and the embedded asset file.

Checks include normal/specular shadow groups, hard/filtered and directional
shadows, mirrored transforms, HDR output, one-mask invalidation, warm reuse,
1024-pixel map fallback, and 24-light atlas capacity rollover. The rollover case
compares both normalized and floating-point images and verifies retained GPU
storage on repeated draws.

All 24 quick benchmark cases complete in ordinary/grouped modes with flat and
normal/specular artwork on Vulkan, D3D9 and D3D11. Contributions match, warm
texture creation is zero, static maps are not uploaded, and moving one light
causes one upload per measured frame. VM timings are used only for functional
validation, not the performance claims above.
