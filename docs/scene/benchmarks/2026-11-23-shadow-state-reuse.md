# Retained drawing state for shadow maps — 23 November 2026

Shadow maps now retain a private drawing-state object for rebuilding their owned
render images. The pass restores the original caller state and target in `Finally`.
Point and directional lights, hard and filtered shadows, and point-light patterns
use the same path. A conservative full-scope fallback preserves the target view
if an owned shadow image is ever selected as the caller target. Public scopes and
lighting APIs are unchanged. Soft-shadow blur still uses its existing outer scope.

## Measurements

Same macOS arm64 host and release workload as the
[atlas follow-up](2026-11-23-atlas-state-reuse.md), with three 120-frame trials per
case and `--trials-only --allocation-detail`. Metal and OpenGL give identical
allocation counts across all trials.

| Workload | Before, managed bytes/frame | After, managed bytes/frame |
| --- | ---: | ---: |
| Cached | 32 | 32 |
| Mask changes | 1,136 | 1,136 |
| Lighting changes | 3,008 | 2,272 |
| Combined changes | 3,376 | 2,640 |

Lit-receiver allocation falls from 736 to zero bytes/frame, including the two
changing hard-shadow maps. This does not claim allocation-free soft-shadow
filtering. Bloom remains 1,104 bytes/update and alpha masking 736. Combined
allocation is about 77% below the original 11,504-byte baseline. Cached rendering
remains 32 bytes/frame.

These are managed allocation results, not frame-rate or GPU-throughput claims.
Detailed counter reads add timing overhead. No new long soak or Windows/Linux
validation was performed. All trials pass warm-texture, resource-charge and
cleanup invariants, with zero new textures.

- [Metal CSV](2026-11-23-shadow-state-reuse-sdlgpu.csv)
- [OpenGL CSV](2026-11-23-shadow-state-reuse-gl.csv)

## Correctness checks

On each backend:

- `lighting_shadow_state.bmx`: 87 checks covering caller state identity, camera,
  transform, colour, target, virtual size, viewport and enclosing scope balance.
  Exercises hard/soft point shadows with and without patterns, hard/soft
  directional shadows, locked-pattern failure and successful retry, cached reuse,
  and native-frame cleanup.
- `lighting_affine_mesh.bmx`: 366 existing lighting geometry and pixel checks.
- `lighting_specular_native.bmx`: 279 existing native material and lighting checks.

Build these with `-ud max2d_sdlgpu` or `-ud max2d_gl`. The new state regression
requires no assets or arguments. For workload reproduction see the
[attribution instructions](2026-11-23-render-attribution.md#reproduce-and-interpret).

Remaining measured allocation is concentrated in bloom, masking and other
render-stage scopes. Those are the next candidates for bounded state reuse,
with view restoration and failure recovery retained.
