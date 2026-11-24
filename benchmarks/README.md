# Renderer benchmarks

Build from the BlitzMax SDK directory, in release mode:

```sh
./bin/bmk makeapp -r -o /private/tmp/max2d-benchmark mod/max2d.mod/benchmarks/renderer.bmx
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software /private/tmp/max2d-benchmark 120
SDL_RENDER_DRIVER=metal /private/tmp/max2d-benchmark 120 /absolute/path/to/font.ttf
```

The second argument is optional. Supply the same font file for comparable scalable-text results. SDL must support the requested renderer on the host. The output identifies the renderer actually selected. Redirect stdout to a CSV file; metadata lines start with `#`. A successful run ends with `# benchmark complete`; failures return exit code 1.

Each case creates a fresh 640×480 window, warms up for 20 frames, then measures the requested number of frames. No external assets are required except the optional font. Run at least three times, with the same build, display configuration, font, and renderer, before claiming a timing improvement. Keep competing workloads off the machine. Software with the dummy video driver is a useful repeatable baseline; it does not predict GPU performance.

## Workloads

For scene lighting materials and increasing mesh triangle counts, see the
[material/geometry workload and measurements](../docs/scene/benchmarks/2026-11-23-material-geometry.md).
`material_geometry.bmx` compares warmed and edited maps, shared materials,
fixed-area meshes and isolated CPU packing, with optional asynchronous GPU queries
and resource cleanup assertions.
The [native-material refresh and allocation attribution](../docs/scene/benchmarks/2026-11-23-material-refresh.md)
compares `--packed` with native sampling and `--large-maps` with the default size.
`render_allocations.bmx` isolates warmed scope, scene and text allocations.
The [retained-snapshot follow-up](../docs/scene/benchmarks/2026-11-23-state-reuse.md)
records the first production scene allocation reduction.
The [text-cache follow-up](../docs/scene/benchmarks/2026-11-23-text-cache.md)
records allocation-free cache hits for bitmap and scalable fonts.
`tests/scene_workload.bmx --trials-only` reports allocation by phase without running
the long soak.
The [affine mesh follow-up](../docs/scene/benchmarks/2026-11-23-affine-mesh.md)
records the same workload after whole-mesh grouping for eligible geometry.

- `sprites_separate` / `sprites_atlas`: identical positions and order, 4,096 sprites, 64 images. Measures texture switches versus shared atlas batching.
- `text_cached` / `text_changing`: 80 labels; changing labels include a frame counter and therefore also draw more characters. These represent different workloads, not an isolated cache microbenchmark.
- `atlas_one_edit` / `atlas_two_edits`: update one or two adjacent 16×16 entries before drawing, including their one-pixel filtering borders.
- `target_alpha` / `target_solid`: eight target writes and composites per frame. SOLID may require an additional cached representation and readback in the SDL backend.
- `text_density_changes`: cycles through 1×–4× presentation scales, using the optional scalable font. These are simulated scale changes, not physical monitor moves. The default raster cache retains these variants after warmup.
- Resource cycles: twelve rounds of two simultaneous windows sharing one image, including reselecting the first window and closing both. Checks that closed contexts retain no registered native frames, and reports GC heap size after collection.

## Reading results

Times use SDL's high-resolution performance counter. `draw_submit_mean_ms` includes clear, drawing, and an explicit Max2D flush; `present_mean_ms` includes `Flip(0)`. Median and p95 cover both. Neither interval is a GPU execution timer: drivers can defer work or block in either interval. `Flip(0)` requests no vsync, but compositor/display pacing can still dominate. No pixel readbacks are inserted into the ordinary frame timing loop.

Counters are cumulative differences over the measured interval, excluding setup and warmup. Submissions are **Max2D geometry submissions**, not guaranteed GPU draw calls. Upload pixels count core texture uploads, including padded bounds, not driver bandwidth. For RGBA source data, multiply by four for source bytes. Backend conversion textures/readbacks are not included in these counters.

