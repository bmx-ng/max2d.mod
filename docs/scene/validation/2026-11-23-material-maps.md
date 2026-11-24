# Emission and separate specular map validation

Materials can reference emission RGB/alpha artwork and separately authored
specular strength. Emission modulates the existing source-coloured contribution
through a new ABI-3 ambient package. Grouped direct lights remain available, with
mapped ambient submitted separately. Separate specular artwork is packed into
retained normal/gloss storage and uses the existing ordinary and grouped shader
paths. No additional native sampler contract or light-capacity reduction is needed.

`tests/material_maps.bmx` checks both maps on sprites and meshes, ordinary and
grouped lighting, null/default behavior, source coverage, specular precedence over
normal alpha, the viewer-facing default without a normal map, differing-size
emission atlas/trim sampling, target-feedback rejection/recovery, warm texture
reuse, invalid dimensions/frames, pixel edits, storage recreation and scene cache
invalidation. Floating-point target checks verify that mapped emission exceeds
one where supported. Byte comparisons allow three channel units for rounding.

The existing `scene_lighting`, `lighting_mesh` and `lighting_emission` suites
exercise established normal/specular/shadow behavior, grouped geometry and
uniform-emission parity. The package-generator suite checks reproducible source
and embedded assets, including the new emission package. All generator/compiler
utilities remain BlitzMax applications; platform shader compilation uses `glslc`
and `D3DCompile`. The material-map example has a three-frame `--test` mode.

[Completed runs](2026-11-23-material-maps.csv) record release builds: macOS arm64
and Windows x64 under Windows 11 ARM64/Parallels. These are correctness and warm
texture-reuse checks, not throughput or managed-allocation benchmarks.

The packing helper's default RGB was also corrected from `(255,128,128)` to
`(128,128,255)`. The new specular-only test uses normal strength one, so it detects
a sideways default normal. Existing tests used zero XY strength and did not expose
that mistake.

## Reproduce

From the SDK directory:

```sh
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/material_maps mod/max2d.mod/tests/material_maps.bmx
/tmp/material_maps
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/scene_material_maps mod/max2d.mod/examples/scene_material_maps.bmx
/tmp/scene_material_maps --test
```

Use `max2d_gl` for OpenGL, or `max2d_d3d9` / `max2d_d3d11` with Windows paths
and `bin/bmk.exe`. The regression runner registers `material_maps` on all four
shader-capable profiles. SDL renderer does not provide these shaders.

See [material map usage](../../lighting.md#emission-and-separate-specular-maps)
for ownership, pixel invalidation, extra ambient-pass cost and specular CPU packing
constraints. Independent GPU specular samplers, resampling differently sized
normal/specular maps and packing render targets remain outside this implementation.
