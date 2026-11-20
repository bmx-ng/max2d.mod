# Custom shader packages

Import `Max2D.SDL3GPUEffects` to use shader packages on SDL GPU, or
`Max2D.GLEffects` for OpenGL, `Max2D.D3D9Effects` for native Direct3D9 or
`Max2D.D3D11Effects` for native Direct3D11. All support ABI 1–4 and import the shared
`Max2D.ShaderEffects` API; existing SDL imports and package factories remain valid.
ABI 1 transforms sampled colour; ABI 2 transforms image-local texture
coordinates before sampling; ABI 3 also samples a second image; ABI 4 adds
independent transforms for that image. Existing ABI 1–3 packages remain compatible. Arbitrary resource layouts remain outside
these contracts.
Software SDL reports packages unsupported. OpenGL supports ABI 1–4 packages with desktop GLSL assets. Always query `Max2DSupportsImageEffect` before use.

The snippets below assume an open graphics context and existing source/map images.
Start with [Applying effects](effects-quickstart.md) for a complete program.
Built-in package factories already include their assets; the generation tools are
needed only when authoring or modifying shader packages.

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

ABI 2–4 manifests may add `colourBodies`, an object with equivalent `metal`,
`glsl` and `hlsl` function bodies returning a four-component colour. These receive
`c` (straight RGBA) and the same named parameters as the coordinate body.
The two functions share the package parameter slots (six for ABI 2, three for ABI 3/4). See
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

### Positioning the map

The built-in displacement, dissolve and texture-mask factories now create ABI 4
packages. They start with an identity map transform, so existing calls behave as
before. Custom packages opt in with `"abi": 4` and regenerated/compiled assets.
Original ABI 3 binaries remain usable with their original layout; attempting to
set a transform on them throws rather than silently ignoring it.

```blitzmax
effect.SetTextureTransform(offsetX,offsetY,scaleX,scaleY,rotation)
effect.SetTextureTransform() ' Restore identity.
```

Offsets use source-local widths/heights: `(0.25,0)` moves the map right by one
quarter of the source width. Scale is the visible map size: `(0.5,0.5)` makes it
half-size, or repeats it twice per axis with repeat edges. Negative scale mirrors
that axis. Rotation is clockwise in degrees about the map centre. Rotation uses
normalized coordinates; a non-square source stretches that coordinate space.

The shader samples using the inverse placement transform:

`mapUV = 0.5 + inverseScale * rotate(-rotation, sourceUV - 0.5 - offset)`

Map edge handling and bounded filtering follow the transform. Source sampling
coordinates remain independent; the map sample still drives the user functions
through `m`. Translation can move a transparent map completely out of view.
For a displacement map, transparent outside samples have zero RG, which means
negative displacement; choose clamp/repeat when that is unwanted.

Arguments and the resulting matrix coefficients must be finite. Zero scale and
coefficient overflow are rejected without changing the previous transform.
Parameters and transforms are snapshotted together for queued draws. The setter
creates no parameter arrays and needs no texture upload or intermediate image.

ABI 4 keeps three user slots and uses seven reserved slots: source bounds,
source sampling, map bounds, map sampling, two affine rows `(x,y,translation,0)`,
and map alpha interpretation. Its maximum uniform size is 160 bytes; older
versions keep their original layouts and sizes. Ordinary native draw records
retain their previous size.

### Sharing a map across sprites

`SetTextureMapping(mapPlacement,image,drawX,drawY)` derives the source-to-map
transform for the next image draw. Capture a map placement once, then reuse it
across sprites:

```blitzmax
' Set the camera/parent/object transform for the map first.
Local placement:TMax2DDrawTransform=CaptureImageTransform(maskImage,mapX,mapY)

' Set the camera/parent/object transform for this sprite.
SetRotation(spriteAngle)
effect.SetTextureMapping(placement,sprite,x,y)
DrawImageEffect(sprite,effect,x,y)
```

The bound second texture supplies the map's pixel dimensions. Capture its
placement with that image's handle. The helper includes each sprite's own handle,
origin, object rotation/scale/reflection, parent coordinate transform and camera.
Both captures must describe the same virtual coordinate space. Map placement is
read immediately and not modified or retained; later edits cannot change queued
draws. The mapping replaces the previous `SetTextureTransform` or mapping value.

Capture the map with the world camera applied for a world-aligned mask. Capture
with `SetCamera(Null)` for a mask fixed in virtual screen space, then restore the
sprite camera before mapping/drawing. This also works for displacement and
dissolve effects. Render-target changes can change the coordinate space: capture
and draw against matching target/view settings.

Call the helper immediately before each corresponding `DrawImageEffect`, using
the same image, position and drawing state. Each sprite needs its own update;
a batch shares one transform and cannot represent independent placements. This
convenience helper allocates a source-transform capture per call. It needs no
intermediate image or texture upload. Rendering the group to a layer remains an
alternative when one effect draw for the entire group is preferable.

Null inputs, missing maps, singular/non-finite map placements and coefficients
outside Float range throw without changing the previous mapping. A collapsed
source transform is allowed; it does not require an inverse. ABI 4 is required.
Trimmed sprites retain the existing restriction for coordinate effects.

