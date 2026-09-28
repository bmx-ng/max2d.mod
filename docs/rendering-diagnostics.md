# Rendering capabilities and statistics

Ask the current graphics context about the features your application needs.
Call these functions after `Graphics` or `SetGraphics`; each window can have
its own context and capabilities.

## Choosing a fallback

```blitzmax
If Max2DSupportsBlend(MASKBLEND) Then
	SetBlend(MASKBLEND)
Else
	SetBlend(ALPHABLEND)
End If

Local flags:Int=FILTEREDIMAGE
If Max2DSupportsImageFlags(flags | MIPMAPPEDIMAGE) Then
	flags :| MIPMAPPEDIMAGE
End If

Local cache:TRenderImage
If Max2DSupportsRenderImage(512,256,flags) Then
	cache=CreateRenderImage(512,256,flags)
End If
```

Choose fallbacks appropriate to your artwork: alpha blending does not have the
same threshold behaviour as MASKBLEND. SDL3 Renderer does not support mipmaps;
its MASKBLEND support depends on the renderer selected for that window.

`Max2DSupportsRenderImage(width,height,flags)` checks positive dimensions,
recognised flags, reported size limits and the backend's RGBA render-image
support. D3D9 also checks its device's power-of-two and square-image requirements;
OpenGL checks its viewport limits. Omitting `flags` uses `AutoImageFlags`, just
like `CreateRenderImage`.

The query creates no test image and does not flush queued geometry. A positive
answer is not an allocation guarantee: memory pressure or device loss can still
cause creation or first use to fail. Image creation is generally lazy; native
resources are created when first used in a context.

```blitzmax
Local maximumWidth:Int,maximumHeight:Int
GetMax2DTextureSize(maximumWidth,maximumHeight)
```

The built-in OpenGL, SDL3 Renderer, D3D9 and D3D11 backends implement these
queries. Custom contexts can override `TextureSize` and `SupportsRenderImage`;
the base context reports unknown limits and unsupported render images.

These are texture dimensions in pixels, independent of DPI, virtual resolution
and camera zoom. A zero value means the backend reported no bound. It does **not**
mean unlimited memory. For render images use the full query above as well.
Max2D currently exposes RGBA render images; this is not a query for arbitrary HDR,
depth or compressed render-target formats.

For window transitions, use `Max2DSupportsFullscreen()` and
`Max2DSupportsBorderlessFullscreen()`. A supported transition may still be
rejected for a particular display mode by the operating system.

## Texture storage formats

`Max2DTextureFormatSupport(pixelFormat,flags=0)` returns an
`ETextureFormatSupport` value for the current context:

| Result | Meaning |
| --- | --- |
| `Native` | The requested channels and precision are retained in texture storage. |
| `Converted` | Another representation provides equivalent drawing semantics, currently A8 expanded to RGBA. |
| `Unsupported` | Max2D cannot use this requested storage format or flag combination. |

```blitzmax
Select Max2DTextureFormatSupport(PF_A8,FILTEREDIMAGE)
	Case ETextureFormatSupport.Native
		Print "Coverage textures retain single-channel storage."
	Case ETextureFormatSupport.Converted
		Print "Coverage textures work, but use expanded GPU storage."
	Case ETextureFormatSupport.Unsupported
		Print "This combination is unavailable."
End Select
```

The format is the optional **storage** argument to `TImage.FromPixmap` or
`TTextureAtlas.Create`. It is not the input pixmap's format. For example,
`TImage.FromPixmap(rgb565Pixels)` still converts an RGB565 pixmap to RGBA even
though requesting retained `PF_RGB565` texture storage currently returns
`Unsupported`. Passing `PF_A8` as the storage argument explicitly discards colour
and retains opacity.

RGBA channel storage is native across the built-in backends. Non-mipmapped A8
storage is native in OpenGL, native SDL GPU and supported D3D11 devices; SDL3 Renderer and D3D9
report `Converted`. Mipmapped A8 remains `Native` in the native SDL GPU backend;
other backends with mipmap support report `Converted` for automatically generated A8 chains.
If the backend does not support mipmaps, that request reports `Unsupported`.

RGBA16F and RGBA32F report `Native` on supported OpenGL and D3D11 devices, or
`Unsupported` elsewhere. There is no lossy conversion fallback. Requests for
automatic floating-point mipmaps report `Unsupported`. For floating-point render targets,
query `Max2DSupportsRenderImage(width,height,flags,PF_RGBA16F)` (or `PF_RGBA32F`):
rendering and blending require additional device support. See
[floating-point render images](float-render-images.md). Load float bytes through
`TTextureData`, not `TPixmap`.

