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

	Rem
	bbdoc: The requested storage format or flags cannot be used by the backend.
	End Rem
	Unsupported

	Rem
	bbdoc: Drawing semantics are preserved using another native storage representation.
	End Rem
	Converted

	Rem
	bbdoc: The requested channels and precision are stored natively; byte order may still change on upload.
	End Rem
	Native
End Enum

Rem
bbdoc: Discards pixels below the backend's mask alpha threshold; query support before use.
End Rem
Const MASKBLEND:Int = 1

Rem
bbdoc: Replaces destination pixels without alpha blending.
End Rem
Const SOLIDBLEND:Int = 2

Rem
bbdoc: Blends source colour over the destination using source alpha.
End Rem
Const ALPHABLEND:Int = 3

Rem
bbdoc: Adds source colour to the destination using source alpha.
End Rem
Const LIGHTBLEND:Int = 4

Rem
bbdoc: Multiplies destination colour by source colour.
End Rem
Const SHADEBLEND:Int = 5

Rem
bbdoc: Uses the mask colour when loading image pixels that have no alpha channel.
End Rem
Const MASKEDIMAGE:Int = 1

Rem
bbdoc: Enables smooth texture filtering when drawing the image.
End Rem
Const FILTEREDIMAGE:Int = 2

Rem
bbdoc: Requests mipmap sampling and generation where supported.
End Rem
Const MIPMAPPEDIMAGE:Int = 4

Rem
bbdoc: Allows CPU pixel editing through image locks.
End Rem
Const DYNAMICIMAGE:Int = 8

Rem
bbdoc: Windowed presentation mode.
End Rem
Const MAX2D_WINDOWED:Int = 0

Rem
bbdoc: Exclusive fullscreen presentation mode.
End Rem
Const MAX2D_FULLSCREEN:Int = 1

Rem
bbdoc: Borderless fullscreen at the desktop display mode.
End Rem
Const MAX2D_BORDERLESS_FULLSCREEN:Int = 2

Rem
bbdoc: Scales the virtual scene independently on each axis to fill the destination.
End Rem
Const VIRTUAL_STRETCH:Int = 0

Rem
bbdoc: Preserves aspect ratio and centres the scene with bars where required.
End Rem
Const VIRTUAL_LETTERBOX:Int = 1

Rem
bbdoc: Uses one logical drawing unit per native destination pixel.
End Rem
Const VIRTUAL_NATIVE:Int = 2

Rem
bbdoc: Uses integer upscaling when possible, or fractional downscaling to keep the scene visible.
End Rem
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
