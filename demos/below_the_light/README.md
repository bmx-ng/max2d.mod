# Below the Light

A playable example of combining Max2D's optional scene, lighting and effect
modules with ordinary Max2D drawing and Box2D physics. Pilot a submarine from a
sunlit surface into generated caves, activate survey probes, then return to the
launch vessel to dock.

This guide explains how the demo is assembled and where to find the code to
adapt for your own project. You do not need the entire demo architecture to use
one of these features: a lit sprite, a bloom composite or a captured effect can
be used independently.

## Build and explore

From the BlitzMax SDK directory, build the default SDL3 GPU version:

```sh
bin/bmk makeapp -r -t gui -o /tmp/below_the_light mod/max2d.mod/demos/below_the_light/below_the_light.bmx
open /tmp/below_the_light.app
```

This example requires `Physics.Box2D` as well as the Max2D and SDL3 modules.
Add `-ud max2d_gl` to select the OpenGL profile. On Windows or Linux, choose a
suitable output path and launch the executable directly.

No downloaded artwork is required. BlitzMax code generates the colour images,
normal maps, emission maps and effect textures at startup. The demo loads a
platform font when available, falling back to the built-in font.

To see the features in context:

1. Watch the surface fish turn through the light: their normal and specular
   materials change the highlights on their flanks.
2. Descend beneath the vessel. Daylight fades continuously into the cave's local
   lighting; toggle the headlight to compare the two.
3. Fire sonar near a wall. The world distorts and cave edges light up as the wave
   passes, while the HUD stays clear.
4. Shine the headlight on a luminous colony. Its emission, bloom and nearby light
   respond together.
5. Look at kelp in front of and behind the submarine. Its lit mesh bends while
   its root remains attached to the rock.

## Features at a glance

| What you see | Max2D building blocks | Source to study |
| --- | --- | --- |
| Scrolling world and fixed HUD | `TScene`, `TLayerNode`, `TCamera2D`, custom drawing nodes | [dive.bmx](dive.bmx), [nodes.bmx](nodes.bmx) |
| Rock relief and reflective fish | `TLitSpriteNode`, normal maps, specular materials | [dive.bmx](dive.bmx), [fish.bmx](fish.bmx) |
| Submarine headlight | Textured `TPointLightNode`, light placement and occluder shadows | [dive.bmx](dive.bmx) |
| Daylight and cave shadows | Ambient illumination, `TDirectionalLightNode`, `TLightOccluderNode` | [dive.bmx](dive.bmx) |
| Shallow-water caustics | Projected light textures and receiver masks | [ecology.bmx](ecology.bmx) |
| Bioluminescent colonies | Emission maps, `TCompositeNode`, bloom stages and local lights | [ecology.bmx](ecology.bmx) |
| Sonar and probe waves | `TMax2DEffectLayer`, displacement shader effects, reusable effect chains | [sonar.bmx](sonar.bmx) |
| Sonar instrument | Automatically cached composite plus immediate drawing | [chart.bmx](chart.bmx) |
| Waving grass and kelp | `TLitMeshNode`, `TMesh2D`, content invalidation | [flora.bmx](flora.bmx) |
| Independent touch steering and throttle | Scene hit testing, pointer capture, cancellation and input mapping | [input.bmx](input.bmx), [nodes.bmx](nodes.bmx) |
| Text overlays | Scalable fonts and ordinary `DrawText` | [dive.bmx](dive.bmx) |

The procedural caves, flocking, buoyancy, bubble pool and mission rules are
application code. They demonstrate how to connect a simulation to scene nodes;
they are not additional services supplied by the scene framework.

## Start reading here

Follow [below_the_light.bmx](below_the_light.bmx), then `TDive.Init`,
`TDive.Advance`, `TDive.Draw` and `TDive.Close` in [dive.bmx](dive.bmx).
These show the complete lifecycle before you go into any individual effect.

| File | Responsibility |
| --- | --- |
| [below_the_light.bmx](below_the_light.bmx) | Module/profile selection, graphics setup, event hook, main loop and application teardown |
| [dive.bmx](dive.bmx) | Scene construction, shared resources, light registration, camera, mission state and HUD |
| [art.bmx](art.bmx) | Shared procedural artwork and normal maps |
| [nodes.bmx](nodes.bmx) | Custom scene components: ocean, probes, bubbles and touch controls |
| [input.bmx](input.bmx) | SDL events, coordinate mapping, native touch identities and device detection |
| [physics.bmx](physics.bmx) | Box2D simulation and the conversion between physics and scene coordinates |
| [map.bmx](map.bmx) | Seeded cave routes, boundary rocks, objectives and fish habitats |
| [fish.bmx](fish.bmx) | Fish artwork, materials and flock behaviour |
| [flora.bmx](flora.bmx) | Vegetation placement, shared materials and mesh deformation |
| [ecology.bmx](ecology.bmx) | Reactive glowing colonies and selective caustic lighting |
| [sonar.bmx](sonar.bmx) | World capture, displacement and wave-driven edge highlights |
| [chart.bmx](chart.bmx) | Cached instrument frame, sonar returns and heading marker |

