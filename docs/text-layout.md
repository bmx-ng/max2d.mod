# Retained paragraph layout

```blitzmax
Local prepared:TPreparedText = PrepareText("Text that wraps to fit a panel.")
Local paragraph:TParagraphLayout = prepared.Layout(320, TEXT_ALIGN_LEFT)

' Each frame:
DrawTextLayout(paragraph, 20, 40)

' Only when the available width changes:
paragraph = prepared.Layout(newWidth, TEXT_ALIGN_LEFT)
```

`PrepareText(text, font)` accepts an explicit font and can be used without a
current graphics context in that case. Omit the font to use the current image
font. The selected font is retained; changing the current image font afterwards
does not alter this paragraph. Recreate prepared text when content or the font's
logical settings change. Treat prepared objects and returned layout fields as
read-only.

## Wrapping and alignment

`prepared.Layout(width, alignment, lineSpacing)` returns a `TParagraphLayout`,
which can be passed to the existing `DrawTextLayout` function.

- Width is finite and nonnegative, in local text units.
- Alignment is `TEXT_ALIGN_LEFT`, `TEXT_ALIGN_CENTER` or `TEXT_ALIGN_RIGHT`.
  Left/right are physical alignment choices, not language-direction choices.
- `lineSpacing` is the distance between successive line origins. Zero selects
  the font's natural line height; a positive value can increase or reduce it.
- Ordinary spaces and tabs collapse to a single space between words. Leading
  and trailing spaces are discarded. CRLF and CR are normalized to newlines.
- Explicit blank lines and a trailing newline are retained. An empty string
  yields no lines and zero height. A whitespace-only line remains a blank line.
- In basic mode, wrapping occurs only at ordinary spaces. An overlong word remains intact and
  may exceed the box width. Zero width therefore produces one word per line.
  Nonbreaking spaces remain inside their word.
- Wrapping does not clip. Apply a viewport clip when content must stay inside
  a panel. Overflowing centred/right-aligned words can extend to the left.

Unicode line breaking is available through the optional provider described below.
Automatic hyphenation, emergency character/grapheme wrapping, justification,
rich text and paragraph-level bidi resolution remain outside this implementation.
Every completed line uses the font's existing shaping implementation, preserving
its kerning/ligatures without adding mixed-direction paragraph support.

## Measurements and rendering

`paragraph.boxWidth` is the requested width. `paragraph.width` is the widest
line's advance, which may be smaller or larger. `height` includes the natural
height of the last line plus the preceding line spacing; no trailing spacing
is added. `boundsX/Y/Width/Height` enclose the positioned glyph bitmaps, including
alignment offsets and glyph overhangs.

`paragraph.lines` contains `TParagraphLine` entries with normalized `text`, local
`x/y` offsets and a retained `layout`. The paragraph is a composite layout: its
inherited `glyphs` array is empty; inspect each line's layout instead.

Drawing observes ordinary Max2D colour, blend, transforms, camera and clipping,
and works on render images. Moving or scaling the paragraph does not reflow it.
Scalable fonts still choose appropriate raster density during drawing without
changing the logical line arrangement.

## Cost and caching

Preparation records word measurements and the font's natural line height.
Reflow uses these widths to estimate breaks, then shapes complete candidate
lines to verify the fit. It adjusts breaks when contextual shaping differs from
the sum of word widths. Reflow can therefore invoke the font shaper; it is not
an arithmetic-only algorithm for all input.

The prepared object caches eight layouts by width, alignment and resolved line
spacing. `SetCacheLimit(n)` changes that bound; zero disables it. `ClearCache()`
releases cached references. Eviction does not invalidate application-held
layouts. `reflowBuilds` counts newly built paragraph layouts. The font retains
its own separate bounded layout and glyph caches.

For a frame loop, keep the returned paragraph and draw it directly. Drawing
does not segment, shape or rebuild the paragraph. A previously unseen glyph
raster density can still require font rasterization/upload, just as for other
scalable text. Requesting an already cached layout does not reshape it either.

The regression tests assert that 1,000 cached requests and repeated draws leave
layout-build counters unchanged. A small release-build host probe (Apple M4 Max,
Noto Sans 18, about 500 characters, warmed font caches) measured approximately
0.04 ms per prepare-plus-initial-layout and 0.02 ms per uncached width change.
10,000 cached requests were below the millisecond timer's resolution and created
zero additional font layouts. These are illustrative measurements, not a timing
guarantee or cold glyph-upload benchmark.
[paragraph_benchmark.bmx](../tests/paragraph_benchmark.bmx) reproduces the probe;
pass an outline font path as its first argument.

See [paragraph.bmx](../examples/paragraph.bmx) for interactive width and alignment
changes. Left/right arrows change width, up/down change height, 1/2/3 select horizontal alignment, and 4/5/6 select vertical alignment. The displayed box-build count remains unchanged while simply drawing.

