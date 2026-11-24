# Tilemap and particle scene adapters

These are separate optional imports. Neither is required by `Max2D.Scene`.

## Tilemaps

`Max2D.SceneTileMap` supplies `TTileMapNode`. It references an existing
`TTileMap`, including maps loaded through Tiled or LDtk. Images and map data
remain application-owned. Local scene transforms, inherited tint/alpha and the
layer view are passed to the existing map renderer; its visible-cell culling,
layer ordering and animated artwork remain in use.

```blitzmax
Import Max2D.SceneTileMap

Local ground:TTileMapNode = TTileMapNode.Create(map)
layer.AddChild(ground)
ground.SetPosition(40, 100)

' After an external map edit:
map.layers[0].SetCell(3, 2, grassTile)
ground.InvalidateContent()
```

Notify every referencing node after changing cells, sprites, objects, layer
properties, or shared artwork. The adapter does not poll the map for edits.
`SetMap` resets the animation clock and clears old declared bounds; `GetMap`
returns the shared reference. Destruction drops that reference without releasing
shared images. Scene resource release does not erase the map.

### Animation and bounds

Maps are static by default. Enable `SetProcessing(True)` to advance animated
tiles using `scene.Update(dt)` in seconds. Updates invalidate enclosing captures.
Alternatively, call `SetElapsedMilliseconds(value)` for an application-controlled
clock. `ElapsedMilliseconds()` returns whole milliseconds. Fractional milliseconds
are retained during updates. Scene pause and detachment suspend automatic updates.
The clock accepts 0 through 9,007,199,254,740,991 milliseconds; overflow throws.

Bounds are **unknown by default**, allowing the map renderer to cull visible
cells without assuming that occupied cells describe the full artwork extent.
For a finite ordinary map, declare a conservative rectangle when scene culling
or automatic composite sizing is wanted:

```blitzmax
ground.SetSelfBounds(TSceneRect.Create(0, 0, 784, 392))
```

Include oversized/offset artwork, sprites, objects and all layer offsets. Update
this rectangle when editing changes the extent. `ClearSelfBounds()` restores
unknown bounds. A composite can instead declare its own fixed capture rectangle.
Static maps can then use automatic composite caching; explicit edits or clock
changes invalidate the capture through normal scene rules.

Parallax and repeating image layers depend on the current view. Keep them outside
cached/effect composites, and leave scene bounds unknown unless you can supply a
correct view-dependent envelope. The adapter does not translate parallax into
independent scene layers. Picking/physics still use the existing map/grid query
APIs: do not call the immediate-mode `map.Pick` outside a matching drawing state
and assume it includes the scene transform. Convert input into the appropriate
layer and node coordinates first for ordinary non-parallax grid queries.

The adapter adds no per-cell nodes. Existing tilemap renderer allocation and
sorting behaviour is unchanged; it is not a promise that map drawing allocates
nothing.

## Particles

`Max2D.SceneParticles` supplies `TSceneParticleNode`, a small retained particle
batch. It is a CPU simulation with explicit emission, constant local velocity
and linear opacity fading. It does not create one scene node per particle.

```blitzmax
Import Max2D.SceneParticles

Local sparks:TSceneParticleNode = TSceneParticleNode.Create(512, sparkImage)
layer.AddChild(sparks)
' Local position, velocity in units/second, lifetime in seconds, square size, RGB:
Local accepted:Int = sparks.Emit(100, 60, 40, -80, 0.8, 12, 255, 190, 90)
```

The image is optional; without it particles draw as discs. An image uses frame
zero stretched into the specified square, ignoring its image handle. Particle
colour and fading opacity multiply inherited scene tint/alpha. Particles are
local to their node, so moving or scaling the node affects particles already
emitted. Camera/layer behaviour is the same as other scene drawables.

`Create(capacity, image)` allocates the fixed pool. A full pool makes `Emit`
return False without eviction or growth. `Count()` and `Capacity()` are cheap
queries. Emission enables variable-step processing; when the pool empties it
stops processing. Scene pause and detachment freeze automatic simulation.
Applications remain responsible for emission timing, bursts and randomness.

Survivors retain emission order for alpha blending. Updates reuse inline slots;
normal emission and update do not allocate particle objects. `Clear()` empties
the pool and stops processing but keeps capacity and shared artwork. Destruction
releases CPU storage and the image reference; it does not release the shared image.
Local bounds are maintained after emission, movement, expiration and clearing,
which also invalidates enclosing captures. No bounds guess or manual invalidation
is required. Keep dynamic particles separate from large static cached subtrees
when you want those static captures reused.

Lifetimes and sizes must be positive, values finite, and RGB channels within
0..255. Trajectories are limited to a conservative coordinate envelope of 1e30
units per axis to keep Float drawing bounds representable. This initial batch
does not implement acceleration, collision, trails, animated sprite frames,
automatic emission or GPU simulation. Build burst patterns in application code.

## Runnable example

[`examples/scene_adapters.bmx`](../../examples/scene_adapters.bmx) combines a cached
checkerboard tilemap with a 512-slot particle pool. Click to edit a cell and emit a
burst, Space to emit centrally, and P to pause the scene. Its HUD shows live
particle count and cache hits. Build from the SDK directory:

```sh
bin/bmk makeapp -r -t gui -o /tmp/scene-adapters mod/max2d.mod/examples/scene_adapters.bmx
```
