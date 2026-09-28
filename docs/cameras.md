# Cameras and drawing-state scopes

The camera is an optional transform in `Max2D.Core`. All enabled backends use the
same implementation. Existing applications have no camera by default and retain
existing drawing behaviour.

## Camera coordinates

```blitzmax
Local camera:TCamera2D = New TCamera2D
camera.x = playerX
camera.y = playerY
camera.offsetX = 320
camera.offsetY = 180
camera.zoom = 2
camera.rotation = 0
SetCamera(camera)
DrawImage(player, playerX, playerY)
```

Here the world point `(playerX, playerY)` appears at virtual coordinate `(320,180)`.
Offsets are in the current virtual drawing surface, not window or backing pixels.
The default camera is identity: position and offset zero, zoom one, rotation zero.
Zoom must be positive; all camera values must be finite. Rotation is in degrees.
Positive rotation turns the camera clockwise, so the world turns counterclockwise.

The coordinate chain is:

```
object geometry/handle -> existing object transform and origin
                       -> world -> camera -> virtual surface
                       -> virtual presentation / letterbox -> drawable pixels
```

The camera transforms both object positions and their geometry. Existing
`SetRotation`, `SetScale`, handles and origins retain their original meanings.
`SetOrigin` is applied before the camera. Lines and plots also pass through the
camera; their world-space widths/sizes grow with camera zoom. Scalable text takes
camera zoom/rotation into account when choosing its glyph raster density, without
changing layout metrics. Camera-aware tiling covers the inverse-transformed view
bounds, including rotated views.

`SetCamera` copies the supplied values. Modify your camera and call `SetCamera`
again to apply changes. `GetCamera` returns a detached copy, or Null when disabled.
Queued geometry already contains the camera transform, so later camera changes
cannot move earlier draws. `SetCamera(Null)` returns to identity.

## Anchored zoom and view corners

`camera.ZoomAt(newZoom, viewX, viewY)` changes zoom while keeping the world point
at that virtual coordinate stationary. It handles rotated cameras and nonzero
camera offsets. Invalid zoom/anchor values leave the camera unchanged. Call
`SetCamera(camera)` afterwards to apply the edited camera snapshot.

```blitzmax
Local viewX:Float, viewY:Float
If GetVirtualMouse(viewX, viewY) Then
    camera.ZoomAt(newZoom, viewX, viewY)
    SetCamera(camera)
End If
```

The anchor is in virtual coordinates; do not pass raw mouse/window pixels.
Use the camera offset as the anchor to zoom around its centre. The example uses
mouse-anchored zoom for the wheel and Q/E, falling back to the centre while the
pointer is outside the scene or over the minimap.

`camera.WorldCorners(viewX, viewY, width, height)` returns eight Float values:
world x/y for the virtual rectangle's top-left, top-right, bottom-right and
bottom-left corners, in that order. The result describes a rotated rectangle,
not an axis-aligned bounding box. It is a new array and does not modify the camera.
Use the actual visible virtual rectangle, or a clipped viewport rectangle.
For a render image, supply the virtual rectangle used when rendering that image.
Neither helper needs an active graphics context.

The example projects those corners through the minimap camera to draw a yellow
outline. Its yellow centre marker shows the main camera position; a cyan marker
shows the same world point as the main view's mouse dot. The outline shrinks when
zooming in and rotates with the main view. It is clipped at the minimap boundary.

## Views, clipping and targets

A camera does not change the virtual resolution, viewport, render target or clear
operation. `SetViewport` continues to be a clip rectangle in virtual coordinates;
it does not establish a new origin. For a minimap, set its clipping rectangle and
place the camera offset at that rectangle's centre. `examples/camera.bmx` shows
this together with a main camera. Independent aspect-fit presentation within each
sub-viewport is not introduced by this camera API.

The applied camera is drawing state on the canvas. It remains active when changing
render targets or calling `SetNativeResolution`. For an untransformed overlay,
explicitly select `SetCamera(Null)`, optionally inside a saved state. Render images
can use their own camera offset/zoom when selected; save/restore around that pass.
`DrawPixmap`/`GrabPixmap` retain physical-pixel semantics and bypass the camera.
Camera changes do not alter collision coordinates or stored collision layers.
Use world coordinates for collision queries.

## Coordinate conversion and input

| API | Meaning |
| --- | --- |
| `WorldToVirtual` / `VirtualToWorld` | Apply/invert the current camera |
| `camera.WorldToVirtual` / `camera.VirtualToWorld` | Convert with an explicit camera, without a graphics context |
| `WorldToWindow` / `WindowToWorld` | Combine the applied camera with window DPI and virtual presentation |
| `GetWorldMouse` | Mouse position in world coordinates, plus whether it is inside the scene |
| `CaptureCameraInput` | Retain a snapshot of camera and window presentation for later picking |
| `CaptureDrawTransform` / `CaptureImageTransform` | Include the camera when mapping object-local coordinates to/from virtual coordinates |

