# Tilemap and Tiled maintainer checks

For application usage, start with [Using Tiled maps](../docs/tiled.md) or
[Native tilemaps](../docs/tilemaps.md). This page covers regression checks and
extending the importer.

## Run the relevant suites

Run from the BlitzMax installation directory. `core` tests do not open a graphics
window; `software` uses SDL's dummy video driver and software renderer.

```sh
python3 mod/max2d.mod/tests/run_regressions.py core --debug \
  --test tilemap --test tile_objects --test tiled --test tiled_json \
  --test tiled_templates --test tiled_project \
  --test tiled_zstd --test tiled_zstd_enabled

python3 mod/max2d.mod/tests/run_regressions.py software --debug \
  --test tilemap_render --test tiled_render --test tile_transform_render \
  --test tiled_sizing_text
```

Use `gl`, `sdl`, `d3d9` or `d3d11` instead of `software` to check a real backend
on a supported platform. Omit `--debug` for a release build. The runner reports
the temporary directory containing binaries, build logs, run logs and results.
Graphics tests require a working desktop session.

| Tests | Coverage |
| --- | --- |
| `tilemap`, `tilemap_render` | Grid geometry, negative coordinates, sparse storage, properties, regions, picking and drawing order |
| `tile_objects`, `tiled_render` | Object geometry, tile collisions, layers, tint, parallax, imported artwork and templates |
| `tile_transform_render` | Rectangular/hex transformations, non-square and trimmed artwork, culling and sorting |
| `tiled`, `tiled_json` | Encodings, relative resources, streams, embedded assets, ZIP mounts and malformed input |
| `tiled_templates`, `tiled_project` | Overrides, independent instances, class defaults, enums and schema type recovery |
| `tiled_sizing_text` | Display sizing, fitted collisions, animation, text layout reuse and rotated clipping |
| `tiled_zstd`, `tiled_zstd_enabled` | Missing-provider errors and bounded zstd decoding, including malformed data |

The two zstd tests deliberately use different imports. Keep the missing-provider
case separate so an accidental dependency cannot make it pass for the wrong reason.
On macOS, symbol inspection with `nm` can also confirm that a base Tiled test binary
contains no `ZSTD_` symbols.

## Visual checks

Use the [upstream example viewer](../tiled.mod/examples/README.md) for map-level
checks. Keep upstream maps unmodified and preserve their attribution files.
Add small original fixtures under `data/tiled` for targeted regressions.

The viewers and native comparison examples accept `--test` to exit after three
frames and `--screenshot=/absolute/path.png` to save a capture. On macOS, build
with `-t console` when passing arguments; the GUI app stub does not forward them.
Supply absolute asset paths when placing the executable in a temporary directory.
The upstream viewer also needs `--project=/absolute/path/examples.tiled-project`
or `--project=` when relocated.

VM results establish coverage for the tested virtual drivers, not every physical
GPU. Exact pixel tests use deterministic bitmap glyphs; visually inspect scalable
fonts separately when changing text drawing.

## Add a compression provider

Create an optional module importing `Max2D.Tiled` and its codec dependency. Extend
`TTiledDecompressor`, implement `CanDecode(compression)` and
`Decode(source:Byte[], destination:Byte[])`, and instantiate the provider in a
module-level global. Construction registers it. See
[Max2D.TiledZstd](../tiledzstd.mod/tiledzstd.bmx) for a small example.

The importer supplies an output buffer of exactly `cellCount * 4` bytes.
`Decode` must consume all input, fill that buffer exactly, and return False for
corrupt input or a size mismatch. Do not resize either array or allocate output
based on an untrusted frame header. The newest matching provider wins; decoder
failure is an error, not a request to try another provider. Registration is not
synchronized: do it during module initialization, before loading maps.

The built-in zlib/gzip providers use the same interface. `Archive.Zstd` currently
also imports `Archive.Core`; changes to that dependency belong in the archive
modules rather than duplicating codec sources here.

## LDtk

Run `core --test ldtk` for project selection, external levels, fields, IntGrid,
streams/ZIP mounts and malformed input. Run `software --test ldtk_render` for
stacking, opacity, flips, layer-specific picking and render-target transforms.
The render test supports the same GL/D3D9/D3D11 profiles as the Tiled tests.
Use [the upstream viewer](../ldtk.mod/examples/README.md) for map-level inspection.

The LDtk rendering regression also checks fractional background placement,
scaled/unscaled parallax, camera movement, picking and parent transforms. The
fractional crop is compared with direct Max2D region drawing so nearest-sampling
differences between renderers do not become importer requirements.

