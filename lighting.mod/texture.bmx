Rem
bbdoc: Shared image and placement for a point light's projected colour pattern.
about: RGB and alpha multiply direct light, including specular highlights; they do not affect ambient illumination or receiver coverage. The image is shared, not owned. Placement uses lighting coordinate units relative to the point centre, independently of its radial falloff. Scene node transforms move the centre; projection size and angle are explicit world-space settings. Sampling outside the rectangle is transparent. No implicit colour-space conversion occurs.
End Rem
Type TMax2DLightTexture
	Internal
	Field image:TImage, frame:Int
	Field width:Float, height:Float, offsetX:Float, offsetY:Float, rotation:Float
	Field xx:Float, xy:Float, yx:Float, yy:Float, tx:Float, ty:Float
	Field revision:Long
	Field pixelRevision:Long
	Public
	Rem
	bbdoc: Creates a projected pattern, initially centred on the light at the image's pixel size.
	param: Borrowed image; its lifetime remains application-owned.
	param: Zero-based frame index in the supplied image.
	returns: A new #TMax2DLightTexture instance configured with the supplied settings.
	about: Requires a nonnull image frame. Use SetPlacement to choose a size in lighting coordinates.
	End Rem
	Function Create:TMax2DLightTexture(image:TImage, frame:Int = 0)
		Local result:TMax2DLightTexture = New TMax2DLightTexture
		result.SetImage(image, frame)
		result.SetPlacement(image.width, image.height)
		Return result
	End Function
	Rem
	bbdoc: Sets the shared image and frame, preserving an existing placement.
	param: Borrowed image; replacing it does not release the previous image.
	param: Zero-based frame index in the supplied image.
	about: An uninitialized description starts with the logical image dimensions as its projected size. Trimmed CPU-backed byte frames are supported using retained full-size sampling storage; removed margins become transparent. Call Invalidate after editing shared pixels.
	End Rem
	Method SetImage(value:TImage, frame:Int = 0)
		If Not value Then
			Throw "Max2D Lighting: light texture is null"
		End If

		value.CheckIndex(frame)
		If image = value And Self.frame = frame Then
			Return
		End If

		If width = 0 Or height = 0 Then
			SetPlacement(value.width, value.height)
		End If

		image = value
		Self.frame = frame
		revision :+ 1
		pixelRevision :+ 1
	End Method
	Rem
	bbdoc: Returns the shared image.
	returns: The shared image.
	End Rem
	Method GetImage:TImage()
		Return image
	End Method
	Rem
	bbdoc: Returns the selected frame.
	returns: The selected frame.
	End Rem
	Method GetFrame:Int()
		Return frame
	End Method
	Rem
	bbdoc: Sets projected width, height, centre offset and clockwise angle in degrees.
	param: Width in lighting/world units; finite and positive.
	param: Height in lighting/world units; finite and positive.
	param: Finite horizontal centre offset relative to the point light, in lighting units.
	param: Finite vertical centre offset relative to the point light, in lighting units.
	param: Finite clockwise rotation in degrees.
	about: Dimensions must be finite and positive; offsets and angle must be finite. Offsets use lighting coordinates relative to the point centre. Rotation is around the projected rectangle's centre. Settings are validated atomically. Placement is independent of radius and falloff; the two shapes multiply.
	End Rem
	Method SetPlacement(width:Float, height:Float, offsetX:Float = 0, offsetY:Float = 0, rotation:Float = 0)
		If IsNan(width) Or IsInf(width) Or width <= 0 Or IsNan(height) Or IsInf(height) Or height <= 0 Or IsNan(offsetX) Or IsInf(offsetX) Or IsNan(offsetY) Or IsInf(offsetY) Or IsNan(rotation) Or IsInf(rotation) Then
			Throw "Max2D Lighting: invalid light texture placement"
		End If

		Local c:Double = Cos(rotation), s:Double = Sin(rotation)
		Local a:Float = Float(c / width), b:Float = Float(s / width), d:Float = Float(-s / height), e:Float = Float(c / height)
		Local ox:Float = Float(0.5 - Double(a) * offsetX - Double(b) * offsetY), oy:Float = Float(0.5 - Double(d) * offsetX - Double(e) * offsetY)
		If IsNan(a) Or IsInf(a) Or IsNan(b) Or IsInf(b) Or IsNan(d) Or IsInf(d) Or IsNan(e) Or IsInf(e) Or IsNan(ox) Or IsInf(ox) Or IsNan(oy) Or IsInf(oy) Then
			Throw "Max2D Lighting: light texture placement is out of range"
		End If

		If Self.width = width And Self.height = height And Self.offsetX = offsetX And Self.offsetY = offsetY And Self.rotation = rotation Then
			Return
		End If

		Self.width = width
		Self.height = height
		Self.offsetX = offsetX
		Self.offsetY = offsetY
		Self.rotation = rotation
		xx = a
		xy = b
		yx = d
		yy = e
		tx = ox
		ty = oy
		revision :+ 1
	End Method
	Rem
	bbdoc: Copies projected size, centre offset and angle to caller variables without allocating.
	param: Receives width in lighting/world units; finite and positive.
	param: Receives height in lighting/world units; finite and positive.
	param: Receives finite horizontal offset in lighting-space units.
	param: Receives finite vertical offset in lighting-space units.
	param: Receives finite clockwise rotation in degrees.
	End Rem
	Method GetPlacement(width:Float Var, height:Float Var, offsetX:Float Var, offsetY:Float Var, rotation:Float Var)
		width = Self.width
		height = Self.height
		offsetX = Self.offsetX
		offsetY = Self.offsetY
		rotation = Self.rotation
	End Method
	Rem
	bbdoc: Marks edited image pixels as changed for cached scene receivers.
	about: Call after changing pixels in the shared image. Configuration edits invalidate automatically during the next lighting environment Prepare.
	End Rem
	Method Invalidate()
		revision :+ 1
		pixelRevision :+ 1
	End Method
	Rem
	bbdoc: Returns this description's revision.
	returns: This description's revision.
	End Rem
	Method Revision:Long()
		Return revision
	End Method
End Type
