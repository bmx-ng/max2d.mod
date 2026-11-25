Type TDive
	Field profiling:Int, fishNs:ULong
	Field scene:TScene, world:TLayerNode, hud:TLayerNode, camera:TCamera2D
	Field lighting:TSceneLighting, head:TPointLightNode, fill:TPointLightNode, sun:TDirectionalLightNode
	Field pattern:TMax2DLightTexture, ship:TLitSpriteNode, scatter:TSpriteNode, atmosphere:TDiveAtmosphere
	Field ecology:TDiveEcology
	Field sonar:TDiveSonar
	Field flora:TDiveFlora
	Field physics:TDivePhysics
	Field schools:TDiveSchool[]
	Field ocean:TDiveOcean, veil:TSpriteNode
	Field steering:TDiveControl, throttle:TDiveControl, ping:TDiveButton, newDive:TDiveButton, lightButton:TDiveButton, replayButton:TDiveButton
	Field menuButton:TDiveMenuButton, menuPanel:TDiveMenuPanel, menuOpen:Int
	Field chart:TDiveChart
	Field map:TDiveMap
	Field rocks:TDiveRock[], probes:TDiveProbe[], beacons:TPointLightNode[]
	Field px:Float[], py:Float[]
	Field rockArt:TImage, normals:TImage, backArt:TImage, entranceArt:TImage, backNormal:TImage, hull:TImage, beam:TImage, haze:TImage
	Field font:TImageFont, title:TImageFont
	Field x:Float = 620, y:Float = -1390, vx:Float, vy:Float, heading:Float, time:Float, cooldown:Float
	Field missionTime:Float, maxDepth:Float, dockProgress:Float, complete:Int
	Field lamps:Int = True, recovered:Int, testingChecks:Int, touchInterface:Int
	Method Init(seed:Int = 7)
		map = New TDiveMap
		map.Generate(seed)
		map.Check()
		rocks = map.rocks
		px = map.px
		py = map.py
		probes = New TDiveProbe[px.Length]
		beacons = New TPointLightNode[px.Length]
		Local path:String
?osx
			path = "/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
			path = getenv_("WINDIR") + "/Fonts/segoeui.ttf"
