# Tile sizing and text objects

These are native `Max2D.TileMap` features. `Max2D.Tiled` imports their XML/JSON
settings, including text inherited from object templates.

## Tile display canvases

```blitzmax
Local id:Int = tiles.Add(image)
tiles.SetSize(id, 64, 64, ETileFillMode.PreserveAspectFit)
```

The default display size is the source image size. `SetSize` changes it without
resampling pixels. `Stretch` fills the canvas; `PreserveAspectFit` keeps the
source proportions and centres the artwork within it. Display dimensions must be
positive and finite. Tile offsets remain in map units; native callers choose
whether to anchor the canvas at the cell origin or offset it elsewhere.

Drawing, source-axis flips, diagonal/hex transforms, animation, sorting and
culling use that display canvas. Cell collision shapes remain in source-image
coordinates and receive the same scaling and padding when instantiated or queried.
Changing display size does not change grid geometry, cell picking or ground-depth
sort keys. Aspect-fit padding is part of the canvas, not collision artwork.

Tile objects instead use their own `width`, `height` and `fillMode`. Their normal
object bounds and picking cover the full box, including any aspect-fit margins.

Tiled `tilerendersize="grid"` uses map grid dimensions; `"tile"` keeps natural
image dimensions. `fillmode` applies to grid-sized cells and tile objects. Tiled
artwork offsets scale with the image. Native `SetSize` deliberately leaves offsets
alone. Animated frames still require matching source dimensions.

## Retained text

Add a text object to a layer and supply a font at the size you want to draw.
This snippet uses `Max2D.ScalableFont` and a font asset at `fonts/ui.ttf`:

```blitzmax
Local label:TTileObject = New TTileObject
label.x = 40
label.y = 60
label.width = 260
label.height = 100
label.text = New TTileText
label.text.text = "Welcome to the village!"
label.text.pixelSize = 20
label.text.font = LoadScalableImageFont(AppDir + "/fonts/ui.ttf", 20)
label.text.wrap = True
label.text.red = 255
label.text.green = 230
label.text.blue = 170
layer.AddObject(label)
```

`map.Draw` draws text alongside tile objects, respecting layer order, visibility,
opacity, tint, parallax, object transforms, cameras and render targets. Normal
point/region queries see the text rectangle. Glyphs and decorations clip to that
rectangle **before rotation**, so a rotated label does not leak from its box.
No per-character interaction maps are requested.

Settings include wrapping, explicit newlines, left/centre/right alignment,
top/middle/bottom alignment, colour/alpha, underline and strikeout. Justification
expands spaces on wrapped non-final paragraph lines; RTL lines keep their shaped
spacing. Decoration positions are approximate font-metric based positions, not
an exact reproduction of Qt's rendering.

`Prepare(width,height)` retains layouts. Drawing calls it again with a cheap
cache check. Text, font, box dimensions, pixel size or layout changes trigger a
rebuild; colour and decoration changes do not. `layoutBuilds` is a diagnostic
counter. `map.drawnTexts` counts submitted text objects, separate from sprites.
The renderer scans object layers; it does not maintain a text spatial index.

`font` must be loaded at the requested size. If it is Null, the built-in bitmap
font scales to `pixelSize`; that fallback does not provide arbitrary families,
bold/italic variants or scalable-font quality. With `Max2D.ScalableFont`, normal
layout drawing selects raster density for the camera/output scale. Changing
`pixelSize` on an object with an assigned font requires assigning a matching font.
Standard Max2D bitmap and scalable fonts are supported; custom text layouts should
emit glyph quads to use the object's clipping adapter.

## Tiled font mapping

Import `Max2D.ScalableFont` and provide a resolver. This example maps every
requested family to your game's UI font, caches sizes/styles, and honours kerning.
Place the four font files beside the executable under `fonts/`:

```blitzmax
Import Max2D.Tiled
Import Max2D.ScalableFont

Type TGameFonts Extends TTiledFontResolver
	Field fonts:TTreeMap<String,TImageFont> = New TTreeMap<String,TImageFont>

	Method Resolve:TImageFont(family:String, pixelSize:Int, bold:Int, italic:Int, kerning:Int) Override
		Local name:String = "ui"
		If bold Then name :+ "-bold"
		If italic Then name :+ "-italic"
		Local key:String = name + ":" + pixelSize + ":" + kerning
		Local font:TImageFont
		If fonts.TryGetValue(key, font) Then Return font

		Local flags:Int = SMOOTHFONT | LIGATURESFONT
		If kerning Then flags :| KERNFONT
		font = LoadScalableImageFont(AppDir + "/fonts/" + name + ".ttf", Float(pixelSize), flags)
		fonts.Put(key, font)
		Return font
	End Method
End Type

Local map:TTiledMap = LoadTiledMap("level.tmx", FILTEREDIMAGE, "", Null, New TGameFonts)
' With a project: project.LoadMap("level.tmj", FILTEREDIMAGE, "", New TGameFonts)
```

The filenames are `ui.ttf`, `ui-bold.ttf`, `ui-italic.ttf` and `ui-bold-italic.ttf`.
Use your own assets and naming scheme. To preserve different families, use the
`family` argument to choose the corresponding asset before looking in the cache.
Font assets can also use stream-backed paths. Return Null to choose the bitmap
fallback for a request.

Use `LoadTiledMap` or `TTiledProject.LoadMap` when supplying fonts. The generic
`LoadTileMap` entry point uses the bitmap fallback.

The resolver runs during import, once per text object. It receives font family,
pixel size, bold, italic and kerning. These requests remain available in `TTileText`
as metadata; changing them later requires resolving/assigning a new face yourself.
Text defaults match Tiled: sans-serif, 16 pixels, black, kerning enabled, no wrap,
left/top alignment. Underline and strikeout draw independently of face selection.
Fonts and shaping can differ from Tiled/Qt; matching font files helps but does not
promise identical line breaks. Import limits total text to 1,048,576 UTF-16 units
and requested font size to 1..4096. Text is not accepted as tile collision geometry.

## Try the example

`examples/tile_sizing_text.bmx` compares natural, stretched and fitted tiles with
wrapped, centred and rotated text. Space toggles diagonal tile flips. The example
uses the same SDL3/OpenGL/D3D9/D3D11 build conditionals as other native examples.
`--test` exits after three frames; `--screenshot=/absolute/path.png` captures one.
On macOS build as a console application when passing arguments.