`gc_heap_delta_bytes` and resource-cycle heap sizes use `GCMemAlloced()`. With the current Boehm runtime this is reserved GC heap size, **not live object bytes, RSS, or GPU memory**. Collections can shrink it and produce negative deltas; a stable value does not establish absence of leaks. Context frame-registry cleanup is a separate deterministic check. Native memory profiling remains necessary for a complete GPU/driver memory audit.

The C helper only exposes timing and renderer identification; scene code uses the public Max2D API, apart from inspecting context cleanup and identifying the SDL renderer. OpenGL uses the same workloads with its own timing and renderer-name adapter.

## OpenGL

Build the same source with `-ud max2d_gl` to select `Max2D.GLMax2D` and its
monotonic OS timer adapter (no SDL imports):

```sh
./bin/bmk makeapp -r -ud max2d_gl -o /private/tmp/max2d-gl-benchmark mod/max2d.mod/benchmarks/renderer.bmx
/private/tmp/max2d-gl-benchmark 120 /absolute/path/to/font.ttf
```

The GL renderer name is printed in each case. See
[the OpenGL guide](../docs/opengl-backend.md) for the initial capture and limits.

## Snowfall frame pacing

See [Snowfall timing](../docs/snowfall-pacing.md) for bounded timer/VSync
comparisons, raw captures and the distinction between CPU timing and visible
presentation cadence.

## Native SDL GPU comparison

`gpu_comparison.bmx` uses the same deterministic scenes for SDL_Renderer and
native SDL GPU. Build both executables in release mode, sequentially:

```sh
./bin/bmk makeapp -r -o /tmp/max2d-compare-renderer mod/max2d.mod/benchmarks/gpu_comparison.bmx
./bin/bmk makeapp -r -ud max2d_sdlgpu -o /tmp/max2d-compare-native mod/max2d.mod/benchmarks/gpu_comparison.bmx
python3 mod/max2d.mod/benchmarks/compare_gpu.py \
  --renderer-exe /tmp/max2d-compare-renderer \
  --native-exe /tmp/max2d-compare-native \
  --output /tmp/max2d-comparison
```

Defaults compare SDL_Renderer Metal, SDL_Renderer GPU, and native Metal on macOS.
Use `--renderer` and `--gpu-driver` to request different host drivers; executable
paths are supplied explicitly. This runner does not build applications or configure
VM access. Each capture identifies its renderer/native driver and physical drawing
resolution. A rejected driver fails the run; inspect the metadata before comparing
results. `renderer-default` in filenames denotes the `--renderer` choice.

Workloads use a procedural 32×32 soft particle and identical linear filtering,
without mipmaps, text overlays or external assets:

- `snow`: 1,000 small additive particles with deterministic motion and size changes,
  inspired by Snowfall. This is not a timing capture of the original sample.
- `atlas`: 10,000 alpha-blended sprites using 64 regions of one atlas.
- `switches`: 4,096 alpha-blended sprites alternating 64 separate textures.

Every case uses an 800×600 window and virtual resolution, 120 warm-up frames and
360 measured frames by default. Three repetitions rotate backend order. All
scenes use `Flip(0)`; a separate `snow` case uses `Flip(1)`. No software frame timer
is requested. Event handling, simulation, drawing, flush and presentation are
included. Frame arrays are allocated before warm-up; logs are written afterwards.
GC is collected before measurement and otherwise retains its normal behaviour.

The runner preserves per-frame CSVs, stderr and a JSON summary with median, p95,
p99, maximum, and the count exceeding 1.5× that run's median. That last count is a
relative long-frame indicator, not a count of missed display refreshes. Inspect
individual repetitions rather than treating every frame as an independent trial.

These are CPU wall-clock frame intervals, not GPU timestamps or measured on-screen
presentation intervals. A compositor can pace `Flip(0)` as well as `Flip(1)`.
`FlushMax2D` has different submission boundaries across backends; compare complete
frame times, not the draw/flip split alone. Submission counts are Max2D geometry
batches, not hardware draw-call counts. Window blits and driver-internal work are
not included in those counts.

