SuperStrict
Rem
bbdoc: Renderer-independent shader package descriptions, parameters and factories.
End Rem
Module Max2D.ShaderEffects
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Effects
Import "package.c"
Import "../sdl3gpueffects.mod/packages/texturemask/texturemask_assets.c"
Import "../sdl3gpueffects.mod/packages/thresholdmask/thresholdmask_assets.c"
Import "../sdl3gpueffects.mod/packages/dissolve/dissolve_assets.c"
Import "../sdl3gpueffects.mod/packages/displacement/displacement_assets.c"
Import "../sdl3gpueffects.mod/packages/colormatrix/colormatrix_assets.c"
Import "../sdl3gpueffects.mod/packages/distortion/distortion_assets.c"
Import "../sdl3gpueffects.mod/packages/graded_distortion/graded_distortion_assets.c"

Include "../sdl3gpueffects.mod/packages/colormatrix/colormatrix.bmx"
Include "../sdl3gpueffects.mod/packages/distortion/distortion.bmx"
Include "../sdl3gpueffects.mod/packages/graded_distortion/graded_distortion.bmx"
Include "../sdl3gpueffects.mod/packages/displacement/displacement.bmx"
Include "../sdl3gpueffects.mod/packages/dissolve/dissolve.bmx"
Include "../sdl3gpueffects.mod/packages/texturemask/texturemask.bmx"
Include "../sdl3gpueffects.mod/packages/thresholdmask/thresholdmask.bmx"

Include "package.bmx"
