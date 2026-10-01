# Native SDL3 GPU drawing

Use `Framework Max2D.SDL3GPUMax2D` to draw through SDL's GPU API. SDL selects
Metal, Vulkan or Direct3D 12 according to the platform and available device.
`SDLGPUMax2DDriverName()` reports the selected driver. There is no silent fallback
to SDL_Renderer: failure to create the GPU device fails graphics creation. Check
the result of `Graphics` before drawing; BRL.Graphics may catch driver exceptions.

```blitzmax
SuperStrict
Framework Max2D.SDL3GPUMax2D

Graphics(640,480,0)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls()
	DrawText("Native SDL GPU: "+SDLGPUMax2DDriverName(),10,10)
	Flip()
Wend
EndGraphics()
```

The [hello example](../examples/sdl_gpu_hello.bmx) also demonstrates letterboxing
and a native-resolution text overlay.

## Choosing between the SDL backends

`Max2D.SDL3RenderMax2D` uses SDL_Renderer, including when its selected renderer is
named `gpu`. `Max2D.SDL3GPUMax2D` owns the GPU device, graphics pipelines, shaders,
textures and command buffers directly. Import one backend as your framework.
Both build against the included SDL sources; neither needs an installed SDL DLL.

Window sizes, input events and fullscreen requests use the shared SDL3 graphics
and system modules. Existing cameras, coordinate conversion, text, atlases,
tilemaps and drawing-state scopes remain core Max2D features.

## Current coverage

The implementation supports:

- All five blend modes, including shader-based `MASKBLEND` with the usual 0.5 threshold.
- RGBA8 images, dynamic partial updates, nearest/linear filtering, and native
  single-channel A8 glyph/atlas storage.
- RGBA8 render images, transparent target composition, target-to-target drawing,
  and straight-alpha pixmap readback.
- Automatic RGBA8/A8 mipmaps, mipmapped RGBA8 render images, and supplied
  RGBA8/A8 mip chains (including partial chains).
- Native RGBA16F/RGBA32F image textures, supplied mip chains and render images,
  when supported by the device. Float target readback returns RGBA32F data.
- Native BC1/BC3 compressed images and supplied mip chains on capable devices,
  including optional `Image.DDS` file and stream loading.
- Viewports, virtual-resolution bars, multiple windows and presentation with or
  without vsync (falling back to vsync when immediate presentation is unavailable).

Other compressed formats, explicit device-loss recovery and custom shader APIs
remain future work. Capability queries report unsupported format requests explicitly. Do not infer these features from the capabilities of SDL's GPU API.
No native maximum texture dimension is reported yet; zero in that query means
unknown, and actual allocation can still fail.

## Mipmaps

Use `FILTEREDIMAGE|MIPMAPPEDIMAGE` when loading artwork that will be drawn smaller
than its source size. This selects trilinear filtering. Without `FILTEREDIMAGE`,
sampling chooses the nearest pixel in the nearest mip level. Query
`Max2DSupportsImageFlags` or `Max2DTextureFormatSupport` first.

```blitzmax
Local image:TImage=LoadImage(pixmap,FILTEREDIMAGE|MIPMAPPEDIMAGE)
Local target:TRenderImage=CreateRenderImage(512,512,FILTEREDIMAGE|MIPMAPPEDIMAGE)
```

Automatic chains extend down to 1×1, including for non-power-of-two dimensions.
They are generated on the GPU when first sampled after an upload, edit, clear or
draw. Unchanged images reuse their chain. A one-pixel image needs no generation
command. `mipmapGenerations` counts generation commands recorded with drawing.
Generation closes the current render pass when necessary; it does not read pixels
back to the CPU. Rectangular Vulkan textures use explicit GPU blits between
levels to work around an unclamped-dimension bug in the bundled SDL generator.

RGBA uploads are premultiplied before generation so invisible RGB does not bleed
into visible edges. Their CPU pixmaps and read locks remain straight alpha.
Render-image storage is already premultiplied. A8 images keep their one-byte
coverage storage even with mipmaps; no RGBA expansion is required.

For authored levels, use `LoadImage(data)` with `TTextureData`, and query
`Max2DTextureDataSupport`. Supplied RGBA8/A8/RGBA16F/RGBA32F levels are uploaded unchanged with
straight alpha, never regenerated, and clamp sampling to the last supplied level.
A single level with `MIPMAPPEDIMAGE` instead requests automatic generation.
See [supplying mipmaps](texture-data.md) for construction and alpha guidance.

Packed runtime atlases still reject automatic mipmaps. Animation cells loaded
from ordinary pixmaps get independent chains to prevent neighbouring frames
bleeding into each other. Views of supplied chains share their original texture.

The [mipmap example](../examples/sdl_gpu_mipmaps.bmx) compares ordinary linear
filtering with trilinear mipmaps. Left/Right adjusts size; Space pauses rotation.

