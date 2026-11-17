# Effects and group masking

`Max2D.Effects` is optional. Import it only in applications that use layer
compositing. The first slice provides two operations on a caller-owned
`TRenderImage`: `ApplyLayerAlphaMask(mask)` and `ApplyLayerOpacity(opacity)`.
Both multiply stored RGB and alpha, so a transparent layer remains in Max2D's
premultiplied format. They use one ordinary draw over the layer bounds, without
readback, new allocation or a shader package. Query `Max2DSupportsLayerAlpha()`
and `Max2DSupportsRenderImage(width, height, flags)` after opening graphics.
Unsupported capabilities are reported and the operation throws rather than
silently using a CPU fallback.

```blitzmax
Import Max2D.Effects

If Max2DSupportsRenderImage(240, 160, 0) And Max2DSupportsLayerAlpha() Then
	Local group:TRenderImage = CreateRenderImage(240, 160, 0)
	' mask is a distinct 240x160 image with alpha at every pixel.
	SetRenderImage(group)
	SetClsColor(0, 0, 0, 0)
	Cls
	DrawImage(sprite, 20, 20)
	ApplyLayerAlphaMask(mask)
	SetRenderImage(Null)
	DrawImage(group, 100, 100)
End If
```

Create and retain the group and mask images across frames. Generate or redraw
the mask only when it changes. `ApplyLayerAlphaMask` samples the mask's alpha;
its RGB is irrelevant. It requires the mask and layer to have equal dimensions
and rejects sampling the same render image being written. The helper ignores
the current camera, transforms, image handle and viewport while it composites,
then restores drawing state and the current target. The layer's pixels outside
the mask become transparent only if those mask pixels have zero alpha.
`ApplyLayerOpacity` also costs a pass; use `SetAlpha` on a single draw instead.

For nested groups, composite an inner render image into an outer one, then
apply the outer mask. This exposes target switches and memory cost to the caller.
The example [layer_effects.bmx](../examples/layer_effects.bmx) shows both a
soft group mask and nested rectangular clipping. For a hard screen-aligned
rectangle, use `ScopedMax2DState` and `IntersectViewport`; nested intersections
use the backend scissor and allocate no intermediate image. Viewport coordinates
are virtual screen coordinates and do not move with cameras or object transforms.
For a camera-moving shape, draw that shape into a coverage image under the same
camera, then mask a group layer. `MASKBLEND` only thresholds the source alpha of
individual draws; it does not clip a group.

## Architecture for shader effects

The layer operation above exercises the target and compositing contract. The
next shader slice should keep two explicit categories:

* **Direct draw effects** change a draw's sampling or colour without needing the
  destination. A selected immutable effect snapshot joins texture, blend, clip
  and target in the batch key. Changing effect or parameter values ends the
  pending batch. Queued draws retain their submitted snapshot even if the
  caller changes a parameter object later. A parameter object is reusable; one
  fixed-size native uniform upload per changed batch is preferable to per-draw
  allocations. Ordinary drawing continues through its current pipeline.
* **Layer effects** sample a previously rendered group. They declare input
  textures, output format, sampling radius/padding and bounds. They require an
  explicit render-image target or an opt-in scoped group API. A radius-zero
  colour effect can cover just the group's bounds; a blur expands by its sample
  radius. Rendering a full window when the group occupies a small rectangle
  would waste bandwidth. An effect chain can ping-pong between two compatible
  scratch targets owned by the graphics context. A source may never be the
  active destination in the same pass.

An effect description should contain a stable name, typed parameter layout,
declared texture slots, colour convention, bounds/padding and a package version.
Create effect instances once, then update typed values between draws. Built-in
and third-party shader packages should use the same backend registration
contract. The package should carry precompiled SPIR-V for Vulkan, Metal source
or metallib for Metal, and appropriate Direct3D bytecode, plus GLSL 1.20 for
the desktop OpenGL baseline. This matches the current SDL GPU shader-source
layout but needs a versioned binding manifest and reflection/validation at
registration. A package is supported only when its exact format and resource
limits fit the active context. Direct3D 9 needs a separate shader profile and
Direct3D 11 a separate device implementation. `SDL3RenderMax2D` has no general
shader hook; it must report custom shader effects unsupported. The SDL renderer
named `gpu` is still SDL_Renderer and does not make it the native SDL GPU
backend. Fixed-function operations such as this alpha multiplication can be
supported where the selected SDL renderer exposes the exact blend equation.

Texture slots should be explicit rather than implicit global image bindings.
The package must declare whether a slot expects a straight-alpha image,
premultiplied render image, coverage map or other data. Rendering a layer into
RGBA starts premultiplied; a shader's output to that layer must preserve the
same convention. Normal maps and light maps can later use typed data slots
without changing sprite texture semantics. The resource owner is the current
`TMax2DContext`; pipelines, parameter buffers and scratch targets are released
on context close or device loss. Shader package descriptions may outlive a
context, but native objects cannot. Capability checks must be repeated after
changing backend or recreating graphics.

## Cost and validation plan

The default draw path needs zero effect lookups, passes, copies or allocations
when no effect is selected. A rectangular clip changes scissor state and can
split a batch; this is cheaper than a layer. Each alpha-mask or opacity call
adds one target draw and can cause a target switch. Reuse caller-owned layers
and masks; future scratch pooling should key by width, height, format, flags
and context, with a bounded memory budget. Avoid GPU readbacks and CPU/GPU
fences in normal effect use. Readback is appropriate only in tests or capture.

The current `layer_effects` regression establishes a small no-effect baseline:
100 same-state rectangles submit as one batch. The alpha mask and opacity
operations each submit one additional batch and perform no readback on macOS
SDL GPU, OpenGL and the default SDL renderer. The warmed opacity operation
creates no texture and uploads no pixels. These counters do not measure render
passes, target switches or GPU time. Before adding a shader pipeline, compare
representative scenes with no effect, a rectangular clip and a masked layer
using the existing `benchmarks/renderer.bmx` and GPU comparison harness.
Native GPU profiling should additionally record render passes, uniform uploads,
temporary bytes and CPU/GPU frame time at several group sizes. The regression
also checks compositing pixels and state restoration where the backend supports
the exact operation.
