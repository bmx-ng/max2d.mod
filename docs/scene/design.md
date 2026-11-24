# Scene framework design and contracts

**Status: the [tree and transform foundation](foundation.md),
[scene rendering](rendering.md), [subtree bounds and stable sorting](bounds-order.md),
[coordinates and picking](picking.md), [pointer routing/capture](pointer.md), and [hover/keyboard focus](interaction.md), and [culling/render counters](culling.md) are implemented in `Max2D.Scene`.
The [layout, chain, bloom and shadow stages](stages.md) and
[composite nodes with automatic caching](composites.md) are implemented in
`Max2D.SceneEffects`. Shared scene budgets and retained/peak texture-byte
statistics, tree inspection and a bounds/hit-region overlay are implemented
alongside per-composite limits. Optional [GPU timers](../gpu-profiling.md) are
available for OpenGL and Direct3D 9/11; automatic per-scene/stage GPU timing
is not implemented.**
This document describes the current contracts and explicitly identified extensions. The
[worked examples](examples.md) are now runnable applications with developer
guides and integration checks. Backend/device coverage and performance
measurement remain separate release checks. An initial
[performance and allocation baseline](performance.md) is available for macOS
SDL3 GPU/Metal and OpenGL.
See [platform validation](validation.md) for the Windows/Linux correctness
matrix and instructions for rerunning the scene and worked-example checks.

The framework provides reusable trees of objects, local coordinates, input
routing and optional subtree composition. Applications retain their graphics
backend, resource loading and main loop. Ordinary Max2D drawing can surround a
scene render or be used inside a custom drawing node.

## Design goals

- An application can build and manipulate its scene using ordinary BlitzMax
  types, methods and typed references.
- A reusable subtree works without knowing the names or layout of its parents.
- Drawing, bounds and picking agree about transforms, visibility and clipping.
- Parenting alone allocates no render image and creates no batch boundary.
- Expensive captures and effect updates are visible in diagnostics.
- Lifecycle, input cancellation and resource ownership have documented rules.
- Scene construction and spatial queries work without an open graphics context.

A scene editor, saved-scene format, physics integration and complete UI widget
library are later additions. Their extension points must not require changing
the basic tree, lifecycle or ownership contracts. The first release includes
keyboard focus and pointer routing, but not text editing, IME or automatic UI
layout.

## Composition and lifecycle

The framework combines visual composition with reusable subtrees and a small
lifecycle. All nodes can have children, including sprites. An empty spatial
node is a useful group. The application explicitly drives processing and
rendering. No engine singleton or automatic event polling is introduced.

## Modules and types

| Module | Imports | Responsibility |
| --- | --- | --- |
| `Max2D.Scene` | `Max2D.Core` | Tree, transforms, visual nodes, views, input, lifecycle and diagnostics. |
| `Max2D.SceneEffects` | `Max2D.Scene`, `Max2D.Effects` | Composite nodes, retained captures and adapters for effect helpers. |
| `Max2D.SceneLighting` | `Max2D.Scene`, `Max2D.Lighting` | Light nodes, receivers and occluders. |
| `Max2D.SceneAnimation` | `Max2D.Scene` | Retained transform/alpha tweens. |
| `Max2D.SceneTileMap` | `Max2D.Scene`, `Max2D.TileMap` | Tilemap drawing adapter. |
| `Max2D.SceneParticles` | `Max2D.Scene` | Fixed-capacity particle simulation and drawing. |

Applications import a matching effects provider when using shader effects.
None of these scene modules selects a backend. Adapters for virtual controls
and physics can depend on the scene module without the scene module depending
on those systems.

| Core type | Base | Role |
| --- | --- | --- |
| `TScene` | `Object` | Owns the attached root, coordinates traversal and routes input. |
| `TSceneNode` | `Object` | Tree membership, name, lifecycle and optional processing. |
| `TSceneNode2D` | `TSceneNode` | Transform, visibility, tint, alpha, bounds and picking. |
| `TLayerNode` | `TSceneNode` | A root-level camera and screen-clip boundary. |
| `TSpriteNode` | `TSceneNode2D` | Image and frame, with a node-local pivot. |
| `TTextNode` | `TSceneNode2D` | Text and font with local glyph bounds. |
| `TMeshNode` | `TSceneNode2D` | Existing `TMesh2D` drawing. |
| `TCustomDrawNode` | `TSceneNode2D` | User-defined local drawing and bounds. |
| `TCompositeNode` | `TSceneNode2D` | Offscreen composition, stages and optional pixel caching. |
| `TSceneDrawContext` | `Object` | Effective drawing state and helpers for custom drawing. |
| `TScenePointerEvent`, `TSceneKeyEvent` | `Object` | Typed input delivered along a stable event path. |
| `TSceneRect`, `TSceneTransform` | `Object` | Detached bounds and affine-transform values. |

`TScene.Root()` is an attached, non-spatial node. Visual content must be under a
layer. Layers are direct children of the root and cannot nest. Root-level logic
nodes are allowed. This gives each visual subtree an unambiguous view and input
mapping. A HUD is a layer with no camera. Every layer uses the current virtual
surface; its optional viewport clips in those coordinates without introducing
another origin or virtual-resolution setting.

## Tree ownership and lifecycle

A node has at most one parent. Cycles, self-parenting and attaching a destroyed
node are errors. `AddChild` rejects an already-parented child; `Reparent`
expresses that operation explicitly. Names are optional, need not be unique,
and are for diagnostics and explicit searches. There is no implicit global
name registry. Applications should retain typed references to important nodes.

- `AddChild` attaches an unparented child; insertion order is stable.
- `RemoveChild` detaches a subtree without destroying it or its resources.
- `Reparent` changes the parent without recreating the node.
- `Destroy` is terminal, recursive and idempotent. Destroying the scene destroys
  its attached root tree; previously detached subtrees belong to the caller.
- Images, fonts and meshes referenced by nodes remain externally owned. Node
  destruction does not call `ReleaseFrames` on shared application images.
- Scene-owned capture images and effect-stage storage are released explicitly.
  Garbage-collection finalisers do not perform graphics operations.

Attachment invokes `OnEnterScene` parent first. `OnReady` runs children first,
once per node lifetime, after the subtree's initial attachment callbacks.
Detachment invokes `OnExitScene` children first; reattachment repeats enter/exit
but not ready. Moving within one scene produces no enter/exit or ready callbacks. Reparenting
cancels captures in the moved subtree even within one scene; keyboard focus is
preserved if the node remains eligible.
Destroying an attached subtree cancels input ownership, exits the scene, then
invokes `OnDestroy` children first. Destroying an unattached node skips scene exit. Both paths invoke the resource
release hook before the destroy hook. Hook exceptions must not leave a half-attached tree.

`SetProcessing(True)` opts a node into `OnUpdate(dt)`;
`SetFixedProcessing(True)` separately opts into `OnFixedUpdate(dt)`. Both
traversals are parent first in insertion order. Drawing order does not alter
processing order. A scene pause suppresses processing by default; an explicit
process-while-paused setting permits menus. Visibility does not control
processing. Input and rendering remain active while paused.

### Mutation during callbacks

Structural changes are immediate outside a traversal. During input, lifecycle,
or update traversal they are queued and committed in request order
at the outermost traversal boundary. Newly added nodes cannot join that active
traversal. Tree queries continue to see committed structure until that boundary.
A pending destroy immediately makes its subtree ineligible for subsequent
update/enter/ready/input callbacks, drawing and picking (exit and destruction
cleanup still runs); a pending remove takes effect at commit.

Scalar setters are immediate during update and input. Scene mutation from
`OnDraw` is rejected: rendering observes a stable scene. Custom drawing can
change drawing state, but must schedule animation through update instead.

Commands are validated when requested and again when committed. A command whose
subject has since been destroyed is discarded and counted in diagnostics;
other invalid commands report an error. Exceptions abort the current traversal,
but pending cleanup and structural commits are completed in a protected cleanup
phase. The first exception is rethrown after state and membership are consistent.
Callbacks triggered by commits can enqueue more commands; a bounded commit guard
reports non-terminating callback mutation instead of hanging.

## Coordinates, transforms and order

All scene measurements are logical units. Rotations are clockwise degrees,
matching Max2D. Position, pivot, scale and rotation compose as:

`local = Translate(position) * Rotate(rotation) * Scale(scale) * Translate(-pivot)`

`world = parentWorld * local`

A non-spatial node between spatial nodes preserves the inherited transform and
visual state. A layer starts a new world coordinate space. Camera mapping and
virtual presentation happen after the world transform. Screen coordinates in
this API mean virtual surface coordinates, not native window or backing pixels.

