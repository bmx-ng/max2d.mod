# Value snapshots for layer-alpha operations — 23 November 2026

ApplyLayerAlphaMask, ApplyLayerInverseAlphaMask and ApplyLayerOpacity now save the
specific drawing fields they change in a private value snapshot. They reuse the
existing value snapshot for the active target's view. These closed drawing passes
need no heap-allocated public scope, retained global cache or public API change.
Camera settings themselves are not edited; their reference and cached transform
are restored. Clear colour, line width, font and unrelated settings are untouched.

## Measurements

Same macOS arm64 host and release workload as the
[chain/mask follow-up](2026-11-23-chain-mask-state-reuse.md). Three 120-frame trials
per case with `--trials-only --allocation-detail`. Metal and OpenGL produce the
same allocation counts in all trials.

| Workload | Before, managed bytes/frame | After, managed bytes/frame |
| --- | ---: | ---: |
| Cached | 32 | 32 |
| Mask changes | 768 | 400 |
| Lighting changes | 800 | 432 |
| Combined changes | 1,168 | 800 |

Measured mask application falls from 368 to zero bytes/update. Receiver drawing
and bloom remain zero. Combined allocation is about 93% below the original
11,504-byte baseline. This does not make the complete scene allocation-free.

A new optional `mask_prepare_bytes_per_frame` column measures alpha-mask
preparation separately from Update. It is appended to the CSV; the existing
`other_render_bytes_per_frame` now excludes this additional measured component.
With detail disabled, all component columns remain zero and other-render records
the full render allocation. Existing saved reports retain their original meaning.

| Workload | Mask preparation | Other render work, bytes/frame |
| --- | ---: | ---: |
| Cached | 0 | 32 |
| Mask changes | 368 | 32 |
| Lighting changes | 0 | 432 |
| Combined changes | 368 | 432 |

The preparation measurement identifies the scope in the alpha-mask stage's blend
support check. Source inspection and prior scope measurements account for the
remaining 432 bytes during recapture as the 368-byte effect-layer Capture scope
plus two 32-byte scene stack entries. The cached path uses one such entry. This
capture breakdown is inferred, not independently instrumented in this report.

These are managed allocation results, not frame-rate or GPU-throughput claims.
Detailed counters add timing overhead. All trials pass warm-texture, resource-charge
and cleanup invariants, with zero new textures. No new long soak or Windows/Linux
validation was performed.

- [Metal CSV](2026-11-23-layer-operation-state-sdlgpu.csv)
- [OpenGL CSV](2026-11-23-layer-operation-state-gl.csv)

Reproduce using the unchanged trial options in the
[attribution instructions](2026-11-23-render-attribution.md#reproduce-and-interpret).

## Correctness checks

On each backend:

- `layer_operation_state.bmx`: 68 checks, including original state identity,
  non-default view, affine matrix, parent coordinates, camera transform, colour
  byte alpha, unrelated settings, enclosing scope balance, locked-mask failure,
  successful retry and native cleanup. One thousand repetitions of all three
  operations (3,000 calls) allocate zero managed bytes after warming.
- `layer_effects.bmx`: native alpha-mask and opacity pixel checks.
- `inverse_layer_masks.bmx`: inverse-alpha pixel checks and context recreation.
- `scene_alpha_masks.bmx`: 56 scene checks, including selected-output restoration
  after success and failure.

Build with `-ud max2d_sdlgpu` or `-ud max2d_gl`; no external assets are required.

Next targets are mask support validation and composite capture. Capture exposes
a public one-shot scope, so any optimization must preserve stale-handle safety,
nesting and unwinding rather than recycling a returned handle.
