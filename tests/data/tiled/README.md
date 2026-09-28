These tiny maps and the generated colour-test PNG are original Max2D regression fixtures, under the repository zlib/libpng licence. No upstream artwork is included.

The `json-*` fixtures mirror the original XML cases in current Tiled JSON form.
They exercise numeric/base64/compressed data, external TSJ, image collections,
groups, geometry, templates (including mixed formats), unnamed nested class
values, exact integers, stream ownership and malformed GIDs/duplicate keys.
`json.zip` contains the JSON CSV-equivalent map, TSJ and sheet image.

The `order-*` XML/JSON pairs check all four orthogonal traversal settings through
nested groups. Native pixel tests cover overlapping artwork across positive and
negative chunk boundaries and GroundDepth precedence.

`project/` contains original project-schema fixtures and their ZIP bundle. These
exercise class defaults on every owner, nested class/enum metadata, file origins,
object references, template/tile/instance precedence, mutable independence,
optional loading, stream ownership and malformed schema rejection.
