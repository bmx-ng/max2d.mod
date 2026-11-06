Rem
bbdoc: Blend factor: zero.
End Rem
Const BLEND_ZERO:Int = 1

Rem
bbdoc: Blend factor: one.
End Rem
Const BLEND_ONE:Int = 2

Rem
bbdoc: Blend factor: source colour.
End Rem
Const BLEND_SRC_COLOR:Int = 3

Rem
bbdoc: Blend factor: one minus source colour.
End Rem
Const BLEND_ONE_MINUS_SRC_COLOR:Int = 4

Rem
bbdoc: Blend factor: source alpha.
End Rem
Const BLEND_SRC_ALPHA:Int = 5

Rem
bbdoc: Blend factor: one minus source alpha.
End Rem
Const BLEND_ONE_MINUS_SRC_ALPHA:Int = 6

Rem
bbdoc: Blend factor: destination colour.
End Rem
Const BLEND_DST_COLOR:Int = 7

Rem
bbdoc: Blend factor: one minus destination colour.
End Rem
Const BLEND_ONE_MINUS_DST_COLOR:Int = 8

Rem
bbdoc: Blend factor: destination alpha.
End Rem
Const BLEND_DST_ALPHA:Int = 9

Rem
bbdoc: Blend factor: one minus destination alpha.
End Rem
Const BLEND_ONE_MINUS_DST_ALPHA:Int = 10

Rem
bbdoc: Blend operation: add.
End Rem
Const BLEND_OP_ADD:Int = 1

Rem
bbdoc: Blend operation: source term minus destination term.
End Rem
Const BLEND_OP_SUBTRACT:Int = 2

Rem
bbdoc: Blend operation: destination term minus source term.
End Rem
Const BLEND_OP_REVERSE_SUBTRACT:Int = 3

Rem
bbdoc: Blend operation: component-wise minimum of source and destination, ignoring factors.
End Rem
Const BLEND_OP_MIN:Int = 4

Rem
bbdoc: Blend operation: component-wise maximum of source and destination, ignoring factors.
End Rem
Const BLEND_OP_MAX:Int = 5

Rem
bbdoc: Subtracts source colour times source alpha from destination colour, preserving destination alpha.
about: Query Max2DSupportsBlend before use. Normalized targets clamp negative values to zero; floating-point targets can retain negative values.
End Rem
Const SUBTRACTBLEND:Int = 6

Rem
bbdoc: Creates a reusable custom blend mode for SetBlend, without allocating graphics resources.
param: Source colour factor, one of the BLEND_ constants.
param: Destination colour factor, one of the BLEND_ constants.
param: Colour operation, one of the BLEND_OP_ constants.
param: Source alpha factor.
param: Destination alpha factor.
param: Alpha operation.
returns: An opaque integer blend mode; identical arguments return the same value.
about: Create modes once and query Max2DSupportsBlend on the active backend. Source RGB is straight (not premultiplied), after image sampling and drawing tint; source alpha includes drawing opacity. Destination values are the stored framebuffer values, including premultiplied RGB in render images. Alpha factors using colour names refer to the corresponding alpha component. MIN/MAX ignore factors. Invalid arguments throw; valid but unsupported combinations are rejected by SetBlend. No Free call is needed.
End Rem
Function CreateBlendMode:Int(source:Int, destination:Int, operation:Int = BLEND_OP_ADD, sourceAlpha:Int = BLEND_ONE, destinationAlpha:Int = BLEND_ONE_MINUS_SRC_ALPHA, alphaOperation:Int = BLEND_OP_ADD)
	If source < BLEND_ZERO Or source > BLEND_ONE_MINUS_DST_ALPHA Or destination < BLEND_ZERO Or destination > BLEND_ONE_MINUS_DST_ALPHA Then Throw "Max2D: invalid colour blend factor"
	If sourceAlpha < BLEND_ZERO Or sourceAlpha > BLEND_ONE_MINUS_DST_ALPHA Or destinationAlpha < BLEND_ZERO Or destinationAlpha > BLEND_ONE_MINUS_DST_ALPHA Then Throw "Max2D: invalid alpha blend factor"
	If operation < BLEND_OP_ADD Or operation > BLEND_OP_MAX Or alphaOperation < BLEND_OP_ADD Or alphaOperation > BLEND_OP_MAX Then Throw "Max2D: invalid blend operation"
	' Alpha equations use scalar components. Canonicalize colour aliases.
	Select sourceAlpha
		Case BLEND_SRC_COLOR, BLEND_ONE_MINUS_SRC_COLOR
			sourceAlpha :+ 2
		Case BLEND_DST_COLOR, BLEND_ONE_MINUS_DST_COLOR
			sourceAlpha :+ 2
	End Select
	Select destinationAlpha
		Case BLEND_SRC_COLOR, BLEND_ONE_MINUS_SRC_COLOR
			destinationAlpha :+ 2
		Case BLEND_DST_COLOR, BLEND_ONE_MINUS_DST_COLOR
			destinationAlpha :+ 2
	End Select
	If operation >= BLEND_OP_MIN Then
		source = BLEND_ONE
		destination = BLEND_ONE
	End If
	If alphaOperation >= BLEND_OP_MIN Then
		sourceAlpha = BLEND_ONE
		destinationAlpha = BLEND_ONE
	End If
	Return $10000000 | source | (destination Shl 4) | (operation Shl 8) | (sourceAlpha Shl 12) | (destinationAlpha Shl 16) | (alphaOperation Shl 20)
End Function