The [shared-map comparison](../examples/shared_texture_mapping.bmx) shows original
sprites, per-sprite masks and one shared moving mask over rotating sprites.

The [map-transform demo](../examples/texture_transforms.bmx) scrolls and rotates
a displacement map and moves an elliptical soft mask. M toggles mouse control of
the mask; up/down changes map size; E cycles displacement-map edge modes.

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
without an intermediate render image. ABI 4 custom shaders use the same transform controls as the built-ins.
Arbitrary texture counts remain outside this contract.

### Texture masks

```blitzmax
Local mask:TMax2DShaderEffect=CreateTextureMaskEffect(maskImage)
DrawImageEffect(image,mask,100,100)

Local inverse:TMax2DShaderEffect=CreateTextureMaskEffect(maskImage,True)
DrawImageEffect(image,inverse,400,100)
```

By default, map alpha multiplies the source alpha; source straight RGB stays
unchanged, including HDR values. This supports ordinary RGBA masks, render-image
masks and single-channel R8 coverage (`PF_A8`) masks. Drawing colour and alpha
still apply normally. With alpha blending, fully transparent pixels have no
visible RGB contribution.

`channels` is a float4 of red, green, blue and alpha weights. The weighted sum is
clamped to 0–1, then inverted when `invert` is above 0.5. Examples:

```blitzmax
mask.SetFloat4("channels",1,0,0,0) ' Red-channel mask.
mask.SetFloat4("channels",0.2126,0.7152,0.0722,0) ' Weighted luminance.
mask.SetFloat4("channels",0,0,0,1) ' Alpha (default).
mask.SetFloat("invert",1)
```

Colour-channel masks use the map's straight RGB after alpha interpretation. A
render image cannot recover colour from pixels with zero alpha; use an opaque
RGBA map when colour channels are data. Coverage images expose coverage in alpha
and white RGB. No implicit colour-space conversion is performed.

Reuse the effect with `SetTexture` to change maps. `DrawImageEffectBatch` shares
one mask across all instances in a batch. Each instance maps the mask to its own
image-local bounds. For a mask spanning a group, first draw that group into a
render image and apply the mask to the layer. This effect changes alpha during
the draw; it does not change ambient clipping or stencil state.

The [soft-mask example](../examples/texture_masks.bmx) uses one moving render-image
mask for complementary normal and inverted reveals. Press M to preview the map.

## Package API

`TMax2DShaderPackage.Create(name,names,types,metal,spirv,dxbc,abiVersion=1,glsl=Null,d3d11=Null,d3d9=Null)`
copies the schema and shader bytes. Names must be unique identifiers. Declare
one to eight `MAX2D_PARAMETER_FLOAT` or `MAX2D_PARAMETER_FLOAT4` parameters
for ABI 1, one to six for ABI 2, or one to three for ABI 3/4.
Each occupies one 16-byte slot, including scalars; including reserved slots,
total uniforms are at most
128 bytes for ABI 1–3 or 160 bytes for ABI 4. At least one platform asset is required, each at most 4 MiB.

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
four-component colour for ABI 1 or two-component coordinates for ABI 2–4.
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
The entry point is `m2dEffectMain`, with optimization level 3. The default profile
is `ps_5_1` for SDL; pass `ps_4_0` or `ps_3_0` for the native assets.

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

ABI 1–4 generation also writes `.glsl`: a GLSL 1.20 wrapper using the manifest
`glsl` body, distinct from the Vulkan `.frag` source. The embedder includes it
as asset 3; OpenGL compiles it on first use. It uses sampler `image`, the Max2D
mode uniforms and a `vec4 p[]` parameter array. Keep shader bodies compatible
with GLSL 1.20 when targeting OpenGL. Regenerate and embed existing ABI 1–4
packages to add OpenGL support; their Metal/SPIR-V/DXBC assets need no changes.

Direct callers may pass desktop GLSL bytes after the ABI version in
`TMax2DShaderPackage.Create(..., abiVersion, glsl)`. Existing calls remain valid.
A GLSL-only ABI 1–4 package is allowed; missing renderer assets report unsupported.
The shared module owns immutable assets and typed values, while each renderer
registers its own adapter and owns compiled resources per context.
`examples/color_matrix.bmx`, `examples/coordinate_effects.bmx` and
`examples/graded_distortion.bmx` accept `-ud max2d_gl`.

OpenGL coordinate packages share the ABI 2 bounds and edge-mode slots. They
fetch texel centres at mip level zero, using nearest texture taps and explicit
interpolation for filtered images. Transparent, clamp and repeat modes stay
inside the source image region, including atlas views. Render-image taps flip
Y before sampling. The renderer restores the source texture's minification,
magnification and mip-range settings after submission. Combined colour bodies
run after sampling, alpha interpretation and tint, before alpha clamping and
mask discard. Trimmed images retain the existing explicit rejection.

