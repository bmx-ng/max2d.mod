' A small fixed-size school. Neighbour reads use the previous simulation state;
' acceleration is stored separately before integrating, so update order is neutral.
Type TDiveSchool
	Const CAPACITY:Int = 28
	Field worldWidth:Int = 3000, worldBottom:Int = 1100
	Field count:Int = 28, species:Int, homeX:Float = 620, homeY:Float = -680
	Field cruise:Float = 48, bodyScale:Float = 1, roam:Float = 120
	Field fish:TLitSpriteNode[CAPACITY]
	Field x:Float[CAPACITY], y:Float[CAPACITY], vx:Float[CAPACITY], vy:Float[CAPACITY]
	Field ax:Float[CAPACITY], ay:Float[CAPACITY], alarm:Float[CAPACITY]
	Field colour:TImage, normal:TImage
	Method Init(world:TLayerNode, lighting:TSceneLighting, kind:Int = 0, number:Int = 28, anchorX:Float = 620, anchorY:Float = -680)
		species = kind
		count = Max(1, Min(CAPACITY, number))
		homeX = anchorX
		homeY = anchorY
		Select species
			Case 1
				cruise = 30
				bodyScale = 1.15
				roam = 65
			Case 2
				cruise = 38
				bodyScale = 1.05
				roam = 80
			Case 3
				cruise = 65
				bodyScale = 0.9
				roam = 110
		End Select

		colour = FishImage(False, species)
		normal = FishImage(True, species)
		Local material:TMax2DLightingMaterial = TMax2DLightingMaterial.Create()
		material.SetReceiverMask(3)
		material.SetNormalMap(normal)
		material.SetNormalStrength(0.85)
		material.SetSpecular(2.5, 48)
		If species = 1 Then
			material.SetSpecular(1.2, 24)
		End If

		If species = 2 Then
			material.SetSpecular(1.8, 36)
		End If

		If species = 3 Then
			material.SetSpecular(3, 64)
		End If

		For Local i:Int = 0 Until COUNT
			fish[i] = TLitSpriteNode.Create(colour, lighting, material)
			If species = 0 Then
				fish[i].SetTint(155 + i Mod 4 * 17, 205 + i Mod 3 * 12, 235)
			End If

			world.AddChild(fish[i])
		Next

		Reset()
	End Method

	Method Reset()
		For Local i:Int = 0 Until COUNT
			x[i] = homeX + Cos(i * 137.5) * (20 + i * 3)
			y[i] = homeY + Sin(i * 137.5) * (18 + i * 2)
			vx[i] = cruise * 0.6
			vy[i] = 0
			alarm[i] = 0
			fish[i].SetPosition(x[i], y[i])
		Next
	End Method

	Method Advance(dt:Float, time:Float, subX:Float, subY:Float, rocks:TDiveRock[])
		If dt <= 0 Then
			Return
		End If
		' Small substeps keep avoidance and cohesion stable at different frame rates.
		Local steps:Int = Max(1, Int(Ceil(dt * 60))), stepTime:Float = dt / steps
		For Local substep:Int = 0 Until steps
			Local targetX:Float = homeX + Sin(time * 9) * roam, targetY:Float = homeY + Sin(time * 13) * roam * 0.625
			For Local i:Int = 0 Until COUNT
				Local cx:Float, cy:Float, avx:Float, avy:Float, sepX:Float, sepY:Float, neighbours:Int
				For Local j:Int = 0 Until COUNT
					If i = j Then
						Continue
					End If

					Local dx:Float = x[i] - x[j], dy:Float = y[i] - y[j], d2:Float = dx * dx + dy * dy
					If d2 < 150 * 150 Then
						cx :+ x[j]
						cy :+ y[j]
						avx :+ vx[j]
						avy :+ vy[j]
						neighbours :+ 1
						If d2 < 32 * 32 Then
							sepX :+ dx / Max(16:Float, d2)
							sepY :+ dy / Max(16:Float, d2)
						End If
					End If
				Next

				ax[i] = (targetX - x[i]) * 0.12
				ay[i] = (targetY - y[i]) * 0.12
				If neighbours Then
					ax[i] :+ (cx / neighbours - x[i]) * 0.22 + (avx / neighbours - vx[i]) * 0.8 + sepX * 850
					ay[i] :+ (cy / neighbours - y[i]) * 0.22 + (avy / neighbours - vy[i]) * 0.8 + sepY * 850
				End If

				Local dx:Float = x[i] - subX, dy:Float = y[i] - subY, d:Float = Sqr(dx * dx + dy * dy)
				alarm[i] = Max(0:Float, alarm[i] - stepTime * 0.35)
				If d < 210 Then
					alarm[i] = 1
					If d < 1 Then dx = Cos(i * 137.5);dy = Sin(i * 137.5);d = 1

					Local flee:Float = 260 * (1 - d / 210)
					ax[i] :+ dx / d * flee
					ay[i] :+ dy / d * flee
				End If

				For Local rock:TDiveRock = EachIn rocks
					dx = x[i] + vx[i] * 0.5 - rock.x
					dy = y[i] + vy[i] * 0.5 - rock.y
					d = Sqr(dx * dx + dy * dy)
					Local clearance:Float = rock.radius + 70
					If d < clearance And d > 0.01 Then
						ax[i] :+ dx / d * (clearance - d) * 5
						ay[i] :+ dy / d * (clearance - d) * 5
					End If
				Next

				If y[i] < -1290 Then
					ay[i] :+ (-1290 - y[i]) * 3
				End If

				If y[i] > worldBottom - 120 Then
					ay[i] :- (y[i] - worldBottom + 120) * 3
				End If

				If x[i] < 180 Then
					ax[i] :+ (180 - x[i]) * 3
				End If

				If x[i] > worldWidth - 120 Then
					ax[i] :- (x[i] - worldWidth + 120) * 3
				End If
			Next

			For Local i:Int = 0 Until COUNT
				vx[i] :+ ax[i] * stepTime
				vy[i] :+ ay[i] * stepTime
				Local speed:Float = Sqr(vx[i] * vx[i] + vy[i] * vy[i]), limit:Float = cruise + alarm[i] * 110
				If speed > limit Then vx[i] :* limit / speed;vy[i] :* limit / speed

				x[i] :+ vx[i] * stepTime
				y[i] :+ vy[i] * stepTime
				' Resolve any penetration after steering, including direct flee paths.
				For Local rock:TDiveRock = EachIn rocks
					Local dx:Float = x[i] - rock.x, dy:Float = y[i] - rock.y, d:Float = Sqr(dx * dx + dy * dy), radius:Float = rock.radius + 12
					If d < radius Then
						If d < 0.01 Then dx = 1;dy = 0;d = 1

						x[i] = rock.x + dx / d * radius
						y[i] = rock.y + dy / d * radius
						Local into:Float = (vx[i] * dx + vy[i] * dy) / d
						If into < 0 Then vx[i] :- into * dx / d;vy[i] :- into * dy / d
					End If
				Next

				x[i] = Max(150:Float, Min(Float(worldWidth - 80), x[i]))
				y[i] = Max(-1320:Float, Min(Float(worldBottom - 80), y[i]))
			Next
		Next

		For Local i:Int = 0 Until COUNT
			Local angle:Float = ATan2(vy[i], vx[i]), size:Float = (0.42 + (i Mod 5) * 0.052) * bodyScale
			' A slight roll changes the reflective flank as each fish swims.
			Local roll:Float = 0.75 + 0.25 * Sin(time * (150 + alarm[i] * 160) + i * 71)
			fish[i].SetPosition(x[i], y[i])
			If vx[i] < 0 Then
				fish[i].SetScale(-size, size * roll)
				fish[i].SetRotation(angle - 180)
			Else
				fish[i].SetScale(size, size * roll)
				fish[i].SetRotation(angle)
			End If
		Next
	End Method

	Method Spread:Float()
		Local total:Float
		For Local i:Int = 0 Until COUNT
			total :+ Sqr((x[i] - homeX) ^ 2 + (y[i] - homeY) ^ 2)
		Next

		Return total / COUNT
	End Method

	Method CheckBehaviour(rocks:TDiveRock[])
		Reset()
		Local initial:Float = Spread()
		For Local frame:Int = 0 Until 120
			Advance(1.0 / 60, 0, homeX, homeY, rocks)
		Next

		Local scattered:Float = Spread()
		If scattered < initial + 40 Then
			Throw "School did not scatter from submarine"
		End If

		For Local frame:Int = 0 Until 1800
			Advance(1.0 / 60, 0, -5000, -5000, rocks)
		Next

		If Spread() >= scattered * 0.8 Then
			Throw "School did not regroup after danger passed"
		End If

		For Local i:Int = 0 Until COUNT
			If y[i] < -1320 Or y[i] > worldBottom - 80 Then
				Throw "Fish escaped the water bounds"
			End If
		Next
		' Deliberate rock overlap must be resolved even during a panic response.
		x[0] = rocks[0].x
		y[0] = rocks[0].y - rocks[0].radius + 1
		Advance(1.0 / 60, 0, -5000, -5000, rocks)
		If (x[0] - rocks[0].x) ^ 2 + (y[0] - rocks[0].y) ^ 2 < (rocks[0].radius + 11) ^ 2 Then
			Throw "Fish remained inside a rock"
		End If

		Reset()
	End Method

	Method Close()
		colour.ReleaseFrames()
		normal.ReleaseFrames()
	End Method
