# Runtime fullscreen switching

The current Max2D canvas exposes the same window-mode API across backends:

```blitzmax
SetFullscreen(True, 1280, 720, 0) ' Exclusive display mode
SetBorderlessFullscreen(True)    ' Fill the desktop display without changing its mode
SetFullscreen(False)            ' Restore the original window from either fullscreen style
```

`SetBorderlessFullscreen(False)` restores the window only from borderless fullscreen;
it does nothing in ordinary windowed or exclusive mode. This name means fullscreen
without window decorations, not removing decorations from an ordinary window.

`SetFullscreen(enabled,width=0,height=0,hertz=0)` uses the current window drawing
width/height for omitted dimensions, and the highest matching refresh rate when
hertz is zero on D3D11, D3D9, OpenGL and SDL3. Explicit dimensions must match an available mode;
there is no silent substitution of a nearby resolution. Rates use rounded integer
Hz. The backend/window system may reject a transition even when it supports this API.

Query support after creating graphics:

```blitzmax
If Max2DSupportsBorderlessFullscreen() Then SetBorderlessFullscreen(True)
Local mode:Int = GetWindowMode()
```

`GetWindowMode()` returns `MAX2D_WINDOWED`, `MAX2D_FULLSCREEN`, or
`MAX2D_BORDERLESS_FULLSCREEN`. Exclusive mode temporarily suspended by focus loss
still counts as the application's exclusive mode on D3D11. Borderless reports
`GraphicsDepth()=0` and `GraphicsHertz()=0`; use the mode query to distinguish it
from an ordinary window.

