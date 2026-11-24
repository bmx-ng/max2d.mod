# Retained drawing state for light-atlas copies — 23 November 2026

Native lighting's atlas now owns a reusable drawing-state object for its internal
copy pass. It temporarily selects that object and restores the caller's original
state object and target in `Finally`. This avoids allocating a full public state
scope for each map copied into the atlas.

The existing validation requires the atlas target to differ from the caller's
target. The pass configures only the atlas's view and its retained copy state;
it does not edit the caller's view, font or state. Failed copies leave the tile
invalid so the next resolve retries it. No public scope or lighting API changes.

## Measurements

Same macOS arm64 host and detailed workload as the
[effect-view follow-up](2026-11-23-effect-view-reuse.md). Release builds, three
120-frame trials per case, Metal and native OpenGL. Both backends return identical
allocation counts in all three trials.

| Workload | Before, managed bytes/frame | After, managed bytes/frame |
| --- | ---: | ---: |
| Cached | 32 | 32 |
| Mask changes | 1,136 | 1,136 |
| Lighting changes | 3,744 | 3,008 |
| Combined changes | 4,112 | 3,376 |

Lit-receiver draws fall from 1,472 to 736 bytes/frame. The two changing shadow maps
previously required two 368-byte atlas-copy scopes per frame; those copies now
allocate zero. The remaining receiver allocation matches the two state scopes in
shadow rendering itself. Bloom stays at 1,104 bytes/update and masking at 736.
The cached path remains 32 bytes/frame.

Combined allocation is now 71% below the original 11,504-byte baseline. These are
managed allocation measurements, not frame-rate or GPU-throughput claims. Detailed
counter reads add timing overhead. No new long soak or Windows/Linux run is claimed.

- [Metal CSV](2026-11-23-atlas-state-reuse-sdlgpu.csv)
- [OpenGL CSV](2026-11-23-atlas-state-reuse-gl.csv)

Build and run the unchanged workload with `--trials-only --allocation-detail`,
following the [attribution instructions](2026-11-23-render-attribution.md#reproduce-and-interpret).
All runs pass warm-texture, stable resource-charge and cleanup checks.

## Correctness checks

The new `tests/lighting_atlas_state.bmx` passes 30 checks on each backend. It checks
atlas pixels under a non-default caller camera, transform, tint, alpha and viewport;
caller state identity and target restoration; an enclosing public scope; tile
invalidation and caller restoration after a locked-image copy failure; successful
retry; and final native-frame cleanup. One thousand warmed, revision-changing atlas
copies allocate zero managed bytes.

The existing `scene_shadows.bmx` also passes 39 checks on each backend. The direct
atlas regression builds with `-ud max2d_sdlgpu` or `-ud max2d_gl` and needs no assets
or arguments.

The next remaining receiver target is shadow rendering's own state scope. That
operation has a broader path than atlas copying, including optional patterns and
soft-shadow filtering, so its restoration rules need separate validation.