End Type

Function FishImage:TImage(normal:Int = False, species:Int = 0)
	Local pix:TPixmap = CreatePixmap(48, 24, PF_RGBA8888)
	For Local y:Int = 0 Until 24
		For Local x:Int = 0 Until 48
			Local width:Float = 17, height:Float = 8
			Select species
				Case 1
					width = 11
					height = 10
				Case 2
					width = 13
					height = 8.5
				Case 3
					width = 19
					height = 4.5
			End Select

			Local nx:Float = (x - 27) / width, ny:Float = (y - 11.5) / height, d:Float = nx * nx + ny * ny
			Local alpha:Int = Channel((1 - d) * 1800)
			Local tailEnd:Float = 29 - width
			If x >= tailEnd - 10 And x <= tailEnd And Abs(y - 11.5) < (tailEnd - x) * 0.65 Then
				alpha = 255
			End If

			If species = 1 And x >= 21 And x <= 29 And Abs(y - 11.5) < 11 - Abs(x - 25) * 0.35 Then
				alpha = 255
			End If

			If species = 2 And x >= 18 And x <= 30 And y < 8 And y > 3 + Abs(x - 24) * 0.4 Then
				alpha = 220
			End If

			Local r:Int, g:Int, b:Int
			If normal Then
				Local sx:Float = nx * 0.45, sy:Float = ny * 0.75
				' Fine scale facets give narrow highlights under a moving lamp.
				sy :+ Float(Sin(x * 95 + y * 70)) * 0.13
				Local z:Float = Sqr(Max(0.05:Float, 1 - sx * sx - sy * sy))
				r = Channel(127.5 + sx * 127.5)
				g = Channel(127.5 + sy * 127.5)
				b = Channel(127.5 + z * 127.5)
			Else
				Local flank:Float = Max(0:Float, 1 - Abs(ny)), scales:Float = Sin(x * 95 + y * 70) * 12
				r = Channel(65 + flank * 145 + scales)
				g = Channel(130 + flank * 105 + scales)
				b = Channel(170 + flank * 80)
				Select species
					Case 1
						r = Channel(200 + flank * 50)
						g = Channel(105 + flank * 90)
						b = Channel(20 + flank * 55)
						If x >= 24 And x <= 27 Then r = 45;g = 58;b = 65
					Case 2
						r = Channel(185 + flank * 65)
						g = Channel(45 + flank * 65)
						b = Channel(65 + flank * 55)
						If (x >= 20 And x <= 22) Or (x >= 30 And x <= 32) Then r = 225;g = 240;b = 220
					Case 3
						r = Channel(80 + flank * 90)
						g = Channel(40 + flank * 70)
						b = Channel(150 + flank * 100)
						If Abs(y - 11.5) < 1.3 Then r = 65;g = 225;b = 240
				End Select

				If (x - Int(27 + width * 0.6)) ^ 2 + (y - 9) ^ 2 < 3 Then r = 8;g = 20;b = 28
			End If

			pix.WritePixel(x, y, (alpha Shl 24) | (r Shl 16) | (g Shl 8) | b)
		Next
	Next

	Local image:TImage = LoadImage(pix, FILTEREDIMAGE)
	SetImageHandle(image, 24, 12)
	Return image
End Function