| Backend | Exclusive switching | Borderless fullscreen switching |
|---|---|---|
| D3D11 | Yes | Yes |
| SDL3 renderer (including SDL's GPU renderer) | Yes, subject to the window system | Yes |
| BRL-based OpenGL | macOS and Windows owned windows | macOS, Windows, and Linux/X11 with EWMH and RandR 1.5 |
| D3D9 | Yes, default adapter, single owned runtime window | Yes, single owned window |
| D3D7 | Not implemented | Not implemented |

Unsupported operations throw an explanatory exception. The capability queries describe
backend implementation support, not a guarantee that a particular display mode is
available. The existing `D3D11SetFullscreen` and `D3D11SetBorderless` functions forward
to the shared API and still require a D3D11 context.

## Logical window size and drawable pixels

Windowed `Graphics(800,480)` requests an 800-by-480 logical client area. At 200%
Windows scaling this occupies 1600-by-960 physical pixels for both SDL3 and D3D11.
SDL3 converts between its window coordinates and logical units using display scale
and pixel density. This also accommodates macOS point coordinates without applying
Retina scaling twice. D3D11 uses 96-DPI logical units whether or not the process was
already DPI-aware when the window was created.

`GraphicsWidth/Height` and windowed `GraphicsResize` use logical units. Drawable
size remains separate: SDL3 can render at the full pixel size, while D3D11 currently
retains its logical-resolution backbuffer and scales presentation. Use
`NativeResolutionWidth/Height` or `SetNativeResolution` for the actual drawable.
Exclusive fullscreen dimensions remain display-mode pixels. Borderless fills the
monitor and reports its size in logical units.

Raw SDL window APIs and raw mouse coordinates remain in native window coordinates.
Max2D queries that input extent separately: `VirtualMouseX/Y`, `WindowToVirtual`,
and virtual mouse warping map it into the drawing coordinates. Explicit desktop
positions remain native desktop coordinates.

## Drawing, window restoration and input

Select the window with `SetRenderImage(Null)` before switching. Max2D flushes queued
drawing, delegates the transition, and refreshes cached graphics dimensions, viewport,
and input mapping. Explicit virtual resolution and drawing state are retained.
Returning to a window restores its previous size and position, including after direct
transitions between fullscreen styles. Normal transitions retain images and render
images; device loss has the backend's usual recovery rules.

SDL3 transitions wait for the window system with `SDL_SyncWindow`, so desktop/Space
animations can make these calls take time. Actual window state is queried afterward,
including after errors. SDL restores the window geometry itself. Queued resize and
move events refresh current geometry rather than reapplying obsolete event sizes.
SDL3 rejects programmatic resize/position changes while fullscreen; leave fullscreen
first. D3D11 allows exclusive resize to another supported mode, but rejects resize
in borderless mode and positioning in either fullscreen style.

## Direct3D9 borderless windows

D3D9 fills the current monitor without changing the display mode. The existing
window frame and decorations are restored on exit. A single owned window and
an available device are required; attached windows and shared devices are rejected.
The shared Max2D API flushes drawing before changing the window and resetting
the backbuffer through the existing DXGraphics lost/reset callbacks.

Ordinary managed images survive Reset. Max2D snapshots live render images into
system memory before these deliberate transitions, then restores their exact
premultiplied pixels on next use and regenerates mipmaps when sampled. This adds
readback cost and temporary memory proportional to live render images. Snapshots
are freed after restoration or image destruction. Unplanned device loss and
changes to Flip synchronization retain the existing recovery behaviour described
in [the D3D9 backend documentation](d3d9.md).

If the window transition succeeds but Reset cannot finish, the call throws and
the reported mode reflects the changed window. Continue processing events and
calling Flip so the existing reset recovery can retry. Programmatic resize and position are available in ordinary windowed mode.
Exclusive switching is described in [D3D9 display handling](d3d9.md#exclusive-fullscreen).

## OpenGL window modes

OpenGL borderless switching uses the existing native window and GL context.
It fills the screen containing that window without changing the display mode.
Returning to windowed restores the saved frame and decorations. Repeating an
already active mode is harmless. Programmatic resize and position requests are
rejected while borderless, so the saved window geometry remains intact.

On macOS this is a desktop borderless window, not a separate fullscreen Space.
The key borderless window temporarily enables automatic hiding of the Dock and
menu bar; the previous application presentation options are restored on focus
loss, exit or close. Retina drawable dimensions remain separate from window points.
On Windows the existing process DPI awareness is preserved; this change does not
introduce per-monitor DPI awareness into BRL.GLGraphics.

Runtime exclusive switching uses the display containing the current window.
Query `GraphicsModes()` after creating/selecting that window: the new OpenGL
backend then returns that display's runtime modes. macOS modes use pixel dimensions,
which can differ from the logical dimensions in legacy BRL.GLGraphics mode lists.
Zero hertz chooses the highest reported matching rate; an unknown native rate is
reported as zero. Unavailable exact modes are rejected before changing the window.
Create ordinary windowed graphics before using runtime switching.

The GL context is retained through all three modes and focus changes. On Windows,
exclusive mode uses temporary per-display settings. On macOS it captures only the
selected display and restores/releases it on exit. Focus loss suspends the mode,
and focus return reapplies it. `GetWindowMode()` continues to report exclusive
while suspended. Closing restores the saved desktop mode. Only one runtime exclusive
GL window can own a display transition at a time; mixing it with an existing legacy
exclusive GL window is rejected.

Exclusive drawing dimensions are display pixels. Input conversion uses actual client
coordinates separately; the native drawable is still queried independently. Windows
retains its process DPI awareness and can use a DPI-virtualized drawable. macOS
retains Retina backing-pixel rendering. Resizing/positioning require returning to
windowed mode first. Mode changes do not recreate textures or render images.

Exclusive-created GL contexts and attached widgets cannot use runtime switching.
Linux/X11 borderless switching uses the window manager's `_NET_WM_STATE_FULLSCREEN`
protocol and requires advertised EWMH fullscreen support plus RandR 1.5 monitor
queries (`libxrandr-dev` when building). It selects the monitor with the largest
intersection with the window and waits up to two seconds for both the WM state
and monitor geometry. Fixed-size hints are relaxed while fullscreen and restored
on exit. Original client geometry is saved once, so repeated requests do not replace
it. A failed entry requests a return to windowed mode; timeouts report failure
instead of assuming the window manager accepted the request. Queued input events
are left to ordinary BlitzMax dispatch. The window and GL context are retained.

Linux windowed contexts now correctly report depth zero; previously the native
backend reported 24 for ordinary windows, which confused the shared window-mode
query. Linux runtime exclusive switching remains unsupported. No display mode is
changed by the borderless path.

The borderless regression passes on ARM64 Ubuntu GNOME/Xwayland in Parallels,
including three round trips, monitor coverage, original size/position and sizing
hints, render-image retention, coordinate mapping, rejected resize/move requests,
and closing while fullscreen. Native X11 sessions, other WMs, multiple monitors,
and monitor hotplug still need runtime validation.

## Examples and validation

- `examples/d3d9_fullscreen.bmx`: F10 borderless, F11 exclusive using an enumerated mode.
- `tests/d3d9_fullscreen.bmx`: actual display changes/restoration, preserved targets,
  transitions through borderless, DPI handling, minimize/restore and exclusive close.
- `examples/d3d9_borderless.bmx`: F10 toggles D3D9 borderless; Escape exits.
- `tests/d3d9_borderless.bmx`: repeated transitions, native monitor coverage,
  restored geometry, reset callback counts, input conversion and retained images.
- `examples/gl_fullscreen.bmx`: F10 borderless, F11 exclusive, F5 resize, Escape exits.
- `tests/gl_fullscreen.bmx`: exact mode changes/restoration, native resource retention,
  all three modes, input mapping, focus suspension/resumption and exclusive close.
- `examples/gl_borderless.bmx`: F10 toggles OpenGL borderless; Escape exits.
- `tests/gl_window_modes.bmx`: repeated GL borderless round trips, monitor coverage,
  viewport/readback, virtual input, retained render images and geometry restoration.
- `examples/sdl3_fullscreen.bmx`: F10 borderless, F11 exclusive 1280x720, Escape exits.
- `examples/d3d11_fullscreen.bmx`: the same shared calls, with a DXGI-enumerated mode.
- `tests/sdl3_fullscreen.bmx`: Windows/macOS logical sizing and resize events, transitions, exact-mode rejection, retained renderer
  and render image, window/drawable restoration, virtual mouse mapping, and queued events.
- `tests/d3d11_display.bmx`: shared API exercised by the D3D11 display/DPI regression test.

The OpenGL exclusive and borderless regressions passed on macOS Retina and Windows 11 in
Parallels. macOS checks also verify restoration of application presentation options
on exit and close. The example was built for macOS and Windows.

Multiple monitors, mixed display scaling and Linux window systems require further
validation. SDL3's GPU renderer uses this same window-management path; its fullscreen
rendering has not been separately validated here.
