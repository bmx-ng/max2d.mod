# Grouped mesh lighting validation

The native lighting provider now advertises `MeshGeometry` and accepts borrowed
textured triangles. The processor keeps each triangle's UV-to-world basis and
combines eligible lights, including ambient in the first group. Providers whose
capability flag is false never receive mesh requests; unsupported groups retain
the ordinary path. No shader assets or public image-effect ABI layouts changed.

`tests/lighting_mesh.bmx` extends the original mesh checks to 96 checks. It covers
normal/specular materials, emission, tint/alpha, camera transforms, light textures,
shadows, trimmed artwork, unlit bypass, invalid UV rejection, failure recovery,
scene caches and geometry edits. Additional grouped checks compare a deformed
normal-mapped receiver with 1, 8, 9, 16 and 17 lights at requested group limits of
8 and 16. They assert exact group counts, one combined ambient pass per triangle,
matching alpha, warm texture reuse, legacy-provider fallback and borrowed mesh
reference cleanup. The existing 1,050-check lighting suite covers established
sprite and provider behavior.

Two-light comparisons retain their two-channel-unit tolerance. Larger normalized
light groups use the existing sprite test's rounding bound of `lightCount / 2 + 1`
channel units, with exact alpha. Ordinary passes quantize after every light;
grouped passes sum before writing. This allowance covers accumulated storage
rounding rather than geometry or coverage differences.

For the tested two-triangle receiver, submission counts are shown below. Native
counts are asserted by the test; ordinary counts follow one ambient plus one
pass per light for each triangle:

| Intersecting lights | Ordinary | Native limit 8 | Native limit 16 |
| --- | --- | --- | --- |
| 1 | 4 | 2 | 2 |
| 8 | 18 | 2 | 2 |
| 9 | 20 | 4 | 2 |
| 16 | 34 | 4 | 2 |
| 17 | 36 | 6 | 4 |

Native D3D9 uses capacity eight even when the requested limit is sixteen. These
counts assume all lights and the target/material are eligible. Whole-mesh
submission is not implemented; every triangle retains its own affine normal
transform. Counts demonstrate reduced submissions, not a frame-rate measurement.

[Completed runs](2026-11-23-grouped-mesh.csv) use release builds: arm64 on macOS
and x64 on Windows 11 ARM64/Parallels. The example smoke test renders three frames
with batching enabled. To reproduce from the SDK directory:

```sh
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/lighting_mesh mod/max2d.mod/tests/lighting_mesh.bmx
/tmp/lighting_mesh
```

Use `max2d_gl`, or `max2d_d3d9` / `max2d_d3d11` with Windows paths and
`bin/bmk.exe`. See [mesh usage](../../lighting.md#direct-textured-mesh-receivers)
and [provider integration](../../lighting-renderers.md#mesh-geometry-capability).
