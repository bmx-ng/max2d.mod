# Release checks and API documentation — 24 November 2026

## Scope and outcome

The outstanding shared-source preparation platform checks pass. Tested renderer
source is `d4216a6` on `task/scene-design`, including the implementation from
`845fde7` and subsequent formatting commits. This review changes documentation
and the scaling benchmark only: no renderer behaviour or public signatures change.
These checks extend the [existing release matrices](../validation.md), rather
than claiming a fresh run of every historical suite.

## Platform results

All **32 runs passed**: 1,162 regression assertions and four three-frame live-mask
example smoke runs. The [individual results](../validation/2026-11-24-release-platforms.csv)
record the following assertions per backend:

| Suite | Ubuntu SDL GPU | Ubuntu OpenGL | Windows D3D9 | Windows D3D11 |
| --- | ---: | ---: | ---: | ---: |
| Source preparation | 17 | 17 | 17 | 17 |
| Live subtree masks | 39 | 39 | 39 | 39 |
| Selected subtree capture | 68 | 68 | 68 | 68 |
| Composites | 65 | 65 | 64 | 64 |
| Image alpha masks | 56 | 56 | 56 | 56 |
| Culling | 22 | 22 | 22 | 22 |
| Storage | 24 | 24 | 24 | 24 |

Linux ran on Ubuntu 26.04.1 LTS ARM64 in Parallels (the VM retains its older
Ubuntu 25.10 name). Windows ran on Windows 11 Pro 10.0.26200 ARM64 with x64
applications. The guest compiler sources remain `bcc2 a4307ff` and
`blitzmax.mod b6bfb4c`. These are virtualised desktop checks, not native mobile,
touch-hardware, HDR-display or GPU-vendor certification.

## Public API documentation

Reviewed **632 public methods/functions** across nine modules:

| Module | Routines |
| --- | ---: |
| Scene | 178 |
| SceneAnimation | 16 |
| SceneEffects | 117 |
| SceneLighting | 74 |
| SceneParticles | 8 |
| SceneTilemap | 8 |
| Effects | 95 |
| Lighting | 109 |
| LightingDriver | 27 |

Every routine has a bbdoc summary, ordered `param:` entries for its arguments,
and `returns:` information for typed results. Missing tags were added to 537
routine comments. Public lighting request field groups now document coordinate
spaces, units, capabilities, borrowing and queued-resource lifetime. The Scene
module overview describes the implemented framework rather than a proposal.
Existing `about:` guidance was reviewed for ownership, invalidation, validation,
fallback and provider responsibilities; the mesh drawing description now includes
grouped geometry. Simple getters do not need a redundant `about:` paragraph.

A harness using the repository's actual `makedocs` parser successfully read all
nine module entry points and their includes. All 632 routine parameter counts
matched the declarations, and every typed result has return documentation. This
checks parsing and coverage; it is not a claim that a complete HTML manual was
regenerated or visually reviewed. Module changes contain comments only.

## Corrected scaling checks

The old camera-motion fixture mutated a `TCamera2D` after calling `SetCamera`,
which copies its values. Its historical `camera_move` rows therefore measured a
stationary view. The fixture now reapplies the camera after each edit and verifies
a moving artwork edge by pixel readback outside the CPU/allocation interval.
Historical reports identify those rows as invalid. Shared-mask measurements and
the reported preparation improvement are unaffected.

Metal and OpenGL each pass 52 cases, three trials and 40 measured frames per
trial: **12,480 measured frames** plus warmups. Checks include camera pixels,
cache invalidation, stable retained/peak storage, zero new textures after warmup,
and zero scene storage charges after destruction. Host: Apple M4 Max, macOS
27.0.1 (26A434), arm64 release builds.

- [Metal raw trials](2026-11-24-release-scaling-metal.csv)
- [OpenGL raw trials](2026-11-24-release-scaling-gl.csv)

These runs validate workload invariants. They are not a controlled before/after
performance comparison; compilation overlapped part of the Metal run. Use the
[paired shared-source measurements](2026-11-24-source-preparation.md) for the
specific performance claim.

## Remaining boundaries

The release checks are complete within this scope. The obsolete mask-specific
recursive preparation walk was already removed in the implementation tranche.
Ordered lighting fallbacks, ordinary traversal and per-consumer mask captures
remain required paths, not redundant transitional code. Retaining dependency
topology across frames or sharing mask pixels would be separate optimisations
with additional lifetime and invalidation contracts. No such change is required
by these release results.
