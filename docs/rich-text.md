# Inline rich text

Import `Max2D.RichText` when text contains inline styling. It converts markup
into the same font and colour spans used by the ordinary paragraph API.
`DrawText` and `PrepareText` continue to treat every character literally.

```blitzmax
Import Max2D.RichText

Local styles:TStyledTextStyles = TStyledTextStyles.Create()
Local prepared:TPreparedText = PrepareStyledText("Score: [color=#FFD060]1500[/color]", styles)
Local layout:TParagraphLayout = prepared.Layout(400)

' Inside your drawing loop:
DrawTextLayout(layout, 20, 40)
```

The built-in font is sufficient for colours and backgrounds. Bold, italic and
sizes use actual fonts supplied by your application.

## Supported tags

| Markup | Meaning |
| --- | --- |
| `[b]bold[/b]` | Select the registered bold face. |
| `[i]italic[/i]` | Select the registered italic face. |
| `[b][i]both[/i][/b]` | Select the registered bold-italic face. |
| `[color=#FFD060]gold[/color]` | Override glyph RGB colour. |
| `[bg=#203040]highlight[/bg]` | Add background colour. |
| `[alpha=0.5]faint[/alpha]` | Set glyph and background opacity, multiplied by the drawing alpha. |
| `[font=ui]interface[/font]` | Select a registered family. |
| `[size=28]large[/size]` | Select a registered logical font size. |
| `[style=heading]Title[/style]` | Apply a named partial style. |

Tags must nest properly. Closing a tag restores the enclosing style, including
all font and colour settings. An inner `alpha` replaces the enclosing opacity;
it does not multiply it again. Alpha without an explicit colour preserves the
current drawing RGB. Explicit foreground colours replace the drawing RGB.

Tag names are case-insensitive. Registered font and style names are
case-sensitive. Colours require exactly six hexadecimal digits after `#`.
Opacity accepts decimal values from 0 to 1. Sizes are positive integer identifiers
(up to 100000), in your application's logical font units. There are no quoted
attributes, whitespace around tag syntax, implicit closing tags or HTML entities.
A family or style name may contain internal spaces; use neither `[` nor `]` in it.

Newlines are ordinary BlitzMax `~n` characters. Whitespace, wrapping, grapheme
boundaries and bidirectional text follow the existing paragraph API and its
optional providers. This module does not provide underline, strikethrough,
embedded images, hyperlinks or paragraph-formatting tags.

## Literal brackets and interpolated text

Double an opening bracket to display it. A closing bracket needs no escape:

```text
[[b]this is literal[[/b]
```

Displays:

```text
[b]this is literal[/b]
```

Always escape literal content inserted into a markup string, for example player
names or chat messages:

```blitzmax
Local markup:String = "Welcome, [b]" + EscapeStyledText(playerName) + "[/b]!"
```

Escape only the literal portions, not the whole string containing your intended
tags. Backslashes have no special meaning to the markup parser.

## Fonts and named styles

Register font objects once, after loading them with your preferred font loader:

```blitzmax
Local styles:TStyledTextStyles = TStyledTextStyles.Create(regularFont)
styles.RegisterFont("default", boldFont, 0, True)
styles.RegisterFont("default", italicFont, 0, False, True)
styles.RegisterFont("default", boldItalicFont, 0, True, True)
styles.RegisterFont("default", headingFont, 28, True)

Local heading:TStyledTextStyle = New TStyledTextStyle
heading.bold = True
heading.size = 28
heading.foreground = $FFD060
styles.RegisterStyle("heading", heading)

Local prepared:TPreparedText = PrepareStyledText("[style=heading]Mission complete[/style]", styles)
```

Size zero in `RegisterFont` identifies the family's default face; the parser does
not scale that face to satisfy another size. Register every required size, or
supply a `TStyledTextFontResolver` through `styles.resolver`. A resolver should
cache fonts it loads. It receives the family, size and bold/italic flags, and
returns a font or `Null` if that exact request is unavailable.

Resolution first checks explicit registrations, then the resolver. A missing
bold, italic or bold-italic face falls back to **regular at the same family and
size**. A missing family or size throws. No synthetic bolding, shearing or file
loading occurs inside RichText. Resolution results are cached during each
preparation. Keep font objects alive and unchanged while layouts use them.

Named styles are partial overrides: unset fields inherit the enclosing style.
For example, a heading's colour does not erase an enclosing background.
`bold` and `italic` use `-1` for inherit, `0` for off and `1` for on. Colours use
`-1` for inherit, opacity uses `-1` for inherit, the empty font name inherits,
and size zero inherits. `RegisterStyle` copies the supplied settings.
`styles.defaultStyle` supplies overrides at the root of the document.

An unknown named style is a preparation error. Parsing cannot check registered
names, since the same document can be prepared with different collections.

## Parse, prepare, retain

For reusable content, keep parsing separate from style resolution:

```blitzmax
Local document:TStyledTextDocument = ParseStyledText(markup, True)
Local prepared:TPreparedText = document.Prepare(styles)
Local layout:TParagraphLayout = prepared.Layout(400)
```

- **Content changes:** parse and prepare the new content.
- **Fonts or theme change:** prepare the existing document again.
- **Panel width changes:** request a layout from the existing prepared text.
- **Position, clipping or scrolling changes:** keep the layout and draw it at the
  new position, optionally using `DrawTextLayoutVisible`.

Do not call `PrepareStyledText` in the drawing loop for unchanged content. It is
a convenience operation, not a global cache.

Parsing scans the string and matches tags with an iterative stack. Preparation
resolves inherited styles and merges adjacent equivalent font/colour spans. The
result uses the existing `TPreparedText` layout cache and rendering path, with no
markup traversal during drawing. Colour changes do not introduce font shaping
boundaries. This adds content preparation work and retained document storage;
the resulting drawing work is the same as supplying equivalent spans manually.

RichText enables the source mapping needed by the current span API. Caret
geometry and interaction caches remain lazy. No map from plain-text offsets back
to markup offsets is allocated.

## Selection, backgrounds and scrolling

`document.PlainText()` returns the text with valid tags removed and escapes
decoded. All span, caret and selection positions are **UTF-16 offsets into this
plain text**, so the existing `TTextSelectionController` works without seeing the
tags. Extract selected text with:

```blitzmax
Local selected:String = document.PlainText()[controller.SelectionStart()..controller.SelectionEnd()]
```

The paragraph API may collapse whitespace for display; offsets still refer to
the original plain text, as with ordinary prepared paragraphs.

`DrawTextLayout` draws both span backgrounds and glyphs by default. To put a
selection highlight between them, draw text backgrounds first, selection
rectangles second, then glyphs through `DrawTextLayoutVisible` with its
`backgrounds` argument set to `False`. Use the visible-range variants in a
scrollable panel. See
[rich_text.bmx](../examples/rich_text.bmx) for a complete interactive example with
font variants, theme switching, reflow, scrolling and selection.

## Invalid markup

By default, unsupported tags, invalid values, unmatched closing tags and unclosed
opening tags remain literal. Correctly paired tags elsewhere still take effect.
`document.Diagnostics()` returns descriptions and UTF-16 offsets into the
**original markup**, useful for reporting authoring errors.

For example, `[b]unfinished` remains `[b]unfinished`. With crossed tags such as
`[b][i]x[/b][/i]`, only the properly matched italic pair is removed, leaving
`[b]x[/b]`. Prefer strict validation for authored content:

```blitzmax
Local document:TStyledTextDocument = ParseStyledText(markup, True)
```

Strict mode throws at the first detected syntax error. Unknown registered font
or style names are checked later during preparation, in both modes.
