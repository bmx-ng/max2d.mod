# Reusable bloom

`TMax2DBloom` owns bright-pass extraction, scaled blur, glow gain and composition.
It builds on `TMax2DEffectBuffers` and uses either optional effect provider: `Max2D.SDL3GPUEffects` or
`Max2D.GLEffects`. OpenGL supports float bloom and SDR tone-mapped presentation;
HDR window presentation remains separate.

```blitzmax
Local bloom:TMax2DBloom = CreateBloom(1.5, 12, 1)
bloom.Prepare(640, 360, 2, PF_RGBA16F)

' When scene pixels or bloom settings change:
Local result:TRenderImage = bloom.Update(scene)

' Reuse on subsequent frames without rebuilding:
DrawImageEffect(bloom.Result(), outputEffect, 0, 0)
```

Keep the descriptor and buffers across frames. `Prepare` materializes the images;
shader pipelines may still need warming. Query bright-pass, blur and linear-output
effect support and the desired render-image format on the active backend.

## Controls

| Setting | Meaning |
| --- | --- |
| Threshold | Finite, nonnegative bright-pass threshold in source colour units. |
| Radius | Finite, nonnegative blur radius in full-resolution source pixels. |
| Intensity | Finite, nonnegative glow multiplier: 0 suppresses glow, 1 preserves it, values above 1 amplify it. |

Use `SetThreshold`, `SetRadius`, `SetIntensity` and their matching getters.
Settings affect the next `Update`; they do not change the previous cached result.
Radius must fit a four-pixel kernel at the prepared reduction resolution.
`Prepare` and `Update` reject an insufficient pyramid before changing the result.
Zero radius still resamples when reduction levels are present.

## Output and colour

The source is composited over **opaque black**, then glow is added. The result is
opaque, so halos remain visible outside the source's original alpha coverage.
For a scene with a different background, compose that background into the source
before applying bloom. This API does not return a transparent glow-only layer;
use the lower-level bright-pass and blur operations for that purpose.

Use linear source colours and floating-point buffers for HDR. RGBA16F is the
default; there is no automatic downgrade when unsupported. RGBA8888 is an explicit
LDR option and clips output above its range. Source dimensions must match the
prepared layout, and the source cannot be the cached result. Source pixels are
preserved, including alpha. The output is not tone mapped and the class does not
change the window's HDR mode. Present through `TMax2DLinearOutputEffect` as shown
in [HDR output and colour handling](hdr-output.md).

Source handles, camera, transforms, tint and viewport do not affect the operation.
The caller's drawing state and target views are restored. Pad source content when
halos should extend beyond its current bounds; bloom is bounded by the images.

## Cache and lifetime

- `Update(source)` always rebuilds. No source-version tracking is performed.
- `Result()` performs no rendering and returns borrowed storage. It throws before
  a successful update, after a changed layout, after release, or on the wrong or
  closed context.
- Identical `Prepare` calls preserve pixels and the cached result. A changed
  layout replaces storage and requires another update.
- Preflight validation failures preserve the previous result. A later rendering
  failure marks it unavailable; call `Update` successfully before reading it again.
- `Release()` frees the owned layout using normal deferred frame cleanup and
  retains settings. Do not release while its result is the active render target.
- Borrowed results must not outlive resize, release or context closure. The buffer
  owner's [context and resize rules](effect-buffers.md) also apply here.

## Cost

For `L` reduction levels, preparation creates `L+4` textures: three full-size
images, `L` reduced images and one smallest-level scratch image.

An update uses extraction, blur, opaque fill, source composition and glow addition:

- No reductions: 6 draws.
- `L > 0`: `L+7` draws; two levels use **9 draws**.
- Retrieving `Result`: **0 draws**; presenting it normally adds one.

After warming, updates create no images, arrays, effect descriptions or textures
and perform no uploads or readbacks. The underlying helpers allocate drawing-state
scopes. Rebuild only when scene content or bloom settings change; output exposure
and HDR/SDR changes need only a new presentation draw.

`examples/hdr_scene.bmx` uses this API. H changes HDR/SDR, Space toggles bloom,
I cycles intensity, left/right changes threshold and up/down changes exposure.

## Validation

`tests/bloom_pipeline.bmx` checks opaque composition from a partially transparent
HDR source, halos outside source coverage, zero and amplified intensity, cached
result behaviour, invalid radius recovery, resize invalidation, context lifetime,
both sprite submission paths and nine-draw steady-state cost. Software rendering
verifies rejection of unsupported shaders and restoration of the original target.

Validated on macOS Metal and Windows/Ubuntu Vulkan, with software rejection also
passing. The wider Metal run passed all 13 effects suites. An additional Metal
window readback check verifies pixels drawn before and after repeated updates,
including restoration of the window target, origin and tint. The GUI demo was
also checked with intensity changes and HDR/SDR switching.
