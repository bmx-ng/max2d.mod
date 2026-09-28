# Existing sample compatibility

`examples/oldskool2.bmx` adapts the public-domain Binary Therapy demo from
`samples/flameduck/oldskool2`. The original sample is unchanged. Assets are
embedded from the SDK samples directory; this example requires that directory
alongside `mod`, rather than a standalone checkout of max2d.mod.

## Migration findings

- Select `Max2D.SDL3RenderMax2D` or `Max2D.GLMax2D` as the framework.
- Replace the legacy SDL audio import/driver with `BRL.FreeAudioAudio` and
  `FreeAudio`. This is independent of the drawing API.
- OpenGL retains `MASKBLEND`. SDL3 Renderer supports it on GPU/Metal; this example
  explicitly selects `ALPHABLEND` when masking is unavailable. Filtered edges
  can therefore differ; this is not an exact masking emulation.
- Asset paths changed only because the example moved directories.

The existing image loads before `Graphics`, animated font frames, image handles,
Double coordinates, rotations, alpha, primitive drawing and drawing order work
without changes. Explicit event polling/window-close handling and cleanup were
added. The deterministic test harness is extra instrumentation, not a migration
requirement. This is evidence for this sample, not a guarantee for every app.

## Running

From the max2d.mod directory, using the SDK's bmk:

```sh
../../bin/bmk makeapp -r -t gui -hi -o /private/tmp/oldskool2 examples/oldskool2.bmx
../../bin/bmk makeapp -r -t gui -hi -ud max2d_gl -o /private/tmp/oldskool2-gl examples/oldskool2.bmx
```

For a silent, deterministic GUI test, add `sample_test` to the definitions
(`-ud max2d_gl,sample_test` for GL, `-ud sample_test` for SDL3). The application
closes after 700 frames and writes `oldskool2-test.png` to `AppDir`. Console
builds also accept `--test [screenshot-path]`. The macOS GUI app stub currently
replaces command-line arguments, so use the build definition for GUI tests.
Choose a writable output directory for the screenshot.

Use `-ud max2d_sdl_gpu,sample_test` to exercise SDL3 GPU masking instead of
the default renderer. See [SDL3 masking](sdl3-maskblend.md) for capabilities.

A headless SDL3 check can use a console build:

```sh
../../bin/bmk makeapp -r -o /private/tmp/oldskool2-sdl examples/oldskool2.bmx
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software /private/tmp/oldskool2-sdl --test /private/tmp/oldskool2-sdl.png
```

## Validation (macOS arm64, 2026-09-21)

| Backend | Output | Result |
| --- | --- | --- |
| SDL3 software, dummy video | 640×480 | 700 frames, 4,000 stars, 18 letters; captured scene inspected |
| OpenGL 2.1, native GUI/Retina | 1280×960 | 700 frames, 4,000 stars, 18 letters; captured scene inspected |
| SDL3 GPU/Metal, MASKBLEND | 640×480 | 700 frames, 4,000 stars, 18 letters; captured scene inspected |

All three recorded 4,287 submissions, three texture creations and three texture
uploads across the full run. These core counters exclude backend helper resources,
including the GPU mask shader's one-pixel white texture. These are cumulative counters, not frame timings
or a performance comparison with BRL. The test checks population counts and a
nonblank framebuffer; it does not assert pixel equality between backends.
Interactive OpenGL playback was also observed with music. Automated runs skip
audio and do not validate the Escape fade or audio teardown behavior.

## Viewport sample

`examples/viewport.bmx` adapts James L Boyd's `samples/hitoro/viewport.bmx`
and uses its existing assets. The original sample and the user's Oldskool2
framework selection are preserved. Build normally for SDL3, with `-ud max2d_gl`
for OpenGL, or `-ud max2d_sdl_gpu` for SDL3 GPU/Metal. Adding `sample_test` captures
three deterministic positions to `AppDir/viewport-0.png` through `viewport-2.png`
and exits. The interactive version follows the mouse and exits on Escape/close.

The intended viewport is a 400×300 cutout centred on the mouse. At mouse (0,0),
only its intersection with the window, 200×150 logical units, is visible.
Clipping does not move the drawing origin or the image. The port uses
`GetVirtualMouse` for drawing coordinates and explicitly falls back to alpha
blending where masking is unavailable.

Legacy SDL2's `bmx_SDL_RenderSetClipRect` disables clipping if either origin is
negative. This explains the original sample showing the full background near
the top/left edges. Its `Cls` also uses SDL_RenderClear, which clears the whole
target rather than the clip. In this particular sample both clears are black,
so that second difference is not visible.

A temporary BRL.GLMax2D GUI reproduction measured a 1280×960 drawable and GL
viewport for the 640×480 window on this Retina display. BRL's macOS mouse events
use view coordinates (points); its GL scissor code uses stored frame dimensions
and receives no explicit backing-pixel conversion in that method. This identifies
a Retina coordinate-consistency issue to investigate in BRL separately, not a
reason to multiply all application mouse positions by a hard-coded two.

