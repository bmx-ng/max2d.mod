Rem
bbdoc: Retained simple polygon which blocks point and directional lights in lighting coordinates.
about: Geometry is copied. Either winding is accepted; points must form a simple polygon without repeated vertices, consecutive collinear edges or self-intersections. Concave outlines are triangulated once on geometry changes. Holes require separate geometry. Casting is independent of visible artwork and receiver materials. Polygons represent opaque walls extending perpendicular to the 2D plane; SetHeight enables finite-height shadows on the receiving plane at Z=0. The default height -1 represents an infinitely tall wall.
End Rem
Type TMax2DLightOccluder
	Internal
	Field vertices:Float[]
	Field triangles:Int[]
	Field revision:Long
	Field mask:Int = -1
	Field enabled:Int = True
	Field height:Float = -1
	Public
	Rem
	bbdoc: Creates a polygon from alternating X,Y coordinates in lighting space.
	param: Alternating finite X,Y coordinates of a simple polygon with at least three vertices; do not repeat the first vertex.
	returns: A new #TMax2DLightOccluder instance configured with the supplied settings.
	End Rem
	Function Create:TMax2DLightOccluder(points:Float[])
		Local result:TMax2DLightOccluder = New TMax2DLightOccluder
		result.SetPolygon(points)
		Return result
	End Function
	Rem
	bbdoc: Copies a finite simple polygon with at least three vertices, validating and triangulating before replacement.
	param: Alternating finite X,Y coordinates of a simple polygon with at least three vertices; do not repeat the first vertex.
	about: Identical coordinates preserve the revision and storage. Do not repeat the first vertex at the end.
	End Rem
	Method SetPolygon(points:Float[])
		If points.Length < 6 Or points.Length Mod 2 Then
			Throw "Max2D Lighting: invalid occluder polygon"
		End If

		For Local v:Float = EachIn points
			If IsNan(v) Or IsInf(v) Then
				Throw "Max2D Lighting: nonfinite occluder vertex"
			End If
		Next

		Local same:Int = vertices.Length = points.Length
		If same Then
			For Local i:Int = 0 Until points.Length
				If vertices[i] <> points[i] Then same = False;Exit
			Next
		End If

		If same Then
			Return
		End If

		For Local i:Int = 0 Until points.Length Step 2
			Local j:Int = (i + 2) Mod points.Length, k:Int = (i + 4) Mod points.Length
			If Cross(points, i, j, k) = 0 Then
				Throw "Max2D Lighting: consecutive collinear occluder edges"
			End If

			For Local other:Int = i + 2 Until points.Length Step 2
				If points[i] = points[other] And points[i + 1] = points[other + 1] Then
					Throw "Max2D Lighting: repeated occluder vertex"
				End If

				Local following:Int = (other + 2) Mod points.Length
				If other = j Or following = i Then
					Continue
				End If

				If Intersects(points, i, j, other, following) Then
					Throw "Max2D Lighting: self-intersecting occluder polygon"
				End If
			Next
		Next

		Local indices:Int[] = TriangulatePoly(points)
		If indices.Length <> (points.Length / 2 - 2) * 3 Then
			Throw "Max2D Lighting: occluder triangulation failed"
		End If

		vertices = points[..]
		triangles = indices
		revision :+ 1
		MarkCasterEdit()
	End Method
	Rem
	bbdoc: Copies another polygon through a finite affine transform into this polygon, reusing matching storage.
	param: Required distinct source polygon; its geometry is not modified.
	param: Coefficient of X in the transformed X coordinate.
	param: Coefficient of Y in the transformed X coordinate.
	param: Coefficient of X in the transformed Y coordinate.
	param: Coefficient of Y in the transformed Y coordinate.
	param: Horizontal affine translation.
	param: Vertical affine translation.
	about: Coefficients follow x'=xx*x+xy*y+tx, y'=yx*x+yy*y+ty. Source must be distinct. Intended for retained scene/ECS adapters. Singular transforms disable useful casting geometry; callers should disable the occluder while collapsed. Overflow is rejected before modifying vertices.
	End Rem
	Method SetTransformFrom(source:TMax2DLightOccluder, xx:Double, xy:Double, yx:Double, yy:Double, tx:Double, ty:Double)
		If Not source Or source = Self Or source.vertices.Length < 6 Then
			Throw "Max2D Lighting: invalid source occluder"
		End If

		For Local i:Int = 0 Until source.vertices.Length Step 2
			Local x:Float = Float(xx * source.vertices[i] + xy * source.vertices[i + 1] + tx)
			Local y:Float = Float(yx * source.vertices[i] + yy * source.vertices[i + 1] + ty)
			If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then
				Throw "Max2D Lighting: occluder transform overflow"
			End If
		Next

		Local changed:Int = vertices.Length <> source.vertices.Length
		If changed Then
			vertices = New Float[source.vertices.Length]
		End If

		For Local i:Int = 0 Until source.vertices.Length Step 2
			Local x:Float = Float(xx * source.vertices[i] + xy * source.vertices[i + 1] + tx)
			Local y:Float = Float(yx * source.vertices[i] + yy * source.vertices[i + 1] + ty)
			If vertices[i] <> x Or vertices[i + 1] <> y Then
				changed = True
			End If

			vertices[i] = x
			vertices[i + 1] = y
		Next

		If triangles <> source.triangles Then triangles = source.triangles;changed = True

		If changed Then
			revision :+ 1
			MarkCasterEdit()
		End If
	End Method
	Rem
	bbdoc: Sets height above the receiving plane in lighting units, or -1 for infinite height (default).
	param: Height in lighting/world units; -1 means infinite caster height.
	about: Zero blocks only the footprint. Directional shadows shorten with increasing positive elevation. At or below the horizon they retain unlimited reach. Point shadows shorten when the light is above the caster. Invalid values are rejected before mutation.
	End Rem
	Method SetHeight(value:Float)
		If IsNan(value) Or IsInf(value) Or (value < 0 And value <> -1) Then
			Throw "Max2D Lighting: invalid occluder height"
		End If

		If height = value Then
			Return
		End If

		height = value
		revision :+ 1
		MarkCasterEdit()
	End Method
	Rem
	bbdoc: Returns height above Z=0, or -1 for infinite height.
	returns: Height above Z=0, or -1 for infinite height.
	End Rem
	Method GetHeight:Float()
		Return height
	End Method
	Rem
	bbdoc: Sets the 32-bit caster mask, default all bits.
	param: 32-bit caster-selection mask; -1 enables all bits.
	about: A polygon blocks a light only when their caster masks intersect. This is independent of light receiver masks.
	End Rem
	Method SetCasterMask(value:Int)
		If mask = value Then
			Return
		End If

		mask = value
		revision :+ 1
		MarkCasterEdit()
	End Method
	Rem
	bbdoc: Returns the caster mask.
	returns: The caster mask.
	End Rem
	Method GetCasterMask:Int()
		Return mask
	End Method
	Rem
	bbdoc: Enables or disables casting without removing geometry.
	param: True to enable this light or caster, False to disable it without changing ownership.
	End Rem
	Method SetEnabled(value:Int)
		value = value <> 0
		If enabled = value Then
			Return
		End If

		enabled = value
		revision :+ 1
		MarkCasterEdit()
	End Method
	Rem
	bbdoc: Returns whether casting is enabled.
	returns: Whether casting is enabled.
	End Rem
	Method GetEnabled:Int()
		Return enabled
	End Method
	Rem
	bbdoc: Returns the geometry and casting configuration revision.
	returns: The geometry and casting configuration revision.
	End Rem
	Method Revision:Long()
		Return revision
	End Method

	Internal
	' Boundary-inclusive containment works for either winding and concave outlines.
	Method Contains:Int(x:Double, y:Double)
		Local inside:Int
		For Local i:Int = 0 Until vertices.Length Step 2
			Local j:Int = (i + 2) Mod vertices.Length
			Local ax:Double = vertices[i], ay:Double = vertices[i + 1], bx:Double = vertices[j], by:Double = vertices[j + 1]
			If (bx - ax) * (y - ay) - (by - ay) * (x - ax) = 0 And x >= Min(ax, bx) And x <= Max(ax, bx) And y >= Min(ay, by) And y <= Max(ay, by) Then
				Return True
			End If

			If (ay > y) <> (by > y) Then
				If x < ax + (y - ay) * (bx - ax) / (by - ay) Then
					inside = Not inside
				End If
			End If
		Next

		Return inside
	End Method

	Private
	Function Cross:Double(points:Float[], a:Int, b:Int, c:Int)
		Return (Double(points[b]) - points[a]) * (Double(points[c + 1]) - points[a + 1]) - (Double(points[b + 1]) - points[a + 1]) * (Double(points[c]) - points[a])
	End Function

	Function Intersects:Int(points:Float[], a:Int, b:Int, c:Int, d:Int)
		If Max(points[a], points[b]) < Min(points[c], points[d]) Or Max(points[c], points[d]) < Min(points[a], points[b]) Or Max(points[a + 1], points[b + 1]) < Min(points[c + 1], points[d + 1]) Or Max(points[c + 1], points[d + 1]) < Min(points[a + 1], points[b + 1]) Then
			Return False
		End If

		Local abC:Double = Cross(points, a, b, c), abD:Double = Cross(points, a, b, d)
		Local cdA:Double = Cross(points, c, d, a), cdB:Double = Cross(points, c, d, b)
		Return ((abC <= 0 And abD >= 0) Or (abC >= 0 And abD <= 0)) And ((cdA <= 0 And cdB >= 0) Or (cdA >= 0 And cdB <= 0))
	End Function

