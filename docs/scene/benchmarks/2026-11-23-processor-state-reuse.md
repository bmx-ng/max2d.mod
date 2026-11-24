# Retained drawing state for bloom and scaled blur — 23 November 2026

Bloom and scaled blur now retain private drawing-state storage. Each call uses a
value scope to restore the caller's original state object and render target.
Existing per-pass view snapshots still restore every output image's independent
virtual size and viewport, including when that image was the caller's target.
Bloom support validation uses the same retained storage.

The helper is private to Max2D.Effects and applies only to operations that preserve
all output views themselves. A provider entering an already active processor uses
a separate public scope instead of sharing live state. Public scope handles and
API signatures are unchanged. Effect providers retain their existing obligation
to preserve drawing state. Bloom extraction still uses ApplyLayerEffects and its
one outer scope; alpha masking is unchanged in this tranche.

## Measurements

Same macOS arm64 host and release workload as the
[shadow-state follow-up](2026-11-23-shadow-state-reuse.md). Three 120-frame trials
per case with `--trials-only --allocation-detail`. Metal and OpenGL produce the
same allocation counts in every trial.

| Workload | Before, managed bytes/frame | After, managed bytes/frame |
| --- | ---: | ---: |
| Cached | 32 | 32 |
| Mask changes | 1,136 | 1,136 |
| Lighting changes | 2,272 | 1,536 |
| Combined changes | 2,640 | 1,904 |

Bloom falls from 1,104 to 368 bytes/update: its own scope and the scaled-blur scope
no longer allocate in the ordinary path. The remaining 368 bytes are extraction's
scope. Receiver drawing stays at zero and alpha masking at 736 bytes/update.
Combined allocation is about 83% below the original 11,504-byte baseline.

These are managed allocation measurements, not frame-rate or GPU-throughput
claims. Detailed counters add timing overhead. All trials pass warm-texture,
resource-charge and cleanup invariants, with zero new textures. No new long soak
or Windows/Linux validation was performed.

- [Metal CSV](2026-11-23-processor-state-reuse-sdlgpu.csv)
- [OpenGL CSV](2026-11-23-processor-state-reuse-gl.csv)

Reproduce using the unchanged workload and the
[attribution instructions](2026-11-23-render-attribution.md#reproduce-and-interpret).

## Correctness checks

On each backend:

- `effect_processor_state.bmx`: 152 checks. A test provider copies images and
  injects failures at each blur and bloom effect-draw position. Checks include
  caller state identity, camera, transform, tint, target, virtual size, viewport,
  enclosing scope balance, retry after failure, bloom cache invalidation and
  cleanup. Blur is tested with source, destination and scratch selected as the
  caller target; bloom with its result selected. The provider also reenters the
  same blur descriptor using separate images, checking caller restoration.
- `scaled_blur.bmx`: existing independent CPU alpha-reference and output-view
  checks, including odd dimensions, reduction levels and context recreation.
- `bloom_pipeline.bmx`: existing native pixel checks for opaque and transparent
  composition, intensity, halos, window drawing and context recreation.
- `lighting_shadow_state.bmx`: 87 checks, including soft-shadow filtering and
  textured-shadow failure recovery through the changed blur path.

The injected-failure provider deliberately does not implement real shaders; the
separate native pixel suites cover rendering fidelity. Build all tests with
`-ud max2d_sdlgpu` or `-ud max2d_gl`; no external assets are required.

The next allocation targets are alpha masking's outer and layer-operation scopes,
plus the extraction scope retained by effect chains.