## Verification (2026-09-24)

- CPU paragraph tests passed on macOS, Linux ARM64 and Windows 11.
- Paragraph pixel tests passed on macOS SDL software/default and OpenGL,
  Linux SDL/OpenGL, and Windows SDL/OpenGL/D3D9/D3D11.
- Existing text layout tests and real Noto Sans scalable-font paragraph tests
  passed on macOS, including ligatures and stable build counters.
- The macOS example was visually checked at multiple widths and alignments.

Windows and Linux results are from Parallels VMs. No claim of additional physical
GPU coverage is made by this feature pass.

## Fitting a box and marking overflow

```blitzmax
Local fitted:TParagraphLayout = prepared.LayoutBox(320, 120, TEXT_ALIGN_LEFT, 0, 3)
DrawTextLayout(fitted, 20, 40)
If fitted.truncated Then
	' Offer a way to display the complete text.
End If
```

`LayoutBox(width, height, alignment, lineSpacing, maxLines, ellipsis, verticalAlignment)` shares
ordinary wrapping and uses the following additional options:

- Height must be finite and nonnegative. Only complete logical line boxes fit;
  a height smaller than the natural line height gives zero visible lines.
- `maxLines` is an optional additional limit; zero means unlimited.
- `ellipsis` defaults to three dots, which work with the built-in bitmap font.
  Pass another single-line marker supported by your font, or an empty string
  to omit the marker. Newlines and tabs are rejected.

The last visible line receives the marker when later lines are omitted. Any
individually overwide line is also shortened and marked. Fitting removes whole
words (or Unicode break segments when enabled) from the end and shapes the resulting line together with its marker.
It never slices code units or splits a word's combining sequences. If the marker
alone cannot fit, that line is empty. Empty retained lines keep their vertical
space. The method does not implement direction-aware ellipsis for bidi text.

`truncated` reports omitted content, including when no line fits.
`totalLineCount` is the number of lines in the complete wrapped paragraph;
`lines.Length` is the retained count. `height` and bitmap bounds describe the
retained result, while `boxHeight` is the requested height. Ordinary `Layout`
results have `boxHeight = -1` and `truncated = False`, even for overwide words.
Alignment is recalculated after fitting each line. Neither the full layout nor
other retained boxes are modified.

The first box request wraps the complete paragraph to obtain its total line
count. Box results and full layouts share the prepared object's bounded cache.
Height changes can reuse cached full layouts; repeated identical box requests
return the cached box. `boxBuilds` counts fitted results, separately from
`reflowBuilds`. Directly drawing a retained box does neither kind of work.

Logical height fitting does not constrain glyph overhangs or transformed output.
Use `IntersectViewport` when a strict pixel clip is required.

Box fitting follow-up (2026-09-25): CPU checks passed on macOS, Linux ARM64
and Windows 11; fitted-line pixel checks passed on macOS SDL software/OpenGL,
Linux OpenGL and Windows D3D11. Real-font ellipsis/shaping checks passed with
Noto Sans on macOS SDL software. The resized macOS example was visually checked.

## Vertical box alignment

The final optional `LayoutBox` argument selects `TEXT_ALIGN_TOP` (the default),
`TEXT_ALIGN_MIDDLE` or `TEXT_ALIGN_BOTTOM`. Alignment is applied **after** height
and line-count fitting, so it positions the retained content, including any
ellipsis. Blank lines remain part of that content's logical height.

```blitzmax
Local centred:TParagraphLayout = prepared.LayoutBox(320, 120, TEXT_ALIGN_CENTER, 0, 0, "...", TEXT_ALIGN_MIDDLE)
DrawTextLayout(centred, 20, 40)
```

`contentY` reports the vertical offset within the box. Each retained line's `y`
and the visible glyph `boundsY` already include it; do not add it again when
drawing. `height` remains the content height, not the bottom position or box
height. Empty results retain zero height, offset and ink bounds. Alignment uses
logical line height rather than individual glyph outlines, keeping the position
stable when the letters change; a font's overhang may still require clipping.

Vertical alignment is included in the bounded cache key. Existing retained boxes
are not mutated, and ordinary `Layout` and previous `LayoutBox` calls retain
their top-aligned behaviour. The example uses 4/5/6 for top/middle/bottom.

Vertical alignment follow-up (2026-09-25): CPU layout checks and SDL software /
OpenGL pixel checks passed on macOS, including retained-layout independence,
cache identity, truncated content, empty results and updated ink bounds. The
bottom-aligned example was visually checked. This shared layout-only change was
not separately rerun in the VMs.

## Optional Unicode boundaries

```blitzmax
Framework Max2D.GLMax2D
Import Text.Unibreak

Local prepared:TPreparedText = PrepareText(text)
```

`Max2D.Core` imports only the small `Text.Boundaries` interface. It does **not**
import libunibreak. `Text.Unibreak` registers the implementation when explicitly
imported by an application. Without a provider, the existing basic behaviour is
unchanged, including its treatment of long words and ordinary spaces.

