# Combined ambient lighting — 22 November 2026

## What changed

With `SetLightBatching(True)`, the first eligible native group now composes
ambient colour, receiver coverage and up to eight direct lights in one draw.
Further groups add direct light while preserving destination alpha. Normals,
specular response, projected patterns and shadow maps retain their existing
grouping support.

This saves one draw per receiver whose first group supports ambient composition.
Zero or one eligible light, an unsupported first light, and renderer providers
without ambient support retain separate ambient drawing. Flattened `Update`
also retains its ordinary path.

Ambient follows ordinary alpha composition on each backend. Native Direct3D 11
clamps normalized ambient RGB before coverage; the other native paths preserve
overbright colour through premultiplied composition. HDR retains the full range. Direct
contributions retain their individual normalized-target clamping. This
distinction matters for bright ambient on translucent artwork.

## Work counters

Quick normal/specular runs with shared projected patterns used three warm-up
frames and five measured frames. For 16 lights and 64 receivers, with only the
first light moving:

| Shadows | Ordinary submissions/frame | Previous grouping with separate ambient | Combined ambient grouping |
| --- | ---: | ---: | ---: |
| None | 544 | 152 | 88 |
| Hard | 544 | 152 | 88 |
| Filtered | 544 | 152 | 88 |

The previous grouping column is the unchanged 88 direct passes plus 64 separate
ambient draws. The new path records 64 combined ambient compositions and 88
direct passes, with unchanged light contributions.

All 24 grouped workloads create no textures during measurement. Moving an
unshadowed projection requires no atlas upload; moving a shadowed light requires
one upload per frame. Ambient composition adds no textures or retained arrays.

These are submission and cache checks, not a claim of proportional frame-time
improvement. The quick interval is too short for reliable timing comparisons.
The totals exclude HUD drawing and shadow preparation.

Reproduce with the same backend and display settings:

```sh
lighting-benchmark --quick --normal --patterns > ordinary.csv
lighting-benchmark --quick --normal --patterns --grouped > grouped.csv
```

Omit `--quick` and repeat paired runs for timing measurements.

## Diagnostics

- `AmbientPasses()`: completed ambient compositions, separate or combined.
- `CombinedAmbientPasses()`: ambient compositions included in the first group.
- `LightPasses()`: completed direct-light passes, retaining its prior meaning.
- Total lighting submissions: ambient + direct − combined.

The benchmark exports these as `ambient_passes`, `combined_ambient_passes`,
`light_passes` and `lighting_submissions`.

## Regression coverage

The suite compares ordinary and combined rendering with zero and overbright
ambient, gradient transparency, overlapping artwork, tint, opacity, clipping,
more than eight lights, ambient-only selection and unsupported patterns at the
start or end of the light list. It checks blend restoration, exactly one ambient
composition and counter reset.

Normalized comparisons preserve alpha exactly and allow repeated byte rounding
across nine direct lights plus ambient. An HDR comparison checks the same
overbright translucent composition without normalized clamping. Existing
normal/specular, patterned, shadowed and transformed receiver checks remain in
the suite. Generated shader sources and embedded assets are reproduced by the
shader regression.

All **476 lighting checks** passed on macOS Metal and OpenGL, Ubuntu Vulkan and
OpenGL, and Windows Direct3D 9 and 11. The SDL renderer's six unsupported-provider
checks passed too. The 24-workload benchmark comparisons verified the submission
counts and cache behaviour above on Metal, Vulkan, Direct3D 9 and Direct3D 11.
