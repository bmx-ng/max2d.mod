# Textured mesh validation

The textured-mesh foundation adds optional normalized UVs to `TMesh2D`,
`DrawTexturedMesh` for immediate drawing, and optional image/frame selection on
`TMeshNode`. It uses each backend's existing textured-triangle submission path.
It does not add direct mesh lighting or custom shader geometry submission.

`tests/textured_mesh.bmx` checks copied/validated UV data, image parity for atlas
frames under tint/alpha and transformed geometry, image-handle independence,
trimmed sampling, nonrectangular triangle coverage, immediate/scene parity,
explicit UV invalidation, cache reuse and warm texture reuse. Pixel comparisons
allow two channel units for backend rasterization/rounding. The original
`scene_render` suite additionally covers untextured meshes and existing scene
rendering behaviour.

[Results](2026-11-23-textured-mesh.csv) list each completed run. macOS uses arm64
release builds; Windows uses x64 release builds in Windows 11 ARM64/Parallels.
These are functional checks, not performance comparisons. The animated-grid
example also has a three-frame console smoke mode (`--test`).

From the SDK directory:

```sh
bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/textured_mesh mod/max2d.mod/tests/textured_mesh.bmx
/tmp/textured_mesh
```

Use `max2d_gl` for OpenGL, omit the define for SDL renderer, or use
`max2d_d3d9` / `max2d_d3d11` with Windows output paths and `bin/bmk.exe`.
The regression runner registers `textured_mesh` under all five profiles.

See [textured mesh usage](../rendering.md#textured-meshes) for sampling, mutation,
ownership and the runnable example.
