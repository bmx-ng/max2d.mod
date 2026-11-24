# Camera World

A complete scene example combining a scrolling star chart, nine cached relay
stations, a moving survey ship, a fixed interactive HUD and ordinary Max2D
drawing before and after scene rendering.

## Build and run

From the BlitzMax SDK directory, on macOS:

```sh
bin/bmk makeapp -r -t gui -o /tmp/camera_world mod/max2d.mod/demos/camera_world/camera_world.bmx
open /tmp/camera_world.app
```

SDL3 GPU is the default. Add `-ud max2d_gl` for OpenGL. On Windows or Linux,
choose a suitable output path and run the resulting executable directly.
No external artwork is required; the application uses a platform font with a
default-font fallback.

Build without `-t gui` and run with `--test` for the integration checks.
They need a graphics display and exercise camera-aware picking, HUD selection,
capture reuse, letterboxed input at 1x/2x density, viewport clipping, offscreen
rendering and caller-state restoration.

## Controls

| Input | Action |
| --- | --- |
| Arrow keys | Pan in screen directions; disable follow |
| Q / E | Zoom out/in continuously |
| J / K | Rotate the camera |
| F, or Follow ship button | Toggle following |
| R, or Reset camera button | Centre the chart with default zoom and rotation |
| + / -, or sidebar buttons | Change zoom in steps |
| Click a relay | Select it and centre the camera on it |
| Space | Pause/resume ship motion |
| D | Toggle bounds overlay |
| Escape | Quit |

The ship starts in follow mode. Pan to explore the chart or reset to see its
centre. Newly visible relays capture once; camera movement then reuses those
pixels. Zoom changes their apparent size without automatically increasing
capture resolution. Increase a composite's resolution explicitly if the intended
zoom range requires sharper output, accounting for the larger storage cost.

## Scene structure

```text
Scene root
  World layer: camera snapshot, viewport (30, 140, 780, 510)
    Grid and stars: custom drawing with declared bounds
    Nine relay composites: independent automatic caches
      Procedural station art
      Station label
    Survey ship: ordinary custom drawable
  HUD layer: identity camera
    Follow / Reset / Zoom buttons
    Screen-space label tracking the ship
```

The application draws the chart/sidebar backgrounds before `scene.Render()`.
It draws headings, controls, counters and the minimap afterwards. The minimap
uses ordinary Max2D primitives and the camera's inverse transform to draw the
visible world quadrilateral. Its temporary viewport is scoped so it cannot
leak into later drawing.

### Camera ownership

The application owns and edits one `TCamera2D`. A layer takes a **snapshot**,
so call `world.SetCamera(camera)` after changes and before coordinate queries
or rendering:

```blitzmax
Local world:TLayerNode = TLayerNode.Create()
Local hud:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(world)
scene.Root().AddChild(hud)

Local camera:TCamera2D = New TCamera2D
camera.offsetX = 420
camera.offsetY = 395
world.SetViewport(TSceneRect.Create(30, 140, 780, 510))

' Each frame, after updating application state:
camera.x = shipX
camera.y = shipY
world.SetCamera(camera)

Local screenX:Float, screenY:Float
scene.LocalToScreen(ship, 0, 0, screenX, screenY)
shipLabel.SetPosition(screenX + 20, screenY - 35)
scene.Update(deltaSeconds)
scene.Render()
```

The HUD has no world camera. Its buttons and the tracking label retain constant
screen size. The label's position is projected from the ship; this does not
reparent the ship or change its render layer. Near the chart edge the label is
hidden to keep it clear of the fixed sidebar.

### Picking and clipping

Window input is first converted by `GetVirtualMouse`, then dispatched in
virtual screen coordinates. Do not apply the world camera yourself: the scene
uses each layer's camera for picking. This allows the same dispatch call to
reach either a world station or a HUD button.

The scene's input clip covers the full presentation, including the sidebar.
The world layer has its own smaller viewport, which restricts both drawing and
picking. Changing render targets does not redefine the scene's input clip.
Application suspension cancels input and stops elapsed-time advancement.

### Caching and allocation

Each station owns one composite cache. The camera is outside that local capture,
so panning, rotation and zoom do not invalidate its source pixels. Culling skips
offscreen station subtrees; the first frame that reveals a station may allocate
and capture it. There is a 16 MiB scene storage budget.

The ship updates its existing transform. Geometry and minimap corner arrays are
retained, and stats are copied into a reusable record. Diagnostic strings and
the mouse mapping helper can allocate; this is not an allocation benchmark.
The buffer counter excludes fonts, driver overhead and other application data.

The application owns the loop, timing, camera and ship motion. Scene rendering
does not update simulation, clear the target or present the frame. A physics
application can run its fixed steps before setting node transforms; the scene
does not need to own the physics bodies.

## Source guide

- [camera_world.bmx](camera_world.bmx): setup, input, camera controller, HUD and minimap.
- [world_nodes.bmx](world_nodes.bmx): reusable relay/button components and drawing nodes.
- [world_tests.bmx](world_tests.bmx): deterministic integration checks.

Integration checks pass on macOS SDL3 GPU and OpenGL. Native touch conversion is
demonstrated separately in [Touch Playground](../touch_playground/README.md);
this example uses desktop mouse and keyboard input.
