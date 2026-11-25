' Seeded cave geometry, independent of rendering and the global random stream.
Type TDiveMap
	Const SPACING:Int = 130
	Field seed:Int, state:Long, cols:Int, rows:Int, width:Int, bottom:Int
	Field roomX:Float[], roomY:Float[], habitatX:Float[], habitatY:Float[], habitatKind:Int[], habitatCount:Int[]
	Field samples:Float[] = New Float[32768], sampleCount:Int
	Field rocks:TDiveRock[], floors:TDiveRock[], px:Float[], py:Float[]
	Method Random:Int(limit:Int)
		state = (state * 48271) Mod 2147483647
		Return Int(state Mod limit)
	End Method

	Method Sample(x:Float, y:Float, radius:Float)
		If (sampleCount + 1) * 3 > samples.Length Then
			samples = samples[..samples.Length * 2]
		End If

		Local i:Int = sampleCount * 3
		samples[i] = x
		samples[i + 1] = y
		samples[i + 2] = radius
		sampleCount :+ 1
	End Method

	Method Generate(value:Int)
		seed = Max(1, value)
		state = seed
		sampleCount = 0

		' A growing tree of chambers gives each seed its own branching structure.
		Local across:Int = 5 + Random(3), down:Int = 4 + Random(2), roomCount:Int = across * down
		cols = across * 8 + 5
		rows = down * 8 + 5
		width = 200 + (cols - 1) * SPACING
		bottom = 100 + (rows - 1) * SPACING
		roomX = New Float[roomCount]
		roomY = New Float[roomCount]
		For Local room:Int = 0 Until roomCount
			roomX[room] = 100 + (4 + (room Mod across) * 8) * SPACING + Random(481) - 240
			roomY[room] = 100 + (4 + (room / across) * 8) * SPACING + Random(481) - 240
		Next

		roomX[0] = 620
		roomY[0] = 620
		Local visited:Int[roomCount], active:Int[roomCount], distance:Int[roomCount], degree:Int[roomCount]
		Local links:Int[roomCount * 8], activeCount:Int = 1, branching:Int = 25 + Random(65)
		visited[0] = True
		active[0] = 0
		For Local y:Int = -1400 To 620 Step 40
			Sample(620, y, 120)
		Next

		While activeCount > 0
			Local pick:Int = activeCount - 1
			If Random(100) < branching Then
				pick = Random(activeCount)
			End If

			Local room:Int = active[pick], rx:Int = room Mod across, ry:Int = room / across
			Local choices:Int[8], directions:Int[8], count:Int
			For Local direction:Int = 0 Until 8
				Local nx:Int = rx, ny:Int = ry
				Select direction
					Case 0
						nx :- 1
					Case 1
						nx :+ 1
					Case 2
						ny :- 1
					Case 3
						ny :+ 1
					Case 4
						nx :- 1
						ny :- 1
					Case 5
						nx :+ 1
						ny :+ 1
					Case 6
						nx :- 1
						ny :+ 1
					Case 7
						nx :+ 1
						ny :- 1
				End Select

				If nx < 0 Or nx >= across Or ny < 0 Or ny >= down Then
					Continue
				End If

				Local neighbour:Int = ny * across + nx
				If visited[neighbour] Then
					Continue
				End If

				choices[count] = neighbour
				directions[count] = direction
				count :+ 1
			Next

			If count = 0 Then
				activeCount :- 1
				active[pick] = active[activeCount]
				Continue
			End If

			Local choice:Int = Random(count), nextRoom:Int = choices[choice], direction:Int = directions[choice]
			links[room * 8 + direction] = True
			links[nextRoom * 8 + (direction ~ 1)] = True
			degree[room] :+ 1
			degree[nextRoom] :+ 1
			JoinRooms(room, nextRoom)
			visited[nextRoom] = True
			distance[nextRoom] = distance[room] + 1
			active[activeCount] = nextRoom
			activeCount :+ 1
		Wend
		' Sparse extra connections make alternate routes without erasing the walls.
		Local loopCount:Int = 1 + Random(3)
		For Local loop:Int = 0 Until loopCount
			Local room:Int = Random(roomCount), direction:Int = Random(2) * 2 + 1
			Local rx:Int = room Mod across, ry:Int = room / across, nx:Int = rx, ny:Int = ry
			If direction = 1 Then nx :+ 1 Else ny :+ 1

			If nx >= across Or ny >= down Or links[room * 8 + direction] Then
				Continue
			End If

			JoinRooms(room, ny * across + nx)
		Next
		' Rounded pockets blend into the variable-width connecting routes.
		For Local room:Int = 0 Until roomCount
			Local chamberRadius:Float = 125 + Random(86)
			If Random(5) = 0 Then
				chamberRadius = 240 + Random(81)
			End If

			Sample(roomX[room], roomY[room], chamberRadius)
		Next

		Local objectives:Int = 3 + Random(3), selected:Int[roomCount]
		px = New Float[objectives]
		py = New Float[objectives]
		For Local objective:Int = 0 Until objectives
			Local best:Int = -1, bestScore:Int = -100000
			For Local room:Int = across Until roomCount
				If selected[room] Then
					Continue
				End If

				Local score:Int = distance[room] * 3 + Random(8)
				If degree[room] = 1 Then
					score :+ 8
				End If

				For Local other:Int = 0 Until roomCount
					If Not selected[other] Then
						Continue
					End If

					Local separation:Int = Abs(room Mod across - other Mod across) + Abs(room / across - other / across)
					score :- Max(0, 5 - separation) * 12
				Next

				If score > bestScore Then best = room;bestScore = score
			Next

			selected[best] = True
			px[objective] = roomX[best]
			py[objective] = roomY[best]
		Next
		' Overlapping, irregular boundary rocks follow the continuous carved volume.
		Local storage:TDiveRock[cols * rows], anchors:TDiveRock[cols * rows], count:Int, anchorCount:Int
		For Local y:Int = 0 Until rows
			For Local x:Int = 0 Until cols
				Local rock:TDiveRock = New TDiveRock
				rock.x = 100 + x * SPACING + Random(21) - 10
				rock.y = 100 + y * SPACING + Random(21) - 10
				rock.radius = 100 + Random(16)
				Local gap:Float = 100000
				For Local i:Int = 0 Until sampleCount * 3 Step 3
					gap = Min(gap, Float(Sqr((rock.x - samples[i]) ^ 2 + (rock.y - samples[i + 1]) ^ 2)) - samples[i + 2] - rock.radius)
				Next

				If gap < 0 Or (gap > 190 And y > 0) Then
					Continue
				End If

				storage[count] = rock
				count :+ 1
			Next
		Next

		rocks = storage[..count]
		For Local rock:TDiveRock = EachIn rocks
			If Clear(rock.x, rock.y - rock.radius - 100) Then anchors[anchorCount] = rock;anchorCount :+ 1
		Next

		floors = anchors[..anchorCount]
		' Habitats occupy a spread of clear chambers, independent of probe placement.
		Local surfaceGroups:Int = 6, habitats:Int = roomCount / 2 + surfaceGroups
		habitatX = New Float[habitats]
		habitatY = New Float[habitats]
		habitatKind = New Int[habitats]
		habitatCount = New Int[habitats]
		For Local i:Int = 0 Until surfaceGroups
			habitatX[i] = 400 + i * 340 + Random(161)
			habitatY[i] = -1160 + Random(291)
			habitatKind[i] = i Mod 4
			If habitatKind[i] = 1 Or habitatKind[i] = 2 Then
				habitatCount[i] = 2 + Random(2)
			Else
				habitatCount[i] = 20 + Random(9)
			End If
		Next

		For Local i:Int = surfaceGroups Until habitats
			Local room:Int = 1 + (i - surfaceGroups) * 2 + Random(2)
			room = Min(room, roomCount - 1)
			habitatX[i] = roomX[room]
			habitatY[i] = roomY[room]
			habitatKind[i] = Random(4)
			Select habitatKind[i]
				Case 1, 2
					habitatCount[i] = 2 + Random(2)
				Default
					habitatCount[i] = 8 + Random(15)
			End Select
		Next
	End Method

	Method JoinRooms(a:Int, b:Int)
		Local ax:Float = roomX[a], ay:Float = roomY[a], bx:Float = roomX[b], by:Float = roomY[b]
		Local length:Float = Sqr((bx - ax) ^ 2 + (by - ay) ^ 2), bend:Float = Random(361) - 180
		Local startWidth:Float = 85 + Random(36), endWidth:Float = 85 + Random(36)
		Local steps:Int = Int(Ceil(length / 35))
		For Local sampleIndex:Int = 0 To steps
			Local t:Float = Float(sampleIndex) / steps, sway:Float = Sin(t * 180) * bend
			Local x:Float = ax + (bx - ax) * t - (by - ay) / length * sway, y:Float = ay + (by - ay) * t + (bx - ax) / length * sway
			Local radius:Float = startWidth + (endWidth - startWidth) * t + Sin(t * 360) * 15
			Sample(x, y, Max(80:Float, radius))
		Next
	End Method

	Method Clear:Int(x:Float, y:Float)
		If x < 85 Or x > width - 85 Or y > bottom - 85 Then
			Return False
		End If

		For Local rock:TDiveRock = EachIn rocks
			If (x - rock.x) ^ 2 + (y - rock.y) ^ 2 < (rock.radius + 60) ^ 2 Then
				Return False
			End If
		Next

		Return True
	End Method

	Method LinkClear:Int(ax:Float, ay:Float, bx:Float, by:Float)
		For Local sample:Int = 0 To 16
			If Not Clear(ax + (bx - ax) * sample / 16, ay + (by - ay) * sample / 16) Then
				Return False
			End If
		Next

		Return True
	End Method

	Method Check()
		' Each tree edge joins reachable chamber centres. Check the actual carved
		' centreline samples against collision geometry, including diagonal bends.
		If Not LinkClear(620, -1390, 620, 100) Then
			Throw "Blocked surface approach, seed " + seed
		End If

		For Local i:Int = 0 Until sampleCount * 3 Step 3
			If Not Clear(samples[i], samples[i + 1]) Then
				Throw "Blocked cave route, seed " + seed
			End If
		Next

		For Local i:Int = 0 Until px.Length
			If Not Clear(px[i], py[i]) Then
				Throw "Blocked probe, seed " + seed
			End If
		Next

		For Local i:Int = 0 Until habitatX.Length
			If Not Clear(habitatX[i], habitatY[i]) Then
				Throw "Blocked fish habitat, seed " + seed
			End If
		Next

		If floors.Length < 12 Then
			Throw "Insufficient habitat anchors"
		End If
	End Method

	Function CheckSeeds()
		For Local sample:Int = 1 To 100
			Local seed:Int = sample * 7919
			If sample = 1 Then
				seed = 7
			End If

			If sample = 2 Then
				seed = 337897
			End If

			Local a:TDiveMap = New TDiveMap, b:TDiveMap = New TDiveMap
			a.Generate(seed)
			b.Generate(seed)
			a.Check()
			If a.rocks.Length <> b.rocks.Length Or a.px.Length <> b.px.Length Then
				Throw "Seed changed cave dimensions"
			End If

			For Local i:Int = 0 Until a.px.Length
				If a.px[i] <> b.px[i] Or a.py[i] <> b.py[i] Then
					Throw "Seed changed objective positions"
				End If
			Next

			For Local i:Int = 0 Until a.habitatX.Length
				If a.habitatX[i] <> b.habitatX[i] Or a.habitatY[i] <> b.habitatY[i] Or a.habitatKind[i] <> b.habitatKind[i] Or a.habitatCount[i] <> b.habitatCount[i] Then
					Throw "Seed changed fish habitats"
				End If
			Next

			For Local i:Int = 0 Until a.rocks.Length
				If a.rocks[i].x <> b.rocks[i].x Or a.rocks[i].y <> b.rocks[i].y Or a.rocks[i].radius <> b.rocks[i].radius Then
					Throw "Seed changed cave geometry"
				End If
			Next
		Next
	End Function
End Type
