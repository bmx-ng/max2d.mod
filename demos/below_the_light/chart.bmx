' Static scope bezel is cached; world-space returns hold their shape and fade together.
Type TDiveChart Extends TCustomDrawNode
	Const RANGE:Float = 800
	Field life:Float, previousPing:Float = -1
	Field map:TDiveMap, edges:Float[], echo:Float[], probeEcho:Float[]
	Method Init(value:TDiveMap, sonar:TDiveSonar)
		map = value
		edges = sonar.edges
		echo = New Float[sonar.edgeCount]
		probeEcho = New Float[map.px.Length]
		SetSelfBounds(TSceneRect.Create(0, 0, 160, 160))
	End Method

	Method ReturnAlpha:Float()
		Local fade:Float = Min(1:Float, life / 4)
		Return fade * fade * (3 - 2 * fade)
	End Method

	Method Advance(dt:Float, sonar:TDiveAtmosphere)
		life = Max(0:Float, life - dt)
		If sonar.sonar >= 0 And (previousPing < 0 Or sonar.sonar < previousPing) Then
			If life <= 0 Then
				ClearReturns()
			End If

			life = 9
		End If

		previousPing = sonar.sonar
		For Local i:Int = 0 Until echo.Length
			Local j:Int = i * 4
			If Arrived((edges[j] + edges[j + 2]) * 0.5, (edges[j + 1] + edges[j + 3]) * 0.5, dt, sonar) Then
				echo[i] = 3
			End If
		Next

		For Local i:Int = 0 Until probeEcho.Length
			If Arrived(map.px[i], map.py[i], dt, sonar) Then
				probeEcho[i] = 3
			End If
		Next
	End Method

	Method Arrived:Int(x:Float, y:Float, dt:Float, sonar:TDiveAtmosphere)
		If sonar.sonar < 0 Then
			Return False
		End If

		Local arrival:Float = Sqr((x - sonar.sx) ^ 2 + (y - sonar.sy) ^ 2) / 430
		Return arrival <= sonar.sonar And arrival >= sonar.sonar - Max(0.04:Float, dt)
	End Method

	Method Reset()
		life = 0
		previousPing = -1
		ClearReturns()
	End Method

	Method ClearReturns()
		For Local i:Int = 0 Until echo.Length
			echo[i] = 0
		Next

		For Local i:Int = 0 Until probeEcho.Length
			probeEcho[i] = 0
		Next
	End Method

	Method Check()
		Local ping:TDiveAtmosphere = New TDiveAtmosphere
		ping.sx = (edges[0] + edges[2]) * 0.5 - 430
		ping.sy = (edges[1] + edges[3]) * 0.5
		ping.sonar = 0.5
		Advance(0.01, ping)
		If echo[0] <> 0 Then
			Throw "Scope return preceded sonar arrival"
		End If

		ping.sonar = 1
		Advance(0.01, ping)
		If echo[0] <> 3 Then
			Throw "Scope missed sonar return"
		End If

		If ReturnAlpha() < 0.9 Then
			Throw "Sonar did not reveal scope returns"
		End If

		ping.sonar = -1
		Advance(6, ping)
		If echo[0] <> 3 Then
			Throw "Scope erased a return while still fading"
		End If

		If ReturnAlpha() <= 0 Or ReturnAlpha() >= 1 Then
			Throw "Scope did not fade smoothly"
		End If

		Advance(4, ping)
		If ReturnAlpha() > 0.001 Then
			Throw "Scope returns did not fade out"
		End If

		Reset()
	End Method

	Method CheckRendered(probes:TDiveProbe[])
		Local target:TRenderImage = CreateRenderImage(1200, 760), savedLife:Float = life, savedProbeEcho:Float = probeEcho[0], headingPixels:Long
		Try
			Using
    Local state:TMax2DStateScope = ScopedMax2DState()
   Do
				SetRenderImage(target)
				SetBlend(ALPHABLEND)
				SetClsColor(0, 0, 0, 0)
				probeEcho[0] = 3
				For Local phase:Int = 0 Until 2
					Cls
					life = 9
					If phase = 1 Then
						life = 0
					End If

					DrawMarkers(map.px[0] - 200, map.py[0], 0, probes)
					Local pixels:TPixmap = ReadRenderImage(target), total:Long, marker:Long
					For Local y:Int = 174 Until 334
						For Local x:Int = 1010 Until 1170
							If x >= 1082 And x <= 1098 And y >= 246 And y <= 262 Then
								marker :+ pixels.ReadPixel(x, y) & $ffffff
							Else
								total :+ pixels.ReadPixel(x, y) & $ffffff
							End If
						Next
					Next
					' Nearby cave returns may overlap the heading marker. Check its opacity
					' separately over empty water so geometry cannot affect the comparison.
					Cls
					DrawMarkers(-5000, -5000, 0, probes)
					pixels = ReadRenderImage(target)
					marker = 0
					For Local y:Int = 246 To 262
						For Local x:Int = 1082 To 1098
							marker :+ pixels.ReadPixel(x, y) & $ffffff
						Next
					Next

					If marker = 0 Then
						Throw "Scope heading marker disappeared"
					End If

					If phase = 0 Then
						headingPixels = marker
					End If

					If phase = 1 And marker <> headingPixels Then
						Throw "Scope heading marker faded with returns"
					End If

					If phase = 0 And total = 0 Then
						Throw "Active scope did not draw"
					End If

					If phase = 1 And total <> 0 Then
						Throw "Scope drawing ignored its fade opacity"
					End If
				Next
			End Using
		Finally
			life = savedLife
			probeEcho[0] = savedProbeEcho
			target.ReleaseFrames()
		End Try
	End Method

	Method OnDraw(context:TSceneDrawContext) Override
		context.SetColor(4, 17, 23)
		context.SetAlpha(0.88)
		DrawOval(2, 2, 156, 156)
		SetLineWidth(1)
		For Local ring:Int = 0 To 1
			Local radius:Float = 76 - ring * 5
			context.SetColor(54, 101, 109)
			context.SetAlpha(0.45 - ring * 0.2)
			For Local segment:Int = 0 Until 96
				DrawLine(80 + Cos(segment * 3.75) * radius, 80 + Sin(segment * 3.75) * radius, 80 + Cos((segment + 1) * 3.75) * radius, 80 + Sin((segment + 1) * 3.75) * radius)
			Next
		Next

		context.SetAlpha(0.4)
		For Local tick:Int = 0 Until 12
			Local angle:Float = tick * 30
			DrawLine(80 + Cos(angle) * 70, 80 + Sin(angle) * 70, 80 + Cos(angle) * 73, 80 + Sin(angle) * 73)
		Next

		context.SetAlpha(1)
	End Method

	Method DrawMarkers(x:Float, y:Float, heading:Float, probes:TDiveProbe[])
		Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
		Local cx:Float = 1090, cy:Float = 254, scale:Float = 68 / RANGE
		Local visibility:Float = ReturnAlpha()
		SetColor(81, 171, 162)
		For Local i:Int = 0 Until echo.Length
			' Short gaps avoid an unbroken miniature maze and suggest discrete returns.
			If (i Mod 11) > 7 Then
				Continue
			End If

			Local j:Int = i * 4, ax:Float = edges[j] - x, ay:Float = edges[j + 1] - y, bx:Float = edges[j + 2] - x, by:Float = edges[j + 3] - y
			Local d2:Float = Max(ax * ax + ay * ay, bx * bx + by * by)
			If d2 > RANGE * RANGE Then
				Continue
			End If

			Local distance:Float = Sqr(d2), strength:Float = Max(echo[i] / 3, 0.12 * Max(0:Float, 1 - distance / 260))
			strength :* (1 - (distance / RANGE) ^ 4)
			If strength < 0.01 Then
				Continue
			End If

			SetLineWidth(2)
			canvas.SetAlpha(strength * 0.025 * visibility)
			DrawLine(cx + ax * scale, cy + ay * scale, cx + bx * scale, cy + by * scale)
			SetLineWidth(1)
			canvas.SetAlpha(strength * 0.28 * visibility)
			DrawLine(cx + ax * scale, cy + ay * scale, cx + bx * scale, cy + by * scale)
		Next

		SetLineWidth(1)
		Local allRecovered:Int = True
		For Local i:Int = 0 Until probes.Length
			If Not probes[i].recovered Then
				allRecovered = False
			End If

			Local dx:Float = map.px[i] - x, dy:Float = map.py[i] - y, distance:Float = Sqr(dx * dx + dy * dy)
			If distance > RANGE Then
				Continue
			End If

			Local strength:Float = Max(probeEcho[i] / 3, Float(distance < 250) * 0.45)
			If probes[i].recovered Then
				strength = Max(strength, 0.4)
			End If

			If strength <= 0 Then
				Continue
			End If

			If probes[i].recovered Then SetColor(92, 235, 166) Else SetColor(255, 173, 76)

			Local sx:Float = cx + dx * scale, sy:Float = cy + dy * scale
			canvas.SetAlpha(strength * 0.12 * visibility)
			DrawOval(sx - 4, sy - 4, 8, 8)
			canvas.SetAlpha(strength * 0.75 * visibility)
			DrawOval(sx - 1.5, sy - 1.5, 3, 3)
		Next

		If allRecovered Then
			Local angle:Float = ATan2(-1390 - y, 600 - x)
			SetColor(142, 202, 200)
			canvas.SetAlpha(0.65 * visibility)
			DrawLine(cx + Cos(angle) * 72, cy + Sin(angle) * 72, cx + Cos(angle - 4) * 66, cy + Sin(angle - 4) * 66)
			DrawLine(cx + Cos(angle) * 72, cy + Sin(angle) * 72, cx + Cos(angle + 4) * 66, cy + Sin(angle + 4) * 66)
		End If

		canvas.SetAlpha(0.8)
		SetColor(167, 220, 208)
		DrawLine(cx + Cos(heading) * 5, cy + Sin(heading) * 5, cx + Cos(heading + 140) * 3, cy + Sin(heading + 140) * 3)
		DrawLine(cx + Cos(heading) * 5, cy + Sin(heading) * 5, cx + Cos(heading - 140) * 3, cy + Sin(heading - 140) * 3)
		canvas.SetAlpha(1)
	End Method
End Type
