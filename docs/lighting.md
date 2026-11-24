# Lighting

Max2D provides optional ambient and coloured point/directional illumination through
`Max2D.Lighting`. `Max2D.SceneLighting` adds scene light nodes, shared receiver
materials and individually lit sprites. Import the matching effects provider:
`Max2D.SDL3GPUEffects`, `Max2D.GLEffects`, `Max2D.D3D9Effects` or
`Max2D.D3D11Effects`.

The SDL renderer does not implement this shader path. Unsupported configurations
throw; they do not silently draw unlit artwork.

## Start with a scene

Use one lighting environment per layer. Register its lights, then call
`Prepare` after movement and material edits and before each render. This resolves
light positions and directions and updates cached receiver dependencies without creating
per-frame light arrays, matrices or textures.

```blitzmax
Import Max2D.SceneLighting

Local scene:TScene = TScene.Create()
Local world:TLayerNode = TLayerNode.Create()
Local hud:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(world)
scene.Root().AddChild(hud)

Local lighting:TSceneLighting = TSceneLighting.Create(world)
lighting.SetAmbient(160,180,220,0.15)

Local lamp:TPointLightNode = TPointLightNode.Create(240)
lamp.SetPosition(320,200)
lamp.SetColor(255,170,80)
lamp.SetIntensity(2)
lamp.SetFalloff(2)
world.AddChild(lamp)
lighting.SetLights([lamp])

' artwork is a caller-owned TImage loaded by the application.
Local sprite:TLitSpriteNode = TLitSpriteNode.Create(artwork,lighting)
sprite.SetPosition(200,150)
world.AddChild(sprite)

' Ordinary sprites/text remain unlit, including this HUD.
hud.AddChild(TTextNode.Create("ENERGY 100",font))

' Each frame, after movement and scene.Update if used:
lighting.Prepare()
Cls
scene.Render()
Flip
```

The complete [Light Lab](../demos/light_lab/README.md) example includes image
creation, fonts, input, teardown and selectable receiver materials.

### Coordinates and cameras

A point light's centre follows its node and parent transforms. Its radius is in
**layer-world units**: node scale and rotation do not change the circular
footprint. Camera transforms move lights and receivers together on screen.
Receiver images retain their affine world placement, including rotation,
reflection and nonuniform scale, independently of the drawing camera.

Place registered lights and receivers beneath the environment's layer. A light
that is detached from a scene contributes nothing; attaching it beneath another
layer is rejected by `Prepare`. Use `SetEnabled` to switch a light off. The
light's enabled state and colour are independent of inherited visual visibility
and tint; hiding a decorative marker does not disable its light.

Call `Prepare` even if there was no scene update. For several environments,
prepare each before rendering the scene. This explicit synchronization boundary
also suits ECS applications: copy component state into the light nodes, prepare,
then render. Do not modify light lists, environment settings or shared materials
inside drawing callbacks.

## Directional lights

Use a directional light for sunlight or another source arriving from a constant
angle across the layer. Point and directional nodes share `TLightNode2D` colour,
intensity, receiver mask and enabled settings:

```blitzmax
Local sun:TDirectionalLightNode = TDirectionalLightNode.Create(-1,-1,1)
sun.SetColor(255,235,200)
sun.SetIntensity(0.8)
sun.SetReceiverMask(1)
world.AddChild(sun)
lighting.SetLights([TLightNode2D(lamp),sun])
```

The finite, nonzero vector points **from the surface toward the source**:
positive X is right, positive Y down and positive Z toward the viewer.
`SetDirection(x,y,z)` changes it; `GetDirection(x,y,z)` copies the authored
components into caller variables. The node and parent linear transforms affect
XY, while Z remains unchanged; the result is normalized. Rotation, reflection,
scale and shear can change the direction. Translation has no effect, including
on cached receiver shading. `Prepare` rejects a transform that collapses the
vector to zero. Detached or disabled lights contribute nothing.

Directional lights have no radius, height or distance attenuation. Normal and
specular materials respond to their direction. Flat materials receive uniform
colour multiplication. Receiver masks, unlit materials and HUDs work as with
point lights. Existing point-only arrays remain accepted by `SetLights`.

For direct drawing, `TMax2DLighting.SetDirectionalLight(index,x,y,z,red,green,blue,intensity)`
configures an existing slot. `SetPointLight` and `SetDirectionalLight` switch its
kind while retaining its receiver mask. `SetLightHeight` requires a point slot.
The optional `TSceneLightingStage` also exposes `SetDirectionalLight`, but its
flattened artwork has no surface normals, so it receives uniform illumination.

## Textured point lights

Attach a shared `TMax2DLightTexture` to a point light to project an authored
shape, coloured window pattern or spotlight mask:

```blitzmax
Local pattern:TMax2DLightTexture = TMax2DLightTexture.Create(LoadImage("window.png"))
pattern.SetPlacement(480,320,0,0,25) ' width, height, offset X/Y, clockwise degrees
lamp.SetTexture(pattern)

' Later, after editing settings and before rendering:
lighting.Prepare()
```

The projected rectangle is centred on the point light plus its offset. Size and
offset use **layer-world units**, and the angle is clockwise in degrees. These
settings are independent of radius and falloff: the pattern multiplies analytic
attenuation. Node and parent transforms move the light centre; projection size,
offset and angle are explicit world-space settings, independent of parent scale
and rotation. Camera transforms still move the pattern and receivers together.
Set radius large enough to include the desired pattern. Outside the rectangle,
the light contributes nothing; ambient and other lights remain visible.

The pattern's RGB and alpha multiply both diffuse and specular illumination.
A white opaque texel preserves the analytic light; black or transparent texels
suppress it. Receiver alpha is unchanged. Normal maps, selective receivers and
unlit materials continue to work. Register occluders and enable point-light shadows to block this projected artwork.
Visible foreground sprites alone do not cast shadows.

`Create(image,frame)` starts with the image's pixel dimensions as its projected
size. `SetImage(image,frame)` changes the shared image without changing placement;
`GetImage` and `GetFrame` return the current binding. `GetPlacement` copies size,
offset and angle into caller variables. Images must be nonnull. Atlas views,
including trimmed CPU-backed byte frames, and untrimmed render images are
supported. Trimmed frames use their original logical dimensions and retain
full-size sampling storage with transparent margins. Grouped lighting copies
that full canvas into its shared atlas; hard and filtered shadows use the same
placement. Changing pixels still requires `pattern.Invalidate()`, including
when clearing previously visible pixels. Filtering follows the
image flags, uses mip level zero and stays within the selected region. Render
images are decoded from premultiplied colour before modulation. Do not bind the
active destination as a light pattern. Use linear colour artwork when working
in a linear lighting pipeline.

A trimmed atlas pattern uses the same API as any other image:

```blitzmax
Local atlas:TTextureAtlas = TTextureAtlas.Create(512, FILTEREDIMAGE)
Local image:TImage = atlas.AddPixmap(LoadPixmap("spotlight.png"), "spotlight", True)
Local pattern:TMax2DLightTexture = TMax2DLightTexture.Create(image)
pattern.SetPlacement(240, 180, 0, 0, 15)
lights.SetLightTexture(0, pattern)
```

Placement includes the original transparent margins. Trimming saves atlas space,
but coordinate sampling retains an additional full-size image for each used
frame. It cannot recover RGB data discarded from transparent borders. If pixels
are edited through the image or another view of its atlas page, call
`pattern.Invalidate()` before drawing again. The next draw refreshes sampling
storage, affected native atlas tiles and shadow patterns; unchanged draws reuse
those resources.

Several lights can share a description. Configuration edits invalidate cached
scene receivers during the next `Prepare`. After editing the image's pixels,
call `pattern.Invalidate()` to notify those caches. `lamp.SetTexture(Null)`
restores analytic lighting. Images remain application-owned.

Direct drawing uses `lights.SetLightTexture(index,pattern)`. The flattened
`TSceneLightingStage` exposes the same setter; its placement uses composite-local
logical units. After editing a shared description or its pixels, call the stage
setter again to invalidate its output. Directional lights currently reject
patterns; remove a slot's pattern before switching it to directional lighting.

Textured draws sample artwork, the optional normal map and the light pattern in
one light pass, without an intermediate image per receiver. Descriptions,
shader parameters and bindings are retained; changing placement creates no
per-frame arrays, matrices or textures. Textured passes perform more texture
reads than analytic lights.

## Selective receivers and unlit materials

Lights and materials each have a 32-bit receiver mask. A light contributes
when their masks share at least one bit. Ambient illumination is unaffected by
these masks. A receiver mask of zero receives ambient only.

```blitzmax
lamp.SetReceiverMask(1)

Local material:TMax2DLightingMaterial = TMax2DLightingMaterial.Create()
material.SetReceiverMask(1)
sprite.SetMaterial(material)

' Bypass ambient and all selected lights:
material.SetUnlit(True)
```

