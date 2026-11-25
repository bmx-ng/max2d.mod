Type TDiveRock
	Field x:Float, y:Float, radius:Float
	Field node:TLitSpriteNode, occluder:TLightOccluderNode
End Type

Type TDiveControl Extends TCustomDrawNode
	Field held:Int, device:Long, pointer:Long, axisX:Float, axisY:Float
	Field vertical:Int, font:TImageFont
	Method OnPointer(event:TScenePointerEvent) Override
		If event.Kind() = EScenePointerKind.Down Then
			If held Then
				Return
			End If

			held = True
			device = event.DeviceId()
			pointer = event.PointerId()
			event.CapturePointer(Self)
		End If

		If Not held Or event.DeviceId() <> device Or event.PointerId() <> pointer Then
			Return
		End If

		Select event.Kind()
			Case EScenePointerKind.Down, EScenePointerKind.Move
				Local x:Float, y:Float
				If event.PositionIn(Self, x, y) Then
					Local value:Float = x / 60
					If vertical Then
						value = y / 60
					End If

					value = Max(-1:Float, Min(1:Float, value))
					If Abs(value) < 0.12 Then
						value = 0
					Else If value > 0 Then
						value = (value - 0.12) / 0.88
					Else
						value = (value + 0.12) / 0.88
					End If

					If vertical Then axisY = value Else axisX = value
				End If
			Case EScenePointerKind.Up, EScenePointerKind.Cancel, EScenePointerKind.CaptureLost
				held = False
				axisX = 0
				axisY = 0
		End Select

		event.Handle()
	End Method

	Method OnDraw(context:TSceneDrawContext) Override
		SetImageFont(font)
		context.SetColor(12, 43, 55)
		context.SetAlpha(0.55)
		If vertical Then DrawRect(-35, -72, 70, 144) Else DrawRect(-82, -30, 164, 60)

		context.SetColor(65, 143, 158)
		context.SetAlpha(0.8)
		SetLineWidth(2)
		If vertical Then
			DrawLine(0, -60, 0, 60)
			DrawLine(-12, 0, 12, 0)
		Else
			DrawLine(-60, 0, 60, 0)
			DrawLine(0, -12, 0, 12)
		End If

		context.SetColor(157, 238, 232)
		context.SetAlpha(0.8)
		DrawOval(axisX * 60 - 15, axisY * 60 - 15, 30, 30)
		context.SetAlpha(1)
		SetLineWidth(1)
		If vertical Then
			DrawText("FWD", -TextWidth("FWD") / 2, -96)
			DrawText("REV", -TextWidth("REV") / 2, 76)
		Else
			DrawText("STEER", -TextWidth("STEER") / 2, -58)
			DrawText("<", -76, -TextHeight("<") / 2)
			DrawText(">", 67, -TextHeight(">") / 2)
		End If
	End Method

End Type

Type TDiveButton Extends TCustomDrawNode
	Field label:String = "PING"
	Field requested:Int, font:TImageFont
	Method OnPointer(event:TScenePointerEvent) Override
		If event.Kind() = EScenePointerKind.Down Then requested = True;event.Handle()
	End Method

	Method OnDraw(context:TSceneDrawContext) Override
		context.SetColor(12, 43, 55)
		context.SetAlpha(0.85)
		DrawOval(-43, -43, 86, 86)
		context.SetColor(132, 218, 224)
		context.SetAlpha(1)
		SetImageFont(font)
		DrawText(label, -TextWidth(label) / 2, -TextHeight(label) / 2)
	End Method
End Type

Type TDiveMenuPanel Extends TCustomDrawNode
	Method OnDraw(context:TSceneDrawContext) Override
		context.SetColor(12, 43, 55)
		context.SetAlpha(0.95)
		DrawRect(0, 0, 220, 174)
	End Method
End Type

Type TDiveMenuButton Extends TDiveButton
	Field icon:Int
	Method OnDraw(context:TSceneDrawContext) Override
		context.SetColor(12, 43, 55)
		context.SetAlpha(0.65)
		If icon Then
			Return
		Else
			context.SetColor(65, 143, 158)
			context.SetAlpha(0.25)
			DrawRect(-100, -22, 200, 44)
			context.SetColor(157, 238, 232)
			context.SetAlpha(1)
			SetImageFont(font)
			DrawText(label, -TextWidth(label) / 2, -TextHeight(label) / 2)
		End If
	End Method
End Type

Function DrawDiveMenuIcon(x:Float, y:Float)
	SetColor(12, 43, 55)
	SetAlpha(0.65)
	DrawOval(x - 22, y - 22, 44, 44)
	SetColor(157, 238, 232)
	SetAlpha(1)
	SetLineWidth(2)
	For Local line:Int = -1 To 1
		DrawLine(x - 10, y + line * 6, x + 10, y + line * 6)
	Next

	SetLineWidth(1)
