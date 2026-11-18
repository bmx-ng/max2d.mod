# Custom colour shader packages

Import `Max2D.SDL3GPUEffects` to use version-one packages on SDL GPU.
The first contract is a single sampled source colour plus typed parameters.
It supports colour grading and other per-pixel colour functions. Additional
textures, neighbourhood sampling and arbitrary resource layouts are outside
this version. Software SDL and OpenGL report these packages unsupported.

## Colour matrix

```blitzmax
Local grade:TMax2DShaderEffect = CreateColorMatrixEffect()
grade.SetFloat4("row0",1.2,0,0,0)
grade.SetFloat4("row1",0,1.2,0,0)
grade.SetFloat4("row2",0,0,1.2,0)
grade.SetFloat4("bias",-0.1,-0.1,-0.1,0)
If Max2DSupportsImageEffect(grade) Then DrawImageEffect(image,grade,x,y)
```

The factory starts with an identity RGBA matrix. `row0` through `row3` are
four-component rows; `bias` is added to their dot products with the input.
The example changes contrast around 0.5 and preserves alpha. The interactive
[example](../examples/color_matrix.bmx) adds brightness and sepia.

The wrapper samples the image, interprets coverage, converts premultiplied
input to straight colour, and applies drawing tint before calling the colour
function. It clamps output alpha to 0–1, applies mask discard and the blend
mode's output premultiplication. RGB remains unclamped for HDR intermediates.
There is no implicit colour-space conversion. Use linear inputs for linear
colour processing; an RGBA8 destination still limits the stored range.

## Package API

`TMax2DShaderPackage.Create(name,names,types,metal,spirv,dxbc,abiVersion=1)`
copies the schema and shader bytes. Names must be unique identifiers. Declare
one to eight `MAX2D_PARAMETER_FLOAT` or `MAX2D_PARAMETER_FLOAT4` parameters.
Each occupies one 16-byte slot, including scalars; total uniforms are at most
128 bytes. At least one platform asset is required, each at most 4 MiB.

`CreateShaderEffect(package)` creates reusable, initially zero parameters.
Use `SetFloat(name,value)` and `SetFloat4(name,x,y,z,w)`. Unknown names, type
mismatches and non-finite values throw. A vector update validates every
component before changing the value. Queued draws keep submitted snapshots.
Multiple instances can share a package. Package display names do not determine
cache identity; each package receives a unique identity. Native shaders and
pipelines belong to the graphics context and are released when it closes.
Packages can be reused in a later context.

A support query compiles the backend shader and checks the current target,
blend mode and vertex layout. An unavailable backend or incompatible package
returns false; attempted drawing throws. A support result for one target does
not guarantee every other target format. If explicitly testing software after
importing the GPU provider, select `SDLRenderMax2DDriver()` before `Graphics`.

## Building a package

The tools live in `sdl3gpueffects.mod/packages`. Start from the checked-in
`colormatrix/manifest.json` or `tests/data/shaderpackage/manifest.json`.
A manifest has `abi`, `name`, `factory`, `parameters` and `bodies` fields.
Each parameter has `name` and `type` (`float` or `float4`). Supply equivalent
trusted function bodies for `metal`, `glsl` and `hlsl`; each returns a
four-component colour. `c` is tinted straight RGBA, and named parameters are
available as local values. This is not an automatic shader-language translator.

All three tools are BlitzMax console applications. The generator and embedder
use `Text.JSON` plus BRL modules. Build them once from the packages directory:

```sh
bmk makeapp -r -t console -o generate generate.bmx
bmk makeapp -r -t console -o embed embed.bmx
```

For the reference package (use `generate.exe`/`embed.exe` on Windows):

```sh
./generate colormatrix/manifest.json colormatrix
glslc -O colormatrix/colormatrix.frag -o colormatrix/colormatrix.frag.spv
```

On Windows, build and run the BlitzMax DXBC compiler tool. It calls
`D3DCompile` in `d3dcompiler_47.dll` directly through a BlitzMax binding; no C++
helper is required. It prints compiler diagnostics and exits nonzero on failure.
The target remains `m2dEffectMain`, pixel shader 5.1, optimization level 3.

```text
bmk makeapp -r -t console -o compile_dxbc compile_dxbc.bmx
compile_dxbc.exe colormatrix/colormatrix.hlsl colormatrix/colormatrix.dxbc
```

Finally embed the compiled assets:

```sh
./embed colormatrix/manifest.json colormatrix
```

Import the generated `_assets.c` alongside your application imports, then
include the generated `.bmx` file. Its factory creates the
package; pass that to `CreateShaderEffect`. Keep the manifest, generated source,
SPIR-V, DXBC, BMX wrapper and `_assets.c` together in version control. C arrays
embed the assets without runtime file access. No build-time shader compiler is
linked into the application. Metal source is compiled by the system on use.

The fixed bindings are image/sampler 0 and two uniform buffers: Max2D mode
flags at 0, parameter float4 slots at 1. Vulkan uses image set 2 and uniform
set 3; HLSL uses t0/s0 space2 and b0/b1 space3, shader model 5.1. Metal uses
`m2dEffectMain`, Vulkan `main`, and HLSL `m2dEffectMain`.

## Validation and cost

The generator checks manifest fields, schema and basic function-body structure.
Runtime creation checks version, schema, size and SPIR-V/DXBC container bounds;
backend shader/pipeline creation performs backend compatibility checks. These
checks are **not shader reflection or a security sandbox**. Use trusted generated
assets with the fixed wrapper ABI; arbitrary binaries can violate that contract.

Ordinary draw records retain their previous size and do not allocate or copy
package parameters. Built-in 16-byte uniforms remain inline. Larger package
uniforms use a retained arena, allocated on first use and grown when needed.
There are no per-draw parameter-array allocations after capacity is sufficient.
This preserves the ordinary drawing path; it is not a GPU performance claim.

Tests cover typed validation, HDR/alpha matrix arithmetic, tint, ordinary and
render-image inputs, compact and triangle paths, queued parameter snapshots,
arena growth, batching, state recovery and context recreation. The separate
scalar-plus-vector test package exercises the public generator. Direct3D assets
are compile-checked; VM Vulkan results do not establish Direct3D 12 runtime
support.

Validation on 2026-11-18: package regressions pass on macOS Metal and on
Windows/Ubuntu Vulkan; software fallback rejects unsupported package draws.

The build tools and their regression tests are written in BlitzMax. The shader
compilers (`glslc` and Microsoft's `D3DCompile`) remain external platform tools.
The generated `_assets.c` files contain only embedded data and accessors.
Readable triple-quoted templates live in `packages/templates.bmx`.

Run the generator regression without Python from the repository root:

```sh
bmk makeapp -r -t console -o shader_package_generator tests/shader_package_generator.bmx
./shader_package_generator . /path/to/new-scratch-directory
```

It checks exact reproduction of both reference packages, including embedded
assets, and rejects malformed schemas and function bodies. The tools resolve
relative paths against the directory from which they were launched.
