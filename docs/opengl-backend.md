# Max2D.GLMax2D

```blitzmax
SuperStrict
Framework Max2D.GLMax2D

Graphics 640,480,0
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
    PollSystem()
    Cls()
    DrawText("Hello World",10,10)
    Flip()
Wend
EndGraphics()
```

This backend uses `Max2D.Core`, `BRL.GLGraphics` and `Pub.Glew`. It does not import
BRL.Max2D or SDL. Existing image/font loaders remain usable.

## Rendering

Requires desktop OpenGL 2.1, GLSL 1.20 and `EXT_framebuffer_object`. Creation fails
with an explanatory error if these are unavailable; shader compile/link errors
include the driver log. This is a desktop compatibility-context backend, not an
OpenGL ES or core-profile backend.

- The core's ordered triangle batches are uploaded to a streaming vertex buffer.
  Each native context owns a shader program, vertex buffer and fallback white
  texture. Images and framebuffer objects also belong to their owning context.
- RGBA asset textures retain straight alpha. Render targets store premultiplied
  alpha. The fragment shader handles modulation, target texture orientation and
  alpha conversion. SOLID/SHADE target sampling requires no conversion texture
  or GPU readback; explicit image readback returns straight-alpha pixels.
- SOLID, ALPHA, LIGHT and SHADE follow the new core's blend contract. MASK is
  additionally supported: fragments with modulated alpha below 0.5 are discarded;
  the surviving colour/alpha replaces the destination. Mipmapped images and
  targets are supported; see [mipmap lifecycle and atlas limits](mipmaps.md).
- Virtual presentation, integer scaling, letterbox bars, clipping, atlas subviews,
  dynamic edits, bitmap/scalable fonts and physical pixel transfers use the same
  core paths as the SDL renderer. FBO images are flipped at sampling/readback so
  public image coordinates remain top-left based.
- Context creation, resource deletion and closing a non-current window activate
  the owning GL context and restore the selected window where appropriate.
  Deferred releases remain on the rendering thread.

The backend owns GL rendering state. Mixing arbitrary raw GL calls with queued
Max2D draws is not a supported interop API yet. Use the normal Max2D target and
state APIs; push/pop Max2D state does not save arbitrary external GL state.

## Window management

`GraphicsResize` and `GraphicsPosition` now operate on owned windowed contexts.
`CanResize()` returns true. Resizing keeps the GL context, textures and render
images alive; the new Max2D core refreshes presentation and preserves explicitly
configured virtual resolution. Positions describe the client area's top-left
relative to the desktop. Window decoration and creation flags are unchanged.
Attached widgets and exclusive fullscreen contexts reject these operations.
Runtime borderless switching is supported on macOS, Windows, and Linux/X11 owned
windows with EWMH fullscreen and RandR 1.5 support. Runtime exclusive switching is
supported on macOS and Windows; see [window modes](window-modes.md). Native widget attachment and native handle export are not implemented
in this Max2D backend.

The underlying BRL.GLGraphics implementation supplies macOS, Win32 and X11
operations. Window sizes retain the existing platform coordinate units: Cocoa
points, Win32 client coordinates under the process's existing DPI awareness,
and X11 pixels. This does not add per-monitor DPI handling to Windows GL.
X11 window-manager requests are asynchronous. Resize and position now wait up to
one second for the actual requested geometry, then report failure if it was not
applied. Queued input and window events remain available to normal system polling.
Owned windows receive structure notifications instead of intercepting the window
manager's resize requests. This has been tested under GNOME/Xwayland on Linux ARM64;
other X11 window managers remain unvalidated.

Legacy BRL.GLMax2D remains usable. Its existing wrapper does not advertise
`CanResize` and does not automatically refresh rendering state after a direct
canvas resize: use `canvas.Resize(...)` followed by `SetGraphics(canvas)`.
Its wrapper still reports position as -1; query the underlying TGLGraphics
settings to obtain client position.

On macOS, output dimensions are queried from the active OpenGL view in backing
pixels, while BRL window/event coordinates remain in points. This keeps Retina
viewports, letterboxing, native overlays, readback and mouse conversion aligned.
The view is queried again when the core refreshes presentation, including after
render-target switches. Render images retain their explicitly requested pixel
sizes. Other platforms currently use the dimensions supplied by BRL.GLGraphics.
BRL.GLGraphics now queries live owned-window dimensions as well as widget sizes.

This follows Apple's [OpenGL backing-surface coordinate guidance](https://developer.apple.com/documentation/appkit/nsopenglview/wantsbestresolutionopenglsurface?language=objc).

## Validation

From the SDK root:

```sh
./bin/bmk makeapp -r -ud max2d_gl -o /private/tmp/max2d-gl-test mod/max2d.mod/tests/integration.bmx
/private/tmp/max2d-gl-test
```

The fixed-coordinate pixel fixtures explicitly select 1× GL surfaces on macOS;
Retina coverage is provided separately below.
The `max2d_gl` definition selects GL for the shared smoke, integration,
api_coverage, dirty_regions and scalable_text tests. Without it they still select
SDL3. Only the programmatic resize assertions are skipped when the selected
window driver reports that it cannot resize.

