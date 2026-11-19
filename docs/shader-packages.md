# Custom shader packages

Import `Max2D.SDL3GPUEffects` to use single-source packages on SDL GPU.
ABI 1 transforms sampled colour; ABI 2 transforms image-local texture
coordinates before sampling. Existing ABI 1 packages remain compatible.
Additional textures and arbitrary resource layouts are outside these contracts.
Software SDL and OpenGL report these packages unsupported.

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

## Waves, ripples and custom coordinates

```blitzmax
Local warp:TMax2DShaderEffect = CreateDistortionEffect(0.035,28)
warp.SetEdgeMode(MAX2D_EDGE_REPEAT)
' Each frame: time is a phase in radians, supplied by the application.
warp.SetFloat("time",Float(MilliSecs())*0.002)
warp.SetFloat("ripple",1) ' >0.5: radial ripple; otherwise heat-haze waves
DrawImageEffect(image,warp,x,y)
```

The [interactive example](../examples/coordinate_effects.bmx) displays original,
wave and ripple panels. Space pauses, E cycles edge modes, up/down changes
strength, and left/right changes frequency. Strength is a fraction of image
size. Frequency and time use radians. The radial centre is (0.5,0.5); image
aspect ratio is not corrected automatically.

For a custom coordinate package, set `abi` to **2** in the manifest. Bodies
receive `uv`, an image-local normalized coordinate, and return finite `float2`
(Metal/HLSL) or `vec2` coordinates (GLSL). For example `return uv+offset.xy;` uses a declared
float4 `offset`. The regular generator, compiler and embedder commands apply.
`tests/data/coordinates/manifest.json` is a complete minimal example.

Use one to six typed user slots. Two additional float4 slots are supplied by
the renderer: normalized source bounds (left, top, width, height), followed by
inverse texture dimensions, edge mode and the filtered-image flag. These
values are captured with the user parameters for each submitted draw. Named
setters cannot overwrite the reserved slots.

`SetEdgeMode` accepts:

- `MAX2D_EDGE_TRANSPARENT` (default): samples outside [0,1) return transparent.
  Interior samples clamp to edge texel centres; this is a hard boundary, not
  a filtered fade into a transparent border.
- `MAX2D_EDGE_CLAMP`: samples clamp to the image's edge texel centres.
- `MAX2D_EDGE_REPEAT`: coordinates wrap in either direction. Filtered images
  blend four wrapped texels across the region's own seam, excluding neighbours.

All coordinate sampling uses **mip level zero**. Atlas regions and animation
frames use their own bounds, including nonzero source offsets. Nearest and
filtered sampling follow the image flags. Filtered sampling explicitly blends four bounded texel reads; nearest uses one.
This avoids atlas bleed from hardware filtering precision at region edges. Colour interpretation, tint, mask discard and output
premultiplication follow the existing wrapper rules; HDR RGB remains unclamped.
Render-image filtering operates on stored premultiplied colour. Ordinary
straight-colour textures retain their existing interpolation convention.

Distortion only changes sampling within the drawn quad; it does not expand
geometry or layer padding. Trimmed sprites are rejected explicitly because
removed pixels cannot be recovered by coordinate sampling. Draw them into an
untrimmed transparent render-image layer first. A coordinate package changes
sampling only; chain a colour effect through a layer when both are required.
No new work is added to ordinary draws or the native renderer's draw records.

## Package API

`TMax2DShaderPackage.Create(name,names,types,metal,spirv,dxbc,abiVersion=1)`
copies the schema and shader bytes. Names must be unique identifiers. Declare
one to eight `MAX2D_PARAMETER_FLOAT` or `MAX2D_PARAMETER_FLOAT4` parameters
for ABI 1, or one to six for ABI 2.
Each occupies one 16-byte slot, including scalars; including reserved slots,
total uniforms are at most
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
four-component colour for ABI 1 or two-component coordinates for ABI 2.
In ABI 1, `c` is tinted straight RGBA; in ABI 2, `uv` is image-local. Named parameters are
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

Both versions use image/sampler 0 and two uniform buffers: Max2D mode
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
Readable triple-quoted templates live in `sdl3gpueffects.mod/packages/templates.bmx`.

Run the generator regression without Python from the repository root:

```sh
bmk makeapp -r -t console -o shader_package_generator tests/shader_package_generator.bmx
./shader_package_generator . /path/to/new-scratch-directory
```

It checks exact reproduction of both reference packages, including embedded
assets, and rejects malformed schemas and function bodies. The tools resolve
relative paths against the directory from which they were launched.

Coordinate tests exercise both axes, atlas bounds, all edge modes, filtered
repeat seams, HDR and alpha, tint, queued edge snapshots, native compact and
triangle paths, batching, state recovery, trim rejection and context recreation.
The generator regression reproduces all four checked-in packages.

Validation on 2026-11-19: coordinate regressions pass on macOS Metal and
Windows/Ubuntu Vulkan with strict numeric comparisons; software rejects the
unsupported effects. Both Direct3D assets compile without warnings; Direct3D
12 runtime remains unverified. Existing ABI 1 and generator tests also pass.
