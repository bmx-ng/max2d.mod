SuperStrict
Rem
bbdoc: Optional ambient, point and directional illumination for Max2D images.
End Rem
Module Max2D.Lighting
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.ShaderEffects
Import Max2D.LightingDriver
Import Max2D.LightingNative
Import "../sdl3gpueffects.mod/packages/emissionlight/emissionlight_assets.c"
Import "../sdl3gpueffects.mod/packages/texturedlight/texturedlight_assets.c"
Import "../sdl3gpueffects.mod/packages/lightpair/lightpair_assets.c"
Import "../sdl3gpueffects.mod/packages/pointlight/pointlight_assets.c"
Import "../sdl3gpueffects.mod/packages/normallight/normallight_assets.c"
Include "../sdl3gpueffects.mod/packages/emissionlight/emissionlight.bmx"
Include "../sdl3gpueffects.mod/packages/pointlight/pointlight.bmx"
Include "../sdl3gpueffects.mod/packages/normallight/normallight.bmx"
Include "../sdl3gpueffects.mod/packages/lightpair/lightpair.bmx"
Include "material.bmx"
Include "materialmap.bmx"
Include "meshcache.bmx"
Include "texture.bmx"
Include "diagnostics.bmx"
Include "selection.bmx"
Include "occluder.bmx"
Include "casterstate.bmx"
Include "../sdl3gpueffects.mod/packages/texturedlight/texturedlight.bmx"

Private
Global lightPairPackage:TMax2DShaderPackage = CreateLightPairPackage()
Global pointLightPackage:TMax2DShaderPackage = CreatePointLightPackage()
Global texturedLightPackage:TMax2DShaderPackage = CreateTexturedLightPackage()
Global normalLightPackage:TMax2DShaderPackage = CreateNormalLightPackage()
Global emissionLightPackage:TMax2DShaderPackage = CreateEmissionLightPackage()
Public
Include "pairedrenderer.bmx"

