# Culling and render diagnostics

Culling lets a scene skip known offscreen branches. It is **disabled by default**,
so existing custom draw callbacks continue to run as before. Enable it when
nodes provide reliable drawing bounds:

```blitzmax
scene.SetCulling(True)
scene.Render()
```

Culling changes drawing traversal only. It does not suppress Update or
FixedUpdate, remove nodes from the tree, change focus, or alter pointer picking.
A culled node's OnDraw is not called; keep gameplay and other required work in
update callbacks rather than drawing callbacks.

## What can be skipped?

For each visible spatial node, the renderer tests cached aggregate content
bounds, transformed through its world matrix and the layer camera. The effective
clip is the intersection of the caller's viewport and the layer viewport, just
as in normal scene rendering. An empty effective clip can skip the entire branch.
Culling uses the current render target and clip, not the scene's separate input
clip or the window input mapping.

A spatial group whose complete known bounds are outside the clip can be skipped
without visiting its descendants. Non-spatial parents preserve the transform
chain; their spatial descendants are tested normally. Hidden and zero-opacity
branches are skipped independently of culling, as before.

Unknown bounds prevent that branch from being rejected by bounds. Known children
beneath an unknown parent can still be tested individually. Empty or collapsed
bounds are conservatively kept, since custom code may draw lines or points.
Bounds with extreme numerical scales are also kept. A small uncertainty margin
at clip edges accommodates Float rendering transforms; borderline objects may
render even if their mathematical bounds are just outside the clip.

Declared bounds must include **all** pixels a custom draw can produce, including
strokes and intentional overhang. Leave bounds unknown when that cannot be
promised. The renderer cannot infer output from arbitrary OnDraw calls. Culling
uses output bounds, including composite stage expansion.

Geometry changes must invalidate cached content as explained in
[bounds and ordering](bounds-order.md). Node setters do this automatically.
External mesh/image/font changes and application-managed custom geometry require
`InvalidateContent()` on affected nodes. Incorrect stale bounds can hide visible
content when culling is enabled.

## Organize large scenes into spatial groups

Culling still has to examine branch roots. Group nearby objects together under
TSceneNode2D parents so an offscreen group can avoid many descendant visits.
An initial bounds rebuild may visit the whole group; subsequent unchanged bounds
are cached. Moving only the camera does not rebuild local bounds or node world
matrices.

Unknown drawing in a group makes its aggregate bounds unknown, so avoid placing
an unbounded custom drawable above an otherwise bounded large scene unless that
is intentional. Culling is a traversal optimization, not a spatial index or a
guarantee that every workload becomes faster. Very small scenes may not benefit
from the extra bounds tests.

## Read statistics without allocations

```blitzmax
Local stats:TSceneStats = New TSceneStats

' In the application loop:
scene.Render()
scene.CopyStats(stats)
Print "Visited: " + stats.NodesVisited()
Print "Draw visits: " + stats.DrawVisits()
Print "Culled branches: " + stats.CulledSubtrees()
```

CopyStats fills reusable storage. CaptureStats allocates an independent snapshot
when one is needed for history or inspection. Neither query performs GPU reads.
Counters describe the latest Render attempt, reset at the beginning of each call,
and are not cumulative. Before the first render, all counts are zero.

| Accessor | Meaning |
| --- | --- |
| `Captures()` | Subtree captures performed by render groups. |
| `CacheHits()` | Reused composite outputs with no capture work. |
| `StagePasses()` | Completed effect-stage updates, not internal GPU passes. |
| `RetainedStorageBytes()` | Estimated registered texture bytes at render exit. |
| `PeakStorageBytes()` | Highest accepted total texture reservation during this render, including replacements. |
| `Completed()` | Render and caller-state restoration finished successfully. |
| `NodesVisited()` | Popped traversal nodes, including root, layers and skipped branch roots. |
| `DrawVisits()` | Spatial drawing-hook visits, including plain groups and a hook that threw. |
| `CulledSubtrees()` | Branch roots rejected by known offscreen bounds. |
| `HiddenSubtrees()` | Branch roots skipped for their own visibility/zero opacity. |
| `ClippedSubtrees()` | Branch roots skipped by an empty clip with culling enabled. |
| `BoundsTests()` | Aggregate bounds tests performed for culling. |
| `UnknownBounds()` | Tests where unknown bounds prevented rejection. |
| `BoundsRebuilds()` | Successful aggregate bounds cache rebuilds during Render. |
| `WorldRebuilds()` | Successful world-matrix rebuilds during Render. |

