' Decorative, lit vegetation. Shared textures are built once; deforming kelp
' reuses scene nodes, and all roots stay fixed to the cave rocks.
Type TDiveFlora
	Field art:TImage[4], normal:TImage[4], material:TMax2DLightingMaterial[4]
	Field grass:TDivePlantMesh[], grassSize:Float[]
	Field kelp:TDivePlantMesh[], segments:Int[], rootX:Float[], rootY:Float[], kelpSize:Float[]
	Method Init(world:TLayerNode, lighting:TSceneLighting, map:TDiveMap)
		Local rocks:TDiveRock[] = map.floors
		For Local kind:Int = 0 Until 4
			art[kind] = FloraImage(kind)
			normal[kind] = FloraNormal(art[kind])
			material[kind] = TMax2DLightingMaterial.Create()
			material[kind].SetReceiverMask(3)
			material[kind].SetNormalMap(normal[kind])
			material[kind].SetNormalStrength(0.45)
			material[kind].SetSpecular(0.35, 18)
		Next

		Local patches:Int = rocks.Length, clusters:Int = Max(1, rocks.Length / 2)
		grass = New TDivePlantMesh[patches * 6]
		grassSize = New Float[grass.Length]
		kelp = New TDivePlantMesh[clusters * 3]
		segments = New Int[kelp.Length]
		rootX = New Float[kelp.Length]
		rootY = New Float[kelp.Length]
		kelpSize = New Float[kelp.Length]
		For Local patch:Int = 0 Until patches
			Local rock:TDiveRock = rocks[patch * (rocks.Length - 1) / (patches - 1)]
			Local baseX:Float = rock.x, baseY:Float = rock.y - rock.radius * 0.9 + 8
			For Local blade:Int = 0 Until 6
				Local index:Int = patch * 6 + blade
				grass[index] = TDivePlantMesh.Create(art[0], lighting, material[0], 1, False)
				grassSize[index] = 0.32 + 0.28 * (0.5 + 0.5 * Sin(index * 137))
				grass[index].node.SetPosition(Float(baseX + (blade - 2.5) * 7), Float(baseY + Abs(blade - 2.5) * 2))
				grass[index].node.SetTint(65 + patch Mod 3 * 18, 155 + blade * 10, 100 + patch Mod 4 * 12)
				grass[index].node.SetScale(grassSize[index], grassSize[index])
				world.AddChild(grass[index].node)
			Next

			Local kind:Int = 2 + patch Mod 2
			Local coral:TLitSpriteNode = TLitSpriteNode.Create(art[kind], lighting, material[kind])
			coral.SetPosition(baseX + 62, baseY + 12)
			coral.SetScale(Float(0.34 + 0.08 * (patch Mod 3)), Float(0.34 + 0.08 * (patch Mod 3)))
			Select patch Mod 3
				Case 0
					coral.SetTint(255, 112, 135)
				Case 1
					coral.SetTint(242, 175, 75)
				Case 2
					coral.SetTint(164, 118, 242)
			End Select

			world.AddChild(coral)
		Next

		For Local plant:Int = 0 Until segments.Length
			Local cluster:Int = plant / 3, stem:Int = plant Mod 3
			Local rock:TDiveRock = rocks[cluster * (rocks.Length - 1) / (clusters - 1)]
			Local offset:Float = -55 + (stem - 1) * 22
			rootX[plant] = rock.x + offset
			rootY[plant] = rock.y - Sqr(rock.radius * rock.radius - offset * offset) + 16
			kelpSize[plant] = 0.55 + (cluster Mod 3) * 0.1 + stem * 0.035
			segments[plant] = 7 + (cluster Mod 3) * 3 + stem
			If stem = 1 Then
				segments[plant] = 16
			End If

			Local room:Float = 900
			For Local ceiling:TDiveRock = EachIn map.rocks
				If ceiling = rock Then
					Continue
				End If

				Local dx:Float = rootX[plant] - ceiling.x, radius:Float = ceiling.radius + 45
				If Abs(dx) >= radius Then
					Continue
				End If

				Local underside:Float = ceiling.y + Sqr(radius * radius - dx * dx)
				If underside < rootY[plant] - 35 Then
					room = Min(room, rootY[plant] - underside - 25)
				End If
			Next

			Local height:Float = 60 + (segments[plant] - 1) * 48
			kelpSize[plant] = Min(kelpSize[plant], Max(0.12:Float, room / height))
			kelp[plant] = TDivePlantMesh.Create(art[1], lighting, material[1], segments[plant], True)
			Local node:TLitMeshNode = kelp[plant].node
			node.SetPosition(rootX[plant], rootY[plant])
			node.SetTint(103 + plant Mod 3 * 18, 190, 65 + plant Mod 2 * 23)
			node.SetScale(kelpSize[plant] * 0.55, kelpSize[plant])
			If cluster Mod 2 = 0 Then
				world.AddChild(node)
			Else
				node.SetAlpha(0.88)
			End If
		Next

		Advance(0, 0, 0, True)
	End Method

	Method AddForeground(world:TLayerNode)
		For Local plant:Int = 0 Until segments.Length
			If (plant / 3) Mod 2 = 0 Then
				Continue
			End If

			world.AddChild(kelp[plant].node)
		Next
	End Method

	Method Advance(time:Float, viewX:Float, viewY:Float, allPlants:Int = False)
		For Local i:Int = 0 Until grass.Length
			Local gx:Float, gy:Float
			grass[i].node.GetPosition(gx, gy)
			If allPlants Or (Abs(gx - viewX) < 1000 And Abs(gy - viewY) < 800) Then
				grass[i].Advance(time, Float(i * 39), 0.13)
			End If
		Next

		For Local plant:Int = 0 Until segments.Length
			If allPlants Or (Abs(rootX[plant] - viewX) < 1000 And Abs(rootY[plant] - viewY) < 1400) Then
				kelp[plant].Advance(time, Float((plant / 3) * 71 + (plant Mod 3) * 13), 0.19)
			End If
		Next
	End Method

	Method CheckMotion()
		For Local plant:TDivePlantMesh = EachIn grass
			plant.CheckMotion()
		Next

		For Local plant:TDivePlantMesh = EachIn kelp
			plant.CheckMotion()
		Next
	End Method

	Method Close()
		For Local i:Int = 0 Until art.Length
			art[i].ReleaseFrames()
			normal[i].ReleaseFrames()
		Next
	End Method