Entity-artwork cases cover all seven LDtk tile sizing modes, unchanged gameplay
bounds, hidden artwork, multiplied opacity, supplied embedded atlases, metadata-only
loading and ZIP resources. Repeated backgrounds cover pivot alignment, partial edge
tiles, parent transforms and visible-only traversal of a large level.

LDtk navigation checks exercise duplicate names across worlds, external-level
metadata without file reads, neighbour direction codes, explicit registry lifetime,
wrong world/layer IDs, typed scalar/point/tile/reference fields, nullable arrays,
conversion caching and invalid values. The navigation fixture deliberately names
an absent external level to catch accidental eager loading.

## Upstream LDtk compatibility sweep

`ldtk_upstream.bmx` loads every `.ldtk` project in a supplied directory, renders
all levels, reads typed fields and resolves entity references after explicitly
registering the loaded maps. It is separate from the normal regression suite
because the third-party sample assets are not bundled here.

Use [LDtk's sample directory](https://github.com/deepnight/ldtk/tree/6d69bd1d6be92f01ac30778f6a934f0da8448b16/app/extraFiles/samples)
at revision `6d69bd1d6be92f01ac30778f6a934f0da8448b16`, preserving its subdirectories.
The suite also needs `app/assets/embedAtlas/finalbossblues-icons_full_16.png` from
that revision. Keep each asset's upstream licence/attribution with your copy.

`WorldMap_Free_layout.ldtk` uses the NuclearBlaze Aseprite tilesheet. Export it to
PNG at its original size, or use the validation-only helper:

```sh
python3 mod/max2d.mod/tests/export_ldtk_nuclear_fixture.py /samples/atlas/NuclearBlaze_by_deepnight.aseprite /samples/atlas/NuclearBlaze_by_deepnight.png
bin/bmk makeapp -r -o /tmp/ldtk-upstream mod/max2d.mod/tests/ldtk_upstream.bmx
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software /tmp/ldtk-upstream /samples /path/to/finalbossblues-icons_full_16.png /samples/atlas/NuclearBlaze_by_deepnight.png
```

The Python helper checks the input SHA-256 and accepts only this exact test asset;
it is not a general image decoder or a module dependency. The sweep supplies the
exported pixels for tileset UID 73 in the free-layout project without editing the
project. PNG arguments are optional: omitting required assets results in explicit
load failures. Add a final existing output directory to save each level's capture.
Use `-ud max2d_gl` when building to exercise OpenGL instead of SDL3.

The pinned suite contains **14 projects / 58 levels**. With those assets supplied,
the sweep reads **414 field values / 37 entity references**, with zero unresolved
references. It covers entity artwork, external levels, auto-layer variations,
backgrounds, platformer/top-down layouts, free worlds and GridVania worlds.
A successful sweep checks loading, rendering submission/readback and typed data;
inspect captures as well. It is not a pixel-exact comparison with the LDtk editor.

### Rendering diagnostics

`render_diagnostics.bmx` tests the active backend’s size/flag rejection, render-image
use, native/converted/unsupported texture-format results, batching, detached
statistics, reset boundaries and per-context counters. Format queries are also
checked to create no image frames.
Run `python3 tests/run_regressions.py software --test render_diagnostics`; replace
`software` with `sdl`, `gl`, `d3d9` or `d3d11` for desktop rendering.

### Glyph coverage storage

`coverage_atlas.bmx` compares PF_A8 and RGBA atlas output, allowing one channel
value of rounding difference. It covers tint/alpha, filtered scaling, updates on
later atlas rows, mipmap fallback, MASKBLEND where supported, trimmed locks,
collision thresholds and the built-in font's storage format. It also checks that
OpenGL and the D3D11 test device select native coverage storage while SDL3 and
D3D9 use RGBA. The D3D11 recovery regression also checks native coverage after
device replacement, edits retained across failed replacement, and transitions
to RGBA fallback and back to native storage.

Run `python3 tests/run_regressions.py software --test coverage_atlas`, or choose
`gl`, `sdl`, `d3d9` or `d3d11`. The executable accepts an optional outline-font
path to exercise `Max2D.ScalableFont` as well.

### Owned texture data

`texture_data.bmx` compares raw RGBA/A8 storage against pixmap rendering, including
odd row pitches, image snapshots, animation loading, read-lock isolation, alpha
collision masks and close/reopen. Run it through any rendering regression profile.
`d3d11_recovery.bmx` additionally restores a texture-data-backed image after device
replacement. The CPU ownership, mip layout and invalid-buffer cases are in
`BRL.TextureData/tests/texture_data.bmx`.

`float_textures.bmx` checks RGBA16F and RGBA32F uploads, padded rows and values
outside 0–1 before colour modulation. OpenGL and D3D11 exercise native storage;
SDL3 Renderer and D3D9 verify explicit rejection. With `d3d11_recovery_test`, it
also checks restoration after device replacement. The CPU format metadata and
pixmap rejection checks are in `BRL.TextureData/tests/float_formats.bmx`.

### Supplied mipmaps

`supplied_mipmaps.bmx` gives each level a distinct colour or coverage value and
checks minification, partial-chain clamping, odd row pitches, non-square sizes,
straight alpha, floating-point range, image snapshots, upload statistics and
close/reopen. SDL3 Renderer and D3D9 check explicit rejection. D3D11 builds with
`d3d11_recovery_test` also check all-level restoration and coverage fallback.
Run it with `python3 tests/run_regressions.py gl --test supplied_mipmaps` or choose
another rendering profile.

### Compressed textures

`compressed_textures.bmx` supplies hand-authored BC1/BC3 blocks. It checks decoded
colours, BC1 transparency, BC3 partial alpha, padded block rows, partial mip chains,
small mip levels, rectangular textures, single-level animation loading and
close/reopen. D3D11 recovery builds also check restoration of single levels and
whole chains. SDL3 Renderer and D3D9 verify explicit rejection. CPU layout and
invalid-buffer tests are in `BRL.TextureData/tests/compressed_formats.bmx`.

### Optional DDS loading

`dds_loading.bmx` checks file and stream-factory URLs, caller-owned streams,
legacy/DX10 containers, PNG fallback, animation loading and sampled mip levels.
`dds_disabled.bmx` checks that support remains absent without `Image.DDS`.
Both use generated test fixtures, with parser validation covered separately by
`Image.DDS/tests/dds.bmx`.

`float_targets.bmx` checks RGBA16F/32F rendering, additive blending, values outside
0–1, straight-alpha readback, row order, target switching and sampling into RGBA8.
It also checks ordinary RGBA8 texture-data readback and rejection on unsupported
backends. D3D11 recovery builds verify target recreation and redraw after device loss.
Run with `python3 tests/run_regressions.py gl software --test float_targets`.

The `sdlgpu` profile selects `Max2D.SDL3GPUMax2D`. Its dedicated
`sdl_gpu_targets.bmx` test covers blending, target alpha/orientation, presentation
and multiple-window resource ownership. The remaining tests share the existing
texture, atlas, viewport, camera and drawing-state regressions. Run with
`python3 tests/run_regressions.py sdlgpu`.

`sdl_gpu_mipmaps.bmx` checks lazy automatic generation, partial updates,
premultiplied transparent edges, non-power-of-two and one-pixel images, queued
render-target edits, animation isolation and per-context ownership. The shared
`supplied_mipmaps` and `coverage_atlas` tests cover supplied/partial chains,
trilinear versus nearest-level sampling, and native A8 generation.

The `sdlgpu` profile also runs `float_textures` for native RGBA16F/RGBA32F uploads,
padded rows, negative values and highlights above one. Its `supplied_mipmaps`
checks cover supported float chains and reopening a graphics context.

The native SDL GPU `float_targets` checks cover half/full-precision destinations,
transparent initial contents, straight-alpha readback, negative and above-one
values, additive blending, target-to-target sampling and mixed-format drawing.

The native SDL GPU profile runs `compressed_textures` and `dds_loading` for BC1/BC3
blocks, transparency, padded rows, tiny/partial mip levels, retained images across
contexts, block-aligned base dimensions and optional DDS file/stream loading.

### Native SDL GPU integration and window checks

The `sdlgpu` profile includes paragraph and coloured-text rendering, trimmed
atlases, tilemaps and tile transformations, Tiled/LDtk rendering, capability
queries/statistics and the shared integration test. The integration test covers
virtual/input mapping, resizing, context switching and cross-context rejection.

`sdl_gpu_lifetime` queues 45,000 image draws to cross the native vertex-queue
limit, releases queued source textures, recreates image frames, repeatedly resizes
the window, samples a released render-image source and checks context cleanup.

Run `python3 tests/run_regressions.py sdlgpu-window` separately for the shared
SDL3 fullscreen test with the native backend. It switches between windowed,
borderless and exclusive modes, checks restored size/input mapping, rejects
invalid transitions, and verifies that the GPU context and render-image contents
survive. Keeping it separate lets the normal profile run without display-mode
changes.
