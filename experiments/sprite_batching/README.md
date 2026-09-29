# Compact GPU sprite experiment

This is an isolated macOS/Metal prototype. It does not change the production
Max2D submission path or select a different default renderer.

The question is whether sending a compact rectangle description to the vertex
shader is worth integrating into Max2D.Core. Both paths use SDL3's GPU API and
the production GPU backend's fragment shader. The expanded path uploads six
32-byte vertices per sprite; the compact path uploads one 64-byte record and
uses the vertex ID to generate the six corners in the shader.

The record stores an origin, two affine basis vectors, a UV rectangle and colour.
It handles shear and reflections as well as rotation. The CPU still computes
those basis vectors: repeating sine/cosine work for every vertex is unnecessary.
There are no new production dependencies or public APIs.

## Running on macOS

With this repository installed as `mod/max2d.mod` inside the SDK:

```sh
sh experiments/sprite_batching/build.sh
MAX2D_PROBE_INFLIGHT=3 experiments/sprite_batching/sprite-probe.app/Contents/MacOS/sprite-probe > results.csv
```

Run from the repository root. `build.sh` uses the SDK's `bin/bmk` and bundled SDL3
headers. The temporary object file is built explicitly so the standalone
experiment does not need changes to module compiler options. Nothing is installed.

The window exists to initialise the GPU backend; all measured rendering goes to
a 512 × 512 offscreen texture. VSync and window presentation are not timed.
The default in-flight limit is one; set the environment variable to three to
allow CPU/GPU overlap. Each group is drained before its timing interval.

## Method

- Counts: 1,000, 10,000 and 40,000 rectangles.
- Coverage workload: synthetic 8 × 12 quads sampling an R8 alpha texture. This
  models glyph submission, not font shaping or actual text layout.
- Sprite workload: 16 × 16 quads with quarter-turns, reflections and shear.
- Tile workload: 32 × 32 quads. Larger overlapping coverage makes this workload
  more sensitive to fragment processing and blending.
- Both paths preserve order, sample identical textures, use the same premultiplied
  alpha blending and perform one draw per frame.
- Colour, alpha and atlas selection vary by sprite. Geometry moves between frames.
- Before timing, compare every RGBA pixel exactly for both paths with a scissor
  rectangle. All nine scene/count comparisons must match.
- Five warmup frames per path, 30 timed frames per trial, four trials with
  alternating path order. Repeat the full executable three times.
- `pack_ms`: CPU time to build the upload data from common precomputed sprite
  inputs. Allocation is outside timing.
- `submit_ms`: CPU time for transfer mapping/copying and command recording/submission.
  It can include driver backpressure and is not GPU execution time.
- `completed_ms`: wall time divided by frame count, including waiting for all work
  to finish every one or three frames. With three frames in flight this measures
  amortised throughput, not individual frame latency or isolated GPU time.
- `upload_bytes`: geometry transfer size only, excluding uniforms and textures.

## Initial results

Apple M4 Max, macOS, SDL Metal backend, release C compiled with `clang -O3`.
The three checked-in CSV files use three frames in flight. Values below are
medians of 12 trial averages (four per run), in milliseconds per frame.

| Workload | Count | Expanded completed | Compact completed | Reduction |
| --- | ---: | ---: | ---: | ---: |
| Coverage quads | 1,000 | 0.1012 | 0.0936 | 7.5% |
| Coverage quads | 10,000 | 0.1748 | 0.1256 | 28.2% |
| Coverage quads | 40,000 | 0.4754 | 0.2256 | 52.5% |
| Sprites | 1,000 | 0.0826 | 0.0772 | 6.6% |
| Sprites | 10,000 | 0.1605 | 0.1151 | 28.3% |
| Sprites | 40,000 | 0.5038 | 0.3129 | 37.9% |
| Tiles | 1,000 | 0.0739 | 0.0731 | 1.1% |
| Tiles | 10,000 | 0.2366 | 0.1985 | 16.1% |
| Tiles | 40,000 | 0.7694 | 0.6674 | 13.3% |

At 40,000 items, geometry uploads fall from 7,680,000 to 2,560,000 bytes per
frame. CPU packing falls from about 0.26 ms to 0.058 ms (roughly 78%). All nine
pixel comparisons passed on every run.

The smaller workloads show small absolute differences; these are not universal
speedup guarantees. Reusing existing vertices, multi-texture draws, application
logic and other costs can change the outcome. No statistical confidence interval
or isolated GPU timestamp measurements are provided.

## What this establishes—and what remains

This supports continuing with an integrated, opt-in rectangle path. It does not
benchmark the existing BlitzMax calls, scene traversal or current backend's
multi-batch command collector. Both comparison paths here use the same small C
harness to isolate geometry representation, rather than comparing the full
production backend against an artificially simpler implementation.

Before making it a default:

1. Add an optional compact-rectangle submission contract to Core, with triangle
   fallback for existing backends. Do not reconstruct rectangles from triangles.
2. Preserve draw order when mixing rectangles, meshes, text and target changes.
   Keep atlas frame changes, clipping, texture updates and mipmap dependencies correct.
3. Preserve arbitrary affine transforms, pixel-aligned glyphs, trim offsets and
   per-vertex features that require a triangle fallback.
4. Add equivalent SPIR-V and DXBC shaders; validate Vulkan and D3D12 as well as Metal.
5. Run end-to-end Max2D pixel comparisons and application benchmarks, including
   text, tilemaps, render-to-texture work and a workload with many small batches.
6. Measure allocations and transfer volume, and ensure small scenes do not regress.

The idea follows [Moonside's sprite batcher article](https://moonside.games/posts/sdl-gpu-sprite-batcher/).
Metal shader resource bindings follow [SDL's GPU shader conventions](https://wiki.libsdl.org/SDL3/SDL_CreateGPUShader).
