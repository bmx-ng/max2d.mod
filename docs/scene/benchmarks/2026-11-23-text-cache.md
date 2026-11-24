# Allocation-free layout-cache hits — 23 November 2026

Bitmap and scalable fonts now share layout-cache lookup and insertion helpers.
A cache hit moves the existing list entry to the most-recently-used position,
without allocating a replacement link or scanning the eviction list. A bounded
map indexes those links by text. This adds retained bookkeeping per cached key;
entries are removed on eviction, shrinking and clearing. No BRL changes are needed.

The public `Layout` behavior is unchanged: repeated keys return the same layout,
least-recently-used entries are evicted, zero capacity disables caching, and held
layouts remain valid after eviction or clearing. Both font implementations use the
same path, including empty text and shaped scalable layouts.

## Allocation results

Release builds on the same macOS arm64 host and workload as the
[snapshot follow-up](2026-11-23-state-reuse.md). Metal and native OpenGL returned
identical allocation counts in all three trials.

| Operation | After snapshot reuse, bytes | After text-cache reuse, bytes |
| --- | ---: | ---: |
| Empty or single-sprite scene, per call | 32 | 32 |
| Eight cached text nodes, per call | 288 | 32 |
| Full cached workload, per frame | 288 | 32 |
| Mask-changing workload, per frame | 2,128 | 1,872 |
| Lighting-changing workload, per frame | 10,464 | 10,208 |
| Combined workload, per frame | 10,832 | 10,576 |

The eight cached labels no longer add 256 bytes/frame. Across the snapshot and
text-cache changes, the cached workload falls from 624 to 32 bytes/frame (95%).
The remaining 32 bytes are the drawing-state stack link. Public state scopes
still allocate 368 bytes/call in the isolated probe. Changing lighting/effects
still allocate substantially more and need further attribution.

Editing, preparation and picking remain allocation-free in the measured workload.
All graphics runs passed warm-texture and resource-cleanup checks. These are
managed allocation measurements, not frame-rate or GPU-throughput claims.
Windows/Linux and a new 60,000-frame soak were not run for this tranche.

| Backend | Isolated probes | Full workload |
| --- | --- | --- |
| Metal | [CSV](2026-11-23-text-cache-allocations-sdlgpu.csv) | [CSV](2026-11-23-text-cache-scene-sdlgpu.csv) |
| OpenGL | [CSV](2026-11-23-text-cache-allocations-gl.csv) | [CSV](2026-11-23-text-cache-scene-gl.csv) |

Use the [baseline build commands](2026-11-23-material-refresh.md#reproduce),
then run each allocation executable without arguments and each scene workload
with `--trials-only`, sequentially. Probe trials use 2,000 calls after 32 warmups;
scene trials use the existing three 120-frame trials per case.

## Correctness and allocation regression

`tests/layout_cache.bmx` checks forward and backward LRU order, stable list-link
identity, first/middle/last hits, eviction, replacement, shrinking, empty strings,
disabled caching, invalid limits, clearing and refilling. Its mixed eight-key
warm loop performs 16,000 hits per font and asserts zero managed allocations and
zero layout builds. The alternating keys ensure a last-key-only shortcut would
not satisfy the test.

Both release and debug builds pass 222 checks across the built-in bitmap font and
scalable Noto Sans Bold, with zero warm-hit allocations for each. The font file
used was the SDK's HarfBuzz `test/api/fonts/NotoSans-Bold.ttf` fixture. The existing
synthetic shaping/layout regression passes. The OpenGL scalable-text regression
also passes, covering actual pixels, shaping, density changes and retained layouts
after glyph-cache clearing.

From the SDK directory, build and run the headless cache regression with:

```sh
bin/bmk makeapp -r -o /tmp/layout-cache mod/max2d.mod/tests/layout_cache.bmx
/tmp/layout-cache /absolute/path/to/font.ttf
```

Omit `-r` (or use `-d`) for a debug build. Without a font argument, the test runs
the bitmap cases only. Supply an absolute font path.

## Custom font implementations

Derived fonts can use `FindCachedLayout(text)` to look up and touch an entry, and
`CacheLayout(text, layout)` to retain a newly built layout. The latter respects
capacity and does not increment `layoutBuilds`; the font increments its build
counter when it constructs a layout. Use `SetLayoutCacheLimit` and
`ClearLayoutCache` to manage storage. Treat `layouts` and `layoutKeys` as inspection
views so the cache index stays consistent. A first helper lookup can adopt an
entry inserted by an older derived implementation; that adoption may allocate.