The comparison records SDL window visibility flags on every frame and rejects
a capture containing occluded, hidden or minimized frames. Keep the display awake
and the test windows visible. A visibility check cannot detect every compositor
or display-state change; implausibly short VSync intervals still require review.

See the [initial macOS comparison](../docs/native-gpu-performance.md) for results,
raw captures and the presentation-pacing limits of this test.

## Image effects

Build `image_effects.bmx` with the SDK's `bmk makeapp -r -t console` and run
the resulting executable with an optional measured-frame count (default 120,
minimum 100). It requires native SDL GPU and the optional SDL3GPUEffects module.
Keep its window visible. Each case warms for 30 frames and uses `Flip(0)`.

The CSV compares a cached layer, that layer drawn through saturation, and a layer
redrawn and alpha-masked before saturation, at 128 and 512 pixels square. It also
compares two-pass blur rebuilt every frame against drawing its cached output. It records
CPU draw/whole-frame means, whole-frame p95, geometry submissions, texture creation,
pixel uploads, readbacks and logical RGBA retained-image bytes. Blur cases retain
the layer, mask and two outputs (four images); other cases retain two. Memory excludes
driver alignment, the window backing surface and shared geometry buffers. The
timings are CPU wall-clock intervals, not GPU timestamps; compositor pacing can
dominate even with `Flip(0)`. See [effects and masking](../docs/effects-and-masking.md)
for the operations and their batching limits.

## Scaled blur

Build `scaled_blur.bmx` with the native SDL GPU backend. It prints CSV for 256²
and 512² layers at full, half and quarter resolution, rebuilding or drawing cached
outputs. Each case has 20 warm-up and 60 measured frames. Radii are 4, 8 and 16
respectively, so these cases demonstrate wider effects rather than equal output.
`retained_bytes` counts source, destination, reduction levels and scratch at
RGBA8 size. Counters include the final display draw. Timings measure CPU
whole-frame duration, including presentation; they are not GPU timings or proof
of a speedup. Run with the window visible and without another local graphics test.

## Cached effects

`cached_effects.bmx` compares source-only, cached and rebuilt soft shadows, inner
shadows and bloom at 128² and 512² with RGBA16F buffers. Optional arguments are
measured frames (default/minimum 100) and repetitions (default 2). Every case has
30 warm-up frames, and alternate repetitions reverse case order. It checks the
expected steady-state submission counts and zero texture churn/readback. Keep
its window visible. See the [gallery and benchmark guide](../docs/effects-gallery.md)
for scene definitions, memory accounting and timing limitations.

Reference CPU captures are available for [image effects](../docs/effects-macos-smoke.csv),
[small blur](../docs/blur-macos-smoke.csv), scaled blur on
[macOS](../docs/scaled-blur-macos-smoke.csv),
[Windows](../docs/scaled-blur-windows-smoke.csv) and
[Linux](../docs/scaled-blur-linux-smoke.csv), and
[cached helpers](../docs/cached-effects-macos.csv). Treat these as sample data
for the documented workloads, not cross-device GPU performance guarantees.

## Lighting

`lighting.bmx` exercises 1/4/8/9/16 point lights, 1/64 receivers covering the same
768×512 area, 16 finite-height casters, no/hard/filtered shadows, and static or
moving-light configurations. Shadow resolution is 256; filtered radius is 3.
Only the first light moves, measuring independent shadow invalidation
against static-light reuse. The artwork is procedural and uses flat diffuse materials. This benchmark
does not measure directional lights, scene traversal or scene caches. Use
`--normal` to include normal maps and specular highlights.

```sh
./bin/bmk makeapp -r -ud max2d_sdlgpu -o /private/tmp/lighting-benchmark mod/max2d.mod/benchmarks/lighting.bmx
/private/tmp/lighting-benchmark > lighting.csv
```