End Type

Private
' Retained mask and optional blur images per light; never per receiver.
Type TMax2DLightShadow
	Field boundsX:Float, boundsY:Float, boundsWidth:Float, boundsHeight:Float
	Field resolution:Int = 512, mask:Int = -1
	Field buffers:TMax2DEffectBuffers
	Field texture:TMax2DLightTexture
	Field valid:Int
	Field drawState:TMax2DState = New TMax2DState
	Field softness:Float
	Field filtered:Int
	Field blur:TMax2DScaledBlur = CreateScaledBlur(0)
	Field multiply:Int = CreateBlendMode(BLEND_ZERO, BLEND_SRC_COLOR, BLEND_OP_ADD, BLEND_ZERO, BLEND_ONE)
	Field mesh:TMesh2D = TMesh2D.Create(New Float[8], [0, 1, 2, 0, 2, 3])
	Method Release()
		If buffers Then
			buffers.Release()
		End If

		buffers = Null
		texture = Null
		valid = False
		filtered = False
	End Method

	Method Update:TMax2DLightTexture(x:Float, y:Float, radius:Float, occluders:TMax2DLightOccluder[], casterStates:TMax2DCasterState[], pattern:TMax2DLightTexture, directional:Int = False, dx:Float = 0, dy:Float = 0, dz:Float = 0, pointHeight:Float = 128, stats:TMax2DLightingStats = Null)
		If directional And (boundsWidth <= 0 Or boundsHeight <= 0) Then
			Throw "Max2D Lighting: configure directional shadow bounds before drawing"
		End If

		stats.shadowRequests :+ 1
		If valid And texture Then stats.shadowCacheHits :+ 1;Return texture

		If Not buffers Or (softness > 0 And Not filtered) Then
			Local candidate:TMax2DEffectBuffers = New TMax2DEffectBuffers
			Try
				If softness > 0 Then
					candidate.Prepare(resolution, resolution, 2, 0, PF_RGBA8888)
				Else
					candidate.Prepare(resolution, resolution, 1, -1, PF_RGBA8888)
				End If

				Local description:TMax2DLightTexture = TMax2DLightTexture.Create(candidate.Image(0))
				If buffers Then
					buffers.Release()
				End If

				texture = description
			Catch error:Object
				candidate.Release()
				Throw error
			End Try

			buffers = candidate
			filtered = softness > 0
		End If

		Local horizontal:Double = Sqr(Double(dx) * dx + Double(dy) * dy)
		Local radiusY:Double = radius
		If directional Then
			x = boundsX + boundsWidth / 2
			y = boundsY + boundsHeight / 2
			radius = boundsWidth / 2
			radiusY = Double(boundsHeight) / 2
			Local length:Double = Sqr(Double(dx) * dx + Double(dy) * dy)
			If length > 0 Then dx = Float(-dx / length);dy = Float(-dy / length)
		End If

		Local quad:Float[] = mesh.xy
		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		Local callerState:TMax2DState = canvas.state
		Local callerTarget:TRenderImage = canvas.renderImage
		Local scope:TMax2DStateScope
		' Owned targets normally leave the caller view untouched. Preserve it with a
		' full scope if a caller ever selects one of these borrowed images directly.
		Local aliases:Int = callerTarget = buffers.Image(0)
		If filtered Then
			aliases = aliases Or callerTarget = buffers.Image(1)
		End If

		If aliases Then
			scope = ScopedMax2DState()
		End If

		canvas.state = drawState
		Try
			SetRenderImage(buffers.Image(0))
			SetVirtualResolution(resolution, resolution)
			SetViewport(0, 0, resolution, resolution)
			SetCamera(Null)
			ResetCoordinates()
			SetAffineTransform(1, 0, 0, 1)
			SetOrigin(0, 0)
			SetHandle(0, 0)
			SetColor(255, 255, 255)
			SetAlpha(1)
			SetBlend(SOLIDBLEND)
			SetClsColor(255, 255, 255, 1)
			If pattern And softness = 0 Then
				SetClsColor(0, 0, 0, 0)
			End If

			Cls
			Local scale:Double = Double(resolution) / (2 * Double(radius)), scaleY:Double = Double(resolution) / (2 * radiusY)
			If pattern And softness = 0 Then
				DrawPattern(pattern, radius, scale)
			End If

			SetColor(0, 0, 0)
			SetAlpha(1)
			For Local iCaster:Int = 0 Until occluders.Length
				stats.occluderTests :+ 1
				If Not casterStates[iCaster].Affects(Self, directional, x, y, radius) Then
					Continue
				End If

				Local polygon:TMax2DLightOccluder = occluders[iCaster]
				Local points:Float[] = polygon.vertices
				If (Double(points[2]) - points[0]) * (Double(points[5]) - points[1]) = (Double(points[3]) - points[1]) * (Double(points[4]) - points[0]) Then
					Continue
				End If

				stats.casters :+ 1
				Local finitePoint:Int = Not directional And polygon.height >= 0 And polygon.height < pointHeight
				If directional Or finitePoint Or polygon.height = 0 Then
					' Fill the footprint, including the case where light arrives straight down.
					Local indices:Int[] = polygon.triangles
					For Local i:Int = 0 Until indices.Length Step 3
						For Local corner:Int = 0 Until 3
							Local vertex:Int = indices[i + corner] * 2
							quad[corner * 2] = Float((Double(points[vertex]) - x + radius) * scale)
							quad[corner * 2 + 1] = Float((Double(points[vertex + 1]) - y + radiusY) * scaleY)
						Next

						quad[6] = quad[0]
						quad[7] = quad[1]
						DrawMesh(mesh)
					Next
				End If
				' Every edge projects a convex quad. Their union also works for either winding.
				Local inside:Int
				If Not directional Then
					inside = polygon.Contains(x, y)
				End If

				For Local i:Int = 0 Until points.Length Step 2
					Local j:Int = (i + 2) Mod points.Length
					Local ax:Double = Double(points[i]) - x, ay:Double = Double(points[i + 1]) - y
					Local bx:Double = Double(points[j]) - x, by:Double = Double(points[j + 1]) - y
					If directional Then
						Local distance:Double = Abs(ax) + Abs(ay) + Abs(bx) + Abs(by) + 4 * (Double(radius) + radiusY)
						If polygon.height = 0 Then
							distance = 0
						Else If polygon.height > 0 And dz > 0 Then
							distance = Min(distance, Double(polygon.height) * horizontal / dz)
						End If

						quad[0] = Float((ax + radius) * scale)
						quad[1] = Float((ay + radiusY) * scaleY)
						quad[2] = Float((bx + radius) * scale)
						quad[3] = Float((by + radiusY) * scaleY)
						quad[4] = Float((bx + dx * distance + radius) * scale)
						quad[5] = Float((by + dy * distance + radiusY) * scaleY)
						quad[6] = Float((ax + dx * distance + radius) * scale)
						quad[7] = Float((ay + dy * distance + radiusY) * scaleY)
						DrawMesh(mesh)
						Continue
					End If

					Local al:Double = Sqr(ax * ax + ay * ay), bl:Double = Sqr(bx * bx + by * by)
					If al = 0 Or bl = 0 Then
						Continue
					End If

					Local distance:Double = Double(radius) * 3
					Local distanceA:Double = distance, distanceB:Double = distance
					If finitePoint Then
						Local ratio:Double = Double(polygon.height) / (Double(pointHeight) - polygon.height)
						distanceA = Min(distance, al * ratio)
						distanceB = Min(distance, bl * ratio)
					Else If polygon.height = 0 Then
						distanceA = 0
						distanceB = 0
					End If

					quad[0] = Float((ax + radius) * scale)
					quad[1] = Float((ay + radius) * scale)
					quad[2] = Float((bx + radius) * scale)
					quad[3] = Float((by + radius) * scale)
					quad[4] = Float((bx + bx / bl * distanceB + radius) * scale)
					quad[5] = Float((by + by / bl * distanceB + radius) * scale)
					quad[6] = Float((ax + ax / al * distanceA + radius) * scale)
					quad[7] = Float((ay + ay / al * distanceA + radius) * scale)
					DrawMesh(mesh)
				Next

				If inside And Not directional And Not finitePoint And polygon.height <> 0 Then
					DrawRect(0, 0, resolution, resolution)
				End If
			Next

			texture.SetImage(buffers.Image(0))
			If softness > 0 Then
				blur.SetRadius(softness)
				Local visibility:TRenderImage = buffers.ApplyBlur(buffers.Image(0), 1, blur)
				stats.filterPasses :+ 2
				If pattern Then
					SetRenderImage(buffers.Image(0))
					SetClsColor(0, 0, 0, 0)
					Cls
					SetColor(255, 255, 255)
					SetBlend(SOLIDBLEND)
					DrawPattern(pattern, radius, scale)
					SetBlend(multiply)
					Max2D.Core.DrawImage(visibility, 0, 0)
				Else
					texture.SetImage(visibility)
				End If
			End If

			If directional Then
				' White guard texels make clamped sampling outside the bounds unshadowed.
				Local output:TRenderImage = buffers.Image(0)
				If softness > 0 Then
					output = buffers.Image(1)
				End If

				SetRenderImage(output)
				SetColor(255, 255, 255)
				SetAlpha(1)
				SetBlend(SOLIDBLEND)
				DrawRect(0, 0, resolution, 1)
				DrawRect(0, resolution - 1, resolution, 1)
				DrawRect(0, 0, 1, resolution)
				DrawRect(resolution - 1, 0, 1, resolution)
			End If
		Finally
			canvas.state = callerState
			If scope Then
				scope.Close()
			Else If Not canvas.context.closed Then
				canvas.SetRenderImage(callerTarget)
			End If
		End Try

		If directional Then
			texture.SetPlacement(boundsWidth, boundsHeight, x, y)
		Else
			texture.SetPlacement(radius * 2, radius * 2)
		End If

		texture.Invalidate()
		valid = True
		stats.shadowRebuilds :+ 1
		Return texture
	End Method

	Method DrawPattern(pattern:TMax2DLightTexture, radius:Float, scale:Double)
		Local c:Double = Cos(pattern.rotation), s:Double = Sin(pattern.rotation)
		SetAffineTransform(Float(c * pattern.width / pattern.image.width * scale), Float(-s * pattern.height / pattern.image.height * scale), Float(s * pattern.width / pattern.image.width * scale), Float(c * pattern.height / pattern.image.height * scale))
		Local px:Float = Float((radius + pattern.offsetX - c * pattern.width / 2 + s * pattern.height / 2) * scale)
		Local py:Float = Float((radius + pattern.offsetY - s * pattern.width / 2 - c * pattern.height / 2) * scale)
		SetOrigin(px, py)
		Local samplingFrame:Int = pattern.frame
		Local sampling:TImage = pattern.image.SamplingImage(samplingFrame)
		' Project the full rectangle: image handles are drawing metadata, not pattern placement.
		' DrawImage offsets are outside the affine basis, so adding the handle cannot cancel it here.
		TMax2DGraphics.Current().DrawImageRegion(sampling, 0, 0, sampling.width, sampling.height, 0, 0, sampling.width, sampling.height, 0, 0, samplingFrame)
		SetOrigin(0, 0)
		SetAffineTransform(1, 0, 0, 1)
	End Method

End Type

Public
