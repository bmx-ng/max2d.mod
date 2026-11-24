SuperStrict

Rem
bbdoc: Optional isolated scene composition, automatic pixel caches and retained effect stages.
about: Composite nodes capture subtrees with tracked invalidation, flattened opacity, explicit resolution and bounded retained storage. Import an effects provider matching your graphics backend for shader stages.
End Rem
Module Max2D.SceneEffects
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Scene
Import Max2D.Effects
Import Max2D.Lighting

Include "stage.bmx"
Include "chain.bmx"
Include "alphamask.bmx"
Include "subtreemask.bmx"
Include "bloom.bmx"
Include "shadow.bmx"
Include "lighting.bmx"

Include "composite.bmx"
