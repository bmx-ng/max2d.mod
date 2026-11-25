' One retained analysis entry per lighting processor. Compare values because the
' public mesh arrays can be edited directly, without a revision notification.
Private
Type TMax2DLightingMeshCache
	Field xy:Float[], uv:Float[], indices:Int[]
	Field coordinates:Int = -1, indexCount:Int = -1, eligible:Int
	Field shapeKnown:Int, shapeDisjoint:Int
	Field shapeBounds:Float[]
	Field separatingEdges:Byte[]
	Field valid:Int
	Field mappings:Double[]
	Field membership:Int[]
	Field runCount:Int
	Field starts:Int[]
	Field meshes:TMesh2D[]
	Field basis:Double[6]

	Method Accepts:Int(mesh:TMesh2D)
		If mesh.indices.Length < 6 Or mesh.indices.Length > 512 * 3 Then
			Return False
		End If

		Local same:Int = valid And coordinates = mesh.xy.Length And indexCount = mesh.indices.Length
		Local topologySame:Int = same
		If same Then
			For Local i:Int = 0 Until coordinates
				If xy[i] <> mesh.xy[i] Then
					same = False
				End If

				If uv[i] <> mesh.uv[i] Then same = False;topologySame = False
			Next

			For Local i:Int = 0 Until indexCount
				If indices[i] <> mesh.indices[i] Then same = False;topologySame = False;Exit
			Next
		End If

		If same Then
			Return eligible
		End If

		valid = False
		shapeKnown = False
		coordinates = mesh.xy.Length
		indexCount = mesh.indices.Length
		If xy.Length < coordinates Then xy = New Float[coordinates];uv = New Float[coordinates]

		If indices.Length < indexCount Then
			indices = New Int[indexCount]
		End If

		For Local i:Int = 0 Until coordinates
			xy[i] = mesh.xy[i]
			uv[i] = mesh.uv[i]
		Next

		For Local i:Int = 0 Until indexCount
			indices[i] = mesh.indices[i]
		Next

		For Local section:TMesh2D = EachIn meshes
			If section Then section.xy = xy;section.uv = uv
		Next

		If mappings.Length < indexCount * 2 Then
			mappings = New Double[indexCount * 2]
		End If

		If membership.Length < indexCount / 3 Then
			membership = New Int[indexCount / 3]
		End If

		eligible = Analyze(topologySame)
		For Local section:Int = 0 Until runCount
			For Local triangle:Int = starts[section] / 3 Until starts[section + 1] / 3
				membership[triangle] = section
			Next
		Next

		valid = True
		Return eligible
	End Method

	Method Analyze:Int(knownTopology:Int = False)
		' Bound cold quadratic overlap analysis. Larger meshes retain the old path.
		If indexCount < 6 Or indexCount > 512 * 3 Then
			Return False
		End If

		Local triangles:Int = indexCount / 3
		If starts.Length < triangles + 1 Then
			starts = New Int[triangles + 1]
		End If

		runCount = 0
		Local invertible:Int
		For Local t:Int = 0 Until indexCount Step 3
			Local a:Int = indices[t] * 2, b:Int = indices[t + 1] * 2, c:Int = indices[t + 2] * 2
			Local u:Double = uv[a], v:Double = uv[a + 1]
			Local du:Double = Double(uv[b]) - u, dv:Double = Double(uv[b + 1]) - v
			Local eu:Double = Double(uv[c]) - u, ev:Double = Double(uv[c + 1]) - v
			Local det:Double = du * ev - dv * eu
			If Abs(det) < 0.000000000001 Then
				Throw "Max2D Lighting: mesh triangle has singular UVs"
			End If

			Local dx:Double = Double(xy[b]) - xy[a], dy:Double = Double(xy[b + 1]) - xy[a + 1]
			Local ex:Double = Double(xy[c]) - xy[a], ey:Double = Double(xy[c + 1]) - xy[a + 1]
			Local ax:Double = (dx * ev - ex * dv) / det, ay:Double = (ex * du - dx * eu) / det
			Local bx:Double = (dy * ev - ey * dv) / det, by:Double = (ey * du - dy * eu) / det
			Local px:Double = Double(xy[a]) - ax * u - ay * v, py:Double = Double(xy[a + 1]) - bx * u - by * v
			Local offset:Int = t * 2
			mappings[offset] = ax
			mappings[offset + 1] = ay
			mappings[offset + 2] = bx
			mappings[offset + 3] = by
			mappings[offset + 4] = px
			mappings[offset + 5] = py
			Local join:Int = t > 0 And invertible And ax * by - ay * bx <> 0
			' Exact agreement preserves each triangle's normal-map basis.
			If ax <> basis[0] Or ay <> basis[1] Or bx <> basis[2] Or by <> basis[3] Or px <> basis[4] Or py <> basis[5] Then
				join = False
			End If

			Local knownDisjoint:Int
			If join And knownTopology Then
				knownDisjoint = membership[t / 3] = membership[starts[runCount - 1] / 3]
			End If
			' With unchanged UV/index data, any subrange of an old section remains
			' disjoint in UV space. Current exact basis agreement transfers that proof
			' to geometry, even after deformation. New merges still need overlap checks.
			If join And Not knownDisjoint Then
				For Local previous:Int = starts[runCount - 1] Until t Step 3
					If Not Separated(previous, t) And Not Separated(t, previous) Then join = False;Exit
				Next
			End If

			If Not join Then
				starts[runCount] = t
				runCount :+ 1
				basis[0] = ax
				basis[1] = ay
				basis[2] = bx
				basis[3] = by
				basis[4] = px
				basis[5] = py
				invertible = ax * by - ay * bx <> 0
			End If
		Next

		starts[runCount] = indexCount
		If runCount = triangles Then
			Return False
		End If

		If runCount = 1 Then
			Return True
		End If
		' Retain snapshot-backed sections, never the caller's mesh or arrays. Index
		' buffers are reused when section sizes survive edits; warm analysis allocates none.
		If meshes.Length < runCount Then
			meshes = meshes[..runCount]
		End If

		For Local r:Int = 0 Until runCount
			If Not meshes[r] Then
				meshes[r] = New TMesh2D
			End If

			Local section:TMesh2D = meshes[r], size:Int = starts[r + 1] - starts[r]
			section.xy = xy
			section.uv = uv
			If section.indices.Length <> size Then
				section.indices = New Int[size]
			End If

			For Local i:Int = 0 Until size
				section.indices[i] = indices[starts[r] + i]
			Next
		Next

		Return True
	End Method

	Method DisjointGeometry:Int()
		If shapeKnown Then
			Return shapeDisjoint
		End If

		shapeKnown = True
		shapeDisjoint = False
		If shapeBounds.Length < indexCount / 3 * 4 Then
			shapeBounds = New Float[indexCount / 3 * 4]
		End If

		' One byte per unordered pair. A hint names an edge to try first; every
		' use tests the current positions, even after topology or winding changes.
		Local triangles:Int = indexCount / 3
		Local pairs:Int = triangles * (triangles - 1) / 2
		If separatingEdges.Length < pairs Then separatingEdges = New Byte[pairs]

		For Local t:Int = 0 Until indexCount Step 3
			Local a:Int = indices[t] * 2, b:Int = indices[t + 1] * 2, c:Int = indices[t + 2] * 2
			If (Double(xy[b]) - xy[a]) * (Double(xy[c + 1]) - xy[a + 1]) = (Double(xy[b + 1]) - xy[a + 1]) * (Double(xy[c]) - xy[a]) Then
				Return False
			End If

			Local offset:Int = t / 3 * 4
			shapeBounds[offset] = Min(xy[a], Min(xy[b], xy[c]))
			shapeBounds[offset + 1] = Min(xy[a + 1], Min(xy[b + 1], xy[c + 1]))
			shapeBounds[offset + 2] = Max(xy[a], Max(xy[b], xy[c]))
			shapeBounds[offset + 3] = Max(xy[a + 1], Max(xy[b + 1], xy[c + 1]))
			Local pairBase:Int = (t / 3) * (t / 3 - 1) / 2
			For Local previous:Int = 0 Until t Step 3
				Local other:Int = previous / 3 * 4
				If shapeBounds[offset + 2] <= shapeBounds[other] Or shapeBounds[other + 2] <= shapeBounds[offset] Or shapeBounds[offset + 3] <= shapeBounds[other + 1] Or shapeBounds[other + 3] <= shapeBounds[offset + 1] Then
					Continue
				End If

				Local pair:Int = pairBase + previous / 3
				Local hint:Int = separatingEdges[pair]
				If hint Then
					If hint <= 3 Then
						If EdgeSeparates(previous, t, hint - 1, xy) Then Continue
					Else
						If EdgeSeparates(t, previous, hint - 4, xy) Then Continue
					End If
				End If
				Local edge:Int = FindSeparatingEdge(previous, t, xy)
				If edge Then
					separatingEdges[pair] = edge
					Continue
				End If
				edge = FindSeparatingEdge(t, previous, xy)
				If edge Then
					separatingEdges[pair] = edge + 3
					Continue
				End If
				If Not SeparatedProjections(previous, t, xy) And Not SeparatedProjections(t, previous, xy) Then
					Return False
				End If
			Next
		Next

		shapeDisjoint = True
		Return True
	End Method

	Method FindSeparatingEdge:Int(a:Int, b:Int, points:Float[])
		For Local edge:Int = 0 Until 3
			If EdgeSeparates(a, b, edge, points) Then Return edge + 1
		Next
		Return 0
	End Method

	Method EdgeSeparates:Int(a:Int, b:Int, edge:Int, points:Float[])
		Local p:Int = indices[a + edge] * 2, q:Int = indices[a + (edge + 1) Mod 3] * 2
		Local r:Int = indices[a + (edge + 2) Mod 3] * 2
		Local ex:Double = Double(points[q]) - points[p], ey:Double = Double(points[q + 1]) - points[p + 1]
		Local side:Double = ex * (Double(points[r + 1]) - points[p + 1]) - ey * (Double(points[r]) - points[p])
		If side = 0 Then Return False
		For Local corner:Int = 0 Until 3
			Local k:Int = indices[b + corner] * 2
			Local cross:Double = ex * (Double(points[k + 1]) - points[p + 1]) - ey * (Double(points[k]) - points[p])
			If (side > 0 And cross > 0) Or (side < 0 And cross < 0) Then Return False
		Next
		Return True
	End Method

	' Separating axes in UV space: a shared boundary is allowed; overlapping
	' interiors are not, because regrouping passes would change painter order.
	Method Separated:Int(a:Int, b:Int)
		Return FindSeparatingEdge(a, b, uv) Or SeparatedProjections(a, b, uv)
	End Method

	Method SeparatedProjections:Int(a:Int, b:Int, points:Float[])
		For Local edge:Int = 0 Until 3
			Local p:Int = indices[a + edge] * 2, q:Int = indices[a + (edge + 1) Mod 3] * 2
			Local nx:Double = Double(points[q + 1]) - points[p + 1], ny:Double = Double(points[p]) - points[q]
			Local amin:Double, amax:Double, bmin:Double, bmax:Double
			For Local corner:Int = 0 Until 3
				Local ia:Int = indices[a + corner] * 2, ib:Int = indices[b + corner] * 2
				Local av:Double = nx * points[ia] + ny * points[ia + 1], bv:Double = nx * points[ib] + ny * points[ib + 1]
				If corner = 0 Then
					amin = av
					amax = av
					bmin = bv
					bmax = bv
				Else
					amin = Min(amin, av)
					amax = Max(amax, av)
					bmin = Min(bmin, bv)
					bmax = Max(bmax, bv)
				End If
			Next

			If amax <= bmin Or bmax <= amin Then
				Return True
			End If
		Next

		Return False
	End Method
End Type

Public