A skipped branch counts **once**, not once per descendant: counting all its
children would defeat the traversal saving. BoundsRebuilds can exceed NodesVisited
on a cold render because measuring a group may populate descendant caches.
DrawVisits is not a GPU draw-call count: an empty group draws nothing, while a
custom hook can issue many primitives. Use the backend's existing diagnostics for
draw calls, batching and GPU/resource information.

If Render throws, its partial counts remain available with Completed False.
The next Render resets them. Statistics are collected whether culling is enabled
or not; culling-specific counters remain zero when disabled. Update/input queries
do not alter the last render's counters.

Warm culling and CopyStats add no per-node or per-test allocations. Render still
creates its existing outer Max2D state scope. The first bounds query can allocate
scratch rectangles or warm font-layout caches. Explicit CaptureStats also allocates.

## Example and regression checks

[scene_culling.bmx](../../examples/scene_culling.bmx) draws 2,500 tiles in 100
spatial chunks. Arrow keys move the camera; C toggles culling. Its HUD reports
visits, skipped branches and cache rebuilds. The HUD uses ordinary Max2D drawing
after scene.Render and is therefore excluded from scene counters.

[scene_culling.bmx tests](../../tests/scene_culling.bmx) compare complete rendered
pixels with culling disabled/enabled under rotation, shear, negative scale and
clipping. They also check cache reuse, unknown bounds, camera/caller clips,
updates/input independence, failed-render statistics and allocation after warmup.
The regression runner includes these checks in the SDL Renderer, OpenGL,
SDL GPU and native Direct3D 9/11 profiles. Optional [GPU timers](../gpu-profiling.md) can measure an
application-selected region on OpenGL and Direct3D 9/11. Automatic per-scene/stage
GPU timing and per-scene texture allocation counts remain future diagnostics.

## Inspecting a scene

```blitzmax
Print scene.InspectTree()
```

This returns a text snapshot without needing `Graphics`. Each row contains a
child-index path from `root`, diagnostic name, built-in node category, attachment
and readiness state, update/input flags, local visibility/alpha, dirty flags and
cached content/output bounds. Render groups also report charged texture bytes.
The header reports current scene storage and budget. Custom subclasses are shown
under their nearest built-in category; use `SetName` to identify their purpose.

Inspection requires an idle live scene. It does not invoke application bounds
callbacks, rebuild caches, draw or read GPU data. Bounds labelled `cachedContent`
and `cachedOutput` can be stale when `boundsDirty=1`; before first measurement
those caches may be unknown. Flags describe each node's own settings, not a
flattened view of inherited eligibility. The snapshot allocates strings and a
traversal array, so request it on demand rather than every frame.

## Bounds and hit-region overlay

```blitzmax
scene.SetDebugOverlay(True)
scene.Render()
' Later:
scene.SetDebugOverlay(False)
```

`GetDebugOverlay()` returns the toggle. The overlay draws after scene content on
the current target, with the original caller viewport and each layer's camera and
clip. It traverses cached composite children without capturing them or applying
their effects again. Hidden and zero inherited-alpha subtrees are skipped.

| Colour | Meaning |
| --- | --- |
| Cyan | Local aggregate content bounds transformed into the layer view. |
| Yellow | Output bounds, including effect padding. |
| Green | Interactive rectangular hit region, subject to ancestor input flags and input clip. |
| Magenta cross | Unknown content or output bounds, marked at the local origin. |

Coincident outlines overlap: yellow covers cyan, and green is drawn last. Explicit
hit rectangles take precedence; otherwise self bounds are used. Arbitrary custom
`HitTestLocal` shapes are **not** traced. Bounds remain rectangles transformed by
the full affine matrix, including shear and negative scale.

The overlay never calls `HitTestLocal` or dispatches input, and does not alter
picking or effect caches. Caller target, camera, transforms, viewport, colour,
alpha and blend state are restored. Bounds callbacks still obey the usual
read-only rules; an exception aborts the render with `Completed=False` and restores
state. The overlay may resolve dirty bounds/world caches. Its work is excluded
from scene render counters, but its lines appear in backend drawing statistics;
disable it for performance comparisons. Traversal storage is retained, with one
additional drawing scope per overlay pass, not one per node.

The [composition example](../../examples/scene_composite.bmx) offers **D** to
toggle the overlay and **I** to print the tree to standard output. For convenient
text output, build it as a console application; the GUI build retains the overlay.