## 1. Separate the world, HUD and simulation

The scene has two top-level layers. Only the world layer receives the camera:

```blitzmax
Local scene:TScene = TScene.Create()
Local world:TLayerNode = TLayerNode.Create()
Local hud:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(world)
scene.Root().AddChild(hud)

Local camera:TCamera2D = New TCamera2D
camera.offsetX = 600
camera.offsetY = 380
world.SetCamera(camera)
```

These are shortened examples from the demo, intended to be used inside an
application with the corresponding module imports and an active graphics context.
The demo uses a 1200 × 760 virtual resolution. World positions describe the cave;
HUD positions stay in virtual screen coordinates.

Each update advances physics and game behaviour, copies the resulting transforms
to scene nodes, updates lighting, and calls `scene.Update(dt)`. When the camera
moves, the demo calls `world.SetCamera(camera)` again: the layer copies the camera
values. Rendering then draws the scene, or the world-effect path during a pulse,
followed by ordinary Max2D text and instrument overlays.

This separation lets physics remain authoritative. `TDive.Place` moves the
physics body and synchronises the displayed state; changing the submarine sprite
position alone would not move its collider. Likewise, scene nodes do not own the
flocking or cave-generation algorithms.

**Try adapting:** keep your existing update loop and replace just its drawing
objects with scene nodes. You can continue using `DrawText`, `DrawImage` and other
immediate drawing for overlays or custom content.

## 2. Give sprites materials and register lights

A lit sprite combines an image, a lighting registry and a material. For example,
the following pattern assumes `image` and `normalImage` are already loaded:

```blitzmax
Local lighting:TSceneLighting = TSceneLighting.Create(world)
lighting.SetAmbient(60, 105, 114, 0.18)
lighting.SetLightBatching(True)

Local material:TMax2DLightingMaterial = TMax2DLightingMaterial.Create()
material.SetNormalMap(normalImage)
material.SetNormalStrength(0.85)
material.SetSpecular(2.5, 48)

Local sprite:TLitSpriteNode = TLitSpriteNode.Create(image, lighting, material)
world.AddChild(sprite)

Local light:TPointLightNode = TPointLightNode.Create(520)
light.SetColor(163, 219, 209)
light.SetIntensity(3.0)
light.SetHeight(65)
world.AddChild(light)
lighting.SetLights([TLightNode2D(light)])
```

`TDive.Init` registers the complete light array with `SetLights`, and the rock
occluders with `SetOccluders`. Adding a light to the scene establishes its scene
transform; the registry identifies the lights used to illuminate receivers.
Call `lighting.Prepare()` as the demo does before updating/rendering the scene.

Normal maps give flat artwork a surface direction at each pixel. Specular settings
make the moving light produce reflective highlights; the fish use different
settings for different species. Share a material between objects that should
look the same. Use separate materials where parameters need to change independently,
as with the four reactive colonies.

### Project a beam and cast shadows

The headlight attaches a `TMax2DLightTexture` made from the generated beam image
to a point light. `SetPlacement` controls the projected pattern's size, offset
and rotation as the hull turns. A separate, softer point light keeps the nearby
water readable.

Rock outlines become `TLightOccluderNode` polygons. The headlight enables point
shadows; the directional daylight also enables shadows and sets bounds covering
the cave. Shadow polygons and Box2D collision circles are separate representations
of the same rocks, chosen for their respective jobs.

The faint visible beam is an additional sprite that suggests light scattering
through water. It is not volumetric lighting and does not itself receive occluder
shadows. The light illuminating rock surfaces does use shadow occlusion.

### Choose which objects receive a light

Caustics use receiver masks to illuminate the environment without projecting the
pattern onto the submarine or the glowing colonies:

| Receiver/light | Mask | Effect |
| --- | --- | --- |
| Rock, background, fish and plant materials | `3` (`1 | 2`) | Eligible for ordinary lighting and caustics |
| Hull and colony materials | `1` | Eligible for ordinary lighting |
| Caustic lights | `2` | Affect receivers whose mask includes bit 2 |

