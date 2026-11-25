' Shared artwork and retained lighting for small luminous colonies and shallow caustics.
Type TDiveEcology
	Field body:TImage, emission:TImage, caustic:TImage, halo:TImage
	Field halos:TSpriteNode[4], bloom:TSceneBloomStage[4]
	Field illuminated:Float[4], rocks:TDiveRock[]
	Field colony:TCompositeNode[4], material:TMax2DLightingMaterial[4], glow:TPointLightNode[4]
	Field cx:Float[4], cy:Float[4], response:Float[4]
	Field water:TPointLightNode[3], pattern:TMax2DLightTexture[3]
	Method Init(world:TLayerNode, lighting:TSceneLighting, rocks:TDiveRock[], floors:TDiveRock[])
		Self.rocks = rocks
		body = ColonyImage(False)
		emission = ColonyImage(True)
		caustic = CausticImage()
		halo = ColonyHaloImage()
		For Local i:Int = 0 Until 4
			Local rock:TDiveRock = floors[(i + 1) * (floors.Length - 1) / 5]
			cx[i] = rock.x
			cy[i] = rock.y - rock.radius * 0.94

			material[i] = TMax2DLightingMaterial.Create()
			material[i].SetReceiverMask(1)
			material[i].SetEmissionMap(emission)
			material[i].SetEmission(65, 235, 210, 0.8)

			colony[i] = TCompositeNode.Create()
			colony[i].SetPosition(cx[i], cy[i])
			colony[i].SetScale(0.6, 0.6)
			colony[i].SetCaptureRect(TSceneRect.Create(-80, -90, 160, 112))

			bloom[i] = TSceneBloomStage.Create(0.22, 10, 1.25)
			colony[i].SetStages([TSceneEffectStage(bloom[i])])

			halos[i] = TSpriteNode.Create(halo)
			halos[i].SetTint(35 + i * 6, 230 - i * 8, 235)
			colony[i].AddChild(halos[i])
			colony[i].AddChild(TLitSpriteNode.Create(body, lighting, material[i]))
			world.AddChild(colony[i])

			glow[i] = TPointLightNode.Create(135)
			glow[i].SetPosition(cx[i], cy[i] - 28)
			glow[i].SetColor(45, 195, 178)
			glow[i].SetHeight(65)
			glow[i].SetIntensity(0.2)
			world.AddChild(glow[i])
		Next

		For Local i:Int = 0 Until 3
			water[i] = TPointLightNode.Create(650)
			water[i].SetPosition(Float(260 + i * 380), -1190)
			water[i].SetColor(135, 220, 205)
			water[i].SetIntensity(Float(0.45 - i * 0.06))
			water[i].SetHeight(400)
			water[i].SetReceiverMask(2)
			water[i].SetFalloff(0.65)
			pattern[i] = TMax2DLightTexture.Create(caustic)
			water[i].SetTexture(pattern[i])
			world.AddChild(water[i])
		Next
	End Method

	Method Advance(dt:Float, time:Float, x:Float, y:Float, speed:Float, sonar:TDiveAtmosphere, lamps:Int = False, heading:Float = 0)
		For Local i:Int = 0 Until 4
			Local distance:Float = Sqr((x - cx[i]) ^ 2 + (y - cy[i]) ^ 2)
			response[i] = Max(0:Float, response[i] - dt * 0.7)
			If distance < 180 And speed > 20 Then
				response[i] = Max(response[i], Float((1 - distance / 180) * Min(1:Float, speed / 80)))
			End If

			If sonar.sonar >= 0 Then
				Local arrival:Float = Sqr((sonar.sx - cx[i]) ^ 2 + (sonar.sy - cy[i]) ^ 2) / 430
				If Abs(sonar.sonar - arrival) < 0.09 Then
					response[i] = 1
				End If
			End If

			Local exposure:Float
			If lamps Then
				exposure = BeamExposure(x, y, heading, cx[i], cy[i] - 24)
			End If

			illuminated[i] :+ (exposure - illuminated[i]) * Min(1:Float, dt * 5)
			Local pulse:Float = 1.35 + 0.3 * Sin(time * 47 + i * 83) + response[i] * 1.5 + illuminated[i] * 3
			material[i].SetEmission(45 + i * 8, 235 - i * 9, 230 + i * 8, pulse)
			halos[i].SetAlpha(Float(Min(1:Float, 0.65 + response[i] * 0.2 + illuminated[i] * 0.35)))
			bloom[i].SetIntensity(1.25 + illuminated[i] * 2)
			glow[i].SetIntensity(0.12 + pulse * 0.18)
		Next

		For Local i:Int = 0 Until 3
			pattern[i].SetPlacement(Float(650 + 35 * Sin(time * 11 + i * 60)), Float(320 + 20 * Cos(time * 13 + i * 90)), Float(Sin(time * 17 + i * 70) * 60), Float(Cos(time * 14 + i * 55) * 12), Float(Sin(time * 9 + i * 80) * 3))
		Next
	End Method

	Method BeamExposure:Float(x:Float, y:Float, heading:Float, tx:Float, ty:Float)
		Local fx:Float = Cos(heading), fy:Float = Sin(heading)
		Local ox:Float = x + fx * 44, oy:Float = y + fy * 44, dx:Float = tx - ox, dy:Float = ty - oy
		Local along:Float = dx * fx + dy * fy, across:Float = Abs(dx * fy - dy * fx)
		If along <= 0 Or along >= 480 Then
			Return 0
		End If

		Local width:Float = (0.04 + along / 480 * 0.92) * 150
		If across >= width Then
			Return 0
		End If

		Local length2:Float = dx * dx + dy * dy
		For Local rock:TDiveRock = EachIn rocks
			Local t:Float = Max(0:Float, Min(1:Float, ((rock.x - ox) * dx + (rock.y - oy) * dy) / length2))
			If (ox + dx * t - rock.x) ^ 2 + (oy + dy * t - rock.y) ^ 2 < (rock.radius * 0.88) ^ 2 Then
				Return 0
			End If
		Next

		Return Float((1 - across / width) * Min(1:Float, (480 - along) / 180))
	End Method

	Method Reset()
		For Local i:Int = 0 Until response.Length
			response[i] = 0
			illuminated[i] = 0
		Next
	End Method

	Method Check(sonar:TDiveAtmosphere)
		Reset()
		sonar.sonar = -1
		Advance(0.1, 0, cx[0], cy[0] - 30, 100, sonar)
		If response[0] < 0.5 Then
			Throw "Colony did not respond to nearby movement"
		End If

		Advance(2, 0, -10000, -10000, 0, sonar)
		If response[0] <> 0 Then
			Throw "Colony response did not fade"
		End If

		sonar.sx = cx[0] - 430
		sonar.sy = cy[0]
		sonar.sonar = 0.5
		Advance(0.01, 0, -10000, -10000, 0, sonar)
		If response[0] <> 0 Then
			Throw "Colony reacted before the sonar arrived"
		End If

		sonar.sonar = 1
		Advance(0.01, 0, -10000, -10000, 0, sonar)
		If response[0] <> 1 Then
			Throw "Colony did not respond to the sonar wave"
		End If

		For Local light:TPointLightNode = EachIn water
			If light.GetReceiverMask() <> 2 Then
				Throw "Caustic light lost its receiver selection"
			End If
		Next

		sonar.sonar = -1
		Reset()
		If BeamExposure(cx[0] - 160, cy[0] - 24, 0, cx[0], cy[0] - 24) <= 0 Then
			Throw "Headlamp missed a colony inside its beam"
		End If

		If BeamExposure(cx[0] - 160, cy[0] - 24, 180, cx[0], cy[0] - 24) <> 0 Then
			Throw "Colony reacted behind the headlamp"
		End If

		Advance(0.2, 0, cx[0] - 160, cy[0] - 24, 0, sonar, True, 0)
		If illuminated[0] <= 0 Then
			Throw "Colony headlamp response did not rise"
		End If

		Advance(1, 0, cx[0] - 160, cy[0] - 24, 0, sonar, False, 0)
		If illuminated[0] <> 0 Then
			Throw "Colony stayed bright with the lamp off"
		End If

		Reset()
	End Method

	Method Close()
		body.ReleaseFrames()
		emission.ReleaseFrames()
		caustic.ReleaseFrames()
		halo.ReleaseFrames()
	End Method