`PrepareText(text, font, breakMode, language)` supports:

- `ETextBreakMode.Auto` (default): use the registered provider, otherwise basic.
- `ETextBreakMode.Basic`: force the existing space-based behaviour, even with a provider.
- `ETextBreakMode.Unicode`: require a provider; throw if none is registered.

`UnicodeTextBoundariesAvailable()` queries availability. The optional language
string passes to the provider for supported tailoring. A prepared object retains
its chosen provider and analysed maps; later registration changes do not alter
its behaviour. Registration should occur before concurrent preparation starts.

Preparation normalizes CRLF/CR, collapses ASCII spaces/tabs and asks the provider
for line and grapheme boundary maps once. It does not request or allocate a word-boundary map. Unicode mode uses permitted line boundaries that are
also grapheme boundaries, honours mandatory Unicode separators, NBSP and word
joiners, and does not insert spaces between CJK segments. Zero-width spaces are
removed from rendered text. Soft hyphens are invisible except at a selected
break, where an ordinary hyphen is shaped with the completed line. This is not
automatic dictionary hyphenation.

The prepared `normalizedText` and `boundaries` fields describe the normalized
Unicode input, using UTF-16 string offsets. They are read-only inspection data;
they do not map directly to offsets in the original, unnormalized string.
`breakMode` records BASIC or UNICODE after automatic resolution.

Reflow and ellipsis fitting reuse the prepared boundaries. They may still shape
candidate lines, as before; drawing retained layouts does neither operation.
There is no emergency split when a single unbreakable segment is too wide.
Dictionary-based segmentation and font fallback are separate capabilities.
Optional paragraph bidi is described below. A font must contain the glyphs required by the chosen language.

See [paragraph_unicode.bmx](../examples/paragraph_unicode.bmx). The ordinary
paragraph example deliberately remains usable without Text.Unibreak.

Unicode provider follow-up (2026-09-25): the provider's bundled Unicode 17 fixtures
passed all 22,048 upstream cases. Text.Unibreak's BRL.MaxUnit binding tests passed
on macOS, Linux ARM64 and Windows 11. Basic/optional/required paragraph modes
passed on all three systems, with Linux OpenGL and Windows D3D11 paragraph pixel
checks. Real-font Unicode soft-hyphen rendering passed on macOS SDL software.
Additional punctuation/emoji and provider-analysis-count checks were exercised
on macOS with debug runtime checks enabled. VM tests used Parallels.

## Optional text interaction

Pass `True` as the final `PrepareText` argument to retain mappings back to the
**original** UTF-16 input. Ordinary preparation and drawing do not allocate
source maps or caret geometry.

```blitzmax
Local prepared:TPreparedText = PrepareText(text, font, ETextBreakMode.Auto, "", True)
Local paragraph:TParagraphLayout = prepared.Layout(400)
' Optional prewarming; otherwise each query builds only the lines it needs.
paragraph.PrepareInteraction()
Local caret:TTextCaret = paragraph.HitTest(localMouseX, localMouseY)
If caret Then
	Print caret.sourceOffset
	DrawRect(drawX + caret.x, drawY + caret.y, 1, caret.height)
End If
Local sourceCaret:TTextCaret = paragraph.CaretAt(sourceOffset)
```

`HitTest` chooses the nearest visible line and supported caret. `CaretAt` chooses
the nearest visible supported source offset; its optional `preferNextLine`
argument defaults to True for ties between lines. Both return cached read-only
`TTextCaret` objects, or Null if no lines are visible. Queries on a paragraph
that was not prepared for interaction throw, rather than silently constructing
source mappings. Hidden content snaps to visible stops. Synthetic ellipsis and
discretionary-hyphen geometry maps to the corresponding source cutoff.

Coordinates are paragraph-local logical units and include paragraph alignment
and line offsets. Convert mouse coordinates through the inverse of the same
transform used to draw the paragraph. For simple untransformed drawing, use
`GetVirtualMouse` then subtract the paragraph draw position. For cameras,
rotation or parent coordinates, use `CaptureDrawTransform` and
`VirtualToLocal`; caret coordinates can be mapped back with `LocalToVirtual`.
Viewport clipping is the caller's responsibility; hit tests deliberately clamp
outside points. See `examples/paragraph_interaction.bmx`.

### Cost and scope

- Interactive preparation builds source maps once. Unicode mode additionally
  requests a **grapheme-only** map of the original input, so normalization never
  permits a caret inside an original grapheme. Basic mode protects surrogate
  pairs but does not provide full Unicode grapheme segmentation.
- Interactive layouts allocate their line source maps while reflowing. Caret
  geometry is lazy per line. `HitTest` builds only its target line; `CaretAt`
  builds only candidate lines. `PrepareInteraction` explicitly prewarms all lines.
