# Lighting renderer integration

`Max2D.LightingDriver` defines the optional renderer boundary used by
`TMax2DLighting.DrawImage` and `DrawMesh` when `SetLightBatching(True)` is enabled. It depends
only on `Max2D.Core`. Application code continues to use `Max2D.Lighting` and
`Max2D.SceneLighting`; it does not need to construct draw requests or select a
renderer.

This boundary allows a backend to choose its light-group size, shader variants,
parameter storage and texture organization independently of image-effect shader
packages. It does not require one texture per light or impose a three-texture
limit. Providers can use shared atlases or larger light buffers
without changing scene nodes or receiver materials.

## Texture-binding transport

Native providers can submit auxiliary textures through
`TMax2DShaderPackageBackend.SelectTextureSet(context, shader, values, textures, count)`.
The primary image is still supplied by the ordinary image/mesh draw. The first
`count` array entries occupy texture bindings one onward; unused array capacity
is ignored. A provider can retain one array and reuse it without allocating an
array per draw. Native lighting uses a retained four-entry auxiliary array; each
draw supplies only its active prefix (up to five textures including the primary image).

`MaximumTextures(context)` reports a transport upper bound **including the primary
image**, or zero for an unhandled context. Its default is three, preserving the
existing transport. Shader availability and `SupportsShader` remain separate
checks; legacy providers can still reject individual binding combinations.
`SelectTextureSet` validates the count, live context, shader presence and every
active frame before calling the provider: frames must be live, owned by that
context and different from its current render target. Repeated auxiliary frames
are allowed. Validation failure leaves shader selection untouched.

The final validated entry point calls `BindTextureSet`. Its default implementation
forwards zero/one auxiliary textures to `SelectShader`, and two to `SelectTextures`.
Existing provider implementations therefore keep their old hooks. Providers that
extend native texture storage must override both `MaximumTextures` and
`BindTextureSet`, and implement the corresponding native shader/queue bindings.
The active array prefix and parameters are borrowed: copy any state needed by
queued drawing before returning, and never retain the caller's array. Callers may
clear or reuse entries immediately after selection. Restore ordinary rendering
with `ClearShader`, including after submission errors.

OpenGL, SDL GPU, Direct3D 9 and Direct3D 11 now support five total textures
through the counted entry point. Public effect-package schemas
and application materials/scene APIs are unchanged. Native lighting uses a fourth texture for mapped emission, allowing it to join
the light-map atlas in the first group. Independent specular artwork uses a fifth texture where its shader is available,
with retained normal-alpha packing as fallback.

For native packages, `M2D_NATIVE_MATERIAL_ABI` (8) accepts up to five
samplers. The final `samplers - 1` parameter vectors hold auxiliary coverage and
premultiplied flags in `.xy`, in binding order; `.zw` remain caller supplied.
On OpenGL, use `image`, `secondImage`, `thirdImage`, `fourthImage`, and `fifthImage` as sampler
names. Corresponding auxiliary `secondTarget` through `fifthTarget` uniforms
identify render-target orientation. Shader-specific bounds and filtering
parameters precede the mode vectors. Selection requires exactly the shader's
auxiliary count and copies bindings/parameters before returning. Existing package
ABIs retain their layouts. This native ABI is not a new public effect schema.

All active auxiliary textures receive mip-zero, nearest-tap sampling during the
OpenGL draw. As with the existing package wrappers, shaders implement any desired
filtered sampling themselves. Texture filtering and mip limits are restored once
per distinct image, including when auxiliary bindings alias each other or the
primary image. `ClearShader` clears every auxiliary binding from draw state.

SDL GPU copies each draw's active texture pointers beside its parameter snapshot
in the retained command arena. Arena growth and subsequent selections cannot
change earlier draws. This also applies to multi-texture shaders with only one
parameter vector; ordinary single-texture draws keep their compact inline
parameter storage. Texture slots zero through four use SDL GPU's existing shader
binding convention and each image's sampler. Material shaders should explicitly
sample mip zero when required, as the existing lighting wrappers do. Auxiliary
images use the same orientation as ordinary SDL GPU images. `ClearShader` clears
selection for subsequent draws while already queued draws keep their snapshots.

