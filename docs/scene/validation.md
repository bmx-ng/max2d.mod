# Scene platform validation

Scene regressions exercise tree ownership, transforms, input routing, rendering,
compositing, storage budgets and inspection. The worked examples also provide
`--test` modes using their real scene components. Passing these checks is not a
substitute for testing native touch hardware or a production game.

## Release checks — 24 November 2026

The [release review](benchmarks/2026-11-24-release-review.md) completes the latest
shared-source preparation platform checks: **32 passing runs**, 1,162 assertions
and four three-frame example runs on Ubuntu SDL GPU/OpenGL and Windows D3D9/D3D11.
It also records the 632-routine public bbdoc audit and 12,480 corrected Metal/OpenGL
scaling frames. These extend the matrices below; earlier results retain their
original source revisions and scope.

## Shared source preparation — 24 November 2026

The [local matrix](validation/2026-11-24-source-preparation.csv) records 582
assertions across 14 passing Metal/OpenGL runs. This adds 17 preparation checks
per backend to the live-mask, selected-capture, composite, alpha-mask, culling and
storage suites. Shared/overlapping sources, continuous rendering, scene migration,
cycle rejection and retry are covered. The
[measurement report](benchmarks/2026-11-24-source-preparation.md) records an
additional 43,680 current-build scaling frames and alternating baseline timing.
Windows/Linux coverage was subsequently completed in the release checks above.

## Live subtree masks — 23 November 2026

Tested source: `63e0b4f` on `task/scene-design`, with explicit D3D9/D3D11
profiles added to the live-mask example. All **28 runs passed**, comprising
1,094 assertions and four three-frame example smoke runs. The
[individual results](validation/2026-11-23-live-mask-platforms.csv) record:

| Suite | Ubuntu SDL GPU | Ubuntu OpenGL | Windows D3D9 | Windows D3D11 |
| --- | ---: | ---: | ---: | ---: |
| Live subtree masks | 39 | 39 | 39 | 39 |
| Selected subtree capture | 68 | 68 | 68 | 68 |
| Composite | 65 | 65 | 64 | 64 |
| Image-alpha masks | 56 | 56 | 56 | 56 |
| Culling | 22 | 22 | 22 | 22 |
| Storage | 24 | 24 | 24 | 24 |
| Example smoke run | PASS | PASS | PASS | PASS |

These ran in logged-in Parallels desktops: Ubuntu 26.04.1 LTS on ARM64 and
Windows 11 Pro 10.0.26200 on ARM64 using x64 applications. An initial Ubuntu
capture build
failed with a duplicate generated override member. Rebuilding its compiler from
current `bcc2` sources (`a4307ff`) and `blitzmax.mod` (`b6bfb4c`) cleared the
failure; the unchanged tests then passed. Both compiler builds report bcc 1.05.

Coverage includes source edits, shared/nested dependencies, cache reuse, cycles,
detach/reattach/destruction, failure recovery, resolution, budgets and graphics
context replacement. The composite count differs because native Direct3D checks
second-window rejection instead of migration between two live windows. Warm live
masks allocate 3,200 managed bytes per 100 cached frames on all four profiles;
composite and culling probes retain the same allocation result.

The example now selects native Direct3D explicitly. The PowerShell runner also
registers the two subtree suites and accepts their `PASS:` output, while rejecting
failure markers and nonzero exits; syntax, registration and result classification
were checked in Windows. These are correctness checks, not throughput measurements
or physical-device testing. Large dependency-graph CPU cost and changing-mask
allocation remain unmeasured. Earlier macOS results are recorded in the
[local live-mask matrix](validation/2026-11-23-live-subtree-masks.csv).

## VM validation — 21 November 2026

Tested source: `cf80848` on `task/scene-design`. Release builds ran in the
logged-in desktops of Parallels guests on an Apple Silicon host:

- Ubuntu 26.04.1 LTS, ARM64; bmk 4.04, bcc 1.05, GCC 15.
- Windows 11, build 26200.9974, ARM guest with x64 applications; bmk 4.08,
  bcc 1.05, GCC 12.2. SDL3 GPU was explicitly configured to use Vulkan.

