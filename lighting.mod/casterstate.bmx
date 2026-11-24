Private
' Previous caster state is retained per lighting environment. Both old and new
' influence must be checked: moving away must remove the previous shadow too.
Type TMax2DCasterState
	Field revision:Long
	Field enabled:Int, mask:Int
	Field minX:Double, minY:Double, maxX:Double, maxY:Double
	Method Capture(caster:TMax2DLightOccluder)
		revision = caster.Revision()
		enabled = caster.enabled
		mask = caster.mask
		minX = caster.vertices[0]
		maxX = minX
		minY = caster.vertices[1]
		maxY = minY
		For Local i:Int = 2 Until caster.vertices.Length Step 2
			minX = Min(minX, Double(caster.vertices[i]))
			maxX = Max(maxX, Double(caster.vertices[i]))
			minY = Min(minY, Double(caster.vertices[i + 1]))
			maxY = Max(maxY, Double(caster.vertices[i + 1]))
		Next
	End Method

	Method Affects:Int(shadow:TMax2DLightShadow, directional:Int, x:Float, y:Float, radius:Float)
		If Not enabled Or Not (mask & shadow.mask) Then
			Return False
		End If

		If directional Then
			Return True
		End If
		' Include a conservative raster/filter fringe around the complete square map.
		Local reach:Double = Double(radius) * (1.0 + (4.0 * shadow.softness + 4.0) / shadow.resolution)
		Return Not (maxX < Double(x) - reach Or minX > Double(x) + reach Or maxY < Double(y) - reach Or minY > Double(y) + reach)
	End Method
End Type

Public
