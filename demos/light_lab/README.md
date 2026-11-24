# Light Lab

An interactive example of ambient, coloured point and directional illumination, scene light
nodes, convex and concave point/directional occluders, normal-mapped and specular receiver materials, and an unlit HUD. Artwork and normal maps
are generated once using Max2D drawing calls and pixmaps; no external assets are required.

From the SDK directory:

```sh
bin/bmk makeapp -r -t gui -o /tmp/LightLab mod/max2d.mod/demos/light_lab/light_lab.bmx
```

On macOS this creates `/tmp/LightLab.app`. SDL GPU is the default. Add
`-ud max2d_gl`, `-ud max2d_d3d9` or `-ud max2d_d3d11` for another supported
backend; Direct3D backends require Windows. Choose an appropriate output path
on Windows.

## Controls

- **D:** switch between sunlight (the default) and point lights.
- **1 / 2:** select the amber or cyan light.
- **Drag in the room:** move the selected point light and pause automatic motion.
- **Left / right:** change sunlight direction, or the selected point light’s radius.
- **Up / down:** change sunlight intensity, or the selected point light’s intensity.
- **F:** in point mode, cycle falloff exponents 1 through 4.
- **A:** toggle ambient illumination.
- **N:** toggle normal maps to compare surface detail.
- **Q / E:** lower/raise sunlight elevation, or the selected point light above the surface.
- **S:** toggle specular highlights.
- **G:** compare mapped gloss with uniform gloss.
- **M:** toggle cyan emission on the three lit panels; compare with ambient off and shadows enabled.
- **B:** compare hard edges with a four-pixel visibility filter (enabled by default).
- **H:** toggle point and directional shadows from the three solid blocks.
- **T:** toggle the amber light’s projected window pattern.
- **R:** cycle shininess (8, 16, 32, 64, 128); larger values tighten highlights.
- **Space:** pause/resume motion.
- **Escape:** close.

The four panels receive all lights, amber/sun only, cyan only, or no illumination.
The last panel and HUD keep their normal appearance when ambient is disabled.
Emission keeps the three lit panels visible in darkness while they still receive
lighting and shadows. It adds no light to their surroundings; the fourth panel
remains fully unlit.
Brightening respects the underlying artwork and opacity; the small source
markers are ordinary unlit sprites.

Press T to give the amber light a slowly rotating, translucent coloured window pattern.
Its image is generated once, and its shared placement is updated without creating
textures each frame. T compares the patterned and analytic light. This is a light
pattern which is also blocked by the registered scene occluders.

The tile bevels and grille recesses respond to moving lights through normal maps.
Moving highlights add gloss; toggle them with S to compare a matte surface.
Specular works without a normal map too. Disable both S and N to recover the
original flat illumination. Shadows remain active independently of those material
settings. Normal-map alpha stores gloss: alternate floor tiles and panel strips
are matte, while their diffuse surface detail remains visible. G toggles this
material property without replacing textures. The example authors normals and A8
gloss separately, then packs them once with `TMax2DLightingMaterialMap`; it releases
the builders after clearing the materials. Distance-dependent penumbras and
separate specular-colour/roughness textures remain future work. See the [lighting guide](../../docs/lighting.md)
for APIs, caching, colour-space choices and the planned progression.

A console build with `--test` renders three frames and exits for backend smoke
testing. Pixel equations, alpha, selection and cache dependencies are covered by
`tests/scene_lighting.bmx`.

Sunlight uses explicit world shadow bounds covering the room with a margin for the unshadowed guard border. Left/right rotates
its shadow direction along with surface illumination. The three blockers cast
parallel shadows in sunlight mode; point mode retains radial shadows. Directional
bounds are independent of the sun node's translation and camera. The same H and B
controls apply in either mode.

The blocks have a height of 32 world units. In sunlight mode, **Q / E** changes
elevation: shadows shorten as the sun rises. Point lights also use block height
when projecting shadows onto the floor.

The upper-right blocker is an L-shaped concave outline. Its notch remains open
to illumination; it uses one `TLightOccluderNode`, with the same height and
shadow controls as the rectangular blockers.