The guest compilers were built from `bcc2` commit `699c067` and
`BlitzMax.Compiler`/`BlitzMax.Language` sources at `100383f` in `blitzmax.mod`.
BRL sources were at `2b4ad05`.

All **64 test runs passed** with the updated compilers:

| Checks | Ubuntu | Windows |
| --- | ---: | ---: |
| Tree, bounds, picking, pointer routing and interaction | 5/5 | 5/5 |
| Scene rendering/composition on SDL3 GPU / Vulkan | 7/7 | 7/7 |
| Scene rendering/composition on OpenGL | 7/7 | 7/7 |
| Scene rendering/composition on SDL renderer | 7/7 | 7/7 |
| Reactor Workshop: Vulkan and OpenGL | 2/2 | 2/2 |
| Camera World: Vulkan and OpenGL | 2/2 | 2/2 |
| Touch Playground: Vulkan and SDL renderer | 2/2 | 2/2 |
| **Total** | **32/32** | **32/32** |

The [individual results](validation/2026-11-21-vms.csv) record each executable's
success message. Example checks cover their real components, including camera
picking, fixed HUD coordinates, independent pointer capture, cache reuse,
effect isolation and resource lifetime. These are assertion-based runs, not
manual playtesting or screenshot comparisons.

### Toolchain compatibility

The initial guest bcc 1.03 SDKs failed to compile `TChartStation.Create`.
Generated C for the inherited `SetCacheMode` and `SetCaptureRect` calls named
unrelated methods (`Reparent` and `SetProcessing`) with incompatible signatures.
A forced rebuild on Linux reproduced the failure. Updating to bcc 1.05 resolved
it in both guests. Linux also needed current BRL sources, including the
`TPixmap.ClearPixels(UInt)` overload.

Keep the compiler and SDK module sources current when reproducing these tests.
The example source was not altered to work around incorrect compiler output.

## Native Direct3D scene validation — 22 November 2026

Tested source: `977ec6f` plus the accompanying release-review test configurations
and reference-image corrections, on the Windows guest described above. No renderer
or scene runtime changes were required by this validation.

All **18 test runs passed**, totalling **280 assertions per backend**:

| Suite | Direct3D 9 | Direct3D 11 |
| --- | ---: | ---: |
| Rendering and caller state | 54 | 54 |
| Culling | 22 | 22 |
| Composite caching and lifetime | 47 | 47 |
| Effect stages | 51 | 51 |
| Bloom adapter | 19 | 19 |
| Storage budgets | 24 | 24 |
| Inspection | 16 | 16 |
| Outer/inner shadow adapters | 39 | 39 |
| Tilemap/particle adapters | 8 | 8 |

The [individual results](validation/2026-11-22-d3d-scenes.csv) retain the suite
success messages. Both regression runners now include these nine suites in their
native Direct3D profiles. The existing lighting regression is separate from this
matrix; its assertion count is not included here.

The revised composite, bloom and shadow checks also passed on macOS SDL3
GPU/Metal and OpenGL: [six targeted reruns](validation/2026-11-22-macos-references.csv).
These verify the reference-image corrections on the existing paths; they are
not a fresh run of the complete macOS suite.

## Local clipping and alpha masks — 22 November 2026

The local clipping and alpha-mask tranche passed **10 rendering test runs**:
29 rectangular-clipping checks and 30 alpha-mask checks on each of macOS SDL3
GPU/Metal, OpenGL and SDL Renderer, plus Windows native D3D9 and D3D11.
The [individual results](validation/2026-11-22-local-masks.csv) record all 295 checks.
The existing 48-check composite regression also passed on macOS SDL3 GPU.

Coverage includes transformed/nested rectangular clips, camera coordinates,
resolution changes, soft and inverted alpha, explicit CPU input snapshots,
animated mask placement without recapture, warm texture/readback counters,
cache invalidation and storage release. The Mac example was inspected visually,
including its animated mask over an unchanged child capture.

