# Built-in D3D9 effects

Applications use `../effect_shaders.cpp`; they do not load D3DCompiler.
The seven entry points in `effects.hlsl` implement saturation, colourize, blur,
outline, bright-pass extraction, tone mapping and linear output.

Rebuild on Windows from this directory with BlitzMax:

```
bmk makeapp -r -o compile_effects.exe compile.bmx
compile_effects.exe effects.hlsl ../effect_shaders.cpp
```

The tool uses `d3dcompiler_47.dll` at build time and emits `ps_3_0` bytecode.
Commit the HLSL and regenerated arrays together. Each native graphics context
creates and owns its effect shaders lazily. The provider does not compile shaders
at application runtime.
