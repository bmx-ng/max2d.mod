Private
' Retained balanced hierarchy, sorted along X. Leaves keep original slot IDs;
' query results are restored to slot order before any rendering decisions.
Type TMax2DLightSelection
	Field order:Int[], bounds:Double[]
	Field capacity:Int, count:Int
	Field dirty:Int = True
	Method Sort(values:Int[], lo:Int, hi:Int, lights:Float[], directional:Int[])
		Local a:Int = lo, b:Int = hi, pivot:Int = values[(lo + hi) / 2]
		Local key:Double = pivot
		If lights Then
			key = 0
			If Not directional[pivot] Then
				key = lights[pivot * 8]
			End If
		End If

		While a <= b
			While Key(values[a], lights, directional) < key
				a :+ 1
			Wend

			While Key(values[b], lights, directional) > key
				b :- 1
			Wend

			If a <= b Then
				Local swap:Int = values[a]
				values[a] = values[b]
				values[b] = swap
				a :+ 1
				b :- 1
			End If
		Wend

		If lo < b Then
			Sort(values, lo, b, lights, directional)
		End If

		If a < hi Then
			Sort(values, a, hi, lights, directional)
		End If
	End Method

	Method Key:Double(slot:Int, lights:Float[], directional:Int[])
		If Not lights Then
			Return slot
		End If

		If directional[slot] Then
			Return 0
		End If

		Return lights[slot * 8]
	End Method

	Method Build(lights:Float[], directional:Int[])
		count = directional.Length
		Local needed:Int = 1
		While needed < count
			needed :* 2
		Wend

		If capacity <> needed Then
			capacity = needed
			order = New Int[capacity]
			bounds = New Double[capacity * 8]
		End If

		For Local i:Int = 0 Until count
			order[i] = i
		Next

		If count > 1 Then
			Sort(order, 0, count - 1, lights, directional)
		End If

		For Local i:Int = 0 Until capacity
			Local offset:Int = (capacity + i) * 4
			bounds[offset] = 1e300
			bounds[offset + 1] = 1e300
			bounds[offset + 2] = -1e300
			bounds[offset + 3] = -1e300
			If i >= count Then
				Continue
			End If

			Local slot:Int = order[i], j:Int = slot * 8
			If directional[slot] Then
				bounds[offset] = -1e300
				bounds[offset + 1] = -1e300
				bounds[offset + 2] = 1e300
				bounds[offset + 3] = 1e300
			Else
				Local radius:Double = lights[j + 2]
				bounds[offset] = Double(lights[j]) - radius
				bounds[offset + 1] = Double(lights[j + 1]) - radius
				bounds[offset + 2] = Double(lights[j]) + radius
				bounds[offset + 3] = Double(lights[j + 1]) + radius
			End If
		Next

		For Local node:Int = capacity - 1 To 1 Step -1
			Local offset:Int = node * 4, left:Int = node * 8, right:Int = left + 4
			bounds[offset] = Min(bounds[left], bounds[right])
			bounds[offset + 1] = Min(bounds[left + 1], bounds[right + 1])
			bounds[offset + 2] = Max(bounds[left + 2], bounds[right + 2])
			bounds[offset + 3] = Max(bounds[left + 3], bounds[right + 3])
		Next

		dirty = False
	End Method

	Method Query(node:Int, minX:Double, minY:Double, maxX:Double, maxY:Double, result:Int[], used:Int Var, stats:TMax2DLightingStats)
		stats.selectionNodeTests :+ 1
		Local offset:Int = node * 4
		If bounds[offset + 2] <= minX Or bounds[offset] >= maxX Or bounds[offset + 3] <= minY Or bounds[offset + 1] >= maxY Then
			Return
		End If

		If node >= capacity Then
			Local leaf:Int = node - capacity
			If leaf < count Then result[used] = order[leaf] * 8;used :+ 1

			Return
		End If

		Query(node * 2, minX, minY, maxX, maxY, result, used, stats)
		Query(node * 2 + 1, minX, minY, maxX, maxY, result, used, stats)
	End Method
End Type

Public
