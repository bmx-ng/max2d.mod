# Reusable soft shadows

`TMax2DShadow` caches a blurred white silhouette of a render image's alpha.
Source RGB is ignored, and the result remains transparent around the silhouette.
Import `Max2D.SDL3GPUEffects` with the native SDL GPU backend.

```blitzmax
Local shadow:TMax2DShadow = CreateShadow(12)
shadow.Prepare(scene.width, scene.height, 2)
shadow.Update(scene)

' Draw the cached shadow, then the source:
SetBlend(ALPHABLEND)
SetColor(0, 0, 0)
SetAlpha(0.6)
DrawImage(shadow.Result(), x+12, y+12)
SetColor(255, 255, 255)
SetAlpha(1)
DrawImage(scene, x, y)
```

Colour, opacity and offset are ordinary drawing settings. They need no shadow
rebuild. The result's default handle is zero; account for any custom source
handle when aligning it. The result includes the silhouette beneath the source,
so translucent source areas show the shadow underneath them.

## Preparation and updates

- `CreateShadow(radius=8)` creates a reusable description without GPU resources.
- `Prepare(width, height, reductionLevels=2, pixelFormat=PF_RGBA8888)` owns two
  full-size images, a ceil-halved pyramid and smallest-level blur scratch.
- `SetRadius` accepts finite nonnegative source-pixel radii. `GetRadius` returns it.
  The radius must fit four pixels at the smallest prepared level in both axes.
- `Update(source)` always rebuilds from source alpha and returns borrowed storage.
  Source dimensions must match; the cached result cannot be its own source.
- `Result()` returns that storage with no drawing. Changed settings keep the old
  result until another successful update.
- `Release()` drops owned frames through normal deferred cleanup and keeps radius.

Identical preparation retains the cached result. A changed layout invalidates it.
Result retrieval requires a successful update and the correct open context.
The [effect-buffer ownership rules](effect-buffers.md) apply, including rejecting
release while the result is selected and invalidating borrowed references on
resize, release or context closure.

The caller's drawing state and target views are restored, and source pixels are
preserved. Extraction ignores source handles, camera, transform, tint and viewport.
Input/radius/shader preflight failures preserve the old result; a later runtime
failure makes it unavailable until a successful update.

## Bounds and quality

Pad the source with transparent pixels to hold the halo. Result dimensions are
unchanged; no automatic expansion or placement offset is baked into the image.
Reduction adds bilinear filtering, and odd dimensions are approximate. Zero
radius still resamples when reduction levels are present; use zero levels for
an exact silhouette. RGBA8 quantizes faint alpha. Choose a supported floating-point
format when finer precision is needed. Colourization removes source colour before
blur, so coloured artwork does not tint the shadow.

Query colourize, blur and render-image support before use. Unsupported shader
backends throw; no CPU fallback is introduced. No new shaders are required.

## Cost

For `L` reduction levels, preparation creates `L+3` textures. Updating costs one
silhouette pass plus scaled blur:

- Zero levels: **3 draws**.
- `L > 0`: **L+4 draws**; two levels use **6 draws**.
- Cached shadow presentation: **one ordinary image draw**.

Warmed updates allocate no images, arrays, descriptions or textures and perform
no uploads/readbacks. Helpers allocate drawing-state scopes. Rebuild when source
alpha or radius changes. Ordinary drawing pays no shadow overhead when unused.

See `examples/shadow_pipeline.bmx` for live radius, opacity, colour and offset
controls. `tests/shadow_pipeline.bmx` checks an independent two-dimensional kernel,
source preservation, tintable output, cached lifetime and submission costs.

## Validation

The regression passes on macOS Metal and Windows/Ubuntu Vulkan, including both
sprite submission paths and two context lifetimes. It compares floating-point
alpha against the independent binomial-kernel product, checks white RGB around
partially transparent coloured input, verifies source preservation and cache
invalidation, and checks the three/six-draw costs without texture churn. Software
rendering passes the unsupported-provider rejection and target-restoration check.
The macOS GUI example was built as an app and visually inspected with live radius
and offset changes. Direct3D runtime validation remains outstanding.
