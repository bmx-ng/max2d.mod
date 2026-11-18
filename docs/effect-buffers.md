# Reusable effect buffers

`TMax2DEffectBuffers` in `Max2D.Effects` owns a configurable set of render images
and optional scaled-blur storage. Prepare it at startup or on resize, retain it,
and reuse its images when scene content changes. It adds no global pool, hidden
result caching or automatic allocations to ordinary drawing.

## Effect chains

```blitzmax
Local buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
buffers.Prepare(640, 360) ' Two full-size images, no blur storage.
Local chain:TMax2DImageEffect[] = [TMax2DImageEffect(CreateSaturationEffect(0.5)), TMax2DImageEffect(CreateColorizeEffect(120, 180, 255))]
Local result:TRenderImage = buffers.ApplyChain(source, 0, chain)
DrawImage(result, 0, 0)
```

`ApplyChain` takes a destination index and optional scratch index (default 1).
A chain with two or more effects needs a distinct full-size scratch image. A
single effect or empty chain does not use the scratch index. Sources must not
alias the output or the scratch used for that operation. Use additional indexed
images if several intermediate results must coexist.

## Scaled blur and bloom

```blitzmax
' Three full-size images, two reduced levels, one smallest-level scratch image.
buffers.Prepare(640, 360, 3, 2, PF_RGBA16F)
Local extraction:TMax2DImageEffect[] = [TMax2DImageEffect(CreateBrightPassEffect(1.5))]
Local blur:TMax2DScaledBlur = CreateScaledBlur(12)
Local highlights:TRenderImage = buffers.ApplyChain(source, 0, extraction)
Local glow:TRenderImage = buffers.ApplyBlur(highlights, 1, blur)
Local composite:TRenderImage = buffers.Image(2)
```

Each reduction halves both dimensions, rounded up. The blur radius must fit the
prepared pyramid just as with manual `TMax2DScaledBlur.Apply` calls. All owned
images are filtered, with no mipmaps. The format is explicit; use a supported
floating-point format to preserve HDR energy. Buffer preparation does not check
shader support, so also query the effects you plan to use.

The arguments to `Prepare` are width, height, full-size image count, reduction
level count and pixel format. A reduction count of **-1** (the default) omits all
blur storage; **0** adds a full-size blur scratch; positive counts add the pyramid
and a scratch matching its smallest level. The full-size count must be at least
one. Reductions cannot continue after reaching 1×1.

[TMax2DBloom](bloom.md) uses this owner for its highlights, glow, composite,
reduction levels and blur scratch, and is demonstrated in `examples/hdr_scene.bmx`.
The original low-level APIs remain available.

## Ownership, resizing and release

- `Prepare` materializes native textures immediately. Repeating an identical
  layout on the same context is a no-op and preserves images and their pixels.
- A changed layout builds a replacement before releasing the previous images.
  Invalid parameters, unsupported formats and allocation failures leave the old
  set intact. Resizing does not preserve its contents.
- `Image(index)` and operation results are **borrowed images**. Reacquire them
  after reconfiguration. Do not independently release or modify their storage,
  or retain them in saved drawing-state scopes across reconfiguration.
- Release or resize is rejected while an owned image is the owner's active render
  target. Select the window or a separate image first. An unchanged `Prepare`
  remains a no-op even when an owned image is selected.
- A set belongs to one graphics context. Access and operations require that
  context to be current and open. To move between live contexts, call `Release`
  first. After the old context closes, `Prepare` can create a fresh set on a new
  context; it never reuses the old render images.
- `Release()` queues native cleanup and resets the owner. Repeated release and
  release after context closure are safe. Normal context cleanup drains queued
  frames. Drop borrowed references as well when finished.

Preparation does not select a target or change drawing state. Chain and blur
operations use their existing state-preserving helpers; they allocate state
scopes, but no render images or per-pass arrays. Shader pipelines can still be
created on first use, so warm the intended effects before measuring.

## Allocation and draw costs

With `N` full-size images and `L` nonnegative blur levels, preparation creates
`N + L + 1` textures. A chain-only layout creates `N`. Identical preparation creates
zero. A blur with no reduction levels uses two draws; with `L > 0`, it uses `L+3`.
A nonempty chain uses one draw per effect; an empty chain uses one copy draw.

`tests/effect_buffers.bmx` checks eager allocation counts, image/pixel retention,
invalid-layout recovery, selected-target guards, odd-size blur parity against
manual buffers, warm draw counts without texture churn, resize cleanup, live
context rejection and recreation after context closure. Software and OpenGL can
use the buffer owner even where optional shader effects are unavailable.

Validation on 2026-11-18 passed on macOS Metal, OpenGL and software rendering,
plus Windows 11 and Ubuntu Vulkan VMs. The HDR scene was also built as a macOS
GUI application and visually checked while rebuilding bloom with the retained
buffers. The Windows temporary validation task was removed after the run.