- Bitmap fonts use glyph advances. Scalable fonts shape each requested line once
  more on first interaction, obtaining cluster edges and contextual advances
  directly from HarfBuzz. Drawing layouts and raster caches are not rebuilt.
- Queries on already-built lines allocate no objects or arrays and do not shape. Hit testing
  uses a direct line lookup and binary search within that line. Source lookup
  scans line source ranges, then searches candidate lines' ordered stops. Both use cached geometry.
- Ligatures remain indivisible clusters. Interior ligature carets and full text
  editing/keyboard navigation are not implemented. Without a bidi provider,
  single horizontal RTL runs follow the existing shaper and nonmonotone caret
  geometry is rejected. The optional bidi path retains multiple directional runs.
- Custom `TImageFont.Layout` implementations must implement `CreateCaretMap`
  when their positioning differs from the base glyph-advance layout. Legacy
  shaped `TImageFont` instances without cluster metadata report unsupported;
  `TScalableImageFont` supplies the shaped implementation.
- Keep font settings unchanged while holding prepared text, as for ordinary
  layout. Eviction from the paragraph cache does not invalidate held layouts.

`paragraph_interaction.bmx` covers source normalization, blank lines, wrapping,
alignment, truncation, Unicode clusters, lazy creation and repeated queries.
`scalable_interaction.bmx` accepts a NotoSans-Regular.ttf path and an optional
Arabic font path to check ligatures, kerning and single-run RTL geometry.
`paragraph_interaction_bench.bmx` accepts a NotoSans-Regular.ttf path and reports
first-build time, managed allocation volume and warm-query cost. These are
CPU-only tests; no graphics window is required.

A macOS ARM64 release run with 4,100 UTF-16 units and 70 lines measured 1 ms and
326,432 managed allocation bytes for the first caret build. The following
100,000 hit tests plus 100,000 source lookups took 21 ms and allocated zero
managed bytes. Allocation volume includes temporary construction data, not just
retained memory; native HarfBuzz allocations are not counted. Timings are an
illustrative single run, not a cross-platform performance guarantee.

### Scroll containers

Ordinary `DrawTextLayout` still visits all lines. For a long paragraph, use
`DrawTextLayoutVisible` to submit only lines whose logical/ink bounds intersect
an explicit local vertical band. It includes glyph overhangs and uses line
spacing to skip directly to the candidate range. Keep a viewport to clip glyphs
that only partially intersect it.

```blitzmax
' Inside a saved drawing-state scope:
IntersectViewport(panelX, panelY, panelWidth, panelHeight)
DrawTextLayoutVisible(paragraph, panelX, panelY - scrollY, scrollY, scrollY + panelHeight)

Local mouseX:Float, mouseY:Float
If GetVirtualMouse(mouseX, mouseY) Then
	If mouseX >= panelX And mouseX < panelX + panelWidth And mouseY >= panelY And mouseY < panelY + panelHeight Then
		Local caret:TTextCaret = paragraph.HitTest(mouseX - panelX, mouseY - panelY + scrollY)
	End If
End If
```

Use a full `Layout` for scrolling; `LayoutBox` truncates content and cannot hit
test omitted lines. Scrolling does not reflow text or invalidate cached carets.
The full paragraph is still prepared and wrapped up front: visible drawing is
submission culling, not incremental document layout. A rotated/transformed
viewport requires converting its corners to paragraph-local space and using a
conservative vertical band; the actual viewport provides final clipping.

### Font spans

Interactive prepared text accepts optional fonts over original UTF-16 source
ranges, using the same coordinates as selection and colour spans:

```blitzmax
Local prepared:TPreparedText = PrepareText(text, regularFont, ETextBreakMode.Auto, "", True)
prepared.SetFontSpans([TTextFontSpan.Create(0, 12, headingFont)])
Local paragraph:TParagraphLayout = prepared.Layout(400)
```

Supply actual font objects for bold, italic or different sizes. There is no
automatic family lookup or synthetic bold/italic. Later overlapping spans win;
uncovered text uses the prepared paragraph's default font. Ranges are copied,
but font objects must remain unchanged while their layouts are held.
`SetFontSpans(Null)` restores the default font throughout.

Changing font spans clears the prepared paragraph's reflow cache. Previously
returned layouts retain their original fonts and geometry. The source mapping
stays the same, so a selection controller can preserve its source selection when
given the new layout with `SetLayout`. Colour changes continue to reuse geometry.

Adjacent text using the same font object is shaped together, preserving kerning
and ligatures. Different fonts create separate shaping runs. The font at the
first source position of a grapheme controls the whole grapheme when boundary
information is available; basic mode protects surrogate pairs. Colour boundaries
do not split these runs. Synthetic ellipsis text uses the default font.

