# Tiled templates and structured properties

## Native structured values

`Max2D.TileMap` supports nested class-valued properties independently of Tiled:

```blitzmax
Local stats:TTileProperties = New TTileProperties
stats.SetLong("health", 100)
stats.SetDouble("speed", 2.5)

Local properties:TTileProperties = New TTileProperties
properties.SetClass("stats", "EnemyStats", stats)

Local value:TTileProperty = properties.Get("stats")
Print value.ClassName() ' EnemyStats
Print value.AsClass().GetLong("health")
```

- `ETilePropertyType.ClassValue` identifies a structured value.
- `ClassName()` may be empty when the source format omits the nested schema name.
- `SetClass(name,className,members)` stores a deep snapshot of its input.
- `GetClass(name)` and `AsClass()` return the stored member collection without
  copying. Members can be edited. A missing name returns Null; a mismatched type
  throws, as with scalar getters.
- `Copy()` deep-copies nested members while sharing immutable scalar values.
- `Overlay(overrides)` copies overrides into a collection. Matching class names
  merge recursively; different classes and scalar values replace the old value.
- `InheritClasses(defaults)` materializes independent class defaults. Tiled uses
  this for tile objects, so overriding `stats.health` retains an unspecified
  `stats.speed`, and editing one object's members cannot change another object
  or its shared tile definition.

Structured properties are allocated while loading or explicitly creating/editing
metadata. Drawing and point/region queries do not traverse or copy them.

## Reuse objects with templates

Templates let you define an object once in Tiled and place instances in maps.
`Max2D.Tiled` reads XML and JSON templates, including references across formats. The loader combines template defaults with instance attributes, shape
geometry and custom properties. An instance's explicit values win, including
empty strings, zero and False. Nested class overrides retain unspecified members
when their class names match.

Object identity and placement belong to the map instance: template `id`, `x`
and `y` do not leak into placements. Shape overrides replace the inherited shape;
this includes text content and its formatting attributes. Object reference properties remain integer map
IDs, resolved through `ObjectByID` after loading. No object ID remapping is done
inside property values.

Tile templates reference external TSX or TSJ files. Their local GIDs are remapped to the
map's corresponding tileset while retaining flip/rotation flags. A tileset used
only by templates is loaded automatically and receives its own map GID range.
Existing external tilesets are reused. Native tile IDs still differ from Tiled
GIDs, as described in [Tiled loading](tiled.md).

Template files are parsed and expanded once per map import, then freed. Each
instance has independent native property storage. Chained templates are supported;
cycles and excessive nesting produce a source-path error. This is load-time
expansion, not a live link to files being edited in Tiled.

## Paths, streams and archives

All resources are read through the standard stream APIs. Maps may come from paths, `TStream`,
`incbin::` or `BRL.IO` mounts. Include `BRL.RamStream` when using embedded resources.
Caller-owned map streams remain open; internally opened template/TSX streams close
on success and failure.

Relative template references and file-valued properties resolve beside the file
that defines them. For example, a `sound="guard.wav"` default in `templates/guard.tx`
resolves beside that template; an override in the TMX resolves beside the map.
Nested class members follow the same rule. External resources for stream-loaded
maps still require a logical source path. File-valued properties are resolved,
not opened.

## Class schema boundary

The importer reads serialized class values without a schema. To fill omitted
project defaults, recover nested JSON member types and inspect enums, explicitly
load a [Tiled project](tiled_projects.md). Defaults are applied after template
expansion, preserving instance and template precedence. Schema loading is optional.

Limits: 32 levels of template inheritance, 4,096 cached templates, 1,048,576 XML
nodes copied during expansion, 64 levels of structured properties, and 1,048,576
property entries processed per map import. The object/tile limits also apply.

## Examples

- Viewer **9** loads the unmodified upstream Sticker Knight map. Its hero, blocks
  and gems use external templates. All original assets and attribution accompany
  the example.
- `tiled.mod/examples/template_properties.bmx` is a console example with a small
  original metadata fixture. It demonstrates a guard and gatekeeper sharing a
  template, an overridden health value, an inherited speed, an object reference
  to a door, and independent instance edits. No graphics context is needed.

The console example accepts an optional map path when its executable is placed
outside the example directory.

References: [Tiled templates](https://doc.mapeditor.org/en/stable/manual/using-templates/)
and [TMX properties](https://doc.mapeditor.org/en/stable/reference/tmx-map-format/#properties).
