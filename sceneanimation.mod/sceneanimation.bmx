SuperStrict
Rem
bbdoc: Optional retained scene timelines for transforms and opacity.
about: Attach a TSceneTweenNode to the spatial node it animates. Configure explicit endpoints, then Play and drive Scene.Update in seconds. Tracks allocate during configuration; playback reuses them and uses normal scene setters and invalidation.
End Rem
Module Max2D.SceneAnimation
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Scene

Rem
bbdoc: Interpolation curves for scene tween tracks.
End Rem
Enum ESceneEase
 Linear
 SmoothStep
 InQuad
 OutQuad
 InOutQuad
End Enum

Private
Type TTweenTrack
	Field kind:Int, at:Double, duration:Double, ease:ESceneEase
	Field a:Double, b:Double, c:Double, d:Double
	Method Apply(target:TSceneNode2D, time:Double)
		Local t:Double = Max(0.0, Min(1.0, (time - at) / duration))
		Select ease
			Case ESceneEase.SmoothStep;t = t * t * (3 - 2 * t)
			Case ESceneEase.InQuad;t = t * t
			Case ESceneEase.OutQuad;t = t * (2 - t)
			Case ESceneEase.InOutQuad
				If t < 0.5 Then t = 2 * t * t Else t = 1 - 2 * (1 - t) * (1 - t)
		End Select

		Local x:Float = Float(a * (1 - t) + c * t), y:Float = Float(b * (1 - t) + d * t)
		Select kind
			Case 0;target.SetPosition(x, y)
			Case 1;target.SetRotation(x)
			Case 2;target.SetScale(x, y)
			Case 3;target.SetAlpha(x)
		End Select
	End Method
End Type

Function CheckNumber(value:Double)
	If IsNan(value) Or IsInf(value) Then
		Throw "Max2D SceneAnimation: finite numbers required"
	End If
End Function

