# Initial performance baseline — 2026-09-20

Release ARM64 build, macOS 15.7.4 (24G517), bundled SDL 3.4.16.
Software uses SDL's dummy video driver; Metal uses native windows. Each workload
has 20 warmup frames and 120 measured frames. Scalable text uses the existing
NotoSans-Regular.ttf from `imgui.mod/imhtml.mod/imhtml/fonts` (not bundled here).

Raw captures:

- [Software before upload fix](../benchmarks/results/2026-09-20-before-software.csv)
- [Software after fix](../benchmarks/results/2026-09-20-software.csv)
- [Metal after fix](../benchmarks/results/2026-09-20-metal.csv)

The before capture predates the resource-cycle workload and the movement of the
timing-array allocation before the initial GC heap sample. Do not compare its
heap deltas with the final captures. Scene timing and upload counts are comparable.
These are initial individual captures, not statistically established speedups.
See [methodology and limitations](../benchmarks/README.md).

## Findings

### Sprite batching works

For 4,096 sprites, separate textures require 4,096 geometry submissions per frame;
one shared atlas requires four (the vertex buffer holds 8,192 vertices, and each
sprite needs six). On the recorded software run, median frame time was 1.794 ms
for separate textures versus 0.933 ms for the atlas. Both execute the same sprite
order and positions; batching does not reorder transparent draws.

### Multiple edits exposed an avoidable full-page upload

Two adjacent 16×16 edits previously advanced the source version twice, causing
an existing texture to fall back to a complete 512×512 upload. Frames now accumulate
the union of pending padded edit bounds independently for each rendering context.
New textures still receive a full initial upload.

| Per measured frame | Before | After |
| --- | ---: | ---: |
| Uploaded source pixels | 262,144 | 648 |
| RGBA source bytes | 1,048,576 | 2,592 |
| Upload operations | 1 | 1 |

That is approximately **405× less source pixel data** for this workload, not a
405× frame-time improvement. The software median changed from 0.206 ms to
0.178 ms in the stored captures. Presentation and unrelated work still contribute.
Distant edits can produce a large union; this deliberately uses one bounded
rectangle per frame rather than an unbounded edit journal.

`tests/dirty_regions.bmx` verifies exact padded bounds, a second context lagging
behind, preservation of earlier edits, and updated pixels. It passes on software
and Metal. Existing integration tests also pass on software.

### Text and targets identify useful future profiling areas

Cached labels had a 0.890 ms software median; changing labels had 1.914 ms.
Changing labels are longer, so this does not isolate layout-cache overhead.
The scale-cycling font workload created no textures or uploads after warmup,
showing reuse of the retained 1×–4× raster variants for this glyph set.

Eight render-target composites per frame had software medians of 0.654 ms with
ALPHA and 1.103 ms with SOLID. The backend's straight/premultiplied conversion
path is a candidate for focused profiling. No change to blend semantics was made
based on this baseline. Internal conversion readbacks and textures are currently
outside the core counters.

### Resource cleanup and timing limits

All twelve two-window cycles finish with empty native frame registries for both
closed contexts. GC reserved heap fluctuates and then stabilizes within these
short runs. This is not proof that all native allocations are leak-free; driver
and GPU memory require a separate profiler.

Metal frame/presentation timings are strongly variable on this desktop, even
with `Flip(0)`. Compare submission/upload counts first, and use repeated captures
and GPU profiling before optimizing small timing differences. This suite is a
baseline for future GL/GPU backend comparisons, not a renderer ranking.