?linux
			path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
		font = TImageFont.DefaultFont()
		title = font
		If FileType(path) = FILETYPE_FILE Then font = LoadScalableImageFont(path, 15);title = LoadScalableImageFont(path, 27)

		scene = TScene.Create()
		world = TLayerNode.Create()
		hud = TLayerNode.Create()
		scene.Root().AddChild(world)
		scene.Root().AddChild(hud)
		scene.SetCulling(True)
		scene.ReservePointers(20)
		scene.SetInputClip(TSceneRect.Create(0, 0, 1200, 760))
		scene.SetStorageLimitBytes(64 * 1024 * 1024)

		camera = New TCamera2D
		camera.offsetX = 600
		camera.offsetY = 380
		camera.x = 620
		camera.y = -1360
		world.SetCamera(camera)

		lighting = TSceneLighting.Create(world)
		lighting.SetAmbient(60, 105, 114, 0.18)
		lighting.SetLightBatching(True)
		rockArt = RockImage()
		normals = RockImage(True)
		backArt = RockImage(False, True)
		backNormal = RockImage(True, True)
		entranceArt = RockImage(False, True, True)
		hull = HullImage()
		beam = BeamImage()

		ocean = New TDiveOcean
		ocean.Init(camera)
		ocean.width = map.width
		ocean.bottom = map.bottom
		ocean.SetSelfBounds(TSceneRect.Create(0, -2000, map.width, map.bottom + 2000))
		world.AddChild(ocean)

		Local backMaterial:TMax2DLightingMaterial = TMax2DLightingMaterial.Create()
		backMaterial.SetReceiverMask(3)
		backMaterial.SetNormalMap(backNormal)
		backMaterial.SetNormalStrength(0.35)
		backMaterial.SetSpecular(0.2, 16)

		For Local row:Int = -1 Until map.bottom / 512 + 1
			For Local col:Int = 0 Until map.width / 512 + 1
				Local image:TImage = backArt
				If row = -1 Then
					image = entranceArt
				End If

				Local tile:TLitSpriteNode = TLitSpriteNode.Create(image, lighting, backMaterial)
				tile.SetPosition(col * 512, row * 512)
				tile.SetScale(512.0 / 192, 512.0 / 192)
				tile.SetTint(75, 110, 125)
				world.AddChild(tile)
			Next
		Next

		Local material:TMax2DLightingMaterial = TMax2DLightingMaterial.Create()
		material.SetReceiverMask(3)
		material.SetNormalMap(normals)
		material.SetNormalStrength(0.85)
		material.SetSpecular(0.6, 24)

		Local occluders:TLightOccluderNode[rocks.Length]
		For Local i:Int = 0 Until rocks.Length
			Local rock:TDiveRock = rocks[i]
			rock.node = TLitSpriteNode.Create(rockArt, lighting, material)
			rock.node.SetPosition(rock.x, rock.y)
			rock.node.SetScale(rock.radius / 87, rock.radius / 87)
			world.AddChild(rock.node)
			Local polygon:Float[24]
			For Local v:Int = 0 Until 12
				polygon[v * 2] = Cos(v * 30) * rock.radius * 0.88
				polygon[v * 2 + 1] = Sin(v * 30) * rock.radius * 0.88
			Next

			rock.occluder = TLightOccluderNode.Create(polygon)
			rock.occluder.SetPosition(rock.x, rock.y)
			rock.occluder.SetHeight(90)
			world.AddChild(rock.occluder)
			occluders[i] = rock.occluder
		Next

		sonar = New TDiveSonar
		sonar.Init(rocks)
		
		physics = New TDivePhysics
		physics.Init(rocks, map.width, map.bottom)
		
		lighting.SetOccluders(occluders)
		
		sun = TDirectionalLightNode.Create(-0.35, -0.7, 0.8)
		sun.SetColor(70, 156, 189)
		sun.SetIntensity(0.10)
		sun.SetShadows(True, 512)
		sun.SetShadowBounds(0, 0, map.width, map.bottom)
		sun.SetShadowSoftness(1)
		world.AddChild(sun)
		
		head = TPointLightNode.Create(520)
		head.SetColor(163, 219, 209)
		head.SetIntensity(3.0)
		head.SetHeight(65)
		head.SetFalloff(1.25)

		pattern = TMax2DLightTexture.Create(beam)
		head.SetTexture(pattern)
		head.SetShadows(True, 512)
		head.SetShadowSoftness(1)
		world.AddChild(head)

		fill = TPointLightNode.Create(165)
		fill.SetColor(100, 177, 175)
		fill.SetIntensity(0.7)
		fill.SetHeight(80)
		world.AddChild(fill)

		Local lights:TLightNode2D[10 + probes.Length]
		lights[0] = sun
		lights[1] = head
		lights[2] = fill

		For Local i:Int = 0 Until probes.Length
			probes[i] = New TDiveProbe
			probes[i].index = i
			probes[i].SetSelfBounds(TSceneRect.Create(-104, -124, 216, 216))

			Local glow:TCompositeNode = TCompositeNode.Create()
			glow.SetPosition(px[i], py[i])
			glow.SetCaptureRect(TSceneRect.Create(-104, -124, 216, 216))
			glow.SetStages([TSceneEffectStage(TSceneBloomStage.Create(0.85, 2, 0.2))])
			glow.AddChild(probes[i])
			world.AddChild(glow)

			beacons[i] = TPointLightNode.Create(85)
			beacons[i].SetColor(255, 164, 68)
			beacons[i].SetIntensity(0.25)
			beacons[i].SetPosition(px[i] + 4, py[i] - 16)
			world.AddChild(beacons[i])
			lights[i + 3] = beacons[i]
		Next

		ecology = New TDiveEcology
		ecology.Init(world, lighting, rocks, map.floors)
		For Local i:Int = 0 Until 4
			lights[3 + probes.Length + i] = ecology.glow[i]
		Next

		For Local i:Int = 0 Until 3
			lights[7 + probes.Length + i] = ecology.water[i]
		Next

		lighting.SetLights(lights)
		flora = New TDiveFlora
		flora.Init(world, lighting, map)
		schools = New TDiveSchool[map.habitatX.Length]
		For Local i:Int = 0 Until schools.Length
			schools[i] = New TDiveSchool
			schools[i].Init(world, lighting, map.habitatKind[i], map.habitatCount[i], map.habitatX[i], map.habitatY[i])
		Next

		For Local school:TDiveSchool = EachIn schools
			school.worldWidth = map.width
			school.worldBottom = map.bottom
		Next

		scatter = TSpriteNode.Create(beam)
		scatter.SetScale(1.875, 2.34375)
		scatter.SetTint(142, 202, 182)
		scatter.SetAlpha(0.14)
		world.AddChild(scatter)

		Local hullMaterial:TMax2DLightingMaterial = TMax2DLightingMaterial.Create()
		hullMaterial.SetReceiverMask(1)
		hullMaterial.SetEmission(90, 145, 145, 0.16)

		ship = TLitSpriteNode.Create(hull, lighting, hullMaterial)
		ship.SetTint(185, 205, 195)
		world.AddChild(ship)
		flora.AddForeground(world)

		atmosphere = New TDiveAtmosphere
		atmosphere.width = map.width
		atmosphere.bottom = map.bottom
		atmosphere.SetSelfBounds(TSceneRect.Create(0, -1450, map.width, map.bottom + 1450))
		world.AddChild(atmosphere)

		' Screen-space water veil belongs below the controls and text, not inside the lit world.
		haze = WaterHazeImage()
		veil = TSpriteNode.Create(haze)
		veil.SetScale(1200.0 / 128, 760.0 / 80)
		hud.AddChild(veil)

		chart = New TDiveChart
		chart.Init(map, sonar)

		Local chartCache:TCompositeNode = TCompositeNode.Create()
		chartCache.SetCacheMode(ESceneCacheMode.Automatic)
		chartCache.SetCaptureRect(TSceneRect.Create(0, 0, 160, 160))
		chartCache.SetPosition(1010, 174)
		chartCache.AddChild(chart)
		hud.AddChild(chartCache)
		
		menuPanel = New TDiveMenuPanel
		menuPanel.SetPosition(944, 106)
		menuPanel.SetSelfBounds(TSceneRect.Create(0, 0, 220, 174))

		lightButton = New TDiveMenuButton
		lightButton.font = font
		lightButton.label = "LIGHTS"
		lightButton.SetPosition(110, 32)

		replayButton = New TDiveMenuButton
		replayButton.font = font
		replayButton.label = "REPLAY"
		replayButton.SetPosition(110, 87)

		newDive = New TDiveMenuButton
		newDive.font = font
		newDive.label = "NEW CAVE"
		newDive.SetPosition(110, 142)
		For Local button:TDiveButton = EachIn [lightButton, replayButton, newDive]
			button.SetSelfBounds(TSceneRect.Create(-100, -22, 200, 44))
			button.SetHitRect(TSceneRect.Create(-100, -24, 200, 48))
			button.SetInteractive(True)
			menuPanel.AddChild(button)
		Next

		steering = New TDiveControl
		steering.font = font
		steering.SetPosition(130, 646)
		steering.SetSelfBounds(TSceneRect.Create(-85, -60, 170, 95))
		steering.SetHitRect(TSceneRect.Create(-85, -40, 170, 80))
		steering.SetInteractive(True)
		hud.AddChild(steering)

		throttle = New TDiveControl
		throttle.font = font
		throttle.vertical = True
		throttle.SetPosition(970, 620)
		throttle.SetSelfBounds(TSceneRect.Create(-40, -100, 80, 200))
		throttle.SetHitRect(TSceneRect.Create(-45, -75, 90, 150))
		throttle.SetInteractive(True)
		hud.AddChild(throttle)

		ping = New TDiveButton
		ping.font = font
		ping.SetPosition(1090, 646)
		ping.SetSelfBounds(TSceneRect.Create(-45, -45, 90, 90))
		ping.SetHitRect(TSceneRect.Create(-50, -50, 100, 100))
		ping.SetInteractive(True)
		hud.AddChild(ping)
		hud.AddChild(menuPanel)

		menuButton = New TDiveMenuButton
		menuButton.icon = True
		menuButton.SetPosition(1164, 36)
		menuButton.SetSelfBounds(TSceneRect.Create(-22, -22, 44, 44))
		menuButton.SetHitRect(TSceneRect.Create(-24, -24, 48, 48))
		menuButton.SetInteractive(True)
		hud.AddChild(menuButton)
	End Method

	Method SetTouchInterface(available:Int)
		touchInterface = available
		steering.SetVisible(available And Not complete)
		throttle.SetVisible(available And Not complete)
		ping.SetVisible(available)
		menuButton.SetVisible(available)
		If Not available Then
			menuOpen = False
		End If

		menuPanel.SetVisible(available And menuOpen)
	End Method

	Method ApplyActionButtons()
		If menuButton.requested Then
			menuOpen = Not menuOpen
		End If

		menuButton.requested = False
		If lightButton.requested Then lamps = Not lamps;menuOpen = False

		lightButton.requested = False
		If replayButton.requested Then
			Reset()
		End If

		replayButton.requested = False
		lightButton.label = "LIGHTS ON"
		If lamps Then
			lightButton.label = "LIGHTS OFF"
		End If

		SetTouchInterface(touchInterface)
	End Method

	Method Reset()
		scene.CancelInput()
		chart.Reset()
		menuOpen = False
		missionTime = 0
		maxDepth = 0
		dockProgress = 0
		complete = False
		ping.label = "PING"
		Place(620, -1390)
		recovered = 0
		cooldown = 0
		atmosphere.sonar = -1
		camera.x = 620
		camera.y = -1360
		world.SetCamera(camera)
		ecology.Reset()
		atmosphere.ClearBubbles()
		For Local school:TDiveSchool = EachIn schools
			school.Reset()
		Next

		For Local i:Int = 0 Until probes.Length
			probes[i].recovered = False
			beacons[i].SetColor(255, 164, 68)
			beacons[i].SetIntensity(0.25)
		Next
	End Method

	Method PingSonar()
		If complete Then Reset();Return

		If cooldown > 0 Then
			Return
		End If

		cooldown = 3
		atmosphere.sonar = 0
		atmosphere.sx = x
		atmosphere.sy = y
	End Method

	Method Place(px:Float, py:Float, angle:Float = 0)
		physics.Reset(px, py, angle)
		physics.clock = time
		x = physics.x
		y = physics.y
		vx = physics.vx
		vy = physics.vy
		heading = physics.heading
	End Method

	Method Advance(dt:Float, ax:Float, ay:Float)
		time :+ dt
		cooldown = Max(0:Float, cooldown - dt)
		Local thrust:Float = Max(-1:Float, Min(1:Float, -ay))
		If complete Then
			thrust = 0
		Else
			missionTime :+ dt
			physics.Advance(dt, ax, thrust)
		End If

		x = physics.x
		y = physics.y
		vx = physics.vx
		vy = physics.vy
		heading = physics.heading
		maxDepth = Max(maxDepth, Float(Max(0:Float, (y + 1400) * 0.18)))
		UpdateDocking(dt)
		Local driveX:Float = Float(Cos(heading)) * thrust, driveY:Float = Float(Sin(heading)) * thrust
		For Local i:Int = 0 Until probes.Length
			probes[i].time = time
			If Not probes[i].recovered And (x - px[i]) ^ 2 + (y - py[i]) ^ 2 < 72 * 72 Then
				probes[i].recovered = True
				probes[i].activatedAt = time
				recovered :+ 1
				beacons[i].SetColor(95, 255, 177)
			End If
		Next

		camera.x :+ (Max(600:Float, Min(Float(map.width - 600), x + Cos(heading) * 90)) - camera.x) * Min(1:Float, dt * 3)
		camera.y :+ (Max(-1360:Float, Min(Float(map.bottom - 380), y)) - camera.y) * Min(1:Float, dt * 3)
		world.SetCamera(camera)
		ship.SetPosition(x, y)
		If Cos(heading) < 0 Then
			ship.SetScale(-1, 1)
			ship.SetRotation(heading - 180)
		Else
			ship.SetScale(1, 1)
			ship.SetRotation(heading)
		End If

		head.SetPosition(Float(x + Cos(heading) * 44), Float(y + Sin(heading) * 44))
		head.SetEnabled(lamps)
		pattern.SetPlacement(480, 300, Float(Cos(heading) * 240), Float(Sin(heading) * 240), heading)
		fill.SetPosition(x, y)

		' Surface spill is confined to the entrance; deep rooms rely on local lights.
		Local daylight:Float = Max(0:Float, Min(1:Float, -y / 1400))
		daylight = daylight * daylight * (3 - 2 * daylight)
		lighting.SetAmbient(60 + Int(daylight * 90), 105 + Int(daylight * 90), 114 + Int(daylight * 80), 0.18 + daylight * 0.65)
		sun.SetIntensity(daylight * 0.7 + 0.10 * Max(0:Float, Min(1:Float, (1000 - x) / 700)))
		veil.SetAlpha(1 - daylight * 0.9)
		scatter.SetAlpha(0.14 * (1 - daylight * 0.85))
		ocean.time = time
		flora.Advance(time, x, y)
		scatter.SetPosition(Float(x + Cos(heading) * 44), Float(y + Sin(heading) * 44))
		scatter.SetRotation(heading)
		scatter.SetVisible(lamps)
		atmosphere.time = time
		atmosphere.UpdateBubbles(dt, x, y, heading, driveX, driveY)
		If atmosphere.sonar >= 0 Then
			atmosphere.sonar :+ dt
			If atmosphere.sonar > 2 Then
				atmosphere.sonar = -1
			End If
		End If

		Local fishStart:ULong
		If profiling Then fishStart = DiveTicks()
		For Local school:TDiveSchool = EachIn schools
			If Abs(school.homeX - x) < 1500 And Abs(school.homeY - y) < 1100 Then
				school.Advance(dt, time, x, y, rocks)
			End If
		Next

		If profiling Then fishNs :+ DiveTicks() - fishStart
		ecology.Advance(dt, time, x, y, Float(Sqr(vx * vx + vy * vy)), atmosphere, lamps, heading)
		chart.Advance(dt, atmosphere)
		SetTouchInterface(touchInterface)
		lighting.Prepare()
		scene.Update(dt)
	End Method

	Method Draw()
		SetClsColor(3, 12, 21)
		Cls
		sonar.Draw(scene, world, hud, camera, atmosphere, probes, map)
		SetBlend(ALPHABLEND)
		SetColor(5, 17, 27)
		SetAlpha(0.9)
		DrawRect(0, 0, 1200, 104)
		SetAlpha(1)
		SetImageFont(title)
		SetColor(208, 239, 231)
		DrawText("BELOW THE LIGHT", 34, 24)
		SetImageFont(font)
		SetColor(100, 166, 177)
		DrawText("PELAGIC SURVEY  /  SEED " + map.seed, 36, 64)
		SetColor(215, 236, 220)
		DrawText("PROBES  " + recovered + " / " + probes.Length, 960, 28)
		SetColor(115, 191, 200)
		DrawText("DEPTH  " + Max(0, Int((y + 1400) * 0.18)) + " m", 960, 57)
		SetColor(105, 164, 178)
		DrawRect(36, 92, 1128, 1)
		If touchInterface Then
			DrawDiveMenuIcon(1164, 36)
		End If

		SetColor(146, 195, 199)
		Local message:String = "Recover the survey instruments. Approach their amber lights."
		If y < -200 Then
			message = "The cave entrance is beneath the launch vessel. Descend and use sonar to explore."
		End If

		If recovered = probes.Length Then
			message = "Survey downloaded. Return to the vessel and slow down beside the launch crane."
		End If

		If dockProgress > 0 Then
			message = "Docking... hold position."
		End If

		If complete Then
			message = "Mission complete. Welcome aboard."
		End If

		SetColor(5, 17, 27)
		SetAlpha(0.8)
		DrawRect(590 - TextWidth(message) / 2, 115, TextWidth(message) + 20, 28)
		SetAlpha(1)
		SetColor(180, 220, 218)
		DrawText(message, 600 - TextWidth(message) / 2, 121)
		SetColor(126, 181, 191)
		Local hint:String = "W/S thrust  /  A/D steer"
		hint :+ "   |   SPACE sonar   |   L lights   |   R replay   |   N new cave"
		If touchInterface Then
			hint = "STEER to turn   |   FWD / REV for thrust   |   PING to scan"
		End If

		DrawText(hint, 600 - TextWidth(hint) / 2, 728)
		If cooldown > 0 Then
			DrawText("RECHARGING", 1040, 700)
		End If

		If atmosphere.sonar >= 0 And recovered < probes.Length Then
			For Local i:Int = 0 Until probes.Length
				If probes[i].recovered Then
					Continue
				End If

				DrawBearing(px[i], py[i], "0" + (i + 1), Float(Max(0:Float, 1 - atmosphere.sonar / 2)))
			Next
		End If

		If recovered = probes.Length And Not complete Then
			DrawBearing(600, -1390, "HOME", 1)
			If dockProgress > 0 Then
				SetColor(27, 61, 68)
				SetAlpha(1)
				DrawRect(500, 156, 200, 4)
				SetColor(106, 231, 208)
				DrawRect(500, 156, 200 * dockProgress / 1.5, 4)
			End If
		End If

		If Not (touchInterface And menuOpen) Then
			chart.DrawMarkers(x, y, heading, probes)
		End If

		If complete Then
			DrawDebrief()
		End If

		SetAlpha(1)
	End Method

	Method UpdateDocking(dt:Float)
		If complete Then
			Return
		End If

		Local nearShip:Int = Abs(x - 600) < 85 And Abs(y - DiveWaterline(x, time)) < 32
		If recovered = probes.Length And nearShip And vx * vx + vy * vy < 22 * 22 Then
			dockProgress :+ dt
			If dockProgress >= 1.5 Then complete = True;ping.label = "DIVE";atmosphere.ClearBubbles()
		Else
			dockProgress = 0
		End If
	End Method

	Method DrawBearing(tx:Float, ty:Float, label:String, alpha:Float)
		Local sx:Float = tx - camera.x + 600, sy:Float = ty - camera.y + 380
		Local dx:Float = sx - 600, dy:Float = sy - 380, offscreen:Int = sx < 70 Or sx > 1130 Or sy < 180 Or sy > 640
		If offscreen Then
			Local ratio:Float = Min(1:Float, Min(500 / Max(1:Float, Abs(dx)), 210 / Max(1:Float, Abs(dy))))
			sx = 600 + dx * ratio
			sy = 380 + dy * ratio
		Else
			sy :- 44
		End If

		SetAlpha(alpha * 0.85)
		SetColor(6, 28, 37)
		DrawOval(sx - 18, sy - 18, 36, 36)
		SetAlpha(alpha)
		SetColor(113, 224, 213)
		SetLineWidth(1)
		DrawLine(sx - 15, sy - 9, sx - 15, sy - 15)
		DrawLine(sx - 15, sy - 15, sx - 9, sy - 15)
		DrawLine(sx + 9, sy + 15, sx + 15, sy + 15)
		DrawLine(sx + 15, sy + 15, sx + 15, sy + 9)
		If label = "HOME" Then
			DrawLine(sx - 10, sy + 2, sx - 6, sy + 7)
			DrawLine(sx - 6, sy + 7, sx + 7, sy + 7)
			DrawLine(sx + 7, sy + 7, sx + 11, sy + 2)
			DrawLine(sx - 10, sy + 2, sx + 11, sy + 2)
			DrawLine(sx, sy + 2, sx, sy - 9)
			DrawLine(sx, sy - 9, sx + 7, sy - 5)
		Else
			DrawText(label, sx - TextWidth(label) / 2, sy - TextHeight(label) / 2)
		End If

		If offscreen Then
			Local angle:Float = ATan2(dy, dx), ax:Float = Cos(angle) * 27, ay:Float = Sin(angle) * 27
			DrawLine(sx + ax, sy + ay, sx + Cos(angle - 18) * 21, sy + Sin(angle - 18) * 21)
			DrawLine(sx + ax, sy + ay, sx + Cos(angle + 18) * 21, sy + Sin(angle + 18) * 21)
		End If

		Local distance:String = Int(Sqr((tx - x) ^ 2 + (ty - y) ^ 2) * 0.18) + " m"
		DrawText(distance, sx - TextWidth(distance) / 2, sy + 23)
	End Method

	Method DrawDebrief()
		SetAlpha(0.94)
		SetColor(5, 24, 33)
		DrawRect(310, 235, 580, 260)
		SetAlpha(1)
		SetColor(112, 235, 210)
		SetImageFont(title)
		DrawText("SURVEY COMPLETE", 600 - TextWidth("SURVEY COMPLETE") / 2, 263)
		SetImageFont(font)
		SetColor(205, 229, 226)
		DrawText("All survey instruments synchronised. Submarine recovered.", 600 - TextWidth("All survey instruments synchronised. Submarine recovered.") / 2, 315)
		Local seconds:Int = Int(missionTime) Mod 60, stamp:String = Int(missionTime / 60) + ":"
		If seconds < 10 Then
			stamp :+ "0"
		End If

		stamp :+ seconds
		Local stats:String = "DIVE TIME  " + stamp + "     /     MAX DEPTH  " + Int(maxDepth) + " m"
		DrawText(stats, 600 - TextWidth(stats) / 2, 362)
		SetColor(126, 181, 191)
		Local restartHint:String = "Press R to replay or N for a new cave."
		If touchInterface Then
			restartHint = "Tap DIVE to replay, or choose NEW CAVE from the menu."
		End If

		DrawText(restartHint, 600 - TextWidth(restartHint) / 2, 430)
	End Method

	Method CheckControls()
		SetTouchInterface(True)
		scene.DispatchPointer(EScenePointerKind.Down, 1, 8, 1164, 36, 1, 1)
		scene.DispatchPointer(EScenePointerKind.Up, 1, 8, 1164, 36, 1, 0)
		ApplyActionButtons()
		If Not menuOpen Then
			Throw "Touch options menu did not open"
		End If

		Local previousLamps:Int = lamps
		scene.DispatchPointer(EScenePointerKind.Down, 1, 8, 1054, 138, 1, 1)
		scene.DispatchPointer(EScenePointerKind.Up, 1, 8, 1054, 138, 1, 0)
		ApplyActionButtons()
		If lamps = previousLamps Or lightButton.requested Then
			Throw "Touch lights action did not toggle once"
		End If

		lamps = previousLamps
		menuOpen = True
		SetTouchInterface(True)
		missionTime = 12
		scene.DispatchPointer(EScenePointerKind.Down, 1, 8, 1054, 193, 1, 1)
		scene.DispatchPointer(EScenePointerKind.Up, 1, 8, 1054, 193, 1, 0)
		ApplyActionButtons()
		If missionTime <> 0 Or replayButton.requested Then
			Throw "Touch replay did not reset the dive"
		End If

		menuOpen = True
		SetTouchInterface(True)
		scene.DispatchPointer(EScenePointerKind.Down, 1, 8, 1054, 248, 1, 1)
		scene.DispatchPointer(EScenePointerKind.Up, 1, 8, 1054, 248, 1, 0)
		If Not newDive.requested Then
			Throw "Touch new cave was unavailable during a dive"
		End If

		newDive.requested = False
		menuOpen = False
		SetTouchInterface(True)
		scene.DispatchPointer(EScenePointerKind.Down, 1, 1, 130, 646, 1, 1)
		scene.DispatchPointer(EScenePointerKind.Move, 1, 1, 190, 646, 0, 1)
		scene.DispatchPointer(EScenePointerKind.Down, 1, 2, 970, 560, 1, 1)
		If steering.axisX < 0.9 Or throttle.axisY > -0.9 Then
			Throw "Touch steering and forward thrust were not independent"
		End If

		scene.DispatchPointer(EScenePointerKind.Move, 1, 1, 190, 590, 0, 1)
		If steering.axisX < 0.9 Or steering.axisY <> 0 Then
			Throw "Steering changed with vertical finger movement"
		End If

		scene.DispatchPointer(EScenePointerKind.Move, 1, 2, 970, 680, 0, 1)
		If throttle.axisY < 0.9 Or throttle.axisX <> 0 Then
			Throw "Touch reverse thrust did not work"
		End If

		scene.DispatchPointer(EScenePointerKind.Up, 1, 1, 190, 590, 1, 0)
		If steering.axisX <> 0 Or steering.held Or throttle.axisY < 0.9 Then
			Throw "Releasing steering affected throttle"
		End If

		scene.CancelInput()
		If throttle.axisY <> 0 Or throttle.held Then
			Throw "Touch cancellation left thrust active"
		End If

		SetTouchInterface(False)
		scene.DispatchPointer(EScenePointerKind.Down, 1, 3, 970, 560, 1, 1)
		If throttle.held Or throttle.axisY <> 0 Then
			Throw "Hidden touch controls captured input"
		End If

		scene.DispatchPointer(EScenePointerKind.Up, 1, 3, 970, 560, 1, 0)
		For Local i:Int = 0 Until probes.Length
			If probes[i].recovered Or probes[i].PulseAge() >= 0 Then
				Throw "Probe pulsed before activation"
			End If

			Place(px[i], py[i])
			Advance(0, 0, 0)
			If Not probes[i].recovered Or probes[i].PulseAge() < 0 Then
				Throw "Probe did not pulse on activation"
			End If

			probes[i].time = time + 0.7
			If Abs(probes[i].PulseAge() - 0.5) > 0.01 Then
				Throw "Probe ring did not expand"
			End If

			probes[i].time = time + 2
			If probes[i].PulseAge() >= 0 Then
				Throw "Probe ring remained between pulses"
			End If

			probes[i].time = time + 4.2
			If Abs(probes[i].PulseAge() - 0.5) > 0.01 Then
				Throw "Probe pulse did not repeat"
			End If

			probes[i].time = time
		Next

		If recovered <> probes.Length Then
			Throw "Probe route contains an inaccessible objective"
		End If

		CheckMission()
		PingSonar()
		If cooldown <> 3 Then Throw "Sonar did not start"

		Place(2200, 470)
		Advance(0.1, 0, 0)
		If camera.x <= 600 Then
			Throw "Camera did not follow the submarine"
		End If

		TDiveMap.CheckSeeds()
		chart.Check()
		physics.Check(map.floors)
		For Local school:TDiveSchool = EachIn schools
			school.CheckBehaviour(rocks)
		Next

		ecology.Check(atmosphere)
		flora.CheckMotion()
		CheckBubbles()
		Reset()
		testingChecks = True
	End Method

	Method CheckMission()
		complete = False
		dockProgress = 0
		x = 600
		y = -1390
		vx = 0
		vy = 0
		recovered = probes.Length - 1
		UpdateDocking(2)
		If complete Then
			Throw "Docked without all survey data"
		End If

		recovered = probes.Length
		vx = 60
		UpdateDocking(2)
		If complete Then
			Throw "Docked at excessive speed"
		End If

		vx = 0
		y = 500
		UpdateDocking(2)
		If complete Then
			Throw "Docked away from the vessel"
		End If

		y = -1390
		UpdateDocking(0.8)
		If complete Then
			Throw "Docked before holding position"
		End If

		x = 800
		UpdateDocking(0.1)
		If dockProgress <> 0 Then
			Throw "Leaving docking area did not reset progress"
		End If

		x = 600
		UpdateDocking(1.5)
		If Not complete Then
			Throw "Return to ship did not complete the mission"
		End If

		complete = False
		dockProgress = 0
		ping.label = "PING"
	End Method

	Method CheckBubbles()
		atmosphere.ClearBubbles()
		atmosphere.UpdateBubbles(0.1, 300, 470, 0, 0, 0)
		If atmosphere.bubbleSerial <> 0 Then
			Throw "Idle submarine emitted bubbles"
		End If

		atmosphere.UpdateBubbles(0.1, 300, 470, 0, 1, 0)
		If atmosphere.bubbleSerial < 4 Then
			Throw "Powered thruster bubble density too low"
		End If

		For Local i:Int = 1 Until atmosphere.bubbleSerial
			Local sizeDelta:Float = atmosphere.bubbleSize[i] - atmosphere.bubbleSize[i - 1]
			Local riseDelta:Float = atmosphere.bubbleRise[i] - atmosphere.bubbleRise[i - 1]
			If sizeDelta * riseDelta < 0 Then
				Throw "Larger bubbles must rise faster"
			End If
		Next

		Local bx:Float = atmosphere.bubbleX[0], by:Float = atmosphere.bubbleY[0], count:Int = atmosphere.bubbleSerial
		' Move and rotate the emitter far away after release: old bubbles must stay behind.
		atmosphere.UpdateBubbles(0.1, 1800, 700, 160, 0, 0)
		If Abs(atmosphere.bubbleX[0] - bx) > 3 Then
			Throw "Bubble followed the submarine"
		End If

		If atmosphere.bubbleY[0] >= by Then
			Throw "Bubble did not rise"
		End If

		If atmosphere.bubbleSerial <> count Then
			Throw "Coasting emitted new bubbles"
		End If

		For Local i:Int = 0 Until 40
			atmosphere.UpdateBubbles(0.1, 1800, 700, 160, 0, 0)
		Next

		For Local life:Float = EachIn atmosphere.bubbleLife
			If life <> 0 Then
				Throw "Expired bubble remained active"
			End If
		Next
	End Method

	Method CheckRendered()
		chart.CheckRendered(probes)
		If Not testingChecks Or x <= 300 Then
			Throw "Submarine did not move"
		End If

		If scene.RetainedStorageBytes() <= 0 Then
			Throw "Bloom stages were not rendered"
		End If

		If Not sonar.chain.Result() Then
			Throw "Sonar displacement was not rendered"
		End If

		If Not sonar.probeChains[0].Result() Then
			Throw "Activated probe displacement was not rendered"
		End If

		If atmosphere.sonar >= 0 Then
			Throw "Sonar pulse did not expire"
		End If
	End Method

	Method Close()
		ecology.Close()
		sonar.Close()
		flora.Close()
		ocean.Close()
		physics.Close()
		scene.Destroy()
		lighting.ReleaseResources()
		If scene.RetainedStorageBytes() <> 0 Then
			Throw "Scene retained storage after destruction"
		End If

		For Local school:TDiveSchool = EachIn schools
			school.Close()
		Next

		rockArt.ReleaseFrames()
		normals.ReleaseFrames()
		backArt.ReleaseFrames()
		entranceArt.ReleaseFrames()
		backNormal.ReleaseFrames()
		hull.ReleaseFrames()
		beam.ReleaseFrames()
		haze.ReleaseFrames()
	End Method
End Type
