# SDL3 Renderer MASKBLEND

`Max2D.SDL3RenderMax2D` now supports exact alpha-test masking when the active
SDL renderer can use the bundled shader. The first implementation uses **SDL's
GPU renderer with Metal/MSL**. It is tested on macOS arm64. SDL's separate
`metal`, OpenGL and software renderers still report masking as unsupported.
GPU devices requiring SPIR-V or DXIL also report unsupported: those shader
variants are not bundled yet. Merely selecting `gpu` is not a support guarantee.

## Selecting and checking

```blitzmax
SuperStrict
Framework Max2D.SDL3RenderMax2D

If Not SetSDLRenderMax2DRenderer("gpu") Then
    Throw "SDL renderer selection was overridden"
End If
Graphics 640,480

If Not Max2DSupportsBlend(MASKBLEND) Then
    Throw "This renderer cannot provide MASKBLEND"
End If
SetBlend(MASKBLEND)
```

`SetSDLRenderMax2DRenderer` sets SDL's renderer hint for **future windows**,
including other SDL windows created in the process. It does not change existing
contexts. An `SDL_RENDER_DRIVER` environment override takes priority. A failed
hint change returns False; requesting an unavailable renderer can cause graphics
creation to fail. Pass an empty string to restore SDL's automatic choice (subject
to environment overrides). `SDLRenderMax2DRendererName()` reports the active SDL
implementation, such as `gpu`, `metal` or `software`.

Capability is per context, and is enabled only after shader, render-state and
helper-texture creation succeeds. Shader initialization failure leaves ordinary
rendering available. For diagnostics, the SDL context's `maskUnavailableReason`
records the initialization error. Unsupported `MASKBLEND` requests remain errors;
the backend never silently substitutes alpha blending.

## Behaviour

The fragment shader samples with the image's requested filtering, applies drawing
colour/alpha, discards alpha below 0.5, and overwrites surviving pixels with
blending disabled. Surviving alpha is retained rather than forced to one.
This follows the alpha-test rule used by the Max2D OpenGL backend.

Image views, animated atlas frames, dynamic edits and primitives use the same
path. Render-target sources are unpremultiplied after sampling; target destinations
receive premultiplied output. Mask draws do not require a readback or a second
masked texture. Four immutable shader states cover source/destination alpha
representations and preserve queued drawing order. Ordinary draws and internal
conversions continue using SDL's shaders. Resources belong to each context and
are released before its renderer closes.

This does not add mipmap support to SDL3 Renderer, and does not create a separate
SDL GPU Max2D module. A future direct GPU backend remains a separate option.

## Examples and validation

- `examples/maskblend.bmx`: side-by-side alpha blending and alpha testing.
- `examples/oldskool2.bmx`: build with `-ud max2d_sdl_gpu` to request GPU rendering;
  add `sample_test` for the silent 700-frame run. The existing fallback is retained
  for implementations without masking.
- `tests/sdl_maskblend.bmx`: default run requires GPU masking. A console run with
  `--software` checks capability rejection; use `SDL_VIDEODRIVER=dummy` headlessly.

The GPU test covers alpha 127/128, drawing-alpha modulation, exact half-alpha
primitives, filtered edges, dynamic uploads, filtered animation atlas frames,
render-target alpha/colour, ordinary drawing after masking, and context teardown.
Release and debug tests passed on macOS arm64 for GPU/Metal and software
capability rejection. Capturing Oldskool2 also exercises many interleaved masked and ordinary batches.
These checks validate the Metal combination here; Windows/Linux GPU shader
formats still require implementation and platform validation.
