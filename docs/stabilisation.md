# Initial stabilisation

This records the scope of the first stabilisation pass, not a promise of complete
hardware coverage. The aim is a usable initial implementation with explicit limits;
new features and redesigns are outside this pass.

## Backend capabilities

All enabled backends use the shared drawing API, ordered batches, atlas views,
dynamic images, render images, text, collisions, virtual presentation and input
mapping. Capabilities below describe implementation support; query the active
context before relying on optional features.

| Backend | Platforms | MASKBLEND | Mipmaps | Runtime exclusive | Borderless |
| --- | --- | --- | --- | --- | --- |
| OpenGL | macOS, Windows, Linux/X11 | Yes | Yes | macOS/Windows owned windows | macOS/Windows; Linux EWMH + RandR 1.5 |
| SDL3 Renderer | macOS, Windows, Linux | Only SDL GPU renderer with bundled Metal shader | No | Subject to SDL/window system | Subject to SDL/window system |
| Native SDL3 GPU | Metal/macOS, Vulkan/Linux/Windows; D3D12 path included | Yes | RGBA8/A8; capability checked | Shared SDL window handling | Shared SDL window handling |
| D3D9 | Windows | Yes | Device capability checked | Yes, create windowed first | Yes |
| D3D11 | Windows | Yes | Device capability checked | Yes | Yes |
| D3D7 | Disabled | — | — | — | — |

`Max2DSupportsBlend`, `Max2DSupportsImageFlags`, `Max2DSupportsFullscreen` and
`Max2DSupportsBorderlessFullscreen` describe the current context. Unsupported
requests fail explicitly. A window-system capability is not a guarantee that a
particular display transition will succeed.

SDL's GPU renderer is an implementation selected within SDL3 Renderer. Its
masking support is currently macOS/Metal only.
The separate [native SDL GPU backend](sdl-gpu.md) supports masking across its GPU
drivers; it has its own regression coverage for ordinary drawing and mipmaps, and supports floating-point image textures, supplied chains and render images on capable devices.
BC1/BC3 compressed images and supplied chains are also supported on capable devices.
Packed atlases do not support mipmaps on any backend.

## Regression sweep

The runners build existing tests sequentially, retain per-test build/run logs in
a new temporary directory, and stop on the first failure. Tests must both exit
successfully and print their success message. Rendering tests have a 60-second
timeout. They do not change display modes or run long benchmarks.

From the SDK root, with Python 3 on macOS/Linux:

```sh
python3 mod/max2d.mod/tests/run_regressions.py core software gl sdl
```

