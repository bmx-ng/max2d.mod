# Rebuilding the embedded shaders

Keep `draw.metal`, `draw.vert`/`draw.frag` and `draw.hlsl` equivalent. Their uniforms
are a vertex transform and fragment flags for coverage, source premultiplication,
alpha testing and destination premultiplication. Bindings follow
[SDL_CreateGPUShader](https://wiki.libsdl.org/SDL3/SDL_CreateGPUShader).

Compile Vulkan assets with glslang:

```sh
glslangValidator -V draw.vert -o draw.vert.spv
glslangValidator -V draw.frag -o draw.frag.spv
python3 embed.py
```

`embed.py` embeds those SPIR-V files and the Metal source into `../shaders.h`.
Metal source is compiled by the OS when the GPU device is created.

On Windows, build `compile.cpp` with the SDK's MinGW compiler and `-ld3dcompiler`,
then run the resulting tool with `draw.hlsl` and `../shaders_dxbc.h` as arguments.
It compiles shader model 5.1 DXBC with SDL's register-space conventions. Commit
sources, SPIR-V assets and both generated headers together. No build tool or
runtime shader-cross library is required by applications.
