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