The caustic image is built once. Animating its light-texture placement moves the
pattern without rebuilding or uploading a texture each frame. Its influence is
restricted to shallow water. See `TDiveEcology.Init` and `Advance` for the setup
and animation together.

**Try adapting:** use receiver masks for a character-only light, a background
highlight, or a magical effect that should illuminate selected scenery.

## 3. Combine emission, bloom and illumination

The colonies illustrate three distinct contributions to a glowing object:

- **Emission** makes selected parts of the object's material luminous, using an
  emission map to isolate the caps and markings.
- **Bloom and a soft halo** give the visible object a glow extending beyond its
  original silhouette.
- **A point light** illuminates nearby surfaces. Bloom by itself does not do this.

A composite groups the sprites and applies the effect to their combined image:

```blitzmax
Local glow:TCompositeNode = TCompositeNode.Create()
glow.SetCaptureRect(TSceneRect.Create(-80, -90, 160, 112))
Local bloom:TSceneBloomStage = TSceneBloomStage.Create(0.22, 10, 1.25)
glow.SetStages([TSceneEffectStage(bloom)])
glow.AddChild(TLitSpriteNode.Create(image, lighting, material))
world.AddChild(glow)
```

Use a capture rectangle that covers the group's content. The full colony code
also adds the soft halo sprite and positions the group. `TDiveEcology.Advance`
changes emission, bloom intensity and local-light intensity together in response
to proximity, sonar arrival and headlamp exposure.

This is useful for lamps, engine exhausts, pickups or spell effects. The response
logic remains ordinary game code; the rendering uses reusable scene components.

## 4. Apply an effect to the world without distorting the HUD

Sonar uses an explicit capture because it affects a whole rendered world view.
The reusable pieces are created once:

```blitzmax
Local layer:TMax2DEffectLayer = New TMax2DEffectLayer
Local effect:TMax2DShaderEffect = CreateDisplacementEffect(displacementMap)
effect.SetEdgeMode(MAX2D_EDGE_CLAMP)
effect.SetTextureEdgeMode(MAX2D_EDGE_CLAMP)
Local chain:TMax2DEffectChain = CreateEffectChain([TMax2DImageEffect(effect)])
```

Here `displacementMap` is the floating-point radial texture built in
`TDiveSonar.Init`. `ConfigureWave` changes its texture transform and displacement
amount as a wave expands. The draw sequence in `TDiveSonar.Draw` is:

1. Prepare reusable capture storage for the virtual resolution.
2. Temporarily exclude the HUD and capture the scene inside `layer.Capture()`.
3. Draw the cave-edge highlights into that capture.
4. Run the displacement chain on `layer.Image()` and draw its result.
5. Render the HUD separately, then draw the immediate overlays.

The code uses `TMax2DStateScope` and `Try`/`Finally` so temporary render state and
viewport changes are restored. When no visible pulse needs an effect, it uses
ordinary scene rendering. Activated probes reuse the same displacement approach
with shorter-range waves; each visible probe's chain processes the preceding
result so waves can coexist.

The edge highlights are application geometry, not something the displacement
shader discovers. Exposed rock edges are sampled at startup; their distance from
the ping origin determines when they brighten.

**Try adapting:** the same capture boundary can support heat haze, a damage flash
or an underwater distortion while keeping text and controls readable.

### Cache the stable parts of a display

The sonar scope's frame is wrapped in a `TCompositeNode` with
`SetCacheMode(ESceneCacheMode.Automatic)`. Its moving returns and heading pointer
are drawn separately. This avoids rebuilding the static frame while echoes change.
The circle and pointer remain visible; only the returns fade after a scan.

Inside `TCustomDrawNode.OnDraw`, use `TSceneDrawContext` for colour and opacity.
Outside that callback, `TDiveChart.DrawMarkers` explicitly uses
`TMax2DGraphics.Current().SetAlpha(...)`. This distinction matters: an unqualified
`SetAlpha` inside a node method can resolve to the node's own opacity setter
rather than immediate drawing state.

## 5. Animate lit meshes without rebuilding objects

`TDivePlantMesh.Create` builds a mesh with rest positions, UVs and triangle
indices, then gives it to a lit mesh node:

```blitzmax
Local mesh:TMesh2D = TMesh2D.Create(xy, indices, uv)
Local plant:TLitMeshNode = TLitMeshNode.Create(mesh, image, lighting, material)
world.AddChild(plant)
```

