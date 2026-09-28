# BC1 and BC3 textures

BC textures keep their encoded blocks in GPU storage. This reduces storage and
upload size compared with RGBA8888, at the cost of lossy colour encoding. Use
compressed textures for prepared assets; keep pixmaps for editable images.

| Format | Block storage | Alpha |
| --- | --- | --- |
| `PF_BC1_RGBA` (DXT1) | 8 bytes per 4×4 pixels | Opaque or one-bit transparency |
| `PF_BC3_RGBA` (DXT5) | 16 bytes per 4×4 pixels | Interpolated alpha |

The initial implementation supports UNORM sampling with straight alpha. It does
not enable sRGB decoding. It also does not provide a compressor, decompressor or
KTX loader. Import `Image.DDS` to load supported BC1/BC3 DDS containers, or supply
encoded blocks from your asset pipeline.

## Upload encoded bytes

```blitzmax
' bc3Bytes contains standard BC3 blocks in row-major block order.
Local level:TTextureLevel=TTextureLevel.Create(width,height,PF_BC3_RGBA,bc3Bytes)
Local data:TTextureData=TTextureData.Create([level])
If Max2DTextureDataSupport(data,FILTEREDIMAGE)=ETextureFormatSupport.Unsupported Then
	Throw "BC3 texture upload is unavailable"
End If
Local image:TImage=LoadImage(data,FILTEREDIMAGE)
```

OpenGL, D3D11 and native SDL GPU upload BC1/BC3 natively where supported. Other backends currently
reject them. There is no automatic expansion to RGBA: the support query lets you
choose an uncompressed asset explicitly when needed.

D3D11 and native SDL GPU require base width and height to be multiples of four. Lower mip levels
may be smaller or not block-aligned. The CPU container can represent arbitrary
positive dimensions; the data capability query applies the active backend's
additional restrictions. A format-only query cannot check dimensions.

## Rows and mip levels

A stored row contains **blocks**, not individual pixels. Default pitch is
`ceil(width/4) * bytesPerBlock`; the number of stored rows is `ceil(height/4)`.
For example, a 7×5 BC3 level needs two block columns and two block rows: 64 bytes.
Even a 1×1 mip level needs one complete block. Blocks retain their standard
little-endian encoding on every host.

You can supply padded block rows by passing `pitch` to `TTextureLevel.Create`.
Include the padding for the final block row too. The container validates the
buffer length and copies the bytes. OpenGL and native SDL GPU repack padded rows for upload;
D3D11 accepts the source row pitch.

Pass multiple levels to `TTextureData.Create`, largest first, to enable mip
sampling. Partial chains clamp to their final supplied level. Max2D never
regenerates compressed mipmaps. A single level with `MIPMAPPEDIMAGE` is rejected;
omit that flag or supply a chain. See [supplied mipmaps](texture-data.md).

## Ownership and limitations

Images take independent copies of all supplied levels. D3D11 restores the same
blocks after device replacement, and images can be reused after closing and
reopening graphics. Animation frames remain views of their source texture;
prepare padding at each mip level to avoid sampling neighbouring sprites.

Compressed images do not support dynamic edits, pixmap read/write locks,
collision masks or render-target use. `ToPixmap` fails explicitly because it
would require a decoder. Existing TPixmap loading and rendering are unchanged.

The storage encoding follows the [Khronos data-format specification](https://registry.khronos.org/DataFormat/specs/1.4/dataformat.1.4.html).
The D3D resource restrictions follow Microsoft's [block-compression documentation](https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-block-compression).

## Loading DDS files

```blitzmax
Import Image.DDS

Local image:TImage=LoadImage("terrain.dds",FILTEREDIMAGE)
```

DDS support is optional and uses signatures rather than filename extensions.
`LoadTextureData(url)` lets you inspect the format and mip levels before uploading.
Both APIs accept seekable streams and BRL.IO-backed URLs. Use
`LoadTextureDDS(stream)` for forward-only DDS streams. The first loader supports
legacy DXT1/DXT5 and DX10 BC1/BC3 UNORM 2D textures; unsupported DDS features fail
explicitly. Other image formats still use their ordinary pixmap loaders.
