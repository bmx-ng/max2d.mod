# Retained effect-chain and mask drawing state — 23 November 2026

TMax2DEffectBuffers now owns reusable drawing state for ApplyChain. Its internal
implementation is shared with ApplyLayerEffects, keeping validation and per-output
view snapshots in one place. The standalone function still allocates its caller
scope; retained buffers avoid it in ordinary calls and keep the separate-scope
fallback for reentrant calls. This also removes bloom extraction's last scope
allocation without changing public signatures.

TSceneAlphaMaskStage similarly retains drawing state for its coverage and output
passes. It keeps a full caller scope when an owned image is the caller's selected
target, since those passes change that image's view. Other calls restore the
original caller state and target in Finally. The underlying layer-alpha operation
still allocates its own scope.

## Measurements

Same macOS arm64 host and release workload as the
[processor follow-up](2026-11-23-processor-state-reuse.md). Three 120-frame trials
per case with `--trials-only --allocation-detail`. Metal and OpenGL return the
same allocation counts across all trials.

| Workload | Before, managed bytes/frame | After, managed bytes/frame |
| --- | ---: | ---: |
| Cached | 32 | 32 |
| Mask changes | 1,136 | 768 |
| Lighting changes | 1,536 | 800 |
| Combined changes | 1,904 | 1,168 |

Measured bloom allocation falls from 368 to zero bytes/update. Receiver drawing
remains zero. Alpha masking falls from 736 to 368 bytes/update in the ordinary
scene path; selecting its owned output as caller target retains the extra scope.
Combined allocation is approximately 90% below the original 11,504-byte baseline.
The remaining combined total consists of 368 bytes in masking and 800 in other
render work.

These results measure managed allocation, not frame-rate or GPU throughput.
Detailed instrumentation adds timing overhead. All trials pass resource-charge,
warm-texture and cleanup invariants, with zero new textures. No new long soak or
Windows/Linux validation was performed.

- [Metal CSV](2026-11-23-chain-mask-state-reuse-sdlgpu.csv)
- [OpenGL CSV](2026-11-23-chain-mask-state-reuse-gl.csv)

See the [attribution instructions](2026-11-23-render-attribution.md#reproduce-and-interpret)
for reproduction.

## Correctness checks

On each backend:

- `effect_processor_state.bmx`: 255 checks. Adds retained empty and two-effect
  chains with source, destination and scratch selected as caller target; injected
  failures at both effect draws; state/view restoration and retry. One thousand
  warmed two-effect chain calls allocate zero managed bytes with the test provider.
- `scene_alpha_masks.bmx`: 56 checks. Adds successful update, locked-mask failure
  and retry while the returned output is selected with a non-default view.
- `layer_effect_chain.bmx`: existing native pixel, output-view and standalone
  failure checks pass through the shared implementation.
- `bloom_pipeline.bmx`: existing native bloom pixel and lifecycle checks pass.

The processor test uses a deterministic copy/failure provider; the separate native
pixel suites verify effect rendering. Build with `-ud max2d_sdlgpu` or `-ud max2d_gl`.
No external assets or arguments are required.

The next target is the remaining layer-alpha scope, followed by attribution of
the other render work rather than assuming all of it can be removed.