In this pattern, `xy` and `uv` are coordinate arrays and `indices` describes the
triangles. Keep a separate copy of the original positions. Each animation update
writes deformed positions into `mesh.xy`, then calls `plant.InvalidateContent()`.
The grass and kelp bend progressively toward their tips, preserving their roots;
normal-map lighting follows the deformed triangles.

Vegetation placement scales with the generated floor anchors. Each suitable ledge
gets grass and coral, and every two anchors supply a three-strand kelp cluster.
Overhead rocks limit kelp height. Some kelp is inserted after the submarine so it
passes in front, with slight transparency. Only nearby meshes animate; the image
and material resources are shared. Corals remain static lit sprites.

**Try adapting:** use this pattern for flags, flexible signs, tentacles or other
small deformations that do not need a physics simulation.

## 6. Keep input independent of window size and pointer identity

`TDiveInput` converts native SDL mouse/touch coordinates through
`CaptureWindowInput()` and `WindowToVirtual`, then sends scene pointer events.
This accounts for the virtual resolution and letterboxing. Native touch and
finger IDs are retained in reusable slots rather than truncated into scene IDs;
mouse events synthesised from touch are ignored to prevent duplicate input.

Steering and throttle are separate scene controls. Each captures its own pointer,
so a finger can leave its hit rectangle while dragging. Release, cancellation and
capture loss return the corresponding axis to neutral. Two fingers can therefore
turn and apply forward or reverse thrust independently.

Only direct touch-screen devices enable the touch interface; a trackpad does not.
Detection runs periodically and on direct touch input. A top-right menu exposes
lights, replay and new-cave actions. The input hook cancels active gestures when
the application loses focus. The small macOS helper disables press-and-hold accent
selection for this application process only.

Scene input handles hit testing and capture; the mapping from an axis to steering
torque or thrust belongs to the demo. No platform-specific gameplay controls are
needed in the physics code.

## 7. Connect generated content and simulation to rendering

### Caves and habitats

`TDiveMap` uses a local seeded random stream. It connects offset chambers with
curved, variable-width passages, including diagonals and occasional loops, then
retains overlapping boundary rocks around the carved volume. The 130-unit sampling
grid places rocks; it does not constrain route direction.

The same rock data drives collision, occluders, sonar edges and floor anchors.
Probe positions favour distant rooms and dead ends. Fish habitats are distributed
through the cave, with six additional groups in bright surface water. Route
centreline samples, probes and habitats are checked for collision clearance before
the scene is constructed.

Presentation synchronises to the display refresh by default. On high-refresh
displays this can increase the number of frames drawn per second. Pass
`--software-60` to compare with the windowed 60 Hz software timer.

Run the console build with `--profile` to print averages every 30 frames.
Compare a steady surface view with a steady cave view, then toggle the lamps
with L in the same spot. Timings are elapsed milliseconds per frame. Fish time
is included in update time, and Flip can include waiting for the display.
Lighting counters include every receiver draw, including repeated draws for
mesh sections. On SDL GPU, `gpu_draws/frame` counts geometry commands issued and
`adjacent_merged/frame` counts additional records folded into those commands.
Their sum gives the geometry record count before adjacent merging. These totals
cover the entire frame, including HUD and shadow geometry. Depth and lamp state describe the end of each interval.

For a repeatable comparison, run the console build with `--profile-cave`. It
replays a slight change of heading at 241 m for four 90-frame intervals: full
scene, grass hidden, kelp hidden, then lamp off. Vegetation continues animating
while hidden so the two visibility comparisons isolate drawing work. Two final
intervals freeze the pose and animation, first with the lamp on and then off.
The kelp line counts input segments drawn whole, split into affine sections,
or handled per triangle. Its receiver count includes all pieces drawn. Compare
the final two reports per interval to allow for the change of state. Use the
same seed, backend and window size when comparing builds.

Add `--profile-stages` to `--profile-cave` for CPU-side elapsed milliseconds
per frame before draw merging. `mesh_ms` includes coordinate and index checks,
mapping analysis (`mapping_ms`), basis validation and the triangle overlap
test (`overlap_ms`). Mapping and overlap are breakdowns of mesh time.
`selection_ms` covers receiver bounds and light filtering. `group_check_ms`
covers renderer support checks. SDL GPU also reports `record_ms` for building
geometry records, including pipeline lookup and copying parameters and vertices.
The record timer excludes a flush triggered by a full vertex buffer. These
timers cover selected stages; they do not sum to the entire drawing time.
Run the same command without `--profile-stages` to compare timing overhead.