Direct3D 11 binds textures and samplers at slots zero through four, with the
existing mode/parameter constant buffers at `b0`/`b1`. Direct3D 9 uses sampler
registers `s0` through `s4`: mode is `c0`, parameters start at `c1`, and one texture
scale vector per sampler follows at `c(slots + 1)`. Each scale vector contains
logical-to-allocated UV scale in `.xy` and inverse allocated dimensions in `.zw`.
The source filtering/format vector follows those scales at
`c(slots + samplers + 1)`. D3D9 expands coverage artwork to RGBA; D3D11 reports
native coverage through the auxiliary mode vectors. D3D9 auxiliary sampling uses
point filtering without mipmaps; D3D11 retains each image's sampler, with explicit
mip selection in the material shader where required. All five resource slots are
unbound before target transitions. Existing package ABIs retain their register
layouts and binding hooks.

## Independent specular-map negotiation

A renderer can opt in through the final `mappedSpecular` argument of
`TMax2DLightingCapabilities.Create`. `MappedSpecular()` requires `Specular()`;
`SpecularMaps()` continues to mean normal-alpha modulation. Existing providers
keep the default `False` and receive packed normal-alpha material data.

For opted-in providers, `TMax2DLightingDraw.specularMap` and `specularFrame`
reference the original separate artwork. RGBA8888 red or A8 alpha multiplies
specular strength; source coverage and diffuse response stay unchanged. Separate
artwork overrides normal alpha. The map uses the receiver's full logical UVs.
Both normal and specular artwork are borrowed and must be captured by queued
work before `Draw` returns.

The processor first tries independent sampling, including shorter eligible
prefixes. If rejected, it retries with retained CPU-packed normal alpha before
ordinary fallback. Deformed meshes preflight both representations before any
submission. Exceptions from `Draw` propagate without retrying submitted work.
Original map references are restored between groups and cleared after the
receiver, including on failure. Accepted independent groups require no packed
image allocation or CPU pixel copy.

The built-in native renderer uses five-texture shaders for independent specular
artwork. Missing shaders, insufficient texture capacity, or differing normal/gloss
filtering settings select packing. Keeping the packed path for differing filtering
preserves the established behavior: both packed channels use gloss filtering.
A custom normal strength without normal artwork also retains packing, preserving
the scaling of its byte-encoded flat normal.
Application `SetSpecularMap` validation
retains its existing CPU-format, untrimmed and matching-dimension requirements,
so rejected requests remain compatible with the fallback.

## Current implementation

The default native renderer evaluates up to sixteen point/directional
lights with flat, normal-mapped or specular receivers, including hard and filtered
shadows and projected patterns whose maps are at most 512×512 pixels. The first
eligible group also composes ambient and receiver coverage. A dedicated light buffer
holds the group. The existing paired point-light shader is retained as a
compatibility renderer for two flat point lights, including hard/filtered
shadows. Further unsupported cases use ordinary single-light drawing. Batching
remains disabled by default. Native D3D9 retains eight-light groups due to shader
register limits. Other backends try sixteen and fall back to eight if shader
creation is unavailable. Groups of at most eight use the smaller shader.
`SetLightBatchLimit` caps negotiation independently of provider capability.

