# OpenGL mipmaps

This page describes **automatic generation**. For prepared levels, including
floating-point textures, see [supplied mipmaps](texture-data.md).

`Max2D.GLMax2D` supports `MIPMAPPEDIMAGE` for ordinary images and render images:

```blitzmax
Local image:TImage=LoadImage("terrain.png",FILTEREDIMAGE|MIPMAPPEDIMAGE)
Local target:TRenderImage=CreateRenderImage(512,512,FILTEREDIMAGE|MIPMAPPEDIMAGE)
```

Mipmaps are successively smaller versions of a texture. Sampling from an
appropriate level reduces aliasing and shimmer when an image is drawn smaller
than its source resolution. They do not improve magnification.

| Image flags | Minification | Magnification |
| --- | --- | --- |
| Neither flag | Nearest | Nearest |
| FILTEREDIMAGE | Linear | Linear |
| MIPMAPPEDIMAGE | Nearest sample from nearest mip level | Nearest |
| FILTEREDIMAGE \| MIPMAPPEDIMAGE | Trilinear, blending neighbouring mip levels | Linear |

The backend uses `glGenerateMipmapEXT`, already available through its required
framebuffer extension, to generate the full chain down to 1×1. Non-power-of-two
sizes work too. See [Khronos mipmap generation documentation](https://wikis.khronos.org/opengl/GLAPI/glGenerateMipmap).

## Lifecycle and cost

Creation, CPU uploads, render-target clears and submitted draws mark the texture's
mip chain dirty. The chain is generated when the texture is next sampled, after
pending writes, rather than after every edit. Repeated sampling without changes
reuses it. Each rendering context owns and updates its own chain.

`Max2DStats().mipmapGenerations` counts successful complete-chain generations.
It remains zero for SDL Renderer. Core `uploadedPixels` counts CPU uploads, including all supplied levels;
it does not include GPU-generated mip levels. Typical square textures
need approximately one-third more texture storage for the complete chain; thin
textures can have a larger proportional overhead.

Generating a chain costs GPU work. A render image that is redrawn and then sampled
every frame needs a new chain each time. Only request mipmaps where minification
justifies that cost. Collision masks and CPU image locks continue to use level zero.

## Alpha and colour

Mipmapped CPU images are converted to premultiplied RGBA during native upload.
This stops the RGB of fully transparent pixels from contaminating lower levels.
Partial uploads convert only their updated area; CPU image pixels remain unchanged
and straight-alpha. Render images already use premultiplied storage.

The shader handles conversion for each blend mode; target readback still returns
straight-alpha pixels. Hidden RGB at zero alpha is lost in the mipmapped native
texture, so SOLID/SHADE sampling cannot recover that hidden colour. CPU locks and
collision snapshots of ordinary images retain the original pixels.

Generation uses the current RGBA8 colour values. This does not add sRGB/linear-light
filtering, anisotropic filtering or alpha-coverage preservation. A shrinking MASKBLEND sprite can lose thin features as averaged alpha
crosses the 0.5 threshold; ALPHABLEND is usually appropriate for smooth edges.

## Atlases and animation

Packed atlases reject `MIPMAPPEDIMAGE` explicitly. One-pixel gutters protect normal
linear filtering, but a complete page-wide mip chain eventually mixes neighbouring
sprites. Per-region mip layout, padding and level limits need separate support.
This restriction also applies to the batch atlas builder; the package format does
not gain mipmap support in this tranche.

`LoadAnimImage(...,MIPMAPPEDIMAGE)` instead copies each animation cell into its own
source texture, so every frame has an independent chain and cannot bleed into an
adjacent frame. This trades atlas batching for correct mip filtering. With
supplied texture-data mip levels, animation cells instead remain views of the
original sheet so the prepared chain is preserved. Prepare suitable padding at
each level when using that path.

Manually created image subviews and `DrawSubImageRect` still sample the parent's
mip chain. They do not create isolated mip levels; colours outside the selected
region may contribute at reduced levels. Use independent images (or LoadAnimImage
for sheets) when regions need isolation.

## SDL3 Renderer

SDL's Renderer texture sampling API exposes scale modes, not application-controlled
mip chains. Our SDL3 Renderer backend continues to report False for
`Max2DSupportsImageFlags(MIPMAPPEDIMAGE)` and rejects mipmapped draws explicitly.
The native `Max2D.SDL3GPUMax2D` backend supports mipmaps through the separate GPU API.
See [SDL_SetTextureScaleMode](https://wiki.libsdl.org/SDL3/SDL_SetTextureScaleMode).

## Tests and example

`tests/gl_mipmaps.bmx` checks complete mip levels and filter settings, checkerboard
minification, lazy reuse, edits/partial uploads, texture identity, transparent-colour
fringes, SOLID alpha, render-target clears/draws, non-power-of-two sizes, isolated
animation cells, atlas rejection and independent contexts. It renders into fixed-
size targets so Retina window scale cannot conceal a failure.

`tests/sdl_mipmap_capability.bmx` verifies explicit rejection before texture creation.
`examples/mipmaps.bmx` compares ordinary linear filtering with trilinear mipmaps.
Left/Right adjusts image size; Space pauses rotation. The mipmap generation count
should stop increasing after the image's first sampled draw.

Build with the usual `bmk makeapp -r` command. Native GL testing requires a window;
SDL capability testing can use the dummy video driver and software renderer.

Validated locally on macOS OpenGL in debug and release. Existing GL target/blend
regressions pass, and SDL software passes the unsupported-capability check.
The comparison example compiles. Subsequent Windows/Linux VM checks are recorded
in the [stabilisation report](stabilisation.md); physical Windows/Linux GPUs remain unvalidated.

## Windows D3D9

`Max2D.D3D9Max2D` implements the same image flags, premultiplied filtering and
atlas/animation rules. It uses capability-checked D3D9 autogeneration instead of
OpenGL mip generation. See [the D3D9 guide](d3d9.md#mipmaps),
`tests/d3d9_mipmaps.bmx` and `examples/d3d9_mipmaps.bmx`.

## Windows D3D11

`Max2D.D3D11Max2D` implements the same flags, premultiplied filtering and
atlas/animation rules using capability-checked `GenerateMips`. See
[the D3D11 guide](d3d11.md#mipmaps), `tests/d3d11_mipmaps.bmx` and
`examples/d3d11_mipmaps.bmx`.

## Native SDL GPU

`Max2D.SDL3GPUMax2D` implements automatic RGBA8/A8 mipmaps and mipmapped RGBA8
render images. It keeps A8 coverage in single-channel storage, and also accepts
supplied RGBA8/A8 chains. See [the native GPU guide](sdl-gpu.md#mipmaps),
`tests/sdl_gpu_mipmaps.bmx` and `examples/sdl_gpu_mipmaps.bmx`.
