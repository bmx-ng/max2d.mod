# Supplying your own mipmaps

Mipmaps are progressively smaller versions of an image. Supplying them yourself
lets you control filtering, preserve thin details, or prepare assets offline.
Max2D uploads your levels without regenerating or modifying their colours.

## Create an image from levels

Each level must use the same format. Dimensions halve at each step, rounding
down and clamping to one: for example, 7×5 → 3×2 → 1×1. `TTextureData.Create`
validates the layout and copies the levels.

```blitzmax
' These pixmaps contain your prepared 64x64, 32x32 and 16x16 levels.
' Convert to RGBA8888 explicitly if their source formats differ.
Local data:TTextureData=TTextureData.Create([ ..
	TTextureLevel.FromPixmap(basePixels.Convert(PF_RGBA8888)), ..
	TTextureLevel.FromPixmap(mip1Pixels.Convert(PF_RGBA8888)), ..
	TTextureLevel.FromPixmap(mip2Pixels.Convert(PF_RGBA8888))])

' Query after opening graphics with the intended backend.
If Max2DTextureDataSupport(data,FILTEREDIMAGE)=ETextureFormatSupport.Unsupported Then
	Throw "This backend cannot upload the supplied mipmaps"
End If
Local image:TImage=LoadImage(data,FILTEREDIMAGE)
DrawImage(image,20,20)
```

Multiple levels automatically enable `MIPMAPPEDIMAGE`. `FILTEREDIMAGE` selects
linear filtering within and between levels; without it, sampling selects the
nearest pixel and mip level. Partial chains are supported: the example above
stops at 16×16, so greater minification continues to use that last level.

With only one level, `MIPMAPPEDIMAGE` retains its original meaning: request
backend-generated mipmaps. Omit it when you want only that level. Automatic
mipmaps currently support uncompressed byte formats, not floating-point or compressed textures.

## Formats and alpha

OpenGL, D3D11 and native SDL GPU support supplied RGBA8888, A8, RGBA16F,
RGBA32F, BC1_RGBA and BC3_RGBA chains on capable devices.
SDL3 Renderer and D3D9 currently reject multi-level uploads.
Use `Max2DTextureDataSupport`, rather than the format-only query, to check supplied
chains. Unsupported requests fail explicitly; they never silently discard levels.

RGBA levels must contain **straight-alpha** colours, just like ordinary pixmaps.
When generating mipmaps for transparent artwork, average colours weighted by
alpha, then return the result to straight alpha before storing it. Otherwise,
invisible colours can create fringes. Max2D does not perform this preparation for
supplied chains. A8 levels contain only coverage, with implicit white colour.

Floating-point levels retain their precision and values outside 0–1. Prepare raw
bytes with `TTextureLevel.Create`; channels use native host byte order. Max2D does
not convert floating-point levels to pixmaps or quantise them to fit another
backend. The ordinary window/render target still limits the final output range.

## Ownership and recovery

`LoadImage` takes an independent snapshot of every level. You can discard or
modify the original data afterward. Data-backed images are read-only; use the
pixmap path for `DYNAMICIMAGE`, write locks or pixel replacement. Byte-format read
locks and collision masks use the base level. Floating-point and compressed images do not expose
those pixmap operations.

D3D11 retains all supplied levels for device recovery. OpenGL, D3D11 and native SDL GPU also
re-upload them when an image is used in a new graphics context. Supplied uploads
count every level's pixels in rendering statistics, and do not increment the
automatic mipmap-generation counter.

Image views and animation frames share the original texture and its mip chain.
For atlases, prepare padding at every level: tightly packed sprites can otherwise
bleed into one another when sampled at smaller sizes.

For precompressed bytes, see [BC1 and BC3 texture storage](compressed-textures.md).
