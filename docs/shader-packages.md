# Custom shader packages

Import `Max2D.SDL3GPUEffects` to use shader packages on SDL GPU.
ABI 1 transforms sampled colour; ABI 2 transforms image-local texture
coordinates before sampling; ABI 3 also samples a second image. Existing ABI 1
and 2 packages remain compatible. Arbitrary resource layouts remain outside
these contracts.
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
untrimmed transparent render-image layer first. A coordinate package can also apply a colour body in the same draw, as described below.
No new work is added to ordinary draws or the native renderer's draw records.

## Combined distortion and colour

ABI 2 and 3 manifests may add `colourBodies`, an object with equivalent `metal`,
`glsl` and `hlsl` function bodies returning a four-component colour. These receive
`c` (straight RGBA) and the same named parameters as the coordinate body.
The two functions share the package parameter slots (six for ABI 2, three for ABI 3). See
`tests/data/combined/manifest.json` for a minimal example.

The order is coordinate transformation, bounded sampling, source alpha
interpretation, drawing tint, colour body, alpha clamp, mask discard and output
premultiplication. RGB remains unclamped for HDR. No colour-space conversion is
implicit. A colour body that adds alpha can make transparent or outside samples
visible; preserve `c.a` if that is unwanted. The colour body does not receive `uv`.

`CreateGradedDistortionEffect(strength=0.03,frequency=20)` combines the wave/ripple
controls above with two float4 parameters:

- `grade`: saturation, exposure multiplier, contrast around 0.5, brightness offset.
  Defaults to `(1,1,1,0)`.
- `gradeTint`: RGBA multipliers, default `(1,1,1,1)`.

With zero strength and default grading it preserves the source. Saturation uses
luminance weights `(0.2126,0.7152,0.0722)`, then exposure, contrast, brightness and
tint are applied in that order. All controls use the source's numeric colour space.

```blitzmax
Local effect:TMax2DShaderEffect=CreateGradedDistortionEffect()
effect.SetFloat("time",elapsedSeconds)
effect.SetFloat4("grade",0,1,1.2,0) ' Monochrome with extra contrast.
DrawImageEffect(image,effect,100,100)
```

The [interactive example](../examples/graded_distortion.bmx) offers natural,
monochrome, warm and cool grades. Press G to cycle them.
This is an explicitly authored combined shader; existing effect chains are not
automatically fused. It uses one draw without an intermediate render image, and
supports `DrawImageEffectBatch`. This is not a GPU timing claim.

## Two-texture effects

ABI 3 adds one required image bound with `effect.SetTexture(map,frame=0)`.
Its view maps across the drawn source's normalized 0–1 coordinates, independently
of source size, drawing tint or coordinate distortion. Both shader bodies receive
`m`, the sampled **straight RGBA** map value. The coordinate body also receives
`uv`; the optional colour body receives `c` after source sampling and drawing tint.
For example, a custom colour body can return `c * float4(1,1,1,m.a)` for a texture
mask (use `vec4` in GLSL).

The map is sampled at mip zero before source distortion. Source and map use their
own atlas bounds and nearest/bilinear filtering flags. `SetEdgeMode` controls source
sampling; `SetTextureEdgeMode` controls map sampling, including filtered repeat
seams. Both default to transparent. Map pixels use the same alpha interpretation
as normal images: render images are unpremultiplied after interpolation; R8 coverage
images produce white RGB and coverage alpha. Use an RGBA map for red-channel data.

`SetTexture` retains the image; queued draws snapshot the binding and parameters.
It does not copy the texture's pixels. Normal texture updates flush prior draws
before changing pixels. Passing Null clears the binding; subsequent drawing throws.
Trimmed maps and sampling the current render target are rejected. Render-image
maps must belong to the current graphics context. Use an untrimmed layer when
starting from trimmed artwork.

ABI 3 provides one to three typed user slots and five reserved slots: source bounds,
source sampling, map bounds, map sampling and map alpha interpretation. Total
uniform data remains at most 128 bytes. The texture binding is stored alongside
queued uniforms; ordinary draw records remain unchanged in size.

### Displacement

