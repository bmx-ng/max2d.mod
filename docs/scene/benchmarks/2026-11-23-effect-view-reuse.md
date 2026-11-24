# Effect views and provider lookup — 23 November 2026

Two internal changes address the larger render allocations identified by the
[previous attribution run](2026-11-23-render-attribution.md):

- Image-effect provider lookup walks existing list links directly instead of
  allocating an iterator. Registration order and first-match selection are
  preserved; provider callbacks still run on each query, with no cached decision.
- Effect chains, scaled-blur passes, bloom composition and inner-shadow composition
  preserve output views using a private value snapshot. Their enclosing drawing-state
  scopes continue to restore the caller. Each output's persistent virtual size,
  clip, presentation mode, bar colours and automatic/full-clip flags are restored.

The view helper is private to Max2D.Effects. It does not change public scopes or
require a new application API. It is used only inside operations that already own
an outer drawing-state scope. Image-effect providers retain their existing contract
to preserve drawing state.

## Allocation measurements

Release builds on the same macOS arm64 host, with Metal and native OpenGL. Three
120-frame trials per case, using `--trials-only --allocation-detail`. Both backends
return identical byte counts in all three trials.

| Component during group redraw | Before, bytes/frame | After, bytes/frame |
| --- | ---: | ---: |
| Lit-receiver draws, including lazy shadow work | 5,568 | 1,472 |
| Bloom update | 2,736 | 1,104 |
| Alpha-mask update | 736 | 736 |

The receiver path removes 128 iterator allocations of 32 bytes each. Bloom removes
four full 368-byte state scopes and five 32-byte provider iterators in this workload.
Allocation remains in the outer state scopes and other rendering operations.

| Full workload | Before, bytes/frame | After, bytes/frame |
| --- | ---: | ---: |
| Cached | 32 | 32 |
| Mask changes | 1,136 | 1,136 |
| Lighting changes | 9,472 | 3,744 |
| Combined changes | 9,840 | 4,112 |

The combined case saves 5,728 bytes/frame (58%). Relative to the original 11,504-byte
allocation baseline, the cumulative reduction is 64%. This does not establish a
frame-time or GPU-throughput improvement. Detail-mode GC-counter reads add timing
overhead, and these short runs do not include a new 60,000-frame soak.
Windows/Linux were not exercised in this tranche.

Both runs pass warm-texture, stable resource-charge and cleanup checks. Editing,
lighting preparation and picking remain allocation-free in this workload.

- [Metal raw results](2026-11-23-effect-view-reuse-sdlgpu.csv)
- [OpenGL raw results](2026-11-23-effect-view-reuse-gl.csv)

Use the [workload build and run instructions](2026-11-23-render-attribution.md#reproduce-and-interpret)
to reproduce. The measured workload and CSV columns are unchanged.

## Correctness coverage

On both backends, `layer_effect_chain`, `scaled_blur`, `bloom_pipeline` and
`inner_shadow` pass their pixel, validation, cache and state-restoration checks.
The blur and chain tests configure distinct views on scratch, reduction and output
targets and verify they survive processing. Bloom also checks subsequent window
drawing after rebuilding its cached image.

The chain regression now registers a rejecting provider followed by two accepting
providers for a test-only effect. One thousand support lookups allocate zero bytes,
visit the rejecting provider and first accepting provider, and never reach the
later match. An injected runtime draw failure then verifies caller restoration and
preservation of both output views, beyond the existing unsupported-effect preflight
checks.

Remaining allocations are concentrated in outer state saves and lazy shadow work.
Further attribution should distinguish those boundaries before changing their
lifetime or pooling rules.