Rem
bbdoc: Reusable ambient and coloured point/directional illumination for individual images and captured artwork.
about: Combines ambient illumination with point and directional diffuse and optional specular contributions, preserving source alpha.
Point attenuation is (max(0,1-distance/radius))^falloff. Optional receiver materials add normal-mapped diffuse and specular response
to DrawImage. Captured Update remains flat illumination. Optional point and directional shadows use retained simple polygon occluders.
No implicit colour-space conversion is performed. Use linear artwork for linear lighting; RGBA8888 output saturates, while floating-point
output retains values above one. Import a shader effects provider for the selected renderer. Configuration is retained across Release; 
borrowed results expire on update, changed preparation, release or context closure.
End Rem
Type TMax2DLighting
	Private
	Field meshTriangle:TMesh2D
	Field meshReceiver:TMesh2D
	Field meshDeformed:Int, meshAccepted:Int, meshCombined:Int
	Field meshGeometry:Float[6]
	Field meshGroups:Int[]
	Field meshCache:TMax2DLightingMeshCache
	Field drawingMesh:Int
	Field meshX:Float, meshY:Float
	Field meshBasis:Float[6]
	Field buffers:TMax2DEffectBuffers
	Field effect:TMax2DShaderEffect = CreateShaderEffect(pointLightPackage)
	Field normalEffect:TMax2DShaderEffect = CreateShaderEffect(normalLightPackage)
	Field emissionEffect:TMax2DShaderEffect = CreateShaderEffect(emissionLightPackage)
	Field lights:Float[]
	Field activeLights:Int[]
	Field selection:TMax2DLightSelection = New TMax2DLightSelection
	Field spatialSelection:Int
	Field batchLimit:Int = 16
	Field batching:Int
	Field rendererContext:TMax2DContext
	Field renderer:TMax2DLightingRenderer
	Field pairedRenderer:TMax2DPairedLightingRenderer
	Field groupDraw:TMax2DLightingDraw = New TMax2DLightingDraw
	Field groupMaterial:TMax2DLightingMaterial
	Field heights:Float[]
	Field masks:Int[]
	Field texturedEffect:TMax2DShaderEffect = CreateShaderEffect(texturedLightPackage)
	Field textures:TMax2DLightTexture[]
	Field textureRevisions:Long[]
	Field shadows:TMax2DLightShadow[]
	Field stats:TMax2DLightingStats = New TMax2DLightingStats
	Field occluders:TMax2DLightOccluder[]
	Field casterStates:TMax2DCasterState[]
	Field changedCaster:TMax2DCasterState = New TMax2DCasterState
	Field directional:Int[]
	Field revision:Long
	Field ambientRed:Int = 255, ambientGreen:Int = 255, ambientBlue:Int = 255
	Field ambientIntensity:Float = 1
	Field width:Int, height:Int, format:Int
	Field additive:Int = CreateBlendMode(BLEND_SRC_ALPHA, BLEND_ONE, BLEND_OP_ADD, BLEND_ZERO, BLEND_ONE)
	Public
	Rem
	bbdoc: Allocates a retained description with the specified number of initially disabled light slots.
	param: Nonnegative number of retained light slots; new slots are disabled.
	returns: A new #TMax2DLighting instance configured with the supplied settings.
	End Rem
	Function Create:TMax2DLighting(lightCount:Int = 0)
		Local result:TMax2DLighting = New TMax2DLighting
		result.SetLightCount(lightCount)
		Return result
	End Function
	Rem
	bbdoc: Resizes the light list, retaining existing slots and disabling new ones.
	param: Nonnegative number of retained light slots.
	about: Allocates CPU storage only when the count changes. Zero removes all lights. Use intensity zero to temporarily disable a slot without resizing.
	End Rem
	Method SetLightCount(count:Int)
		If count < 0 Or count > 2147483647 / 32 Then
			Throw "Max2D Lighting: invalid light count"
		End If

		If count = GetLightCount() Then
			Return
		End If

		selection.dirty = True
		Local previous:Int = GetLightCount()
		For Local i:Int = count Until previous
			If shadows[i] Then
				shadows[i].Release()
			End If
		Next

		shadows = shadows[..count]
		activeLights = activeLights[..count]
		lights = lights[..count * 8]
		masks = masks[..count]
		heights = heights[..count]
		directional = directional[..count]
		textures = textures[..count]
		textureRevisions = textureRevisions[..count]
		For Local i:Int = previous Until count
			masks[i] = -1
			heights[i] = 128
		Next

		revision :+ 1
	End Method
	Rem
	bbdoc: Enables retained spatial selection for per-image receivers; disabled by default.
	param: True to enable spatial selection of receiver lights, False to disable it.
	about: With at least 32 slots, a balanced bounds hierarchy skips distant point lights before individual tests.
	Directional lights remain global. Selected slots retain their original draw order. Geometry, kind and count changes rebuild lazily
	on the next DrawImage; colour, intensity and mask edits reuse the hierarchy. Storage is retained, with no warm-query allocation.
	Small lists and flattened Update use the linear path. Measure moving-light workloads: rebuilding and sorting can outweigh savings.
	This switch changes selection work, not output or scene cache revisions.
	End Rem
	Method SetSpatialSelection(enabled:Int)
		spatialSelection = enabled <> 0
	End Method

	Rem
	bbdoc: Returns whether spatial receiver selection is enabled.
	returns: Whether spatial receiver selection is enabled.
	End Rem
	Method GetSpatialSelection:Int()
		Return spatialSelection
	End Method

	Rem
	bbdoc: Returns the number of retained light slots.
	returns: The number of retained light slots.
	End Rem
	Method GetLightCount:Int()
		Return lights.Length / 8
	End Method

	Rem
	bbdoc: Sets ambient colour components (0..255) and finite nonnegative intensity.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	about: Defaults to white at intensity one. Zero removes the ambient contribution.
	End Rem
	Method SetAmbient(red:Int, green:Int, blue:Int, intensity:Float = 1)
		CheckLightingColour(red, green, blue, intensity)
		If ambientRed = red And ambientGreen = green And ambientBlue = blue And ambientIntensity = intensity Then
			Return
		End If

		revision :+ 1
		ambientRed = red
		ambientGreen = green
		ambientBlue = blue
		ambientIntensity = intensity
	End Method

	Rem
	bbdoc: Sets a retained point light in the lighting coordinate system, without allocating resources.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Finite horizontal coordinate in lighting-space units.
	param: Finite vertical coordinate in lighting-space units.
	param: Finite positive light radius in lighting/world units.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	param: Finite positive attenuation exponent; one is linear and two is quadratic.
	about: Index must exist. Replaces the slot with a point light while preserving its receiver mask. Position must be finite,
	radius and falloff finite and positive, colour components 0..255 and intensity finite and nonnegative. Falloff one is linear,
	two is quadratic; larger values concentrate light near its centre. Intensity zero disables the slot. Coordinates default to
	source pixels for Update; DrawImage accepts an explicit affine mapping. Changes take effect on the next DrawImage or Update.
	End Rem
	Method SetPointLight(index:Int, x:Float, y:Float, radius:Float, red:Int = 255, green:Int = 255, blue:Int = 255, intensity:Float = 1, falloff:Float = 2)
		If index < 0 Or index >= GetLightCount() Then
			Throw "Max2D Lighting: light index out of range"
		End If

		CheckLightingColour(red, green, blue, intensity)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(radius) Or IsInf(radius) Or radius <= 0 Or IsNan(falloff) Or IsInf(falloff) Or falloff <= 0 Then
			Throw "Max2D Lighting: invalid point light geometry"
		End If

		Local i:Int = index * 8
		If directional[index] = 0 And lights[i] = x And lights[i + 1] = y And lights[i + 2] = radius And lights[i + 3] = red / 255.0:Float And lights[i + 4] = green / 255.0:Float And lights[i + 5] = blue / 255.0:Float And lights[i + 6] = intensity And lights[i + 7] = falloff Then
			Return
		End If

		If directional[index] Or lights[i] <> x Or lights[i + 1] <> y Or lights[i + 2] <> radius Then
			InvalidateShadow(index)
			selection.dirty = True
		End If

		revision :+ 1
		directional[index] = 0
		lights[i] = x
		lights[i + 1] = y
		lights[i + 2] = radius
		lights[i + 3] = red / 255.0
		lights[i + 4] = green / 255.0
		lights[i + 5] = blue / 255.0
		lights[i + 6] = intensity
		lights[i + 7] = falloff
	End Method
	Rem
	bbdoc: Sets a directional light with constant direction and no distance attenuation.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Horizontal component of the finite, nonzero vector toward the light.
	param: Vertical component of the finite, nonzero vector toward the light.
	param: Depth component of the finite, nonzero vector toward the light.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	about: Index must exist. The finite nonzero vector points from the surface toward the light; positive X is right, positive Y down
	and positive Z toward the viewer. It is normalized internally. Colour components are 0..255 and intensity is finite and nonnegative.
	Replaces the slot's light kind while preserving its receiver mask and shadow settings. Remove any point-light texture before switching
	to directional, and configure shadow bounds before drawing a shadow-enabled directional slot. All selected receivers are illuminated
	regardless of position. Normal/specular materials use the direction; flat artwork receives uniform colour multiplication. No resource allocation occurs.
	End Rem
	Method SetDirectionalLight(index:Int, x:Float, y:Float, z:Float, red:Int = 255, green:Int = 255, blue:Int = 255, intensity:Float = 1)
		If index < 0 Or index >= GetLightCount() Then
			Throw "Max2D Lighting: light index out of range"
		End If

		If textures[index] Then
			Throw "Max2D Lighting: remove point texture before switching to directional"
		End If

		CheckLightingColour(red, green, blue, intensity)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(z) Or IsInf(z) Or (x = 0 And y = 0 And z = 0) Then
			Throw "Max2D Lighting: invalid light direction"
		End If

		Local length:Double = Sqr(Double(x) * x + Double(y) * y + Double(z) * z)
		x = Float(x / length)
		y = Float(y / length)
		z = Float(z / length)
		Local i:Int = index * 8
		If directional[index] And lights[i] = x And lights[i + 1] = y And lights[i + 2] = z And lights[i + 3] = red / 255.0:Float And lights[i + 4] = green / 255.0:Float And lights[i + 5] = blue / 255.0:Float And lights[i + 6] = intensity Then
			Return
		End If

		If Not directional[index] Or lights[i] <> x Or lights[i + 1] <> y Or lights[i + 2] <> z Then
			InvalidateShadow(index)
		End If

		If Not directional[index] Then
			selection.dirty = True
		End If

		directional[index] = True
		lights[i] = x
		lights[i + 1] = y
		lights[i + 2] = z
		lights[i + 3] = red / 255.0
		lights[i + 4] = green / 255.0
		lights[i + 5] = blue / 255.0
		lights[i + 6] = intensity
		lights[i + 7] = 0
		revision :+ 1
	End Method
	Rem
	bbdoc: Assigns a shared projected pattern to a point-light slot; Null restores analytic illumination.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Shared projected light pattern; Null clears the pattern.
	about: Requires an existing point slot. The pattern's RGB and alpha multiply radial falloff and material shading. Placement and image
	ownership remain with the shared description. Directional slots reject textures. Direct drawing reads current settings; cached scene
	receivers synchronize during Prepare.
	End Rem
	Method SetLightTexture(index:Int, texture:TMax2DLightTexture)
		If index < 0 Or index >= GetLightCount() Then
			Throw "Max2D Lighting: light index out of range"
		End If

		If texture And directional[index] Then
			Throw "Max2D Lighting: textures require a point light"
		End If

		If texture And Not texture.image Then
			Throw "Max2D Lighting: uninitialized light texture"
		End If

		Local current:Long
		If texture Then
			current = texture.Revision()
		End If

		If textures[index] = texture And textureRevisions[index] = current Then
			Return
		End If

		textures[index] = texture
		textureRevisions[index] = current
		revision :+ 1
		InvalidateShadow(index)
	End Method
	Rem
	bbdoc: Sets finite nonnegative point-light height above the receiving plane in lighting coordinate units.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Finite nonnegative light height above the receiver plane in lighting units.
	about: Defaults to 128. Height controls diffuse and specular direction; radius attenuation remains in the XY plane. Height also
	controls shadow projection for finite-height occluders.
	End Rem
	Method SetLightHeight(index:Int, height:Float)
		If index < 0 Or index >= GetLightCount() Then
			Throw "Max2D Lighting: light index out of range"
		End If

		If directional[index] Then
			Throw "Max2D Lighting: height requires a point light"
		End If

		If IsNan(height) Or IsInf(height) Or height < 0 Then
			Throw "Max2D Lighting: invalid light height"
		End If

		If heights[index] = height Then
			Return
		End If

		heights[index] = height
		revision :+ 1
		InvalidateShadow(index)
	End Method
	Rem
	bbdoc: Copies the shared polygon occluders used by light shadows.
	param: Borrowed lighting-space occluders; the array is copied and Null clears it.
	about: Null clears the list. Null entries are rejected. Geometry edits are observed at the next Revision, DrawImage or Update. No drawing occurs until a shadow-enabled light is used.
	End Rem
	Method SetOccluders(values:TMax2DLightOccluder[])
		For Local value:TMax2DLightOccluder = EachIn values
			If Not value Or value.vertices.Length < 6 Then
				Throw "Max2D Lighting: invalid occluder"
			End If
		Next

		Local states:TMax2DCasterState[] = New TMax2DCasterState[values.Length]
		For Local i:Int = 0 Until values.Length
			states[i] = New TMax2DCasterState
			states[i].Capture(values[i])
		Next

		occluders = values[..]
		casterStates = states
		revision :+ 1
		InvalidateShadows()
	End Method
	Rem
	bbdoc: Enables light shadows with a retained square mask, or disables and releases its storage.
	param: Zero-based light slot; it must be less than the configured light count.
	param: True to enable shadow generation for this light slot, False to disable it.
	param: Shadow-image resolution from 16 to 4096 pixels.
	param: 32-bit caster selection mask; only overlapping caster bits block this light.
	about: Disabled by default. Resolution must be 16..4096. Caster mask selects occluders independently of receiver selection. Hard shadows allocate
	one RGBA8888 image lazily per enabled light; filtering adds two retained images. Storage is reused when geometry moves
	and released by Release. Shadows multiply direct diffuse/specular light and projected patterns, leaving ambient and
	receiver alpha unchanged. Directional lights additionally require SetDirectionalShadowBounds before drawing. Edges are
	hard by default; SetLightShadowSoftness enables filtering. Shadow inputs invalidate only this light; registered caster edits
	invalidate masks whose caster selection and old or new influence can overlap. Directional shadows remain conservative for matching
	casters, and replacing the caster list invalidates all masks. Ambient, colour, intensity, falloff and receiver-mask edits preserve prepared shadows.
	End Rem
	Method SetLightShadows(index:Int, enabled:Int = True, resolution:Int = 512, casterMask:Int = -1)
		If index < 0 Or index >= GetLightCount() Then
			Throw "Max2D Lighting: light index out of range"
		End If

		If resolution < 16 Or resolution > 4096 Then
			Throw "Max2D Lighting: invalid shadow resolution"
		End If

		Local shadow:TMax2DLightShadow = shadows[index]
		If Not enabled Then
			If Not shadow Then
				Return
			End If

			shadow.Release()
			shadows[index] = Null
			revision :+ 1
			Return
		End If

		If shadow Then
			If shadow.resolution = resolution And shadow.mask = casterMask Then
				Return
			End If

			If shadow.resolution <> resolution Then
				shadow.Release()
			End If
		Else
			shadow = New TMax2DLightShadow
			shadows[index] = shadow
		End If

		shadow.resolution = resolution
		shadow.mask = casterMask
		revision :+ 1
		InvalidateShadow(index)
	End Method
	Rem
	bbdoc: Sets the finite rectangle covered by a directional light's shadow image, in lighting coordinates.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Finite horizontal coordinate in lighting-space units.
	param: Finite vertical coordinate in lighting-space units.
	param: Width in lighting/world units; finite and positive.
	param: Height in lighting/world units; finite and positive.
	about: Requires a directional slot with shadows enabled. Width and height must be positive, and rectangle coordinates
	representable as Float. Configure before drawing. Outside this rectangle illumination is unshadowed; its outermost mask
	texels are an unshadowed guard border. Occluders outside the rectangle can still cast into it. Changing bounds reuses
	image storage at the selected resolution. Bounds do not follow the direction or a camera automatically.
	End Rem
	Method SetDirectionalShadowBounds(index:Int, x:Float, y:Float, width:Float, height:Float)
		If index < 0 Or index >= GetLightCount() Then
			Throw "Max2D Lighting: light index out of range"
		End If

		If Not directional[index] Or Not shadows[index] Then
			Throw "Max2D Lighting: enable directional shadows before setting bounds"
		End If

		CheckDirectionalShadowBounds(x, y, width, height)
		Local shadow:TMax2DLightShadow = shadows[index]
		If shadow.boundsX = x And shadow.boundsY = y And shadow.boundsWidth = width And shadow.boundsHeight = height Then
			Return
		End If

		shadow.boundsX = x
		shadow.boundsY = y
		shadow.boundsWidth = width
		shadow.boundsHeight = height
		revision :+ 1
		InvalidateShadow(index)
	End Method
	Rem
	bbdoc: Sets shadow filter radius in shadow-image pixels, from zero to 4.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Shadow filter radius from zero to four shadow-image pixels.
	about: Requires shadows enabled on this light slot. Zero preserves the hard mask.
	Positive values filter visibility before combining the projected pattern, preserving pattern detail and
	receiver alpha. This is a constant-width artistic filter, not a distance-dependent penumbra. First use
	allocates retained blur storage; returning to zero keeps it for reuse until Release or shadow reconfiguration.
	End Rem
	Method SetLightShadowSoftness(index:Int, radius:Float)
		If index < 0 Or index >= GetLightCount() Then
			Throw "Max2D Lighting: light index out of range"
		End If

		If IsNan(radius) Or IsInf(radius) Or radius < 0 Or radius > 4 Then
			Throw "Max2D Lighting: shadow softness must be 0..4"
		End If

		If Not shadows[index] Then
			Throw "Max2D Lighting: enable shadows before setting softness"
		End If

		If shadows[index].softness = radius Then
			Return
		End If

		shadows[index].softness = radius
		revision :+ 1
		InvalidateShadow(index)
	End Method
	Rem
	bbdoc: Returns the lighting configuration revision; unchanged settings do not increment it.
	returns: The lighting configuration revision; unchanged settings do not increment it.
	End Rem
	Method Revision:Long()
		For Local i:Int = 0 Until occluders.Length
			Local previous:TMax2DCasterState = casterStates[i]
			If previous.revision = occluders[i].Revision() Then
				Continue
			End If

			changedCaster.Capture(occluders[i])
			For Local light:Int = 0 Until shadows.Length
				Local shadow:TMax2DLightShadow = shadows[light]
				If Not shadow Or Not shadow.valid Then
					Continue
				End If

				Local offset:Int = light * 8
				If previous.Affects(shadow, directional[light], lights[offset], lights[offset + 1], lights[offset + 2]) Or changedCaster.Affects(shadow, directional[light], lights[offset], lights[offset + 1], lights[offset + 2]) Then
					shadow.valid = False
				End If
			Next

			casterStates[i] = changedCaster
			changedCaster = previous
			revision :+ 1
		Next

		Return revision
	End Method
	Rem
	bbdoc: Sets a light's 32-bit receiver mask; a contribution requires at least one matching bit.
	param: Zero-based light slot; it must be less than the configured light count.
	param: 32-bit light receiver mask; -1 enables all bits.
	about: Defaults to all bits. Ambient illumination is independent of these masks. Shadow-caster selection is a
	separate concern, not represented by this mask.
	End Rem
	Method SetLightMask(index:Int, mask:Int)
		If index < 0 Or index >= GetLightCount() Then
			Throw "Max2D Lighting: light index out of range"
		End If

		If masks[index] = mask Then
			Return
		End If

		masks[index] = mask
		revision :+ 1
	End Method
	Rem
	bbdoc: Enables optional grouped direct-light drawing; default False.
	param: True to enable grouped direct-light drawing, False to disable it.
	about: Dedicated renderer providers choose group limits and supported materials. The built-in native
	renderer groups up to sixteen point/directional lights where supported, with an eight-light fallback,
	including normal maps, specular shading, projected byte colour/alpha patterns and hard/filtered shadow
	maps up to 512 by 512 pixels. SetLightBatchLimit controls the requested maximum; groups of eight or fewer
	use the smaller native shader. Direct mipmapped, compressed and floating-point patterns use ordinary drawing.
	The first eligible native group also composes ambient and receiver coverage, saving a separate draw. Ambient
	remains separate when the first group cannot support it. Groups using maps allocate a retained 16 MiB atlas on
	first use; MapUploads, MapCacheHits and RetainedMapBytes expose its work and storage. Unsupported groups retain
	the ordered compatibility path. The compatibility renderer can combine adjacent selected point lights with intensity
	at most one, no projected patterns, and byte-format source artwork without normal/specular shading. Hard or filtered shadows
	are supported. Remaining unsupported lights/materials, and Update, retain the ordinary path. Pairing preserves alpha but
	normalized-target rounding may differ slightly. Storage is retained; no per-frame selection arrays are created. Changes invalidate
	scene output without rebuilding shadow masks.
	End Rem
	Method SetLightBatching(enabled:Int)
		enabled = enabled <> 0
		If batching = enabled Then
			Return
		End If

		batching = enabled
		revision :+ 1
	End Method
	Rem
	bbdoc: Returns whether optional grouped direct-light drawing is enabled.
	returns: Whether optional grouped direct-light drawing is enabled.
	End Rem
	Method GetLightBatching:Int()
		Return batching
	End Method
	Rem
	bbdoc: Sets the maximum direct lights per group; default 16.
	param: Positive maximum direct lights per submitted group; the provider may use a smaller capacity.
	about: Must be positive. The active renderer may use a smaller capacity. Set 8 to prefer the smaller native
	shader when profiling. Does not enable batching. Changes release renderer-owned atlas storage and invalidate scene output,
	retaining source shadow masks.
	End Rem
	Method SetLightBatchLimit(maximum:Int)
		If maximum < 1 Then
			Throw "Max2D Lighting: batch limit must be positive"
		End If

		If maximum = batchLimit Then
			Return
		End If

		ReleaseRenderer()
		batchLimit = maximum
		revision :+ 1
	End Method
	Rem
	bbdoc: Returns the requested maximum lights per group; actual capacity depends on the renderer.
	returns: The requested maximum lights per group; actual capacity depends on the renderer.
	End Rem
	Method GetLightBatchLimit:Int()
		Return batchLimit
	End Method
	Rem
	bbdoc: Clears cumulative lighting work counters without invalidating caches or releasing textures.
	End Rem
	Method ResetStats()
		stats.Reset()
	End Method
	Rem
	bbdoc: Copies cumulative work counters and current shadow storage into a reusable snapshot.
	param: Required reusable destination lighting-statistics snapshot.
	about: Does not allocate snapshot objects. Null output is rejected. Storage is an RGBA8888 size estimate, not measured driver memory.
	End Rem
	Method CopyStats(output:TMax2DLightingStats)
		If Not output Then
			Throw "Max2D Lighting: statistics output is null"
		End If

		stats.mapBytes = 0
		If renderer Then
			stats.mapBytes = renderer.MapStorageBytes()
		End If

		stats.shadowBytes = 0
		For Local shadow:TMax2DLightShadow = EachIn shadows
			If shadow And shadow.buffers Then
				Local images:Int = 1
				If shadow.filtered Then
					images = 3
				End If

				stats.shadowBytes :+ Long(shadow.resolution) * shadow.resolution * 4 * images
			End If
		Next

		stats.CopyTo(output)
	End Method
	Rem
	bbdoc: Allocates a detached snapshot of cumulative counters and current shadow texture storage.
	returns: A new independent statistics snapshot.
	about: Reuse a TMax2DLightingStats instance with CopyStats in frame loops to avoid snapshot allocations.
	End Rem
	Method CaptureStats:TMax2DLightingStats()
		Local result:TMax2DLightingStats = New TMax2DLightingStats
		CopyStats(result)
		Return result
	End Method
	Rem
	bbdoc: Draws one image with lighting before it is composited over earlier objects.
	param: Borrowed source artwork; must not be the active render target.
	param: Finite horizontal coordinate in local drawing units before the supplied light-space transform.
	param: Finite vertical coordinate in local drawing units before the supplied light-space transform.
	param: Zero-based frame index in the supplied image.
	param: 32-bit receiver selection mask, intersected with the material mask.
	param: Coefficient of X in the transformed X coordinate.
	param: Coefficient of Y in the transformed X coordinate.
	param: Coefficient of X in the transformed Y coordinate.
	param: Coefficient of Y in the transformed Y coordinate.
	param: Horizontal affine translation.
	param: Vertical affine translation.
	param: Optional shared material; Null uses default lighting settings.
	about: Requires no Prepare or per-receiver output buffer. Enabled shadows allocate retained light masks lazily. Uses ordinary alpha
	composition followed by additive light contributions, preserving painter order and object transparency. Drawing tint, alpha
	and clip are respected; blend state is restored. The affine coefficients map local draw coordinates into the light coordinate
	system, independently of the drawing camera. Defaults use the supplied image position directly. A nonzero intersection between
	receiverMask and each light mask selects contributions; zero receives ambient only. Use an ordinary DrawImage for unlit artwork.
	Warm draws allocate no textures or descriptions. The ordinary path uses one ambient pass plus each intersecting selected light.
	SetLightBatching can combine eligible lights; pass counts are not part of the API contract. An optional material intersects its
	receiver mask with receiverMask and supplies a normal map, source-coloured emission or unlit bypass. Emission is independent of light
	selection and shadows. Uniform emission adds to ambient without another pass; emission-map materials can join the first native group
	alongside shadow/pattern textures when the four-texture material shader is supported, otherwise retain a separate ambient pass where
	necessary. Separate specular maps are offered directly to providers advertising MappedSpecular. Eligible native groups sample the
	original maps independently with five textures. Rejected combinations use retained material packing, resolved after light selection
	only when direct lights contribute. Unchanged packing storage is reused across grouped and compatibility drawing. Specular highlights
	use light colour and a fixed viewer-facing view direction. Normal maps use the inverse transpose of the affine linear transform
	(Z scale one); near-singular transforms fall back to a viewer-facing normal. Ambient is independent of normals. Trimmed byte source
	frames use retained full-size sampling storage, refreshed after source pixel edits.
	End Rem
	Method DrawImage(source:TImage, x:Float, y:Float, frame:Int = 0, receiverMask:Int = -1, xx:Float = 1, xy:Float = 0, yx:Float = 0, yy:Float = 1, tx:Float = 0, ty:Float = 0, material:TMax2DLightingMaterial = Null)
		If Not source Then
			Throw "Max2D Lighting: image is null"
		End If

		If material Then
			If material.GetUnlit() Then
				Max2D.Core.DrawImage(source, x, y, frame)
				Return
			End If

			receiverMask = receiverMask & material.GetReceiverMask()
		End If

		Local normalMap:TImage, normalFrame:Int, specularAlpha:Int, mappedEmission:Int
		If material Then
			mappedEmission = material.GetEmissionMap() <> Null And material.GetEmissionIntensity() > 0
		End If

		Local ambientEffect:TMax2DShaderEffect = effect
		If mappedEmission Then
			ambientEffect = emissionEffect
		End If

		Local receiveShadows:Int = True
		If material Then
			receiveShadows = material.GetReceiveShadows()
		End If

		source = source.SamplingImage(frame)
		stats.receiverDraws :+ 1
		RefreshSources()
		Local pointEffect:TMax2DShaderEffect = effect
		' Encode the receiver's geometry separately from its current camera transform.
		Local bx:Float = xx * (x - source.handle_x) + xy * (y - source.handle_y) + tx
		Local by:Float = yx * (x - source.handle_x) + yy * (y - source.handle_y) + ty
		effect.SetFloat4("basisX", xx * source.width, xy * source.height, bx, 0)
		effect.SetFloat4("basisY", yx * source.width, yy * source.height, by, 0)
		effect.SetFloat4("light", 0, 0, 1, 1)
		effect.SetFloat4("shape", 1, 0, 0, 0)
		Local baseRed:Float = ambientRed / 255.0 * ambientIntensity
		Local baseGreen:Float = ambientGreen / 255.0 * ambientIntensity
		Local baseBlue:Float = ambientBlue / 255.0 * ambientIntensity
		If material And material.GetEmissionIntensity() > 0 And Not mappedEmission Then
			baseRed :+ material.GetEmissionRed() / 255.0 * material.GetEmissionIntensity()
			baseGreen :+ material.GetEmissionGreen() / 255.0 * material.GetEmissionIntensity()
			baseBlue :+ material.GetEmissionBlue() / 255.0 * material.GetEmissionIntensity()
			If IsInf(baseRed) Or IsInf(baseGreen) Or IsInf(baseBlue) Then
				Throw "Max2D Lighting: ambient plus emission overflow"
			End If

			effect.SetFloat4("colour", baseRed, baseGreen, baseBlue, 1)
		Else
			effect.SetFloat4("colour", ambientRed / 255.0, ambientGreen / 255.0, ambientBlue / 255.0, ambientIntensity)
		End If

		If mappedEmission Then
			emissionEffect.SetTexture(material.GetEmissionMap(), material.GetEmissionFrame())
			emissionEffect.SetFloat4("ambient", baseRed, baseGreen, baseBlue, 1)
			emissionEffect.SetFloat4("emission", material.GetEmissionRed() / 255.0, material.GetEmissionGreen() / 255.0, material.GetEmissionBlue() / 255.0, material.GetEmissionIntensity())
		End If

		Local oldBlend:Int = GetBlend()
		Try
			SetBlend(ALPHABLEND)
			If Not Max2DSupportsImageEffect(ambientEffect) Then
				Throw "Max2D Lighting: image lighting unsupported"
			End If

			SetBlend(additive)
			Local minX:Float = bx + Min(0.0:Float, xx * source.width) + Min(0.0:Float, xy * source.height)
			Local maxX:Float = bx + Max(0.0:Float, xx * source.width) + Max(0.0:Float, xy * source.height)
			Local minY:Float = by + Min(0.0:Float, yx * source.width) + Min(0.0:Float, yy * source.height)
			Local maxY:Float = by + Max(0.0:Float, yx * source.width) + Max(0.0:Float, yy * source.height)
			If meshDeformed Then
				Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
				For Local vertex:Int = 0 Until meshReceiver.indices.Length
					Local k:Int = meshReceiver.indices[vertex] * 2
					Local gx:Double = meshReceiver.xy[k] + Double(meshX) - canvas.state.handleX, gy:Double = meshReceiver.xy[k + 1] + Double(meshY) - canvas.state.handleY
					Local lx:Float = meshGeometry[0] * gx + meshGeometry[1] * gy + meshGeometry[4], ly:Float = meshGeometry[2] * gx + meshGeometry[3] * gy + meshGeometry[5]
					If vertex = 0 Then minX = lx;maxX = lx;minY = ly;maxY = ly

					minX = Min(minX, lx)
					maxX = Max(maxX, lx)
					minY = Min(minY, ly)
					maxY = Max(maxY, ly)
				Next
			End If

			Local activeCount:Int, candidates:Int = GetLightCount()
			Local indexed:Int = spatialSelection And candidates >= 32
			If indexed Then
				If selection.dirty Then
					selection.Build(lights, directional)
					stats.selectionRebuilds :+ 1
				End If

				candidates = 0
				selection.Query(1, minX, minY, maxX, maxY, activeLights, candidates, stats)
				stats.spatialRejects :+ GetLightCount() - candidates
				If candidates > 1 Then
					selection.Sort(activeLights, 0, candidates - 1, Null, Null)
				End If
			End If

			For Local candidate:Int = 0 Until candidates
				Local i:Int = candidate * 8
				If indexed Then
					i = activeLights[candidate]
				End If

				stats.lightTests :+ 1
				If lights[i + 6] = 0 Or (masks[i / 8] & receiverMask) = 0 Then stats.excludedLights :+ 1;Continue

				Local radius:Float = lights[i + 2]
				If Not directional[i / 8] Then
					If Double(lights[i]) + radius <= minX Or Double(lights[i]) - radius >= maxX Or Double(lights[i + 1]) + radius <= minY Or Double(lights[i + 1]) - radius >= maxY Then stats.boundsRejects :+ 1;Continue
				End If

				activeLights[activeCount] = i
				activeCount :+ 1
			Next
			' Resolve direct-light material data only after receiver/light selection.
			' Ambient and emission do not sample normal or specular artwork.
			If activeCount Then
				If batching Then
					PrepareRenderer()
				End If

				Local independentSpecular:Int = renderer And batching And renderer.Capabilities().MappedSpecular()
				If material Then
					normalMap = material.GetNormalMap()
					normalFrame = material.GetNormalFrame()
					specularAlpha = material.GetSpecularFromNormalAlpha() And Not material.GetSpecularMap()
					If Not independentSpecular And material.GetSpecularMap() And material.GetSpecularStrength() > 0 Then
						normalMap = material.ResolvedNormalMap()
						normalFrame = material.ResolvedNormalFrame()
						specularAlpha = True
					End If

					If normalMap Or material.GetSpecularStrength() > 0 Then
						pointEffect = normalEffect
					End If
				End If

				If pointEffect = normalEffect Then
					If normalMap Then
						normalEffect.SetTexture(normalMap, normalFrame)
					Else
						normalEffect.SetTexture(source, frame)
					End If

					normalEffect.SetFloat4("basisX", xx * source.width, xy * source.height, bx, 1.0 / source.width)
					normalEffect.SetFloat4("basisY", yx * source.width, yy * source.height, by, 1.0 / source.height)
				End If

				If Not Max2DSupportsImageEffect(pointEffect) Then
					Throw "Max2D Lighting: additive image lighting unsupported"
				End If

				If batching Then
					PrepareDraw(source, x, y, frame, xx, xy, yx, yy, bx, by, material, normalMap, normalFrame, specularAlpha)
				End If
			End If

			If meshDeformed Then
				If meshGroups.Length < activeCount Then
					meshGroups = New Int[activeCount]
				End If

				Local planned:Int
				meshCombined = False
				While planned < activeCount
					groupDraw.includeAmbient = planned = 0 And (Not mappedEmission Or renderer.Capabilities().MappedEmission()) And renderer.Capabilities().AmbientComposition()
					groupDraw.ambientRed = baseRed
					groupDraw.ambientGreen = baseGreen
					groupDraw.ambientBlue = baseBlue
					Local size:Int = SubmitGroup(renderer, TMax2DGraphics.Current(), planned, activeCount, receiveShadows, True)
					If Not size And groupDraw.includeAmbient Then
						groupDraw.includeAmbient = False
						size = SubmitGroup(renderer, TMax2DGraphics.Current(), planned, activeCount, receiveShadows, True)
					End If

					If Not size Then stats.receiverDraws :- 1;Return

					If planned = 0 Then
						meshCombined = groupDraw.includeAmbient
					End If

					meshGroups[planned] = size
					planned :+ size
				Wend

				groupDraw.includeAmbient = False
				meshAccepted = True
			End If

			Local cursor:Int
			If activeCount And batching And renderer Then
				If renderer.Capabilities().AmbientComposition() And (Not mappedEmission Or renderer.Capabilities().MappedEmission()) And (Not meshDeformed Or meshCombined) Then
					groupDraw.includeAmbient = True
					groupDraw.ambientRed = baseRed
					groupDraw.ambientGreen = baseGreen
					groupDraw.ambientBlue = baseBlue
					Local required:Int
					If meshDeformed Then
						required = meshGroups[0]
					End If

					cursor = SubmitGroup(renderer, TMax2DGraphics.Current(), 0, activeCount, receiveShadows, False, required)
					If meshDeformed And Not cursor Then
						Throw "Max2D Lighting: provider changed support after mesh preflight"
					End If

					groupDraw.includeAmbient = False
				End If
			End If

			If cursor Then
				stats.combinedAmbientPasses :+ 1
			Else
				SetBlend(ALPHABLEND)
				DrawReceiver(source, ambientEffect, x, y, frame)
			End If

			stats.ambientPasses :+ 1
			SetBlend(additive)
			While cursor < activeCount
				Local i:Int = activeLights[cursor]
				cursor :+ 1
				Local radius:Float = lights[i + 2]
				If batching Then
					Local consumed:Int = DrawGroup(cursor - 1, activeCount, receiveShadows)
					If consumed Then
						cursor :+ consumed - 1
						Continue
					End If
				End If

				If material And material.GetSpecularMap() And material.GetSpecularStrength() > 0 And Not specularAlpha Then
					normalMap = material.ResolvedNormalMap()
					normalFrame = material.ResolvedNormalFrame()
					specularAlpha = True
					normalEffect.SetTexture(normalMap, normalFrame)
				End If

				Local selectedEffect:TMax2DShaderEffect = pointEffect
				Local texture:TMax2DLightTexture = LightTexture(i / 8, receiveShadows)
				If texture Then
					selectedEffect = texturedEffect
					ConfigureTexture(texture, i / 8, xx * source.width, xy * source.height, yx * source.width, yy * source.height, bx, by)
					If material And normalMap Then
						texturedEffect.SetTexture(normalMap, normalFrame)
					Else
						texturedEffect.SetTexture(source, frame)
					End If

					texturedEffect.SetFloat4("basisX", xx * source.width, xy * source.height, bx, 1.0 / source.width)
					texturedEffect.SetFloat4("basisY", yx * source.width, yy * source.height, by, 1.0 / source.height)
				End If

				If selectedEffect = normalEffect Or texture Then
					Local exponent:Float = lights[i + 7]
					If directional[i / 8] Then
						selectedEffect.SetFloat4("light", lights[i], lights[i + 1], lights[i + 2], 0)
						exponent = -1
					Else
						selectedEffect.SetFloat4("light", lights[i], lights[i + 1], radius, heights[i / 8])
					End If

					Local strength:Float = -2, specular:Float, shininess:Float = 32
					If material Then
						specular = material.GetSpecularStrength()
						shininess = material.GetShininess()
						If specular > 0 Then
							strength = -1
						End If

						If normalMap Then
							strength = material.GetNormalStrength()
							' The compatibility shader encodes gloss mode in the exponent sign.
							If specularAlpha Then
								shininess = -shininess
							End If
						End If
					End If

					selectedEffect.SetFloat4("shape", exponent, strength, specular, shininess)
				Else
					selectedEffect.SetFloat4("light", lights[i], lights[i + 1], radius, radius)
					If directional[i / 8] Then
						selectedEffect.SetFloat4("shape", 1, 0, 0, 0)
					Else
						selectedEffect.SetFloat4("shape", lights[i + 7], 1, 0, 0)
					End If
				End If

				selectedEffect.SetFloat4("colour", lights[i + 3], lights[i + 4], lights[i + 5], lights[i + 6])
				DrawReceiver(source, selectedEffect, x, y, frame)
				stats.lightPasses :+ 1
				stats.lightContributions :+ 1
			Wend
		Finally
			groupDraw.ClearImages()
			groupMaterial = Null
			emissionEffect.SetTexture(Null)
			normalEffect.SetTexture(Null)
			texturedEffect.SetTexture(Null)
			texturedEffect.SetThirdTexture(Null)
			SetBlend(oldBlend)
		End Try
	End Method
	Rem
	bbdoc: Lights a textured triangle mesh directly, with no per-receiver capture.
	param: Borrowed triangle mesh with finite positions and valid UVs and indices.
	param: Borrowed image; its lifetime remains application-owned.
	param: Finite horizontal coordinate in local drawing units before the supplied light-space transform.
	param: Finite vertical coordinate in local drawing units before the supplied light-space transform.
	param: Zero-based frame index in the supplied image.
	param: 32-bit receiver selection mask, intersected with the material mask.
	param: Coefficient of X in the transformed X coordinate.
	param: Coefficient of Y in the transformed X coordinate.
	param: Coefficient of X in the transformed Y coordinate.
	param: Coefficient of Y in the transformed Y coordinate.
	param: Horizontal affine translation.
	param: Vertical affine translation.
	param: Optional shared material; Null uses default lighting settings.
	about: UVs address the full image rectangle. Each nondegenerate UV triangle defines its own affine image-to-lighting mapping, including
	the normal-map basis. Uses current drawing state and drawing handle; ignores the image handle. The supplied affine transform maps
	mesh-local geometry plus x/y into light coordinates, independently of the camera. Supports existing materials, patterns and shadows.
	SetLightBatching combines eligible lights when the provider advertises MeshGeometry; unsupported providers or groups use ordinary
	lighting. Providers advertising AffineMeshGeometry can draw consecutive non-overlapping triangles with one shared UV-to-geometry
	basis per light group. A deformed mesh may contain several such sections; section order preserves painter order even when
	sections overlap. Providers advertising DeformedMeshGeometry can draw the entire non-overlapping mesh with independent triangle
	mappings; every light group is preflighted before drawing. Rejected groups, overlaps and unsupported drawing transforms
	retain section/triangle fallback. Current analysis considers at most 512 triangles. Section grouping requires exact basis
	agreement; general grouping checks geometry overlap using bounds followed by separating axes. One retained value snapshot
	per processor detects raw array edits. Changed geometry rebuilds local mappings and section boundaries, reusing earlier
	disjoint-section proofs when UVs and indices are unchanged. New merges or topology changes can require bounded quadratic
	overlap analysis; unchanged data uses linear value checks. Per-triangle mappings, snapshot-backed section meshes and index
	buffers are retained for reuse. Current draw transforms are still validated before submission. Release discards this analysis.
	Warm calls reuse triangle and section storage. Invalid indices, nonfinite data, out-of-range UVs and near-singular UV triangles
	throw before drawing. Overlapping triangles compose in index order. Unlit materials use ordinary textured drawing. Borrowed
	meshes/images must not be mutated during drawing.
	End Rem
	Method DrawMesh(mesh:TMesh2D, image:TImage, x:Float = 0, y:Float = 0, frame:Int = 0, receiverMask:Int = -1, xx:Float = 1, xy:Float = 0, yx:Float = 0, yy:Float = 1, tx:Float = 0, ty:Float = 0, material:TMax2DLightingMaterial = Null)
		If Not mesh Or Not image Then
			Return
		End If

		If drawingMesh Then
			Throw "Max2D Lighting: recursive mesh drawing"
		End If

		image.CheckIndex(frame)
		If material And material.GetUnlit() Then
			DrawTexturedMesh(mesh, image, x, y, frame)
			Return
		End If

		If mesh.xy.Length < 6 Or (mesh.xy.Length & 1) Or mesh.uv.Length <> mesh.xy.Length Or mesh.indices.Length Mod 3 Then
			Throw "Max2D Lighting: invalid mesh arrays"
		End If

		For Local i:Int = 0 Until mesh.xy.Length
			If IsNan(mesh.xy[i]) Or IsInf(mesh.xy[i]) Or IsNan(mesh.uv[i]) Or IsInf(mesh.uv[i]) Or mesh.uv[i] < 0 Or mesh.uv[i] > 1 Then
				Throw "Max2D Lighting: invalid mesh coordinate"
			End If
		Next

		For Local index:Int = EachIn mesh.indices
			If index < 0 Or index >= mesh.xy.Length / 2 Then
				Throw "Max2D Lighting: mesh index out of range"
			End If
		Next

		If Not meshTriangle Then
			meshTriangle = TMesh2D.Create([0.0, 0.0, 1.0, 0.0, 0.0, 1.0], [0, 1, 2], [0.0, 0.0, 1.0, 0.0, 0.0, 1.0])
		End If

		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		Local whole:Int, mappingCache:TMax2DLightingMeshCache
		If batching And mesh.indices.Length > 3 And mesh.indices.Length <= 512 * 3 Then
			PrepareRenderer()
			If renderer And renderer.Capabilities().AffineMeshGeometry() Then
				If Not meshCache Then
					meshCache = New TMax2DLightingMeshCache
				End If

				whole = meshCache.Accepts(mesh)
				mappingCache = meshCache
			End If
		End If
		' Validate every transformed basis before submitting any triangles, even
		' when unchanged local mappings can be reused from the retained analysis.
		For Local triangle:Int = 0 Until mesh.indices.Length Step 3
			MeshMapping(mesh, triangle, image.width, image.height, x - canvas.state.handleX, y - canvas.state.handleY, xx, xy, yx, yy, tx, ty, mappingCache)
		Next

		drawingMesh = True
		meshX = x
		meshY = y
		Try
			If mappingCache And renderer.Capabilities().DeformedMeshGeometry() And mappingCache.runCount > 1 Then
				If mappingCache.DisjointGeometry() Then
					meshGeometry[0] = xx
					meshGeometry[1] = xy
					meshGeometry[2] = yx
					meshGeometry[3] = yy
					meshGeometry[4] = tx
					meshGeometry[5] = ty
					meshDeformed = True
					meshAccepted = False
					meshReceiver = mesh
					MeshMapping(mesh, 0, image.width, image.height, x - canvas.state.handleX, y - canvas.state.handleY, xx, xy, yx, yy, tx, ty, mappingCache)
					DrawImage(image, image.handle_x, image.handle_y, frame, receiverMask, meshBasis[0], meshBasis[1], meshBasis[2], meshBasis[3], meshBasis[4], meshBasis[5], material)
					meshDeformed = False
					If meshAccepted Then
						Return
					End If
				End If
			End If

			If whole Then
				For Local section:Int = 0 Until meshCache.runCount
					meshReceiver = mesh
					If meshCache.runCount > 1 Then
						meshReceiver = meshCache.meshes[section]
					End If

					MeshMapping(mesh, meshCache.starts[section], image.width, image.height, x - canvas.state.handleX, y - canvas.state.handleY, xx, xy, yx, yy, tx, ty, mappingCache)
					DrawImage(image, image.handle_x, image.handle_y, frame, receiverMask, meshBasis[0], meshBasis[1], meshBasis[2], meshBasis[3], meshBasis[4], meshBasis[5], material)
				Next

				Return
			End If

			meshReceiver = meshTriangle
			For Local triangle:Int = 0 Until mesh.indices.Length Step 3
				MeshMapping(mesh, triangle, image.width, image.height, x - canvas.state.handleX, y - canvas.state.handleY, xx, xy, yx, yy, tx, ty, mappingCache)
				For Local corner:Int = 0 Until 3
					Local index:Int = mesh.indices[triangle + corner] * 2
					meshTriangle.xy[corner * 2] = mesh.xy[index]
					meshTriangle.xy[corner * 2 + 1] = mesh.xy[index + 1]
					meshTriangle.uv[corner * 2] = mesh.uv[index]
					meshTriangle.uv[corner * 2 + 1] = mesh.uv[index + 1]
				Next

				DrawImage(image, image.handle_x, image.handle_y, frame, receiverMask, meshBasis[0], meshBasis[1], meshBasis[2], meshBasis[3], meshBasis[4], meshBasis[5], material)
			Next
		Finally
			drawingMesh = False
			meshReceiver = Null
			meshDeformed = False
		End Try
	End Method

	Private
	Method MeshMapping(mesh:TMesh2D, triangle:Int, width:Int, height:Int, x:Float, y:Float, xx:Float, xy:Float, yx:Float, yy:Float, tx:Float, ty:Float, cache:TMax2DLightingMeshCache = Null)
		Local a:Int = mesh.indices[triangle] * 2, b:Int = mesh.indices[triangle + 1] * 2, c:Int = mesh.indices[triangle + 2] * 2
		Local u:Double = mesh.uv[a], v:Double = mesh.uv[a + 1]
		Local ax:Double, ay:Double, bx:Double, by:Double
		If cache Then
			Local offset:Int = triangle * 2
			ax = cache.mappings[offset]
			ay = cache.mappings[offset + 1]
			bx = cache.mappings[offset + 2]
			by = cache.mappings[offset + 3]
		Else
			Local du:Double = Double(mesh.uv[b]) - u, dv:Double = Double(mesh.uv[b + 1]) - v
			Local eu:Double = Double(mesh.uv[c]) - u, ev:Double = Double(mesh.uv[c + 1]) - v
			Local determinant:Double = du * ev - dv * eu
			If Abs(determinant) < 0.000000000001 Then
				Throw "Max2D Lighting: mesh triangle has singular UVs"
			End If

			Local dx:Double = Double(mesh.xy[b]) - mesh.xy[a], dy:Double = Double(mesh.xy[b + 1]) - mesh.xy[a + 1]
			Local ex:Double = Double(mesh.xy[c]) - mesh.xy[a], ey:Double = Double(mesh.xy[c + 1]) - mesh.xy[a + 1]
			ax = (dx * ev - ex * dv) / determinant
			ay = (ex * du - dx * eu) / determinant
			bx = (dy * ev - ey * dv) / determinant
			by = (ey * du - dy * eu) / determinant
		End If

		Local px:Double = mesh.xy[a] + Double(x) - ax * u - ay * v, py:Double = mesh.xy[a + 1] + Double(y) - bx * u - by * v
		meshBasis[0] = Float((xx * ax + xy * bx) / width)
		meshBasis[1] = Float((xx * ay + xy * by) / height)
		meshBasis[2] = Float((yx * ax + yy * bx) / width)
		meshBasis[3] = Float((yx * ay + yy * by) / height)
		meshBasis[4] = Float(xx * px + xy * py + tx)
		meshBasis[5] = Float(yx * px + yy * py + ty)
		For Local value:Float = EachIn meshBasis
			If IsNan(value) Or IsInf(value) Then
				Throw "Max2D Lighting: nonfinite mesh lighting transform"
			End If
		Next
	End Method

	Method DrawReceiver(source:TImage, selectedEffect:TMax2DShaderEffect, x:Float, y:Float, frame:Int)
		If drawingMesh Then
			selectedEffect.DrawMesh(meshReceiver, source, meshX, meshY, frame)
		Else
			DrawImageEffect(source, selectedEffect, x, y, frame)
		End If
	End Method

	Public
	Rem
	bbdoc: Prepares one matching output image and validates shader and blend support on its actual format.
	param: Width in pixels; finite and positive.
	param: Height in pixels; finite and positive.
	param: Render-image format: PF_RGBA8888, PF_RGBA16F or PF_RGBA32F, subject to backend support.
	about: Identical layouts reuse storage. Unsupported backends throw. Preserves caller state; cannot migrate between
	live contexts or replace a selected output. A failed replacement preserves previous storage.
	End Rem
	Method Prepare(width:Int, height:Int, pixelFormat:Int = PF_RGBA8888)
		If buffers Then
			Local previous:TRenderImage = buffers.Image(0)
			If Self.width = width And Self.height = height And format = pixelFormat Then
				ValidateTarget(previous)
				Return
			End If

			If TMax2DGraphics.Current().renderImage = previous Then
				Throw "Max2D Lighting: deselect output before resizing"
			End If
		End If

		Local candidate:TMax2DEffectBuffers = New TMax2DEffectBuffers
		Try
			candidate.Prepare(width, height, 1, -1, pixelFormat)
			ValidateTarget(candidate.Image(0))
			If buffers Then
				buffers.Release()
			End If
		Catch error:Object
			candidate.Release()
			Throw error
		End Try

		buffers = candidate
		Self.width = width
		Self.height = height
		format = pixelFormat
	End Method
	Rem
	bbdoc: Illuminates matching source artwork, returning a distinct borrowed image while preserving source and caller state.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	param: Horizontal lighting-space coordinate corresponding to source pixel zero.
	param: Vertical lighting-space coordinate corresponding to source pixel zero.
	param: Finite positive pixels per lighting-space unit.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	about: Origin and scale map retained light coordinates into source pixels: pixel=(position-origin)*scale. Defaults suit ordinary Max2D; scene adapters supply their capture origin and resolution. Uses one ambient pass plus one bounded pass per visible enabled light. Warm updates allocate no textures, light arrays or effect descriptions. State scopes are short-lived objects. Source alpha is copied once and never accumulated. Padding and transparent source pixels do not become opaque. Draw HUD artwork after presenting this result.
	End Rem
	Method Update:TRenderImage(source:TRenderImage, originX:Float = 0, originY:Float = 0, scale:Float = 1)
		If Not buffers Then
			Throw "Max2D Lighting: prepare before update"
		End If

		Local destination:TRenderImage = buffers.Image(0)
		If Not source Or source = destination Then
			Throw "Max2D Lighting: source must be distinct from output"
		End If

		If source.width <> width Or source.height <> height Or source.sources[0].targetFormat <> format Then
			Throw "Max2D Lighting: source differs from prepared layout"
		End If

		If IsNan(originX) Or IsInf(originX) Or IsNan(originY) Or IsInf(originY) Or IsNan(scale) Or IsInf(scale) Or scale <= 0 Then
			Throw "Max2D Lighting: invalid coordinate mapping"
		End If

		stats.receiverDraws :+ 1
		RefreshSources()
		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			source.Frame(0, TMax2DGraphics.Current())
			SetRenderImage(destination)
			Local view:TMax2DStateScope = ScopedMax2DState()
			Try
				SetVirtualResolution(width, height)
				SetViewport(0, 0, width, height)
				SetCamera(Null)
				ResetCoordinates()
				SetAffineTransform(1, 0, 0, 1)
				SetOrigin(0, 0)
				SetHandle(0, 0)
				SetColor(255, 255, 255)
				SetAlpha(1)
				SetBlend(SOLIDBLEND)
				effect.SetFloat4("basisX", 1, 0, 0, 0)
				effect.SetFloat4("basisY", 0, 1, 0, 0)
				effect.SetFloat4("light", 0, 0, 1, 1)
				effect.SetFloat4("shape", 1, 0, 0, 0)
				effect.SetFloat4("colour", ambientRed / 255.0, ambientGreen / 255.0, ambientBlue / 255.0, ambientIntensity)
				DrawImageEffect(source, effect, source.handle_x, source.handle_y)
				stats.ambientPasses :+ 1
				SetBlend(additive)
				For Local i:Int = 0 Until lights.Length Step 8
					stats.lightTests :+ 1
					If lights[i + 6] = 0 Or masks[i / 8] = 0 Then stats.excludedLights :+ 1;Continue

					If directional[i / 8] Then
						SetViewport(0, 0, width, height)
						Local shadowTexture:TMax2DLightTexture = LightTexture(i / 8, True)
						If shadowTexture Then
							ConfigureTexture(shadowTexture, i / 8, width / scale, 0, 0, height / scale, originX, originY)
							texturedEffect.SetTexture(source)
							texturedEffect.SetFloat4("basisX", width / scale, 0, originX, scale / width)
							texturedEffect.SetFloat4("basisY", 0, height / scale, originY, scale / height)
							texturedEffect.SetFloat4("light", lights[i], lights[i + 1], lights[i + 2], 0)
							texturedEffect.SetFloat4("shape", -1, -2, 0, 32)
							texturedEffect.SetFloat4("colour", lights[i + 3], lights[i + 4], lights[i + 5], lights[i + 6])
							DrawImageEffect(source, texturedEffect, source.handle_x, source.handle_y)
							stats.lightPasses :+ 1
							stats.lightContributions :+ 1
							Continue
						End If

						effect.SetFloat4("light", 0, 0, 1, 1)
						effect.SetFloat4("shape", 1, 0, 0, 0)
						effect.SetFloat4("colour", lights[i + 3], lights[i + 4], lights[i + 5], lights[i + 6])
						DrawImageEffect(source, effect, source.handle_x, source.handle_y)
						stats.lightPasses :+ 1
						stats.lightContributions :+ 1
						Continue
					End If

					Local x:Double = (Double(lights[i]) - originX) * scale, y:Double = (Double(lights[i + 1]) - originY) * scale, radius:Double = Double(lights[i + 2]) * scale
					If x + radius <= 0 Or y + radius <= 0 Or x - radius >= width Or y - radius >= height Then stats.boundsRejects :+ 1;Continue

					Local left:Int = Int(Max(0.0, Floor(x - radius))), top:Int = Int(Max(0.0, Floor(y - radius)))
					Local right:Int = Int(Min(Double(width), Ceil(x + radius))), bottom:Int = Int(Min(Double(height), Ceil(y + radius)))
					SetViewport(left, top, right - left, bottom - top)
					Local texture:TMax2DLightTexture = LightTexture(i / 8, True)
					If texture Then
						ConfigureTexture(texture, i / 8, width / scale, 0, 0, height / scale, originX, originY)
						texturedEffect.SetTexture(source)
						texturedEffect.SetFloat4("basisX", width / scale, 0, originX, scale / width)
						texturedEffect.SetFloat4("basisY", 0, height / scale, originY, scale / height)
						texturedEffect.SetFloat4("light", lights[i], lights[i + 1], lights[i + 2], heights[i / 8])
						texturedEffect.SetFloat4("shape", lights[i + 7], -2, 0, 32)
						texturedEffect.SetFloat4("colour", lights[i + 3], lights[i + 4], lights[i + 5], lights[i + 6])
						DrawImageEffect(source, texturedEffect, source.handle_x, source.handle_y)
						stats.lightPasses :+ 1
						stats.lightContributions :+ 1
						Continue
					End If

					effect.SetFloat4("light", Float(x / width), Float(y / height), Float(radius / width), Float(radius / height))
					effect.SetFloat4("shape", lights[i + 7], 1, 0, 0)
					effect.SetFloat4("colour", lights[i + 3], lights[i + 4], lights[i + 5], lights[i + 6])
					DrawImageEffect(source, effect, source.handle_x, source.handle_y)
					stats.lightPasses :+ 1
					stats.lightContributions :+ 1
				Next
			Finally
				view.Close()
			End Try
		Finally
			scope.Close()
		End Try

		Return destination
	End Method
	Rem
	bbdoc: Releases owned output and shadow storage, retaining ambient, light and occluder settings; repeated calls are harmless.
	End Rem
	Method Release()
		ReleaseRenderer()
		meshCache = Null
		If buffers Then
			buffers.Release()
		End If

		buffers = Null
		width = 0
		height = 0
		For Local shadow:TMax2DLightShadow = EachIn shadows
			If shadow Then
				shadow.Release()
			End If
		Next
	End Method

	Private
	Method PrepareRenderer()
		Local context:TMax2DContext = TMax2DGraphics.Current().context
		If rendererContext = context Then
			Return
		End If

		ReleaseRenderer()
		renderer = CreateMax2DLightingRenderer(context)
		If Not renderer Then
			renderer = CreateNativeMax2DLightingRenderer(context, batchLimit)
		End If

		rendererContext = context
	End Method

	Method ReleaseRenderer()
		If renderer Then
			renderer.Release()
		End If

		If pairedRenderer Then
			pairedRenderer.Release()
		End If

		renderer = Null
		pairedRenderer = Null
		rendererContext = Null
		groupDraw.ClearImages()
		groupMaterial = Null
	End Method

	Method PrepareDraw(source:TImage, x:Float, y:Float, frame:Int, xx:Float, xy:Float, yx:Float, yy:Float, tx:Float, ty:Float, material:TMax2DLightingMaterial, normalMap:TImage, normalFrame:Int, specularAlpha:Int)
		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		groupMaterial = material
		groupDraw.includeAmbient = False
		groupDraw.source = source
		groupDraw.frame = frame
		groupDraw.x = x
		groupDraw.y = y
		groupDraw.mesh = Null
		groupDraw.deformed = meshDeformed
		If drawingMesh Then
			groupDraw.mesh = meshReceiver
			groupDraw.x = meshX
			groupDraw.y = meshY
		End If

		groupDraw.xx = xx
		groupDraw.xy = xy
		groupDraw.yx = yx
		groupDraw.yy = yy
		groupDraw.tx = tx
		groupDraw.ty = ty
		If meshDeformed Then
			groupDraw.xx = meshGeometry[0]
			groupDraw.xy = meshGeometry[1]
			groupDraw.yx = meshGeometry[2]
			groupDraw.yy = meshGeometry[3]
			groupDraw.tx = meshGeometry[4]
			groupDraw.ty = meshGeometry[5]
		End If

		groupDraw.sourceFormat = source.Frame(frame, canvas).pixelFormat
		groupDraw.targetFormat = canvas.context.DrawingPixelFormat()
		groupDraw.emissionMap = Null
		groupDraw.emissionFrame = 0
		groupDraw.emissionIntensity = 0
		groupDraw.normalMap = Null
		groupDraw.normalFrame = 0
		groupDraw.normalStrength = 1
		groupDraw.specularMap = Null
		groupDraw.specularFrame = 0
		groupDraw.specularStrength = 0
		groupDraw.shininess = 32
		groupDraw.specularFromNormalAlpha = False
		If material Then
			If material.GetEmissionMap() And material.GetEmissionIntensity() > 0 Then
				groupDraw.emissionMap = material.GetEmissionMap()
				groupDraw.emissionFrame = material.GetEmissionFrame()
				groupDraw.emissionRed = material.GetEmissionRed() / 255.0
				groupDraw.emissionGreen = material.GetEmissionGreen() / 255.0
				groupDraw.emissionBlue = material.GetEmissionBlue() / 255.0
				groupDraw.emissionIntensity = material.GetEmissionIntensity()
			End If

			groupDraw.normalMap = normalMap
			groupDraw.normalFrame = normalFrame
			groupDraw.normalStrength = material.GetNormalStrength()
			groupDraw.specularFromNormalAlpha = groupDraw.normalMap <> Null And specularAlpha
			groupDraw.specularStrength = material.GetSpecularStrength()
			groupDraw.shininess = material.GetShininess()
			If groupDraw.specularStrength > 0 And renderer And renderer.Capabilities().MappedSpecular() Then
				groupDraw.specularMap = material.GetSpecularMap()
				groupDraw.specularFrame = material.GetSpecularFrame()
			End If
		End If
	End Method

	Method DrawGroup:Int(start:Int, activeCount:Int, receiveShadows:Int)
		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		Local consumed:Int
		If meshDeformed Then
			consumed = SubmitGroup(renderer, canvas, start, activeCount, receiveShadows, False, meshGroups[start])
			If Not consumed Then
				Throw "Max2D Lighting: provider changed support after mesh preflight"
			End If

			Return consumed
		End If

		If renderer Then
			consumed = SubmitGroup(renderer, canvas, start, activeCount, receiveShadows)
		End If

		If Not consumed Then
			If Not pairedRenderer Then
				pairedRenderer = New TMax2DPairedLightingRenderer
			End If

			consumed = SubmitGroup(pairedRenderer, canvas, start, activeCount, receiveShadows)
		End If

		Return consumed
	End Method

	Method SubmitGroup:Int(selected:TMax2DLightingRenderer, canvas:TMax2DGraphics, start:Int, activeCount:Int, receiveShadows:Int, checkOnly:Int = False, requiredSize:Int = 0)
		If Not groupDraw.specularMap Then
			Return SubmitMaterialGroup(selected, canvas, start, activeCount, receiveShadows, checkOnly, requiredSize)
		End If

		If selected.Capabilities().MappedSpecular() Then
			Local consumed:Int = SubmitMaterialGroup(selected, canvas, start, activeCount, receiveShadows, checkOnly, requiredSize)
			If consumed Then
				Return consumed
			End If
		End If
		' Retry the same provider with the established packed representation. Keep
		' original maps for later groups and restore them even if packing/drawing fails.
		Local normal:TImage = groupDraw.normalMap, normalFrame:Int = groupDraw.normalFrame
		Local specular:TImage = groupDraw.specularMap, specularFrame:Int = groupDraw.specularFrame
		Local alpha:Int = groupDraw.specularFromNormalAlpha
		Try
			groupDraw.normalMap = groupMaterial.ResolvedNormalMap()
			groupDraw.normalFrame = groupMaterial.ResolvedNormalFrame()
			groupDraw.specularMap = Null
			groupDraw.specularFrame = 0
			groupDraw.specularFromNormalAlpha = True
			Return SubmitMaterialGroup(selected, canvas, start, activeCount, receiveShadows, checkOnly, requiredSize)
		Finally
			groupDraw.normalMap = normal
			groupDraw.normalFrame = normalFrame
			groupDraw.specularMap = specular
			groupDraw.specularFrame = specularFrame
			groupDraw.specularFromNormalAlpha = alpha
		End Try
	End Method

	Method SubmitMaterialGroup:Int(selected:TMax2DLightingRenderer, canvas:TMax2DGraphics, start:Int, activeCount:Int, receiveShadows:Int, checkOnly:Int = False, requiredSize:Int = 0)
		Local limits:TMax2DLightingCapabilities = selected.Capabilities()
		If groupDraw.deformed And Not limits.DeformedMeshGeometry() Then
			Return 0
		End If

		If groupDraw.mesh And Not limits.MeshGeometry() Then
			Return 0
		End If

		If groupDraw.mesh And groupDraw.mesh.indices.Length > 3 And Not limits.AffineMeshGeometry() Then
			Return 0
		End If

		If groupDraw.includeAmbient And Not limits.AmbientComposition() Then
			Return 0
		End If

		If groupDraw.includeAmbient And groupDraw.emissionMap And Not limits.MappedEmission() Then
			Return 0
		End If

		If groupDraw.normalMap And Not limits.NormalMaps() Then
			Return 0
		End If

		If groupDraw.specularStrength > 0 And Not limits.Specular() Then
			Return 0
		End If

		If groupDraw.specularMap And Not limits.MappedSpecular() Then
			Return 0
		End If

		If groupDraw.specularFromNormalAlpha And Not limits.SpecularMaps() Then
			Return 0
		End If

		Local count:Int = Min(batchLimit, Min(limits.MaximumLights(), activeCount - start))
		If requiredSize Then
			count = requiredSize
		End If

		If count < limits.MinimumLights() Then
			Return 0
		End If

		groupDraw.Reserve(count)
		Local eligible:Int
		For Local n:Int = 0 Until count
			Local i:Int = activeLights[start + n], index:Int = i / 8
			Local item:TMax2DLightingDrawLight = groupDraw.lights[n]
			item.directional = directional[index]
			item.patterned = textures[index] <> Null
			item.shadowed = receiveShadows And shadows[index] <> Null
			If item.directional And Not limits.DirectionalLights() Then
				Exit
			End If

			If item.patterned And Not limits.ProjectedPatterns() Then
				Exit
			End If

			If item.shadowed And Not limits.Shadows() Then
				Exit
			End If

			item.hasMap = item.patterned Or item.shadowed
			item.mapWidth = 0
			item.mapHeight = 0
			item.mapFormat = 0
			item.mapFlags = 0
			If item.shadowed Then
				item.mapWidth = shadows[index].resolution
				item.mapHeight = item.mapWidth
				item.mapFormat = PF_RGBA8888
				item.mapFlags = FILTEREDIMAGE
			Else If item.patterned Then
				item.mapWidth = textures[index].image.width
				item.mapHeight = textures[index].image.height
				Local mapSource:TImageSource = textures[index].image.sources[textures[index].frame]
				item.mapFormat = mapSource.targetFormat
				item.mapFlags = mapSource.flags
				If mapSource.pixmap Then
					item.mapFormat = mapSource.pixmap.format
				End If

				If mapSource.textureData Then
					item.mapFormat = mapSource.textureData.Format()
				End If
			End If

			item.x = lights[i]
			item.y = lights[i + 1]
			item.z = lights[i + 2]
			item.radius = lights[i + 2]
			item.height = heights[index]
			item.falloff = lights[i + 7]
			item.red = lights[i + 3]
			item.green = lights[i + 4]
			item.blue = lights[i + 5]
			item.intensity = lights[i + 6]
			item.map = Null
			item.mapKey = Null
			item.mapRevision = 0
			eligible :+ 1
		Next

		Local minimum:Int = limits.MinimumLights()
		If requiredSize Then
			minimum = requiredSize
		End If

		For Local size:Int = eligible To minimum Step -1
			groupDraw.count = size
			stats.groupSupportChecks :+ 1
			If Not selected.Supports(canvas, groupDraw) Then
				stats.groupSupportRejections :+ 1
				Continue
			End If

			If checkOnly Then
				Return size
			End If

			For Local n:Int = 0 Until size
				Local index:Int = activeLights[start + n] / 8
				Local item:TMax2DLightingDrawLight = groupDraw.lights[n]
				Local texture:TMax2DLightTexture = LightTexture(index, receiveShadows)
				If texture Then
					item.map = texture.image
					item.mapFrame = texture.frame
					item.mapKey = texture
					item.mapRevision = texture.pixelRevision
					item.mapXX = texture.xx
					item.mapXY = texture.xy
					item.mapYX = texture.yx
					item.mapYY = texture.yy
					item.mapTX = texture.tx
					item.mapTY = texture.ty
					item.mapClamp = item.directional
					If Not item.directional Then
						item.mapTX :- texture.xx * item.x + texture.xy * item.y
						item.mapTY :- texture.yx * item.x + texture.yy * item.y
					End If
				End If
			Next

			Local uploads:Long = selected.MapUploads(), hits:Long = selected.MapCacheHits()
			Try
				selected.Draw(canvas, groupDraw)
			Finally
				stats.mapUploads :+ selected.MapUploads() - uploads
				stats.mapHits :+ selected.MapCacheHits() - hits
			End Try

			stats.lightPasses :+ 1
			stats.groupedPasses :+ 1
			stats.lightContributions :+ size
			stats.groupedLightContributions :+ size
			stats.maximumGroupSize = Max(stats.maximumGroupSize, size)
			If size = 2 Then
				stats.pairedPasses :+ 1
			End If

			Return size
		Next

		Return 0
	End Method

	Method InvalidateShadow(index:Int)
		If shadows[index] Then
			shadows[index].valid = False
		End If
	End Method

	Method InvalidateShadows()
		For Local shadow:TMax2DLightShadow = EachIn shadows
			If shadow Then
				shadow.valid = False
			End If
		Next
	End Method

	Method RefreshSources()
		For Local i:Int = 0 Until textures.Length
			If textures[i] Then
				SetLightTexture(i, textures[i])
			End If
		Next

		Revision()
	End Method

	Method LightTexture:TMax2DLightTexture(index:Int, receiveShadows:Int)
		If receiveShadows And shadows[index] Then
			If textures[index] And textures[index].image = TMax2DGraphics.Current().renderImage Then
				Throw "Max2D Lighting: light pattern is the current render target"
			End If

			Return shadows[index].Update(lights[index * 8], lights[index * 8 + 1], lights[index * 8 + 2], occluders, casterStates, textures[index], directional[index], lights[index * 8], lights[index * 8 + 1], lights[index * 8 + 2], heights[index], stats)
		End If

		Return textures[index]
	End Method

	Method ConfigureTexture(texture:TMax2DLightTexture, index:Int, a:Float, b:Float, d:Float, e:Float, ox:Float, oy:Float)
		Local x:Float = ox - lights[index * 8], y:Float = oy - lights[index * 8 + 1]
		texturedEffect.SetThirdTextureEdgeMode(MAX2D_EDGE_TRANSPARENT)
		If directional[index] Then
			x = ox
			y = oy
			texturedEffect.SetThirdTextureEdgeMode(MAX2D_EDGE_CLAMP)
		End If

		texturedEffect.SetThirdTexture(texture.image, texture.frame)
		texturedEffect.SetFloat4("cookieX", texture.xx * a + texture.xy * d, texture.xx * b + texture.xy * e, texture.xx * x + texture.xy * y + texture.tx, 0)
		texturedEffect.SetFloat4("cookieY", texture.yx * a + texture.yy * d, texture.yx * b + texture.yy * e, texture.yx * x + texture.yy * y + texture.ty, 0)
	End Method

	Method ValidateTarget(target:TRenderImage)
		Local scope:TMax2DStateScope = ScopedMax2DState()
		Try
			SetRenderImage(target)
			SetBlend(SOLIDBLEND)
			If Not Max2DSupportsImageEffect(effect) Then
				Throw "Max2D Lighting: shader provider does not support lighting on this target"
			End If

			SetBlend(additive)
			If Not Max2DSupportsImageEffect(effect) Then
				Throw "Max2D Lighting: additive lighting is unsupported on this target"
			End If
		Finally
			scope.Close()
		End Try
	End Method
