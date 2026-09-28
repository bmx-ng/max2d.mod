# Image collisions

Collision support is part of `Max2D.Core` and uses CPU alpha masks. SDL and GL use
exactly the same implementation. Pairwise checks also work without a graphics
window: the default transform is then identity. Positions and explicit transform
parameters accept Double values, including ordinary Int/Float arguments.

```blitzmax
If ImagesCollide(player,x,y,frame,enemy,ex,ey,enemyFrame) Then
    ' Respond to the collision.
End If

Local hit:Int=ImagesCollide2(player,x,y,frame,rotation,scaleX,scaleY, ..
                           enemy,ex,ey,enemyFrame,enemyRotation,1,1)
```

`ImagesCollide` applies the current affine transform to both images, including
shear/reflection, plus origin and each image's own handle. `ImagesCollide2` uses
its separate rotations/scales and the current origin, without modifying drawing
state. Neither call reads, resets or writes any collision layer.

## What “pixel collision” means

- A source pixel is solid when its alpha is **at least 128**, as in BRL.
- Collision samples lie at `(integer + 0.5, integer + 0.5)` in virtual/world
  coordinates. Each sample is inverse-transformed into each image; its containing
  source pixel is sampled without filtering. Edge contact without overlapping
  area is not a collision. A collision requires a solid sample
  in both shapes. Local image bounds are half-open.
- This is raster collision, not continuous polygon intersection or swept collision.
  A small/subpixel overlap containing no sample centre is not a collision. Fast
  objects may need movement substeps or a separate continuous collision system.
- Virtual presentation scale, DPI, viewport clipping, drawing colour/alpha and
  blend mode do not alter collisions. Moving between displays cannot change a hit.
- Handles, frame selection and atlas/nested-view offsets are respected. Atlas
  padding and neighbouring sprites are excluded.
- Zero-scale/singular transforms and nonpositive rectangle dimensions are empty.
  Nonfinite/out-of-range geometry is rejected; grid bounds must fit signed Int.

BRL's legacy scanline rounding is not reproduced bit-for-bit. GPU/software
triangle rasterizers can also choose different edge texels, and filtered drawing
can visibly soften a binary mask. Collision semantics deliberately stay fixed
across backends. The tests compare arbitrary rotated silhouettes exactly with GL;
SDL software has two edge-only differences in the current 25-position fixture.
Its definite interior overlaps and separated silhouettes agree. Independent CPU
checks verify the sample rule, scanline pruning and symmetry.

## Collision layers

```blitzmax
ResetCollisions()
CollideImage(enemy,ex,ey,0,0,COLLISION_LAYER_1,enemyObject)
Local hits:Object[]=CollideImage(player,x,y,0,COLLISION_LAYER_1,0)
```

`CollideImage(image,x,y,frame,collidemask,writemask,id=Null)` tests existing entries
first, then inserts the current shape into every selected write layer.
`CollideRect(x,y,w,h,collidemask,writemask,id=Null)` uses an opaque rectangle with
the current affine transform and origin. Following BRL, rectangles ignore the
primitive `SetHandle`; image collisions use their image handle.

There are 32 constants, `COLLISION_LAYER_1` through `COLLISION_LAYER_32`. Masks can
be combined with bitwise OR. `ResetCollisions(mask=0)` clears selected layers;
zero/`COLLISION_LAYER_ALL` clears all. For **query/write masks**, zero selects
nothing; `-1` selects all 32 bits.

Results are Null when there are no hits; otherwise they contain the stored ids,
including Null ids. Order is ascending layer number, newest insertion first
within each layer. The same entry written into multiple layers appears once per
matching layer, and separate insertions remain separate. Results are not deduplicated.

The familiar functions use one global world, like BRL. Reset it at the start of
each collision-registration pass or when unloading a scene. It is not reset by
`Cls`, `Flip` or closing a window. Unlike BRL's pairwise implementation, layer 32
is fully available to your application.

Advanced users can create independent `TCollisionWorld` instances. Construct
`TCollisionShape.Image(...)` or `.Rect(...)` with an optional `TMax2DState`, then
call `world.Collide(shape,collidemask,writemask,id)` and `world.Reset(mask)`.
Shape constructors default to identity rather than reading global drawing state.
Treat constructed shapes and their mask data as immutable.

## Edits, caching and resource ownership

Each CPU image source has a lazy packed alpha mask (one bit per source pixel),
shared by its frames/views. Repeat queries reuse it. Write-lock/unlock and atlas
updates advance the source version; the next new shape rebuilds the mask.
Writing directly through internal pixmap fields bypasses version tracking and
is unsupported. Collision queries on an image with an active write lock throw.

Layer insertions capture both geometry and alpha. Editing the image, changing its
handle, or changing drawing state afterwards does not change the stored entry.
Reset/reinsert to update it. Old mask snapshots remain alive only as long as their
shapes are retained. They do not retain native texture resources.

Masks currently rebuild across the whole shared source when it changes. Broad-
phase bounds and row intersections prune sampling, but dense overlaps may still
require many pixel tests; layer queries scan entries linearly. There is no spatial
index or hard cache memory budget yet. Large edited atlases and very large scaled
shapes should be profiled for a particular game's workload.

## Render images: explicit snapshots

Direct collisions against render images (including their views) throw, without
performing a readback. Capture a CPU image deliberately:

```blitzmax
Local collisionImage:TImage=CreateCollisionImage(renderImage)
' Reuse collisionImage in ordinary collision calls.
```

The snapshot copies the selected frame/region and handle. A render image must
already have a live owning context. Capturing performs one explicit readback,
which can stall the GPU; later collision queries do not read back. A target edit
does not update the snapshot—capture again when your application needs it.
`CreateCollisionImage` also makes independent copies of ordinary image frames.

## Validation and example

From the SDK root:

```sh
./bin/bmk makeapp -r -o /private/tmp/max2d-collisions mod/max2d.mod/tests/collisions.bmx
/private/tmp/max2d-collisions
./bin/bmk makeapp -r -o /private/tmp/max2d-collision-render mod/max2d.mod/tests/collision_render.bmx
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software /private/tmp/max2d-collision-render
```

Build the rendering test with `-ud max2d_gl` for GL. It renders into fixed-size
images, so the reference pixel grid is independent of window DPI. The CPU test
covers thresholds, boundaries, atlas edits, retained snapshots, cache reuse,
write locks, animation, handles, rotation/reflection/shear, empty transforms,
layer ordering semantics, resets, ids and preservation of layer 32.

`examples/collisions.bmx` draws a rotating, stretched ring from an atlas and a
mouse-controlled square. The ring changes colour on collision; its transparent
hole remains empty. Mouse mapping respects the letterboxed virtual scene.

Validation completed locally: CPU tests pass in debug and release; rendered
collision/snapshot tests pass in release on SDL software and macOS OpenGL.
The interactive example compiles; it has not been manually play-tested.