Use `-ud max2d_gl`, `-ud max2d_d3d9` or `-ud max2d_d3d11` for those backends.
SDL3 supplies the monotonic timer on every profile. `--quick` runs three warmup
and five measured frames for a smoke check; normal runs use 20 warmup and 60
measured frames per case. The window shows the active workload. CSV counters are
totals over measured frames; divide by `frames` for per-frame counts. Shadow and atlas bytes
are retained sizes at the end, not cumulative totals.

`mean_cpu_ms` includes drawing, the unlit HUD, presentation and any driver
back-pressure. It does not force GPU completion or measure GPU execution. No
pixel readbacks are inserted. Texture creations should be zero after warmup.
Run multiple times in a quiet desktop session and record backend, hardware and
display configuration before comparing timings. VM results and quick runs are
functional checks, not hardware performance limits.

The [initial lighting diagnostic report](results/lighting-2026-11-22.md)
records work counts, retained storage and timing limitations from a Metal run.
The [independent-shadow follow-up](results/lighting-independent-shadows-2026-11-22.md)
records the reduction from sixteen mask rebuilds to one when only one light moves.


### Grouped-light comparison

Pass `--grouped` to enable native light groups and paired compatibility fallback
(`--paired` remains an alias). Add `--normal` for normal-mapped artwork with
specular highlights. Add `--patterns` to project a shared filtered colour/alpha
image from every light. Run the same binary
with and without it, keeping all other arguments and display conditions fixed:

```sh
/private/tmp/lighting-benchmark > baseline.csv
/private/tmp/lighting-benchmark --grouped > grouped.csv
```

The `grouped`, `normal_mapped` and `patterns` columns record those settings.
`light_contributions`, `grouped_passes` and `paired_passes` distinguish applied
lights from completed submissions. `mean_draw_cpu_ms` covers the frame's
CPU work before presentation, including light movement, drawing and the HUD;
`mean_present_cpu_ms` covers `Flip(0)`. Their sum is `mean_cpu_ms`. Drawing can
still block on the driver and neither interval is a GPU timestamp. Repeat the
comparison to distinguish changes from scheduling noise. Work counters and
texture storage are measured over the same interval as before.

See the [paired-light results](results/lighting-paired-2026-11-22.md) for repeated
Metal measurements and the prototype’s scope.

See the [native grouped-light results](results/lighting-native-groups-2026-11-22.md)
for repeated normal/specular measurements.

`map_uploads`, `map_hits` and `map_bytes` report shared renderer storage. In a
warm static grouped-shadow workload, uploads should be zero. Moving only the
first light should produce one upload per measured frame, unless the workload
exceeds atlas capacity and forces tile reassignment. `map_bytes` is additional
to `shadow_bytes`; the default native atlas occupies 16 MiB.

See the [grouped-shadow results](results/lighting-grouped-shadows-2026-11-22.md)
for pass reductions, map-update counts and timing comparisons.

With `--patterns`, moving a light without shadows changes only its projection: warm
atlas uploads remain zero. With shadows enabled, the moving light rebuilds its
combined shadow/pattern image and uploads one map per frame.

See the [grouped-pattern results](results/lighting-grouped-patterns-2026-11-22.md)
for pattern filtering coverage, pass counts and cache behaviour.

The `ambient_passes` and `combined_ambient_passes` columns distinguish separate
ambient draws from first-group composition. `lighting_submissions` is
`ambient_passes + light_passes - combined_ambient_passes`, excluding the HUD and
shadow preparation. This measures the extra saving from combining ambient;
`light_passes` retains its existing direct-light meaning.

See the [combined-ambient results](results/lighting-combined-ambient-2026-11-22.md)
for measured submission savings and composition coverage.

Use `--batch-limit=8` or `--batch-limit=16` with `--grouped` to compare native
capacities; the default limit is 16. The `batch_limit` column records the
requested maximum, and the renderer may choose a smaller supported capacity.
The benchmark covers 1, 4, 8, 9 and 16 lights, one/64 receivers, static/moving
lights and absent/hard/filtered shadows: 60 workloads per run. Short groups use
the eight-light shader under either limit; single-light groups include ambient.

