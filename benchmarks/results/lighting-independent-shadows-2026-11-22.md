# Independent shadow invalidation — 2026-11-22

[Metal CSV](lighting-metal-independent-shadows-2026-11-22.csv), captured with the
same `benchmarks/lighting.bmx` workload as the
[initial diagnostic baseline](lighting-2026-11-22.md): 20 warmup frames and 60
measured frames per case, 256² shadow masks, macOS 27.0.1, SDL3 GPU/Metal.

## Work reduction

For 16 lights, 16 casters, 64 receivers, filtered shadows and one moving light:

| Per-frame metric | Before | After |
| --- | ---: | ---: |
| Shadow rebuilds | 16 | 1 |
| Caster tests during rebuilds | 256 | 16 |
| Blur passes | 32 | 2 |
| Direct-light passes | 479.83 | 479.83 |
| Max2D geometry submissions | 592.83 | 547.83 |
| Warm texture creations | 0 | 0 |
| Retained shadow textures | 12 MiB | 12 MiB |

Shadow rebuild work decreases by 93.75% in this workload. The other fifteen
lights reuse their masks. Ambient, light colour/intensity/falloff and receiver
mask changes also preserve existing shadow masks. Geometry, projected patterns
and filter settings invalidate only the corresponding light; caster edits still
conservatively invalidate all masks. Scene output continues to invalidate when
its visible lighting changes.

All 24 Metal workload cases produced the expected rebuild counts and zero warm
texture creations. Static workloads continue to rebuild no masks after warmup.

CPU frame means remained near 8.3 ms, consistent with the pacing constraint seen
in the baseline. This establishes reduced work, not a 16× frame-rate improvement.
Geometry submissions are Max2D counters, not guaranteed GPU draw calls.
Direct-light passes remain a separate cost: combining several light contributions
per shader pass is a future optimisation candidate.
