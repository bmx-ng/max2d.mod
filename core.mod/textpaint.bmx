
Rem
bbdoc: Optional foreground/background paint over a half-open original-source range.
about: Configure before passing to SetColorSpans, which takes a snapshot. Opacity multiplies the current drawing alpha. A cluster uses the style at its first source position; later overlapping spans win independently for each channel.
End Rem
Type TTextColorSpan

	Rem
	bbdoc: Inclusive UTF-16 source offset.
	End Rem
	Field sourceStart:Int

	Rem
	bbdoc: Exclusive UTF-16 source offset.
	End Rem
	Field sourceEnd:Int

	Rem
	bbdoc: Whether this span overrides glyph colour.
	End Rem
	Field hasForeground:Int

	Rem
	bbdoc: Whether this span supplies background paint.
	End Rem
	Field hasBackground:Int

	Rem
	bbdoc: Red colour component from 0 to 255.
	End Rem
	Field red:Int

	Rem
	bbdoc: Green colour component from 0 to 255.
	End Rem
	Field green:Int

	Rem
	bbdoc: Blue colour component from 0 to 255.
	End Rem
	Field blue:Int

	Rem
	bbdoc: Opacity multiplier from 0.0 to 1.0.
	End Rem
	Field opacity:Float=1

	Rem
	bbdoc: Background red component from 0 to 255.
	End Rem
	Field backgroundRed:Int

	Rem
	bbdoc: Background green component from 0 to 255.
	End Rem
	Field backgroundGreen:Int

	Rem
	bbdoc: Background blue component from 0 to 255.
	End Rem
	Field backgroundBlue:Int

	Rem
	bbdoc: Background opacity multiplier from 0.0 to 1.0.
	End Rem
	Field backgroundOpacity:Float=1

	Rem
	bbdoc: Creates an initially unstyled colour span over a half-open source range.
	param: Inclusive UTF-16 start offset in the original source.
	param: Exclusive UTF-16 end offset in the original source.
	End Rem
	Function Create:TTextColorSpan(first:Int,last:Int)
		Local result:TTextColorSpan=New TTextColorSpan
		result.sourceStart=first;result.sourceEnd=last
		Return result
	End Function

	Rem
	bbdoc: Sets the glyph colour and opacity applied by this span.
	param: Red component, from 0 to 255.
	param: Green component, from 0 to 255.
	param: Blue component, from 0 to 255.
	param: Opacity multiplier from 0.0 to 1.0.
	End Rem
	Method SetForeground(red:Int,green:Int,blue:Int,opacity:Float=1)
		If IsNan(opacity) Or IsInf(opacity) Then Throw "Max2D: text opacity must be finite"
		Self.red=Max(0,Min(255,red));Self.green=Max(0,Min(255,green));Self.blue=Max(0,Min(255,blue))
		Self.opacity=Max(0.0,Min(1.0,opacity));hasForeground=True
	End Method

	Rem
	bbdoc: Sets the background colour and opacity applied by this span.
	param: Red component, from 0 to 255.
	param: Green component, from 0 to 255.
	param: Blue component, from 0 to 255.
	param: Opacity multiplier from 0.0 to 1.0.
	End Rem
	Method SetBackground(red:Int,green:Int,blue:Int,opacity:Float=1)
		If IsNan(opacity) Or IsInf(opacity) Then Throw "Max2D: text opacity must be finite"
		backgroundRed=Max(0,Min(255,red));backgroundGreen=Max(0,Min(255,green));backgroundBlue=Max(0,Min(255,blue))
		backgroundOpacity=Max(0.0,Min(1.0,opacity));hasBackground=True
	End Method

	Rem
	bbdoc: Returns a copy that can be modified independently of this object's scalar settings.
	End Rem
	Method Copy:TTextColorSpan()
		Local result:TTextColorSpan=Create(sourceStart,sourceEnd)
		If hasForeground Then result.SetForeground(red,green,blue,opacity)
		If hasBackground Then result.SetBackground(backgroundRed,backgroundGreen,backgroundBlue,backgroundOpacity)
		Return result
	End Method

End Type

Rem
bbdoc: A local text-background rectangle and its colour span.
End Rem
Type TTextBackground

	Rem
	bbdoc: Left edge of a background rectangle relative to the line origin.
	End Rem
	Field x:Float

	Rem
	bbdoc: Top edge of a background rectangle relative to the line origin.
	End Rem
	Field y:Float

	Rem
	bbdoc: Logical width of this object or region.
	End Rem
	Field width:Float

	Rem
	bbdoc: Logical height of this object or region.
	End Rem
	Field height:Float

	Rem
	bbdoc: Colour span or imported colour metadata associated with this item.
	End Rem
	Field color:TTextColorSpan
End Type

Rem
bbdoc: Cached glyph colours and background rectangles for a shaped text line.
End Rem
Type TTextPaint

	Rem
	bbdoc: Source paint revision represented by the cached colours and rectangles.
	End Rem
	Field revision:Int

	Rem
	bbdoc: Colour span assigned to each glyph, or Null entries for the drawing colour.
	End Rem
	Field glyphColors:TTextColorSpan[]

	Rem
	bbdoc: Retained background rectangles for the text line.
	End Rem
	Field backgrounds:TTextBackground[]

	Rem
	bbdoc: Applies a span colour or the caller's fallback drawing colour.
	param: Drawing state to inspect or apply.
	param: Span colour to apply, or Null to use the supplied fallback components.
	param: Red component, from 0 to 255.
	param: Green component, from 0 to 255.
	param: Blue component, from 0 to 255.
	param: Opacity multiplier, from 0.0 to 1.0.
	End Rem
	Function Apply(state:TMax2DState,color:TTextColorSpan,red:Int,green:Int,blue:Int,alpha:Float)
		If color Then
			state.red=color.red;state.green=color.green;state.blue=color.blue;state.alpha=alpha*color.opacity
		Else
			state.red=red;state.green=green;state.blue=blue;state.alpha=alpha
		End If
	End Function

	Rem
	bbdoc: Draws cached text-background rectangles while restoring the caller's drawing colour.
	param: Drawing canvas whose state and rendering context are used.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method DrawBackgrounds(canvas:TMax2DGraphics,x:Float,y:Float)
		Local red:Int=canvas.state.red,green:Int=canvas.state.green,blue:Int=canvas.state.blue
		Local alpha:Float=canvas.state.alpha
		Try
			For Local rectangle:TTextBackground=EachIn backgrounds
				Local color:TTextColorSpan=rectangle.color
				canvas.state.red=color.backgroundRed;canvas.state.green=color.backgroundGreen;canvas.state.blue=color.backgroundBlue
				canvas.state.alpha=alpha*color.backgroundOpacity
				Local left:Float=rectangle.x-canvas.state.handleX,top:Float=rectangle.y-canvas.state.handleY
				canvas.Quad(Null,left,top,left+rectangle.width,top+rectangle.height,x+canvas.state.originX,y+canvas.state.originY)
			Next
		Catch error:Object
			canvas.state.red=red;canvas.state.green=green;canvas.state.blue=blue;canvas.state.alpha=alpha
			Throw error
		End Try
		canvas.state.red=red;canvas.state.green=green;canvas.state.blue=blue;canvas.state.alpha=alpha
	End Method

End Type