End Type

Function ColonyImage:TImage(emission:Int)
	Local target:TRenderImage = CreateRenderImage(128, 80, FILTEREDIMAGE)
	Using
  Local state:TMax2DStateScope = ScopedMax2DState()
 Do
		SetRenderImage(target)
		SetClsColor(0, 0, 0, 0)
		Cls
		SetBlend(ALPHABLEND)
		SetAlpha(1)
		For Local i:Int = 0 Until 15
			Local x:Float = 9 + i * 7.5, y:Float = 41 + Sin(i * 137) * 19, r:Float = 2.3 + (i Mod 3) * 0.8
			If Not emission Then
				SetColor(70, 115, 112)
				SetLineWidth(1.5)
				DrawLine(x, 74, x - 2, y + 3)
				SetColor(150, 195, 184)
				DrawOval(x - r, y - r, r * 2, r * 1.5)
				SetColor(215, 250, 235)
			Else
				SetColor(255, 255, 255)
			End If

			DrawOval(x - r * 0.7, y - r, r * 1.4, 2.2)
			DrawOval(x - 1, y + 4, 2, 2)
			DrawOval(x, y + 9, 1.5, 1.5)
		Next
	End Using

	Local image:TImage = LoadImage(ReadRenderImage(target), FILTEREDIMAGE)
	SetImageHandle(image, 64, 74)
	target.ReleaseFrames()
	Return image
