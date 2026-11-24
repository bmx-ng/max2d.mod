# Retained mesh preparation — 23 November 2026

This tranche reduces CPU preparation work for the existing affine-section path.
It does not implement arbitrary whole-mesh shader transport or change submission
counts. Public lighting and provider interfaces are unchanged.

## Changes

- Retain each triangle's local UV-to-geometry mapping. Affine-capable grouped
  sessions reuse its linear part during validation and drawing, including when
  no two triangles can be combined. Draw placement and lighting transforms still
  receive full finite-value validation before any submission.
- When XY changes but UV/index data does not, reuse non-overlap proofs for
  subranges of earlier affine sections. Current basis agreement is checked again.
  New merges and changed topology still perform overlap analysis as needed.
- Mark analysis invalid before rebuilding it. A late singular UV triangle cannot
  leave an incomplete snapshot that a later call mistakes for a valid cache hit.

The mapping and membership arrays add 52 bytes per analyzed triangle, up to
26 KiB at the 512-triangle limit, excluding array headers and the existing mesh
snapshots/section buffers. Capacity is retained until `Release()`.

## Isolated CPU measurements

`benchmarks/mesh_preparation.bmx` runs without a graphics window. Both binaries
used the same benchmark source, release-built on macOS arm64. The baseline used
`afbadbe`; the second used this tranche's analyzer. Each case has 20 warm-up
iterations and three trials of 1,000 iterations. Times include coordinate edits
and the analyzer call. Values below are the median trial means, in microseconds.

| Triangles | Workload | Before (µs) | After (µs) |
| ---: | --- | ---: | ---: |
| 128 | Unchanged | 0.175 | 0.185 |
| 128 | Translation every iteration | 71.605 | 0.872 |
| 128 | Bending eight sections | 10.165 | 0.994 |
| 512 | Unchanged | 0.636 | 0.661 |
| 512 | Translation every iteration | 1,016.067 | 3.339 |
| 512 | Bending sixteen sections | 70.384 | 3.946 |

All measured loops recorded zero managed bytes allocated per iteration, in both
versions. This is not an allocation claim for complete lighting draws. Cold
allocation, full draw validation, GPU work, presentation and shader time are not
included. The unchanged cases show no timing improvement; the gain is in reusing
proofs during geometry edits. These regular strips preserve section boundaries.
Topology changes and new section merges can still require quadratic work, bounded
by the 512-triangle limit. Do not extrapolate these timings to arbitrary animated
meshes or game frame rates.

Raw results: [before](2026-11-23-mesh-preparation-before.csv),
[after](2026-11-23-mesh-preparation-after.csv).

## Correctness

The CPU-only `lighting_mesh_cache` test performs 12,215 checks. Across 400
successive edits it compares retained analysis against a fresh analyzer, covering
section splits/merges, overlaps, changed UVs, reordered/duplicate indices, unchanged
repeats and recovery from repeated late UV failures.

The pixel suite now has 141 checks, retaining the two-channel-unit RGBA tolerance
against a triangle-only provider whose mapping is computed independently. Added
checks cover repeated late UV failures, repaired geometry and changed lighting
transforms that overflow after a cache hit. Existing normal/material/shadow,
section-ordering, cache-growth and provider-rejection comparisons remain in place.

[Rendering results](../validation/2026-11-23-mesh-preparation.csv) record the mesh,
material and scene-lighting suites on Metal, OpenGL, D3D9 and D3D11. Windows runs
use x64 applications on ARM64 Parallels; they are correctness checks, not Windows
performance measurements. No Linux or native Windows hardware timing is claimed.

## Remaining whole-mesh work

Arbitrary deformation still draws individual triangles when mappings differ.
A general native path must transport lighting positions and per-triangle normal
bases, use bounds for the complete receiver, and negotiate all required groups
before drawing so a rejected material/light can safely use the ordered fallback.
Cached preparation is groundwork for that path, not completion of it.