Existing `VirtualMouse*` and virtual/window conversion APIs remain camera-independent.
Window-to-world conversion returns False for letterbox bars/outside the window;
outside coordinates remain available without clamping. Pass `True` as the final
argument to respect viewport clipping too. World-to-window returns whether the
mapping is valid, not whether the world point is visible. An invalid input extent
returns False and zero coordinates.

Capture camera input with the window selected and the intended camera applied:

```blitzmax
SetCamera(camera)
Local input:TMax2DCameraInput = CaptureCameraInput()
SetCamera(Null) ' Draw an overlay without changing the retained picking map.
Local worldX:Float, worldY:Float
If input.WindowToWorld(MouseX(), MouseY(), worldX, worldY, True) Then
    ' Interact with the world at worldX/worldY.
End If
```

Snapshots do not track subsequent resize or camera edits; capture again for the
next frame. Window-input camera APIs reject calls with a render image selected,
since its camera may not describe the window. To pick a render image displayed
inside a scene, first reverse the transform used to draw that image, then its
presentation/camera. The camera-only conversions remain usable with any target.

## Manual or scoped state

Both styles preserve camera, drawing settings, font, target and presentation:

```blitzmax
PushMax2DState()
SetCamera(camera)
DrawImage(player, playerX, playerY)
PopMax2DState()
```

```blitzmax
Using
    Local scene:TMax2DStateScope = ScopedMax2DState()
Do
    SetCamera(camera)
    DrawImage(player, playerX, playerY)
End Using
```

`TMax2DStateScope` implements `ICloseable`. `Close` restores state on normal exit,
Return, an Exit crossing the Using boundary, or an exception. It is idempotent and
has no graphics finalizer. An unused/abandoned scope is not automatically restored
by garbage collection: use Using or close it explicitly.

A scope restores its owning canvas and leaves a different currently selected
canvas selected. Closing a scope after its owner was closed is harmless. Manual
Push/Pop pairs may be nested inside a scope. A manual Pop cannot consume the scope's
own save; it throws before changing the stack. Closing an outer scope explicitly
unwinds still-open inner scopes and manual saves, restoring the outer snapshot;
subsequent Close calls on those inner scopes do nothing.

The current BlitzMax Using implementation suppresses exceptions from Close.
Ordinary restoration is tested, but graphics/device failures can still prevent
restoration. Explicit Close calls can surface those failures. Scopes do not undo
pixels already drawn, image changes, or window-management operations. Graphics
operations, including scope closure, must remain on the rendering thread.

## Validation and limits

`tests/camera_math.bmx` runs without graphics and covers camera pivot/rotation,
round trips, letterboxing, synthetic 2x DPI input and invalid mappings.
`tests/camera_render.bmx` covers primitives, images, text, tiling, clipped draws,
physical transfers, queued camera changes, snapshots, manual/scoped restoration,
Return/Exit/exception cleanup and closed/cross-context scope handling. The
cross-context portion is omitted for the single-window Direct3D backends.
`tests/scalable_text.bmx` additionally checks camera-driven glyph density and
unchanged layout metrics using the supplied font file.

The regression runners include the camera tests; select `--test camera_render`
(Python) or `-Tests camera_render` (PowerShell) for a focused run. The interactive
example supports `-ud max2d_gl`, `max2d_d3d9` or `max2d_d3d11`, with SDL3 as default.
Its `--test` runtime argument draws three frames then exits. It imports
`Max2D.ScalableFont` and uses Arial on macOS, Segoe UI on Windows, or DejaVu Sans
on Linux when that system font is available. Otherwise it falls back to the
built-in bitmap font. Interface labels use native coordinates; bitmap fallback
uses integer scaling to avoid uneven strokes at fractional scene scales.
The minimap background is drawn as a rectangle: a second letterboxed `Cls` would
also repaint the window's presentation background.

This first camera implementation provides position, offset, uniform zoom and
rotation. It does not add tracking policies, smoothing, shake, automatic culling,
large-world precision beyond the existing Float drawing API, or a scene graph.
Those can be built on top without changing the basic drawing contract.

Camera math and rendering/scope regressions passed in release on native macOS
ARM64 (SDL software, default SDL and OpenGL), Linux ARM64 Parallels (OpenGL/SDL),
and Windows 11 ARM64 Parallels running x64 binaries (OpenGL/SDL/D3D9/D3D11).
The software camera/scope test also passed in a macOS debug build.
Existing integration, input, viewport and collision checks also passed in the
macOS selection; Linux integration passed. Scalable-font camera density passed
with Noto Sans on macOS software rendering. The camera/minimap example was built,
run and visually checked on macOS. These are the same hardware-coverage limits
as the [stabilisation baseline](stabilisation.md).

The subsequent anchored-zoom/view-corner refinement passed the extended camera
math tests and camera rendering tests on macOS OpenGL and SDL software. The
updated default SDL example was visually checked with a rotated main view,
minimap outline and matching mouse marker. This refinement did not change any
backend-specific rendering code; it was not separately rerun in the VMs.