See the [sixteen-light results](results/lighting-sixteen-lights-2026-11-22.md)
for capacity comparisons, timing limitations and backend validation.

### Group utilisation and negotiation

The lighting CSV includes `grouped_light_contributions`, `ordinary_light_passes`,
`maximum_group_size`, `group_support_checks` and `group_support_rejections`.
Divide grouped contributions by `grouped_passes` (when nonzero) for average
lights per group. Maximum size is the largest completed group in the measurement
interval, not a sum or a reported hardware limit. Other new columns are cumulative
counts across measured frames.

Use these alongside `batch_limit` to distinguish sparse receiver selection from
capacity-limited groups. Ordinary passes include disabled batching and flattened
updates as well as unsupported groups. Support rejections count failed `Supports`
queries, including prefix retries; capability exclusions happen before this query
and are not counted. A rejection can still lead to a successful smaller group.

For example, the static, unshadowed 16-light/64-receiver workload with normal maps
and patterns measured 480 contributions per frame on Metal. An eight-light limit
used 88 groups (5.45 lights/group, maximum 8); sixteen used 64 groups (7.5
lights/group, maximum 12). Both had zero support rejections and zero ordinary
passes. The observed maximum of 12 reflects receiver bounds, even though the
renderer supports sixteen. These counters explain the submission reduction
without implying that every receiver sees every scene light.

## Spatial light selection

`light_selection.bmx` compares linear and indexed selection with 32, 256 and
1,024 shuffled lights, 64 receivers, and static or moving geometry. It warms ten
iterations and measures thirty. CSV timings include light setup and CPU drawing
submission/back-pressure; they exclude presentation and are not GPU timestamps.
Counts are reported per iteration. The receivers share a small output target,
using different world transforms to query the sparse light field.

```sh
bmk makeapp -r -o /tmp/light-selection benchmarks/light_selection.bmx
/tmp/light-selection
```

The default is SDL3 GPU; add `-ud max2d_gl` when building for OpenGL. Compare
individual light tests, hierarchy-node tests and rebuilds alongside timings.
Use the main lighting benchmark for rendering-heavy workloads. This sparse test
is not representative of dense overlapping lights or overall application FPS.

### GPU lighting intervals

Build the lighting benchmark with `-ud max2d_gl`, `-ud max2d_d3d9` or
`-ud max2d_d3d11`, then add `--gpu` to collect asynchronous elapsed-GPU intervals. GPU columns explicitly report support,
completed/pending samples, rejected starts and discarded unreliable samples. Unsupported backends and missing
samples emit `unavailable`, not a substituted CPU measurement. The interval
includes clear, lighting, shadows and HUD, excluding presentation. See the
[profiling guide](../docs/gpu-profiling.md) for queue lifetime, instrumentation
overhead and incomplete-sample caveats. `--quick --gpu` checks functionality;
use longer repeated runs with matching sample coverage for comparisons.

The [initial GPU timing smoke report](results/lighting-gpu-smoke-2026-11-22.md)
records the initial OpenGL/SDL GPU coverage. The [Direct3D smoke report](results/lighting-gpu-d3d-smoke-2026-11-22.md)
adds D3D9/D3D11 sample accounting and device-reset/replacement checks.

### Mesh preparation

`mesh_preparation.bmx` isolates CPU geometry analysis without opening a window.
It compares warm meshes, per-iteration translations and bent strips at 128 and
512 triangles. Each case performs 20 warm-up iterations followed by three trials
of 1,000 iterations, reporting time, managed allocation and section counts.
Reported time includes the coordinate edits. It excludes drawing, shader work,
frame validation and cold storage allocation.

```sh
bmk makeapp -r -o /tmp/mesh-preparation benchmarks/mesh_preparation.bmx
/tmp/mesh-preparation
```

The benchmark includes the internal mesh analyzer used by lighting; it is not an
example of a public application API. See the [dated results](../docs/scene/benchmarks/2026-11-23-mesh-preparation.md)
for the baseline comparison and limits.

### Deformed mesh drawing