The default seed is `7`. Pass `--seed=12345` to the executable to explore another
layout; replay preserves the seed and New Cave advances it deterministically.
For command-line testing, use the console build below. Seeds reproduce layouts
within a generator version; changing the generator can change an older seed's map.

### Physics and buoyancy

`TDivePhysics` converts world units to physics metres using `SCALE` and steps
Box2D at 120 Hz. Thrust acts along the nose, steering applies torque, and water
drag resists broadside motion more than forward motion. The buoyancy controller
uses submerged hull area so the submarine can emerge and settle at the surface.
Its water plane follows the local decorative wave height; this is not a fluid solver.

This Box2D version has a 512-proxy limit. The demo loads nearby rock colliders
within 1,000 world units and removes them beyond 1,200, refreshing the neighbourhood
after 100 units of travel and when repositioning. Distant visual geometry remains
in the scene. If you reuse this approach, choose the loaded margin to exceed your
object's possible travel between refreshes.

### Fish, bubbles and surface light

Fish schools use separation, alignment and cohesion, plus submarine and rock
avoidance. Positions, velocities and accelerations live in fixed arrays; lit
sprite nodes display the result. Distant groups pause simulation.

Exhaust bubbles use a fixed pool of world-space particles. Thrust controls
emission; bubbles lose their initial backward velocity and rise at varied speeds.
They do not remain attached to the moving hull. This is custom simulation and
drawing code, rather than use of the scene-particle module.

Surface light shafts crossfade through prebuilt textures. Together with ambient
light, projected caustics and a depth-dependent veil, they suggest murky water
without a physical scattering or refraction solver. These approximations are
separate from the actual scene lighting and shadow calculations.

## Resource ownership and performance

Study `TDive.Close` alongside each component's `Init` and `Close` methods.
Creating resources once is only half the pattern: explicitly release the effect
chains, capture layers, image frames, physics world and lighting resources, and
destroy the scene when a dive is replaced or the application exits.

The main allocation and work-saving choices are:

- Shared procedural artwork, normal maps and materials for repeated objects.
- Retained scene nodes and meshes; animation edits existing arrays.
- Fixed storage for fish, bubbles, input slots and sonar returns.
- Reused capture buffers and a cached static scope frame.
- Scene culling and light batching enabled during scene setup.
- Nearby-only fish/vegetation updates, visible-pulse effects, and local colliders.

These choices reduce repeated work; they do not promise an allocation-free frame
or constant rendering cost. More visible lit meshes, lights, shadow casters or
simultaneous full-screen pulses still cost work. The demo sets a 64 MiB scene
storage limit and checks retained scene storage on destruction; that is not a
budget for every texture, physics allocation or standalone effect buffer.

## Controls and mission

| Action | Keyboard | Touch |
| --- | --- | --- |
| Forward/reverse thrust | W/S or Up/Down | FWD/REV slider |
| Turn | A/D or Left/Right | STEER slider |
| Sonar | Space | PING |
| Headlight | L | Menu → Lights |
| Replay this seed | R | Menu → Replay; DIVE after docking |
| Generate another cave | N | Menu → New Cave |
| Close | Escape | Platform application controls |

Approach amber probes to activate them; their status LEDs turn green. Once all
are active, return to the vessel bearing, slow down beside the launch crane and
hold position for 1.5 seconds. There is no combat, fuel or oxygen timer.

## Checks and further reading

Build a console executable for automated checks so the platform entry point
preserves command-line arguments:

```sh
bin/bmk makeapp -r -o /tmp/below_the_light_test mod/max2d.mod/demos/below_the_light/below_the_light.bmx
/tmp/below_the_light_test --test
/tmp/below_the_light_test --test --seed=337897
```

`--test` checks deterministic geometry and placement across 100 seeds, route
clearance, probe recovery and docking, independent touch controls and menu actions,
hidden-control hit testing, physics behaviour, fish scattering/regrouping,
vegetation roots and triangle validity, colony responses, receiver masks and scope
fading. It also renders 120 frames through several parts of the scene and checks
effect results and retained-storage cleanup. Simulated pointer checks do not
replace testing on a physical touch device, and these checks do not constitute a
performance benchmark or validation of every graphics backend.

For smaller isolated examples and API documentation, continue with the
[Max2D overview](../../README.md) and [examples](../../examples). The entry-point
imports show which optional modules this demo needs. Scene animation, scene
particles and tilemap/importer modules are not required by this example.
