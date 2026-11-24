# Grouped projected patterns — 22 November 2026

## Scope

The native grouped renderer now accepts projected RGBA8888/A8 patterns, including
filtered transparency, image subregions and byte render images. Patterns can
share groups with analytic lights, normal/specular materials and hard or filtered
shadows. Enable it with `SetLightBatching(True)`; it remains optional.

Direct mipmapped, compressed and floating-point patterns retain ordinary
drawing. Resolved maps must be no larger than 512×512. Patterns combined with
shadows use the prepared byte shadow map and its dimensions. The retained
2048×2048 atlas costs 16 MiB per lighting processor using native map groups.

## Work counters

The benchmark's new `--patterns` option projects one shared filtered colour/alpha
image from every point light. These quick runs use three warm-up frames and five
measured frames, with normal/specular receivers. They verify work and cache
behaviour; they are too short to establish a CPU or GPU timing improvement.

For 16 lights and 64 receivers, with only the first light moving:

| Shadows | Ordinary direct passes/frame | Grouped direct passes/frame | Grouped map uploads/frame |
| --- | ---: | ---: | ---: |
| None | 480 | 88 | 0 |
| Hard | 480 | 88 | 1 |
| Filtered | 480 | 88 | 1 |

The applied-light count is unchanged. All 24 grouped workloads create zero
textures during the measured interval. Static workloads upload no maps after
warm-up. Moving a projection without shadows reuses the original pattern pixels;
moving a shadowed light rebuilds and copies only that light's combined map.
Workloads exceeding atlas capacity may require additional copies.

Reproduce with the same backend and display settings:

```sh
lighting-benchmark --quick --normal --patterns > ordinary.csv
lighting-benchmark --quick --normal --patterns --grouped > grouped.csv
```

Omit `--quick` and repeat paired runs when measuring timing on a target machine.
Ambient still uses a separate draw. These pass counts and cache checks were
verified on Metal, Vulkan, Direct3D 9 and Direct3D 11.

## Image and cache coverage

The lighting regression compares grouped and ordinary filtered and nearest
patterns, render-image patterns, subregions, alpha-only maps and patterns with
filtered shadows. It includes hidden colour under zero alpha, translucent
receivers, rotated projections and normal/specular shading. Destination alpha
must match exactly; normalized RGB permits at most five byte levels of rounding
difference in these five-light tests.

Additional checks cover shared uploads, placement-only reuse, explicit pixel
invalidation, warm texture reuse, current-target feedback rejection and ordered
mipmap fallback. Shader reproduction also verifies generated sources and
embedded assets.

Validation passed all **427 lighting checks** on macOS Metal and OpenGL,
Ubuntu Vulkan and OpenGL, and Windows Direct3D 9 and 11. The SDL renderer's
six unsupported-provider checks also passed.