ABI 3/4 bind `secondImage` to texture unit 1. The map has its own bounds,
filter/edge controls, render-target orientation and alpha interpretation. ABI 4
also applies its two affine transform rows before sampling. Source and map may
share one texture; sampling state is saved/restored once for aliased storage.
Both textures use mip level zero. A map that is also the active render destination
is rejected before drawing. Ordinary drawing restores texture unit 0 and has no
selected effect/map after an effect draw or a rejected submission.

The two-texture, texture-mask, transformed-map, shared-map and threshold-mask
examples accept `-ud max2d_gl`, as does the complete two-page effects gallery.

SDL GPU versions use image/sampler 0 and two uniform buffers: Max2D mode
flags at 0, parameter float4 slots at 1. Vulkan uses image set 2 and uniform
set 3; HLSL uses t0/s0 space2 and b0/b1 space3, shader model 5.1. Metal uses
`m2dEffectMain`, Vulkan `main`, and HLSL `m2dEffectMain`. ABI 3/4 adds image/sampler
1 in the same resource spaces.

## Native Direct3D assets

The generator also writes `.d3d11.hlsl` and `.d3d9.hlsl`. On Windows, build the
BlitzMax `compile_dxbc.bmx` tool and compile these with the matching profile:

```
compile_dxbc.exe colormatrix/colormatrix.d3d11.hlsl colormatrix/colormatrix.d3d11.dxbc ps_4_0
compile_dxbc.exe colormatrix/colormatrix.d3d9.hlsl colormatrix/colormatrix.d3d9.bin ps_3_0
```

Then run the existing embedder. Generated wrappers include all six assets.
`TMax2DShaderPackage.Create(..., abiVersion, glsl, d3d11, d3d9)` adds two optional
trailing byte arrays; existing calls remain valid. A package may omit any backend
asset, in which case that backend reports it unsupported. SDL DXBC uses its own
binding contract and cannot be substituted for the native D3D11 asset.

D3D11 binds modes at pixel buffer b0, parameters at b1, and source/map at t0/t1.
D3D9 binds modes at c0, parameter slots at c1–c10, allocation scales at c11/c12,
and source filtering information at c13. Generated D3D9 shaders receive float tint
through TEXCOORD1, logical image UV through TEXCOORD0, and screen coordinates
through TEXCOORD2 for pixel-centre interpolation correction. Keep these wrapper
contracts intact when customizing generated source. Coordinate/map packages use
point taps at mip zero and implement requested filtering within the selected view.

Native caches belong to the graphics context and copy package identities. Closing
or replacing a D3D11 device recreates shaders as needed; D3D9 shader objects survive
presentation resets. Drawing rejects destination feedback before submitting pixels
and restores ordinary drawing after success or an exception. No runtime shader
compiler is loaded by applications.

## Validation, resource costs and tool tests

The generator checks manifest fields, schema and basic function-body structure.
Runtime creation checks version, schema, size and SPIR-V/DXBC container bounds;
backend shader/pipeline creation performs backend compatibility checks. These
checks are **not shader reflection or a security sandbox**. Use trusted generated
assets with the fixed wrapper ABI; arbitrary binaries can violate that contract.

On SDL GPU, ordinary draw records retain their previous size and do not allocate or copy
package parameters. Built-in 16-byte uniforms remain inline. Larger package
uniforms use a retained arena, allocated on first use and grown when needed.
There are no per-draw parameter-array allocations after capacity is sufficient.
OpenGL copies the parameter slots into retained context storage and uploads them
when submitting the effect batch. Closing the context releases its shader cache.
This preserves the ordinary drawing path; it is not a GPU performance claim.

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

## Soft threshold masks

`CreateThresholdMaskEffect(map, low=0.4, high=0.6, inverted=False)` turns a
texture into a smooth reveal. The default uses map alpha, including R8 coverage.
Use `SetFloat4("channels",1,0,0,0)` for red-channel noise maps. The weighted
channel sum is clamped to 0–1 after map filtering, then thresholded.

Change thresholds using `SetFloat4("range",low,high,0,0)`. When high exceeds
low, coverage is zero at/below low, one at/above high, and smoothstep between.
Equal or reversed bounds produce a hard cut at low, retaining equality.
`SetFloat("invert",1)` inverts the resulting coverage. Source alpha is multiplied
by coverage; straight RGB retains HDR values, and drawing tint/alpha still apply.
All parameters must be finite; thresholds may extend outside 0–1.

For a complete animated disappearance with progress 0–1 and positive feather:

```blitzmax
Local low:Float=progress*(1+feather)-feather
mask.SetFloat4("range",low,low+feather,0,0)
```

This includes fully visible and fully hidden endpoints even for map values 0
and 1. A hard cut at 1 still retains map value 1; advance its threshold above 1
for complete disappearance. The effect supports `SetTextureTransform`,
`SetTextureMapping`, bounded atlas views and render-image maps just like texture
masks. It uses one draw and no intermediate render targets. Software rendering
rejects the GPU package explicitly.

See [the interactive comparison](../examples/threshold_masks.bmx): Space pauses,
I inverts, and Up/Down adjusts the transition width.