Each styled line aligns its fonts on a shared baseline. The default font supplies
a minimum line height, including for blank lines. Styled lines treat positive
`lineSpacing` as a minimum advance, expanding it when their font metrics require
more room. Ordinary paragraphs without font spans retain their existing fixed
spacing behaviour. Height fitting, visible-line culling, hit testing, selections
and backgrounds all use the resulting per-line geometry.

Scalable fonts supply their actual ascent. Custom `TImageFont` implementations
should override `Baseline()` or set `baselineOffset` for accurate alignment;
legacy fonts without either default to the bottom of their line height.

Without a bidi provider, a line with multiple font runs and a right-to-left
shaped run is explicitly rejected. Import `Text.SheenBidi` to order those runs
correctly and retain their directional interaction geometry. Font fallback
remains separate work: every selected font must contain the required glyphs.

The interaction example uses larger bold and italic faces when installed;
**F** toggles font spans independently of **C** for colours. CPU regressions cover
wrapping, baseline metrics, snapshot retention, selection preservation, height
fitting and culling. On macOS, software-renderer pixel comparisons also match
independently positioned real-font runs, including colour and rotation.
`tests/text_styles_render.bmx` accepts an outline font path as its first argument;
`tests/scalable_interaction.bmx` additionally checks same-font shaping and RTL limits.

## Selection rectangles

Interactive paragraphs provide geometry independently of drawing colour:

```blitzmax
Local rectangles:TTextSelectionRect[] = paragraph.SelectionRects(anchorOffset, activeOffset)
For Local rectangle:TTextSelectionRect = EachIn rectangles
	DrawRect(drawX + rectangle.x, drawY + rectangle.y, rectangle.width, rectangle.height)
Next
' Draw the paragraph afterward, using its normal text colour.
```

For scrolling, use `SelectionRectsVisible(anchorOffset, activeOffset, scrollY,
scrollY + panelHeight)`, subtract scrollY from rectangle drawing positions, and
keep the panel viewport active. Only selected lines intersecting that band build
caret geometry. Full line-height rectangles are returned; the viewport clips
partial lines. This is advance coverage, not a bounding box around glyph ink.

Ranges use original UTF-16 offsets and are half-open `[start, end)`. Reversed
ranges are accepted; out-of-range offsets clamp to the input. Nonempty ranges
that partially intersect a supported cluster expand to the whole cluster,
including ligatures. Empty ranges produce no rectangles. Invisible newlines,
blank lines and zero-width segments have no visible selection coverage.
Synthetic ellipsis is excluded; a displayed discretionary hyphen represents its
source soft hyphen and can be highlighted. Hidden/truncated source text adds no
rectangles. Each returned rectangle includes its covered source range and line
index. Single RTL runs use positive-width rectangles; full mixed bidi remains
outside the current layout model.

The most recent normalized range and visibility band are cached per layout.
Repeated identical queries reuse the same read-only array and rectangles without
allocation or shaping. A changed selection/band allocates a new result, while
held previous results stay valid. Layout changes require a new query on that
layout. Scrolling preserves source selection offsets; colours can change without
recomputing geometry. This is one bounded cache entry, not a history of every
drag position.

The interaction example now supports click-and-drag selection and wheel scrolling
while dragging. Mouse capture begins only inside the text viewport, then clamps
at its edges. It does not implement automatic edge scrolling, clipboard actions
or editing.

## Optional selection controller

`TTextSelectionController` is an optional stateful helper. It does not poll input,
read the clock, capture an OS mouse, or draw. Feed it paragraph-local positions
from your UI/input layer, after applying the viewport/scroll/camera conversion:

```blitzmax
Local controller:TTextSelectionController = New TTextSelectionController
controller.SetLayout(paragraph)
' On a press INSIDE the text viewport:
controller.PointerDown(localX, localY, MilliSecs())
' During capture, including a final movement before release:
controller.PointerMove(localX, localY)
controller.PointerUp()
' On focus loss/capture cancellation:
controller.CancelDrag()
Local rectangles:TTextSelectionRect[] = paragraph.SelectionRects(controller.anchor, controller.active)
```

A single click starts character selection. Double-click selects a word segment;
dragging then extends by whole words, retaining the entire initial word when the
drag reverses. Triple-click selects a wrapped **visual line** and drags by visual
lines. A fourth click starts a fresh sequence. `unit` reports
`ETextSelectionUnit.Character`, `.Word` or `.Line`; `SelectionStart()` and
`SelectionEnd()` return ordered source offsets, while `anchor`/`active` preserve
drag direction. The character policy uses the font's supported cluster-edge
carets, rather than splitting ligatures or graphemes.

Automatic counting defaults to 500 ms and 4 paragraph-local units between clicks.
Configure `clickInterval`, `clickDistance` and `tripleClickEnabled` as appropriate;
these defaults do not query OS preferences. `PointerDown` also accepts an explicit
fourth argument of 1, 2 or 3 for hosts with their own/native click counting.
Zero uses automatic counting. Disabling triple-click limits counting to doubles.
Pointer movement beyond the configured distance resets the click sequence, as do
cancellation, a backwards timestamp, or attaching a different layout.

