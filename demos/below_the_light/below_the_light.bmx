SuperStrict
?max2d_gl
	Framework Max2D.GLMax2D
	Import Max2D.GLEffects
?Not max2d_gl
	Framework Max2D.SDL3GPUMax2D
	Import Max2D.SDL3GPUEffects
?
Import Max2D.SceneEffects
Import Max2D.SceneLighting
Import Max2D.LightingNative
Import Max2D.ScalableFont
Import SDL3.SDL3System
Import Physics.Box2D
Import BRL.Hook
Import BRL.Event
Import BRL.StandardIO
Import BRL.FileSystem
Import Pub.StdC
?osx
Import "macos_input.m"
Extern "C"
	Function DiveDisablePressAndHold:Int()="dive_disable_press_and_hold"
End Extern
?
Extern "C"
	Function DiveTicks:ULong() = "SDL_GetTicksNS"
End Extern

Include "art.bmx"
Include "nodes.bmx"
Include "input.bmx"
Include "fish.bmx"
Include "flora.bmx"
Include "physics.bmx"
Include "sonar.bmx"
Include "ecology.bmx"
Include "map.bmx"
Include "chart.bmx"
Include "dive.bmx"

AppTitle = "Below the Light / Max2D"
?osx
If Not DiveDisablePressAndHold() Then
	Throw "Unable to configure game keyboard input"
End If
?
Graphics(1200, 760)
SetVirtualResolution(1200, 760, VIRTUAL_LETTERBOX)
Local game:TDive = New TDive
Local seed:Int = 7
For Local arg:String = EachIn AppArgs
	If arg.StartsWith("--seed=") Then
		seed = Max(1, Int(arg[7..]))
	End If
Next

game.Init(seed)
Local input:TDiveInput = New TDiveInput
input.Init(game)
input.mapping = CaptureWindowInput()
SetAutoPoll(False)
AddHook(EmitEventHook, DiveInputHook, input)
Local kelpProfile:TDiveKelpProfile
Local profileCave:Int, profileStages:Int
Local sync:Int = 1, testing:Int, frames:Int, previous:Int = MilliSecs()
For Local arg:String = EachIn AppArgs
	If arg = "--profile-stages" Then profileStages = True
	If arg = "--profile-cave" Then profileCave = True
	If arg = "--profile" Or profileCave Or profileStages Then game.profiling = True
	If arg = "--software-60" Then sync = -1
	If arg = "--test" Then
		testing = True
	End If
Next

If testing Then
	game.CheckControls()
End If

?Not max2d_gl
Local gpu:TSDLGPUMax2DContext = TSDLGPUMax2DContext(TMax2DGraphics.Current().context)
Local startIssued:ULong, startMerged:ULong, recordStart:ULong
If profileStages Then gpu.SetRecordTiming(True)
?
Local profileFrames:Int, updateNs:ULong, drawNs:ULong, flipNs:ULong, intervalStart:ULong
While Not AppTerminate()
	input.mapping = CaptureWindowInput()
	PollSystem()
	input.RefreshTouchDevices()
	If KeyDown(KEY_ESCAPE) Then
		Exit
	End If

	Local now:Int = MilliSecs(), dt:Float = Min(0.033:Float, Max(0:Float, (now - previous) * 0.001))
	previous = now
	If AppSuspended() Then
		input.Cancel()
		input.enabled = False
		dt = 0
	Else
		input.enabled = True
	End If

	If KeyHit(KEY_L) Then
		game.lightButton.requested = True
	End If

	If KeyHit(KEY_R) Then
		game.replayButton.requested = True
	End If

	game.ApplyActionButtons()
	If KeyHit(KEY_N) Or game.newDive.requested Then
		input.Cancel()
		game.Close()
		seed = Int((Long(game.map.seed) * 48271) Mod 2147483647)
		Local profiling:Int = game.profiling
		game = New TDive
		game.profiling = profiling
		profileFrames = 0
		game.Init(seed)
		input.Init(game)
	End If

	If KeyHit(KEY_SPACE) Or game.ping.requested Then
		game.PingSonar()
	End If

	game.ping.requested = False
	Local ax:Float = KeyDown(KEY_D) + KeyDown(KEY_RIGHT) - KeyDown(KEY_A) - KeyDown(KEY_LEFT) + game.steering.axisX
	Local ay:Float = KeyDown(KEY_S) + KeyDown(KEY_DOWN) - KeyDown(KEY_W) - KeyDown(KEY_UP) + game.throttle.axisY
	If testing Then
		dt = 1.0 / 60
		ax = 0
		ay = -0.65
		If frames = 15 Then game.Place(620, -1080);game.camera.y = -1080

		If frames = 30 Then game.Place(620, -680);game.camera.y = -680

		If frames = 45 Then game.Place(620, -220);game.camera.y = -220

		If frames = 60 Then game.Place(600, 470);game.camera.y = 480;game.cooldown = 0;game.PingSonar()

		If frames = 90 Then game.Place(game.px[0], game.py[0]);game.camera.x = game.px[0];game.camera.y = game.py[0]

		If frames = 110 Then
			game.atmosphere.sonar = 1.99
		End If
	End If

	If profileCave Then
		' Repeat the same pose series for each 90-frame lighting comparison.
		Local phase:Int = frames / 90, tick:Int = frames Mod 90
		If tick = 0 Then
			If Not kelpProfile Then kelpProfile = New TDiveKelpProfile
			kelpProfile.lighting = game.lighting
			game.lamps = phase <> 3 And phase <> 5
			For Local grass:TDivePlantMesh = EachIn game.flora.grass
				grass.node.SetVisible(phase <> 1)
			Next
			For Local kelp:TDivePlantMesh = EachIn game.flora.kelp
				TDiveKelpNode(kelp.node).profile = kelpProfile
				kelp.node.SetVisible(phase <> 2)
			Next
			Print "profile-cave phase=" + ["full", "hide-grass", "hide-kelp", "lamp-off", "frozen-on", "frozen-off"][phase]
		End If
		If phase < 4 Then
			game.Place(620, -60, Float(Sin(tick * 4) * 2))
		Else
			game.Place(620, -60, 0)
		End If
		game.camera.x = 710
		game.camera.y = -60
		dt = 1.0 / 60
		If phase >= 4 Then dt = 0
		ax = 0
		ay = 0
	End If

	Local start:ULong, drawn:ULong, updated:ULong
	If game.profiling Then
		start = DiveTicks()
		If profileFrames = 0 Then
			intervalStart = start
			updateNs = 0
			drawNs = 0
			flipNs = 0
			game.fishNs = 0
			game.lighting.SetStageTiming(profileStages)
			game.lighting.ResetStats()