```blitzmax
Local water:TMax2DShaderEffect=CreateDisplacementEffect(map,0.03,0.02)
water.SetEdgeMode(MAX2D_EDGE_REPEAT)
DrawImageEffect(image,water,100,100)
```

Map red and green encode horizontal and vertical displacement. A value of 0.5 is
neutral; 0 and 1 apply minus/plus the respective strength as a fraction of source
width/height. Update strengths with `SetFloat4("amount",x,y,0,0)`.

### Dissolve

```blitzmax
Local burn:TMax2DShaderEffect=CreateDissolveEffect(noise)
burn.SetFloat("progress",0.5)
burn.SetFloat("width",0.1)
burn.SetFloat4("edge",4,1,0.1,1) ' HDR RGB and intensity.
DrawImageEffect(image,burn,100,100)
```

Progress 0 preserves the entire source; progress 1 hides it entirely. Between
these endpoints, map red values below progress become transparent. A smooth glow
band extends from progress to progress + width on the visible side. `edge.rgb`
adds colour scaled by `edge.a` and the band weight; source alpha is preserved.
Width <= 0 disables glow. Map alpha is ignored by this built-in effect. RGB is
unclamped, but an SDR destination can clip the glow. The effect does not expand
the source quad or add bloom outside it.

The [live example](../examples/two_texture_effects.bmx) shares one procedural map
between displacement and dissolve. Both effects support `DrawImageEffectBatch`
without an intermediate render image. Custom shaders use the same fixed second
image mapping; arbitrary texture counts and separately transformed map UVs are
not exposed by this ABI.

## Package API

`TMax2DShaderPackage.Create(name,names,types,metal,spirv,dxbc,abiVersion=1)`
copies the schema and shader bytes. Names must be unique identifiers. Declare
one to eight `MAX2D_PARAMETER_FLOAT` or `MAX2D_PARAMETER_FLOAT4` parameters
for ABI 1, one to six for ABI 2, or one to three for ABI 3.
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
four-component colour for ABI 1 or two-component coordinates for ABI 2 and 3.
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

All versions use image/sampler 0 and two uniform buffers: Max2D mode
flags at 0, parameter float4 slots at 1. Vulkan uses image set 2 and uniform
set 3; HLSL uses t0/s0 space2 and b0/b1 space3, shader model 5.1. Metal uses
`m2dEffectMain`, Vulkan `main`, and HLSL `m2dEffectMain`. ABI 3 adds image/sampler
1 in the same resource spaces.

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

It checks exact reproduction of the reference packages, including embedded
assets, and rejects malformed schemas and function bodies. The tools resolve
relative paths against the directory from which they were launched.

Coordinate tests exercise both axes, atlas bounds, all edge modes, filtered
repeat seams, HDR and alpha, tint, queued edge snapshots, native compact and
triangle paths, batching, state recovery, trim rejection and context recreation.
The generator regression reproduces all eight checked-in packages.

Validation on 2026-11-19: coordinate regressions pass on macOS Metal and
Windows/Ubuntu Vulkan with strict numeric comparisons; software rejects the
unsupported effects. Both Direct3D assets compile without warnings; Direct3D
12 runtime remains unverified. Existing ABI 1 and generator tests also pass.

Combined effects validation on 2026-11-19: macOS Metal and Windows/Ubuntu
Vulkan pass strict comparisons against an explicit two-pass reference, covering
HDR, tinted straight alpha, atlas views, filtering, all edge modes, queued
parameter snapshots, six-slot uniforms, compact/triangle paths, batching, mask
thresholds and context recreation. Software rejects unsupported draws. Both new
Direct3D assets compile; Direct3D runtime remains unverified.

Two-texture validation on 2026-11-19: Metal and Windows/Ubuntu Vulkan pass
displacement and dissolve checks for atlas views, ordinary/render-image maps,
nearest/bilinear interpolation, source edge modes, HDR and alpha, queued texture
changes, arena growth, compact/triangle paths, one-submission batching, missing
map/feedback rejection, state recovery and context recreation. Existing colour,
coordinate, combined, built-in image-effect and GPU lifetime regressions pass on
Metal; software rejects the unsupported effects. Both new Direct3D assets compile;
Direct3D runtime remains unverified.
