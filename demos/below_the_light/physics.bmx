' Physics metres use the same downward-positive Y axis as the scene.
' The water controller clips the hull against a horizontal surface; visual waves
' remain decorative, with their local height driving the controller's waterline.
Type TDivePhysics
	Const SCALE:Float = 50
	Const STEP_TIME:Float = 1.0 / 120
	Field world:b2World, body:b2Body, water:b2BuoyancyController
	Field accumulator:Float, clock:Float
	Field caveRocks:TDiveRock[], rockBodies:b2Body[], colliderX:Float = 1e9, colliderY:Float = 1e9
	Field x:Float, y:Float, heading:Float, vx:Float, vy:Float

	Method Init(rocks:TDiveRock[], width:Int = 3000, bottom:Int = 1100)
		Local bounds:b2AABB = New b2AABB.Create(New b2Vec2.Create(-30, -60), New b2Vec2.Create((width + 1500) / SCALE, (bottom + 1500) / SCALE))
		world = New b2World.Create(bounds, New b2Vec2.Create(0, 4), False)
		world.SetContinuousPhysics(True)
		caveRocks = rocks
		rockBodies = New b2Body[rocks.Length]
		Wall(20, (bottom - 2000) / 2, 20, (bottom + 2000) / 2)
		Wall(width - 20, (bottom - 2000) / 2, 20, (bottom + 2000) / 2)
		Wall(width / 2, bottom, width / 2, 20)
		Local def:b2BodyDef = New b2BodyDef
		def.SetPositionXY(620 / SCALE, -1390 / SCALE)
		def.SetAllowSleep(False)
		body = world.CreateBody(def)
		body.SetBullet(True)

		Local hull:b2PolygonDef = New b2PolygonDef, vertices:b2Vec2[8]
		For Local i:Int = 0 Until 8
			vertices[i] = New b2Vec2.Create(Float(Cos(i * 45) * 0.98), Float(Sin(i * 45) * 0.34))
		Next

		hull.SetVertices(vertices)
		hull.SetDensity(0.96)
		hull.SetFriction(0.2)
		hull.SetRestitution(0.03)
		body.CreateShape(hull)
		body.SetMassFromShapes()

		Local fluid:b2BuoyancyControllerDef = New b2BuoyancyControllerDef
		fluid.SetNormal(New b2Vec2.Create(0, -1))
		fluid.SetOffset(1400 / SCALE)
		fluid.SetDensity(1)
		fluid.SetLinearDrag(0.65)
		fluid.SetAngularDrag(0.8)
		fluid.SetUsesWorldGravity(True)
		fluid.SetUsesDensity(False)
		water = b2BuoyancyController(world.CreateController(fluid))
		water.AddBody(body)
		Reset(620, -1390)
	End Method

	Method UpdateColliders(px:Float, py:Float)
		If (px - colliderX) ^ 2 + (py - colliderY) ^ 2 < 10000 Then
			Return
		End If

		colliderX = px
		colliderY = py
		' This Box2D version has 512 broad-phase proxies. Keep a generous local
		' collision neighbourhood; distant cave geometry remains in the scene.
		For Local i:Int = 0 Until caveRocks.Length
			Local rock:TDiveRock = caveRocks[i]
			If rockBodies[i] And (rock.x - px) ^ 2 + (rock.y - py) ^ 2 > 1200 * 1200 Then
				world.DestroyBody(rockBodies[i])
				rockBodies[i] = Null
			End If
		Next

		For Local i:Int = 0 Until caveRocks.Length
			Local rock:TDiveRock = caveRocks[i]
			If rockBodies[i] Or (rock.x - px) ^ 2 + (rock.y - py) ^ 2 > 1000 * 1000 Then
				Continue
			End If

			Local def:b2BodyDef = New b2BodyDef
			def.SetPositionXY(rock.x / SCALE, rock.y / SCALE)
			Local shape:b2CircleDef = New b2CircleDef
			shape.SetRadius(rock.radius / SCALE)
			shape.SetFriction(0.25)
			shape.SetRestitution(0.05)
			rockBodies[i] = world.CreateBody(def)
			rockBodies[i].CreateShape(shape)
		Next
	End Method

	Method Wall(px:Float, py:Float, hx:Float, hy:Float)
		Local def:b2BodyDef = New b2BodyDef
		def.SetPositionXY(px / SCALE, py / SCALE)
		Local shape:b2PolygonDef = New b2PolygonDef
		shape.SetAsBox(hx / SCALE, hy / SCALE)
		shape.SetFriction(0.2)
		world.CreateBody(def).CreateShape(shape)
	End Method

	Method Reset(px:Float, py:Float, angle:Float = 0, speedX:Float = 0, speedY:Float = 0)
		UpdateColliders(px, py)
		body.SetXForm(New b2Vec2.Create(px / SCALE, py / SCALE), angle)
		body.SetLinearVelocity(New b2Vec2.Create(speedX / SCALE, speedY / SCALE))
		body.SetAngularVelocity(0)
		accumulator = 0
		Sync()
	End Method

	Method Sync()
		Local p:b2Vec2 = body.GetPosition(), v:b2Vec2 = body.GetLinearVelocity()
		x = p.GetX() * SCALE
		y = p.GetY() * SCALE
		vx = v.GetX() * SCALE
		vy = v.GetY() * SCALE
		heading = (body.GetAngle() Mod 360 + 360) Mod 360
	End Method

	Method Advance(dt:Float, steer:Float, thrust:Float)
		UpdateColliders(x, y)
		steer = Max(-1:Float, Min(1:Float, steer))
		thrust = Max(-1:Float, Min(1:Float, thrust))
		accumulator :+ Max(0:Float, Min(0.1:Float, dt))
		While accumulator >= STEP_TIME
			accumulator :- STEP_TIME
			clock :+ STEP_TIME
			Local p:b2Vec2 = body.GetPosition(), v:b2Vec2 = body.GetLinearVelocity(), angle:Float = body.GetAngle()
			Local fx:Float = Cos(angle), fy:Float = Sin(angle), mass:Float = body.GetMass()
			Local wet:Float = Max(0:Float, Min(1:Float, (p.GetY() * SCALE - DiveWaterline(p.GetX() * SCALE, clock) + 18) / 36))
			water.SetOffset(-DiveWaterline(p.GetX() * SCALE, clock) / SCALE)
			Local along:Float = v.GetX() * fx + v.GetY() * fy, cross:Float = -v.GetX() * fy + v.GetY() * fx
			Local power:Float = 2.2
			If thrust < 0 Then
				power = 1.5
			End If

			Local forwardForce:Float = thrust * power - along * (0.12 * Abs(along) + 0.25 * (1 - Abs(thrust)))
			Local sideForce:Float = -cross * (2 + 0.4 * Abs(cross))
			body.ApplyForce(New b2Vec2.Create(mass * wet * (fx * forwardForce - fy * sideForce), mass * wet * (fy * forwardForce + fx * sideForce)), body.GetWorldCenter())
			' Torque steers toward a turn rate, never sets the hull angle or angular velocity.
			Local rate:Float = body.GetAngularVelocity() * 0.0174532925
			Local torque:Float = Max(-7:Float, Min(7:Float, (steer * 1.7 - rate) * 3))
			body.ApplyTorque(body.GetInertia() * torque * wet)
			world.DoStep(STEP_TIME, 8, 4)
		Wend

		Sync()
	End Method

	Method Check(rocks:TDiveRock[])
		Reset(620, -1450, 35)
		For Local i:Int = 0 Until 3600
			Advance(1.0 / 120, 0, 0)
		Next

		If Abs(y + 1400) > 25 Or Abs(Sin(heading)) > 0.2 Then
			Throw "Buoyant hull did not surface and settle level: " + y + ", " + heading
		End If

		Reset(620, -700)
		For Local i:Int = 0 Until 12
			Advance(1.0 / 60, 0, 1)
		Next

		Local early:Float = vx
		If early <= 0 Or early > 35 Then
			Throw "Physics thrust starts too abruptly"
		End If

		For Local i:Int = 0 Until 108
			Advance(1.0 / 60, 0, 1)
		Next

		Local cruise:Float = vx
		If cruise < early * 2 Or cruise > 180 Then
			Throw "Physics thrust failed to build speed"
		End If

		For Local i:Int = 0 Until 60
			Advance(1.0 / 60, 0, 0)
		Next

		If vx <= 0 Or vx > cruise * 0.6 Then
			Throw "Hull drag failed to slow coasting"
		End If

		Reset(620, -700)
		For Local i:Int = 0 Until 60
			Advance(1.0 / 60, 1, 0)
		Next

		If heading < 30 Or heading > 130 Then
			Throw "Torque steering did not turn the hull"
		End If

		For Local i:Int = 0 Until 120
			Advance(1.0 / 60, 0, 0)
		Next

		If Abs(body.GetAngularVelocity()) > 5 Then
			Throw "Hull kept spinning after releasing steering"
		End If

		Reset(620, -700)
		For Local i:Int = 0 Until 60
			Advance(1.0 / 60, 0, -1)
		Next

		If vx >= -20 Then
			Throw "Reverse thrust did not back away"
		End If

		Reset(620, -700)
		For Local i:Int = 0 Until 120
			Advance(1.0 / 60, 0, 0)
		Next

		If vy >= 0 Or vy < -20 Then
			Throw "Submerged hull should rise gently"
		End If

		Local rock:TDiveRock = rocks[0]
		Reset(rock.x, rock.y - rock.radius - 80, 90, 0, 150)
		For Local i:Int = 0 Until 180
			Advance(1.0 / 60, 0, 1)
		Next

		If y > rock.y - rock.radius + 5 Then
			Throw "Submarine passed through the cave wall"
		End If

		Reset(620, -1350, 90)
		For Local i:Int = 0 Until 1800
			Advance(1.0 / 60, 0, 1)
		Next

		If y < 400 Then
			Throw "Physics submarine could not descend into the cave"
		End If

		Reset(620, -700)
		clock = 0
		For Local i:Int = 0 Until 120
			Advance(1.0 / 120, 0.3, 1)
		Next

		Local fineX:Float = x, fineY:Float = y, fineAngle:Float = heading
		Reset(620, -700)
		clock = 0
		For Local i:Int = 0 Until 30
			Advance(1.0 / 30, 0.3, 1)
		Next

		If Abs(x - fineX) > 0.1 Or Abs(y - fineY) > 0.1 Or Abs(heading - fineAngle) > 0.1 Then
			Throw "Physics changed with render frame rate"
		End If

		Reset(620, -1390)
	End Method

	Method Close()
		world.Free()
		body = Null
		water = Null
		world = Null
		rockBodies = Null
		caveRocks = Null
	End Method
End Type