Full affine transforms are also supported. `SetLocalTransform` preserves shear.
In component mode `SetPosition` edits position while preserving pivot; in affine
mode it edits matrix translation. Rotation/scale/pivot setters operate on
the explicit component representation and reject raw affine mode, including
matrices produced by preserve-world reparenting. `SetTransform` explicitly replaces that matrix with component values.
Queries return detached snapshots; changing a returned value cannot silently
change the scene. All public setters reject non-finite values. Overflow in a
derived transform or bound is reported with the responsible node before drawing
it; invalid numbers must not reach rendering or hit testing.

`Reparent(parent, preserveWorld=True)` computes the new local affine matrix
before changing membership. It preserves geometry even under rotated,
non-uniformly scaled parents. A singular new parent or crossing a layer boundary
is rejected without changes. Preserve-world reparenting is available only for
spatial nodes; a non-spatial node cannot store the compensating affine matrix. Across layers, callers explicitly choose placement
using screen/world conversion. Zero scale is legal for drawing; inverse queries
return False and the collapsed subtree is not pickable.

A sprite respects its shared image handle, matching ordinary Max2D drawing. Its
logical rectangle starts at `(-handle_x,-handle_y)`; the node's pivot supplies
an additional transform offset. Trimmed atlas content
retains its original logical placement. Text uses a local drawing origin and
actual glyph bounds, including negative bearings. Changing text does not
implicitly move the node's pivot.

The default draw order is parent self, then children in insertion order. Optional
sibling sorting can be enabled on any parent and uses `zIndex` followed by insertion order. Sorting is rebuilt
only when relevant structure or indices change. Non-spatial children sort as
z-index zero, with their subtree kept together. A composite occupies one
indivisible position in its parent's drawing order.

Independent render-order attachments are deferred.
The initial API does not let a child escape a composite, clip or camera boundary.
World-following overlays can use screen conversion to position a separate HUD
node. Adding independent render-order attachments later must preserve input and
compositing semantics.

## Rendering and custom drawing

`scene.Render()` uses the active Max2D target and its virtual presentation. It
does not clear, call `Flip`, poll events or advance time. It restores caller
state and the target view on success or failure. Scene drawing uses identity
caller object/parent transforms and explicit layer cameras; surrounding Max2D
transforms do not implicitly relocate the scene. The caller's existing viewport
is an outer clip that scene rendering cannot enlarge.

Each `TCustomDrawNode.OnDraw(context)` runs in node-local coordinates with its inherited
state applied. State changes cannot leak to siblings. Ordinary Max2D geometry,
image and text draw calls are supported. Changing the selected target, virtual
resolution or clearing the target in this hook is outside the contract.

`context.SetColor(r,g,b)` and `context.SetAlpha(a)` combine local values with
inherited tint/alpha. Custom nodes use those helpers when varying colour or
opacity. Raw Max2D `SetColor`/`SetAlpha` replace the effective values and bypass
inheritance; they must not be used to implement a conforming scene drawable.
Raw coordinate reset and camera replacement likewise bypass scene placement.
These restrictions are documented alongside the custom-node example.

Built-in nodes obtain bounds from their resources. Custom nodes implement
`GetSelfBounds` (return False when unknown), or set explicit local bounds.
Unknown bounds disable culling and automatic composite sizing; they do not mean
empty content. A composite containing unknown bounds needs `SetCaptureRect`.
Hit regions are supplied independently. Drawing cannot be replayed merely to
measure its bounds.

## Visibility, clipping and interaction

Visibility is inherited. Hidden subtrees do not render or receive input, but can
continue updating. Alpha zero does not itself disable picking: an application
can deliberately use an invisible hit region. Explicit `SetInteractive` and
`SetInputEnabled` control this independently.