## Floating-point images

Load `PF_RGBA16F` or `PF_RGBA32F` through `TTextureData`. Query
`Max2DTextureDataSupport(data,flags)` before loading: support depends on the
selected GPU device. Uploads retain the original channel precision, including
negative values and values greater than one. Padded rows are supported. Supplied
mip levels remain unchanged and may form a partial chain.

These are read-only image textures. Automatic float mipmap generation, dynamic
pixmap updates and float pixmap read locks remain unsupported.
The ordinary RGBA8 destination still clamps the final drawing result to 0–1;
this is not HDR display output. The [float texture example](../examples/sdl_gpu_float_textures.bmx)
shows why retaining highlights before colour modulation matters.

## Floating-point render images

Use `CreateRenderImage(width,height,FILTEREDIMAGE,PF_RGBA16F)` or `PF_RGBA32F`
when intermediate drawing must preserve negative values or highlights above one.
Check `Max2DSupportsRenderImage` with the same arguments first. The backend checks
format support and creates the drawing pipelines for that format on first use;
subsequent targets reuse them. Ordinary RGBA8 targets remain the default.

Drawing, clearing, target-to-target sampling and blend modes use the existing
Max2D API. Storage uses premultiplied alpha. `ReadRenderTextureData` returns
straight-alpha RGBA32F data for either float target format, retaining its range;
`ReadRenderImage` rejects float targets instead of silently quantising them.
Readback does not change the current drawing destination.

Float targets do not support automatic mipmaps or HDR window output.
See [floating-point render images](float-render-images.md) for usage and the
lighting example. Build that example with `-ud max2d_sdlgpu` for this backend.

## Compressed images

`PF_BC1_RGBA` and `PF_BC3_RGBA` retain their encoded blocks in GPU storage.
Use `TTextureData`, or import `Image.DDS` and load a supported DDS file/stream.
Check `Max2DTextureDataSupport` before loading; there is no automatic decompression
fallback when the active device does not support a format.

The native SDL GPU backend requires base dimensions to be multiples of four.
Lower mip levels may be smaller or unaligned. Padded block rows are repacked for
upload, and partial chains clamp sampling to the final supplied level. Alpha uses
the existing straight-alpha image convention; BC1 supports one-bit transparency
and BC3 supports interpolated alpha.

Compressed textures are read-only images: no render-target use, automatic mipmap
generation, pixmap locks or collision masks. See [compressed textures](compressed-textures.md)
for storage sizes, DDS loading and asset preparation.

## Rendering and readback

Max2D batches are recorded in order. Their vertices are uploaded together using
reusable buffers with SDL's resource cycling. Consecutive draws to one target
share a render pass. A texture update submits preceding draws before changing
its pixels, preserving dynamic-image ordering.

Window drawing uses a persistent RGBA8 backbuffer, blitted to the swapchain at
`Flip`. This supports existing window readback semantics, at the cost of one
extra full-window texture and a presentation blit. Resizing allocates a new
backbuffer; redraw its contents as usual.

Readback submits pending work and waits on a GPU fence. Prefer keeping images on
the GPU when a CPU copy is unnecessary. Image uploads and readbacks currently
allocate transfer buffers; pooling these is a later performance improvement.
The bundled SDL Metal upload implementation ignores a padded upload stride, so
this backend packs Metal upload rows tightly. D3D12 uploads use 256-byte row
alignment. Readback uses each backend's supported transfer-row layout.

## Shaders and validation

Shader sources and embedded assets live in `sdl3gpumax2d.mod/shaders` and the
adjacent generated headers. Applications do not need a shader compiler installed.
See [shader rebuilding](../sdl3gpumax2d.mod/shaders/README.md) when changing them.

Run `python3 tests/run_regressions.py sdlgpu` for mipmaps, supplied chains, target/blend/presentation,
texture ownership, coverage atlases, dynamic updates, viewports, cameras,
state scopes, text layout/colour, trimmed atlases and Tiled/LDtk/tilemap drawing.
The resource-lifetime check also stresses queue rollover, deferred texture release
and repeated window resizing. These verify pixel output, not performance claims.

Run `python3 tests/run_regressions.py sdlgpu-window` separately to exercise
borderless/exclusive transitions, restored window dimensions and input mapping,
invalid transitions, and retained render-image contents. This changes display
modes during the test. Broader application and physical-hardware coverage remain
useful, particularly for the D3D12 path.

Initial validation passed the seven-test profile on macOS/Metal and Linux/Vulkan,
and on the Windows VM with SDL selecting Vulkan. Subsequent mipmap, supplied-chain,
render-target and coverage-atlas checks passed on all three configurations.
A subsequent integration pass ran 11 checks on each configuration: lifetime/queue
rollover, general integration, paragraph and coloured text, trimmed atlases, tilemaps,
tile transforms, Tiled, LDtk, rendering diagnostics and fullscreen transitions.
All passed, including Windows window restoration at 200% DPI. No rendering-code
changes were required by that pass. The normal profile now contains 23 rendering
tests, with fullscreen in its separate profile.

