# Upstream Tiled examples

Build `tiled_examples.bmx` and leave the executable beside the `maps` folder.
The default backend is SDL3; `-ud max2d_gl`, `-ud max2d_d3d9` or
`-ud max2d_d3d11` selects another backend.

From the BlitzMax installation directory:

```sh
bin/bmk makeapp -r -t gui mod/max2d.mod/tiled.mod/examples/tiled_examples.bmx
```

| Key | Original map | Features illustrated |
| --- | --- | --- |
| 1 | Desert | Orthogonal grid, external TSX, tilesheet margin and spacing |
| 2 | Sewers | Layered orthogonal map |
| 3 | Perspective Walls | Three layers, oversized tiles, tile offsets and properties |
| 4 | Isometric Grass and Water | Isometric grid and tile offsets |
| 5 | Staggered Grass and Water | Staggered grid and infinite-map chunks |
| 6 | Hexagonal Mini | Hexagonal grid and oversized artwork |
| 7 | Orthogonal Outside | Object layers, paths, triggers, spawn point and tile objects |
| 8 | Forest | Parallax backgrounds, image subrectangles and animated tile objects |
| 9 | Sticker Knight | External object templates, image collections and parallax |
| 0 | Sticker Knight title | JSON map, embedded image collection and tile objects |

Use arrow keys to pan, the mouse wheel or Q/E to zoom, Space to fit, and Escape
to exit. O toggles object outlines. Hover to highlight a cell or object and see
its layer, coordinates/ID, name, class or flip flags.
Fitting uses cell bounds; artwork protruding beyond outer cells may be cropped.

A TMX/TMJ/JSON path can also be supplied on the command line. `--test` exits after three
frames; `--screenshot=/absolute/path.png` captures the third frame. On macOS,
build with `-t console` for command-line arguments (the current GUI app stub
does not forward them). If putting the executable elsewhere, supply a map path;
the number keys still look beside the executable for `maps`.

## Source and licences

The map, tileset, template and image files in `maps` are unchanged copies from
[Tiled's examples](https://github.com/mapeditor/tiled/tree/221be2066c4b0ed4bbefbcdfe25d0ad952fc51bd/examples),
revision `221be2066c4b0ed4bbefbcdfe25d0ad952fc51bd`. Relative resource paths are preserved.
The upstream `AUTHORS`, `COPYING` and `LICENSE.GPL` are included in `maps`.

Upstream `AUTHORS` credits the included artwork as follows:

| Artwork | Credit | Upstream licence designation |
| --- | --- | --- |
| `tmw_desert_spacing.png` | The Mana World Development Team | GPL |
| `sewer_tileset.png` | Blues Brothers RPG developers | GPL |
| `perspective_walls.png` | Clint Bellanger | Public Domain |
| `isometric_grass_and_water.png` | Clint Bellanger | GPL2, GPL3, CC-BY-SA3 |
| `buch-outdoor.png` | [Michele "Buch" Bucelli](https://opengameart.org/users/buch) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `hexmini.png` | [Pixel Hex Tilesets Enhanced](https://opengameart.org/content/pixel-hex-tilesets-enhanced) | Public Domain |

The included GPL text is version 2, as shipped by upstream; the isometric
artwork is distributed here under its GPL2 option. Upstream does not add separate
per-file licence headers to these example maps. These third-party assets retain
their upstream terms; the Max2D repository licence does not relicense them.
Our BlitzMax viewer code uses the Max2D repository licence.

The synthetic maps in `max2d.mod/examples/tiled` remain available for targeted
flip, rotation and animation checks. This selection keeps the upstream maps
unmodified and uses features the importer currently supports. Other upstream
examples may use unsupported features such as non-normal layer blend modes.

Orthogonal Outside and its Buch artwork are also unchanged copies from the same
revision. Its object layer is available with key 7. The CC BY 3.0 artwork retains
its attribution above; no modifications have been made.

Forest's four files are unchanged copies from the same pinned revision. Its
`squirrel.license` credits Luis Zuno (@ansimuz), identifies the artwork as public
domain, and links to [Sunnyland Woods](https://opengameart.org/content/sunnyland-woods).
Use key 8 and pan to see the background layers move at different speeds. Outlines
and hover inspection follow the displayed layers.

Sticker Knight is an unchanged copy of the same upstream revision, including its
original README crediting @ponywolf and identifying it as public domain. The
upstream AUTHORS also lists it as CC0 and links to
[Sticker Knight Platformer](https://opengameart.org/content/sticker-knight-platformer).
Key 9 opens `sandbox.tmx`; `sandbox2.tmx` is also included as supplied upstream.

`template_properties.bmx` is a separate console example for defaults, overrides,
nested properties and object references. Its small original fixtures under
`data/templates` use the Max2D repository licence. Build with `-t console` and
leave the executable next to `data`, or supply the TMX path as an argument.
See [templates and structured properties](../../docs/tiled_templates.md).

## Project schemas

The viewer explicitly loads the unchanged upstream `maps/examples.tiled-project`.
This supplies class defaults for typed objects, including the Fixture collision
area in map 7. Override it with `--project=/path/game.tiled-project`, or use
`--project=` to disable it. Relocated console executables need this argument as
well as the map path.

`project_properties.bmx` is a console example using that project and map 7. It
prints nested Fixture defaults, BodyType enum labels and a resolved script path,
and demonstrates that editing a defaults snapshot leaves the project unchanged.
Pass project and map filenames as its first two arguments when building elsewhere.

## Text fonts

The shared viewer maps text font requests to Arial on macOS, Segoe UI on Windows
and DejaVu Sans on Linux, including bold/italic and kerning settings. If absent,
it uses the built-in bitmap fallback. It does not reproduce arbitrary editor font
families. Games should provide a `TTiledFontResolver` backed by bundled font files;
see [tile sizing and text](../../docs/tile_sizing_text.md).
