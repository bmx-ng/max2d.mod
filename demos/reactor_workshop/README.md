# Reactor Workshop

A complete scene example with three reusable reactor instances. Each owns its
animation state, cached plasma and bloom stage; all borrow one housing image.
There are no external assets: the housing is drawn once at startup.

## Build and run

From the BlitzMax SDK directory:

```sh
bin/bmk makeapp -r -t gui -o /tmp/reactor_workshop mod/max2d.mod/demos/reactor_workshop/reactor_workshop.bmx
open /tmp/reactor_workshop.app
```

This selects SDL3 GPU. Add `-ud max2d_gl` for OpenGL. On Windows or Linux,
choose a suitable output path and launch the resulting executable directly.
The application loads Arial on macOS, Segoe UI on Windows or DejaVu Sans on
Linux, falling back to Max2D's default font.

For deterministic integration checks, build without `-t gui`, then run the
executable with `--test`. These checks require a graphics display and verify
capture reuse, effect-only updates, independent instances, resolution changes,
cache bypass, detach/reattach and explicit resource release.

## Controls

| Input | Action |
| --- | --- |
| Click reactor, or 1 / 2 / 3 | Select instance |
| M | Cycle still, subtree motion, effect pulse, source spin |
| Space | Pause/resume selected instance |
| C | Toggle automatic caching |
| S | Toggle plasma resolution between 1x and 2x |
| Left / Right | Adjust bloom power |
| D | Toggle scene bounds overlay |
| R | Release scene buffers; next render rebuilds them |
| I | Print scene inspection to the console |
| Escape | Quit |

This example converts mouse coordinates and dispatches scene pointer events.
Native multi-touch conversion belongs to the planned touch example.

## How the component works

```text
TWorkshopReactor (transform, input target, animation state)
  TSpriteNode       shared housing image
  TCompositeNode    fixed plasma capture, automatic cache, owned bloom stage
    TReactorCore    custom drawing with declared local bounds
  TTextNode         name
  TTextNode         animation status
```

The component lives in [reactor.bmx](reactor.bmx). It selects no graphics
backend and polls no keyboard or mouse state. Its pointer callback records a
selection request; the application consumes it through `TakeSelection()`.
Gameplay code can instead keep a typed reference and call `SetPower()`,
`SetRunning()` or `SetMode()` directly.

After selecting a graphics framework and matching effects provider, import
`Max2D.SceneEffects` and include the component. With graphics active:

```blitzmax
Local housing:TRenderImage = CreateReactorHousing()
Local scene:TScene = TScene.Create()
Local layer:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(layer)

Local reactor:TWorkshopReactor = TWorkshopReactor.Create( ..
    housing, TImageFont.DefaultFont(), "Engine", 300, 250, ..
    90, 210, 255, REACTOR_PULSE)
layer.AddChild(reactor)
reactor.SetPower(4)

' In the application's loop, with elapsed time in seconds:
scene.Update(deltaSeconds)
scene.Render()

' At shutdown, while the graphics context still exists:
scene.Destroy()
housing.ReleaseFrames()
```

### Reading the counters

The initial three modes demonstrate separate paths:

- **Move subtree:** changing the reactor's outer transform reuses the finished
  plasma output.
- **Pulse effect:** changing bloom intensity processes the saved source without
  drawing the core again.
- **Spin source:** changing a child transform inside the capture requires a new
  source capture and effect update.

Once warmed, the default scene should report one capture, one reused output
and two effect stages per frame. A stage count is a scene-level operation,
not a GPU draw-call count; bloom performs multiple internal passes.
The per-reactor draw counter counts actual source visits during that frame.

Name and status text are siblings of the composite. Changing them does not
invalidate the plasma. Fixed capture bounds keep the source canvas stable;
the bloom stage supplies its own padding. For custom source data changes
outside node setters, call `InvalidateContent()` on the source node.

## Ownership, memory and allocation

Each instance owns its bloom descriptor and composite buffers. Never share an
attached stage between instances. The application owns the shared housing and
font lifetime. Destroy the scene before releasing the shared image, and release
graphics resources before closing the graphics context.

The scene has a 32 MiB buffer budget. Its counter covers scene-managed capture
and effect storage, excluding the shared housing, fonts, driver overhead and
other application resources. Doubling resolution increases area and therefore
buffer costs approximately fourfold.

Animation updates existing nodes and effect settings. It does not construct
new subtrees or effect descriptors every frame. Buffers are reused after warmup;
resolution changes and resource release can allocate again. The diagnostic HUD
does format strings each frame, so this application is not an allocation-free
benchmark.

## Source guide

- [reactor_workshop.bmx](reactor_workshop.bmx): setup, input, timing, HUD and cleanup.
- [reactor.bmx](reactor.bmx): reusable component and shared housing generation.
- [workshop_tests.bmx](workshop_tests.bmx): deterministic integration checks.

The example is validated on macOS with SDL3 GPU and OpenGL. Platform-specific
font paths are supplied for Windows and Linux; those builds still need validation.
