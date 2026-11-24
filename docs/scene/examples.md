# Worked scene examples

The scene framework now includes input, cached composition, effects, budgets and
inspection. All three complete applications are available below, with developer guides
and integration checks.

See [platform validation](validation.md) for commands, tested configurations
and toolchain limitations.

## 1. Reactor Workshop

[Run the complete Reactor Workshop](../../demos/reactor_workshop/README.md).
It combines three independently controlled reactor subtrees, shared housing art,
automatically cached plasma, bloom, pointer selection and live capture counters.
Its source separates the reusable component from application input and timing.
The accompanying checks verify capture reuse and resource lifetime.

## 2. Touch Playground

[Run the complete Touch Playground](../../demos/touch_playground/README.md).
Three draggable tiles demonstrate parent-space offsets under rotation and
non-uniform scale, independent pointer capture, and cancellation when targets
are hidden, detached or made non-invertible. It includes a native SDL3 touch
adapter and a two-pointer desktop simulation. Integration checks exercise the
same components and native identifier mapping.

## 3. Camera World

[Run the complete Camera World](../../demos/camera_world/README.md).
A moving survey ship and cached relay stations share a scrolling, zoomable,
rotating world layer. A separate identity-camera HUD provides fixed buttons and
a projected ship label. Ordinary Max2D drawing supplies backgrounds and a
minimap around the scene render call. Checks cover picking, capture reuse,
letterboxing, viewport clipping and caller-state preservation.

## Reusable animation timelines

[Scene animation](animation.md) includes a runnable easing comparison with delayed,
looping transform and opacity tracks, plus scene pause and restart controls.

## Tilemaps and particles

[Scene adapters](adapters.md) includes a cached editable tilemap with a reusable
particle pool. Click to edit cells and emit bursts; pause freezes simulation.

## Live reveal and cutout masks

[Live subtree masks](../../examples/scene_subtree_masks.bmx) shares one animated
source between two cached panels, including cached ancestors. It demonstrates
normal/inverse alpha, source detachment, buffer recreation and unchanged picking.
See the [mask guide](stages.md#live-subtree-alpha-masks) for ownership and coordinate
rules. Build from the SDK directory:

```sh
./bin/bmk makeapp -r -t gui mod/max2d.mod/examples/scene_subtree_masks.bmx
```

Add `-ud max2d_gl` for OpenGL, or `-ud max2d_d3d9` / `-ud max2d_d3d11`
on Windows. Space pauses; D detaches/attaches the source; R
releases buffers. For automated launch checks, build without `-t gui` and pass
`--test`; the console build closes after three frames. The macOS GUI app stub
does not forward ordinary command-line flags.

## Custom drawing without losing scene state

```blitzmax
Type TBadgeNode Extends TCustomDrawNode
    Function Create:TBadgeNode()
        Local badge:TBadgeNode = New TBadgeNode
        badge.SetSelfBounds(TSceneRect.Create(-20, -20, 40, 40))
        Return badge
    End Function

    Method OnDraw(context:TSceneDrawContext) Override
        context.SetColor(255, 190, 60)
        DrawOval(-20, -20, 40, 40)
        context.SetColor(255, 255, 255)
        context.SetAlpha(0.5)
        DrawRect(-8, -3, 16, 6)
    End Method
End Type
```

Geometry uses ordinary Max2D calls in local coordinates. The context helpers
multiply inherited tint/alpha; they do not replace them. The renderer restores
state afterwards. A changed radius would require updating the bounds and calling
InvalidateContent; it would be changed during update, not during OnDraw.

## Review outcomes

These scenarios establish requirements for the first implementation:

1. Reusable visual subtrees need no global scene singleton or parent-name lookup.
2. Shared resources and per-instance processing storage have separate owners.
3. Mutable raw effect parameters require an explicit invalidation path.
4. Pointer positions must convert into arbitrary ancestor coordinates, with
   cancellation when inverse transforms become unusable.
5. Camera and HUD boundaries must be explicit and shared by rendering and input.
6. Custom drawing needs both bounds and inherited-state helpers.

All three scenarios now have runnable applications and integration checks.
Their guides describe validation scope and remaining platform/device checks.

## ECS integration

[ECS Swarm](../../demos/ecs_swarm/README.md) demonstrates optional Flecs simulation
with a retained scene-node pool, explicit update order, entity reuse and teardown.