End Function

Type TDiveAtmosphere Extends TCustomDrawNode
	Field width:Int = 3000, bottom:Int = 1100
	Field time:Float, sonar:Float = -1, sx:Float, sy:Float
	' Fixed-capacity world-space particles; no allocations while emitting or updating.
	Field bubbleX:Float[192], bubbleY:Float[192], bubbleVX:Float[192], bubbleVY:Float[192]
	Field bubbleAge:Float[192], bubbleLife:Float[192], bubbleSize:Float[192]
	Field bubbleRise:Float[192], bubbleDrag:Float[192], bubblePhase:Float[192]
	Field bubbleWobble:Float[192], bubbleFrequency:Float[192], bubbleOpacity:Float[192]
	Field bubbleCursor:Int, bubbleSerial:Int, bubbleCredit:Float, bubbleInterval:Float = 1
	Field bubbleSeed:Long = 7919
	Method BubbleRandom:Float(low:Float, high:Float)
		' Local generator avoids changing application-wide randomness; reproducible checks.
		bubbleSeed = (bubbleSeed * 48271) Mod 2147483647
		Return low + (high - low) * Float(Double(bubbleSeed) / 2147483647.0)
	End Method

	Method ClearBubbles()
		For Local i:Int = 0 Until bubbleLife.Length
			bubbleLife[i] = 0
		Next

		bubbleCursor = 0
		bubbleSerial = 0
		bubbleCredit = 0
		bubbleInterval = 1
		bubbleSeed = 7919
	End Method

	Method UpdateBubbles(dt:Float, sourceX:Float, sourceY:Float, heading:Float, driveX:Float, driveY:Float)
		If dt <= 0 Then
			Return
		End If

		For Local i:Int = 0 Until bubbleLife.Length
			If bubbleLife[i] <= 0 Then
				Continue
			End If

			bubbleAge[i] :+ dt
			If bubbleY[i] < -1400 Then bubbleLife[i] = 0;Continue

			If bubbleAge[i] >= bubbleLife[i] Then bubbleLife[i] = 0;Continue
			' Jet momentum decays into the water; buoyancy settles at an upward drift.
			Local drift:Float = Float(Sin(bubblePhase[i] + bubbleAge[i] * bubbleFrequency[i])) * bubbleWobble[i]
			bubbleVX[i] = drift + (bubbleVX[i] - drift) / (1 + dt * bubbleDrag[i])
			bubbleVY[i] = -bubbleRise[i] + (bubbleVY[i] + bubbleRise[i]) / (1 + dt * 8)
			bubbleX[i] :+ bubbleVX[i] * dt
			bubbleY[i] :+ bubbleVY[i] * dt
		Next

		Local power:Float = Min(1:Float, Sqr(driveX * driveX + driveY * driveY))
		If power < 0.05 Then bubbleCredit = 0;Return

		Local length:Float = Sqr(driveX * driveX + driveY * driveY)
		driveX :/ length
		driveY :/ length
		bubbleCredit :+ power * 64 * dt
		While bubbleCredit >= bubbleInterval
			bubbleCredit :- bubbleInterval
			bubbleInterval = BubbleRandom(0.35, 1.65)
			Local i:Int = bubbleCursor
			bubbleCursor = (bubbleCursor + 1) Mod bubbleLife.Length
			bubbleSerial :+ 1
			Local spread:Float = BubbleRandom(-8, 8), rear:Float = BubbleRandom(42, 50)
			bubbleX[i] = sourceX - Float(Cos(heading)) * rear - Float(Sin(heading)) * spread
			bubbleY[i] = sourceY - Float(Sin(heading)) * rear + Float(Cos(heading)) * spread
			Local push:Float = BubbleRandom(5, 18) * power
			bubbleVX[i] = -driveX * push + BubbleRandom(-3, 3)
			bubbleVY[i] = -driveY * push - BubbleRandom(2, 9)
			bubbleAge[i] = 0
			bubbleLife[i] = BubbleRandom(1.6, 3.3)
			bubbleSize[i] = BubbleRandom(1.0, 4.2)
			bubbleRise[i] = 8 + bubbleSize[i] * 6
			bubbleDrag[i] = BubbleRandom(10, 18)
			bubblePhase[i] = BubbleRandom(0, 360)
			bubbleFrequency[i] = BubbleRandom(110, 270)
			bubbleWobble[i] = BubbleRandom(3, 13)
			bubbleOpacity[i] = BubbleRandom(0.22, 0.55)
		Wend
	End Method

	Method OnDraw(context:TSceneDrawContext) Override
		For Local i:Int = 0 Until 240
			Local x:Float = (i * 347 Mod width) + Sin(time * 9 + i * 23) * 12
			Local y:Float = (i * 193 Mod (bottom + 1400)) - time * (2 + i Mod 4)
			y = y - Floor(y / (bottom + 1400)) * (bottom + 1400) - 1400
			context.SetColor(113, 191, 200)
			context.SetAlpha(Float(0.15 + 0.12 * Sin(i * 17 + time * 20)))
			DrawOval(x, y, 2 + i Mod 2, 2 + i Mod 2)
		Next

		For Local i:Int = 0 Until bubbleLife.Length
			If bubbleLife[i] <= 0 Then
				Continue
			End If

			Local age:Float = bubbleAge[i] / bubbleLife[i], size:Float = bubbleSize[i] * (1 + age * 0.65)
			context.SetColor(102, 191, 210)
			context.SetAlpha((1 - age) * bubbleOpacity[i])
			DrawOval(bubbleX[i] - size / 2, bubbleY[i] - size / 2, size, size)
		Next

		If sonar >= 0 Then
			context.SetColor(94, 242, 215)
			context.SetAlpha(Float(Max(0:Float, 0.24 - sonar * 0.12)))
			SetLineWidth(2)
			Local radius:Float = sonar * 430
			For Local i:Int = 0 Until 96
				DrawLine(sx + Cos(i * 3.75) * radius, sy + Sin(i * 3.75) * radius, sx + Cos((i + 1) * 3.75) * radius, sy + Sin((i + 1) * 3.75) * radius)
			Next
		End If
	End Method
