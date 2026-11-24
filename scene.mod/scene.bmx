SuperStrict

Rem
bbdoc: Optional retained scene trees and affine transforms for Max2D.
about: Provides tree ownership, lifecycle, update traversal and spatial queries without requiring Graphics. Rendering supports sprites, text, meshes, custom drawing and layer views, with cached subtree bounds and optional stable sibling sorting, virtual coordinate conversion and pointer picking. Pointer routing/capture, hover and keyboard focus/routing are supported. Optional conservative culling, render/memory counters, tree inspection and a bounds/hit-region overlay are available. Optional isolated composite nodes, automatic pixel caching and effect chains are available in Max2D.SceneEffects. See docs/scene for usage guides, worked examples, ownership rules and current feature limits.
End Rem
Module Max2D.Scene
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Core

Include "transform.bmx"
Include "node.bmx"
Include "tree.bmx"

Include "render.bmx"
Include "rendergroup.bmx"

Include "bounds.bmx"

Include "picking.bmx"

Include "pointer.bmx"

Include "interaction.bmx"

Include "diagnostics.bmx"

Include "inspection.bmx"
