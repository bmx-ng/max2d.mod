# Scene bounds and draw ordering

The default scene draws each parent, then its children in insertion order. It
only calculates subtree bounds when asked. Neither feature requires a custom
application loop or an ECS integration.

## Measuring a group

Create a rectangle once and reuse it:

```blitzmax
Local bounds:TSceneRect = New TSceneRect
If group.GetContentBounds(bounds) Then
    ' bounds.x/y/width/height describe the group in its own local coordinates.
End If
```

| Query | Result |
| --- | --- |
| `GetSelfBounds(bounds)` | Only the node's own drawable geometry. |
| `GetContentBounds(bounds)` | Union of its visible drawing and visible descendants. |
| `GetOutputBounds(bounds)` | Includes composite effect expansion; ordinary nodes match content bounds. |

True with zero width/height means empty. False means unknown and leaves the
supplied rectangle unchanged. Unknown bounds in any contributing descendant
make the aggregate unknown. Bounds are axis-aligned enclosures, so nesting
rotated groups can leave extra space around the actual geometry.

Content bounds exclude hidden, zero-alpha and pending-destroy subtrees. A query
on a hidden node returns empty content bounds, while `GetSelfBounds` still
describes its own geometry. Ancestor visibility does not affect a descendant's
local query. Cameras and viewports do not affect local bounds either.

A node's own transform is excluded from its local content bounds. Child
transforms are included, including pivots, rotation, negative scales and shear.
The calculation needs no inverse matrix, so singular transforms are supported.
Non-spatial grouping nodes preserve the coordinate chain.

## Caching and invalidation

Content bounds are cached. Moving a child invalidates its ancestors' aggregate
bounds and reuses the child's local measurement. Changes to visibility,
zero-alpha participation, geometry or child membership invalidate the relevant
caches automatically. Sorting changes do not change the geometry enclosure.

Custom drawing should supply local bounds through `SetSelfBounds`, or override
`GetSelfBounds` to fill the supplied rectangle. Include the full drawn extent,
including stroke width. Unknown bounds remain a valid choice for drawing whose
extent cannot be described reliably.

Call `node.InvalidateContent()` when data changes outside node setters:

- A custom node changes the geometry used by its bounds callback.
- A shared image's handle changes.
- Shared mesh vertices or font metrics change.

Notify every affected node when a resource has several users. Changes to pixels
that preserve geometry do not change these bounds; ordinary rendering continues
to use Max2D's resource update handling. Cached composites also use
content invalidation for their captured pixels.

Bounds callbacks must be read-only. Mutating the scene during an aggregate query
is rejected, including for detached trees. Recursive queries that depend on their
own unfinished result are rejected. A failing callback leaves its cache dirty,
so a corrected callback can be retried. Queries and nodes are intended for one
application thread.

Each measured spatial node retains a scratch rectangle and numeric bounds.
First measurement may allocate; subsequent invalidation and recomputation reuse
that storage. Text measurement can also populate the font's normal caches.

## Stable sibling sorting

```blitzmax
group.SetSortableChildren(True)
backdrop.SetZIndex(-10)
player.SetZIndex(0)
foreground.SetZIndex(10)
```

Enable sorting on any parent: spatial groups, layers and non-spatial grouping
nodes all support it. Lower z-indices draw first. Equal indices preserve the
committed child insertion order. Non-spatial children have index zero, with their
entire subtree kept together. A descendant's index cannot escape its parent's
position, layer or camera boundary.

Sorting is a separate view of the children. `ChildAt`, `Children`, updates and
lifecycle callbacks keep their original order. Removing and re-adding a child
appends it unless an insertion index is supplied. Disabling sorting immediately
returns to insertion-order drawing.

The sorted view is rebuilt after relevant insertion, removal or z-index changes.
Stable merge sorting uses retained integer arrays; warm rebuilds allocate no
additional objects. `ReserveChildren` prepares this storage when sorting is
enabled. `scene.TrimStorage()` can shrink it during idle maintenance.

## Try the example

[scene_bounds_order.bmx](../../examples/scene_bounds_order.bmx) shows three
overlapping cards surrounded by their aggregate bounds. Z reverses their indices,
S toggles sorting, R rotates the cyan card and H hides the violet card. The
bounding rectangle updates without rebuilding the scene.

Bounds also support [subtree culling](culling.md) and [picking](picking.md).
Unknown bounds are treated conservatively. See [pointer routing](pointer.md)
for scene input and coordinate conversion during interaction.

## Regression checks

From the SDK root:

```sh
python3 mod/max2d.mod/tests/run_regressions.py core --test scene_bounds
python3 mod/max2d.mod/tests/run_regressions.py sdl gl sdlgpu --test scene_render
```

The bounds test needs no graphics context. It covers affine transformations,
unknown/empty bounds, caching, visibility, structural changes, invalidation,
callback failures and warm allocations. The graphics test checks overlap pixels,
stable ties, non-spatial groups, insertion/removal, unchanged update order and
allocation behaviour while repeatedly sorting 1,000 drawables.