On Windows, no Python installation is required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File mod/max2d.mod/tests/run_regressions.ps1
```

The Windows default selects core, GL, SDL, D3D9 and D3D11. Python accepts the same
profiles, with `--sdk` for a separate SDK installation. Use `--debug` (Python) or
`-DebugBuild` (PowerShell) for debug builds. Do not build against one shared SDK
from multiple platforms at once. Run graphics profiles in a logged-in desktop
session. Only `core` and `software` can run headlessly; software selects SDL's
dummy video driver and software renderer. Other profiles retain the caller's
renderer environment overrides, so record any overrides with results.
For a focused rerun, Python accepts repeated `--test integration --test dirty_regions`;
PowerShell accepts `-Tests integration,dirty_regions` when invoked from PowerShell.

Coverage:

- Core: synthetic text layout, coordinate mapping and CPU collisions.
- SDL: integration/atlas batching, API overloads and pixel transfers, dirty
  uploads, rendered collisions, viewport clipping and explicit mipmap rejection.
- GL: integration, API, dirty uploads, viewport, target/blend and mipmap tests.
- D3D9/D3D11: native rendering, target/blend, mipmap and shared viewport tests.

This is a bounded regression selection, not every test in the repository.
Font-file-dependent tests, atlas package IO, GPU/Metal masking, device-loss
injection, Retina-specific and display-mode tests have separate fixtures and
earlier results in their feature guides. Run those when changing the relevant
area. Ordinary fixed-coordinate GL fixtures use 1x macOS surfaces; they must not
be described as Retina validation.

## Results — 24 September 2026

Fresh release-build results for this pass:

| Environment | Profiles | Result |
| --- | --- | --- |
| Native macOS ARM64, Apple M4 Max | core, software, gl, sdl | 21 passed |
| Linux ARM64 Parallels, GNOME/Xwayland | core, gl, sdl | 15 passed |
| Windows 11 ARM64 Parallels, x64 executables, 200% display scaling | core, gl, sdl, d3d9, d3d11 | 23 passed |

Counts are unique profile/test combinations, not individual assertions. Focused
reruns of corrected fixtures are not counted as additional coverage.

The Windows SDL run exposed a stale test assumption: logical window coordinates
were treated as physical readback pixels. Integration and dirty-region fixtures
now explicitly use native coordinates for pixel-sized drawings. Presentation
expectations use the actual drawable size, input checks use the native input
extent, and resize checks retain drawable density and verify restoration.
The corrected fixtures pass without changing production renderer code.

This pass corrected test assumptions and stale documentation, added reproducible
runners, and found no production-rendering blocker in the tested selection.

The Linux run used the VM's accelerated graphics, not `LIBGL_ALWAYS_SOFTWARE`.
Its 64 applicable Max2D source/test files were compared byte-for-byte with the
shared workspace. No differences were found. The separate legacy BRL issue below
does not affect these new Max2D results.

Earlier window-mode validation remains in [window modes](window-modes.md),
[OpenGL](opengl-backend.md), [D3D9](d3d9.md) and [D3D11](d3d11.md). Those transition
tests are not counted again in this sweep. Previously validated GPU/Metal masking
is likewise distinct from the default SDL renderer profile here.

## Remaining limits

- Physical Windows/Linux GPUs, 32-bit builds, older Windows versions and diverse
  Linux window managers are not established by the VM results.
- Mixed-DPI/multiple-monitor transitions, hotplug and real device resets need
  hardware testing. Injected recovery tests exercise mechanics, not all failures.
- D3D11's windowed backbuffer uses logical resolution and presentation scaling;
  matching visible window sizes does not imply equal drawable pixel density.
  Windows GL retains the process's existing DPI awareness. See
  [window coordinates and modes](window-modes.md).
- D3D9/D3D11 have different resource-recovery guarantees. Ordinary images can be
  restored; render-image contents can be lost after unplanned device loss. See
  [D3D9](d3d9.md) and [D3D11](d3d11.md) before retaining render images as sole data.
- Native widget attachment, packed-atlas mipmaps and paragraph/font-fallback
  layout are not part of the initial scope. D3D7 stays disabled.
- The Linux Parallels legacy BRL.GLMax2D texture failure also reproduces in native
  fixed-function OpenGL. It is separate from the new shader-based GL backend.
- Historical GL benchmark numbers predate the Retina viewport correction;
  they are not evidence for current comparative performance.

## Before a first publish

Keep the companion BRL, Pub and SDL3 changes available together; this repository
is not intended to build against an arbitrary older BlitzMax release. The local
review baseline is Max2D `9191292`, BRL `51cfcd7`, Pub `0ea3659` and SDL3 `74f327c`.
BRL supplies the new window/device interfaces; Pub supplies the corrected DirectX,
DXGI and Direct3D11 bindings. Rebuild dependent modules/applications.

The README lists optional atlas/font dependencies. SDL3 builds from its bundled
sources; Linux needs the SDL module's configuration step and development packages.
GL's Linux window handling also needs Xrandr development headers/libraries.
Sample ports deliberately reference assets in the SDK samples tree; those assets
are not bundled in this repository. See [attribution](../NOTICE.md).

An initial publish should present these as tested development backends with the
limits above, not universal hardware certification. Publishing and companion-repo
merges remain separate decisions; this pass makes no remote changes.
