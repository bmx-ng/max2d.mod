# Using Tiled project properties

`Max2D.Tiled` can load class and enum definitions from a `.tiled-project`. Loading
is explicit: there is no project discovery or global active schema.

```blitzmax
Local project:TTiledProject = TTiledProject.Load("maps/game.tiled-project")
Local map:TTiledMap = project.LoadMap("maps/level.tmj")

' Equivalent when using LoadTiledMap directly:
Local second:TTiledMap = LoadTiledMap("maps/level.tmx", FILTEREDIMAGE, "", project)
```

A project can be reused for multiple sequential imports. The generic
`LoadTileMap` provider continues to load without a project. Loading a schema does
not change any other map or loader. XML and JSON maps, tilesets and templates can
be mixed in the same resource graph.

## Defaults and overrides

Class members are supplied for maps, tilesets, tiles, groups, layers and objects,
including tile collision objects. Nested class values also receive defaults.
A tile object's class can come from its tile when the object has no class label.

Precedence is, from lowest to highest:

1. The object's effective class defaults from the project.
2. Explicit properties on its tile, when it is a tile object.
3. Explicit properties inherited from its object template.
4. Explicit instance properties.

A class member's configured default overrides defaults from its referenced class.
Matching nested class names merge recursively; replacing a class with another type
replaces the value. Zero, `False` and empty strings are explicit overrides.
Defaults are applied after template expansion and tile-property inheritance, so
a schema default cannot accidentally overwrite a serialized template/tile value.

Schema defaults and resolved object values are materialized during import. Each
instance owns its mutable nested values. Editing an object, tile or a returned
default snapshot does not change another instance or the project's cached defaults.
There is no live link back to the project file. Rendering and picking never consult
the schema.

```blitzmax
Local defaults:TTileProperties = project.ClassDefaults("Body")
Local fixture:TTileProperties = defaults.GetClass("fixture")
fixture.SetDouble("friction", 0.25)
' A later ClassDefaults("Body") returns a fresh independent snapshot.
```

Unknown class labels in maps remain valid metadata and acquire no inferred defaults.
A missing class referenced by the project itself is an error, as are cyclic class
references and duplicate type/member definitions. Class `useAs` and colour are
retained for inspection; they are editor metadata, not runtime placement restrictions.

## Restoring JSON member types

Tiled JSON class values omit member declarations. When a project is supplied,
member types are recovered before template merging and path normalization:

- Nested objects retain their class names.
- Numbers declared as `float` become native Number properties even when JSON saves
  them as an integer, such as `4`.
- File members are resolved paths.
- Object members retain integer IDs and their object-reference type.
- Enum members retain the enum schema name and stored value.

Without a project, member types are inferred
from JSON values, nested schema names are unavailable and nested file strings
remain plain text.

## Enums and property metadata

Enums are stored as ordinary native string/integer properties. Their values are
not renumbered or coerced. Numeric enums use zero-based indexes; numeric flags use
a bitmask. String flags remain comma-separated labels. The project retains the
declared order, labels, storage type and flag setting:

```blitzmax
Local body:TTileProperties = project.ClassDefaults("Body")
Local property:TTileProperty = body.Get("type")
Local definition:TTiledEnum = project.EnumType(property.CustomType())
If definition Then
	Print definition.storageType
	For Local label:String = EachIn definition.values
		Print label
	Next
End If
```

`TTileProperty.ValueType()` reports the serialized type (`file`, `object`, `int`,
`string`, `class`, etc.). `CustomType()` reports an enum or class schema name when
present. These annotations are retained for explicitly typed properties even when
no project is loaded. Manually constructed native properties may have empty
annotations. Use `Kind()` and the scalar/class getters to read the stored value.

`project.ClassType(name)` returns `TTiledClass` with its name, ID, colour, `useAs`
and member declarations. `project.Member(className,name)` looks up one declaration;
`project.EnumType(name)` returns `TTiledEnum`. Unknown names return Null.
`ClassDefaults(name)` returns an empty collection for an unknown class.
Treat returned schema declarations as read-only. Edit application values instead.
Enum schemas are descriptive: explicit unknown values are preserved rather than
silently clamped, allowing applications to handle schema migrations.

## Streams, paths and ZIP archives

Project and map APIs accept paths, stream URLs and caller-owned `TStream`s.
Neither API seeks or rewinds the stream. Supply the logical filename when loading
from a stream so relative references have the correct base:

```blitzmax
Using
	Local stream:TStream = ReadStream("assets/game.tiled-project")
Do
	Local project:TTiledProject = TTiledProject.Load(stream, "assets/game.tiled-project")
	Local map:TTiledMap = project.LoadMap("assets/level.tmj")
End Using
```

Caller streams stay open on success and failure. Internally opened streams close.
`BRL.IO` mounts and `incbin::` work for the entire resource graph. Project defaults
resolve file paths beside the project; template and map overrides resolve beside
the file that supplied the value. File properties are normalized but never opened.
Project folders, scripts, extensions and editor commands are not loaded or run.

## Limits and examples

A project accepts up to 4,096 types, 65,536 member declarations, 65,536 enum values
per enum (31 for flags), and 64 levels of property resolution. An expansion budget
of 1,048,576 processed properties bounds defaults and each map import. Unsupported
member types, including typed list/array properties, produce an error.

The upstream example viewer explicitly loads its bundled `examples.tiled-project`.
`--project=/path/game.tiled-project` chooses another project; `--project=` disables
schema loading. When moving the console viewer outside its examples directory,
pass both a map path and either `--project=...` or `--project=`.

`tiled.mod/examples/project_properties.bmx` is a console example using the unchanged
upstream project and Orthogonal Outside map. It demonstrates nested physics defaults,
enum labels, a resolved script path and independent default snapshots. Optional
arguments are the project path followed by the map path.

References: [Tiled custom properties](https://doc.mapeditor.org/en/stable/manual/custom-properties/)
and [upstream inheritance implementation](https://github.com/mapeditor/tiled/blob/221be2066c4b0ed4bbefbcdfe25d0ad952fc51bd/src/libtiled/object.cpp).