End Type

Type TDiveProbe Extends TCustomDrawNode
	Field recovered:Int, time:Float, index:Int, activatedAt:Float
	Method PulseAge:Float()
		If Not recovered Then
			Return -1
		End If

		Local phase:Float = (time - activatedAt) Mod 3.5
		If phase >= 1.4 Then
			Return -1
		End If

		Return phase / 1.4
	End Method

	Method OnDraw(context:TSceneDrawContext) Override
		' Compact pressure housing, stabilising fins and a small status LED.
		context.SetColor(48, 71, 80)
		DrawOval(-12, -7, 24, 14)
		context.SetColor(133, 158, 163)
		DrawRect(-8, -6, 16, 12)
		context.SetColor(74, 104, 117)
		DrawRect(-3, -6, 6, 12)
		context.SetColor(29, 49, 61)
		DrawOval(-12, -5, 7, 10)
		DrawOval(6, -5, 7, 10)
		context.SetColor(114, 143, 148)
		SetLineWidth(2)
		DrawLine(-7, 4, -14, 11)
		DrawLine(7, 4, 14, 11)
		SetLineWidth(1)
		DrawLine(2, -6, 4, -16)
		context.SetColor(160, 184, 187)
		DrawOval(2, -18, 4, 3)
		If recovered Then context.SetColor(90, 245, 170) Else context.SetColor(255, 166, 60)

		context.SetAlpha(0.8)
		DrawOval(-1, -3, 3, 3)
		If recovered Then
			context.SetColor(90, 245, 170)
			context.SetAlpha(0.65)
			DrawOval(2, -18, 4, 4)
			Local age:Float = PulseAge()
			If age >= 0 Then
				Local flash:Float = Max(0:Float, 1 - age * 4)
				context.SetColor(220, 255, 237)
				context.SetAlpha(flash)
				DrawOval(2, -18, 4, 4)

			End If
		End If

		context.SetAlpha(1)
	End Method
End Type

Function DiveWaterline:Float(x:Float, time:Float)
	Return -1400 + Float(Sin(x * 0.55 + time * 80)) * 3
End Function

