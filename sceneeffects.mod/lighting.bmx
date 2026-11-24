Rem
bbdoc: Retained ambient and coloured point/directional illumination for a scene subtree.
about: Point positions and radii are in the composite's local logical coordinates. Light edits invalidate processing without recapturing unchanged artwork. Put an unlit HUD in a sibling layer outside the composite. Lighting preserves alpha and does not expand bounds, cast shadows or illuminate separate composites. Uses Max2D.Lighting and requires the renderer's shader provider.
End Rem
Type TSceneLightingStage Extends TSceneEffectStage
	Private
	Field processor:TMax2DLighting = TMax2DLighting.Create()
	Field prepared:TSceneStageLayout
	Field canvas:TSceneRect = New TSceneRect
	Public
	Rem
	bbdoc: Creates a lighting stage with initially disabled light slots and white ambient illumination.
	param: Nonnegative number of retained light slots; new slots are disabled.
	returns: A new #TSceneLightingStage instance configured with the supplied settings.
	End Rem
	Function Create:TSceneLightingStage(lightCount:Int = 0)
		Local result:TSceneLightingStage = New TSceneLightingStage
		result.SetLightCount(lightCount)
		Return result
	End Function
	Rem
	bbdoc: Resizes the retained light list, preserving existing slots and disabling new ones.
	param: Nonnegative number of retained light slots.
	about: Changes CPU storage only when the count changes. Set intensity zero to temporarily disable a light without resizing.
	End Rem
	Method SetLightCount(count:Int)
		If count = processor.GetLightCount() Then
			Return
		End If

		If owner Then
			owner.CheckGroupMutable()
		End If

		Local previous:Long = processor.Revision()
		processor.SetLightCount(count)
		If previous <> processor.Revision() Then
			Invalidate()
		End If
	End Method
	Rem
	bbdoc: Returns the number of retained light slots.
	returns: The number of retained light slots.
	End Rem
	Method GetLightCount:Int()
		Return processor.GetLightCount()
	End Method
	Rem
	bbdoc: Sets ambient colour (0..255 per component) and finite nonnegative intensity.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	about: White at intensity one preserves artwork; zero removes the ambient contribution. Changes reuse captured artwork and output storage.
	End Rem
	Method SetAmbient(red:Int, green:Int, blue:Int, intensity:Float = 1)
		If owner Then
			owner.CheckGroupMutable()
		End If

		Local previous:Long = processor.Revision()
		processor.SetAmbient(red, green, blue, intensity)
		If previous <> processor.Revision() Then
			Invalidate()
		End If
	End Method
	Rem
	bbdoc: Sets a light in composite-local logical units, with no texture or descriptor allocation.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Finite horizontal coordinate in node-local units.
	param: Finite vertical coordinate in node-local units.
	param: Finite positive light radius in composite-local logical units.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	param: Finite positive attenuation exponent; one is linear and two is quadratic.
	about: Index must exist. Position is finite; radius and falloff are finite and positive. Colour components are 0..255; intensity is finite and nonnegative, with zero disabling the light. Attenuation is (max(0,1-distance/radius))^falloff. Falloff one is linear, two quadratic. Positions move and scale with the composite, including its camera. Use a fixed canvas for a world whose lights move beyond its current artwork bounds.
	End Rem
	Method SetPointLight(index:Int, x:Float, y:Float, radius:Float, red:Int = 255, green:Int = 255, blue:Int = 255, intensity:Float = 1, falloff:Float = 2)
		If owner Then
			owner.CheckGroupMutable()
		End If

		Local previous:Long = processor.Revision()
		processor.SetPointLight(index, x, y, radius, red, green, blue, intensity, falloff)
		If previous <> processor.Revision() Then
			Invalidate()
		End If
	End Method
	Rem
	bbdoc: Assigns a shared projected pattern to a point-light slot; Null clears it.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Shared projected light pattern; Null clears the pattern.
	about: Placement uses composite-local logical units. After editing shared texture settings or pixels, call this setter again to invalidate the stage.
	End Rem
	Method SetLightTexture(index:Int, texture:TMax2DLightTexture)
		If owner Then
			owner.CheckGroupMutable()
		End If

		Local previous:Long = processor.Revision()
		processor.SetLightTexture(index, texture)
		If previous <> processor.Revision() Then
			Invalidate()
		End If
	End Method
	Rem
	bbdoc: Sets a directional light slot for uniform illumination of the captured artwork.
	param: Zero-based light slot; it must be less than the configured light count.
	param: Horizontal component of the finite, nonzero vector toward the light.
	param: Vertical component of the finite, nonzero vector toward the light.
	param: Depth component of the finite, nonzero vector toward the light.
	param: Red component in the inclusive range 0..255.
	param: Green component in the inclusive range 0..255.
	param: Blue component in the inclusive range 0..255.
	param: Finite nonnegative colour multiplier; zero removes this contribution.
	about: Accepts a finite nonzero vector toward the light, colour components 0..255 and finite nonnegative intensity. Direction is retained, but this flattened stage has no surface normals and therefore applies uniform colour multiplication without attenuation. Use scene light nodes and individual materials for directional surface shading.
	End Rem
	Method SetDirectionalLight(index:Int, x:Float, y:Float, z:Float, red:Int = 255, green:Int = 255, blue:Int = 255, intensity:Float = 1)
		If owner Then
			owner.CheckGroupMutable()
		End If

		Local previous:Long = processor.Revision()
		processor.SetDirectionalLight(index, x, y, z, red, green, blue, intensity)
		If previous <> processor.Revision() Then
			Invalidate()
		End If
	End Method
	Rem
	bbdoc: Copies input bounds unchanged; accepts aliased rectangles.
	param: Finite logical input rectangle; may be the same object as output.
	param: Required reusable destination rectangle.
	End Rem
	Method ExpandBounds(input:TSceneRect, output:TSceneRect)
		CheckStageRect(input)
		If Not output Then
			Throw "Max2D SceneEffects: bounds destination is null"
		End If

		output.x = input.x; output.y = input.y; output.width = input.width; output.height = input.height
	End Method
	Rem
	bbdoc: Estimates one full-canvas output image, excluding driver overhead.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Estimated owned texture bytes for the complete replacement layout, excluding driver overhead.
	End Rem
	Method EstimateStorageBytes:Long(layout:TSceneStageLayout)
		If Not layout Then
			Throw "Max2D SceneEffects: layout is null"
		End If

		Return layout.EstimateImageBytes()
	End Method
	Rem
	bbdoc: Returns zero when pixel dimensions and format reuse existing storage.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	returns: Additional peak texture bytes required during preparation; zero when retained storage can be reused.
	End Rem
	Method EstimatePreparationBytes:Long(layout:TSceneStageLayout) Override
		If prepared And layout Then
			If prepared.PixelWidth() = layout.PixelWidth() And prepared.PixelHeight() = layout.PixelHeight() And prepared.PixelFormat() = layout.PixelFormat() Then
				Return 0
			End If
		End If

		Return EstimateStorageBytes(layout)
	End Method
	Rem
	bbdoc: Prepares output and validates lighting on the actual target, preserving caller state.
	param: Required layout describing logical canvas, pixel dimensions, scale and storage format.
	about: Stable pixel dimensions and format reuse textures. Logical origin and resolution changes update light mapping without replacing pixel storage.
	End Rem
	Method Prepare(layout:TSceneStageLayout)
		EstimateStorageBytes(layout)
		processor.Prepare(layout.PixelWidth(), layout.PixelHeight(), layout.PixelFormat())
		layout.CopyCanvasRect(canvas); prepared = layout
	End Method
	Rem
	bbdoc: Illuminates matching captured artwork into a distinct borrowed result, preserving source alpha and caller state.
	param: Source render image matching the prepared dimensions and format; must not alias owned output targets.
	returns: Borrowed processed output owned by this object; valid until a subsequent update, storage replacement or release.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		If Not prepared Then
			Throw "Max2D SceneEffects: prepare lighting before update"
		End If

		Return processor.Update(source, canvas.x, canvas.y, prepared.ResolutionScale())
	End Method
	Rem
	bbdoc: Releases lighting storage while retaining light settings; repeated calls are harmless.
	End Rem
	Method ReleaseResources()
		processor.Release(); prepared = Null
	End Method
End Type
