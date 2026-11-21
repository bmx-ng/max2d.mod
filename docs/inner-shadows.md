# Cached inner shadows

`TMax2DInnerShadow` creates recessed shading inside a layer's alpha coverage.
It retains three full-size buffers and a blur pyramid. Source colours are ignored;
the result is white with transparent areas, ready for ordinary draw-time tinting.
Use the [effects provider](effects-quickstart.md#choose-a-provider) matching
your framework: SDL GPU, OpenGL, native D3D9 or native D3D11.

The fragment below assumes an open graphics context and an existing source
layer. For a complete program, see [Applying effects](effects-quickstart.md).

```blitzmax
Local shadow:TMax2DInnerShadow = CreateInnerShadow(8, 3, 3)
shadow.Prepare(scene.width, scene.height, 2)
shadow.Update(scene)

SetBlend(ALPHABLEND)
SetColor(255, 255, 255)
SetAlpha(1)
DrawImage(scene, x, y)
SetColor(0, 0, 0)
SetAlpha(0.6)
DrawImage(shadow.Result(), x, y)
```

Draw the source first and the shadow over it at the same position. Source and result
have independent image handles; account for a custom source handle when aligning.
Colour and opacity changes need no rebuild. Radius or offset changes take effect
on the next explicit `Update`.

## Coverage and direction

Let `A(x,y)` be source alpha and `B(x,y)` its blurred alpha. The cached alpha is:

`A(x,y) * (1 - B(x-offsetX, y-offsetY))`

The output has no coverage outside the original shape or inside its fully
transparent holes. Positive offsets shift the blurred silhouette right/down,
exposing a darker inner edge on the top/left. Negative offsets reverse that
placement. Large offsets can cover the whole source shape with shadow. Fractional
offsets use the filtered image's normal bilinear sampling.

For opaque shapes, zero radius, zero offset and zero reduction levels produce no
shadow. Partially transparent areas instead produce `A*(1-A)` in that case. When
compositing the result over a translucent source with ordinary alpha blending,
combined alpha increases inside that coverage; the source image itself is unchanged.

## API and lifetime

- `CreateInnerShadow(radius=8, offsetX=3, offsetY=3)` creates a description without
  GPU resources.
- `Prepare(width, height, reductionLevels=2, pixelFormat=PF_RGBA8888)` allocates
  retained storage. Dimensions must be positive; levels successively ceil-halve.
- `SetRadius` accepts finite nonnegative values in source pixels. The radius must
  fit four pixels in both axes at the smallest prepared level. `GetRadius` reads it.
- `SetOffset(x,y)` accepts finite source-pixel offsets; `GetOffsetX/Y` read them.
- `Update(source)` rebuilds and returns borrowed coverage. Source dimensions must
  match; the cached result cannot be its own source.
- `Result()` returns cached storage without rendering.
- `Release()` drops retained frames and keeps settings.

Identical preparation preserves results. Layout changes invalidate them. Result
retrieval requires a successful update and the correct open context. Settings
changes keep the previous result until updated. Input, radius and capability
preflight failures retain it; later runtime failures invalidate it. Normal
[effect-buffer ownership rules](effect-buffers.md) apply: borrowed results expire
on resize, release or context closure, and release rejects an active result target.

Update preserves source pixels, caller drawing state and target views. Source
handles, tint, transforms and clipping do not alter extraction. Query colourize,
blur, inverse-alpha blend and the desired render-image format before use. There
is no CPU fallback and no new shader package.

## Bounds, precision and cost

Pad source content with transparent pixels for blur sampling. Output dimensions
remain unchanged. Reduced blur adds filtering and approximates odd dimensions;
zero radius still resamples when levels are present. RGBA8 quantizes faint alpha;
choose a supported floating-point format for finer coverage precision.

With `L` reduction levels, preparation creates **L+4 textures**. Each update uses
silhouette extraction, scaled blur, a coverage copy and inverse-mask composition:

- Zero levels: **5 draws**.
- `L > 0`: **L+6 draws**; two levels use **8 draws**.
- Cached presentation: **one ordinary image draw**.

Warmed updates create no images, arrays, effect descriptions or textures and do
no uploads/readbacks. Helpers allocate drawing-state scopes. Offset changes
currently rebuild the whole pipeline, including blur. Ordinary drawing incurs no
inner-shadow work when this helper is unused.

`examples/inner_shadow.bmx` compares original shapes/text with recessed shading.
Arrows adjust radius/opacity; O cycles signed offsets, C changes colour and Space
toggles the shadow. `tests/inner_shadow.bmx` checks an independent alpha convolution
and shifted sampling reference, including partial alpha, holes and offsets.