For owned data, use `Max2DTextureDataSupport(data,flags=0)`. This also checks
texture dimensions and supplied levels. OpenGL and D3D11 accept supplied RGBA8888,
A8, RGBA16F and RGBA32F chains where supported by the device. Multiple levels
imply mip sampling, including partial chains. A8 supplied levels stay native
where possible; D3D11 can expand them to RGBA when coverage storage is unavailable.
Native SDL GPU accepts supplied RGBA8888, A8, RGBA16F, RGBA32F, BC1 and BC3 chains
on capable devices.
SDL3 Renderer and D3D9 return `Unsupported` for supplied chains. A single level
with `MIPMAPPEDIMAGE` still requests automatic generation, so floating-point data
with that combination remains unsupported. `DYNAMICIMAGE` is unsupported for
all owned texture data. Neither query guarantees available GPU memory.

BC1_RGBA and BC3_RGBA report `Native` on supported OpenGL, D3D11 and native SDL GPU devices.
There is no decompression fallback. `Max2DTextureDataSupport` additionally checks
D3D11's requirement that base dimensions are multiples of four; smaller mip levels
are valid. Single levels with `MIPMAPPEDIMAGE`, dynamic images and other backends
are unsupported. For supplied chains, the data query checks native sampling
support independently of automatic generation.

`Native` does not promise zero-copy upload or matching channel byte order: a
backend may reorder channels without changing storage precision. The query
creates no image frames and returns an enum without allocating a result object.
Its default flags are zero, matching `TImage.FromPixmap`, rather than
`AutoImageFlags`. Dimensions, allocation failures and render-target support are
separate: use the existing size and render-image queries above.

Query after selecting the intended graphics context, and requery after device
replacement. Custom backends can override `TMax2DContext.TextureFormatSupport`;
the default reports native RGBA, converted A8, and unsupported other formats,
subject to the backend's image-flag support.

## Measuring a frame or a drawing section

```blitzmax
ResetMax2DStats()
Cls()
DrawWorld()
DrawInterface()
Flip()
Local frameStats:TMax2DStats=CaptureMax2DStats(False)
```

`ResetMax2DStats` submits pending geometry before zeroing the counters. It does
not clear the screen, discard drawing or release textures. `Flip` does not
reset counters automatically.

`CaptureMax2DStats()` submits pending geometry and returns a detached snapshot.
Use it at the end of a section that must include all drawing so far. Passing
`False` observes counters without flushing; after `Flip` this normally avoids
an unnecessary flush. Neither form waits for the GPU to finish.

`Max2DStats()` returns the existing **live** counter object, without flushing or
allocating a snapshot. Its fields change as work is submitted. For a display
updated every frame, you can read selected fields into numeric variables to
avoid allocating a snapshot each time. Read counters before drawing the
statistics overlay if you want to exclude the overlay itself.

| Counter | Meaning since the last reset |
| --- | --- |
| `submissions` | Nonempty geometry batches passed from Max2D to its backend |
| `vertices` | Vertices in those batches; ordinary quads contribute six |
| `textureCreations` | Image frames created by the context, including render images and atlas pages |
| `textureUpdates` | Image pixel-update calls issued by the context |
| `uploadedPixels` | Sum of pixel rectangle areas in those updates |
| `readbacks` | Image or backbuffer pixel reads issued by the context |
| `mipmapGenerations` | Mipmap-chain generations reported by the backend while submitting drawing |

These are Max2D counters, **not GPU timings or driver draw-call counts**. SDL
may combine or split submissions. Backend-internal textures, format conversions,
render-target copies and recovery uploads are not represented by these counters.
D3D9 can defer work while its device is unavailable, so a submission is not proof
that pixels reached the display. Uploaded pixels measure update area, not bus
traffic or texture memory. Clear/present operations do not count as geometry
submissions. Memory usage and native texture-bind counts are not currently
reported.

Adjacent draws with compatible texture and blend state share a batch. Texture,
blend, viewport or target changes, explicit flushes and batch capacity can end
one. Extra captures with flushing enabled can therefore change the batching you
are trying to measure.

Counters belong to the graphics context, not the current render image.
Switching render targets continues the same counters; selecting another window
selects that window's counters. The current native D3D9 and D3D11 backends
support one window at a time; reopening starts fresh counters. Snapshots remain valid after subsequent drawing,
reset or context closure.

Run `examples/rendering_diagnostics.bmx` to see the queries and per-frame
measurements together. The `render_diagnostics` regression covers capability
rejection, actual render-image use, batching, snapshots, reset and context
isolation across the supported backends.