End Type

Private
Function CheckLightingColour(red:Int, green:Int, blue:Int, intensity:Float)
	If red < 0 Or red > 255 Or green < 0 Or green > 255 Or blue < 0 Or blue > 255 Or intensity < 0 Or IsNan(intensity) Or IsInf(intensity) Then
		Throw "Max2D Lighting: invalid colour or intensity"
	End If
End Function

Public
Rem
bbdoc: Validates finite directional shadow bounds without allocating resources.
param: Finite horizontal coordinate in lighting/world units.
param: Finite vertical coordinate in lighting/world units.
param: Width in lighting/world units; finite and positive.
param: Height in lighting/world units; finite and positive.
about: Used by scene and ECS adapters before retaining a rectangle. Throws for nonpositive dimensions or unrepresentable coordinates.
End Rem
Function CheckDirectionalShadowBounds(x:Float, y:Float, width:Float, height:Float)
	If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(width) Or IsInf(width) Or IsNan(height) Or IsInf(height) Or width <= 0 Or height <= 0 Then
		Throw "Max2D Lighting: invalid directional shadow bounds"
	End If

	If IsInf(Float(Double(x) + width)) Or IsInf(Float(Double(y) + height)) Or width / 2 = 0 Or height / 2 = 0 Or Float(Double(x) + width) <= x Or Float(Double(y) + height) <= y Then
		Throw "Max2D Lighting: directional shadow bounds out of range"
	End If
End Function
