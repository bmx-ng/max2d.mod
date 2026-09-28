# Nested drawing state

Use `PushMax2DState()` / `PopMax2DState()` for explicit saves, or
`ScopedMax2DState()` in a `Using` block for deterministic restoration on scope exit.
Both save the parent coordinate transform alongside the existing camera, object
transform, colours, blend, font, render target and view settings.

## Group coordinates

- `TranslateCoordinates(x, y)` moves a group, including its draw positions.
- `RotateCoordinates(angle)` rotates a group clockwise (degrees).
- `ScaleCoordinates(x, y)` scales group positions and geometry.
- `TransformCoordinates(xx, xy, yx, yy, tx = 0, ty = 0)` also supports shear.
- `ResetCoordinates()` restores the identity parent transform.

Each operation is composed in the current local coordinate system. For example,
translate by `(100, 50)`, then scale by `(2, 2)`: local `(10, 10)` becomes
world `(120, 70)`. A subsequent child translation is scaled by its parent.

```blitzmax
Using
    Local scope:TMax2DStateScope = ScopedMax2DState()
Do
    TranslateCoordinates(100, 50)
    ScaleCoordinates(2, 2)
    DrawRect(10, 10, 20, 15)
End Using
```

The full drawing order is: subtract handle; apply the existing object transform;
add draw position and origin; apply parent coordinates; apply camera; map virtual
coordinates to output pixels. `SetTransform()` still controls each object's
geometry. It does not reset parent coordinates or the camera.

Primitives, images and text share this order, including render-to-texture draws.
Scalable fonts account for group magnification when choosing raster density;
text layout measurements remain in local units. `TileImage` inverse-maps the
viewport to cover transformed groups. A collapsed transform draws no tiles.
`DrawPixmap` retains its direct output-pixel semantics.

`CaptureDrawTransform` and `CaptureImageTransform` include the complete drawing
transform, so their inverse methods can pick nested objects. `WorldToVirtual`,
`VirtualToWorld` and world mouse helpers remain camera-only: world coordinates
are after parent transforms. Use a captured draw transform for local picking.

Collision shapes include parent coordinates but exclude the camera. This also
applies to `ImagesCollide2`: its explicit rotations/scales replace the object
transform, while the current origin and parent coordinates still apply.

Transforms must remain finite. Zero scale is allowed, but inverse picking
returns False for collapsed transforms. Saved scopes restore independent copies.
See [camera scopes](cameras.md) for ownership and nested-close rules.

## Nested clipping

`IntersectViewport(x, y, width, height)` intersects the current clip with a
rectangle in virtual screen coordinates. It cannot enlarge an existing clip;
an empty intersection stays empty. Negative sizes are rejected.

Clips are axis-aligned and independent of cameras and coordinate transforms.
This is useful for panels with moving or rotating content. Use `SetViewport`
to replace a clip, or save/restore drawing state around a child clip. Changing a
clip alone does not change the coordinate origin. For a coloured panel
background, draw a rectangle inside the clip.

See [drawing_state.bmx](../examples/drawing_state.bmx) for nested tiles, local
mouse picking and a child clip. It supports SDL3 (default), OpenGL, D3D9 and
D3D11 through the usual `max2d_gl`, `max2d_d3d9`, `max2d_d3d11` build flags.

## Verification (2026-09-24)

`drawing_state` and the existing `camera_render` regressions passed on macOS
(SDL software, SDL default and OpenGL), Linux ARM64 in Parallels (SDL and
OpenGL), and Windows 11 in Parallels (SDL, OpenGL, D3D9 and D3D11).
Existing input/collision checks passed on macOS; Linux also passed camera math,
input mapping and integration checks. Scalable-font density tests passed with
Noto Sans on macOS SDL software, and the example was checked visually on macOS.

A final refactor removed temporary matrix allocations from oval tessellation and
font-density selection. The macOS SDL software camera, nested-state and
scalable-font tests were rerun after that refactor. VM results above precede
this arithmetic-equivalent refactor. Physical Windows/Linux GPU coverage remains
an outstanding hardware test, as recorded in the stabilisation notes.
