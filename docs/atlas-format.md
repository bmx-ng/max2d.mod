# Atlas package format

A package is a directory containing `atlas.json` and `page-0.png`, `page-1.png`,
etc. Page filenames are fixed by array index; no filesystem paths come from JSON.
Image coordinates are integers in page pixels. Pixels use straight RGBA alpha.

The loader accepts versions 1 and 2. The writer uses version 1 for untrimmed,
untimed single-frame images; otherwise it writes version 2 for the whole package.

Version 1 example (one 4x4 image with a one-pixel extruded border):

```json
{
  "format": "max2d-atlas",
  "version": 1,
  "pageSize": 1024,
  "padding": 1,
  "flags": 2,
  "pages": [
    {
      "width": 6,
      "height": 6,
      "regions": [
        {"x": 1, "y": 1, "width": 4, "height": 4, "padding": 1}
      ]
    }
  ],
  "images": [
    {
      "name": "player",
      "page": 0,
      "x": 1,
      "y": 1,
      "width": 4,
      "height": 4,
      "handleX": 2,
      "handleY": 2
    }
  ]
}
```

## Fields

- `format` and `version` identify this format. Unknown versions are rejected.
- `pageSize` and `padding` configure subsequent runtime insertions. Page size is
  4–16384; padding is at least one and less than half the configured page size.
- `flags` combines `MASKEDIMAGE` (1), `FILTEREDIMAGE` (2) and `DYNAMICIMAGE` (8).
  Other bits are rejected. Pixels are stored exactly; loading does not apply a
  color key a second time.
- `pages` lists page dimensions (1–16384) and all padded region allocations.
  A region's x/y/width/height describe its interior, excluding padding.
  Padded allocations must fit inside the page and must not overlap each other.
  Regions need not have names; all allocation metadata survives a round trip.
- `images` lists uniquely named, single-frame views into those pages. Names may
  contain Unicode or punctuation and are never used as filenames. Views must
  fit inside their pages. They may alias or select a subrectangle of a region.
  Handles are finite numbers, including fractional or negative values.

Page PNG header dimensions are checked against the manifest before decoding.
The decoded dimensions are checked again. Loading defaults to a budget of
64,000,000 total page pixels, configurable through `LoadTextureAtlas`'s second
argument. This is a count of image pixels, not a bound on peak process memory:
decoding, CPU copies and renderer textures need additional storage.

The loader rebuilds each extruded border from its interior, so an external tool
can edit interior pixels without needing to regenerate borders itself. Existing
pages are not repacked; subsequent runtime insertions start on a new page.

Saving requires a new directory. Pages are written first and the manifest last.
A reported write failure removes files created by that save where possible.
This is not a transactional replacement protocol: process termination can leave
an incomplete directory, and writers must not share an output directory.
Build into a fresh directory and replace a deployed package separately.

Version 1 does not store rotated/trimmed sprites, animation sequences, per-frame
durations, font metrics, or renderer resources. Anonymous image views have no
lookup entry, although their page pixels and padding allocations are retained.

## Version 2: logical canvases, trim offsets and animation

Page fields and allocation regions are unchanged. Each named image instead has
this structure (an illustrative frame within a 32×24 canvas):

```json
{
  "name": "walker",
  "width": 32,
  "height": 24,
  "handleX": 16,
  "handleY": 12,
  "frames": [
    {
      "page": 0,
      "x": 1,
      "y": 1,
      "width": 8,
      "height": 6,
      "offsetX": 5,
      "offsetY": 6,
      "duration": 120
    }
  ]
}
```

- Image `width`/`height` are the original logical canvas, each 1–16384.
- `frames` is a nonempty ordered array. Frames may reference different pages.
- Frame `x`/`y` locate retained pixels within the page. Frame `width`/`height`
  describe those retained pixels, including any transparent filtering fringe
  but excluding extrusion padding.
- `offsetX`/`offsetY` place the retained rectangle within the logical canvas.
  Offsets must be nonnegative; the rectangle must fit both page and canvas.
- A fully transparent frame has both width and height zero. Its x/y still point
  to a valid page pixel (the builder allocates a transparent 1×1 placeholder).
- `duration` is a nonnegative integer number of milliseconds, at most 2147483647.
  Zero means unspecified; manual frame selection remains available, but elapsed
  time helpers reject sequences containing unspecified timing.
- Handles are common to every frame and measured in logical canvas coordinates.
  All frames use the package image flags. A subview can be named separately.

The page pixel budget counts packed storage, not reconstructed logical canvases.
Loading does not allocate full canvases; requesting a trimmed read/write lock does.
Transparent pixels removed by trimming reconstruct as RGBA zero.

Version 2 does not store automatic playback state, loop counts, animation tags,
rotated packing, skeletal data, font metrics or renderer resources. Format-specific
import modules can translate their metadata into these native image objects later.

## Regression coverage

`tests/atlas_animation.bmx` checks packing across pages, timing boundaries,
transparent frames, logical readback, nested views, transformed collisions with
handles, dynamic updates, version 2 round trips and malformed metadata.
`tests/atlas_trim_render.bmx` compares trimmed and untrimmed output with nearest
and linear filtering, scaling, quarter turns, reflection, sub-images, cameras and
render textures. Both are included in the regression runner's relevant profiles:

```sh
python3 mod/max2d.mod/tests/run_regressions.py core software --debug \
  --test atlas_animation --test atlas_trim_render --test collisions
```

The existing `atlas_io.bmx` and `atlas_render.bmx` cover version 1 compatibility,
page updates and border extrusion. The builder also accepts `--trim`.

Validation on 2026-09-25 covered macOS arm64 (OpenGL, SDL3's default renderer and
software), the Linux arm64 Parallels VM (OpenGL and SDL3), and the Windows 11
Parallels VM (D3D9, D3D11 and SDL3). This does not substitute for testing physical
Windows GPU drivers.

The SDL3 bridge bypasses SDL's software rectangle shortcut for quarter-turn
textured quads, where that shortcut loses UV orientation. Those draws submit
individual triangles; ordinary software quads retain their existing path.