Materials can be shared. `lighting.Prepare()` detects their revisions and
invalidates attached receivers. Ordinary `TSpriteNode` and `TTextNode` remain
unlit; a separate HUD layer needs no lighting configuration.

Receiver selection is independent of the shadow-caster mask. Receiving a
light must not automatically imply casting a shadow, or vice versa.

## Colour, intensity and falloff

Point illumination uses:

```text
attenuation = max(0, 1 - distance / radius) ^ falloff
contribution = sourceRGB * lightRGB * intensity * attenuation
```

Ambient is `sourceRGB * ambientRGB * ambientIntensity`. Contributions add to
ambient. RGB setters accept 0..255; intensities are finite and nonnegative.
Radius and falloff are finite and positive. Falloff one is linear, two is
quadratic, and larger values concentrate illumination near the centre. Intensity
zero disables a light without resizing retained storage.

Lighting preserves source coverage. Transparent padding stays transparent;
lights do not paint luminous discs into empty space. Draw an unlit sprite or
apply bloom separately if a light source should visibly glow.

There is no implicit colour-space conversion. For linear lighting, load linear
artwork (for example with `SRGBPixmapToLinearTextureData`) and use a floating-point
target. RGBA8888 output saturates to its storage range. Floating-point targets
retain brightness above one, subject to backend format/blending support. Window
HDR selection and tone mapping remain explicit presentation choices.

## Normal-mapped materials

Normal maps make surface detail respond to the direction of a light:

```blitzmax
Local material:TMax2DLightingMaterial = TMax2DLightingMaterial.Create()
material.SetNormalMap(LoadImage("panel-normal.png"))
material.SetNormalStrength(1)
sprite.SetMaterial(material)
light.SetHeight(128)
lighting.Prepare()
scene.Render()
```

`SetNormalMap(image,frame=0)` shares an image and selects a frame. The map covers
its receiver's complete image-local rectangle; dimensions and handles need not
match the artwork. Atlas frames work; trimmed byte frames use retained expanded sampling storage. `SetNormalMap(Null)` uses a viewer-facing surface if specular is enabled, or
restores the original flat lighting model otherwise. `GetNormalMap`, `GetNormalFrame` and
`GetNormalStrength` expose the settings.

Use RGB normal data without sRGB conversion, opaque unless alpha carries gloss.
Decode each RGB channel as
`2 * channel - 1`. Positive X points right, positive Y **down**, and positive Z
toward the viewer. A neutral map is approximately RGB `(128,128,255)`.
If a tool exports positive-Y-up normals, invert its green channel. The map's
alpha does not control receiver coverage; source artwork supplies coverage.

Normals receive the inverse transpose of the receiver's affine linear transform,
with Z scale one, then are normalized. This handles rotation, reflection,
nonuniform scale and shear. Scaling the receiver also scales the surface slopes;
normal strength can compensate if desired. Near-singular transforms use a
viewer-facing normal. A zero-length normal contributes no diffuse light.
Camera transforms do not change this world-space response.

`SetNormalStrength` accepts finite nonnegative values and scales XY before
transformation. Zero flattens a conventional positive-Z map while keeping the
directional diffuse model. Removing the map with specular disabled restores flat illumination.

Light height is finite and nonnegative, defaults to 128 layer-world units and
is independent of node scale. It changes diffuse direction; radial attenuation
still uses XY distance. For a normalized transformed normal `N`:

```text
L = normalize(lightX - surfaceX, lightY - surfaceY, lightHeight)
diffuse = max(0, dot(N, L))
contribution = sourceRGB * lightRGB * intensity * attenuation * diffuse
```

A coincident light with zero height contributes zero diffuse light. Ambient is
unaffected by normals. Height has no effect on receivers with neither normal maps nor specular.
These maps change shading, not geometry: they do not displace silhouettes or
cast shadows. Specular highlights use the same normals, as described below.

Material and height edits participate in automatic composite invalidation.
Editing pixels inside an already-bound image requires explicit receiver content
invalidation, as with other mutable artwork. Light Lab uses procedurally generated
normal maps; press **N** to compare surface detail, and **Q / E** to change height.

## Emissive materials

Emission keeps a receiver visible in darkness while it continues to receive
normal lighting, specular highlights and shadows:

```blitzmax
Local material:TMax2DLightingMaterial = TMax2DLightingMaterial.Create()
material.SetEmission(90,200,255,0.65) ' RGB tint and intensity
Local panel:TLitSpriteNode = TLitSpriteNode.Create(panelImage,lighting,material)
layer.AddChild(panel)
lighting.Prepare()
scene.Render()
```

RGB components are 0..255; intensity is finite and nonnegative. The default
intensity is zero. `SetEmission(255,255,255,0)` disables emission. The getters
`GetEmissionRed`, `GetEmissionGreen`, `GetEmissionBlue` and
`GetEmissionIntensity` expose the settings.

```text
baseRGB = sourceRGB * (ambientRGB * ambientIntensity
                    + emissionRGB * emissionIntensity)
```

Colours in this equation are normalized to 0..1. Direct light is added normally.
Emission is multiplied by the artwork: black source pixels remain black. It uses
the existing artwork's coverage, drawing tint and alpha; transparent pixels remain
invisible. `SetEmissionMap` optionally modulates this value per pixel, as described
below. Light receiver masks and shadow
reception affect incoming light, not emission. `SetUnlit(True)` bypasses the whole
material, including emission, and draws the ordinary image.

Emission does not light nearby objects or generate a halo by itself. Use light
nodes for illumination and a bloom stage for glow. Values above one survive in
floating-point render targets; RGBA8888 saturates. No colour-space conversion is
introduced. Without an emission map, emission uses the existing ambient pass or combined native lighting
pass, with no extra textures or passes, on both ordinary and grouped paths.

Material setters invalidate affected cached receivers on the next environment
`Prepare`; identical settings preserve their cache. In Light Lab, press **M** to
toggle cyan emission on the three lit panels, then **A** to compare with ambient
disabled. The fourth panel remains fully unlit.

[Emission validation results](scene/validation/2026-11-22-emission.csv) cover
Metal and OpenGL: ordinary/native pixel parity, coverage, floating-point output,
material validation, warm texture reuse and scene cache invalidation. The broader
lighting suite and Light Lab smoke test also passed. The subsequent [Direct3D validation](scene/validation/2026-11-23-d3d-materials.md)
records the emission, composition and broader lighting suites on D3D9 and D3D11
under Windows/Parallels. `lighting_emission` is registered for both Windows
profiles in the regression runner.

## Specular highlights

A material can reflect a moving light as a highlight:

```blitzmax
material.SetSpecular(0.8,32) ' strength, shininess
light.SetHeight(128)
lighting.Prepare()
scene.Render()
```

Strength is finite and nonnegative; it defaults to zero so existing materials
retain their appearance. Shininess is a finite positive exponent, default 32.
Try 8 for a broad satin highlight or 128 for a tight glossy highlight.
`GetSpecularStrength` and `GetShininess` return the current settings.
`SetSpecular(0)` disables highlights; pass the existing shininess as the second
argument if you want to preserve it while toggling strength.

Highlights use the light colour independently of source artwork RGB, so dark
paint can still reflect a bright light. Source alpha, drawing tint and drawing
alpha remain effective. Transparent pixels do not become visible. Receiver masks
exclude both diffuse and specular light; unlit materials bypass both.

With no normal map, nonzero specular strength enables surface lighting using a
viewer-facing normal. This also changes the diffuse response from the original
flat lighting model to directional diffuse. Disabling specular and clearing the
normal map restores the original flat model. Ambient does not produce highlights.

The model is Blinn-Phong with a fixed orthographic viewing direction `(0,0,1)`:

```text
H = normalize(L + (0,0,1))
specular = strength * max(0, dot(N,H)) ^ shininess
contribution = (sourceRGB * diffuse + specular) * lightRGB * intensity * attenuation
```

The specular term is zero when the surface faces away from the light, or when
the light direction is zero. This is an artistic response, not an
energy-conserving material model. The base strength and shininess are uniform per material; normal-map alpha can
optionally scale strength per pixel.
Separate specular-colour and roughness textures are not implemented yet. Specular is evaluated in the
existing light pass, with no additional render passes or intermediate buffers.
As with diffuse lighting, floating-point targets can preserve highlights above
one while RGBA8888 targets saturate.

Material edits invalidate affected cached receivers on the next environment
`Prepare`. Identical settings preserve the cache. In Light Lab, **S** toggles
highlights and **R** cycles shininess; **N** and **Q / E** still control normal maps
and light height.

### Per-pixel gloss

```blitzmax
material.SetNormalMap(normalAndGloss)
material.SetSpecular(0.8,32)
material.SetSpecularFromNormalAlpha(True)
```

RGB stores the normal as usual; alpha scales highlight strength. Zero is matte,
one retains the full configured strength, and values between interpolate strength.
Diffuse, ambient, light selection, shadows and receiver opacity are unchanged.
`GetSpecularFromNormalAlpha()` reports the option. It defaults to False so existing
normal maps retain their appearance. With no normal map the option has no effect.

