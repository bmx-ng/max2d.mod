# ECS Swarm

A worked integration between `Ecs.Flecs` and `Max2D.Scene`. Click or press Space
to spawn a burst of moving drones. P pauses both simulation and scene updates;
Escape exits. Drones bounce inside the arena and expire after twelve seconds
(the initial population has staggered lifetimes).

## Build and run

Install the optional `Ecs.Flecs` module alongside Max2D. From the SDK directory:

```sh
bin/bmk makeapp -r -t gui -o /tmp/ecs-swarm mod/max2d.mod/demos/ecs_swarm/ecs_swarm.bmx
open /tmp/ecs-swarm.app
```

The final command is for macOS; run the resulting executable on other platforms.
The application uses SDL3 GPU. The integration itself does not select a backend.

## Ownership and update order

`swarm.bmx` contains the small simulation/presentation bridge. Flecs components
contain only numbers: position, velocity, remaining lifetime and a pool slot.
The application retains 512 scene nodes and full, generation-bearing entity IDs.
There are no BlitzMax object references in Flecs component memory.

```blitzmax
Local scene:TScene = TScene.Create()
Local layer:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(layer)
Local swarm:TSwarm = TSwarm.Create(layer, 512)
swarm.Spawn(450, 360, 100, -40)

' Each frame, outside scene callbacks; dt is in seconds, capped at 0.1.
If Not paused Then swarm.Step(dt)
scene.Update(dt)
scene.Render()

' Before destroying the scene or closing graphics:
swarm.Close()
scene.Destroy()
```

`Step` updates component arrays through a retained query iterator, queues expired
entities, flushes deletion after iteration, then copies positions and headings
to scene nodes. Borrowed component pointers never survive query iteration.
No Flecs systems are registered here, so the application drives the query directly
and does not additionally call `world.Progress`. In a system-driven game, use
simulation/progress, command flush, presentation sync, then scene update/render.
Scene pause alone does not pause an independent ECS world; the application owns
that decision.

`Sync` also detaches views whose entities were deleted externally or lost their
body component. Call it after external ECS edits and before further spawning if
you need the newly freed slots immediately. Slots and entity bindings are owned
by the bridge: do not change a body's slot or attach these views elsewhere.
Entities created outside `Spawn` are not automatically assigned a view.

The pool refuses spawns when full. Expiry detaches nodes for reuse; final `Close`
destroys them. A scene node is never responsible for deleting its entity.
Changing a parent layer's transform changes presentation without rewriting ECS
coordinates. Picking can be added by looking up a picked view in the binding pool
and queuing a simulation command, rather than writing components during traversal.

## Allocation and lifetime

Creation allocates the world, query, arrays and scene nodes. Ordinary motion and
presentation updates reuse the iterator, numeric components and nodes. Spawning,
ECS archetype growth, deletion queues, scene attachment and HUD strings can still
allocate; this is not a claim of zero allocation for the whole application.
The fixed slot scan is deliberately simple and costs O(capacity) per sync.

Always call `Close` before `scene.Destroy`. The current Flecs wrapper exposes
finalizers but no explicit public close operation. This example releases the native
query before the native world and clears their handles to prevent double release.
Keep those details contained in `Close`; do not retain/use the world or query after
closing. Closing twice is harmless. Shared images, if added, remain application-owned.

## Regression checks

From the Max2D repository:

```sh
python3 tests/run_regressions.py ecs --sdk ../..
```

This optional profile checks movement, capacity, expiry, external deletion,
generation-aware entity replacement, retained view reuse and ordered cleanup.
It needs Flecs but no graphics window. The ordinary core profile does not require
ECS. This example adds no dependency to `Max2D.Scene` itself.
