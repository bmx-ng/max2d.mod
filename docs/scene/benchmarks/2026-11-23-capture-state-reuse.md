# Mask validation and capture state reuse — 23 November 2026

Alpha-mask preparation now restores only the selected render target around its
blend-capability query. That check changes neither drawing state nor target views,
so it no longer needs a full drawing-state scope.

TMax2DEffectLayer.Capture retains separate private saved and working drawing states.
Every capture still allocates a fresh public handle and a fresh saved entry, with
its own active flag. Normal close restores the original caller state object; an
outer unwind leaves the old entry inactive. Closing an old handle cannot unwind a
later capture. Clear and line settings and the current font remain inherited as
before. Camera snapshot storage is retained across ordinary calls. Public API
signatures and capture nesting rules are unchanged.

## Measurements

Same macOS arm64 host and release workload as the
[layer-alpha follow-up](2026-11-23-layer-operation-state.md). Three 120-frame trials
per case with `--trials-only --allocation-detail`. Metal and OpenGL return the
same allocation counts in all trials.

| Workload | Before, managed bytes/frame | After, managed bytes/frame |
| --- | ---: | ---: |
| Cached | 32 | 32 |
| Mask changes | 400 | 32 |
| Lighting changes | 432 | 224 |
| Combined changes | 800 | 224 |

Mask preparation falls from 368 to zero bytes/update. Receiver draws, bloom,
mask application and mask preparation all measure zero during warm redraws.
A direct test with a configured camera measures 160,000 bytes over 1,000 warm
captures. The workload's capture cost falls from 368 to 160 bytes per call.
Together with two 32-byte scene stack entries, this accounts for the remaining
224 bytes during recapture. Cached and mask-only frames use one scene entry.

Combined allocation is about 98% below the original 11,504-byte baseline. These
are managed allocation results, not frame-rate or GPU-throughput claims. Detailed
instrumentation adds timing overhead. All trials pass resource-charge, warm-texture
and cleanup invariants, with zero new textures. No new long soak or Windows/Linux
validation was performed.

- [Metal CSV](2026-11-23-capture-state-reuse-sdlgpu.csv)
- [OpenGL CSV](2026-11-23-capture-state-reuse-gl.csv)

Reproduce using the trial options in the
[attribution instructions](2026-11-23-render-attribution.md#reproduce-and-interpret).

## Correctness checks

On each backend:

- `effect_capture_state.bmx`: 54 checks. Covers inherited clear/line settings,
  caller state identity, affine and parent coordinates, camera, colour byte alpha,
  view and scope balance, exception cleanup, old handles after normal close and
  outer unwind, native cleanup and 1,000 warm captures.
- `composition_helpers.bmx`: existing capture pixels, padding, scaling, nested
  layers, resize/release guards, context closure during capture and reuse after
  context recreation all pass.
- `scene_alpha_masks.bmx`: 56 checks, including preparation, mask pixels and
  caller restoration with owned output selected.

Build with `-ud max2d_sdlgpu` or `-ud max2d_gl`; no external assets are required.

Remaining allocations deliberately keep public handles and entries independent.
Broader lifecycle, platform and timing validation is the next useful gate before
considering further changes to scope bookkeeping.