`SetLayout` preserves selection/capture for reflows of the same prepared source,
but resets them for a different prepared source. Null detaches the controller.
The host decides whether an outside press should deselect, clamps/routes captured
movement, releases OS capture, and handles focus loss. Edge autoscroll, clipboard,
keyboard extension and logical-paragraph triple-click policies remain host work
or later extensions. The example supports wheel scrolling during capture.

### Word and line queries

- `WordAt(offset)` returns the original-source segment containing that UTF-16
  offset. At a boundary it chooses the following segment; the source end chooses
  the last segment. It can query source outside a truncated layout.
- `WordAtPoint(x, y)` uses the shaped cluster **under** the point, avoiding the
  nearest-caret ambiguity on the right half of a word's final character. Outside
  points clamp like hit testing. Whitespace and punctuation are selectable too.
- `LineRange(index)` and `LineAtPoint(x, y)` return the visible wrapped line range,
  excluding newline separators and synthetic ellipsis. Blank lines have a valid
  empty range. These do not request word boundaries.
- Queries return an `STextRange` value (`sourceStart`, `sourceEnd`, `valid`) without
  allocating a range object. An empty paragraph has no word or point target.

Only the first word query requests `ETextBoundaryMaps.Word` on the retained original
input, using the provider captured during preparation. This map is shared across
reflows of that prepared text. Provider maps are treated as read-only; boundaries
inside graphemes/surrogate pairs are ignored when querying. Basic mode groups ASCII
letters/digits/underscore and non-ASCII code units as word runs, groups ASCII
space/tab/CR/LF runs, and treats other ASCII punctuation individually. This is a
simple fallback, not Unicode word segmentation or dictionary-based navigation.

Single-click dragging, line selection, drawing and ordinary preparation do not
request a word map. Warm word-drag updates allocate nothing and reuse shaped caret
geometry. The benchmark's 100,000 warm word-drag updates took 6 ms with zero managed
allocation on one macOS ARM64 run; this excludes first-use word analysis and first
use of new lines. Changing the selection still creates new rectangles when asked,
as described above. `tests/text_selection.bmx` covers click policies, direction
reversal, reflow, source offsets, lazy provider requests and basic/Unicode words.

## Foreground and background colour spans

Colour spans use half-open **original-source** UTF-16 ranges, just like selection.
Enable the existing source-mapping option during preparation (`interactive=True`);
this does not create a selection controller or eagerly build caret geometry.

```blitzmax
Local prepared:TPreparedText = PrepareText(text, font, ETextBreakMode.Auto, "", True)
Local emphasis:TTextColorSpan = TTextColorSpan.Create(0, 5)
emphasis.SetForeground(255, 200, 80)
emphasis.SetBackground(30, 60, 100, 0.7)
prepared.SetColorSpans([emphasis])
Local paragraph:TParagraphLayout = prepared.Layout(400)
DrawTextLayout(paragraph, 20, 30)
```

Both channels are optional and have their own opacity. Unset foreground uses the
current drawing RGB; unset background is transparent. Span RGB replaces the drawing
RGB; span opacity multiplies the current drawing alpha. RGB and opacity are clamped
to their ordinary ranges; nonfinite opacity, null spans and invalid source ranges
are rejected. Later overlapping spans win **independently for each channel**.
A background-only span does not erase an earlier foreground style.

The style at a cluster's **first source position** controls its entire glyph/advance
cluster. A span starting inside an existing ligature does not recolour the ligature
until a later cluster starts inside that span. Unicode graphemes are kept together
when the boundary provider is enabled; scalable fonts also retain their shaped
cluster indices. Basic unshaped fonts without a provider only have their ordinary
code-point/surrogate protection. No colour boundary splits or reshapes a cluster.
Synthetic ellipsis inherits drawing colour and has no span background. A displayed
soft hyphen retains its real source range.

`SetColorSpans` takes a snapshot of the input spans. Update a span and call it again
to change colours; pass Null to clear them. Every held layout from that prepared
text sees the new paint revision lazily, even after cache eviction. Shared font
layouts and other paragraphs are not mutated. Changing paint never reflows text or
invalidates caret/selection geometry. Cached per-line paint is rebuilt only when
needed after an update. Foreground-only painting uses retained glyph cluster metadata
and does not request caret geometry; backgrounds may build a line's caret geometry
on first use, then reuse it. Word boundaries are not needed. Ordinary text allocates
no paint arrays. Span resolution currently checks the supplied spans per glyph/cluster
on a cold paint build; warm drawing uses the cached result.

Backgrounds cover advance widths (including spaces) at logical line height, following
wrapping, alignment, scrolling and drawing transforms. Adjacent same-style areas are
merged into runs. They do not add padding, cover glyph overhangs, or paint invisible
newlines. Drawing restores the caller's colour and alpha, including on exceptions.