Public
Rem
bbdoc: Reusable timeline animating its spatial parent's position, rotation, scale and alpha.
about: Add tracks in increasing start-time order for each property. Later tracks for that property take over at their start; before the first start its explicit initial value is applied. Play restarts, Pause/Resume preserve time, Stop preserves the current pose, and Clear releases tracks. The parent's destruction owns this child; detaching freezes automatic playback. Playback uses variable updates, not fixed updates. Raw affine parents support position and alpha only.
End Rem
Type TSceneTweenNode Extends TSceneNode
	Private
	Field tracks:TTweenTrack[]
	Field used:Int, playing:Int, looping:Int, pingPong:Int
	Field length:Double, clock:Double, speed:Double = 1
	Field disposed:Int
	Method CheckEditable()
		If disposed Then
			Throw "Max2D SceneAnimation: destroyed timeline"
		End If

		If playing Then
			Throw "Max2D SceneAnimation: pause before editing tracks"
		End If
	End Method

	Method AddTrack(kind:Int, a:Float, b:Float, c:Float, d:Float, duration:Double, at:Double, ease:ESceneEase)
		CheckEditable()
		CheckNumber(a);CheckNumber(b);CheckNumber(c);CheckNumber(d)
		CheckNumber(duration);CheckNumber(at);CheckNumber(at + duration)
		If pingPong Then
			CheckNumber((at + duration) * 2)
		End If

		If duration <= 0 Or at < 0 Then
			Throw "Max2D SceneAnimation: positive duration and nonnegative start required"
		End If

		If Int(ease) < 0 Or Int(ease) > Int(ESceneEase.InOutQuad) Then
			Throw "Max2D SceneAnimation: invalid easing"
		End If

		For Local i:Int = 0 Until used
			If tracks[i].kind = kind And tracks[i].at > at Then
				Throw "Max2D SceneAnimation: property tracks must be added in start-time order"
			End If
		Next

		Local track:TTweenTrack = New TTweenTrack
		track.kind = kind;track.a = a;track.b = b;track.c = c;track.d = d
		track.duration = duration;track.at = at;track.ease = ease
		If used = tracks.Length Then
			tracks = tracks[..Max(4, used * 2)]
		End If

		tracks[used] = track;used :+ 1;length = Max(length, at + duration)
	End Method

	Method Normalize:Double(value:Double)
		If Not looping Or length = 0 Then
			Return Min(value, length)
		End If

		Local period:Double = length
		If pingPong Then
			period :* 2
		End If

		Return value Mod period
	End Method

	Method ApplyTime()
		Local target:TSceneNode2D = TSceneNode2D(Parent())
		If Not target Then
			Throw "Max2D SceneAnimation: attach timeline to a spatial parent"
		End If

		Local time:Double = clock
		If looping And length > 0 Then
			Local period:Double = length
			If pingPong Then
				period = length * 2
			End If

			time = clock Mod period
			If pingPong And time > length Then
				time = period - time
			End If
		Else
			time = Min(time, length)
		End If
		' Only the first future track may establish a property's initial value.
		Local seen:Int
		For Local i:Int = 0 Until used
			Local track:TTweenTrack = tracks[i], bit:Int = 1 Shl track.kind
			If time >= track.at Or Not (seen & bit) Then
				track.Apply(target, time)
			End If

			seen :| bit
		Next
	End Method

	Public
	Rem
	bbdoc: Appends a position track with explicit local endpoints and timing in seconds.
	param: Initial finite horizontal coordinate in parent-local units.
	param: Initial finite vertical coordinate in parent-local units.
	param: Final finite horizontal coordinate in parent-local units.
	param: Final finite vertical coordinate in parent-local units.
	param: Finite positive track duration in seconds.
	param: Finite nonnegative start time in seconds within the timeline.
	param: Interpolation curve; defaults to linear interpolation.
	returns: This timeline, allowing additional tracks to be chained.
	End Rem
	Method Position:TSceneTweenNode(fromX:Float, fromY:Float, toX:Float, toY:Float, duration:Double, at:Double = 0, ease:ESceneEase = ESceneEase.Linear)
		AddTrack(0, fromX, fromY, toX, toY, duration, at, ease);Return Self
	End Method
	Rem
	bbdoc: Appends a rotation track in degrees; endpoints are not wrapped or shortened.
	param: Initial clockwise angle in degrees; not wrapped.
	param: Final clockwise angle in degrees; not wrapped.
	param: Finite positive track duration in seconds.
	param: Finite nonnegative start time in seconds within the timeline.
	param: Interpolation curve; defaults to linear interpolation.
	returns: This timeline, allowing additional tracks to be chained.
	End Rem
	Method Rotation:TSceneTweenNode(fromDegrees:Float, toDegrees:Float, duration:Double, at:Double = 0, ease:ESceneEase = ESceneEase.Linear)
		AddTrack(1, fromDegrees, 0, toDegrees, 0, duration, at, ease);Return Self
	End Method
	Rem
	bbdoc: Appends a component-scale track; zero and negative scales are allowed.
	param: Initial horizontal scale multiplier; zero and negative values are supported.
	param: Initial vertical scale multiplier; zero and negative values are supported.
	param: Final horizontal scale multiplier; zero and negative values are supported.
	param: Final vertical scale multiplier; zero and negative values are supported.
	param: Finite positive track duration in seconds.
	param: Finite nonnegative start time in seconds within the timeline.
	param: Interpolation curve; defaults to linear interpolation.
	returns: This timeline, allowing additional tracks to be chained.
	End Rem
	Method Scale:TSceneTweenNode(fromX:Float, fromY:Float, toX:Float, toY:Float, duration:Double, at:Double = 0, ease:ESceneEase = ESceneEase.Linear)
		AddTrack(2, fromX, fromY, toX, toY, duration, at, ease);Return Self
	End Method
	Rem
	bbdoc: Appends an opacity track with endpoints in the inclusive range zero to one.
	param: Initial opacity in the inclusive range 0..1.
	param: Final opacity in the inclusive range 0..1.
	param: Finite positive track duration in seconds.
	param: Finite nonnegative start time in seconds within the timeline.
	param: Interpolation curve; defaults to linear interpolation.
	returns: This timeline, allowing additional tracks to be chained.
	End Rem
	Method Alpha:TSceneTweenNode(fromAlpha:Float, toAlpha:Float, duration:Double, at:Double = 0, ease:ESceneEase = ESceneEase.Linear)
		CheckNumber(fromAlpha);CheckNumber(toAlpha)
		If fromAlpha < 0 Or fromAlpha > 1 Or toAlpha < 0 Or toAlpha > 1 Then
			Throw "Max2D SceneAnimation: alpha outside 0..1"
		End If

		AddTrack(3, fromAlpha, 0, toAlpha, 0, duration, at, ease);Return Self
	End Method
	Rem
	bbdoc: Configures repetition; ping-pong alternates forward and backward when looping.
	param: True to enable timeline repetition, False to disable it.
	param: True to alternate forward and backward playback when looping.
	about: Pause before changing loop mode. A non-looping timeline ends at its last endpoint.
	End Rem
	Method SetLoop(enabled:Int, pingPong:Int = False)
		CheckEditable()
		If pingPong Then
			CheckNumber(length * 2)
		End If

		looping = enabled <> 0;Self.pingPong = pingPong <> 0
	End Method
	Rem
	bbdoc: Sets a finite nonnegative playback multiplier; zero holds time while playing.
	param: Finite nonnegative playback multiplier; zero holds the current time.
	End Rem
	Method SetSpeed(value:Double)
		If disposed Then
			Throw "Max2D SceneAnimation: destroyed timeline"
		End If

		CheckNumber(value)
		If value < 0 Then
			Throw "Max2D SceneAnimation: negative speed"
		End If

		speed = value
	End Method
	Rem
	bbdoc: Applies the initial pose and starts variable-step playback from zero.
	about: Requires a spatial parent and at least one track. Endpoints are explicit and never captured from the previous pose.
	End Rem
	Method Play()
		If disposed Or used = 0 Then
			Throw "Max2D SceneAnimation: empty or destroyed timeline"
		End If

		If pingPong Then
			CheckNumber(length * 2)
		End If

		clock = 0;ApplyTime();playing = True;SetProcessing(True)
	End Method
	Rem
	bbdoc: Suspends playback while preserving time and pose.
	End Rem
	Method Pause()
		If disposed Then
			Throw "Max2D SceneAnimation: destroyed timeline"
		End If

		playing = False;SetProcessing(False)
	End Method
	Rem
	bbdoc: Resumes from the retained time; use Play to restart a completed timeline.
	End Rem
	Method Resume()
		If disposed Or used = 0 Then
			Throw "Max2D SceneAnimation: empty or destroyed timeline"
		End If

		ApplyTime();playing = True;SetProcessing(True)
	End Method
	Rem
	bbdoc: Stops and resets the playback clock without changing the parent's current pose.
	End Rem
	Method Stop()
		Pause();clock = 0
	End Method
	Rem
	bbdoc: Applies an absolute nonnegative playback time without changing the playing state.
	param: Finite nonnegative absolute playback time in seconds.
	about: Looping wraps time; non-looping clamps to Duration. Seeking does not fire callbacks or allocate track objects.
	End Rem
	Method Seek(seconds:Double)
		If disposed Then
			Throw "Max2D SceneAnimation: destroyed timeline"
		End If

		CheckNumber(seconds)
		If seconds < 0 Then
			Throw "Max2D SceneAnimation: negative time"
		End If

		clock = Normalize(seconds);ApplyTime()
	End Method
	Rem
	bbdoc: Returns whether playback is enabled; scene pausing or detachment can still suspend updates.
	returns: Whether playback is enabled; scene pausing or detachment can still suspend updates.
	End Rem
	Method IsPlaying:Int()
		Return playing
	End Method
	Rem
	bbdoc: Returns the end time of the last track, in seconds.
	returns: The end time of the last track, in seconds.
	End Rem
	Method Duration:Double()
		Return length
	End Method
	Rem
	bbdoc: Stops and releases every track and its retained storage; preserves the parent's pose.
	End Rem
	Method Clear()
		Stop();tracks = Null;used = 0;length = 0
	End Method
	Rem
	bbdoc: Advances the retained timeline; normally called by Scene.Update.
	param: Finite nonnegative elapsed time in seconds, supplied by the application.
	End Rem
	Method OnUpdate(dt:Double) Override
		If Not playing Then
			Return
		End If

		CheckNumber(dt)
		If dt < 0 Then
			Throw "Max2D SceneAnimation: negative time step"
		End If

		Local nextTime:Double = clock + dt * speed
		CheckNumber(nextTime)
		clock = Normalize(nextTime);ApplyTime()
		If Not looping And clock >= length Then
			Pause()
		End If
	End Method
	Rem
	bbdoc: Drops owned track references when scene destruction completes.
	End Rem
	Method OnDestroy() Override
		tracks = Null;used = 0;playing = False;disposed = True
	End Method
End Type