' Scenic surface and open-water backdrop; all coordinates share the cave world.
Type TDiveOcean Extends TCustomDrawNode
	Field width:Int = 3000, bottom:Int = 1100
	Field time:Float
	Field surfaceLight:TImage[24]
	Method Init()
		For Local i:Int = 0 Until surfaceLight.Length
			surfaceLight[i] = SurfaceLightImage(i)
		Next
	End Method

	Method Close()
		For Local image:TImage = EachIn surfaceLight
			image.ReleaseFrames()
		Next
	End Method

	Method OnDraw(context:TSceneDrawContext) Override
		context.SetAlpha(1)
		For Local row:Int = 0 Until 30
			Local t:Float = row / 29.0
			context.SetColor(104 + Int(t * 75), 164 + Int(t * 49), 193 + Int(t * 30))
			DrawRect(0, -2000 + row * 20, width, 21)
		Next

		context.SetColor(236, 246, 240)
		context.SetAlpha(0.3)
		DrawOval(90, -1700, 360, 28)
		DrawOval(700, -1850, 450, 35)
		context.SetAlpha(1)
		For Local row:Int = 0 Until (bottom + 1400) / 4 + 1
			Local t:Float = Min(1:Float, row / 467.5), fade:Float = (1 - t) * (1 - t)
			context.SetColor(3 + Int(fade * 29), 12 + Int(fade * 113), 21 + Int(fade * 126))
			DrawRect(0, -1400 + row * 4, width, 5)
		Next
		' Crossfade prebuilt frames: no texture uploads or particle allocations per frame.
		Local animation:Float = (time * 2.4) Mod 24, index:Int = Int(animation), mix:Float = animation - index
		context.SetColor(255, 255, 255)
		For Local tile:Int = 0 Until width / 1500 + 1
			context.SetAlpha(1 - mix)
			DrawImageRect(surfaceLight[index], tile * 1500, -1400, 1500, 1100)
			context.SetAlpha(mix)
			DrawImageRect(surfaceLight[(index + 1) Mod 24], tile * 1500, -1400, 1500, 1100)
		Next

		Local bob:Float = Sin(time * 65) * 4
		' Survey vessel: submerged keel, working deck, bridge, rail and launch crane.
		context.SetAlpha(1)
		context.SetColor(24, 53, 64)
		DrawPoly([110.0:Float, -1428 + bob, 480.0, -1428 + bob, 442.0, -1355 + bob, 164.0, -1355 + bob])
		context.SetColor(194, 216, 207)
		DrawRect(125, -1451 + bob, 330, 25)
		context.SetColor(218, 224, 203)
		DrawRect(190, -1522 + bob, 126, 72)
		context.SetColor(37, 77, 91)
		DrawRect(202, -1508 + bob, 30, 24)
		DrawRect(243, -1508 + bob, 30, 24)
		DrawRect(284, -1508 + bob, 23, 24)
		context.SetColor(232, 158, 68)
		DrawRect(184, -1530 + bob, 139, 9)
		context.SetColor(94, 115, 113)
		DrawRect(210, -1560 + bob, 9, 30)
		SetLineWidth(3)
		DrawLine(269, -1530 + bob, 269, -1590 + bob)
		DrawLine(249, -1570 + bob, 289, -1570 + bob)
		context.SetColor(228, 175, 87)
		SetLineWidth(7)
		DrawLine(397, -1450 + bob, 397, -1552 + bob)
		DrawLine(397, -1552 + bob, 580, -1552 + bob)
		SetLineWidth(2)
		DrawLine(580, -1552 + bob, 580, -1435 + bob)
		context.SetColor(174, 213, 202)
		DrawOval(575, -1438 + bob, 10, 12)
		context.SetColor(220, 232, 220)
		SetLineWidth(2)
		DrawLine(135, -1469 + bob, 450, -1469 + bob)
		For Local post:Int = 0 Until 10
			DrawLine(135 + post * 35, -1469 + bob, 135 + post * 35, -1451 + bob)
		Next
		' Water tint over the submerged keel and a broken moving surface highlight.
		Local waterY:Float = DiveWaterline(295, time)
		Local fraction:Float = (waterY - (-1428 + bob)) / 73
		Local left:Float = 110 + 54 * fraction, right:Float = 480 - 38 * fraction
		context.SetColor(45, 143, 158)
		context.SetAlpha(0.4)
		DrawPoly([left, waterY, right, waterY, 442.0, -1355 + bob, 164.0, -1355 + bob])
		For Local segment:Int = 0 Until width / 20
			Local xx:Float = segment * 20, yy:Float = DiveWaterline(xx, time)
			context.SetColor(190, 236, 221)
			context.SetAlpha(Float(0.5 + 0.2 * Sin(segment * 33 + time * 40)))
			SetLineWidth(2)
			DrawLine(xx, yy, xx + 18, DiveWaterline(xx + 18, time))
		Next
		' Brief highlights track the animated waterline rather than hovering in the air.
		For Local glint:Int = 0 Until width / 31
			Local xx:Float = glint * 31 + Sin(glint * 71) * 12
			Local flash:Float = Max(0:Float, Float(Sin(time * 95 + glint * 137) * Sin(time * 47 - glint * 53)) - 0.65) / 0.35
			If flash <= 0 Then
				Continue
			End If

			Local yy:Float = DiveWaterline(xx, time)
			context.SetColor(222, 255, 238)
			context.SetAlpha(flash * 0.65)
			SetLineWidth(1)
			DrawLine(xx - 2 - flash * 5, yy, xx + 2 + flash * 5, yy)
		Next

		SetLineWidth(1)
		context.SetAlpha(1)
	End Method
End Type