### Backgrounds and selection layering

Ordinary paragraph drawing includes backgrounds before glyphs. For selection on top
of those backgrounds but underneath the text, use separate passes:

```blitzmax
DrawTextBackgroundsVisible(paragraph, x, y - scrollY, scrollY, scrollY + panelHeight)
SetColor(55, 90, 145)
For Local rectangle:TTextSelectionRect = EachIn paragraph.SelectionRectsVisible(anchor, active, scrollY, scrollY + panelHeight)
	DrawRect(x + rectangle.x, y - scrollY + rectangle.y, rectangle.width, rectangle.height)
Next
SetColor(230, 235, 245)
DrawTextLayoutVisible(paragraph, x, y - scrollY, scrollY, scrollY + panelHeight, False)
```

Keep the viewport active for all passes. The final False prevents backgrounds being
painted twice. Selection has no built-in colour and does not alter span styles.
The interaction example demonstrates this ordering; C toggles its colour spans.

The bitmap and scalable implementations use the common Max2D drawing path, so there
are no backend-specific paint calls. Custom layouts must retain each positioned
glyph's single-line UTF-16 `sourceOffset` and override
`DrawColored(canvas, x, y, colors, colorOffset = 0)` if their drawing
needs differ from the base image-glyph implementation. Legacy shaped fonts without
source clusters report unsupported rather than guessing. Max2D.ScalableFont exposes
the actual HarfBuzz cluster indices without an extra shaping pass.
The optional `colorOffset` indexes the run's first glyph within the supplied
colour array, allowing mixed-font drawing without allocating array slices.


## Optional bidirectional paragraphs

```blitzmax
Import Text.SheenBidi
Import Text.Unibreak ' Independent: Unicode breaks and grapheme boundaries.

Local prepared:TPreparedText = PrepareText("Score 42: مرحبا بالعالم", font, ETextBreakMode.Auto, "", True)
Local paragraph:TParagraphLayout = prepared.Layout(400)
```

`Text.Bidi` is the small graphics-independent interface. `Text.SheenBidi` bundles
SheenBidi 3.0.0 / Unicode 17.0 and registers its implementation. Only that optional
module links the native library and its Unicode tables. It builds from included
sources, without runtime downloads or a system installation.

The final optional argument of `PrepareText` is `direction:ETextDirection`:

- `Auto` captures an available provider; otherwise uses the existing layout path.
- `Disabled` bypasses bidi even when a provider is imported.
- `LeftToRight` / `RightToLeft` explicitly set the paragraph base direction and
  require a provider. They do not force every character to flow that way.

```blitzmax
Local label:TPreparedText = PrepareText("Known LTR label", font, ETextBreakMode.Auto, "", False, ETextDirection.Disabled)
```

No provider (or Disabled) means no bidi paragraph analysis, script maps, visual
run arrays or native bidi objects. There is a provider check during preparation
and small optional fields/branches in core objects; this is not a claim of zero
additional code size. `DrawText` and direct `font.Layout` do not automatically
become bidi paragraph APIs. Use `PrepareText` for mixed-direction content.

### Layout and shaping

Analysis runs once per prepared block and survives width changes. Each candidate
wrapped line obtains its visual runs from that retained paragraph, including
line-end whitespace resetting. This preserves the paragraph's base direction
when subsequent lines start with numbers or a different script. Font changes
reuse the same direction analysis and rebuild the affected cached layouts.

Runs are split by direction, script and font, then shaped with explicit direction
and script. ScalableFont passes surrounding line context to HarfBuzz so Arabic
joining can survive a font boundary. HarfBuzz performs glyph mirroring; source
strings and source offsets stay in logical order. Existing colour and font span
policies apply. Font boundaries can still change ligatures and metrics.

Use `Max2D.ScalableFont` with suitable fonts for RTL. Custom fonts can implement
`LayoutRun` and `CreateRunCaretMap`; returned glyph/caret offsets are relative to
the requested run. The base image font supports LTR runs and reports unsupported
RTL rather than reversing unshaped characters. No automatic font fallback is
provided. Importing Unibreak separately is recommended for Unicode wrapping and
grapheme-safe interaction; without it the existing basic break policy remains.

Alignment remains independent of direction: LEFT/CENTER/RIGHT retain their
physical meanings. A discretionary hyphen follows its logical end run. A
synthetic ellipsis is an isolated default-font suffix at the paragraph's visual
end (left for an RTL paragraph), and does not acquire a selectable source range.
Prepared blocks retain the existing whitespace normalization and hard-break
policy; this is not a verbatim document editor.

### Interaction and affinity

Bidi interaction remains lazy per line and requires `interactive=True`. It keeps
source-ordered caret stops and visual cluster cells. Hit testing searches visual
cells; source lookup searches logical stops. A source selection can produce
several disconnected rectangles, and coloured backgrounds use the same coverage.
Word double-click/drag and visual-line triple-click use the existing controller.