`deformed_mesh.bmx` compares a triangle-only provider with the general whole-mesh
provider in the same build. Both use the same native shaders and a 128-triangle
receiver with 17 point lights, normal/specular shading and mapped emission.
Pixel comparisons run before each trial. Warm and edited geometry each have three
trials of 120 frames after eight warm-up frames.

```sh
bmk makeapp -r -ud max2d_sdlgpu -o /tmp/deformed-mesh benchmarks/deformed_mesh.bmx
/tmp/deformed-mesh
```

Use `max2d_gl` for OpenGL. `path=0` is the triangle-only provider; `path=1` enables
general deformation. CPU draw time includes clearing, lighting and flushing;
drained time also waits for a one-pixel readback after each frame. Coordinate
edits occur before the timed interval. These are not GPU-query or game-FPS
measurements. See the [dated results](../docs/scene/benchmarks/2026-11-23-deformed-mesh.md).

## Scene render allocation detail

Pass `--allocation-detail --trials-only` to `tests/scene_workload.bmx` to separate
lit-receiver draws, bloom updates and alpha-mask updates from other render
allocations. Counter reads add timing overhead, so use ordinary runs for timing
comparisons. Without detail mode, component columns are zero (unmeasured).
See the [render attribution and mask-scope report](../docs/scene/benchmarks/2026-11-23-render-attribution.md)
for before/after measurements and interpretation.

The [effect-view and provider-lookup follow-up](../docs/scene/benchmarks/2026-11-23-effect-view-reuse.md)
uses the same detailed workload after removing provider iterators and replacing
per-pass full state saves with target-view value snapshots.

The [light-atlas copy follow-up](../docs/scene/benchmarks/2026-11-23-atlas-state-reuse.md)
measures retained atlas drawing state and zero allocations for warmed map copies.

The [shadow-state follow-up](../docs/scene/benchmarks/2026-11-23-shadow-state-reuse.md)
removes the remaining measured receiver allocation: 736 to zero bytes/frame,
including two changing hard-shadow maps. Combined allocation falls to 2,640 on
Metal and OpenGL; cached rendering remains 32 bytes/frame.

The [bloom/blur state follow-up](../docs/scene/benchmarks/2026-11-23-processor-state-reuse.md)
reduces bloom allocation from 1,104 to 368 bytes/update and combined workload
allocation from 2,640 to 1,904 bytes/frame on Metal and OpenGL. Extraction retains
one scope; masking remains at 736 bytes/update.

The [retained chain/mask follow-up](../docs/scene/benchmarks/2026-11-23-chain-mask-state-reuse.md)
reduces measured bloom allocation to zero and masking to 368 bytes/update. Combined
allocation falls from 1,904 to 1,168 bytes/frame on Metal and OpenGL. The standalone
ApplyLayerEffects function retains its caller scope; buffer-owned chains reuse state.

The [layer-alpha follow-up](../docs/scene/benchmarks/2026-11-23-layer-operation-state.md)
reduces measured mask application to zero and combined allocation to 800
bytes/frame on Metal and OpenGL. Detailed CSVs now append
`mask_prepare_bytes_per_frame`; other-render excludes that measured component.
Mask preparation accounts for 368 bytes on changing-mask frames, leaving 432
bytes of other render work during recapture.

The [capture follow-up](../docs/scene/benchmarks/2026-11-23-capture-state-reuse.md)
removes mask-preparation allocation and reduces capture cost to 160 bytes/call
while preserving independent public handles and saved entries. Combined allocation
is 224 bytes/frame; cached and mask-only cases are 32 on Metal and OpenGL.

The [state-reuse validation](../docs/scene/benchmarks/2026-11-23-state-release-validation.md)
records 32 passing VM runs across Ubuntu SDL GPU/OpenGL and Windows Direct3D 9/11,
plus full 60,000-frame Metal and OpenGL soaks with constant post-GC heap usage.
Alternating baseline/current timing trials show a modest Metal CPU-submission
benefit; OpenGL and broader GPU-drained timings remain inconclusive. Raw trials,
soaks and executable hashes are included.