?Not max2d_gl
			gpu.GetDrawCounts(startIssued, startMerged)
			If profileStages Then recordStart = gpu.GetRecordNanoseconds()
?
		End If
	End If
	game.Advance(dt, ax, ay)
	If game.profiling Then updated = DiveTicks()
	game.Draw()
	If game.profiling Then drawn = DiveTicks()
	Flip(sync)
	If game.profiling Then
		Local finish:ULong = DiveTicks()
		updateNs :+ updated - start
		drawNs :+ drawn - updated
		flipNs :+ finish - drawn
		profileFrames :+ 1
		If profileFrames = 30 Then
			Local gpuReport:String
?Not max2d_gl
			Local issued:ULong, merged:ULong
			gpu.GetDrawCounts(issued, merged)
			gpuReport = " gpu_draws/frame=" + Float(issued - startIssued) / profileFrames + " adjacent_merged/frame=" + Float(merged - startMerged) / profileFrames
?
			Local stats:TMax2DLightingStats = game.lighting.CaptureStats()
			Local ms:Double = 0.000001 / profileFrames
			Print "depth=" + Int((game.y + 1400) * 0.18) + " lamps=" + game.lamps + " fps=" + Int(1.0e9 * profileFrames / (finish - intervalStart)) + ..
				" update_ms=" + Float(updateNs * ms) + " fish_ms=" + Float(game.fishNs * ms) + " draw_ms=" + Float(drawNs * ms) + " flip_ms=" + Float(flipNs * ms) + ..
				" receivers/frame=" + Float(stats.ReceiverDraws()) / profileFrames + " shadow_rebuilds/frame=" + Float(stats.ShadowRebuilds()) / profileFrames + ..
				" occluder_tests/frame=" + Float(stats.OccluderTests()) / profileFrames + " casters/frame=" + Float(stats.Casters()) / profileFrames + gpuReport
			If profileStages Then
				Local stages:String = "mesh_ms=" + Float(stats.MeshNs() * ms) + " mapping_ms=" + Float(stats.MappingNs() * ms) + " overlap_ms=" + Float(stats.OverlapNs() * ms) + ..
					" selection_ms=" + Float(stats.SelectionNs() * ms) + " group_check_ms=" + Float(stats.SupportNs() * ms)
?Not max2d_gl
				stages :+ " record_ms=" + Float((gpu.GetRecordNanoseconds() - recordStart) * ms)
?
				Print stages
			End If
			If kelpProfile Then kelpProfile.Report(profileFrames)
			profileFrames = 0
		End If
	End If
	frames :+ 1
	If profileCave And frames = 540 Then Exit
	If testing And frames = 120 Then
		game.CheckRendered()
		Print "PASS: Below the Light controls, collisions, probe recovery, camera, lighting and 120 rendered frames"
		Exit
	End If
Wend

RemoveHook(EmitEventHook, DiveInputHook, input)
input.Cancel()
game.Close()
EndGraphics