End Type

' One retained mesh per plant. Repeated kelp artwork shares a continuous bend
' function, including the overlapping leaf tips at each texture boundary.
Type TDivePlantMesh
	Field node:TLitMeshNode, mesh:TMesh2D, rest:Float[], height:Float
	Function Create:TDivePlantMesh(image:TImage, lighting:TSceneLighting, material:TMax2DLightingMaterial, count:Int, isKelp:Int)
		Local plant:TDivePlantMesh = New TDivePlantMesh
		Local rows:Int = 6, cols:Int = 2, vertices:Int = (rows + 1) * (cols + 1)
		Local xy:Float[count * vertices * 2], uv:Float[xy.Length], indices:Int[count * rows * cols * 6]
		Local cursor:Int, top:Float = 0
		If isKelp Then
			top = 48
		End If

		plant.height = 108 - top + (count - 1) * 48
		For Local part:Int = 0 Until count
			For Local row:Int = 0 To rows
				Local sourceY:Float = 108 - (108 - top) * row / rows
				For Local col:Int = 0 To cols
					Local v:Int = part * vertices + row * (cols + 1) + col, i:Int = v * 2
					xy[i] = col * 96.0 / cols - 48
					xy[i + 1] = sourceY - 108 - part * 48
					uv[i] = Float(col) / cols
					uv[i + 1] = sourceY / 112
					If row < rows And col < cols Then
						indices[cursor] = v
						indices[cursor + 1] = v + 1
						indices[cursor + 2] = v + cols + 2
						indices[cursor + 3] = v
						indices[cursor + 4] = v + cols + 2
						indices[cursor + 5] = v + cols + 1
						cursor :+ 6
					End If
				Next
			Next
		Next

		plant.rest = xy[..]
		plant.mesh = TMesh2D.Create(xy, indices, uv)
		plant.node = TLitMeshNode.Create(plant.mesh, image, lighting, material)
		Return plant
	End Function

	Method Advance(time:Float, phase:Float, strength:Float)
		For Local i:Int = 0 Until rest.Length Step 2
			Local rise:Float = -rest[i + 1], fraction:Float = rise / height
			Local bend:Float = rise * fraction * strength * (Sin(time * 32 + phase - fraction * 100) + 0.3 * Sin(time * 19 + phase))
			Local flutter:Float = Sin(time * 63 + phase + rise * 1.8) * 0.10 * fraction
			mesh.xy[i] = rest[i] + bend
			mesh.xy[i + 1] = rest[i + 1] + Abs(rest[i]) * flutter
		Next

		node.InvalidateContent()
	End Method

	Method CheckMotion()
		' Sample differing current phases: the root must stay fixed and no triangle
		' may collapse or turn inside out as its lighting basis changes.
		For Local sample:Int = 0 Until 32
			Advance(sample * 0.7, Float(sample * 47), 0.19)
			For Local i:Int = 0 Until rest.Length Step 2
				If rest[i + 1] = 0 And (mesh.xy[i] <> rest[i] Or mesh.xy[i + 1] <> 0) Then
					Throw "Vegetation root moved"
				End If
			Next

			For Local i:Int = 0 Until mesh.indices.Length Step 3
				Local a:Int = mesh.indices[i] * 2, b:Int = mesh.indices[i + 1] * 2, c:Int = mesh.indices[i + 2] * 2
				Local area:Float = (mesh.xy[b] - mesh.xy[a]) * (mesh.xy[c + 1] - mesh.xy[a + 1]) - (mesh.xy[b + 1] - mesh.xy[a + 1]) * (mesh.xy[c] - mesh.xy[a])
				If Not area < -0.01 Then
					Throw "Vegetation mesh folded or collapsed"
				End If
			Next
		Next
	End Method