The new SDL3 GPU path also failed negative-origin clipping in the first test.
The Max2D adapter now intersects clip rectangles with its presentation viewport
before calling SDL, preserving zero-sized and completely off-screen clips.
No vendored SDL code was changed.

`tests/viewport.bmx` checks all pixels after drawing and after clipped clears for
12 rectangles: centred, crossing each edge, completely outside, zero-area and
full-window. On 2026-09-22 all 24 checks passed with SDL3 software (640×480),
SDL3 GPU/Metal (640×480), and OpenGL Retina (1280×960). The adapted OpenGL sample's
three deterministic positions were also captured; the top-left capture was
visually inspected. Actual mouse tracking remains an interactive check.

## Filmclip, Snowfall and worker loading

The following ports keep the original samples unchanged and embed their existing
SDK PNG assets. Their build layout requires `samples` alongside `mod`.

| Port | Original | Migration changes |
| --- | --- | --- |
| `examples/filmclip.bmx` | `birdie/misc/filmclip/main.bmx` | Framework, embedded paths, explicit ALPHABLEND fallback when MASKBLEND is unavailable |
| `examples/snowfall.bmx` | `simonh/snow/snowfall.bmx` | Framework, embedded path, explicit FILTEREDIMAGE fallback when MIPMAPPEDIMAGE is unavailable |
| `examples/background_loading.bmx` | `threads/background_loading.bmx` | Framework, embedded paths, explicit WaitThread before reading worker results, mapped mouse coordinates |

Drawing positions, rotation, image handles, animated frame selection and grayscale
conversion are retained. Snowfall now uses VSync and elapsed-time motion following
a frame-pacing report; see [timing findings](snowfall-pacing.md). Event polling, window-close handling
in the drawing loops and graphics cleanup were added. Snowfall polls inside its
inner wind loop, avoiding a long delay before responding to Escape.

Filmclip retains the original's current drawing alpha while masking the filmstrip.
Its grayscale conversion still locks and edits the CPU pixmap before the first
draw; all pixels are checked for equal RGB channels in test mode. Ten filtered
animation frames share one atlas texture. The SDL software fallback blends edges
and therefore is not a pixel-identical substitute for masking.

Snowfall preserves the original **MIPMAPPEDIMAGE alone** on OpenGL (nearest
sampling within/among mip levels). The SDL fallback uses filtering without
mipmaps, so its appearance differs. This is an application-level choice rather
than the backend silently ignoring an unsupported flag.

The worker example still uses a BlitzMax-created thread and CPU-only decoding,
with no graphics calls on that thread. `WaitThread` establishes the handover
before the main thread reads the map. Assets are embedded for location-independent
execution, so this tests concurrent PNG decoding, not disk I/O. The loading
screen's original simulated delays remain in interactive mode (about six seconds);
closing during loading is handled after the worker completes. Thread creation
and GC registration remain the responsibility of BRL.Threads, unchanged here.

### Builds

From max2d.mod, substitute any of the three filenames:

```sh
# Interactive default SDL renderer
../../bin/bmk makeapp -r -t gui -hi -o /private/tmp/filmclip examples/filmclip.bmx
# Bounded OpenGL Retina run
../../bin/bmk makeapp -r -t gui -hi -ud max2d_gl,sample_test -o /private/tmp/filmclip-gl examples/filmclip.bmx
# Bounded SDL GPU run
../../bin/bmk makeapp -r -t gui -hi -ud max2d_sdl_gpu,sample_test -o /private/tmp/filmclip-gpu examples/filmclip.bmx
# Headless software run
../../bin/bmk makeapp -r -ud sample_test -o /private/tmp/filmclip-software examples/filmclip.bmx
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software /private/tmp/filmclip-software
```

`sample_test` seeds Filmclip/Snowfall randomness, runs 120 Filmclip frames,
720 Snowfall frames, or 120 post-loading frames, saves a PNG in writable `AppDir`
and exits. It also checks grayscale pixels, animation texture sharing, the
1,000-flake population, mipmap generation on supporting backends, or six decoded
worker images as appropriate. The loading-screen duration remains scheduler-dependent. Rendering counters include the loading-screen font texture.

### Results: macOS arm64, 2026-09-22

All nine release runs passed: each sample on SDL3 software, SDL3 GPU/Metal and
OpenGL Retina. No additional backend defects were found in these runs.

| Sample | SDL output | OpenGL output | Core textures / uploads | GL mipmap generations |
| --- | --- | --- | --- | --- |
| Filmclip | 640×480 | 1280×960 | 2 / 2 | 0 |
| Snowfall | 800×600 | 1600×1200 | 1 / 1 | 1 |
| Background loading | 640×480 | 1280×960 | 7 / 7 | 0 |

SDL GPU captures of all three scenes and OpenGL Filmclip/Snowfall captures were
visually inspected. These are compatibility runs, not performance benchmarks or
pixel-equality comparisons with BRL. They do not establish worker-safe GPU calls,
concurrent map access, or universal cross-platform behaviour.