Use **straight-alpha linear RGBA data**, retaining normal RGB even in matte texels.
Do not premultiply or trim this data: zero alpha describes a material property,
not transparent artwork. The two properties share the normal map's frame, UVs,
resolution and filtering. Per-pixel shininess and coloured specular textures are
not provided by this option. Flat normals plus gloss can represent an otherwise
flat surface; normal strength zero also removes XY normal perturbations.

This mode uses the existing normal sampler, with no additional image allocation
or reduction in grouped light capacity. The ordinary and native grouped paths
support it. Custom grouped providers must advertise `SpecularMaps()` and honour
`TMax2DLightingDraw.specularFromNormalAlpha`; providers that do not advertise it
use the ordinary fallback. Changing the option invalidates cached scene receivers
at the next environment preparation. After changing shared image pixels, invalidate
cached receivers as with other normal-map edits.

### Separate normal and gloss artwork

`TMax2DLightingMaterialMap` packs separately authored images into the same efficient
normal/gloss texture. It performs CPU work only when inputs change; rendering
still uses the existing normal sampler.

```blitzmax
Local maps:TMax2DLightingMaterialMap = TMax2DLightingMaterialMap.Create()
Local normal:TImage = LoadImage("panel-normal.png")
Local gloss:TImage = LoadImage("panel-gloss.png")
Local packed:TImage = maps.Update(normal,gloss)
material.SetNormalMap(packed)
material.SetSpecular(0.8,32)
material.SetSpecularFromNormalAlpha(True)

' After changing input pixels with ReplacePixels or a write lock:
packed = maps.Update(normal,gloss)
material.SetNormalMap(packed)
receiver.InvalidateContent() ' Required for cached scene artwork after pixel edits.

' Once no receiver needs the borrowed output:
material.SetNormalMap(Null)
maps.Release()
```

RGBA8888 gloss takes strength from **red**, ignoring its alpha; A8 gloss uses its
byte value. Normal RGB is preserved exactly and normal alpha is ignored. Pass
`Null` for the normal image to create a flat normal, or `Null` for gloss to use
full strength. At least one image is required. Both images must have the same
logical dimensions. Optional `normalFrame` and `glossFrame` arguments select
frames, including untrimmed atlas regions. Inputs are neither modified nor owned.

The builder rejects trimmed, locked, render-target, compressed and floating-point
inputs. Material data must retain RGB even where gloss is zero, so do not trim or
premultiply the source artwork. Resize mismatched inputs deliberately during asset
preparation; this helper does not resample them. Output is RGBA8888, filtered by
default; `Create(False)` chooses nearest filtering independently of input flags.

Unchanged `Update` calls create no objects or textures. Changed source revisions
trigger packing and an upload on the next draw. Same-sized edits retain output
identity and texture storage. Dimension changes replace the output, so apply the
returned image to all its materials again. Cached scene receivers need explicit
invalidation after pixel edits, because image identity and material settings can
remain unchanged. Calling `Update` is explicit; editing inputs alone does not
refresh the packed image.

The returned image is borrowed from the builder. Do not modify it, release its
frames or feed it back as an input. Clear material references before `Release` or
replacing the output dimensions. `Release` frees retained CPU/GPU storage and input
references; it is idempotent, and a subsequent `Update` can rebuild. The builder
retains a CPU packing buffer plus the output's CPU snapshot, trading memory for
reuse. It introduces no per-frame work unless the application calls `Update`.
The builder has 24 CPU regression checks; its rendering and refresh checks pass
in the 959-check lighting suite on macOS Metal and OpenGL.

The [Light Lab](../demos/light_lab/README.md) uses checkerboard floor gloss and
striped panel gloss; press G to compare it with uniform highlights.

Gloss regression coverage includes matte, partial and full strength, default/disabled
behaviour, absent maps, unchanged diffuse/ambient/coverage, cached material edits,
patterned point lights, directional lights, multiple light groups and fallback for
custom providers without the capability. The shader generator checks reproduce
the source and embedded assets. The updated suite passed 955 checks each on
macOS Metal/OpenGL and Windows VM D3D9/D3D11 on 22 November 2026.

## Occluder shadows

Register geometry separately from visible artwork, then enable shadows on the
point lights that need them:

```blitzmax
Local wall:TLightOccluderNode = TLightOccluderNode.Create( ..
    [0.0, 0.0, 48.0, 0.0, 48.0, 48.0, 0.0, 48.0])
wall.SetPosition(240, 280)
world.AddChild(wall)
lighting.SetOccluders([wall])
amber.SetShadows(True, 512, 1)
amber.SetShadowSoftness(4) ' Zero restores hard edges.
wall.SetCasterMask(1)

' This receiver still sees the light and its pattern, but ignores shadows.
material.SetReceiveShadows(False)

' After movement and material edits, before rendering:
lighting.Prepare()
scene.Render()
```

Polygons must be finite, simple outlines with at least three vertices. Convex
and concave shapes work in either winding. Do not repeat vertices (including the
first vertex at the end), use consecutive collinear edges, or cross/touch a
nonadjacent edge. Invalid geometry is rejected before replacement. Holes are not
supported; use separate solid pieces around an opening.

For example, a single L-shaped caster:

```blitzmax
Local corner:TLightOccluderNode = TLightOccluderNode.Create([ ..
    0.0,0.0, 48.0,0.0, 48.0,16.0, 16.0,16.0, 16.0,48.0, 0.0,48.0])
corner.SetHeight(32)
world.AddChild(corner)
lighting.SetOccluders([corner]) ' Supply the complete caster list here.
```

Concave footprints are triangulated when `SetPolygon` changes geometry. Rendering
and scene transforms reuse those indices; there is no per-frame triangulation.
Boundary edges project the shadow, and point-light containment uses the actual
outline, so a light in an open notch is not treated as inside the caster. Existing
height, caster-mask, softness and receiver settings apply without extra render
targets or shader capabilities. Regression checks compare an L-shaped caster
with an equivalent union of rectangles for both windings, mirrored transforms,
point/directional lights, finite heights and hard/filtered edges. The updated
lighting suite passes 1,050 checks on Metal, OpenGL, D3D9 and D3D11.

Node transforms, including reflection and parent
movement, transform the geometry. Detached, disabled or collapsed scene
occluders do not cast. Visibility and tint do not change casting. An occluder
blocks light inside its own area; a point light inside a polygon contributes no direct
illumination unless its height is below the light and permits finite projection.
Use a material with shadow reception disabled for artwork that
should remain illuminated independently of its own caster.

A light's caster mask selects blocking polygons. Its receiver mask selects lit
sprites. These masks are independent. Shadows affect direct diffuse and
specular contributions, including projected light patterns. They preserve
ambient illumination, image transparency and painter order; the HUD remains
ordinary unlit artwork.

Outside a scene, use `TMax2DLightOccluder.Create(points)`,
`TMax2DLighting.SetOccluders(polygons)` and
`SetLightShadows(index, True, resolution, casterMask)`. Coordinates are in the
same space as the lights. `SetTransformFrom` supports reusable scene or ECS
adapters without allocating a new vertex array on each movement. Both
`DrawImage` and flattened `Update` support these shadows. The flattened
`TSceneLightingStage` does not yet expose occluder configuration.

Each hard-shadow light lazily owns one square RGBA8888 image. At 512
pixels this costs 1 MiB, at 1024 pixels 4 MiB. For a point light it covers the full
diameter; for a directional light it covers the explicit shadow rectangle.
Increasing that area reduces shadow detail at a fixed resolution.
Positive softness lazily adds a full-size filtered result and a full-size scratch
image: three images total (3 MiB at 512, 12 MiB at 1024). Returning to zero keeps
these images for reuse until release or resolution changes.

