Rem
bbdoc: Optional foreground/background paint over a half-open original-source range.
about: Configure before passing to SetColorSpans, which takes a snapshot. Opacity multiplies the current drawing alpha. A cluster uses the style at its first source position; later overlapping spans win independently for each channel.
End Rem
Type TTextColorSpan
	Field sourceStart:Int,sourceEnd:Int
	Field hasForeground:Int,hasBackground:Int
	Field red:Int,green:Int,blue:Int,opacity:Float=1
	Field backgroundRed:Int,backgroundGreen:Int,backgroundBlue:Int,backgroundOpacity:Float=1
	Function Create:TTextColorSpan(first:Int,last:Int)
		Local result:TTextColorSpan=New TTextColorSpan
		result.sourceStart=first;result.sourceEnd=last
		Return result
	End Function
	Method SetForeground(red:Int,green:Int,blue:Int,opacity:Float=1)
		If IsNan(opacity) Or IsInf(opacity) Then Throw "Max2D: text opacity must be finite"
		Self.red=Max(0,Min(255,red));Self.green=Max(0,Min(255,green));Self.blue=Max(0,Min(255,blue))
		Self.opacity=Max(0.0,Min(1.0,opacity));hasForeground=True
	End Method
	Method SetBackground(red:Int,green:Int,blue:Int,opacity:Float=1)
		If IsNan(opacity) Or IsInf(opacity) Then Throw "Max2D: text opacity must be finite"
		backgroundRed=Max(0,Min(255,red));backgroundGreen=Max(0,Min(255,green));backgroundBlue=Max(0,Min(255,blue))
		backgroundOpacity=Max(0.0,Min(1.0,opacity));hasBackground=True
	End Method
	Method Copy:TTextColorSpan()
		Local result:TTextColorSpan=Create(sourceStart,sourceEnd)
		If hasForeground Then result.SetForeground(red,green,blue,opacity)
		If hasBackground Then result.SetBackground(backgroundRed,backgroundGreen,backgroundBlue,backgroundOpacity)
		Return result
	End Method
End Type

Type TTextBackground
	Field x:Float,y:Float,width:Float,height:Float
	Field color:TTextColorSpan
End Type

Type TTextPaint
	Field revision:Int
	Field glyphColors:TTextColorSpan[]
	Field backgrounds:TTextBackground[]
	Function Apply(state:TMax2DState,color:TTextColorSpan,red:Int,green:Int,blue:Int,alpha:Float)
		If color Then
			state.red=color.red;state.green=color.green;state.blue=color.blue;state.alpha=alpha*color.opacity
		Else
			state.red=red;state.green=green;state.blue=blue;state.alpha=alpha
		End If
	End Function
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
