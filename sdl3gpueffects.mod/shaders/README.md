# Built-in image shader packages v1

This optional package uses the native SDL GPU backend's existing triangle and
compact vertex shaders. It changes only the fragment stage. Applications import
`Max2D.SDL3GPUEffects` to register the provider; no shader compiler is linked into
the application. Metal source is compiled by the system at first support query.

The package key is `max2d.saturation.v1`. The fixed ABI is:

| Input | Metal | Vulkan GLSL | Direct3D HLSL |
| --- | --- | --- | --- |
| Primary image + sampler | texture/sampler 0 | set 2, binding 0 | t0/s0, space 2 |
| Max2D sampling/blending flags, float4 | buffer 0 | set 3, binding 0 | b0, space 3 |
| Effect parameters, float4 | buffer 1 | set 3, binding 1 | b1, space 3 |

Parameter x is nonnegative finite saturation. Other components are reserved and
zero. Vertex outputs match `sdl3gpumax2d.mod/shaders/draw.*`. Input alpha is
converted as indicated by Max2D's flags, then tint and saturation are applied to
straight RGB. The existing mask threshold and output-premultiplication rules
run afterwards. This keeps custom blend inputs straight and render-image
storage premultiplied where required by the selected blend mode.

Rebuild SPIR-V using `glslc -O saturation.frag -o saturation.frag.spv` (or
`glslangValidator -V saturation.frag -o saturation.frag.spv`), then run
`python3 embed.py`. On Windows, compile `compile.cpp` with the SDK MinGW C++
compiler and `-ld3dcompiler`, then run it with `saturation.hlsl` and
`../shaders_dxbc.h`. Commit all three shader sources, the SPIR-V file and both
generated headers together. The DXBC target is pixel shader 5.1, matching SDL's
Direct3D 12 path and register-space conventions.

This directory describes internal built-ins. The public
[shader package API](../../docs/shader-packages.md) uses generated fixed wrappers
for colour (ABI 1), coordinates (ABI 2), or a second texture (ABI 3/4), with typed parameter slots. General texture layouts and reflection
remain outside that contract. Other backends report these effects unsupported.

## Blur package

`max2d.blur.v1` uses the same resource ABI. Parameters x,y contain the UV step
along the selected axis (`radius / (4 * image dimension)`); z,w are zero. The
nine weights are 1,8,28,56,70,56,28,8,1, normalized by 256. Sampling explicitly
uses mip level zero. Outside-image taps are transparent. Inputs must be
premultiplied render images; interpolation and convolution preserve their alpha
convention before converting to straight output for the usual tint/blend rules.

Compile `blur.frag` to `blur.frag.spv` before running `embed.py`, which now embeds
both packages. The Windows compiler accepts an optional package argument:
`compile.exe blur.hlsl ../blur_dxbc.h blur`. Omitting the final argument keeps
the original saturation build behavior. Keep blur sources, SPIR-V and generated
headers together. Direct3D bytecode compilation does not establish runtime
support on a device without a working Direct3D 12 GPU backend.

## Colourize package

`max2d.colorize.v1` uses the same ABI. Parameters xyz are the replacement RGB
(normalized from 0–255); w is zero. It samples alpha (red for coverage textures),
replaces RGB, multiplies drawing tint/alpha, then uses the ordinary mask and
output-premultiplication rules. It does not need to unpremultiply source RGB.
Compile `colorize.frag` to `colorize.frag.spv`, run `embed.py`, and generate DXBC
with `compile.exe colorize.hlsl ../colorize_dxbc.h colorize`.

## Outline package

`max2d.outline.v1` uses the same ABI. Parameters xy are the reciprocal source
width and height; z is the integer radius (0–4); w is zero. The kernel samples
alpha at integer offsets inside a disk (`x*x+y*y <= radius*radius`), including
the centre. Its output alpha is `max(neighbour alpha) - centre alpha`, clamped
to zero, then multiplied by drawing alpha. RGB is drawing tint. Existing mask
threshold and output-premultiplication rules apply. Mip level zero is sampled,
and taps outside the image are transparent. Sources must be render images, so
UV offsets cannot reach adjacent atlas entries or trimmed image storage.

There are 1, 5, 13, 29 and 49 selected samples for radii 0 through 4. The shader
loops over a fixed 9×9 stencil and skips offsets outside the chosen disk. This
is a bounded pixel stencil, not a distance-field outline or an arbitrary-radius
stroke. Compile `outline.frag` to `outline.frag.spv`, run `embed.py`, and generate
DXBC with `compile.exe outline.hlsl ../outline_dxbc.h outline`.

## Bright-pass package

`max2d.brightpass.v1` uses the same ABI. Parameter x is a finite, nonnegative
luminance threshold; yzw are zero. After converting sampled RGB to straight
colour and applying drawing tint, luminance is the dot product with
(0.2126, 0.7152, 0.0722). No implicit transfer-function conversion is performed.
RGB is preserved; alpha is multiplied by `max(luminance-threshold,0)/luminance`,
with zero weight when luminance is zero. Applying the extraction weight only
to alpha keeps premultiplied energy from being weighted twice. The ordinary
mask threshold and output-premultiplication rules run afterwards.

Compile `brightpass.frag` to `brightpass.frag.spv`, run `embed.py`, and generate
DXBC with `compile.exe brightpass.hlsl ../brightpass_dxbc.h brightpass`.

## Tone-map package

`max2d.tonemap.v1` uses the same ABI. Parameters x,y contain exposure and reciprocal
gamma; zw are zero. After source unpremultiplication and drawing tint, negative
RGB is clamped to zero and each channel uses `1 - 1/(1 + channel*exposure)`.
The mapped value is raised to reciprocal gamma. The absolute value before `pow`
asserts its nonnegative domain for shader compilers. Alpha is unchanged except
for the usual drawing alpha. Mask threshold and output-premultiplication follow.
This per-channel Reinhard curve can change colour ratios; gamma is an explicit
power curve, not an automatic colour-space conversion or an sRGB transfer function.

Compile `tonemap.frag` to `tonemap.frag.spv`, run `embed.py`, and generate DXBC
with `compile.exe tonemap.hlsl ../tonemap_dxbc.h tonemap`.

`linearoutput` presents linear RGB as extended linear HDR (exposure × white
level), or as per-channel Reinhard followed by piecewise sRGB encoding. Parameters
are exposure, white level, HDR boolean, and zero. It preserves coverage and uses
the same premultiplied input/output contract as the other colour effects. Its
Metal, SPIR-V and DXBC packages are generated with the tools above; pass
`linearoutput` as the final argument to `compile.cpp`'s executable.