End Type

Function FloraImage:TImage(kind:Int)
	Local target:TRenderImage = CreateRenderImage(96, 112, FILTEREDIMAGE)
	Using
  Local state:TMax2DStateScope = ScopedMax2DState()
 Do
		SetRenderImage(target)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetBlend(ALPHABLEND)
		SetAlpha(1)
		Select kind
			Case 0
				' A tapered blade curves away from its anchored base.
				SetColor(190, 220, 170)
				DrawPoly([46.0:Float, 108.0, 43.0, 82.0, 44.0, 58.0, 54.0, 31.0, 58.0, 8.0, 59.0, 33.0, 51.0, 61.0, 51.0, 84.0, 50.0, 108.0])
				SetColor(230, 244, 205)
				SetLineWidth(1)
				DrawLine(48, 106, 47, 61)
				DrawLine(47, 61, 56, 31)
			Case 1
				SetColor(184, 205, 154)
				SetLineWidth(3)
				DrawLine(48, 108, 48, 58)
				For Local leaf:Int = 0 Until 4
					Local yy:Float = 96 - leaf * 10, side:Float = 1
					If leaf Mod 2 = 0 Then
						side = -1
					End If

					SetColor(190 + leaf * 12, 220 + leaf * 5, 170 + leaf * 10)
					DrawPoly([48.0:Float, yy, 48 + side * 15, yy - 2, 48 + side * 29, yy - 18, 48 + side * 12, yy - 14, 48.0, yy - 6])
					SetColor(225, 240, 193)
					SetLineWidth(1)
					DrawLine(48, yy - 3, 48 + side * 24, yy - 15)
				Next
			Case 2
				' Branching fan coral, with rounded polyps at its tips.
				For Local branch:Int = 0 Until 9
					Local tipX:Float = 9 + branch * 9.5, tipY:Float = 12 + Abs(branch - 4) * 5
					Local midX:Float = 48 + (tipX - 48) * 0.55, midY:Float = 65 + Abs(branch - 4) * 2
					SetColor(172, 183, 180)
					SetLineWidth(5)
					DrawLine(48, 108, midX, midY)
					SetColor(220, 230, 219)
					SetLineWidth(3)
					DrawLine(midX, midY, tipX, tipY)
					DrawLine(midX, midY, tipX - 7, tipY + 24)
					DrawLine(midX, midY, tipX + 7, tipY + 33)
					SetColor(255, 247, 231)
					DrawOval(tipX - 3, tipY - 3, 6, 6)
					DrawOval(tipX - 9, tipY + 22, 4, 4)
				Next
			Case 3
				' Cluster of rounded tube coral with darker mouths and pale rims.
				For Local tube:Int = 0 Until 7
					Local xx:Float = 17 + tube * 9, top:Float = 35 + Sin(tube * 83) * 20
					SetColor(180, 195, 185)
					DrawOval(xx - 7, top, 14, 110 - top)
					SetColor(243, 239, 223)
					DrawOval(xx - 7, top, 14, 9)
					SetColor(70, 90, 86)
					DrawOval(xx - 4, top + 2, 8, 4)
					SetColor(225, 232, 207)
					SetLineWidth(1)
					DrawLine(xx - 3, top + 12, xx - 3, 98)
				Next
		End Select
	End Using

	Local result:TImage = LoadImage(ReadRenderImage(target), FILTEREDIMAGE)
	SetImageHandle(result, 48, 108)
	target.ReleaseFrames()
	Return result
End Function

Function FloraNormal:TImage(colour:TImage)
	Local source:TPixmap = LockImage(colour, 0, True, False), pix:TPixmap = CreatePixmap(96, 112, PF_RGBA8888)
	For Local y:Int = 0 Until 112
		For Local x:Int = 0 Until 96
			Local alpha:Int = (source.ReadPixel(x, y) Shr 24) & 255
			Local nx:Float = Sin(x * 17 + y * 3) * 0.3, ny:Float = -0.25
			Local z:Float = Sqr(1 - nx * nx - ny * ny)
			pix.WritePixel(x, y, (alpha Shl 24) | (Channel(127.5 + nx * 127.5) Shl 16) | (Channel(127.5 + ny * 127.5) Shl 8) | Channel(127.5 + z * 127.5))
		Next
	Next

	UnlockImage(colour)
	Local result:TImage = LoadImage(pix, FILTEREDIMAGE)
	SetImageHandle(result, 48, 108)
	Return result
End Function