The D3D9 immediate mask edge showed alpha 2/255 after filtered intermediate
copies. The regression allows at most two alpha units at that adjacent pixel,
while requiring exact zero in the transparent interior and farther outside.
D3D11 passed the original stricter edge check as well. No backend runtime change
was needed for this difference.

Mac and Windows compilers include the imported-slot identity fix `b6bfb4c` in
`blitzmax.mod`, with regression `a4307ff` in `bcc2`. This fixes application
provider overrides discovered during clipping work. Linux and native touch
hardware were not rerun for this tranche.

## Running the checks

From the SDK directory, run the graphics-independent scene tests:

```sh
python3 mod/max2d.mod/tests/run_regressions.py core \
  --test scene_foundation --test scene_bounds --test scene_picking \
  --test scene_pointer --test scene_interaction
```

Run the rendering tests in a logged-in desktop session:

```sh
python3 mod/max2d.mod/tests/run_regressions.py sdlgpu gl sdl \
  --test scene_render --test scene_culling --test scene_composite \
  --test scene_stages --test scene_bloom --test scene_storage \
  --test scene_inspection --test scene_clipping --test scene_alpha_masks \
  --test scene_subtree_capture --test scene_subtree_masks --test scene_source_preparation
```

For native Direct3D scene/composition checks on Windows, use the same runner:

```sh
python mod/max2d.mod/tests/run_regressions.py d3d9 d3d11 \
  --test scene_render --test scene_culling --test scene_composite \
  --test scene_stages --test scene_bloom --test scene_storage \
  --test scene_inspection --test scene_shadows --test scene_adapters_render \
  --test scene_clipping --test scene_alpha_masks \
  --test scene_subtree_capture --test scene_subtree_masks --test scene_source_preparation
```

Without Python, the PowerShell runner includes the same scene suites:

```powershell
./mod/max2d.mod/tests/run_regressions.ps1 -Profiles d3d9,d3d11 -Tests scene_render,scene_culling,scene_composite,scene_stages,scene_bloom,scene_storage,scene_inspection,scene_shadows,scene_adapters_render,scene_clipping,scene_alpha_masks,scene_subtree_capture,scene_subtree_masks,scene_source_preparation
```

The test sources select native Direct3D explicitly and include the shader-backed
composition assertions. These are not SDL renderer fallback runs.

Profiles run sequentially. The SDL renderer profile deliberately omits an
image-effect provider and verifies unsupported-effect handling. Vulkan/Metal
and OpenGL profiles require the imported shader provider to work.

For each of `reactor_workshop`, `touch_playground` and `camera_world`, build and
run the example's checks (substitute the example name below):

```sh
bin/bmk makeapp -r -o /tmp/camera_world \
  mod/max2d.mod/demos/camera_world/camera_world.bmx
/tmp/camera_world --test
```

For Reactor Workshop and Camera World, add `-ud max2d_gl` to test OpenGL.
Touch Playground instead supports `-ud max2d_sdlrender` for the SDL renderer;
its native input adapter uses SDL3. The default backend for all three examples
is SDL3 GPU. Use platform-appropriate executable paths on Windows. These console
builds expose assertion output; ordinary interactive examples may use `-t gui`.

## Coverage limits

Virtual-machine results exercise the guest driver stack and do not establish
performance or device coverage for physical machines. The example checks
simulate pointer input; they do not verify a physical multitouch device.
Native Direct3D 9/11 currently support one live graphics window. Their composite
checks verify explicit rejection of a second live window and recreation after
closing/reopening Graphics. Live migration between two simultaneous contexts is
covered only on backends that support it. The worked-example matrix above has
not been extended to native Direct3D.

The composite placement check allows up to four alpha units of loss at one
filtered outer corner (observed as 251/255 on the D3D9 VM). Interior colour and
coverage, transparent padding and cached/uncached pixel equality remain exact.
Zero-intensity bloom and zero-opacity shadows are compared exactly against an
ordinary source copy/presentation using the same sampling and blending. This
avoids confusing byte-target filtering/unpremultiplication precision with an
effect contribution. Adapter-versus-helper output equality remains exact.

The initial macOS [performance measurements](performance.md) are separate from
these correctness checks. Do not compare VM timings with those measurements.