At a directional boundary, one source offset can have two visual positions:

```blitzmax
Local following:TTextCaret = paragraph.CaretAt(offset, True, ETextCaretAffinity.Following)
Local preceding:TTextCaret = paragraph.CaretAt(offset, True, ETextCaretAffinity.Preceding)
```

Following is the default and attaches to the following logical run; Preceding
attaches to the preceding run. `HitTest` returns the side nearest the pointer,
including `caret.affinity`. Exact coincident stops use a deterministic visual-cell
choice; distinct logical offsets at the same x cannot all round-trip uniquely.
The selection controller retains `anchorAffinity` and `activeAffinity`; use the
latter with `CaretAt` to draw its active endpoint. Selection itself remains one
logical half-open source range. Keyboard movement/editing and interior ligature
carets remain future work.

### Costs and verification

Ordinary drawing reuses positioned runs. Noninteractive paragraphs never build
caret/selection data. First interaction shapes the needed runs once more for
cluster advances, without rebuilding glyph layouts or rasterizing fonts. Warm
queries use retained arrays and objects. Changing selection rebuilds its
rectangles; an unchanged range and visible band reuse the cached result.

A macOS ARM64 release probe using Arial 18 and 4,500 UTF-16 units over 67 mixed
Arabic/Hebrew/Latin lines measured approximately 6 ms for preparation plus layout,
2 ms and 1.12 MB managed allocations to prewarm all carets, and 27 ms for 100,000
hit tests plus 100,000 source lookups with **zero managed allocation**. Warm
selection, word-drag and paint queries also allocated zero managed bytes.
These are illustrative timings, not guarantees; native provider memory is not
included in managed GC statistics. Run `tests/text_bidi_bench.bmx` with a suitable
outline-font path to reproduce the probe. Lazy use only prepares touched lines.

The bundled upstream SheenBidi suite passed on macOS ARM64. Provider tests cover
UTF-16 ranges, levels, isolates, line-end resetting and supplementary characters.
`tests/text_bidi.bmx` covers optional/disabled paths, visual ordering, wrapping,
font runs, normalization, affinity, disconnected selection/backgrounds and cache
reuse. `tests/text_bidi_render.bmx` accepts a Latin/Hebrew/Arabic font path and
compares SDL software rendering against independently positioned runs, including
rotation and mixed font sizes; it also checks Arabic context and mirroring.
Existing no-provider paragraph/interaction/paint regressions pass. The new provider
and mixed-direction rendering have also passed the VM validation below.

`examples/paragraph_bidi.bmx` demonstrates scrolling, selection, mixed fonts and
colours. F toggles fonts, C toggles colours, arrows resize the panel and 1/2/3
change alignment. Its system font paths can be adjusted for local installations.


### Windows and Linux validation (2026-09-25)

| Check | Ubuntu 25.10 ARM64, Parallels | Windows 11 ARM64, x64 executables, Parallels |
| --- | --- | --- |
| Text.SheenBidi provider tests | Passed | Passed |
| Debug paragraph interaction, selection, colours, font spans, bidi | Passed | Passed |
| Real-font bidi and font-span pixels, SDL software | Passed | Passed |
| Real-font bidi pixels, live SDL / OpenGL | Passed / Passed | Passed / Passed |
| Real-font bidi pixels, D3D9 / D3D11 | Not applicable | Passed / Passed |
| Warm caret, selection, word-drag and paint managed allocations | Zero | Zero |
| Bidi interaction example build and three-frame smoke run | Passed | Passed |

The rendering test compares independently ordered runs, including mixed font
sizes, colour and rotation, and checks Arabic joining context, bracket mirroring,
caret affinity and disconnected selection. Tests used DejaVu Sans on Linux and
Arial on Windows. The new provider compiled directly from its bundled sources
on both VMs; no SheenBidi system installation was needed.

For the 4,500-unit interaction probe, Linux produced 78 lines and measured 25 ms
for 200,000 warm caret queries; Windows produced 67 lines and measured 62 ms.
Different fonts, VM settings and Windows x64 emulation make these diagnostic
measurements rather than a platform performance comparison. First prewarming
allocated approximately 1.13 MB / 1.12 MB of managed data respectively; untouched
lines still allocate none of this optional interaction geometry.

Validation exposed a pre-existing `Pub.FreeType` linker condition that omitted
generic Linux ARM64. Its system FreeType import now applies to all Linux targets,
matching the existing x86/x64/Raspberry Pi behaviour. After that fix, real-font
builds and all listed Linux runs passed. The bidi integration needed no
platform-specific implementation changes.

The example smoke check also caught Windows font-path setup calling a nonexistent
`GetEnv`. The affected paragraph, camera and drawing-state examples now explicitly
import `Pub.StdC` and use `getenv_`. This fixes example setup; no bidi rendering
or interaction code needed platform-specific changes.