`tests/gl_targets.bmx` directly selects GL and tests target-to-target and target-
to-window alpha, asymmetric texture orientation, all five blend modes, restoration
after reading a different framebuffer, and closing a non-current window.

Release integration, API, dirty-region, scalable-font, and GL target/blend tests
passed on macOS 15.7.4 / Apple M4 Max. The window-management regressions are recorded separately below;
see the [stabilisation report](stabilisation.md) for the subsequent Windows/Linux
regression selection and remaining coverage gaps. The shared
suite tests rendering semantics, not complete equivalence with historical
BRL.GLMax2D behaviour.

## Historical benchmark (affected by the Retina viewport bug)

Build the existing benchmark with `-ud max2d_gl`; no SDL environment variables
are needed. The GL timing adapter uses a monotonic OS clock, and records the
actual GL renderer string.

[Initial capture](../benchmarks/results/2026-09-21-opengl.csv): 20 warmup frames,
120 measured frames, release ARM64, macOS 15.7.4, Apple M4 Max, NotoSans-Regular.ttf
from the existing imgui module. All twelve two-window resource cycles completed
with empty closed-context frame registries.

| Workload | Median frame ms | Submissions/frame |
| --- | ---: | ---: |
| 4,096 sprites, separate textures | 8.207 | 4,096 |
| Same sprites, atlas | 0.245 | 4 |
| Eight ALPHA target composites | 0.651 | 16 |
| Eight SOLID target composites | 0.599 | 16 |

Two adjacent atlas edits upload 648 source pixels per frame, as with SDL. These
are individual captures; different window/compositor pacing makes direct timing
rankings against the prior SDL/Metal run unreliable. Repeated measurements and
GPU profiling are needed before claiming comparative speedups. Read the benchmark
methodology for memory and counter limitations.

## Retina regression

The initial tests assumed window dimensions equalled backing dimensions and
missed a Retina viewport bug: a 640×480 point
window could have a 1280×960 drawable, while the backend used 640×480 for its GL
viewport. This produced a half-sized scene in the lower-left corner. The macOS
backing-size query fixes the viewport, scissor, native overlays and readback.

Build the regression as a HiDPI GUI application, not just a console executable:

```sh
./bin/bmk makeapp -r -t gui -hi -o /private/tmp/max2d-gl-hidpi mod/max2d.mod/tests/gl_hidpi.bmx
/private/tmp/max2d-gl-hidpi.app/Contents/MacOS/max2d-gl-hidpi retina
```

The optional `retina` argument requires a backing width greater than the window
width, preventing an accidental 1× run from counting as Retina validation. On the
development display it reports a 640×480 window and 1280×960 drawable. Pixel
checks cover both letterbox bars, the far-right scene edge, rectangle scale,
a top-right native overlay, window-to-virtual input mapping and target switching.
The GUI Retina test passed; `examples/gl_hello.bmx` was rebuilt with `-t gui -hi`.
The earlier benchmark capture predates this fix and used the incorrect viewport
on Retina. Treat its timings as historical only; it did not render the intended
full-window workload. Console builds can also receive a Retina drawable.
The `lowdpi` test argument explicitly requests a one-pixel-per-point macOS GL
surface and checks 640×480 rendering with the same pixel assertions.

## Window-management regression

`tests/gl_window_management.bmx` exercises repeated resize/position requests,
live settings, viewport updates, virtual mouse conversion, GL context identity,
texture retention and render-image retention. `tests/brl_gl_window_management.bmx`
checks direct legacy canvas operations and image rendering after reselection.
Both passed on macOS and in the Windows 11 Parallels VM. On Linux ARM64 under
GNOME/Xwayland, the new Max2D test passes with Parallels acceleration, including
growing, shrinking, restoring the original size, and drawing at both window edges.
The render-target/blend and mipmap suites also pass. Legacy BRL compatibility passes
with `LIBGL_ALWAYS_SOFTWARE=1`; its image readback still fails with this VM's
accelerated driver. Do not interpret the software-renderer pass as accelerated
legacy validation. Native X11 sessions, mixed-DPI monitor transitions and
attached-widget management remain unvalidated.

## Runtime exclusive regression

`tests/gl_fullscreen.bmx` changes to an enumerated display mode, checks actual
display pixels/rate, and tests windowed/exclusive/borderless round trips. It verifies
GL context identity, texture names, translucent render-image pixels, input conversion,
window geometry and desktop-mode restoration. Focus loss uses application hiding on
macOS and minimization on Windows; both must release the display and restore the
requested mode and retained resources on return. Exclusive close must restore the
desktop. macOS additionally checks capture release and application presentation options.

The regression passed on macOS Retina (1920x1200 at 120 Hz) and Windows 11 Parallels
(1280x1024 at 120 Hz), along with borderless and legacy BRL.GLMax2D window-management
tests. Multiple monitors, unplugging a captured display, failed native restoration,
and physical Windows GPUs remain unvalidated. Linux runtime exclusive fullscreen remains
unsupported; EWMH borderless fullscreen is validated under GNOME/Xwayland. The example queries modes after window creation; legacy native GL
mode-list semantics and startup-exclusive paths are unchanged.


The borderless regression also passes on Linux ARM64 GNOME/Xwayland with VM
acceleration. Its native helper independently checks the fullscreen property and
RandR monitor bounds, and checks that the original sizing hints return on exit.