Mapped emission can join the first native group alongside shadow/pattern maps
when the four-texture shader is supported. Three-texture fallback groups combine
emission only when they need no light maps; otherwise mapped ambient stays separate;
eligible direct lights still use native groups. Uniform emission without a map
can remain in the combined first group. See [material channels](lighting.md#emission-and-separate-specular-maps).

The native implementation reuses the backends' shader transport and image
sampling conventions. Its light-buffer layout is independent of the public
image-effect package schema. Native transport reserves up to 128 float4 slots;
the eight- and sixteen-light material shaders use 67 and 115 respectively, with
four textures (artwork, normal map, shared light-map atlas and emission artwork).
Independent-specular variants add the fifth texture and use 70/118 float4 slots.
Their final four vectors contain auxiliary mode flags; specular bounds/info
precede them. Separate gloss uses red for RGBA8888 and alpha for A8, including
D3D9 expanded coverage storage. The shader samples gloss once per fragment before
the light loop. Groups without independent gloss or mapped emission, and
compatibility providers, retain the 64/112-slot
three-texture variants. Public effect-package ABI versions and
parameter limits are unchanged. Backend shader compilation and target/blend
support remain capability gates.

The atlas is a retained 2048×2048 RGBA image (16 MiB), allocated only when a
group using maps is first drawn. Unchanged maps are reused across receivers;
rebuilt maps update only their own tiles. A full page is reset between groups,
retaining its GPU allocation. Workloads exceeding its capacity can require
repeated copies; inspect the map counters below. Larger shadow maps fall back
to compatible paired or ordinary drawing. Direct patterns accept RGBA8888/A8
images and byte render images; mipmapped, compressed and floating-point direct
patterns use ordinary drawing. Combined shadow/pattern images use the prepared
shadow map dimensions.

See the [grouped-shadow measurements](../benchmarks/results/lighting-grouped-shadows-2026-11-22.md),
[grouped-pattern results](../benchmarks/results/lighting-grouped-patterns-2026-11-22.md)
and [combined-ambient results](../benchmarks/results/lighting-combined-ambient-2026-11-22.md).

## Why the fallback implementations remain

| Path | Active responsibility |
| --- | --- |
| Sixteen-light native shader | Larger eligible groups on supporting contexts. |
| Eight-light native shader | Groups of at most eight, native D3D9 and fallback when the larger shader is unavailable. |
| Paired package renderer | Two eligible flat point lights when the selected renderer declines, including shadow maps larger than the native atlas accepts. |
| Ordinary image-light shaders | Unsupported groups/materials/maps, disabled batching, flattened Update and image-reference comparisons. |

The paired renderer is created on its first fallback attempt and reused until
release or a renderer-context/limit change. It still has narrower capabilities:
no normal/specular materials, directional lights or projected patterns, and
intensity must be at most one. A rejected pair proceeds to ordinary lighting.

These paths are reachable compatibility implementations, not unused prototypes.
Removing one requires identifying every supported case it handles and verifying
the replacement's pixels, alpha, state restoration and capability behaviour.
The ordinary receiver and flattened-output paths also have different composition
and clipping contracts; merging their calculations must preserve those contracts.

## Provider lifecycle

A backend module imports `Max2D.LightingDriver`, implements
`TMax2DLightingBackend`, and registers one factory with
`RegisterMax2DLightingBackend`. Registration takes place during module
initialization, before lighting processors are used. Re-registering the same
factory instance is harmless. Factories are considered in registration order. When no registered factory accepts
the context, the processor tries the built-in native renderer.

`CreateRenderer(context)` returns Null when the factory cannot handle a context.
Otherwise it returns a `TMax2DLightingRenderer` with initialized, immutable
`TMax2DLightingCapabilities`. A processor lazily retains one renderer session
for its current graphics context. Changing context or calling the processor's
`Release()` releases that session; subsequent drawing can recreate it.

Native shaders, pipelines and shared atlases belong to their graphics context.
They must be released when that context closes. Session `Release()` must also
be safe after context closure and on repeated calls. Providers run on the
rendering thread.

Capabilities specify minimum/maximum lights per submission and support for
normal maps, specular response, directional lights, projected patterns and
shadows, and optional ambient composition. Existing providers default to separate
ambient; pass True for the `ambient` capabilities argument to opt in. These are upper bounds, not a guarantee that every combination or
target format is supported. A renderer with tighter hardware limits can expose
smaller groups while the processor continues to handle arbitrary scene counts.

## Negotiation and drawing

1. The processor performs receiver-mask and bounds selection in the existing
   light order.
2. It builds the largest eligible prefix within the renderer's declared limits.
   An unsupported light category ends that prefix; lights are never reordered
   to fill a group.
3. `Supports(canvas, draw)` checks the material, light metadata, logical source
   and target formats, and current drawing state. It may compile resources but
   must not submit geometry or alter pixels/state. The processor retries shorter
   prefixes down to the declared minimum.
4. Only after acceptance does the processor resolve the group's retained light
   masks and projected patterns. `Draw(canvas, draw)` receives those images and
   their transforms and submits exactly one direct-light pass.
5. Rejection tries the compatibility renderer, then the ordinary single-light
   path. An exception from `Draw` propagates: retrying after partial submission
   could apply lighting twice.

Ordinary group requests add direct-light contributions and preserve destination
alpha. An ambient-capable provider may receive `includeAmbient=True` for the
first group only. It must compose ambient colour and receiver coverage over the
destination, then add that group's direct contributions. `ambientRed/Green/Blue`
already include intensity. Ambient remains independent of normals, patterns and
shadows. Match the backend’s ordinary ALPHABLEND behaviour: native Direct3D 11
clamps normalized ambient RGB before applying coverage, whereas the other native
paths preserve overbright ambient through premultiplied composition. HDR targets
retain the full ambient range. Normalized direct contributions clamp individually
before source alpha is applied.

The processor negotiates this first group before drawing ambient. If rejected,
it draws ambient separately and continues ordinary group negotiation. Receivers
with no eligible lights require separate ambient; a single native light composes
ambient in its one pass. A successful first group must not be repeated after
failure. Providers preserve the receiver's tint,
alpha, transform, camera, clipping and painter order, and restore drawing state
and native shader selection on success or failure. Normalized-target clamping
and floating-point output should match the reference path; compare translucent
and additive render-image artwork as well as opaque sprites.

## Borrowed data and allocation

`TMax2DLightingDraw` contains the receiver, its affine mapping into lighting
coordinates, normal/specular material data, logical pixel formats and ordered
light records. Its `count` identifies the active prefix of the retained array.
The affine translation already accounts for the image handle and draw position;
its input origin is the top-left of the source image.

Each `TMax2DLightingDrawLight` supplies position/direction, colour, intensity,
falloff and height. During `Supports`, inspect `hasMap`, `shadowed`, `patterned`, `mapWidth`,
`mapHeight`, `mapFormat` and `mapFlags`; map images have not yet been resolved. During `Draw`, `map` is the
combined shadow/pattern image when required. Its six affine coefficients map
lighting coordinates to normalized map coordinates. Directional shadow maps use
clamped edges; point-light maps use transparent edges.

The processor owns and reuses requests, arrays and records. Providers must not
modify them, keep them, or retain their arrays for deferred processing. Capture
all required values and native image resources before `Draw` returns. Image
references in the request are cleared after drawing or failure. Capacity grows
only when a larger group is encountered and is retained for reuse.

## Caching resolved light maps

During `Draw`, each resolved map supplies `mapKey` and `mapRevision` alongside
`map` and `mapFrame`. Compare all four when caching pixels. `mapKey` is an opaque
identity that may be retained in a cache entry; never retain the borrowed light
record itself. The request clears both image and identity references after
submission, including error recovery.

A projected pattern keeps its pixel revision when its placement changes.
`TMax2DLightTexture.Invalidate()` advances that revision after application pixel
edits, and replacing its image or frame also advances it. Shadow maps advance
when rebuilt; repeated receivers using an unchanged shadow retain the same
identity and revision. Continue reading the affine transform and `mapClamp`
from each draw because they describe sampling, independently of cached pixels.

`lightingnative.mod/atlas.bmx` contains the internal retained page implementation.
A page reserves tile records up front and copies only new or changed maps. It
uses normalized RGBA storage and restores drawing state after a copy. Direct
byte patterns retain straight RGB and alpha; render-image maps retain
premultiplied RGB. Each tile records this representation. The native shader
filters the stored values first, then multiplies straight RGB by filtered alpha.
Premultiplying CPU patterns during upload would change their filtered edges.
Direct mipmapped patterns are excluded from this renderer. Full pages return no tile without evicting existing entries; a
renderer must choose another page or divide its group before submission.
Pages keep strong references to cached maps until released, so their lifetime
should follow the renderer session. They are implementation details, not an
application-level atlas API.

Tiles have no padding. Any shader consuming them must clamp **each texel fetch**
to the tile rectangle, including both neighbours in bilinear filtering. Applying
the page's ordinary filtering directly would leak neighbouring maps. Transparent
outside-map sampling and directional edge clamping must be applied in the
original map coordinates before translating into atlas coordinates.

## Diagnostics and validation

- `LightPasses()` counts completed direct-light passes.
- `LightContributions()` counts the lights applied, regardless of group size.
- `GroupedPasses()` counts submissions through a grouped renderer.
- `PairedPasses()` counts the subset that applies exactly two lights.
- `MapUploads()` counts completed copies into renderer map storage.
- `MapCacheHits()` counts unchanged map lookups served from that storage.
- `RetainedMapBytes()` reports current renderer map texture storage, separately
  from `RetainedShadowBytes()`.

Providers expose monotonic session counters through `MapUploads()` and
`MapCacheHits()`, and current storage through `MapStorageBytes()`. Defaults are
zero. The processor accumulates counter differences around each `Draw`, including
partial copy work if a submission fails; `ResetStats()` does not clear caches.

Use `LightContributions()` rather than deriving contributions from the paired
counter when writing tools that should accommodate larger groups.

The lighting regression suite compares the compatibility renderer's actual
images with ordinary drawing, including shadows, transformed and translucent
artwork, HDR output and material fallback. Provider-contract checks also cover
ordered-prefix negotiation, rejected groups, invalid capabilities, injected
submission failure, borrowed-reference cleanup and session release/recreation.

The [sixteen-light validation report](../benchmarks/results/lighting-sixteen-lights-2026-11-22.md)
records 641 checks across six native configurations. The subsequent diagnostics
extension passes 710 checks on macOS Metal/OpenGL, including prefix rejection,
exception accounting and detached statistics snapshots. These are distinct
validation snapshots, not a claim that the latest suite ran on every backend.
The current benchmark covers 60 workloads per mode; see the
[benchmark guide](../benchmarks/README.md) for its columns and interpretation.

## Building native shader assets

Applications use the checked-in assets; no runtime shader compiler is needed
for the Direct3D backends. Maintainers can build
`lightingnative.mod/shaders/generate.bmx` with BlitzMax and run:

```sh
lighting-shaders generate /path/to/max2d.mod /path/to/output
# Compile lightgroup.frag to SPIR-V and the three HLSL files to their matching
# SDL DXBC, native D3D11 ps_4_0 and native D3D9 ps_3_0 assets.
# Compile lightgroup16.frag and its SDL/native D3D11 HLSL variants likewise.
# Repeat for lightmaterial and lightmaterial16 (four-texture emission variants).
# Repeat for lightspecular and lightspecular16 (five-texture specular variants).
# Sixteen-light groups have no D3D9 variant.
lighting-shaders embed /path/to/output
```

The generator reuses the established textured-light image-sampling wrappers and
provides the dedicated grouped-light calculation as a multiline template.
`tests/native_lighting_shaders.bmx` reproduces all source and embedded assets.
The native binding tag is internal; it is not a new public manifest ABI.

### Packed gloss materials

`TMax2DLightingCapabilities.Create` accepts an optional `specularMaps` flag,
default False. Providers advertising it must multiply specular strength by normal
map alpha when `draw.specularFromNormalAlpha` is True. This must leave diffuse,
ambient and receiver coverage unchanged. The native renderer supports this using
its existing normal sampler; custom providers without the flag fall back normally.

### Emissive receivers

Source-coloured material emission is folded into the ambient coefficients supplied
to `TMax2DLightingDraw`. An `AmbientComposition` provider applies those coefficients
unchanged, including values above one on floating-point targets. No new provider
flag or shader parameter is required. Providers without ambient composition keep
the ordinary base pass, which includes emission once before direct lighting.

## Mesh geometry capability

`TMax2DLightingCapabilities.Create` accepts an optional `meshes` flag,
exposed through `MeshGeometry()`. It defaults to false, so existing providers
continue to receive image geometry only. The processor checks this flag before
calling `Supports` for a mesh request. The native provider advertises support;
the paired compatibility provider does not and uses ordinary fallback for meshes.

`TMax2DLightingDraw.mesh` is null for image draws. Otherwise draw the borrowed
textured geometry at request `x/y` using the current drawing state and handle,
ignoring the image handle. Source UVs follow the normal full-image/atlas contract.
The supplied affine basis maps source pixel coordinates into lighting coordinates;
it already incorporates the triangle's geometry, draw position and drawing handle.
Do not apply them to the lighting basis a second time. These rules apply when
`deformed=False`, where each request uses one affine UV mapping.

The optional `affineMeshes` flag defaults to false and requires `meshes`.
`AffineMeshGeometry()` providers may receive multiple non-overlapping triangles
sharing that mapping; they must draw every supplied index. A request can represent
a consecutive section of a larger deformed mesh. Sections arrive in index order
and may overlap previous sections; the non-overlap guarantee applies within each
request, not across requests. Affine sections use the same shader calculations
as individual triangles. Existing mesh providers
still receive exactly one triangle per request. The processor checks both
capabilities before `Supports`; compatibility renderers never receive a whole
mesh merely because they support individual triangles. Application code keeps
using `DrawMesh` and `SetLightBatching(True)`.

The final optional `deformedMeshes` flag also defaults to false and requires
`affineMeshes`. With `DeformedMeshGeometry()` enabled, `draw.deformed=True` means
`xx/xy/yx/yy/tx/ty` map **mesh-local geometry plus x/y minus the drawing handle**
into lighting coordinates. They are not a source-pixel basis in this mode. Each
triangle may have an independent UV mapping; geometric interiors remain disjoint.
The provider must use each triangle's UV-to-lighting normal basis. Ordinary
artwork sampling, tint, alpha, clipping and drawing transforms still apply.

The native implementation reconstructs lighting position from framebuffer pixel
coordinates. It computes the normal basis from UV gradients and the
screen-to-lighting linear transform, avoiding derivatives of large world-position
values. Screen transforms include drawing state, parent coordinates, camera and
virtual presentation. Singular drawing transforms and texture gradients too small or ill-conditioned
for reliable fragment precision are rejected before drawing. The gradient check
includes source-atlas scale; those cases retain the uniform-basis path.
Degenerate fragment gradients use the existing viewer-facing normal fallback.

The processor preflights **all** selected groups before any deformed receiver
passes. This includes whether ambient can join the first group. Rejection returns
to the ordered section/triangle path. Actual submission rechecks the planned group
sizes: if support changes after preflight, it throws rather than redrawing over
partially submitted pixels. Genuine draw failures have the same rule. `Supports`
therefore runs more often for deformed requests; it must not draw or retain the
borrowed request. Diagnostic support-check counters include these preflight calls.

Providers must consume or copy mesh arrays before returning. The processor reuses
its triangle scratch storage immediately, and `ClearImages` clears the mesh
reference along with borrowed images. Mesh requests preserve the same ambient,
coverage, normals, specular and map contracts as image requests. Rejection before
submission selects ordinary fallback; draw failures propagate without redrawing.

See [grouped mesh validation](scene/validation/2026-11-23-grouped-mesh.md) for
pixel comparisons, group-boundary counts and legacy-provider compatibility.
The subsequent [affine mesh validation](scene/benchmarks/2026-11-23-affine-mesh.md)
covers whole-mesh grouping and triangle-only provider compatibility.
[Section validation](scene/validation/2026-11-23-mesh-sections.md) extends this
to deformed meshes with several consecutive affine sections. The later
[general deformation report](scene/benchmarks/2026-11-23-deformed-mesh.md) covers
independent mappings, complete receiver bounds and preflight/failure behavior.

## Mapped materials

Separate specular artwork is resolved to retained normal/gloss storage after
light selection, before provider negotiation. Ambient-only receivers skip this
work. The resolved image/frame and gloss mode are reused for negotiation and
compatibility drawing within that receiver call. Providers continue to use `normalMap` and
`specularFromNormalAlpha`; existing capability and fallback rules apply.
`MappedEmission()` opts into independent emission sampling during ambient
composition and defaults to False. It requires `AmbientComposition()`.
When `includeAmbient` and `emissionMap` are set, the provider adds
`sourceRGB * emissionRGB * emissionIntensity * mapRGB * mapAlpha` to ambient.
The map covers the full logical receiver rectangle, independent of map dimensions;
atlas, trimmed byte, A8 and premultiplied render-image sampling follow ordinary
image-effect conventions. Emission never changes coverage or direct lighting.
Direct-only groups ignore all emission fields. `ClearImages()` drops the borrowed
emission image alongside other receiver references.

The native renderer prefers a fourth sampler for emission, so the accepted group
can also sample the shared light-map atlas. If the adapter reports fewer than four
textures or the material shader is unavailable, it retains the three-texture
variant, using the third sampler for emission when no light maps are required.
It may shorten the first group to a compatible prefix. If no
prefix can compose emission, the processor draws mapped ambient separately, then
submits direct groups without emission. General deformed meshes preflight this
choice before any drawing. Existing providers retain the separate pass without
changes. Uniform emission continues to be included in ambient coefficients.
Floating-point emission artwork on a normalized target is rejected for combined
ambient, preserving the separate-pass clamp before direct light when map RGB is
negative. Floating-point destinations retain linear accumulation.
No extra texture is allocated for native emission; trimmed images may use the
ordinary retained full-size sampling image. Separate specular maps still use CPU
packing. Combined emission/light-map groups save one receiver submission compared
with a separate mapped ambient pass, without changing the light-group limit.
