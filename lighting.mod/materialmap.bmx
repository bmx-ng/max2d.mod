Rem
bbdoc: Retained CPU builder for a normal map with per-pixel gloss in alpha.
about: Use when normal and grayscale gloss artwork are authored separately. Update returns a borrowed image suitable for SetNormalMap with SetSpecularFromNormalAlpha(True). Inputs are shared, never modified or owned. Unchanged updates allocate nothing. Changed inputs rebuild CPU pixels and mark the existing output for upload; rendering still uses one material sampler. This builder does not resample, read back render targets or decompress textures.
End Rem
Type TMax2DLightingMaterialMap
	Private
	Field filtered:Int
	Field output:TImage, pixels:TPixmap
	Field normal:TImage, gloss:TImage
	Field normalSource:TImageSource, glossSource:TImageSource
	Field normalVersion:Long, glossVersion:Long
	Field normalIndex:Int, glossIndex:Int
	Field normalX:Int, normalY:Int, glossX:Int, glossY:Int
	Public
	Rem
	bbdoc: Creates an empty reusable builder; output filtering defaults to True.
	param: True for filtered output sampling, False for unfiltered sampling.
	returns: A new #TMax2DLightingMaterialMap instance configured with the supplied settings.
	End Rem
	Function Create:TMax2DLightingMaterialMap(filtered:Int = True)
		Local result:TMax2DLightingMaterialMap = New TMax2DLightingMaterialMap
		result.filtered = filtered <> 0
		Return result
	End Function
	Rem
	bbdoc: Packs normal RGB and gloss strength into a retained image and returns it borrowed.
	param: Borrowed straight-alpha RGBA8888 normal artwork; Null uses a viewer-facing normal.
	param: Borrowed RGBA8888 red or A8 gloss-strength artwork; Null uses full strength.
	param: Zero-based normal-image frame; use zero when the image is Null.
	param: Zero-based gloss-image frame; use zero when the image is Null.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: At least one input is required. Null normal uses RGB (128,128,255); Null gloss uses full strength. RGBA8888 gloss uses red, ignoring alpha; A8 gloss uses its byte value. Normal data must be straight-alpha RGBA8888; its alpha is ignored. Inputs must have equal logical dimensions when both are supplied. Untrimmed atlas frames are supported. Trimmed frames, locked images, render targets, compressed and floating-point data are rejected before changing output. Frame indices must be valid; Null requires frame zero. Use ReplacePixels or normal image write locks to report source changes. Repeated calls with unchanged source revisions reuse both CPU and GPU storage. Same-sized edits preserve output identity; dimension changes replace it. Apply the returned image to materials after every update that might resize it, and invalidate cached receivers after pixel edits. The returned image expires on replacement or Release and must not be modified, released or supplied as input by the caller. No source image is retained after Release.
	End Rem
	Method Update:TImage(normal:TImage, gloss:TImage, normalFrame:Int = 0, glossFrame:Int = 0)
		If Not normal And Not gloss Then
			Throw "Max2D Lighting: material map needs normal or gloss artwork"
		End If

		If output And (normal = output Or gloss = output) Then
			Throw "Max2D Lighting: material output cannot be its own input"
		End If

		Local ns:TImageSource = Validate(normal, normalFrame, False)
		Local gs:TImageSource = Validate(gloss, glossFrame, True)
		Local width:Int, height:Int
		If normal Then width = normal.width;height = normal.height Else width = gloss.width;height = gloss.height

		If normal And gloss Then
			If normal.width <> gloss.width Or normal.height <> gloss.height Then
				Throw "Max2D Lighting: material map dimensions must match"
			End If
		End If

		Local nx:Int, ny:Int, gx:Int, gy:Int, nv:Long, gv:Long
		If normal Then nx = normal.sourceX[normalFrame];ny = normal.sourceY[normalFrame];nv = ns.version

		If gloss Then gx = gloss.sourceX[glossFrame];gy = gloss.sourceY[glossFrame];gv = gs.version

		If output Then
			If output.width = width And output.height = height And Self.normal = normal And Self.gloss = gloss And normalSource = ns And glossSource = gs And normalVersion = nv And glossVersion = gv And normalIndex = normalFrame And glossIndex = glossFrame And normalX = nx And normalY = ny And glossX = gx And glossY = gy Then
				Return output
			End If
		End If

		Local np:TPixmap, gp:TPixmap
		If ns Then
			np = ns.ReadPixels()
		End If

		If gs Then
			gp = gs.ReadPixels()
		End If

		If Not pixels Or pixels.width <> width Or pixels.height <> height Then
			pixels = CreatePixmap(width, height, PF_RGBA8888)
		End If

		For Local y:Int = 0 Until height
			For Local x:Int = 0 Until width
				Local rgb:Int = $8080ff, alpha:Int = 255
				If np Then
					rgb = np.ReadPixel(nx + x, ny + y) & $ffffff
				End If

				If gp Then
					Local sample:Int = gp.ReadPixel(gx + x, gy + y)
					If gp.format = PF_A8 Then alpha = sample Shr 24 & 255 Else alpha = sample Shr 16 & 255
				End If

				pixels.WritePixel(x, y, (alpha Shl 24) | rgb)
			Next
		Next

		If Not output Then
			output = TImage.FromPixmap(pixels, filtered * FILTEREDIMAGE)
		Else If output.width <> width Or output.height <> height Then
			Local replacement:TImage = TImage.FromPixmap(pixels, filtered * FILTEREDIMAGE)
			output.ReleaseFrames();output = replacement
		Else
			output.ReplacePixels(pixels)
		End If

		Self.normal = normal;Self.gloss = gloss;normalSource = ns;glossSource = gs
		normalVersion = nv;glossVersion = gv;normalIndex = normalFrame;glossIndex = glossFrame
		normalX = nx;normalY = ny;glossX = gx;glossY = gy
		Return output
	End Method
	Rem
	bbdoc: Releases output textures, CPU packing storage and borrowed input references.
	about: Does not release input images. Call Update to build again. Remove the borrowed output from materials before releasing or replacing it. Repeated Release calls are harmless.
	End Rem
	Method Release()
		If output Then
			output.ReleaseFrames()
		End If

		output = Null;pixels = Null;normal = Null;gloss = Null;normalSource = Null;glossSource = Null
	End Method

	Internal
	Function Validate:TImageSource(image:TImage, frame:Int, gloss:Int)
		If Not image Then
			If frame <> 0 Then
				Throw "Max2D Lighting: null material artwork requires frame zero"
			End If

			Return Null
		End If

		image.CheckIndex(frame)
		Local source:TImageSource = image.sources[frame]
		If source.renderTarget Or source.locked Or image.Trim(frame) Then
			Throw "Max2D Lighting: material packing requires unlocked, untrimmed CPU artwork"
		End If

		If source.pixmap Then
			If source.pixmap.format = PF_RGBA8888 Or (gloss And source.pixmap.format = PF_A8) Then
				Return source
			End If
		Else If source.textureData Then
			If source.textureData.Format() = PF_RGBA8888 Or (gloss And source.textureData.Format() = PF_A8) Then
				Return source
			End If
		End If

		Throw "Max2D Lighting: material packing requires RGBA8888 normals and RGBA8888 or A8 gloss"
	End Function
End Type
