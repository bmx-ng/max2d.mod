' A world-only sonar capture. The HUD is rendered afterward at full clarity.
Type TDiveSonar
	Field layer:TMax2DEffectLayer, chain:TMax2DEffectChain, effect:TMax2DShaderEffect, map:TImage
	Field probeEffects:TMax2DShaderEffect[], probeChains:TMax2DEffectChain[]
	Field empty:TSceneRect = TSceneRect.Create(0, 0, 0, 0)
	Field edges:Float[], edgeCount:Int
	Method Init(rocks:TDiveRock[])
		Local pixels:Float[256 * 256 * 4]
		For Local y:Int = 0 Until 256
			For Local x:Int = 0 Until 256
				Local dx:Float = (x - 127.5) / 128, dy:Float = (y - 127.5) / 128, d:Float = Sqr(dx * dx + dy * dy)
				Local band:Float = (d - 0.8) / 0.055, pulse:Float = 0
				If Abs(band) < 3 And d > 0 Then
					pulse = Sin(band * 100) * Exp(-band * band) * 0.48 / d
				End If

				Local i:Int = (y * 256 + x) * 4
				pixels[i] = 0.5 + dx * pulse
				pixels[i + 1] = 0.5 + dy * pulse
				pixels[i + 2] = 0.5
				pixels[i + 3] = 1
			Next
		Next

		Local bytes:Byte[pixels.Length * 4]
		MemCopy(bytes, pixels, Size_T(bytes.Length))
		map = LoadImage(TTextureData.Create([TTextureLevel.Create(256, 256, PF_RGBA32F, bytes)]), FILTEREDIMAGE)
		effect = CreateDisplacementEffect(map)
		effect.SetEdgeMode(MAX2D_EDGE_CLAMP)
		effect.SetTextureEdgeMode(MAX2D_EDGE_CLAMP)
		layer = New TMax2DEffectLayer
		chain = CreateEffectChain([TMax2DImageEffect(effect)])
		edges = New Float[rocks.Length * 192 * 4]
		For Local rock:TDiveRock = EachIn rocks
			For Local sample:Int = 0 Until 192
				Local a:Float = sample * 360.0 / 192, b:Float = (sample + 1) * 360.0 / 192
				Local ra:Float = OutlineRadius(rock, a), rb:Float = OutlineRadius(rock, b)
				Local ax:Float = rock.x + Cos(a) * ra, ay:Float = rock.y + Sin(a) * ra
				Local bx:Float = rock.x + Cos(b) * rb, by:Float = rock.y + Sin(b) * rb
				Local mx:Float = (ax + bx) / 2, my:Float = (ay + by) / 2, hidden:Int
				For Local other:TDiveRock = EachIn rocks
					If other = rock Then
						Continue
					End If

					Local dx:Float = mx - other.x, dy:Float = my - other.y
					If dx * dx + dy * dy < OutlineRadius(other, Float(ATan2(dy, dx))) ^ 2 Then hidden = True;Exit
				Next

				If hidden Then
					Continue
				End If

				Local i:Int = edgeCount * 4
				edges[i] = ax
				edges[i + 1] = ay
				edges[i + 2] = bx
				edges[i + 3] = by
				edgeCount :+ 1
			Next
		Next
	End Method

	Function OutlineRadius:Float(rock:TDiveRock, angle:Float)
		Return Float((0.91 + 0.035 * Sin(angle * 5) + 0.025 * Cos(angle * 9)) * 96 * rock.radius / 87)
	End Function

	Method ConfigureWave(wave:TMax2DShaderEffect, x:Float, y:Float, radius:Float, fade:Float, camera:TCamera2D)
		Local diameter:Float = Max(1:Float, radius) * 2 / 0.8
		Local sx:Float = x - camera.x + 600, sy:Float = y - camera.y + 380
		wave.SetTextureTransform(sx / 1200 - 0.5, sy / 760 - 0.5, diameter / 1200, diameter / 760)
		wave.SetFloat4("amount", 6 * fade / 1200, 6 * fade / 760, 0, 0)
	End Method

	Method Draw(scene:TScene, world:TLayerNode, hud:TLayerNode, camera:TCamera2D, atmosphere:TDiveAtmosphere, probes:TDiveProbe[], cave:TDiveMap)
		If Not probeEffects Then
			probeEffects = New TMax2DShaderEffect[probes.Length]
			probeChains = New TMax2DEffectChain[probes.Length]
			For Local i:Int = 0 Until probes.Length
				probeEffects[i] = CreateDisplacementEffect(map)
				probeEffects[i].SetEdgeMode(MAX2D_EDGE_CLAMP)
				probeEffects[i].SetTextureEdgeMode(MAX2D_EDGE_CLAMP)
				probeChains[i] = CreateEffectChain([TMax2DImageEffect(probeEffects[i])])
			Next
		End If

		Local age:Float = atmosphere.sonar, active:Int = age >= 0 And age <= 2
		For Local i:Int = 0 Until probes.Length
			If VisiblePulse(probes[i], cave.px[i], cave.py[i], camera) Then
				active = True
			End If
		Next

		If Not active Then scene.Render();Return

		layer.Prepare(1200, 760)
		hud.SetViewport(empty)
		Try
			Using
    Local capture:TMax2DStateScope = layer.Capture()
   Do
				SetClsColor(3, 12, 21)
				Cls
				scene.Render()
				If age >= 0 And age <= 2 Then
					DrawWaveEdges(atmosphere.sx, atmosphere.sy, age, 430, 2, camera)
				End If

				For Local i:Int = 0 Until probes.Length
					If VisiblePulse(probes[i], cave.px[i], cave.py[i], camera) Then
						DrawProbeFront(cave.px[i] + 4, cave.py[i] - 16, probes[i].PulseAge(), camera)
						DrawWaveEdges(cave.px[i] + 4, cave.py[i] - 16, probes[i].PulseAge() * 1.4, 225, 1.4, camera)
					End If
				Next
			End Using
		Finally
			hud.ClearViewport()
		End Try

		Local result:TRenderImage = layer.Image()
		If age >= 0 And age <= 2 Then
			ConfigureWave(effect, atmosphere.sx, atmosphere.sy, age * 430, Min(1:Float, age * 10) * Max(0:Float, 1 - age / 2), camera)
			chain.Prepare(1200, 760)
			chain.Update(result)
			result = chain.Result()
		End If

		For Local i:Int = 0 Until probes.Length
			If Not VisiblePulse(probes[i], cave.px[i], cave.py[i], camera) Then
				Continue
			End If

			Local progress:Float = probes[i].PulseAge()
			ConfigureWave(probeEffects[i], cave.px[i] + 4, cave.py[i] - 16, progress * 315, Min(1:Float, progress * 14) * (1 - progress) ^ 2, camera)
			probeChains[i].Prepare(1200, 760)
			probeChains[i].Update(result)
			result = probeChains[i].Result()
		Next

		SetColor(255, 255, 255)
		SetAlpha(1)
		SetBlend(ALPHABLEND)
		layer.Draw(0, 0, result)
		world.SetViewport(empty)
		Try
			scene.Render()
		Finally
			world.ClearViewport()
		End Try
	End Method

	Method DrawProbeFront(x:Float, y:Float, progress:Float, camera:TCamera2D)
		Local sx:Float = x - camera.x + 600, sy:Float = y - camera.y + 380, radius:Float = progress * 315
		SetBlend(ALPHABLEND)
		SetColor(94, 242, 215)
		SetAlpha(0.24 * (1 - progress) ^ 2)
		SetLineWidth(2)
		For Local segment:Int = 0 Until 96
			Local a:Float = segment * 3.75, b:Float = (segment + 1) * 3.75
			DrawLine(sx + Cos(a) * radius, sy + Sin(a) * radius, sx + Cos(b) * radius, sy + Sin(b) * radius)
		Next
	End Method

	Method VisiblePulse:Int(probe:TDiveProbe, x:Float, y:Float, camera:TCamera2D)
		Return probe.PulseAge() >= 0 And Abs(x - camera.x) < 940 And Abs(y - camera.y) < 720
	End Method

	Method DrawWaveEdges(x:Float, y:Float, age:Float, speed:Float, duration:Float, camera:TCamera2D)
		SetBlend(ALPHABLEND)
		SetColor(109, 234, 219)
		For Local i:Int = 0 Until edgeCount * 4 Step 4
			Local dx:Float = (edges[i] + edges[i + 2]) / 2 - x, dy:Float = (edges[i + 1] + edges[i + 3]) / 2 - y
			Local lag:Float = age - Sqr(dx * dx + dy * dy) / speed
			If lag < -0.035 Or lag > 0.4 Then
				Continue
			End If

			Local alpha:Float = Max(0:Float, 1 - age / duration) * Exp(-Max(0:Float, lag) * 9) * 0.6
			If lag < 0 Then
				alpha :* (1 + lag / 0.035)
			End If

			Local ax:Float = edges[i] - camera.x + 600, ay:Float = edges[i + 1] - camera.y + 380
			Local bx:Float = edges[i + 2] - camera.x + 600, by:Float = edges[i + 3] - camera.y + 380
			SetLineWidth(5)
			SetAlpha(alpha * 0.16)
			DrawLine(ax, ay, bx, by)
			SetLineWidth(1.3)
			SetAlpha(alpha)
			DrawLine(ax, ay, bx, by)
		Next
	End Method

	Method Close()
		For Local probeChain:TMax2DEffectChain = EachIn probeChains
			probeChain.Release()
		Next

		chain.Release()
		layer.Release()
		map.ReleaseFrames()
	End Method
End Type
