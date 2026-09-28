# LDtk example viewer

Build from the BlitzMax installation directory:

```sh
bin/bmk makeapp -r -t gui mod/max2d.mod/ldtk.mod/examples/ldtk_viewer.bmx
```

Leave the executable beside `maps`. It opens LDtk's basic auto-layer example.
The default backend is SDL3; `-ud max2d_gl`, `-ud max2d_d3d9` or
`-ud max2d_d3d11` selects another backend.

- A/D/W/S: pan.
- Mouse wheel or Q/E: zoom.
- Space: fit the level.
- Left/right arrows: select another level in the project.
- O: toggle entity rectangle outlines.
- Escape: exit.

Hover to inspect a layer's cell coordinate and IntGrid value. The viewer displays
tile layers, auto-layer results, entity artwork, backgrounds and parallax. Optional
outlines show the entity gameplay rectangles, which can differ from their artwork.
It does not run game movement or collision rules.
See the [LDtk guide](../../docs/ldtk.md) for supported features and data access.

Pass a project filename and optional `--level=IdentifierOrIID` to open your own
project. Without `--level`, the viewer selects its first level. This is a viewer
choice; the library requires a selector for multi-level projects.

Use `--no-entity-art` for projects whose entities are just editor markers. If a
project uses the built-in `LdtkIcons` atlas, pass `--icons=/path/to/icons.png` with
its corresponding pixels, or use `--no-entity-art`. The viewer does not bundle
LDtk's built-in icon sheet. External entity tilesheets load automatically.

For command-line arguments on macOS, build with `-t console`; the GUI app stub does
not forward them. `--test` exits after three frames, and
`--screenshot=/absolute/path.png` saves a capture. A relocated executable needs an
explicit project path.

## Navigation and field inspection

`ldtk_navigation.bmx` is a console example. It lists level metadata and neighbours,
then inspects fields and entity references in the levels you explicitly select:

```sh
bin/bmk makeapp -r -t console mod/max2d.mod/ldtk.mod/examples/ldtk_navigation.bmx
mod/max2d.mod/ldtk.mod/examples/ldtk_navigation /absolute/path/to/game.ldtk Entrance Dungeon
```

Use the generated `.exe` filename on Windows. Absolute project paths avoid
BlitzMax's executable-relative working directory. Select levels by IID when names are
ambiguous. With no level arguments it loads the first level. References into other
levels remain unresolved unless you include those levels as arguments. Entity
artwork is disabled for this inspection example; tile layers/backgrounds still
load normally. No arguments uses the bundled auto-layer map, which has no entity
links; use a project containing references to exercise that part of the example.

## Source and attribution

The map and tilesheet are unchanged files from
[LDtk's samples](https://github.com/deepnight/ldtk/tree/6d69bd1d6be92f01ac30778f6a934f0da8448b16/app/extraFiles/samples),
revision `6d69bd1d6be92f01ac30778f6a934f0da8448b16`:

- `maps/AutoLayers_1_basic.ldtk`
- `maps/atlas/Cavernas_by_Adam_Saltsman.png`

LDtk's repository MIT licence is included as `maps/LICENSE.upstream`, and its
sample attribution notes as `maps/README.upstream.md`. The notes also mention
packs used by other upstream samples which are not included here.

The Cavernas artwork is by Adam Saltsman, who identifies it as public domain on
[the asset's original page](https://adamatomic.itch.io/cavernas). The map retains
its original relative tilesheet path. Our BlitzMax viewer code uses the Max2D
repository licence; upstream assets retain their own terms.
