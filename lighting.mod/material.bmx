Rem
bbdoc: Shared receiver settings for individual lit images.
about: A material selects which lights affect an image, or bypasses illumination entirely. It does not own supplied images or lights; it owns any derived specular packing storage. Optional normal maps provide per-pixel diffuse response. Optional specular strength and shininess add light-coloured highlights. Shadow reception can be disabled independently of casting. Normal-map alpha can optionally modulate specular strength. Source-coloured emission keeps artwork visible independently of incoming light. Optional emission artwork modulates that contribution; separate specular artwork can be offered directly to renderer providers, with retained normal-alpha packing as the compatibility path.
End Rem
Type TMax2DLightingMaterial
	Private
	Field emissionRed:Int = 255, emissionGreen:Int = 255, emissionBlue:Int = 255
	Field emissionMap:TImage, specularMap:TImage
	Field emissionFrame:Int, specularFrame:Int
	Field packed:TMax2DLightingMaterialMap
	Field emissionVersion:Long = -1, specularVersion:Long = -1, normalVersion:Long = -1
	Field emissionIntensity:Float
	Field receiverMask:Int = -1
	Field receiveShadows:Int = True
	Field unlit:Int
	Field revision:Long
	Field normalMap:TImage
	Field normalFrame:Int
	Field normalStrength:Float = 1
	Field specularStrength:Float
	Field shininess:Float = 32
	Field specularFromNormalAlpha:Int
	Public
	Rem
	bbdoc: Creates a material receiving all lights and ambient illumination.
	returns: A new #TMax2DLightingMaterial instance configured with the supplied settings.
	End Rem
	Function Create:TMax2DLightingMaterial()
		Return New TMax2DLightingMaterial
	End Function
	Rem
	bbdoc: Sets source-coloured emission, independent of ambient illumination and lights; default intensity zero.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	about: RGB components must be 0..255 and intensity finite and nonnegative. Adds sourceRGB * emissionRGB/255 * intensity before direct lighting. This makes artwork self-lit while preserving normal/specular lighting and shadows on incoming light. It does not illuminate neighbours or cast light; use a light node for that and bloom for a halo. Source coverage, drawing tint and alpha still apply. Receiver masks and shadow reception do not suppress emission; SetUnlit bypasses the material entirely, including emission. Without an emission map, existing ambient composition carries emission without extra passes or textures. SetEmissionMap modulates this contribution per pixel. Floating-point targets retain values above one. Scene receivers observe edits at the next environment Prepare.
	End Rem
	Method SetEmission(red:Int, green:Int, blue:Int, intensity:Float = 1)
		If red < 0 Or red > 255 Or green < 0 Or green > 255 Or blue < 0 Or blue > 255 Or IsNan(intensity) Or IsInf(intensity) Or intensity < 0 Then
			Throw "Max2D Lighting: invalid emission settings"
		End If

		If emissionRed = red And emissionGreen = green And emissionBlue = blue And emissionIntensity = intensity Then
			Return
		End If

		emissionRed = red;emissionGreen = green;emissionBlue = blue;emissionIntensity = intensity;revision :+ 1
	End Method
	Rem
	bbdoc: References RGB emission modulation artwork, or clears it with Null.
	param: Shared material-map image, or Null to clear it; format and mapping requirements are described below.
	param: Zero-based frame index in the supplied image.
	about: The full map rectangle covers the receiver independently of image size and handle. RGB multiplies the source-coloured SetEmission value; alpha also masks emission. A8 uses white RGB and its alpha. Atlas and trimmed byte images are supported. Source coverage and drawing tint still apply. Zero emission intensity disables the map. With light batching, eligible native groups combine mapped ambient/emission with direct lighting alongside shadow and projected-pattern textures where the four-texture material shader is supported. Three-texture providers combine emission only when the first group needs no light maps. Other groups/providers retain a separate ambient pass. Shared artwork is not owned. CPU pixel revisions invalidate scene receivers during Prepare; call InvalidateMaps after other content changes.
	End Rem
	Method SetEmissionMap(image:TImage, frame:Int = 0)
		ValidateFrame(image, frame)
		If emissionMap = image And emissionFrame = frame Then
			Return
		End If

		emissionMap = image;emissionFrame = frame;revision :+ 1
	End Method
	Rem
	bbdoc: Returns shared emission artwork, or Null.
	returns: Shared emission artwork, or Null.
	End Rem
	Method GetEmissionMap:TImage();Return emissionMap;End Method
	Rem
	bbdoc: Returns the selected emission artwork frame.
	returns: The selected emission artwork frame.
	End Rem
	Method GetEmissionFrame:Int();Return emissionFrame;End Method
	Rem
	bbdoc: References separate grayscale specular-strength artwork, or clears it with Null.
	param: Shared material-map image, or Null to clear it; format and mapping requirements are described below.
	param: Zero-based frame index in the supplied image.
	about: RGBA8888 red or A8 alpha multiplies SetSpecular strength; zero is matte. Overrides SetSpecularFromNormalAlpha while present. With batching enabled, providers advertising MappedSpecular receive the original maps first. Built-in native renderers sample independent artwork with five-texture shaders where available. Rejected combinations use retained CPU packing into normal-map alpha, preserving existing lighting paths. Different normal/gloss filtering settings retain packing so both channels keep the established gloss filtering mode. Requires unlocked, untrimmed CPU RGBA8888 normals and RGBA8888 or A8 specular artwork with matching logical dimensions; atlas frames are supported. Null normals use a viewer-facing surface. Inputs are borrowed. Packing is deferred until direct lighting needs it, rebuilt only after pixel/configuration edits and uses one retained RGBA image per material. Ambient/emission-only receivers do not resolve normal/specular maps. CPU pixel edits invalidate scene receivers at Prepare; call InvalidateMaps after other content edits. ReleaseResources discards packing without changing settings.
	End Rem
	Method SetSpecularMap(image:TImage, frame:Int = 0)
		ValidateFrame(image, frame)
		If image Then
			ValidatePacking(normalMap, normalFrame, image, frame)
		End If

		If specularMap = image And specularFrame = frame Then
			Return
		End If

		specularMap = image;specularFrame = frame;revision :+ 1
		ReleaseResources()
	End Method
	Rem
	bbdoc: Returns shared separate specular artwork, or Null.
	returns: Shared separate specular artwork, or Null.
	End Rem
	Method GetSpecularMap:TImage();Return specularMap;End Method
	Rem
	bbdoc: Returns the selected specular artwork frame.
	returns: The selected specular artwork frame.
	End Rem
	Method GetSpecularFrame:Int();Return specularFrame;End Method
	Rem
	bbdoc: Invalidates derived map storage and cached scene receivers after untracked pixel edits.
	about: Normal image write locks and ReplacePixels are tracked automatically. Use this after changes that do not advance source revisions, including externally updated render-image emission maps.
	End Rem
	Method InvalidateMaps()
		ReleaseResources();revision :+ 1
	End Method
	Rem
	bbdoc: Releases owned packed material storage, retaining settings and borrowed source images.
	about: Shared materials are application-owned. Call after use or to discard packing; the next draw needing specular packing recreates it. Repeated calls are harmless.
	End Rem
	Method ReleaseResources()
		If packed Then
			packed.Release()
		End If

		packed = Null
	End Method

	Internal
	Method ResolvedNormalMap:TImage()
		If Not specularMap Or specularStrength = 0 Then
			Return normalMap
		End If

		If Not packed Then
			packed = TMax2DLightingMaterialMap.Create((specularMap.flags & FILTEREDIMAGE) <> 0)
		End If

		Return packed.Update(normalMap, specularMap, normalFrame, specularFrame)
	End Method

	Method ResolvedNormalFrame:Int()
		If specularMap And specularStrength > 0 Then
			Return 0
		End If

		Return normalFrame
	End Method

	Private
	Function ValidateFrame(image:TImage, frame:Int)
		If frame < 0 Then
			Throw "Max2D Lighting: negative material frame"
		End If

		If image Then
			image.CheckIndex(frame)
		Else If frame <> 0 Then
			Throw "Max2D Lighting: null material map requires frame zero"
		End If
	End Function

	Function ValidatePacking(normal:TImage, nf:Int, specular:TImage, sf:Int)
		TMax2DLightingMaterialMap.Validate(normal, nf, False)
		TMax2DLightingMaterialMap.Validate(specular, sf, True)
		If normal And specular Then
			If normal.width <> specular.width Or normal.height <> specular.height Then
				Throw "Max2D Lighting: material map dimensions must match"
			End If
		End If
	End Function

	Public
	Rem
	bbdoc: Returns the emission red component, 0..255.
	returns: The emission red component, 0..255.
	End Rem
	Method GetEmissionRed:Int()
		Return emissionRed
	End Method
	Rem
	bbdoc: Returns the emission green component, 0..255.
	returns: The emission green component, 0..255.
	End Rem
	Method GetEmissionGreen:Int()
		Return emissionGreen
	End Method
	Rem
	bbdoc: Returns the emission blue component, 0..255.
	returns: The emission blue component, 0..255.
	End Rem
	Method GetEmissionBlue:Int()
		Return emissionBlue
	End Method
	Rem
	bbdoc: Returns emission intensity; zero disables emission.
	returns: Emission intensity; zero disables emission.
	End Rem
	Method GetEmissionIntensity:Float()
		Return emissionIntensity
	End Method
	Rem
	bbdoc: Sets the 32-bit light receiver mask, default all bits.
	param: 32-bit light-selection mask; zero excludes direct lights and -1 enables all bits.
	about: Zero receives ambient only. This does not determine whether an object casts shadows.
	End Rem
	Method SetReceiverMask(value:Int)
		If receiverMask = value Then
			Return
		End If

		receiverMask = value; revision :+ 1
	End Method
	Rem
	bbdoc: Returns the light receiver mask.
	returns: The light receiver mask.
	End Rem
	Method GetReceiverMask:Int()
		Return receiverMask
	End Method
	Rem
	bbdoc: Enables or disables reception of light shadows; default True.
	param: True to receive occluder shadows, False to keep other material lighting without shadows.
	about: Disabling preserves projected patterns, normal/specular response and light selection. It does not affect occluder casting or ambient illumination.
	End Rem
	Method SetReceiveShadows(value:Int)
		value = value <> 0
		If receiveShadows = value Then
			Return
		End If

		receiveShadows = value;revision :+ 1
	End Method
	Rem
	bbdoc: Reports whether this material receives shadows.
	returns: True if this material receives shadows, False otherwise.
	End Rem
	Method GetReceiveShadows:Int()
		Return receiveShadows
	End Method
	Rem
	bbdoc: Bypasses ambient, point and directional illumination when True, preserving ordinary image appearance.
	param: True to bypass the lighting material and draw ordinary artwork.
	End Rem
	Method SetUnlit(value:Int)
		value = value <> 0
		If unlit = value Then
			Return
		End If

		unlit = value; revision :+ 1
	End Method
	Rem
	bbdoc: Reports whether illumination is bypassed.
	returns: True if illumination is bypassed, False otherwise.
	End Rem
	Method GetUnlit:Int()
		Return unlit
	End Method
	Rem
	bbdoc: References a normal map and frame, or clears it with Null.
	param: Shared material-map image, or Null to clear it; format and mapping requirements are described below.
	param: Zero-based frame index in the supplied image.
	about: RGB encodes a local surface normal from -1 to +1; positive X points right, positive Y down, positive Z toward the viewer. Use linear data without colour-space conversion; keep it opaque unless using alpha for gloss. The map covers the entire image, independently of its pixel dimensions or handle; atlas frames are supported; trimmed byte frames retain expanded sampling storage. Removed margins become transparent black; normal data discarded by trimming cannot be recovered. Alpha is ignored unless SetSpecularFromNormalAlpha is enabled. A separate SetSpecularMap takes precedence over normal alpha and requires matching, untrimmed CPU artwork. The image is shared, not owned. Null uses a viewer-facing surface when specular is enabled, otherwise restores flat illumination. Editing image pixels requires application invalidation of cached receivers.
	End Rem
	Method SetNormalMap(image:TImage, frame:Int = 0)
		If frame < 0 Then
			Throw "Max2D Lighting: negative normal frame"
		End If

		If image Then
			image.CheckIndex(frame)
		Else
			If frame <> 0 Then
				Throw "Max2D Lighting: null normal map requires frame zero"
			End If
		End If

		If specularMap Then
			ValidatePacking(image, frame, specularMap, specularFrame)
		End If

		If normalMap = image And normalFrame = frame Then
			Return
		End If

		normalMap = image; normalFrame = frame; revision :+ 1
	End Method
	Rem
	bbdoc: Returns the shared normal map, or Null for flat illumination.
	returns: The shared normal map, or Null for flat illumination.
	End Rem
	Method GetNormalMap:TImage()
		Return normalMap
	End Method
	Rem
	bbdoc: Returns the selected normal map frame.
	returns: The selected normal map frame.
	End Rem
	Method GetNormalFrame:Int()
		Return normalFrame
	End Method
	Rem
	bbdoc: Sets finite nonnegative normal strength; default one.
	param: Finite nonnegative multiplier for the normal map XY components; defaults to one.
	about: Scales the normal's XY components before transformation and normalization. Zero makes a conventional positive-Z normal map face the viewer, while retaining directional diffuse lighting. Clearing the map with specular disabled restores the original nondirectional flat lighting model.
	End Rem
	Method SetNormalStrength(value:Float)
		If IsNan(value) Or IsInf(value) Or value < 0 Then
			Throw "Max2D Lighting: invalid normal strength"
		End If

		If normalStrength = value Then
			Return
		End If

		normalStrength = value; revision :+ 1
	End Method
	Rem
	bbdoc: Returns normal strength.
	returns: Normal strength.
	End Rem
	Method GetNormalStrength:Float()
		Return normalStrength
	End Method
	Rem
	bbdoc: Sets specular highlight strength and shininess; material defaults are zero strength and shininess 32.
	param: Finite nonnegative specular highlight multiplier; zero disables specular light.
	param: Finite positive highlight exponent; larger values produce narrower highlights.
	about: Strength must be finite and nonnegative; shininess must be finite and positive. Larger shininess gives a narrower highlight. Highlights use the light colour, independently of the source artwork RGB, and preserve source coverage. The viewing direction is fixed toward the viewer (+Z). A nonzero strength enables directional surface lighting even without a normal map, using a viewer-facing normal. This is an artistic Blinn-Phong response, not an energy-conserving material model. Settings are shared. Direct draws use edits immediately; scene receivers invalidate on the next environment Prepare.
	End Rem
	Method SetSpecular(strength:Float, shininess:Float = 32)
		If IsNan(strength) Or IsInf(strength) Or strength < 0 Or IsNan(shininess) Or IsInf(shininess) Or shininess <= 0 Then
			Throw "Max2D Lighting: invalid specular settings"
		End If

		If specularStrength = strength And Self.shininess = shininess Then
			Return
		End If

		specularStrength = strength; Self.shininess = shininess; revision :+ 1
	End Method
	Rem
	bbdoc: Enables per-pixel specular strength from the normal map alpha channel; default False.
	param: True to enable specular-strength modulation by normal-map alpha, False to disable it.
	about: When enabled and a normal map is present, its alpha multiplies SetSpecular strength: zero is matte, one retains full strength. RGB still encodes the normal; alpha does not change diffuse light, ambient or receiver coverage. Use straight-alpha linear RGBA data and preserve RGB even where alpha is zero. Do not trim or premultiply this material data. The same map frame, UVs and filtering apply to both properties. Without a normal map this setting has no effect. A separate SetSpecularMap overrides this option while assigned. This option alone allocates no additional texture, capture or sampler. Scene receivers observe changes at the next environment Prepare.
	End Rem
	Method SetSpecularFromNormalAlpha(enabled:Int)
		enabled = enabled <> 0
		If specularFromNormalAlpha = enabled Then
			Return
		End If

		specularFromNormalAlpha = enabled;revision :+ 1
	End Method
	Rem
	bbdoc: Reports whether normal-map alpha modulates specular strength.
	returns: True if normal-map alpha modulates specular strength, False otherwise.
	End Rem
	Method GetSpecularFromNormalAlpha:Int()
		Return specularFromNormalAlpha
	End Method
	Rem
	bbdoc: Returns the specular highlight strength; zero disables highlights.
	returns: The specular highlight strength; zero disables highlights.
	End Rem
	Method GetSpecularStrength:Float()
		Return specularStrength
	End Method
	Rem
	bbdoc: Returns the specular highlight exponent.
	returns: The specular highlight exponent.
	End Rem
	Method GetShininess:Float()
		Return shininess
	End Method
	Rem
	bbdoc: Returns the material configuration and tracked map-pixel revision for retained consumers.
	returns: The material configuration and tracked map-pixel revision for retained consumers.
	End Rem
	Method Revision:Long()
		Local ev:Long = -1, sv:Long = -1, nv:Long = -1
		If emissionMap Then
			ev = emissionMap.sources[emissionFrame].version
		End If

		If specularMap Then
			sv = specularMap.sources[specularFrame].version
			If normalMap Then
				nv = normalMap.sources[normalFrame].version
			End If
		End If

		If ev <> emissionVersion Or sv <> specularVersion Or nv <> normalVersion Then
			emissionVersion = ev;specularVersion = sv;normalVersion = nv;revision :+ 1
		End If

		Return revision
	End Method
End Type
