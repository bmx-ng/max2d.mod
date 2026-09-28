SuperStrict

Rem
bbdoc: The backend-independent Max2D drawing API.
End Rem
Module Max2D.Core
ModuleInfo "Version: 0.02"
ModuleInfo "License: zlib/libpng"

Import Text.Boundaries
Import Text.Bidi
Import BRL.Graphics
Import BRL.TextureData
Import BRL.Pixmap
Import BRL.Font
Import BRL.PolledInput
Import BRL.LinkedList
Import BRL.Map
Import Math.Polygon

Rem
bbdoc: How the active backend represents a requested texture storage format.
about: Native retains the requested channels and precision; uploads may still reorder bytes. Converted uses a different storage representation with equivalent drawing semantics. Unsupported means this storage request or its flags are unavailable.
End Rem
Enum ETextureFormatSupport
	Unsupported
	Converted
	Native
End Enum

Const MASKBLEND:Int = 1
Const SOLIDBLEND:Int = 2
Const ALPHABLEND:Int = 3
Const LIGHTBLEND:Int = 4
Const SHADEBLEND:Int = 5
Const MASKEDIMAGE:Int = 1
Const FILTEREDIMAGE:Int = 2
Const MIPMAPPEDIMAGE:Int = 4
Const DYNAMICIMAGE:Int = 8
Const MAX2D_WINDOWED:Int = 0
Const MAX2D_FULLSCREEN:Int = 1
Const MAX2D_BORDERLESS_FULLSCREEN:Int = 2

Const VIRTUAL_STRETCH:Int = 0
Const VIRTUAL_LETTERBOX:Int = 1
Const VIRTUAL_NATIVE:Int = 2
Const VIRTUAL_INTEGER:Int = 3

Incbin "blitzfont.bin"

Include "driver.bmx"
Include "image.bmx"
Include "atlas.bmx"
Include "camera.bmx"
Include "canvas.bmx"
Include "textpaint.bmx"
Include "text.bmx"
Include "textstyles.bmx"
Include "textbidi.bmx"
Include "paragraph.bmx"
Include "textinteraction.bmx"
Include "textselection.bmx"
Include "input.bmx"
Include "collision.bmx"
Include "api.bmx"
Include "overloads.bmx"