The Direct3D 12 shader assets compile successfully. Forcing `SDL_GPU_DRIVER=direct3d12` in this Windows VM
reports that driver as unsupported, so Direct3D 12 rendering still needs a
compatible device. Set `SDL_GPU_DRIVER` before launching when testing a specific
SDL GPU driver.

## Compact sprites

`Max2D.SDL3GPUMax2D` enables compact sprites by default. To use expanded triangles instead:

```blitzmax
Graphics 960, 540
SetSDLGPUMax2DCompactSprites(False)
```

If compact pipelines cannot be created, a new context falls back to expanded
triangles. Calling `SetSDLGPUMax2DCompactSprites(True)` explicitly enables compact
submission and reports pipeline-creation failures. The setting belongs to the current
GPU context; changing it flushes pending Core geometry and does not change other
windows. Use `False` to return to expanded triangles. It is a backend setting,
not drawing state, so Push/Pop and Using scopes do not restore it.

Images, glyphs and other rectangles using the common quad drawing path submit a
64-byte affine record instead of six 32-byte vertices. A vertex shader generates
the corners. Arbitrary meshes and other primitives retain their triangle path.
Mixing the two preserves submission order and forces a batch boundary. Clipping,
blend modes, render targets, texture updates and mipmap dependencies retain the
same semantics. Atlas images and trimmed images need no API changes.

Transforms, including cameras and pixel-aligned glyph placement, are applied
before the compact record is submitted. Floating-point evaluation differs from
CPU-expanded vertices, so non-integral transforms can have small rasterisation
rounding differences. This is not a text-layout or coordinate-system change.

Fewer uploaded bytes and fewer Core batches can improve CPU-bound scenes, but
speedups depend on workload and hardware. Very frequent switches between meshes
and rectangles may offset the benefit. `Max2DStats().vertices` continues to count
the generated triangle vertices (six per rectangle), not the uploaded record
count, so it should not be used to calculate upload bytes.

Press **C** in `examples/sdl_gpu_hello.bmx` to toggle the path. The same option
covers Metal, Vulkan and Direct3D shader variants. Pixel comparisons have passed
on Metal/macOS and Vulkan in both Linux and Windows VMs. The Direct3D bytecode
compiles, but this VM selected Vulkan, so Direct3D runtime validation and broad
real-application performance evaluation are still pending.

`tests/gpu_compact.bmx` compares mixed rendering with the option off/on.
`tests/gpu_compact_benchmark.bmx` measures public `DrawImage` calls, Core batching,
command recording and GPU completion via a small readback every three frames.
The readback cost is included in both modes. It does not measure isolated GPU
time or window presentation, and synthetic results are not whole-game speedups.

## Native window overlays

`TSDLGPUMax2DContext.GetGPUDevice()` returns a borrowed SDL device handle for integrations such as ImGui. External resources must be released before closing graphics. `WindowOverlayFormat()` reports the intermediate window texture format; it need not match the swapchain format.

`RenderWindowOverlay(prepare, draw, data)` flushes queued Max2D drawing, invokes a native preparation callback outside a render pass, then a native drawing callback inside a preserving window pass. Max2D ends and submits that pass. The callbacks must be C functions, must not throw or re-enter Max2D, and must not end or submit the supplied objects. The target uses physical pixels and one sample. Only the current context's window target is accepted; drawing to image targets is rejected. Subsequent Max2D drawing remains ordered after the overlay, and `Flip()` presents normally. Native overlay work is not included in Core drawing statistics.

Applications using Dear ImGui should normally use the higher-level `ImGui.ImGuiSDL3GPUMax2D` adapter rather than provide these callbacks themselves.

## Native MaxGUI canvases on macOS and Windows

Import `SDL3.SDL3MaxGUI` alongside `Max2D.SDL3GPUMax2D`, create a MaxGUI canvas,
and draw using `SetGraphics(CanvasGraphics(canvas))`. The bridge uses Metal on macOS and an available SDL GPU driver on Windows. It
keeps the native GUI event loop and input handling. Rendering and render images
use the same GPU implementation as standalone windows.

Resize the gadget rather than calling `GraphicsResize`; fullscreen operations are
unavailable on attached canvases. Each canvas owns its GPU device and drawing
resources. Close manually attached graphics before freeing their host gadget.
See `sdl3.mod/sdl3maxgui.mod/examples/canvas_gpu.bmx` and the SDL3 MaxGUI guide for
a complete event loop. Linux attachment and ImGui input routing inside
MaxGUI canvases are not implemented yet.