The projected pattern is combined into the result image; its sampling also becomes
limited by that resolution and RGBA8888 colour range. Unchanged lighting reuses the mask. Changed lighting
or occluders redraw it, reusing image and polygon scratch storage. Light geometry
changes rebuild only that light’s mask; caster edits invalidate affected cached
lighting conservatively. Ambient, colour and intensity edits preserve masks.
Ordinary drawing uses one ambient pass plus each selected light; optional
[grouping](#grouped-lighting) combines eligible contributions and ambient. There
is no extra shadow pass per receiver. State scopes are short-lived objects, but warm
movement does not allocate textures or vertex arrays.

Call `lighting.ReleaseResources()` before closing the scene's graphics context,
or `TMax2DLighting.Release()` for direct use. Configuration is retained. Disabled
core light shadows release their image; changing resolution replaces it lazily.

`TLightNode2D.SetShadowSoftness(radius)` and the core
`SetLightShadowSoftness(index, radius)` accept finite radii from 0 to 4 in
shadow-image pixels. Core callers must enable shadows first; scene nodes retain
softness even while shadows are disabled. Positive values apply a separable blur
to visibility before multiplying the projected pattern, so pattern edges remain
sharp. Changing softness invalidates cached receivers and reuses prepared blur
storage. The filter adds two full-image passes per rebuilt mask and, for textured
lights, a visibility-composition pass. It does not add passes per receiver.

This is a constant-width artistic filter, not a physical area light or a
distance-dependent penumbra. Its width in world units scales with light diameter
or directional bounds size divided by shadow resolution. The implementation treats
occluders as opaque solids perpendicular to the receiving plane at Z=0. Distance-dependent
penumbras, open polylines and translucent occluders are not
implemented. Light Lab demonstrates three solid blocks; **H** toggles
shadows, **B** compares hard and filtered edges, and **T** toggles the projected pattern.

### Directional shadow bounds

Directional lights have no natural radius. Choose an explicit axis-aligned
rectangle in world coordinates to allocate their shadow detail:

```blitzmax
Local sun:TDirectionalLightNode = TDirectionalLightNode.Create(-1, -1, 1)
world.AddChild(sun)
sun.SetShadowBounds(0, 0, 1024, 768)
sun.SetShadows(True, 1024)
sun.SetShadowSoftness(3)
lighting.SetLights([TLightNode2D(sun)])
```

Register occluders on the same environment as in the point-light example.
`SetShadows`, `SetShadowSoftness` and their getters are shared on
`TLightNode2D`, preserving existing point-light calls. A directional light with
shadows enabled requires valid bounds before preparation/rendering.

The direction vector points **toward** the source; shadows extend in the opposite
XY direction. Parent transforms rotate/reflect that direction as usual. The
bounds remain in world coordinates: moving the sun node does not move the shadow
rectangle. Update the bounds explicitly to follow a camera or cover the room.
That update redraws the retained mask without reallocating textures.

Occluders outside the rectangle are still considered and can cast into it.
Illumination outside the rectangle is unshadowed. The outermost mask texels form
an unshadowed guard border, so place the rectangle beyond the visible area when
its boundary should not be visible. The image is square even for rectangular
world bounds: resolution and softness have independent world sizes on X and Y.

Occluders default to infinite height. Use `wall.SetHeight(32)` on either a
`TLightOccluderNode` or `TMax2DLightOccluder` for a finite height in world units.
Height is independent of scene transforms and survives polygon replacement.
Use `SetHeight(-1)` to restore infinite height; zero blocks only the footprint.
Other negative values and nonfinite values are rejected.

For positive sun elevation, shadow length is `height / tan(elevation)`: raising
the sun shortens the shadow. At or below the horizon, shadows have unlimited
reach. Point lights above a finite caster project its top onto Z=0; lights at
or below the caster height retain unlimited reach. Height changes redraw retained
masks and invalidate cached receivers without reallocating shadow images.
A purely vertical light blocks only the
polygon footprint, with no lateral extrusion. Caster masks, receiver bypass,
filtering, alpha preservation and scene cache invalidation work as for point
lights. Directional light patterns remain unsupported.

For ordinary Max2D, configure the directional slot, call
`SetLightShadows(index, True, resolution, casterMask)`, then
`SetDirectionalShadowBounds(index, x, y, width, height)`. Both `DrawImage` and
flattened `Update` use these bounds. Switching a slot's light kind retains its
shadow settings; directional bounds must be configured before drawing it.

## Ordinary Max2D

`TMax2DLighting` also draws individual images without a scene or intermediate
output buffer:

```blitzmax
Local lights:TMax2DLighting = TMax2DLighting.Create(1)
lights.SetAmbient(255,255,255,0.15)
lights.SetPointLight(0,320,200,240,255,170,80,2,2)
lights.SetLightMask(0,1)

' receiverMask=1; ordinary tint, alpha and viewport are respected.
lights.DrawImage(artwork,200,150,0,1)
```

The optional affine arguments map local draw coordinates into the lights'
coordinate system. Supply them when object drawing transforms change placement
in that system; keep camera transforms separate. Scene sprites supply this
mapping automatically. The final optional `material` argument applies normal maps and specular settings,
intersects the supplied receiver mask with the material mask, and supports unlit
bypass. Set core light height with `lights.SetLightHeight(index,height)`. Drawing uses normal alpha composition, then selected
light contributions, so overlapping translucent objects retain painter order.
The caller's blend is restored. Trimmed byte source artwork and normal maps retain full-size sampling images,
including transparent margins. Each requested frame needs additional CPU/GPU
storage; warm draws reuse it, and source pixel edits refresh it. This works in
ordinary and grouped lighting, including projected light textures.

## Optional flattened lighting

`TSceneLightingStage` in `Max2D.SceneEffects` illuminates a complete captured
subtree. This is useful when all its artwork shares one lighting response:

```blitzmax
Local stage:TSceneLightingStage = TSceneLightingStage.Create(1)
stage.SetAmbient(255,255,255,0.15)
stage.SetPointLight(0,120,80,160,255,170,80,2,2)
group.SetCacheMode(ESceneCacheMode.Automatic)
group.SetStages([TSceneEffectStage(stage)])
```

Stage positions and radii use composite-local logical units, adjusted for the
capture origin and resolution scale. Light edits reprocess output without
recapturing unchanged artwork. Lighting does not expand bounds. One additional
full-canvas output image is charged to the composite's existing storage budget;
no light map or falloff textures are allocated. Keep the HUD outside the group.

The equivalent standalone pipeline is `lights.Prepare(width,height,format)`
followed by `lights.Update(source)`. Source/output dimensions and formats must
match. The borrowed result expires on update, changed preparation, `Release` or
context closure. Release explicitly; do not release borrowed output frames.
Caller drawing state and target views are restored.

Flattened lighting cannot distinguish the materials of overlapping source
objects. Use individually lit sprites for selective materials and normal-mapped surfaces. Do not apply a lighting stage to already-lit sprites unless
you deliberately want a second colour modulation.

## Caching, allocation and cost

- Light and material descriptions are retained. Setting position, direction, radius,
  intensity or falloff creates no new textures or light descriptors.
- Changing a light count/list may allocate CPU arrays; do it during setup where
  practical. Temporarily disable lights instead of removing and recreating them.
- Ordinary individual drawing uses an ambient pass and a pass for each selected
  light affecting the image. Optional [grouping](#grouped-lighting) reduces these
  submissions, including ambient in the first supported group. Point lights are culled against world bounds; directional
  lights have no spatial bounds. Shadow-enabled lights lazily allocate one retained
  mask each; warm draws reuse it.
- Flattened processing uses one ambient pass plus visible light passes clipped
  to each point light's bounds; directional passes cover the canvas. It reuses one output texture. Drawing-state scopes are
  short-lived allocations.
- `Prepare` tracks material revisions and receiver world placement. A changed
  light conservatively invalidates registered receivers' enclosing captures;
  unchanged frames preserve automatic caches. Moving a cached group also updates
  its world-relative lighting.
- GPU packages/pipelines are cached by the graphics context. Warm the intended
  drawing paths before measuring frame time. Pass count is an implementation
  detail; performance depends on the workload and backend.

## Current lighting capabilities

The scene-integrated lighting system provides these capabilities:

| Capability | Current status / progression |
| --- | --- |
| Ambient and coloured point illumination | Implemented, with intensity, radius and analytic falloff |
| Scene light nodes and selective receivers | Implemented for point/directional lights and individually lit sprites |
| Unlit materials and HUD | Implemented |
| Textured lights | Implemented for point lights: shared colour/alpha patterns with independent size, offset and angle |
| Directional lights | Implemented: transformed direction, no distance attenuation |
| Normal-mapped materials | Implemented: shared normal maps, strength, light height and transformed diffuse response |
| Specular materials | Implemented: strength, shininess and optional gloss from normal-map alpha |
| Occluder shadows | Simple convex/concave polygons, hard/filtered point and directional shadows, separate caster masks and receiver bypass |
| Grouped light submission | Implemented: up to sixteen lights, eight on native D3D9, with capability fallbacks |
| Shared map storage | Implemented: retained atlas for eligible shadow maps and point-light patterns |
| Combined ambient | Implemented: first eligible native group includes ambient and receiver coverage |

Normal/specular data belongs to each receiver material. Occluders describe
shadow-casting geometry separately from visible artwork. Textured lights belong
to lights, not receiver textures. These distinctions are why individual-object
lighting is the primary path and flattened composition is optional.

Max2D's optional grouped path combines ambient and direct illumination in the
first eligible receiver draw. Additional groups and unsupported inputs require
further passes; flattened Update remains ordinary multipass lighting. Separate
specular-colour/roughness maps remain unimplemented. See
[grouped lighting](#grouped-lighting) for current limits and
[renderer integration](lighting-renderers.md) for the backend contract.

## Validation

Independent shadow invalidation was checked on 2026-11-22: all 222 lighting checks
passed on macOS Metal/OpenGL, Linux Vulkan/OpenGL and Windows Direct3D 9/11.
New checks cover individual light geometry, kind, height, bounds, softness and
pattern changes; preservation on ambient/colour/intensity/falloff/receiver-mask
edits; conservative caster invalidation; slot growth; and release/rebuild.
The 24-case benchmark on Metal, Linux Vulkan and both Direct3D backends confirmed
one rebuilt mask per frame when only one light moves, and zero warm texture
creations. See the [before/after report](../benchmarks/results/lighting-independent-shadows-2026-11-22.md).

The diagnostic extension was checked on 2026-11-22: all 208 lighting checks
passed on macOS Metal/OpenGL, Linux Vulkan/OpenGL and Windows Direct3D 9/11.
Coverage includes counter reset/snapshot semantics, light exclusions, bounds
rejection, shadow reuse, filter passes and storage release. The 24-case benchmark
completed on Metal, OpenGL, Linux Vulkan and both Direct3D backends, with expected
mask-rebuild counts and zero warm texture creations. Only the Metal run used the
full measurement interval; the others were functional smoke runs.

The finite-height extension was checked on 2026-11-22: all 198 lighting checks
passed on macOS Metal/OpenGL, Linux Vulkan/OpenGL and Windows Direct3D 9/11.
New coverage includes finite point and directional projections, shorter shadows
at higher sun elevations, zero-height footprints, invalid-height rejection,
revision stability, scene cache invalidation, polygon replacement and texture
reuse. The updated finite-height sunlight view was visually inspected on macOS.

The directional-shadow extension was checked on 2026-11-22: all 183 lighting
checks passed on macOS Metal/OpenGL, Linux Vulkan/OpenGL and Windows Direct3D
9/11. New coverage includes parallel and vertical projections, outside-bounds
casters, unshadowed outside-area lighting, bounds validation, directional
normal/specular materials, filtering, receiver bypass, flattened processing,
scene transforms/cache invalidation and texture reuse. Unsupported SDL renderer
rejection and both Direct3D Light Lab smoke runs passed. The sunlight view was
visually inspected on macOS.

The filtered-shadow extension was checked on 2026-11-22: all 155 lighting checks
passed on macOS Metal/OpenGL, Linux Vulkan/OpenGL and Windows Direct3D 9/11.
New checks cover intermediate edge coverage, dark interiors, preserved alpha,
sharp projected patterns, softness validation, scene-cache invalidation and
texture reuse. Unsupported SDL renderer rejection and Direct3D 9/11 Light Lab
smoke runs passed; hard/filtered comparisons were visually inspected on macOS.

The point-shadow extension was checked on 2026-11-22: all 146 lighting checks
passed on macOS Metal/OpenGL, Linux Vulkan/OpenGL and Windows Direct3D 9/11.
Checks cover shadow coverage, winding, caster selection, receiver bypass,
normal/specular and projected-pattern composition, flattened lighting, scene
cache invalidation and reuse of texture storage during movement. Unsupported SDL
renderer rejection also passed. Light Lab was visually inspected on macOS with
shadows and projected patterns, and smoke tested on Direct3D 9/11.

The lighting baseline, including normal-mapped materials, was checked on 2026-11-21:

| Platform | Lighting regression | Light Lab |
| --- | --- | --- |
| macOS ARM64 | SDL GPU/Metal, OpenGL; SDL renderer rejection | Native GUI inspection, including ambient toggle and unlit panel/HUD |
| Linux ARM64 VM | SDL GPU/Vulkan, OpenGL; SDL renderer rejection | Vulkan and OpenGL smoke runs |
| Windows x64 in ARM VM | SDL GPU/Vulkan, OpenGL, Direct3D 9, Direct3D 11; SDL renderer rejection | All four shader backends smoke tested |

The specular extension was checked on macOS Metal/OpenGL, Linux Vulkan/OpenGL,
and Windows Direct3D 9/11, including Light Lab inspection on macOS and native
Direct3D smoke runs.

The directional extension was checked on 2026-11-22: all 93 lighting checks
passed on macOS Metal/OpenGL, Linux Vulkan/OpenGL and Windows Direct3D 9/11.
Shader-package reproducibility and unsupported SDL renderer rejection also passed.
Light Lab was inspected on macOS in both sunlight and point-light modes;
Direct3D 9/11 demo smoke runs also passed.

The textured-point-light extension was checked on 2026-11-22: all 120 lighting
checks passed on macOS Metal/OpenGL, Linux Vulkan/OpenGL and Windows Direct3D
9/11. Existing colour, coordinate, two-texture and transformed-map package
regressions also passed on those backends. Shader generation remained
reproducible, including unchanged older ABI assets; malformed ABI 5 manifests
and unsupported SDL renderer use were rejected. Light Lab's pattern toggle was
visually inspected on macOS, and its Direct3D 9/11 smoke runs passed.

Textured checks include pattern colour and alpha, unchanged receiver coverage,
independent size/offset/rotation, atlas regions, render-image orientation and
premultiplied decoding, normal/specular shading, receiver masks, target feedback
rejection and recovery, shared-pattern cache invalidation, warm texture reuse,
and flattened-stage projection.

Regression coverage includes attenuation and overlapping colours, intensity above
one, transparent coverage and painter order, receiver masks, unlit materials,
logical-to-pixel mapping, target/viewport restoration, warm texture reuse,
composite memory accounting and cache invalidation. Normal-light checks include
light-facing and away-facing surfaces, rotation, reflection, shear, height,
zero-length light direction, ambient independence, and normal-map cache edits.
Specular checks cover light colour on black artwork, highlight width, normal
direction, coverage, receiver masks, parameter validation and cache invalidation.
Directional checks cover constant illumination, normal/specular response, masks,
slot-kind changes, full-canvas composition after a bounded point pass, parent
rotation, translation-independent caching, and disabled/detached nodes. Shader-package generation
also checks reproducibility of the existing packages and the point-light and normal-light
packages. These are correctness checks, not comparative performance benchmarks.

From the Max2D repository, run the applicable profiles:

```sh
python3 tests/run_regressions.py core --test shader_package_generator
python3 tests/run_regressions.py sdlgpu gl sdl --test scene_lighting
# Windows:
python tests/run_regressions.py d3d9 d3d11 --test scene_lighting
```

## Profiling lighting work

Both `TMax2DLighting` and `TSceneLighting` provide `ResetStats`, `CopyStats`
and `CaptureStats`. Counters accumulate until reset; neither scene preparation
nor rendering resets them automatically. Reuse a snapshot in a frame loop:

```blitzmax
Local work:TMax2DLightingStats = New TMax2DLightingStats
' Once per measured frame, with lighting: TSceneLighting and scene: TScene:
lighting.ResetStats()
lighting.Prepare()
scene.Render()
lighting.CopyStats(work)
' Read work.LightPasses(), work.ShadowRebuilds(), work.ShadowCacheHits(), etc.
```

`CopyStats` does not allocate a snapshot; `CaptureStats` creates a detached copy.
Resetting counters preserves shadow caches. Instrumentation uses retained counters
and adds no per-draw diagnostic objects. Counters describe attempted work, with
completed direct passes, mask rebuilds and blur passes counted after success.
They are not backend draw-call counts or GPU timestamps.

| Counter | How to interpret it |
| --- | --- |
| `ReceiverDraws()` | Lit image draw attempts or flattened updates; excludes unlit bypasses. |
| `LightTests()` | Light slots examined across all receivers. |
| `ExcludedLights()` | Zero-intensity or receiver-mask exclusions. |
| `BoundsRejects()` | Individually tested point lights outside receiver bounds. |
| `SelectionNodeTests()` | Hierarchy bounds tested, including internal nodes. |
| `SelectionRebuilds()` | Completed lazy hierarchy rebuilds. |
| `SpatialRejects()` | Slots skipped by hierarchy bounds before mask/intensity testing. |
| `LightPasses()` | Completed direct-light passes, including groups that also compose ambient; excludes shadow construction. |
| `AmbientPasses()` | Completed ambient compositions, separate or combined. |
| `CombinedAmbientPasses()` | Ambient compositions included in the first direct-light group. |
| `PairedPasses()` | Direct-light passes combining exactly two contributions when light batching is enabled. |
| `GroupedPasses()` | Direct-light submissions through a grouped renderer, including paired passes. |
| `LightContributions()` | Direct-light contributions drawn, independently of group size. |
| `GroupedLightContributions()` | Contributions submitted through grouped renderers, including paired compatibility and single-light groups. |
| `OrdinaryLightPasses()` | `LightPasses() - GroupedPasses()`: ordinary work, including disabled batching and flattened updates. |
| `MaximumGroupSize()` | Largest completed group since reset; zero if none completed. This is observed use, not backend capacity. |
| `GroupSupportChecks()` | Calls to renderer `Supports`, including smaller-prefix retries and paired compatibility. |
| `GroupSupportRejections()` | Support checks returning False; excludes capability exclusions and exceptions. |

| `ShadowRequests()` | Requests for a selected light's shadow mask. |
| `ShadowCacheHits()` | Requests satisfied without rebuilding the mask. |
| `ShadowRebuilds()` | Successfully rebuilt masks. |
| `OccluderTests()` / `Casters()` | Polygons examined / enabled, matching, nondegenerate polygons processed during rebuilds. |
| `FilterPasses()` | Two blur passes per filtered mask rebuild; excludes pattern composition. |
| `RetainedShadowBytes()` | Current estimated shadow texture storage when copied, including retained filter scratch images. |
| `MapUploads()` / `MapCacheHits()` | Copies into / unchanged lookups from retained renderer map storage. |
| `RetainedMapBytes()` | Current estimated renderer map texture storage, separate from the shadow masks. |

A warm static scene should reuse masks. A cached scene receiver can skip lighting
entirely, producing zero lighting work; use `scene.CopyStats` to inspect its cache
hits. Many receiver draws can increase light tests and direct passes while still
sharing masks. Receiver-mask filtering and point-light bounds rejection reduce
those passes. A single large receiver has fewer tests but may shade a larger area.

### Interpreting batching diagnostics

Measure a stable interval with batching enabled, then compare limits 8 and 16.
Reuse the snapshot in frame loops:

```blitzmax
Local work:TMax2DLightingStats = New TMax2DLightingStats
lighting.ResetStats()
' Draw the measured scene or receivers here.
lighting.CopyStats(work)
Local average:Double
If work.GroupedPasses() Then
    average = Double(work.GroupedLightContributions()) / work.GroupedPasses()
End If
Print "Average lights per group: " + average
Print "Largest group: " + work.MaximumGroupSize()
Print "Ordinary passes: " + work.OrdinaryLightPasses()
Print "Support checks/rejections: " + work.GroupSupportChecks() + "/" + work.GroupSupportRejections()
```

A low average can be expected when receiver bounds or masks select few lights.
Increasing capacity only helps receivers whose selected lights exceed the smaller
limit. Ordinary passes can indicate unsupported materials or maps, but also occur
when batching is disabled or flattened `Update` is used. They are not exclusively
fallbacks. `PairedPasses()` counts any two-light group, not just the compatibility
renderer.

Support rejections measure negotiation overhead: the processor may try smaller
prefixes or another renderer and still draw every light. Capabilities can exclude
a candidate before `Supports` is called, so zero rejections does not guarantee
that every receiver used a native group. Check `LightContributions()` for completed
lighting work and the ordinary/grouped counters for how it was submitted.
A throwing support check is counted as attempted work, without adding a rejection;
a throwing draw does not increase completed-group counts or maximum size.

Shadow masks are invalidated independently per light. Position, radius, height,
direction, light kind, projected pattern, shadow bounds, caster mask, resolution
and softness changes rebuild only that light's mask when it is next needed.
Ambient colour/intensity, light colour/intensity/falloff and receiver masks do not
change shadow visibility and preserve the prepared masks. They still update the
lighting revision so cached scene receivers refresh their visible output.

Registered caster edits now check both the previous and current casting state.
A point-light mask is invalidated only if the old or new enabled caster has a
matching caster mask and its bounds overlap the light's square shadow region,
including a conservative raster/filter fringe. Checking the old state removes
shadows when a caster moves away, changes mask or becomes disabled. Height and
shape edits use the same conservative bounds test. Snapshots belong to each
lighting environment and are reused without allocating on edits.

Directional shadows invalidate for any matching old or new enabled caster,
regardless of distance: distant geometry can project into the shadow region.
Replacing the registered caster list still invalidates all masks. Disabled or
unselected lights rebuild lazily when used again; resource release also forces
a rebuild. This optimization preserves shadow images and native atlas tiles;
caster revisions still invalidate scene receiver output through the existing
environment dependency tracking.

`ShadowRebuilds()`, `ShadowCacheHits()`, `MapUploads()` and `FilterPasses()` expose
the avoided work. The selective-invalidation regression compares each result
pixel for pixel with forced full rebuilds. Its two separated point lights and
one directional light require 14 mask rebuilds across twelve caster edits,
instead of 36 with full invalidation; the unchanged native tiles also avoid
uploads. This is a work-count comparison, not a frame-rate measurement.

Storage is an estimate of owned RGBA8888 shadow images, excluding textures supplied
by the caller, flattened output, scene caches and driver overhead. Soft shadows
retain three images per prepared light; switching back to hard shadows retains
that capacity until release or resize. `Release`/`ReleaseResources` clears the
storage estimate without resetting cumulative work counters.

Use [the lighting benchmark](../benchmarks/README.md#lighting) for repeatable
workloads and renderer-level submissions and texture-creation counts alongside
lighting diagnostics.


## Grouped lighting

`SetLightBatching(True)` on `TMax2DLighting` or `TSceneLighting` enables optional
grouped direct-light drawing. It defaults to False; disable it for an ordinary
reference-path comparison. The scene adapter refreshes cached output at its next
`Prepare`.

```blitzmax
Local lighting:TSceneLighting = TSceneLighting.Create(world)
lighting.SetLightBatching(True)
' Optionally cap groups for profiling or a particular device:
' lighting.SetLightBatchLimit(8)
' Register lights and receivers as usual; Prepare before scene.Render.
```

`SetLightBatchLimit(maximum)` accepts a positive maximum (default 16), without
enabling batching. `GetLightBatchLimit()` returns the requested limit; the backend
may use less. Changing it releases the renderer atlas and refreshes scene output
at the next `Prepare`, while retaining prepared source shadow masks. Configure
it during setup or profiling rather than changing it every frame.

The built-in native renderer evaluates up to **sixteen lights per
pass**, with flat, normal-mapped or specular receivers. Point and directional
lights can share a group. Intensities above one are supported. Byte-format
source artwork can draw into normalized or floating-point targets. Hard and
filtered shadow maps and projected patterns up to 512×512 pixels share a retained atlas.

| Renderer path | Maximum lights per pass | Normal/specular | Shadows | Projected patterns |
| --- | ---: | --- | --- | --- |
| Native grouped | 16 where supported; otherwise 8 | Yes | Hard and filtered, maps up to 512×512 | Byte colour/alpha maps up to 512×512 |
| Paired compatibility | 2 | Uses fallback | Hard and filtered | Uses fallback |
| Ordinary | 1 | Yes | Hard and filtered | Yes |

The native shader currently has assets for SDL3 GPU (Metal, Vulkan and
Direct3D), desktop OpenGL, native D3D9 and D3D11. Actual shader and drawing-state
support is checked on the active context. If the native renderer is unavailable
or a group is unsupported, the processor tries paired compatibility and then
ordinary drawing. The paired path retains its restrictions: flat point lights,
intensity at most one, and no projected patterns. Floating-point source artwork
uses ordinary drawing. Native D3D9 retains eight-light groups because its
sixteen-light shader exceeds temporary-register limits. Other native backends
try sixteen lights and fall back to eight when shader creation is unavailable.
Groups of eight or fewer use the smaller shader even when sixteen are supported.

Direct patterns support RGBA8888 and A8 images, image subregions and byte-format
render images, with nearest or linear filtering. Mipmapped, compressed and
floating-point direct patterns use ordinary drawing. A pattern combined with
shadows is eligible when its prepared shadow map meets the byte-format and size
limits. The atlas preserves each source’s alpha representation so filtering
transparent coloured patterns matches ordinary lighting.

Selected lights remain in their original order. Shadow bypass, receiver masks
and bounds rejection retain their existing meaning. Disabling shadow reception
skips atlas sampling and can avoid the shadow-map size limit when no projected
patterns are present. Flattened `Update` uses the ordinary path regardless of this setting.
The first eligible native group also composes ambient and receiver coverage.
A receiver with one to sixteen eligible lights (eight on fallback backends) can
therefore use one lighting submission. More lights add further groups; ambient is applied only once.
Zero eligible lights, an unsupported first light, and providers without
ambient support retain a separate ambient draw. Unlit artwork still bypasses
lighting.

On normalized targets, each direct contribution is clamped before multiplying
by source alpha, matching the ordinary path even for additive render-image
artwork whose decoded colour exceeds one. Floating-point targets retain the
full light range. The first combined pass applies receiver coverage with ordinary
alpha composition; later passes preserve destination alpha. Separately rounded normalized
blends can differ from grouped sums by a few rounding units; image tests cover
opaque, translucent, transformed and additive artwork.

`AmbientPasses()` counts completed ambient compositions, including combined
ones. `CombinedAmbientPasses()` counts those included in the first light group.
Total lighting submissions are `AmbientPasses() + LightPasses() -
CombinedAmbientPasses()`. The counters also cover flattened updates, whose
ambient remains separate.

`LightPasses()` counts actual completed direct-light passes.
`LightContributions()` counts the lights applied independently of group size.
`GroupedPasses()` counts submissions through a grouped renderer, and
`PairedPasses()` counts the subset applying exactly two lights. Shadow-mask
invalidation remains independent per light. Native groups using maps additionally
retain a 2048×2048 atlas (16 MiB), allocated on their first use and released with
the lighting processor. Only new or rebuilt maps are copied. Shared pattern pixels are copied once;
changing placement reuses them. Call the pattern’s `Invalidate()` after editing
its pixels, as with ordinary lighting. If a workload fills
the page, tile assignments are reset between groups without reallocating the
texture; this can increase uploads for workloads exceeding atlas capacity.
`MapUploads()`, `MapCacheHits()` and `RetainedMapBytes()` expose that work and
storage. Requests, selection arrays, light records and atlas tile records are
retained and reused.

Use the benchmark's `--grouped` switch (`--paired` remains an alias), and add
`--normal` for normal/specular receivers and `--patterns` for shared projected
artwork. See the
[native grouped-light measurements](../benchmarks/results/lighting-native-groups-2026-11-22.md),
the [grouped-shadow measurements](../benchmarks/results/lighting-grouped-shadows-2026-11-22.md),
the [grouped-pattern results](../benchmarks/results/lighting-grouped-patterns-2026-11-22.md),
the [combined-ambient results](../benchmarks/results/lighting-combined-ambient-2026-11-22.md),
and the [renderer integration guide](lighting-renderers.md).

## Lit text, meshes and custom artwork

`TLitCanvasNode` gives custom drawing the same environment, material, receiver
masks, normal/specular response and shadows as `TLitSpriteNode`. Subclass
`OnPaint`, initialize the receiver, and give it explicit local capture bounds:

```blitzmax
Type TLabelPanel Extends TLitCanvasNode
    Method OnPaint() Override
        SetColor(80,120,170)
        DrawRect(0,0,240,80)
        SetColor(255,255,255)
        DrawText("Engine ready",16,28)
    End Method
End Type

Local panel:TLabelPanel = New TLabelPanel
panel.InitializeLighting(lighting)
panel.SetCanvas(0,0,240,80)
panel.SetPosition(60,100)
layer.AddChild(panel)
```

Call `lighting.Prepare()` before rendering, as for lit sprites. `OnPaint` runs
only when captured pixels need refreshing. After changing text, mesh vertices,
fonts or image pixels used by the callback, call `panel.InvalidateCanvas()`.
This also invalidates enclosing automatic composites. Light, material and node
transform changes reuse the captured pixels. Shared materials are available via
`GetMaterial` and `SetMaterial`.

The capture starts with white tint, full opacity, alpha blending and a transparent
clear. Paint in the configured local rectangle; drawing outside it is clipped.
Set the font and drawing styles you need explicitly. Inside a node subclass,
qualify drawing setters that also name node methods: for example,
`Max2D.Core.SetAlpha(0.5)` sets paint opacity, while `panel.SetAlpha(0.5)` changes
the final receiver opacity. The same distinction applies to scale and rotation.
Do not change render targets or mutate the scene inside `OnPaint`.

The first visible render allocates a filtered RGBA8 image at one pixel per local
unit. Normal maps cover that complete rectangle, including transparent margins.
The canvas is one flattened receiver: overlapping paint operations do not have
independent materials or lighting order. Use separate canvases or sprites when
that distinction matters. Children remain independent scene drawables. This is
not a direct lit mesh shader, an HDR capture or an automatically scaled high-DPI
capture. Large or frequently repainted canvases have capture and storage costs.

Scene resource release and destruction release the owned image; shared assets
remain application-owned. A failed paint callback restores drawing state and
retries at the next render. Custom receiver implementations can derive from
`TLitNode` and use `DrawLitImage` for their own retained images.

See [the lit canvas example](../examples/scene_lit_canvas.bmx) for text, a mesh,
shapes, moving lighting and explicit repainting.

## Spatial receiver selection

Enable the optional spatial path on either the processor or scene environment:

```blitzmax
lighting.SetSpatialSelection(True)
```

For `DrawImage` with at least 32 light slots, this builds a retained balanced
bounds hierarchy sorted along X. Receiver bounds prune whole branches before
individual light tests. Directional lights remain global. Candidates are restored
to their original slot order, so additive composition, grouping and fallbacks
retain their existing order. Smaller lists and flattened `Update` keep linear
selection. The default is disabled; `GetSpatialSelection()` reports the setting.

Changing point position/radius, light kind or slot count marks the hierarchy for
one lazy rebuild on the next receiver draw. Colour, intensity, masks and material
changes do not rebuild it. Warm queries allocate no arrays; rebuilds reuse storage
while the required power-of-two capacity remains unchanged. Geometry changes
across many lights should be completed before drawing the receivers.

Measure both `LightTests()` and `SelectionNodeTests()`. `SpatialRejects()` counts
slots removed before mask/intensity tests, so those slots are absent from
`ExcludedLights()` and `BoundsRejects()`. `SelectionRebuilds()` exposes maintenance
cost. Reset and copied snapshots include all these counters.

This helps sparse, spatially separated light fields. Large overlapping lights,
many directional lights, small receiver counts or frequent rebuilding can reduce
or reverse the benefit. X-only sorting is less effective for distributions with
little X separation. Other per-receiver work, including source revision checks,
still visits light descriptions; this does not make the entire draw sublinear.
Changing this option preserves scene caches because rendered output is unchanged.
See the [selection benchmark](../benchmarks/README.md#spatial-light-selection)
and its [initial results](../benchmarks/results/light-selection-2026-11-22.md).

## GPU elapsed timing

Optional [GPU profiling](gpu-profiling.md) can bracket a lighting draw or scene
render independently of the CPU work counters. The first provider uses desktop
OpenGL timer queries. Unsupported contexts return no timer; CPU timing is never
reported as GPU time. The lighting benchmark accepts `--gpu` and reports sample
coverage alongside the elapsed results.

## Direct textured mesh receivers

`TMax2DLighting.DrawMesh(mesh, image, x, y, frame, receiverMask, xx, xy,
yx, yy, tx, ty, material)` draws textured triangles directly. In a scene use
`TLitMeshNode` from `Max2D.SceneLighting`:

```blitzmax
Local mesh:TMesh2D=TMesh2D.Create( ..
    [0.0,0.0,160.0,0.0,140.0,100.0,10.0,90.0], ..
    [0,1,2,0,2,3], ..
    [0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0])
Local receiver:TLitMeshNode=TLitMeshNode.Create(mesh,artwork,lighting,material)
layer.AddChild(receiver)
' After geometry edits:
mesh.xy[5]=110
receiver.InvalidateContent()
lighting.Prepare()
scene.Render()
```

Here `lighting` is a `TSceneLighting` environment for `layer`; `artwork` and
`material` are shared image/material resources. See the complete
[animated lit mesh example](../examples/scene_lit_mesh.bmx) for setup, generated
normal-map artwork and cleanup.

UVs span the image's full logical rectangle, including trimmed margins. Image
handles are ignored. Immediate drawing respects the drawing handle and current
camera; the optional affine coefficients independently map geometry into lighting
coordinates. Each triangle derives a UV-to-world mapping, so light positions and
the normal-map basis follow deformation. Adjacent triangles with different
mappings can have visible normal/specular boundaries.

Point and directional lights, normal/specular materials, emission, receiver masks,
light textures and shadows support both ordinary and grouped drawing. There is no
per-receiver capture. Enable `lighting.SetLightBatching(True)` on the immediate
processor or scene environment to combine eligible lights. The native
provider accepts mesh geometry, including combined ambient composition. Existing
image-only providers and unsupported groups fall back to ordinary lighting.

With batching disabled each triangle costs an ambient pass plus its selected
intersecting light passes. With an eligible native group the first pass also
includes ambient; further passes add groups up to the backend's light limit.
Consecutive non-overlapping triangles with exactly the same UV-to-geometry affine
mapping can be submitted together. Native providers support this optional
`AffineMeshGeometry` capability. Two such triangles and 17 intersecting lights
need 2 submissions with a sixteen-light provider, or 3 with an eight-light provider.
Mapped emission joins the first eligible group per section when it needs no
shadow/pattern texture; other combinations add one separate ambient submission.

A deformed mesh can contain several eligible sections: for example, a bent strip
whose segments each have their own affine mapping. Each section keeps its own
lighting positions and normal-map basis. Sections are processed in index order;
they may overlap each other, but overlapping triangles within one section split
it before the overlap. Triangles are never sorted to find more matches. Authoring
consecutive triangles for each affine section allows more of them to be combined.
Older providers still receive individual triangles. Receiver/pass counters count
the actual section or triangle requests. Normalized targets can differ slightly
because ordinary passes round to stored channel values after each light; grouping
rounds less often.

The current fast path conservatively requires exact affine-basis agreement within
a section and at most 512 triangles in the mesh. One retained value snapshot per
processor detects direct array edits, including replaced arrays. Changed XY data
rebuilds local mappings and section boundaries, reusing the non-overlap proof for
subranges of earlier sections when UV/index data is unchanged. Merging sections
or changing UV/index data can still require quadratic overlap analysis, bounded
by that limit. Unchanged geometry uses linear value checks and cached triangle
mappings. Current lighting transforms are validated before drawing, even when
local mappings are cached; a failed analysis is never reused. Section meshes
share the retained coordinate snapshots; their index buffers are reused when sizes
match. Alternating different meshes can rebuild this single cache. `Release()`
discards it. Larger meshes retain the triangle path. Within the analysis limit,
triangles with distinct bases can use the general path described below when the
provider supports it.
See the [original affine measurements](scene/benchmarks/2026-11-23-affine-mesh.md)
and [section validation](scene/validation/2026-11-23-mesh-sections.md).
The [preparation benchmark](scene/benchmarks/2026-11-23-mesh-preparation.md) measures
the later CPU analysis changes separately from rendering.

Native providers also advertise `DeformedMeshGeometry`. With batching enabled,
a mesh whose triangles have distinct mappings can be drawn once per light group,
provided its geometry interiors do not overlap. This uses the same `DrawMesh` API
and also applies to lit scene mesh nodes. Full receiver bounds select lights,
including lights outside the first triangle's mapped image rectangle. Normal and
specular maps retain each triangle's local direction; cameras and virtual
presentation affect drawing without moving lights in lighting coordinates.

All light groups are checked before drawing the general mesh. Unsupported
materials, patterns, providers, singular drawing transforms or texture gradients
too small for reliable fragment precision fall back to the
ordered section/triangle path. If a provider fails or changes support after actual
submission begins, the error propagates without a fallback redraw. Ambient-only
meshes need no native group. Mapped emission can join the first native group alongside shadow/pattern textures
where the four-texture shader is supported. Three-texture providers combine it
only with groups needing no light maps; unsupported combinations retain a separate
ambient pass.
Overlapping meshes and meshes above the 512-triangle analysis limit retain ordered
fallback. There is no public API change required to opt into this beyond existing
`SetLightBatching(True)`.

General overlap analysis uses triangle bounds to reject separated pairs before
precise tests, and caches the result for unchanged geometry. Deformation can
invalidate it; worst-case analysis remains quadratic within the triangle limit.
The native fragment shader uses screen position and UV gradients; degenerate
gradients use a viewer-facing normal. See the [deformation measurements and
validation](scene/benchmarks/2026-11-23-deformed-mesh.md) for tested cases and costs.

Lit triangles require nonsingular UV mappings (absolute normalized determinant
at least `1e-12`). Invalid arrays, indices, nonfinite coordinates and UVs outside
`[0,1]` are rejected before submission. Unlit materials use ordinary textured mesh
drawing and do not require invertible UV mappings. Overlapping triangles compose
in index order. Null geometry or artwork draws nothing.

The node borrows its mesh, image and material. Material edits are observed during
`Prepare`; direct geometry, UV or artwork edits require `InvalidateContent()`.
Warm immediate draws reuse triangle scratch storage. Scene automatic caches can
retain the result until a dependency changes.

For custom shader packages, `TMax2DShaderEffect.DrawMesh(mesh, image, x, y, frame)`
applies the package directly to textured geometry. Package coordinates remain
image UVs; a generic package does not acquire world-space coordinates automatically.
Use a supported shader backend and avoid sampling the active render target.

## Emission and separate specular maps

These optional maps work on `TLitSpriteNode`, `TLitMeshNode`, `TLitCanvasNode`
and immediate `DrawImage`/`DrawMesh` receivers. Existing materials keep their
original defaults. See the complete [material maps example](../examples/scene_material_maps.bmx)
for generated artwork, a deforming mesh, controls and cleanup.

```blitzmax
Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
material.SetNormalMap(normalImage)
material.SetSpecular(0.8,32)
material.SetSpecularMap(specularImage)
material.SetEmission(255,255,255,2)
material.SetEmissionMap(emissionImage)
Local receiver:TLitSpriteNode=TLitSpriteNode.Create(artwork,lighting,material)
layer.AddChild(receiver)
lighting.SetLightBatching(True)
lighting.Prepare()
scene.Render()
```

### Emission map

`SetEmissionMap(image, frame=0)` references shared artwork. Its full logical
rectangle maps to the receiver independently of pixel size and image handle;
atlas frames and trimmed byte images follow the existing sampling rules.
With a map, the base colour is:

```text
sourceRGB * (ambientRGB * ambientIntensity
           + emissionRGB * emissionIntensity * mapRGB * mapAlpha)
```

RGB and alpha therefore both control emission. A8 artwork uses white RGB and its
alpha. The map does not change receiver coverage, light selection, incoming
shadows or specular highlights. Drawing tint/alpha still apply. Black source
artwork stays black; this is modulation of the existing source-coloured emission.
Zero emission intensity disables it. `SetEmissionMap(Null)` restores uniform
emission. Read the selection with `GetEmissionMap()` and `GetEmissionFrame()`.

With `SetLightBatching(True)`, the first eligible native group samples emission
independently alongside artwork and normals, combining ambient, emission and direct
lights in one draw. It uses the third texture binding when no light in that group
needs a shadow or projected-pattern map. Later groups can still use shadow/pattern
maps. If the first group needs that binding, the provider lacks mapped-emission
support, or no lights match, the dedicated ambient shader draws emission separately.
Floating-point emission artwork also retains the separate pass on normalized
colour targets, preserving clamping of possible negative emission before direct light.
This works for sprites, affine meshes and eligible deformed meshes. Light capacity
is unchanged; a 17-light receiver uses two groups on a sixteen-light backend and
no extra ambient draw when combined emission is eligible. Separate specular maps
continue to use retained normal/gloss packing. Uniform emission also retains combined ambient.
No capture image or additional material texture is created for emission maps.
Do not sample the current render target; HDR destinations retain overbright values.

### Separate specular map

`SetSpecularMap(image, frame=0)` references grayscale strength artwork. RGBA8888
uses red and ignores alpha; A8 uses alpha. Zero is matte and one retains the full
`SetSpecular` strength. This map overrides `SetSpecularFromNormalAlpha`; clearing
it with `Null` restores the selected normal-alpha behavior. Getters are
`GetSpecularMap()` and `GetSpecularFrame()`.

With `SetLightBatching(True)`, eligible native groups sample specular artwork
independently using a fifth texture, alongside source artwork, normals, the shared
shadow/pattern atlas and emission. This avoids allocating, copying and uploading
a derived packed image. Light capacity stays at sixteen, or eight on D3D9.
Unavailable shaders and unsupported combinations retain the CPU packer, which
combines normal RGB with specular strength in alpha for compatibility drawing.
Null normals produce a viewer-facing normal. A zero specular strength avoids
packing and leaves the original diffuse behavior intact.

The material API continues to require **unlocked, untrimmed CPU RGBA8888 normal artwork and RGBA8888
or A8 specular artwork**, with equal logical dimensions when both are supplied.
Untrimmed atlas views are supported. When replacing both maps with a different
size, clear the specular map first, then assign the new normal and specular maps.
Render targets, compressed textures and
floating-point data cannot be packed. The resulting texture uses the specular
image's filtering setting for both channels. Native groups also choose packing
when the normal and specular images request different filtering, preserving that
behavior. Use `TMax2DLightingMaterialMap`
directly if you need explicit ownership/filtering of a reusable packed texture.

Packing is deferred until a draw selects at least one direct light. Ambient-only
or emission-only receivers do not resolve normal/specular artwork, including when
all lights are excluded by masks, bounds or zero intensity. Pending pixel edits
are picked up when direct lighting is next needed. An accepted independent group
uses the original maps; rejected groups resolve and reuse retained packed storage.

The first draw needing specular packing creates one retained RGBA image per material. Input pixel
changes rebuild its pixels and upload the existing texture; unchanged draws reuse
storage. Sharing a material shares this derived texture. Configuration changes
may replace the storage. Accepted independent groups need no packed storage;
`ReleaseResources()` remains safe whether or not a fallback has created it.

### Changes, caches and ownership

Maps are shared and never released by the material. Setters advance material
revisions. `ReplacePixels` and image write locks also advance source revisions;
scene `Prepare()` observes emission/specular edits and normal edits involved in
packing, invalidating cached receivers. Raw external updates must call
`material.InvalidateMaps()` before preparation. This also discards derived packing.

`material.ReleaseResources()` releases only owned packed storage, retaining the
settings and borrowed maps. Call it after the material is no longer needed, or to
discard storage for recreation when direct lighting next needs it. Scene environments do not own
shared materials and do not release their packed storage. For example:

```blitzmax
scene.Destroy()
lighting.ReleaseResources()
material.ReleaseResources()
' Release application-owned artwork after its final user has finished.
```

[Validation](scene/validation/2026-11-23-material-maps.md) covers pixel output,
cache updates, resource recreation and ordinary/grouped paths.
