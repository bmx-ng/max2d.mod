# Building a hex board without a map editor

`Max2D.TileMap` can be used on its own. Create the board in code, generate it
procedurally, or edit it during play. Tiled and other map editors are optional.

The [hex board example](../examples/hex_board.bmx) is a complete starting point.
It generates two hex images, fills a board with grass and water, lets you select
cells, and displays distance and a three-cell range. It needs no asset files.

From your BlitzMax installation directory, build it with:

```sh
bin/bmk makeapp -r -t gui mod/max2d.mod/examples/hex_board.bmx
```

On Windows use `bin\bmk.exe`. The example uses SDL3; change its `Framework` line
to another Max2D backend if desired. Click a cell to select it. Yellow outlines
show geometric range, white marks the selected cell, and blue marks the hovered
cell. The range deliberately includes water: it demonstrates geometry, not a
movement rule.

## What the module provides for a wargame

| Need | Native support |
| --- | --- |
| Hex layout | Pointy/flat tops, odd/even staggering and configurable proportions |
| Coordinates | Column/row storage, axial/cube conversion, cell corners and centres |
| Selection | Mouse-to-cell picking through virtual resolution, cameras and layer offsets |
| Neighbouring cells | Six neighbours, grid distance, ranges and rings |
| Terrain | Shared tile properties plus per-cell overrides |
| Drawing | Layers, animated/atlas artwork, movable sprites, text objects and sorting |
| Queries | Occupied cell regions, map objects and tile collision shapes |

These are enough to build the board and its interactions. Your game supplies
movement/pathfinding, unit occupancy, combat, turns, line of sight and fog of war.
There is no built-in rules engine or native map save format. You can serialize
your board and game state using your chosen BlitzMax stream/format modules.

## Create and populate the board

A grid describes geometry; a tileset describes shared artwork and properties;
a map holds layers of cells. Given loaded `grassImage` and `waterImage` images:

```blitzmax
Local grid:TTileGrid = TTileGrid.Hexagonal(48, 56, ETileLayout.PointyHex, ETileStagger.Odd)
Local tiles:TTileSet = New TTileSet
Local grass:Int = tiles.Add(grassImage)
Local water:Int = tiles.Add(waterImage)
Local map:TTileMap = TTileMap.Create(grid, tiles)
Local ground:TTileLayer = map.AddLayer("Terrain")

ground.SetCell(0, 0, grass)
ground.SetCell(1, 0, water)
```

The complete example generates these images from `grid.Contains` instead of
loading them. To make your own artwork, use images whose canvas matches the grid
cell's bounding box, with transparent corners. Grid geometry does not automatically
clip rectangular artwork into a hexagon.

Cells are addressed by offset columns and rows. Use `ToAxial` or `ToCube` when
an algorithm needs those coordinate systems, then convert back to access the
layer. The grid is unbounded within its coordinate limits: your populated cells
or a separate board mask define the playable area. `ground.Cell(c,r)=0` means no
terrain is stored there.

## Store terrain rules

```blitzmax
tiles.Properties(grass).SetLong("moveCost", 1)
tiles.Properties(water).SetBool("blocked", True)

' A bridge can override its water tile's default.
ground.CellProperties(1, 0, True).SetBool("blocked", False)
ground.CellProperties(1, 0, True).SetLong("moveCost", 1)
```

Read with `ground.Property(c,r,"blocked")` or `ground.Property(c,r,"moveCost")`
to include overrides. Missing properties return Null; decide your game's defaults
before calling `AsBool()` or `AsLong()`. Names such as `blocked` and `moveCost`
have no built-in meaning to Max2D.

Keep unit state separately from terrain. A unit can hold its column/row and a
`TTileSprite` for rendering; use `grid.CellCenter` to position it. An occupancy
table can tell your movement rules which cells contain units. An ECS is optional.

## Geometric range versus movement range

`grid.Range(column,row,3)` returns all cells within three hex steps, including
empty cells and obstacles. Pass `True` as its fourth argument for just the outer
ring. Cache the returned array until the selection or radius changes.

For reachable movement with terrain costs, use a cost-aware search such as
Dijkstra's algorithm:

1. Start with the unit's cell at cost zero.
2. Visit the cheapest pending cell and ask `grid.Neighbour` for its six neighbours.
3. Reject cells outside the board, blocked terrain and disallowed occupants.
4. Add the entry cost; keep the cell if it improves its best cost and fits the
   unit's movement budget.
5. Retain predecessor cells if you need to reconstruct a path.

`grid.Distance` ignores obstacles and terrain. It is useful for geometric attack
ranges or an A* heuristic. For a movement-cost heuristic, scale it by a valid
minimum step cost; special movement rules may require a different heuristic.
Range and distance do not test line of sight.

## Cameras, overlays and picking

Pass the same map x/y and layer to `map.MouseCell` that you use for drawing.
When using a camera, keep it active for both picking and scene drawing. This
keeps selection aligned when panning, zooming or changing virtual resolution.

Use `grid.CellCorner` for selection outlines and `CellCenter` for markers.
They return grid-local pixels, so apply the same map position, layer offset and
camera as the terrain. The example keeps the camera at its default and uses one
map offset to make this relationship easy to follow.

For larger maps and more interaction, see the [native tilemap guide](tilemaps.md)
and [full tilemap example](../examples/tilemap.bmx), which demonstrate camera
controls, painting, multiple layouts and ground-depth sprite sorting.