End Function

Function CausticImage:TImage()
	Local pix:TPixmap = CreatePixmap(256, 256, PF_RGBA8888)
	For Local y:Int = 0 Until 256
		For Local x:Int = 0 Until 256
			Local u:Float = x * 360.0 / 256, v:Float = y * 360.0 / 256
			Local a:Float = Sin(u * 4 + Sin(v * 3) * 35) + Sin(v * 5 + Cos(u * 3) * 40)
			Local b:Float = Sin(u * 3 - v * 2 + 20) + Cos(v * 4 + Sin(u * 2) * 50)
			Local brightness:Float = Min(1:Float, Exp(-a * a * 100) * 0.8 + Exp(-b * b * 120) * 0.55)
			Local edge:Float = Min(1:Float, Min(Min(x, 255 - x), Min(y, 255 - y)) / 30.0)
			' A soft projection boundary and downward attenuation keep the deep cave dark.
			Local fade:Float = edge * edge * (1 - y / 256.0)
			pix.WritePixel(x, y, (Channel(fade * 255) Shl 24) | (Channel(brightness * 255) * $010101))
		Next
	Next

	Return LoadImage(pix, FILTEREDIMAGE)
End Function

' Broad translucent coverage stays visible even when the luminous caps are tiny.
' Shared by all colonies; only tint and opacity change during animation.
Function ColonyHaloImage:TImage()
	Local pix:TPixmap = CreatePixmap(160, 112, PF_RGBA8888)
	For Local y:Int = 0 Until 112
		For Local x:Int = 0 Until 160
			Local coverage:Float
			For Local i:Int = 0 Until 15
				Local cx:Float = 25 + i * 7.5, cy:Float = 57 + Sin(i * 137) * 19
				Local d2:Float = (x - cx) ^ 2 + (y - cy) ^ 2
				coverage :+ Float(0.48 * Exp(-d2 / 28) + 0.10 * Exp(-d2 / 150))
			Next

			pix.WritePixel(x, y, (Channel(Min(0.8:Float, coverage) * 255) Shl 24) | $ffffff)
		Next
	Next

	Local image:TImage = LoadImage(pix, FILTEREDIMAGE)
	SetImageHandle(image, 80, 90)
	Return image
End Function