The first release provides a **screen-space rectangular clip on each layer**.
It intersects the caller clip for rendering and the explicit scene input clip
for picking. Applications keep those outer clips matched for their interactive
presentation. A node's local hit
rectangle is exact under its inverse transform; its screen bounding box is only
a broad-phase optimisation. Composite `SetClipRect` supplies local rectangular
clipping under full affine transforms, limiting drawing and fresh picking through
the same outward-rounded region. `SetCaptureRect` alone limits output. Alpha-mask
stages optionally test explicit CPU coverage snapshots; transparent or
shader-displaced pixels do not automatically become exact hit regions. See [composite clipping](composites.md#local-rectangular-clipping).

### Pointer and keyboard dispatch

`DispatchPointer` accepts a pointer ID, kind, button state and a position already
mapped into scene virtual coordinates. Mouse and touch use the same model;
pointer IDs include their source/device identity. The default mouse adapter
suppresses synthetic mouse events generated from touches it already forwards.
A platform adapter converts native events using `TMax2DInputMapping`. The scene
never drains the application event queue or synthesises keyboard text input.

`SetInputClip` supplies the interactive presentation's outer clip in virtual
coordinates. Pointer hit testing is inactive until it is supplied. The application
updates it alongside its presentation viewport; Render never overwrites it. This
keeps input independent of offscreen previews or a different render target used
later in the frame. Pointer capture bypasses these clips for delivery, so native
adapters must continue forwarding unclipped move/up positions.

Hit testing visits eligible nodes in reverse draw order. An interactive node
uses its explicit hit region, or known self bounds by default; it does not
implicitly claim all of its children's combined bounds. Non-interactive
ancestors can still receive propagated events. Input-disabled subtrees are
skipped entirely. Picking observes committed live scene state; deferred tree
commands remain invisible until committed. Cached pixels do not replace the
underlying interactive subtree.

Events follow capture (root towards target), target, then bubble (towards root).
The path is fixed for one dispatch. `StopPropagation` stops subsequent path
visits; `Handle` marks the event handled and stops propagation, also preventing
application fallback handling. Dispatch returns
whether the event was handled. There is one overridable hook per phase, using
typed event objects rather than strings naming methods. Destroyed/pending-destroy
nodes are skipped on the remaining path. Event objects are immutable to callers
apart from dispatch-control methods and are borrowed for the current callback only. The scene reuses their storage;
call `Copy()` to allocate a durable data snapshot without dispatch-control methods.

Pointer capture is distinct from the event capture phase. During a pointer
callback, a node may claim that pointer ID. Subsequent move/up events route to
it even outside its hit region or layer viewport. Explicit release, pointer up
or cancellation ends capture. Detachment, hiding, input disablement, singular
transforms, destruction and application focus loss cancel affected captures.
Cancellation is delivered before detachment/exit. Multiple pointers can belong
to different nodes; virtual sticks and buttons must not steal each other's IDs.
Nodes moving under a stationary mouse cause enter/leave reconciliation at the
next `Update`; touch pointers do not produce hover events. Hover reconciliation
is suspended for a captured pointer and resumes when capture ends.

Focusable nodes opt in explicitly. Key events route through the focused node's
ancestor path. `FocusNext(reverse)` follows explicit focus order, with insertion
order as the tie-breaker; it skips hidden/input-disabled nodes. Loss of eligibility
clears focus and delivers focus-lost notification. A game can process unhandled
keys after dispatch. Widget-level navigation, text entry and modal focus scopes
remain separate future facilities.

## Composite nodes and effect stages

A `TCompositeNode` always isolates its subtree into an image, including with no
effects and caching disabled. Its presence is an explicit rendering boundary.
Turning caching on only changes reuse; it must not change rendering semantics.
Ordinary spatial groups continue drawing their children directly.

`SetAlpha` is inherited per-child alpha. `SetOpacity` on a composite applies
once to the flattened result. They are different operations: overlapping children
faded independently do not look like a finished group faded once.
Inherited tint/alpha are applied inside the
capture; changing them invalidates its pixels. Composite opacity is applied at
presentation and does not invalidate that composite's pixels.

The initial stage adapters are:

- `TSceneChainStage`: wraps `TMax2DEffectChain` with caller-specified logical
  padding. Raw effect descriptions retain their existing pixel/UV units.
- `TSceneBloomStage`: adapts `TMax2DBloom`, expresses radius in logical units,
  and selects a suitable retained blur pyramid at the requested resolution.
  Its output preserves transparency by default; opaque-black composition is explicit.

The stage interface includes bounds calculation, revision, storage estimation, preparation with actual-target support validation,
processing and release. Each attached stage owns its mutable processing storage
and belongs to one composite; sharing its configuration is separate from sharing
buffers. `SetStages` takes stages in order and owns them after successful
attachment. Removing/replacing stages releases their storage and detaches them;
callers may reuse the stage objects afterwards. A rejected replacement leaves
the old stage list intact.

`TSceneShadowStage` and `TSceneInnerShadowStage` explicitly return source plus
shadow, while the underlying helpers retain their shadow-only output contracts.
See [shadow stages](stages.md#soft-and-inner-shadows) for bounds, composition and
cache behaviour.

### Bounds and allocation

Content bounds are the union of visible drawable descendants in composite-local
coordinates, including nested composites' declared output bounds. The composite's
own world transform is outside this calculation. Each stage expands the preceding
bounds; padding accumulates in processing order. The initial adapters reserve
one common canvas covering every intermediate/output bound, so existing
same-size layer helpers can process it without changing coordinate origins
between stages. The initial stage interface does not support cropping or moving
the content origin between passes. Custom shaders must declare
conservative padding. Hit regions do not grow merely because a halo is visible.

Negative origins and fractional bounds are allowed. Round outward to whole
logical units for `TMax2DEffectLayer`; allocate at the explicit positive integer
resolution scale. Capture translates by the negative content-rectangle origin;
presentation restores that origin. Increasing padding must not move content.
A fixed `SetCaptureRect` chooses a stable content region; effect padding is added
outside it, and content outside the fixed region is clipped before processing.

The default scale is one; the application can select a higher scale based on
its display and camera needs. Moving or zooming does not silently resize caches.
A changed scale invalidates pixels and rescales logical-radius stage parameters.
Raw chain descriptors are never silently edited to rescale their parameters.

Preparation checks target dimensions, format, a configurable scene resource
budget and required capabilities. Budget accounting uses conservative texture
storage estimates, excluding driver alignment and allocation overhead. It allocates replacement storage before
releasing the old layout where practical, including temporary replacement memory
in budget checks. Failure reports the node and operation. Unsupported effects
never silently disappear. Retained output is invalid after a failed render;
previous storage may remain owned, but stale output is not presented as current.
Empty bounded subtrees produce no image or effect work unless a stage explicitly
supports generating output without source content.

### Cache invalidation

`ESceneCacheMode.None` captures and processes on each render.
`ESceneCacheMode.Automatic` reuses output until a tracked dependency changes.
Both produce the same intended pixels. The framework does not automatically
choose which subtrees to cache. A visible descendant composite with cache None
requires work each render, so an Automatic ancestor must refresh too. An ancestor
cannot freeze a descendant that explicitly requests uncached rendering.

| Change | Own composite | Enclosing cached composite |
| --- | --- | --- |
| Move/rotate/scale composite | Reuse local pixels | Invalidate |
| Change composite opacity | Reuse local pixels | Invalidate |
| Change inherited tint/alpha | Invalidate | Invalidate |
| Change descendant transform, visibility, order, text, image or frame | Invalidate | Invalidate |
| Change stage through its tracked setters | Invalidate processing | Invalidate |
| Change capture region, format or resolution | Reprepare and invalidate | Invalidate |
| Move camera with unchanged capture resolution | Reuse local pixels | Reuse local pixels |
| Edit an externally shared resource | Explicit invalidation required | Propagate invalidation |

Dirty state distinguishes transforms, bounds, content and effects. An effect-only
change can reuse the captured source when the required canvas layout is unchanged.
Changing padding or stage bounds requires recapturing into the new layout. The first implementation may conservatively
recapture more often; diagnostics must reveal that work. All node-owned tracked
state is private and changed through setters. Returning a mutable internal
transform or child array is forbidden.

`InvalidateContent()` is required after external image/mesh edits or changes to
custom drawing data. `InvalidateEffects()` is required after directly mutating a
raw effect description retained by a chain stage. Existing native texture upload
versions are not a complete resource-change contract. Automatic observation of
all resource edits is not promised. An animated custom node invalidates during
update; a time-driven raw shader invalidates its composite's effects each tick.

## Resource and context lifetime

Scene nodes can be created and updated without graphics. GPU storage is lazy.
A scene with prepared resources is bound to one live graphics context. Rendering
on another context requires `ReleaseResources()` first; that call preserves the
tree, node configuration and application resource references. Context closure
invalidates caches. Closed-context resources can be released, then recreated on
a new render. No graphics release happens in a GC finaliser.

The initial release does not maintain simultaneous caches for several contexts.
The same scene can render to different targets on its bound context; target
compatibility and views are checked on each render. Custom nodes participate
through `OnReleaseResources`. Scene-owned render images must not be retained in
application drawing-state scopes across resource release or reconfiguration.

## Diagnostics and performance contract

`InspectTree()` returns a developer-readable tree with paths, names, built-in node
categories, attachment, visibility, processing, dirty state and cached bounds. A debug overlay shows content/output
bounds and hit regions without changing picking. Per-render statistics include
nodes visited, nodes culled, local/world transform recomputations, bounds
recomputations, captures, stage passes, cache hits, owned texture bytes and
allocations. Discarded deferred commands are counted separately.

Unchanged transforms/bounds are reused. An unchanged cached composite performs
no capture or effect passes. The renderer must preserve ordinary Max2D batching
for adjacent compatible sprites. Public query methods may return snapshots;
hot traversal does not call allocating public snapshot APIs for every node.
The foundation retains child-array, traversal-stack and deferred-command capacity.
`Reserve` and `ReserveChildren` let loading code prepare capacity; removals do not
shrink it. `TrimStorage` explicitly trades spare memory for future regrowth.
Consumed reference slots are cleared, including exception paths. Nodes themselves
are never silently recycled while applications may still hold references.
Local/world matrices are inline numeric structs. `CopyLocalTransform` and
`CopyWorldTransform` fill caller-owned snapshots; the shorter snapshot-returning
queries deliberately allocate. Preserve-world reparenting uses the transform at
commit time.

Rendering and input retain sorting, picking, event-path and draw-state
storage. Input dispatch takes primitive values and borrows reusable callback
events. Nested synthetic events need separate retained slots. Do not create one
`ScopedMax2DState` per node: its current implementation allocates state objects.
Measure outer render/effect scope allocations separately before promising an
allocation-free complete frame. Application callbacks remain responsible for
their own allocations.

Allocation tests compare cumulative bytes from `GCGetStats` before/after warmed
loops, accounting for intervening collections. Heap size alone is not evidence
of allocation-free operation. Test growth and deliberate snapshot allocation
separately from steady-state traversal.

Pixel caches retain rendered images, not GPU rendering instructions.

Performance acceptance compares immediate drawing with equivalent uncached
scene sprites, and compares static, moving-parent and moving-child cached groups.
Record CPU traversal costs separately from backend submissions and texture work.
Culling only skips drawing; it does not suppress update callbacks. Unknown bounds
and unbounded custom drawing must not be incorrectly culled.

## Public API outline

The [API outline](api.md) lists the main methods used by the examples and
contracts above. It is a design reference, not module source. Core names and
semantics should be reviewed together before the first public module ships.

## Delivery and verification

| Delivery | Required evidence |
| --- | --- |
| Tree, lifecycle and affine math | Pure tests for cycles, reparenting with shear, singular inverses, readiness order, mutation during callbacks, exception cleanup and subtree destruction. |
| Basic rendering and custom nodes | Pixel parity with immediate drawing; inherited transforms/tints; font bearings and atlas trim; caller-state restoration; stable ordering; no render images for ordinary groups. |
| Pointer and focus routing | Reverse-order picking; nested transforms; layer clipping; event phases; two simultaneous drags; cancellation during removal and focus loss; stationary hover reconciliation. |
| Composite stages and caching | Padding/origin parity; group-opacity overlap; nested invalidation; external resource invalidation; empty/unknown bounds; allocation failure; context closure; zero capture passes on warm unchanged caches. |
| Developer-facing first release | Three runnable examples, bbdoc, usage guide, inspection/overlays, measured scene overhead, and backend matrix results. |

The worked scenarios are release requirements: reusable reactors with animated
plasma, simultaneous touch drags, and a camera world with independent HUD.
Input tests use injected pointer records so they do not depend on touchscreen
hardware; physical touch coverage is reported separately. Common rendering is
checked on SDL Renderer, OpenGL and SDL GPU. Native D3D9/D3D11 lighting has
separate coverage; this does not establish full scene-suite coverage on those
backends. See [validation](validation.md) for the recorded matrix. Tests must
report unsupported cases explicitly.

Later work can add saved scenes and registered factories, UI layout/widgets,
physics adapters, additional effect stages and independent
render-order attachments. Persistent IDs and serialization metadata remain
separate from optional names and runtime parent pointers. The first release
requires no reflection-based serializer, editor or asset pipeline.


## Development sequence

The next development cycle covers scenes, effects and lighting together. Each
part should retain documented capability fallbacks and include appropriate
examples, regression coverage and measurements. This is a roadmap, not a promise
that the listed extensions are already implemented.

| Order | Part | Scope and completion evidence |
| --- | --- | --- |
| 1 | Consolidation | Reconcile current guides and API status; document module/resource ownership and active fallback dependencies; remove unnecessary setup without removing supported paths. |
| 2 | Complete existing integration | Scene shadow/inner-shadow adapters, drawable/material coverage and trimmed-atlas support; demonstrate bounds, alpha, invalidation and resource lifetime. |
| 3 | Scalability | Spatial light selection, selective caster invalidation and GPU profiling; compare equivalent output and measured work before/after changes. |
| 4 | Developer conveniences | Scene animation, tilemap/particle adapters and a worked ECS integration; preserve optional imports and explicit ownership. |
| 5 | Broader rendering features | Specular maps, material flexibility and improved shadow geometry/softness, with backend capability reporting and fallback coverage. |

Consolidation has reconciled the stale scene/lighting descriptions and recorded
why the native, paired and ordinary lighting paths remain. The paired renderer
is created only when fallback is first needed. Shared package source locations
remain stable for existing application imports and generation scripts; their
cross-backend ownership is documented in the [shader guide](../shader-packages.md#shared-assets-and-module-ownership).

Part 2 has added source-plus-shadow and source-plus-inner-shadow stages with
a worked example and regression checks. Coordinate effects and lit sprites now
support trimmed byte artwork, normal maps and projected light textures through
retained full-size sampling storage, including grouped lighting and hard/filtered
shadows. `TLitNode` now shares receiver tracking between sprites and retained
`TLitCanvasNode` artwork, extending materials to text, meshes and custom drawing
as a flattened receiver. The canvas has explicit capture bounds, paint
invalidation and resource lifetime. This completes the planned Part 2 integration
scope. The subsequent material tranche adds direct lit meshes, described below.

Part 3 now includes optional retained spatial receiver selection and separate
query/rebuild diagnostics. Selective caster invalidation now preserves unrelated
point-light masks using old/new bounds and caster masks; directional shadows and
list replacement retain conservative invalidation. Optional asynchronous GPU
profiling now has OpenGL and Direct3D 9/11 providers, unreliable-sample accounting
and lighting-benchmark integration. The bundled SDL GPU API lacks timestamp
queries; its provider remains unavailable rather than substituting CPU timing.
This completes the planned Part 3 implementation on APIs that expose timestamps;
the benchmark reports separate functional timing coverage from performance evidence.

Part 4 begins with optional `Max2D.SceneAnimation`: retained parent-bound
transform/opacity timelines, explicit endpoints, easing, looping and seeking.
See [scene animation](animation.md) for ownership and the runnable example.
Optional tilemap and fixed-capacity particle adapters now cover scene transforms,
clocks, bounds and explicit shared-data invalidation; see [adapters](adapters.md).
The [ECS Swarm](../../demos/ecs_swarm/README.md) worked example completes part 4
with Flecs-owned simulation, pooled scene presentation and explicit teardown.

Part 5 begins with optional gloss strength in normal-map alpha, supported by
ordinary and native grouped lighting without another sampler or capture. A retained
material-map builder accepts separate normal/grayscale gloss artwork, with explicit
refresh and resource lifetime. Simple concave shadow outlines now use retained
triangulation and boundary-based projection, including finite heights and filtered
edges. This covers the initial part-5 scope and brings the five-part cycle to its
next survey. Separate specular-colour/roughness textures and further shadow-softness
improvements remain candidates for a subsequent cycle.

The subsequent capability review identified this progression:

1. Reconcile release documentation and extend scene/composition backend validation.
2. Add local scene clipping and masking with explicit transform, input and cache contracts.
3. Measure a representative combined workload, including long-running allocation behaviour.
4. Optimise the measured bottleneck, considering cached-subtree validation, lighting
   invalidation and retained rendering instructions where the evidence warrants them.
5. Extend material/shader capabilities, considering direct lit meshes and richer
   material channels.

The release review in step 1 is complete. Step 2 now includes local rectangular
composite clips with matching fresh picking, affine transforms, nested captures
and cache/resource integration. Local image-alpha stages now add soft/inverted
masking and optional CPU alpha picking, completing the initial step-2 scope. Live
scene-subtree masks remain a possible extension; they need separate dependency
and ownership rules. Step 3 is complete with a reproducible combined workload and
60,000-frame allocation runs on Metal and OpenGL; see the
[measurement report](benchmarks/2026-11-22-workload.md). Retained storage and
post-collection heap remained stable, while managed allocations continued.
Step 4 now reuses unchanged effect-chain prefixes: changing the final alpha mask
retains the preceding bloom output when the source and canvas are unchanged.
Explicit whole-chain invalidation and conservative source/layout/resource handling
remain available. Pixel parity and repeated combined-workload measurements cover
the change; see the [optimisation results](benchmarks/2026-11-22-stage-reuse.md).
This completes the initial measured optimisation step. Step 5 starts with
source-coloured emissive materials using existing ordinary and combined ambient
composition, with no additional passes or textures. Emission alone does not
complete that scope.
The textured-mesh foundation now adds normalized UVs, immediate drawing and
optional artwork on scene mesh nodes, including atlas/trim sampling and explicit
mutation invalidation. Direct mesh lighting now uses per-triangle UV-to-world mappings and the existing
ordinary and grouped material paths, including normal/specular maps, emission, textured lights
and shadows. `TLitMeshNode` integrates material dependencies and explicit geometry
invalidation with scene caching. Native grouped mesh lighting now combines eligible
lights and ambient per triangle, with explicit capability gating for older providers.
Emission and separate specular maps now extend the material API, using a dedicated
mapped ambient pass and retained normal/gloss packing respectively. Pixel edits
participate in scene cache invalidation. These complete the initial material-extension
step; independent GPU material samplers and whole-mesh submissions remain possible
follow-ups. See the [material map limits and validation](validation/2026-11-23-material-maps.md).
See the [direct lit mesh validation](validation/2026-11-23-lit-mesh.md) and
[grouped mesh checks](validation/2026-11-23-grouped-mesh.md).

Saved scenes, an editor and a full widget toolkit remain separate design decisions.
Backend correctness results and performance evidence remain distinct; timings
apply to the measured workloads and hardware.

## Capability review — 24 November 2026 (after shared-source preparation)

The earlier release progression is complete within its stated initial scope. The
subsequent optimisation progression has completed all five steps within the bounded
scope recorded below. Live subtree masks and their example now have macOS, Ubuntu
and native Direct3D validation. Large-tree CPU scaling remains a measurement gate.
The current result is an optional, code-driven 2D scene and composition toolkit. Applications
still own their loop, assets and simulation. The following review describes what
developers can rely on today, rather than treating proposed extensions as features.

### Current coverage

| Area | Available | Remaining boundaries |
| --- | --- | --- |
| Scenes | Trees, lifecycle, affine transforms, stable ordering, bounds, cameras, HUD layers, culling and inspection. | No saved-scene format or visual scene editor. |
| Interaction | Coordinate conversion, picking, pointer routing/capture, multitouch examples, hover and keyboard focus. | No complete widget/layout system, text editing or IME integration in the scene framework. |
| Composition | Retained buffers, automatic composite caches, local rectangular clips, image-alpha and live subtree masks, chains, bloom, shadows and inner shadows. Unchanged chain prefixes can be reused. | Live masks preserve ordinary picking and resolve dependency graphs on the CPU; cached pixels are not retained rendering instructions. |
| Animation and simulation | Transform/opacity timelines, tilemap and particle adapters, pooled ECS presentation example. | No general animation editor or integrated scene physics system. |
| Lighting | Ambient, point/directional and textured lights, receiver/caster masks, normal/specular materials, uniform/mapped emission, concave occluders and finite-height hard/filtered shadows. | No general SDF lighting facility or per-pixel specular colour/roughness channels. |
| Geometry | Textured meshes, direct shader drawing and lit mesh scene nodes. | Non-overlapping affine and deformed meshes support whole-mesh grouping within the 512-triangle analysis limit; unsupported cases retain ordered section/triangle fallback. |
| Diagnostics | CPU work counters, retained/peak storage, cache/shadow/map activity and optional GPU queries on OpenGL/D3D9/D3D11. | Bundled SDL GPU API has no timestamp-query provider; material and allocation measurements cover Metal/OpenGL, with platform correctness coverage recorded separately. |

The flattened `TSceneLightingStage` remains a simpler captured-image effect: it
does not expose occluders or per-object materials. Use `Max2D.SceneLighting`
receivers for those features. `TLitCanvasNode` can light captured custom artwork,
but the capture is one receiver, not independently shaded children.

### Rendering and material limits

Native grouping is opt-in and handles up to sixteen eligible lights per receiver
pass, or eight on native D3D9. Smaller groups use the eight-light shader;
unsupported cases fall back. This is not one draw for the whole scene, and more
lights can require more groups. Eligible first groups include ambient. Mapped
emission can join the first group alongside shadows and patterns using four-texture
shaders. Independent specular sampling uses five textures where supported. Smaller
transports and unsupported combinations retain combined or separate ambient and
packed-specular fallbacks. Signed floating-point emission on normalized targets
still uses a separate ambient pass to preserve clamping.

The shared map atlas is retained RGBA storage, currently 2048×2048 (16 MiB).
Native mapped groups accept maps up to 512×512. Larger maps and unsupported
formats use compatibility paths; atlas pressure can cause repeated map copies.
These are reasons to inspect counters before increasing light counts or map size.
See [renderer capabilities and fallbacks](../lighting-renderers.md).

Separate specular artwork supplies scalar highlight strength through independent
native sampling where supported, with retained CPU normal/gloss packing as fallback.
Normal and specular inputs must have matching logical dimensions when both are assigned and meet the documented CPU format
requirements. Render-target packing and automatic resampling are not supported.
Emission remains source-coloured: a bright emission map does not make black
source RGB glow. See [material usage and ownership](../lighting.md#emission-and-separate-specular-maps).

### Architectural boundaries

Composite caches retain rendered pixels. They do not retain GPU rendering
instructions. Lighting uses bounded native groups and ordered fallback passes;
additional groups require additional submissions. Eligible deformed meshes can
submit as whole meshes, while unsupported geometry retains ordered fallback.

Specular maps provide scalar highlight strength; separate specular-colour and
roughness maps are not implemented. Finite-height directional shadows shorten
with light elevation. Custom vertex/fragment/light programs and an automatically
generated scene distance field are not exposed by the scene lighting API.

Reusable subtrees are authored in BlitzMax. A scene editor, saved-scene format,
full UI toolkit and broader engine integration remain separate projects.

### Evidence and consolidation

The [native specular validation](validation/2026-11-23-native-specular.csv) and
[material refresh](benchmarks/2026-11-23-material-refresh.md) cover current material
paths and measured Metal/OpenGL workloads. Independent sampling removes CPU
packing from eligible edited maps; static maps show no consistent timing benefit.
Whole-mesh rendering reduces the measured 128-triangle, 17-light, both-map case to
two submissions on sixteen-light providers. Counts are not frame-rate guarantees.

The [state-reuse validation](benchmarks/2026-11-23-state-release-validation.md)
records 32 selected regressions across Ubuntu SDL GPU/OpenGL and Windows D3D9/11.
Metal and OpenGL each completed 60,000 combined frames with stable retained charges,
constant post-GC used heap, no new warm textures and successful cleanup. The
combined workload now allocates **224 managed bytes/frame**, down from 11,504;
cached and mask-only cases allocate 32. Remaining allocation preserves scope/stack
lifetime guarantees. This is workload evidence, not an allocation-free API promise.

Alternating baseline/current trials show about 6% lower combined CPU submission
on Metal in this sample. OpenGL ranges overlap; no general FPS improvement is
established. VM correctness results do not establish native-device performance,
and selected Ubuntu state regressions do not validate every new material shader.
See each report for exact backend, fixture and device coverage.

The ordinary, paired, eight-light and sixteen-light implementations still have
documented active roles. Generated shader sources, compiled binaries and embedded
assets also serve different build/runtime targets. This review identifies no safe
wholesale removal of those paths; it is not a whole-repository dead-code proof.
Any removal should first transfer its supported cases and regression coverage.

### Optimisation progression and completion status

The five-step plan below is retained as the scope of this cycle. Its current status:

| Step | Status | Evidence or remaining work |
| --- | --- | --- |
| 1. Measure materials/geometry | Complete | Baseline and completed-material refresh, including edited maps and geometry. |
| 2. Reduce mesh submissions | Complete within the bounded native path | Affine and general non-overlapping deformed meshes; conservative fallback remains necessary. |
| 3. Native material sampling | Complete within current material semantics | Independent emission and specular, combined mapped ambient, five-texture transport on the four native backends. |
| 4. CPU/GC costs | Allocation work complete and validated | 224 bytes per combined frame; instruction retention remains a separate, unproven optimisation opportunity. |
| 5. Composition usability | Complete within the live-mask scope | Live source dependencies, cycle checks, lifetime/input contracts and an interactive example; macOS, Ubuntu and native Direct3D checks pass. |

#### Live subtree masks: validated scope

`TSceneSubtreeMaskStage` now supports borrowed same-scene sources, normal/inverse
coverage, offsets, shared/nested dependencies and automatic cache invalidation.
Configuration rejects cycles; later tree changes that introduce cycles fail before
scene drawing. Detached/destroyed/other-scene sources supply empty coverage.
Picking remains unchanged, with no readback. See the [usage contract](stages.md#live-subtree-alpha-masks)
and [interactive example](../../examples/scene_subtree_masks.bmx).

Checks cover pixels, cache reuse, source changes, cycles, failure recovery,
resolution, storage budgets and context replacement. The additional
[platform matrix](validation/2026-11-23-live-mask-platforms.csv) records 28 passing
runs on Ubuntu SDL GPU/OpenGL and Windows D3D9/D3D11; see the
[environment and coverage notes](validation.md#live-subtree-masks--23-november-2026).
This closes the selected platform gate and this five-step cycle. Large dependency
graphs need their own CPU measurements before claiming scalability.

#### Consolidation and later priorities

Keep the ordinary, paired, three/four/five-texture and eight/sixteen-light paths:
capability negotiation and regression tests still exercise them. Keep generated
sources, compiled shaders and embedded assets until their build/runtime consumers
are replaced. Private retained state helpers serve different restoration scopes;
merging them requires preserving nested capture, target-view and failure contracts.
This inspection establishes active roles, not an exhaustive dead-code audit.

After masks, measure large stable subtrees with moving parents/cameras and edited
children before implementing retained rendering instructions. `TSceneRenderGroup`
is currently a capture/provider boundary; its name does not imply a command cache.
That extension can coexist with composite pixel caches and the public scene API.
Further material channels, SDF lighting, serialization, an editor, UI layout and
physics integration are separate feature projects. Broader physical-device and
Vulkan material coverage remain validation opportunities.

#### Next measured progression

The next useful investigation is CPU scaling of stable scene trees and live-mask
dependencies. Compare ordinary traversal with composite pixel caching using the
same artwork at 16, 256 and 4,096 nodes. Include idle frames, parent/camera motion,
one edited leaf, and a full edit. Separately vary mask-source size, shared consumer
count and dependency depth. Report preparation and submission time, captures,
stage updates, allocations, retained/peak storage and cleanup. Keep GPU execution
measurements separate where available.

Use those results to choose the implementation:

- If dependency preparation dominates, retain dependency adjacency/revisions and
  update affected consumers without repeatedly walking unchanged source subtrees.
- If stable-tree traversal or submission dominates, prototype optional retained
  rendering instructions with explicit invalidation and resource-lifetime rules.
  Preserve ordinary drawing, custom callbacks and pixel-cache composition as
  supported alternatives.
- If rendering dominates on the GPU, optimise the measured passes or shader work;
  reducing scene traversal alone will not resolve that cost.

This is a measurement gate, not a commitment to replace the scene renderer. The
remaining capability projects—richer material channels, SDF access, saved scenes,
editor tooling, full UI and physics integration—have different public contracts
and should be prioritised separately from this performance investigation.

#### Scaling measurement outcome

The [stable-tree and dependency baseline](benchmarks/2026-11-23-scene-scaling.md)
now covers all of the workload dimensions above. Two Metal runs and one OpenGL
run pass 56,160 measured frames of work/storage assertions. Metal repeats identify
shared unchanged mask-source traversal as the immediate CPU target: sixteen
consumers of a 4,096-node source spend about 449–454 µs in preparation despite
zero captures and stage updates. OpenGL timing was noisy under background load;
its correctness and allocation results agree, but no backend speed comparison is
claimed. The [shared-source follow-up](benchmarks/2026-11-24-source-preparation.md)
now reuses successful walks within each render attempt. Two alternating Metal
comparisons reduce preparation for this case to about 37 µs and CPU submission
from about 466–467 µs to 45 µs, with unchanged captures, stages and allocations.
Single-source bookkeeping costs slightly more; each node retains 16 bytes of
additional fields. Lifecycle, continuous-source, cycle and retry regressions pass.
Distinct source nodes still require one walk per render; retaining dependency
topology across frames and sharing captured pixels remain separate opportunities.

#### Original five-step scope

1. **Measure current materials and geometry.** Extend the reproducible workload
   with mapped emission, shared/edited specular maps and increasing triangle counts.
   Separate submission count, packing/uploads, managed allocation and GPU time where
   available. Include warmed and invalidated cases, with cleanup accounting.
2. **Reduce mesh submission overhead.** Design whole-mesh lighting around those
   results, preserving UV-to-world mappings, transformed normals, transparency and
   backend capability fallback. Compare pixels and counts before claiming a gain.
3. **Extend native material sampling.** Consider independent specular/emission
   sampling and combined mapped ambient on capable providers, retaining the current
   packing fallback. Specify sampler limits, ownership and new material semantics
   before adding colour or roughness channels.
4. **Address measured scene CPU/GC costs.** Attribute remaining allocations and
   stable-subtree traversal. Prototype retained instructions only if that workload
   justifies their invalidation and resource-lifetime complexity.
5. **Complete a composition usability pass.** Specify live subtree masks, cycle
   detection, cross-subtree invalidation and picking, then build a worked example.
   Keep saved-scene/editor design separate from this bounded rendering cycle.

Reassess after these steps using the same workloads. Higher light limits alone
should not substitute for less submitted work or a simpler developer workflow.

### Implementation history

The entries below record each tranche at the time it landed; later entries
supersede their temporary limits and next-step statements. Use the capability
review and completion table above for current status.

Step 1 now has a [material and geometry baseline](benchmarks/2026-11-23-material-geometry.md)
on Metal and OpenGL, plus a separate OpenGL GPU-query run. Fixed-area meshes expose
submission/allocation growth per triangle; unchanged shared maps reuse storage,
while edits upload once per frame. Isolated CPU packing measurements cover 64×64
and 256×256 inputs. Pixel comparisons and cleanup checks accompany all trials.
The results support proceeding to whole-mesh lighting in step 2; they do not
establish performance on unmeasured backends or replace the earlier scene soak.

Step 2 now has an [initial affine whole-mesh path](benchmarks/2026-11-23-affine-mesh.md).
Eligible non-overlapping meshes with a shared UV mapping are drawn once per light
group on opting-in providers. Exact basis checks, a 512-triangle analysis bound
and retained value snapshots preserve conservative fallback and direct array edits.
The fixed-area 128-triangle/17-light case falls from 256 submissions to 2 and from
4,096 managed bytes/frame to 32 on Metal and OpenGL. General deformed meshes still
need varying geometry/material transport; step 2 remains open for that work.

Step 2 also groups [consecutive affine sections inside deformed meshes](validation/2026-11-23-mesh-sections.md).
Sections retain independent normal bases and index order, including overlap between
sections. A 128-triangle bent strip with eight sections and 17 lights needs 16
grouped passes on sixteen-light providers, versus 256 through the triangle-only
provider. The eight-light counts are 24 versus 384. This extends the existing
capability without a shader ABI change. Arbitrary deformation with a different
basis on every triangle still needs richer geometry/material transport; step 2
remains open. Geometry edits now rebuild section analysis, so animated workloads
need separate timing measurements before treating submission savings as a frame-time gain.

The next preparation tranche caches each triangle's local mapping and reuses
non-overlap proofs inside earlier sections when UV/index data stays unchanged.
[Focused CPU measurements](benchmarks/2026-11-23-mesh-preparation.md) address the
geometry-edit analysis cost above. Shader transport and all-or-nothing fallback
negotiation for arbitrary whole-mesh submissions remain unfinished; this tranche
does not change native shader capabilities or submission counts.

Step 2 now includes a [general non-overlapping deformed-mesh path](benchmarks/2026-11-23-deformed-mesh.md).
Native providers reconstruct lighting position and per-triangle normal bases in
the fragment shader, using the existing vertex layout. The processor selects
lights against complete receiver bounds and preflights all groups before drawing.
Unsupported combinations, overlapping geometry and meshes above 512 triangles
retain ordered section/triangle fallback. Ambient-only and mapped-emission paths
remain supported, and provider failures after submission propagate without redraw.

This completes the bounded whole-mesh progression for the existing native
backends; it does not remove fallback or the analysis limit. The 128-triangle,
17-light mapped-emission workload needs three submissions versus 384 with a
triangle-only provider. CPU and drained-draw timings cover warm and edited
geometry on Metal/OpenGL; the report separates these from GPU-only timing and
platform correctness. The next planned step is native material sampling: independent
specular/emission sampling and combined mapped ambient where provider limits allow.

Material preparation now follows direct-light selection. Ambient/emission-only
receivers skip normal/specular resolution; grouped receiver calls reuse their
resolved material instead of asking the packer twice. This removes unnecessary
preparation and defers pending packing updates until a light reaches the receiver.
Independent native specular/emission samplers and combined mapped ambient remain
the next part of step 3; the current three-texture transport is unchanged.

[Material-selection validation](validation/2026-11-23-material-selection.csv)
passes 121 material-map and 366 mesh checks on Metal/OpenGL and D3D9/D3D11
(the Windows runs use x64 applications under ARM64 Parallels). The new checks
cover unused locked maps, empty/excluded/distant lights, selected-map rejection,
drawing-state restoration and recovery across sprites, affine and deformed meshes.

Step 3 now includes native independent emission sampling during combined ambient
composition. The first group can use emission artwork in the third texture binding
when none of its lights needs a shadow/pattern map. Other groups can still use the
light-map atlas. Incompatible first groups and older providers retain separate
mapped ambient. Eligible sprites, affine meshes and general deformed meshes save
one submission per receiver without reducing light capacity or allocating another
material texture. Normal/gloss packing remains in place.

The provider contract adds optional `MappedEmission()` support, defaulting to
False; application materials and scene APIs are unchanged. The native shaders use
64/112 float4 slots and three textures, with the third binding selected per group.
Independent specular sampling and simultaneous emission/light-map sampling remain
unfinished and require further texture-transport work. This completes the first
native material-sampling case, not all of step 3.

[Mapped-ambient validation](validation/2026-11-23-mapped-ambient.csv) records 184
new pixel/count/recovery checks, plus the existing 121 material-map, 366 mesh and
1,049 emission checks on Metal, OpenGL, D3D9 and D3D11. Windows results use x64
applications under ARM64 Parallels. The new suite compares against a provider
using the same native shaders with mapped composition disabled. It covers
RGBA/A8, filtering, atlas/trimmed artwork, premultiplied render images, HDR targets,
signed floating-point emission fallback on normalized targets, light-map conflicts,
disabled/excluded lights, warm texture reuse and feedback recovery. Eligible
17-light receivers save exactly one submission: three to two with sixteen-light
groups, four to three with eight-light groups. These counts are not frame-time
measurements. Shader source/embedded-asset reproducibility also passes; SPIR-V
was compiled, with no Vulkan runtime validation claimed.

The next transport tranche adds a counted auxiliary-texture interface and an
explicit total-texture upper bound to shader adapters. Native lighting uses this
interface with a retained binding array, and validates frame ownership, lifetime,
count and destination feedback before provider selection. Existing provider hooks
remain compatible through default forwarding. Extended providers can override the
binding hook without changing the caller's submission shape. This is preparation
for additional material samplers; built-in native bindings still support three
textures, and the outstanding independent-specular/emission-plus-light-map work
remains unchanged. See [texture-binding transport](../lighting-renderers.md#texture-binding-transport).

[Binding validation](validation/2026-11-23-texture-bindings.csv) passes 19 interface
checks and all 184 mapped-lighting checks on Metal, OpenGL, D3D9 and D3D11
(Windows uses x64 applications under ARM64 Parallels). Interface checks exercise
legacy forwarding, rejection before selection, active-prefix handling, frame
ownership/lifetime, destination feedback, duplicate images and caller array reuse.
A mock five-texture provider verifies the extension hook; this is not native
five-texture rendering or a performance measurement.


The next native transport implementation extends OpenGL to five total textures.
A counted native material ABI supplies per-binding coverage/premultiplied modes
and render-target orientation. Bindings are copied before selection returns;
shader-specific count mismatches and destination feedback preserve the previous
selection. Sampling state is restored once per distinct texture, including
aliases. The adapter reuses its native pointer array, with no per-selection array
allocation. Existing public effect packages and three-texture lighting retain
their layouts.

This completes the OpenGL transport portion of the material-sampling work. SDL
GPU and Direct3D transport extensions, simultaneous emission/light-map shaders
and independent specular sampling remain outstanding. The application-facing
lighting API is unchanged. This tranche does not claim fewer lighting draws or a
frame-time improvement.

[OpenGL transport validation](validation/2026-11-23-gl-texture-set.csv) records
108 native five-texture checks across two graphics-context lifetimes, 19 binding
checks, 184 mapped-emission checks, and the existing texture-effect and public
shader-package suites. The new pixel checks cover RGBA/A8 modes, render-target
orientation, restored mip/filter settings, repeated/source aliases, caller-array
reuse, fifth-slot feedback rejection and shader-count failure recovery. These
results are macOS OpenGL only; the other backends are unchanged.


SDL GPU now implements the same five-texture native material transport. Each
queued draw snapshots all auxiliary bindings and sampling modes together with
its parameters. The retained arena handles both large parameter blocks and
single-vector multi-texture shaders; single-texture built-ins retain inline
uniform storage. Selection validates the complete set before changing state,
and the adapter reuses its native pointer array. This extends the shared SDL GPU
command path without changing public effect packages or application materials.

[SDL GPU transport validation](validation/2026-11-23-gpu-texture-set.csv) records
3,132 native checks on macOS Metal, plus 19 binding checks, 184 mapped-emission
checks and the public shader-package suite. The native test covers RGBA/A8,
render-image rows, repeated/source bindings, count/feedback rejection, caller
array reuse and recovery. Alternating five-texture and small two-texture draws
exercise mixed parameter sizes and arena growth, followed by reuse, across two
graphics-context lifetimes. The fixture contains Metal shaders; Vulkan and SDL
GPU's D3D runtime are not validated by this test.

Direct3D 9/11 native binding extensions and the lighting shader/material changes
remain outstanding. Lighting continues to use three textures, so simultaneous
emission/light-map sampling and independent specular sampling are not enabled yet.


Direct3D 9 and 11 now implement five-texture native bindings through the counted
entry point. The adapters reuse their native pointer arrays, upload/restore each
active image through the existing context lifecycle, and reject shader-count
mismatches before changing selection. Native selection copies parameter values
and texture pointers. Both backends clear all five resource slots during target
transitions, including when a fourth/fifth sampler becomes a render destination.
D3D9's material ABI places each texture's allocation scale after the parameter
block; existing public package and lighting layouts are preserved.

This completes the five-texture transport implementations for all four built-in
native lighting backends. The lighting shaders still use three textures. The
next material work is simultaneous emission/light-map sampling, followed by
independent specular sampling; those features are not enabled by transport
capacity alone. D3D9 retains its eight-light group limit.

[Direct3D transport validation](validation/2026-11-23-d3d-texture-set.csv) passes
60 native five-texture checks, 19 binding checks and 184 mapped-emission checks
on each of D3D9 and D3D11, plus the existing public shader-package and texture-map
suites. The new checks cover RGBA/A8, render-image orientation, repeated/source
aliases, caller-array reuse, shader-count and feedback rejection, ordinary-draw
recovery, and a fifth-slot texture becoming a destination and returning to
sampling. Both profiles run x64 applications under Windows 11 ARM64 Parallels;
these are correctness results, not native Windows performance measurements.


The native material shader now samples mapped emission independently of the
shared shadow/pattern atlas. Eligible first groups therefore combine ambient,
emission and direct lighting even when lights use shadows or projected patterns,
saving one receiver submission compared with separate mapped ambient. Eight- and
sixteen-light variants use 67/115 float4 slots and four textures; D3D9 keeps its
eight-light limit. Direct-only groups retain the existing smaller three-texture
shaders. The renderer reuses its binding array and parameter storage.

Three-texture adapters and unavailable material shaders retain the earlier
combined-emission path for groups without light maps, or a separate ambient pass
where necessary. Signed floating-point emission on normalized targets keeps its
separate-pass clamping. Public materials, scene APIs and effect-package schemas
are unchanged. Independent specular sampling remains outstanding: separate gloss
artwork still uses CPU packing into normal alpha.

[Mapped light-material validation](validation/2026-11-23-mapped-light-material.csv)
records 724 pixel/pass-count/recovery checks per backend on Metal, OpenGL, D3D9
and D3D11. The suite compares combined rendering against separate mapped ambient,
including sprites, affine and deformed meshes, native A8/RGBA, atlas/trimmed and
render-image emission, HDR, saturation, shadows and projected patterns together,
feedback recovery and warm texture reuse. It also forces a three-texture adapter
and unavailable four-texture shaders to verify fallback. Eligible receivers save
exactly one submission: for 17 lights, three to two with sixteen-light groups,
or four to three with eight-light groups. These are submission counts, not
frame-time measurements. Windows runs x64 applications under ARM64 Parallels.
SPIR-V assets compile, with no Vulkan runtime result claimed. The reproduction
test covers both capacities and both texture layouts.

### Independent specular-map negotiation

Lighting providers can now advertise `MappedSpecular` and receive original
normal/specular images through the reused draw description. Separate artwork
uses RGBA red or A8 alpha and overrides normal-alpha modulation. Accepted groups
avoid CPU packing. Rejected combinations retry the same provider with retained
packed normal alpha before ordinary fallback. Original references are restored
between groups and cleared on completion or error; failed draws are never
retried. Deformed meshes preflight both representations. Existing providers
keep their previous material resolution before drawing, and the default
capability remains disabled.

The [specular negotiation validation](validation/2026-11-23-specular-negotiation.csv)
records 339 contract checks each on Metal and OpenGL, plus 121 material-map and
724 mapped-emission checks on Metal. The contract probe holds gloss pixels
locked to detect accidental packing in accepted groups, and covers rejection,
mixed representations, normal-less materials, sprites, affine/deformed meshes,
and draw-failure recovery. It verifies negotiation rather than independent
specular shader output. No Windows runtime or performance claim is made for
this tranche.

Built-in native lighting still packs gloss. Five-texture native material shaders
are the next integration step; application map validation retains the current
CPU-format and matching-dimension restrictions to preserve fallback support.

### Native independent specular sampling

The native renderer now samples separate gloss artwork with a fifth texture,
alongside source artwork, normals, the shared shadow/pattern atlas and emission.
Eight- and sixteen-light variants use 70/118 float4 slots; light capacities are
unchanged, including eight on D3D9. Gloss is sampled once per fragment before the
light loop. Accepted independent requests avoid derived CPU packing and its
upload. Binding arrays and parameter storage remain reused.

Four-texture transport limits and unavailable five-texture shaders retry packed
normal alpha. Differing normal/gloss filtering settings retain packing, preserving
the established gloss-filtering behavior for both channels. Custom normal
strength without normal artwork also retains packing to preserve scaling of the
byte-encoded flat normal. Locked maps remain rejected, including when their GPU
textures are already cached. Application map validation and public effect-package
schemas are unchanged; render-image gloss and differently sized normal/gloss maps
remain outside the current material API.

[Native specular validation](validation/2026-11-23-native-specular.csv) records
279 pixel/path/storage checks each on Metal and OpenGL, and 252 each on D3D9 and
D3D11. The additional 27 checks for custom flat-normal strength were added after
the Windows run and verified on Metal/OpenGL. Comparisons cover sprites, affine
and deformed meshes, RGBA/A8 and atlas gloss, filtering, normal-alpha override,
normal-less materials, zero specular, HDR, emission, projected patterns and
occluder shadows together. Forced four-texture limits and missing shaders verify
fallback, while warm draws create no textures. Existing material tests pass 121
checks each on Metal, D3D9 and D3D11, including pixel edits and locked-map recovery.
Windows runs x64 applications under ARM64 Parallels; these are correctness checks,
not performance measurements. SPIR-V compiles but has no new Vulkan runtime claim.
All six generated variants reproduce their source and embedded assets exactly;
the existing three/four-texture assets are unchanged.

### Completed-material measurements and scene allocation attribution

The [material refresh](benchmarks/2026-11-23-material-refresh.md) compares native
specular sampling against forced packing in the same current renderer on Metal
and OpenGL. Edited shared 256×256 gloss reduces median CPU submission from
591.06 to 104.64 µs on Metal and 663.20 to 180.18 µs on OpenGL. Edited materials
allocate 144 fewer managed bytes/frame; uploads remain once per frame. Static
maps show no consistent timing benefit. Both-map 128-triangle meshes retain two
submissions and 32 managed bytes/frame, including when packing is forced. These
results separate recent whole-mesh/ambient savings from the gloss-sampling change.

Step 4 now has phase-level allocation measurements. All measured scene allocation
is in rendering: editing, lighting preparation and picking allocate zero in this
workload. Isolated probes account for the cached scene's 624 bytes/frame as a
368-byte drawing scope plus eight 32-byte cached text draws. The first targets are
reusable internal render-state snapshots and allocation-free layout-cache hits,
with public scope lifetime guarantees preserved. Retained instructions remain a
separate response to measured traversal/submission costs. No production allocation
optimisation or new long soak is claimed by this measurement tranche.

### Retained drawing-state snapshots

Scene, render-group and diagnostic-overlay boundaries now reuse internal snapshots
while restoring into the caller's original drawing-state object. Public scopes
keep their one-shot lifetime and outer-unwind behavior. The
[allocation follow-up](benchmarks/2026-11-23-state-reuse.md) measures 32 bytes per
empty/sprite scene render, down from 368, on Metal and OpenGL. The cached workload
falls from 624 to 288 bytes/frame; changing lighting and combined cases save
672 bytes/frame. Remaining cached allocations are the stack link and eight text
layout-cache updates. This completes the first production allocation improvement
in step 4; text-cache bookkeeping and further lighting/effect attribution remain.

### Allocation-free text-cache hits

Bitmap and scalable fonts now share cache helpers that retain and reposition list
entries through a bounded key-to-link index. Warm hits allocate zero bytes without
scanning the eviction list. LRU eviction, capacity changes and held-layout lifetime
remain intact. The [text-cache measurements](benchmarks/2026-11-23-text-cache.md)
show the cached workload falling from 288 to 32 bytes/frame on both Metal and
OpenGL, and another 256 bytes/frame removed from changing mask/lighting cases.
Across both step-4 improvements the cached baseline is down from 624 to 32 bytes.
The drawing-state stack link remains, alongside larger allocations inside changing
lighting/effects that still need attribution.

### Render allocation attribution and simpler alpha masking

Optional workload instrumentation now separates lit-receiver, bloom and alpha-mask
allocations from other render work. The
[attribution report](benchmarks/2026-11-23-render-attribution.md) identifies
5,568 bytes/frame in lit-receiver draws (including lazy shadow work), 2,736 in bloom
and 1,472 in masking during redraws. Removing two redundant nested mask scopes
halves the mask stage's allocation to 736 bytes/update, with caller restoration
and failure recovery preserved. Metal/OpenGL combined workload allocation falls
from 10,576 to 9,840 bytes/frame; the cached case remains 32. Receiver and bloom
allocation remain the larger targets for step 4.

### Effect view snapshots and allocation-free provider lookup

Effect-provider lookup now walks existing links without allocating an iterator,
while preserving registration order and first-match selection. Internal effect
passes preserve target views with value snapshots inside the existing outer state
scope. The [follow-up measurements](benchmarks/2026-11-23-effect-view-reuse.md)
reduce receiver allocations from 5,568 to 1,472 bytes/frame and bloom from 2,736 to
1,104 in the workload. Combined allocation falls from 9,840 to 4,112 bytes/frame
on Metal and OpenGL. Pixel, target-view and injected-failure restoration checks pass;
remaining outer-scope and lazy-shadow allocations still need further attribution.

### Retained light-atlas copy state

Native lighting atlas copies now use a retained drawing-state object and restore
the caller's original state and target in `Finally`. The atlas is already required
to be distinct from the caller target, so the copy never changes the caller view.
The [atlas follow-up](benchmarks/2026-11-23-atlas-state-reuse.md) verifies zero
allocations across 1,000 warm copies, including retry after failure. Receiver
allocation falls to 736 bytes/frame and the combined workload to 3,376 on Metal
and OpenGL. Shadow rendering's own scopes remain the next receiver target.

### Retained shadow-map drawing state

Shadow rebuilding now uses a private retained drawing state and restores the
caller state and target after success or failure. Hard/soft point and directional
shadows and point-light patterns pass restoration checks on Metal and OpenGL.
The [shadow follow-up](benchmarks/2026-11-23-shadow-state-reuse.md) reduces measured
receiver allocation from 736 to zero bytes/frame and combined allocation from
3,376 to 2,640. Soft filtering retains its existing blur scope; bloom, masking
and other render-stage scopes remain the next allocation targets.

### Retained bloom and scaled-blur drawing state

Bloom and scaled blur now retain private drawing state while preserving each
output view with the existing per-pass snapshots. Runtime-failure, retry, selected
output-target and nested-provider restoration checks pass on Metal and OpenGL,
alongside native pixel regressions. The
[processor follow-up](benchmarks/2026-11-23-processor-state-reuse.md) reduces bloom
allocation from 1,104 to 368 bytes/update and combined allocation from 2,640 to
1,904 bytes/frame. Extraction's scope and alpha masking remain the next targets.

### Retained chain and mask drawing state

Buffer-owned effect chains now reuse private drawing state through the same
implementation as standalone layer chains. Alpha-mask stages reuse state when
the caller target is distinct, keeping full view restoration for selected owned
outputs. The [chain/mask follow-up](benchmarks/2026-11-23-chain-mask-state-reuse.md)
reduces bloom allocation to zero, masking to 368 bytes/update and combined
allocation to 1,168 bytes/frame on Metal and OpenGL. The remaining layer-alpha
scope and attribution of other render work are next.

### Allocation-free layer-alpha passes

Alpha masks, inverse masks and opacity passes now preserve their drawing fields
and target view with private value snapshots. The
[layer-alpha follow-up](benchmarks/2026-11-23-layer-operation-state.md) measures
zero allocation across 3,000 warmed calls and reduces combined scene allocation
to 800 bytes/frame on Metal and OpenGL. Receiver, bloom and mask-update components
are zero. Additional instrumentation assigns 368 bytes to mask preparation when
its rectangle changes; the remaining 432 bytes during recapture match capture
and scene-scope bookkeeping. Mask validation and capture are the next targets.

### Mask validation and capture state reuse

Mask capability checks now restore only the target they change. Effect-layer
capture reuses private saved/working drawing state while retaining a fresh public
handle and saved entry for every call. Stale handles after close or outer unwind
cannot affect a later capture. The
[capture follow-up](benchmarks/2026-11-23-capture-state-reuse.md) measures 160 bytes
per capture and 224 bytes/frame for combined redraws, with cached and mask-only
frames at 32. Native composition and lifecycle tests pass on Metal and OpenGL.
Remaining allocation is scope bookkeeping; broader platform, lifecycle and timing
validation is the next gate.

### State-reuse validation gate

The [cross-platform and timing review](benchmarks/2026-11-23-state-release-validation.md)
passes 32 selected VM regressions across Ubuntu SDL GPU/OpenGL and Windows
Direct3D 9/11. Metal and OpenGL each complete a 60,000-frame combined soak at
224 bytes/frame, with unchanged retained charges, constant post-GC used heap and
successful cleanup. Alternating baseline/current trials show roughly 6% lower
Metal combined CPU render submission in this sample; OpenGL ranges overlap and
there is no general frame-rate claim. This closes the allocation validation gate;
a renewed scene/lighting/effects survey should guide the next priorities.


### Selected-subtree capture foundation

Step 5 now has `TSceneGroupContext.RenderSubtree`, a provider primitive for drawing
a same-scene source independently of its ancestors into a selected capture target.
It retains the source's own transform and visual properties, rejects active-group
cycles before drawing, restores state after failures and supports nested composite
caches. See [capture semantics](composites.md#capturing-a-selected-subtree).

This completes the capture foundation only. The live-mask stage, automatic source
dependency invalidation, configuration-time cycle checks, lifetime/picking contracts
and interactive example remain open. Existing image-alpha masks are unchanged.

[Capture validation](validation/2026-11-23-subtree-capture.csv) records 68 new
checks on each of macOS Metal and OpenGL, plus 65 composite, 56 image-alpha-mask
and 22 culling checks per backend. Existing 100-frame cached composite/culling
probes remain at 3,200 managed bytes. Windows/Linux profiles are registered but
were not run for this tranche; no new throughput claim is made.


### Live subtree mask implementation

The capture foundation now supports `TSceneSubtreeMaskStage`, dependency preparation
before drawing and visual revisions including source placement and composite
presentation. Shared/nested source edits refresh cached ancestors without recapturing
unchanged consumer artwork. Registry membership follows scene attachment and
destruction. Normal/inverse masks use two budgeted targets; source ownership and
ordinary picking are preserved. An interactive reveal/cutout example accompanies
the stage. See [live-mask usage](stages.md#live-subtree-alpha-masks).

[Live-mask validation](validation/2026-11-23-live-subtree-masks.csv) records 39
new checks per backend on macOS Metal/OpenGL, plus the subtree-capture, composite,
image-alpha-mask, culling and storage regressions. Both console example smoke
runs complete three frames; both GUI builds were inspected visually, including
Metal pause, detach/reattach and buffer recreation. Warm cached live-mask renders
allocate 3,200 managed bytes per 100 frames, with no extra dependency-preparation
allocation beyond scene scope links. This does not measure changing-mask allocation
or large-graph CPU cost. Windows/Linux live-mask runtime coverage remains pending.


### Live-mask platform review

Ubuntu SDL GPU/OpenGL and native Windows D3D9/D3D11 pass all 28 selected runs:
1,094 assertions plus four example smoke runs. Warm cached live masks remain at
3,200 managed bytes per 100 frames. The [platform review](validation.md#live-subtree-masks--23-november-2026)
records compiler sources, environment and coverage limits. This supersedes the
pending Windows/Linux coverage above and closes step 5. The current capability
review retains the material, renderer, input and tooling boundaries; the next
measured progression investigates stable-tree and dependency preparation costs.
