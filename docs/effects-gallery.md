# Effects gallery

Build `examples/effects_gallery.bmx` as a GUI app. The default build uses native
SDL GPU with `Max2D.SDL3GPUEffects` and offers both pages. Add `-ud max2d_gl` to
build with OpenGL and `Max2D.GLEffects`. On Windows, use `-ud max2d_d3d9` or `-ud max2d_d3d11` for native Direct3D.
All four builds offer eighteen views across both pages and require inverse-alpha
blending and RGBA16F render images.

The gallery compares source artwork with one selected effect. Keys 0–8 select
views. Tab switches between pages in both builds. For example:

```text
bmk makeapp -r -ud max2d_gl -t gui -o effects_gallery examples/effects_gallery.bmx
```

## Page 1: layers and cached effects

| Key | View |
| --- | --- |
| 0 | Original |
| 1 | Grayscale saturation |
| 2 | Outer outline plus original |
| 3 | Cached scaled blur |
| 4 | Soft alpha mask |
| 5 | Inverse mask / cutout |
| 6 | Cached soft shadow behind the source |
| 7 | Cached inner shadow over the source |
| 8 | HDR bloom, tone mapped into the SDR window |

## Page 2: shader packages and maps

| Key | View |
| --- | --- |
| 0 | Sepia colour matrix |
| 1 | Animated wave distortion |
| 2 | Waves and desaturation in one effect draw |
| 3 | Texture-driven displacement |
| 4 | Animated dissolve with an edge glow |
| 5 | Reusable texture alpha mask |
| 6 | Independently moving, scaled and rotated mask |
| 7 | One stationary mask spanning four independently rotating source tiles |
| 8 | Soft threshold reveal using the red channel of a procedural map |

Space pauses/resumes animation on either page. Left/right changes blur radius
from 0 to 16 source pixels. Escape exits. Layer outputs are retained and rebuilt
on radius changes; switching views uses cached images. Package views reuse their
effect descriptions and textures while updating parameters. The shared-map view
captures transforms per tile and uses four effect draws; it is not a single batch.
The noise map is uploaded once. The gallery's SDR window clips the dissolve's
bright edge; float composition and HDR output are shown in the focused examples.
The gallery precomputes several outputs for comparison, so its total storage and
rebuild work exceed those of an application using only one effect. The focused
examples remain available for learning each API in isolation.

## Independent shapes versus group shadows

Inner shadows start in **independent** mode: the circle, square and text have
separate source layers and cached shadow results. Press G to apply the effect to
the combined group instead. With a shared source, nearby shapes contribute to
the same blurred alpha and can lighten each other's inner edges. This is expected
group behaviour. Separate layers avoid that interaction at the cost of additional
buffers and draws. Letters in the text still share one text layer.

Except for the shared-map tiles, other views operate on the combined source.
Bloom uses a separately prepared
linear floating-point source with extra energy in bright artwork. Its left panel
shows that HDR source with the same SDR presentation mapping as the bloom panel;
this gallery does not enable HDR monitor output. See `hdr_scene.bmx` for that.

## Benchmark companion

`benchmarks/cached_effects.bmx` measures cached presentation versus rebuilding
shadow, inner shadow and bloom every frame, plus a source-only baseline. It uses
nine opaque/translucent cards inside 128-square and 512-square floating-point
layers. These represent small UI groups and larger panels. A rebuild recomputes
the same source; source animation/upload cost is intentionally excluded.

Build it as a release console app, then run with optional measured-frame count
and repetition count (defaults 100 and 2). At least 100 measured frames are
required. Each case warms for 30 frames; alternate repetitions reverse case order.
Keep the window visible. Visibility flags reject hidden, minimized or occluded
captures. Escape interrupts the run.

CSV records CPU draw/flush mean, CPU whole-frame mean and p95, submissions, texture
creation, uploads, readbacks and logical retained-image bytes. All cases use two
reduction levels, radius 8, RGBA16F storage and `Flip(0)`. Shadow and inner-shadow
presentation includes both source and shadow. Bloom includes one mapped draw.
The program checks expected submissions and rejects any measured texture churn
or readback. Logical bytes count source plus all effect images/pyramid/scratch,
excluding window buffers, geometry, driver alignment and pipeline memory.

CPU timings include host/compositor scheduling and are **not GPU timings**.
Presentation may pace `Flip(0)`. Compare repetitions and counters before drawing
performance conclusions; cached/rebuilt images do not establish equal visual
output across different effect types. The bloom benchmark uses normalized source
colours and a 0.5 extraction threshold in float storage; it measures pipeline cost,
not physical HDR-display brightness.

## Native Direct3D and framebuffer captures

Build the same gallery with `-ud max2d_d3d9` or `-ud max2d_d3d11` on Windows.
Both pages use the native optional effects provider. Float formats must be supported
by the device; window presentation remains SDR.

Pass `--capture-dir <directory>` to render all eighteen selections at a fixed
animation time, save `effect-00.png` through `effect-17.png` from the framebuffer,
and exit. This also works with the OpenGL and SDL GPU gallery builds.
