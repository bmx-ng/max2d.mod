Rem
bbdoc: Converts an 8-bit straight-alpha sRGB pixmap to linear RGBA32F texture data.
about: Converts RGB with the piecewise sRGB transfer function; alpha remains linear coverage. The source is unchanged. Convert once before LoadImage so filtering and generated mipmaps operate on linear values. This does not interpret ICC profiles, premultiplied artwork or wider colour spaces. The result contains one mip level and allocates CPU storage only.
End Rem
Function SRGBPixmapToLinearTextureData:TTextureData(pixmap:TPixmap)
	If Not pixmap Then Throw "Max2D Effects: source pixmap is null"
	If pixmap.format <> PF_RGBA8888 And pixmap.format <> PF_BGRA8888 And pixmap.format <> PF_RGB888 And pixmap.format <> PF_BGR888 And pixmap.format <> PF_I8 And pixmap.format <> PF_A8 Then Throw "Max2D Effects: sRGB conversion requires an 8-bit pixmap"
	If pixmap.width <= 0 Or pixmap.height <= 0 Or Long(pixmap.width)*pixmap.height > $7fffffff/16 Then Throw "Max2D Effects: pixmap dimensions are invalid or too large"
	Local lookup:Float[256]
	For Local i:Int = 0 Until 256
		Local value:Double = i/255.0
		If value <= 0.04045 Then
			lookup[i] = Float(value/12.92)
		Else
			lookup[i] = Float(Exp(Log((value+0.055)/1.055)*2.4))
		End If
	Next
	Local bytes:Byte[] = New Byte[pixmap.width*pixmap.height*16]
	Local values:Float Ptr = Float Ptr(bytes)
	For Local y:Int = 0 Until pixmap.height
		For Local x:Int = 0 Until pixmap.width
			Local pixel:Int = pixmap.ReadPixel(x, y)
			Local offset:Int = (y*pixmap.width+x)*4
			values[offset] = lookup[(pixel Shr 16) & 255]
			values[offset+1] = lookup[(pixel Shr 8) & 255]
			values[offset+2] = lookup[pixel & 255]
			values[offset+3] = ((pixel Shr 24) & 255)/255.0
		Next
	Next
	Return TTextureData.Create([TTextureLevel.Create(pixmap.width, pixmap.height, PF_RGBA32F, bytes)])
End Function

Rem
bbdoc: Presents linear scene colours as extended linear HDR or tone-mapped sRGB.
about: HDR multiplies nonnegative RGB by exposure and white level. SDR applies exposure, per-channel Reinhard mapping and the piecewise sRGB encoding curve; white level is ignored. Alpha is preserved. Drawing tint is linear and applied before output conversion. Use an opaque scene and SOLIDBLEND for final presentation, since blending encoded SDR output is not linear composition. This effect does not select the window output mode.
End Rem
Type TMax2DLinearOutputEffect Extends TMax2DImageEffect
	Private
	Field hdr:Int
	Field exposure:Float = 1
	Field whiteLevel:Float = 1
	Public
	Rem
	bbdoc: Selects extended linear HDR output when True, or tone-mapped sRGB when False.
	End Rem
	Method SetHDR(enabled:Int)
		hdr = enabled <> 0
	End Method
	Rem
	bbdoc: Returns whether extended linear HDR output is selected.
	End Rem
	Method IsHDR:Int()
		Return hdr
	End Method
	Rem
	bbdoc: Sets the finite, nonnegative exposure multiplier.
	End Rem
	Method SetExposure(value:Float)
		If value < 0 Or IsNan(value) Or IsInf(value) Then Throw "Max2D Effects: exposure must be finite and nonnegative"
		exposure = value
	End Method
	Rem
	bbdoc: Returns the exposure multiplier.
	End Rem
	Method GetExposure:Float()
		Return exposure
	End Method
	Rem
	bbdoc: Sets the finite, positive SDR white level used by extended linear HDR output.
	about: Use the SDL GPU context's SDRWhiteLevel; this setting is ignored for SDR output.
	End Rem
	Method SetWhiteLevel(value:Float)
		If value <= 0 Or IsNan(value) Or IsInf(value) Then Throw "Max2D Effects: white level must be finite and positive"
		whiteLevel = value
	End Method
	Rem
	bbdoc: Returns the HDR output white level.
	End Rem
	Method GetWhiteLevel:Float()
		Return whiteLevel
	End Method
End Type

Rem
bbdoc: Creates a linear-scene output effect; defaults to tone-mapped sRGB with unit exposure.
End Rem
Function CreateLinearOutputEffect:TMax2DLinearOutputEffect(hdr:Int = False, exposure:Float = 1, whiteLevel:Float = 1)
	Local effect:TMax2DLinearOutputEffect = New TMax2DLinearOutputEffect
	effect.SetHDR(hdr)
	effect.SetExposure(exposure)
	effect.SetWhiteLevel(whiteLevel)
	Return effect
End Function
