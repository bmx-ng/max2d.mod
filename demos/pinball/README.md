# Flux Pinball

A small playable physics table using **Physics.Box2D** and **Max2D**. This first
version concentrates on the ball and flippers: two independently controlled
flippers, a charged launcher, three bumpers, two slingshots, scoring and three
balls per game. Light all three bumpers for 500 points and ten seconds of double
scoring. There is a five-second launch protection period with at most one
protected relaunch per launch.

Roll over the three numbered top lights (150 points each) to arm the centre
jackpot for 15 seconds. Pass through its glowing ring to collect 1,000 points,
then build the next set. An expired jackpot requires another set of lights.

## Forge challenge

Hit the **left core three times** to fill its three orange charge segments.
Then shoot the orange **FORGE** ring below it to activate the challenge.
The shutter on the left opens, exposing three targets. Hit all three within
**25 seconds** for 250 points per target, a **2,000-point completion bonus**,
and one power cell. The sidebar shows charge, remaining time and earned cells.

Charge and earned cells persist across balls. An active challenge ends on a
ball drain (including a protected relaunch); a timeout or completion lets the
ball leave the bay before closing the shutter. The bottom rail slopes down to
the left, clear of the lowest target; a matching outlet opens with the shutter
and stays open until the departing ball has cleared it. Hit the core again to recharge
and replay.

## Reactor Frenzy and Multiball

Hit the **centre core three times**, then shoot the centre jackpot ring to start
**Reactor Frenzy**. Make **ten core hits in 25 seconds**: each adds 200 points on
top of normal scoring, and the tenth awards **2,000 points and a power cell**.
The centre ring can collect an armed jackpot and activate Frenzy on the same shot.

Hit the **right core six times**, then shoot **upwards through** the blue **MULTI** ring to release
a second ball from the upper playfield. Falling balls and slow drifts do not activate it. Make **eight core hits while both balls
survive** for **2,000 points and a power cell**. Both balls remain in play after
completion; the reward is awarded once per activation. Losing either ball ends
the challenge and leaves the survivor in play without spending a life. Only the
last ball draining uses the ordinary ball-loss/launch-protection rules.

All three challenges can overlap. Charge and earned cells persist across balls;
Frenzy ends when the final ball drains. Multiball cannot release a third ball.
Both balls score, activate switches, and keep the Forge exit open while inside.
The charge bars and sidebar show readiness, objectives, timers and completion.
Power cells are tracked towards a future Overdrive finale; that finale is not
implemented yet.


## Build

From the Max2D repository directory in the bcc2 SDK:

```sh
../../bin/bmk makeapp -r -t gui -o demos/pinball/Flux demos/pinball/pinball.bmx
```

Open `Flux.app` on macOS (BMK appends `.app` automatically). Windows builds
produce an executable. The sibling `physics.mod/box2d.mod` is required, alongside
SDL3 and the normal Max2D dependencies. Default rendering uses SDL GPU; add
`-ud max2d_gl` to use the OpenGL effects provider instead.

The currently checked-in physics module uses Box2D 2.0.2, with BlitzMax wrapper
version 1.07. No changes to that module are required. Its angular APIs use degrees,
including motor speeds in degrees per second; modern Box2D examples should not be
copied into this binding without adapting their units and API.

## Controls

| Action | Keyboard | Mouse / touch |
| --- | --- | --- |
| Left flipper | Left arrow, A, left Shift | Hold L |
| Right flipper | Right arrow, D, right Shift | Hold R |
| Launch | Hold Space or Down, then release | Hold/release the charge panel |
| Pause / resume | P or Escape | Tap Pause / Resume |
| New game | R; Enter after game over | Tap the game-over panel |
| Sound effects | M | Tap SFX ON/OFF |
| Quit | Window close | Window close |

Both flippers support simultaneous touches. Each captures its finger until
release, including if it slides outside the initial hit area. Launcher and pause
panels have rectangular touch regions matching their artwork. App suspension
cancels touches and pauses. Controls account for native output scale and
letterboxing. On macOS, a small Cocoa bridge disables the held-key accent popup
using a process-only user-default override. SDL's hint alone cannot do this here:
BlitzMax creates NSApp first, bypassing SDL's default-registration path. No
persistent user preference or application plist is changed. Physical touchscreen hardware has not yet been tested.

The table starts with a ball in the shooter lane. A quick tap launches at minimum
power; holding charges a stronger shot. A one-way gate closes after the ball
clears the shooter lane, preventing it from returning to the launcher. Raised flippers can cradle the ball: release and stroke
again to put it back into play.

## Implementation

- Fixed **120 Hz** simulation, with a bounded frame-time accumulator.
- Bullet ball and bullet flippers with continuous collision detection enabled.
- Motorised revolute joints with limited travel, torque and distinct return speed.
- Flippers collide with the ball but not the surrounding static table structure.
- Contact callbacks queue bumper/slingshot events; impulses and scoring happen
  after Box2D unlocks the world. A cooldown suppresses duplicate contact scoring.
- Only the inward-facing long edge of each slingshot kicks and scores. The back
  and end caps cancel outward rebound while preserving motion along the surface.
- Rollovers and the jackpot use swept ball segments, so fast shots cannot skip them.
- Repeated slingshot exchanges progressively reduce powered kicks after the first
  two hits. Flipper or core contact restores full strength, breaking unattended
  Forge/slingshot orbits without random impulses. Forge target caps are bevelled
  into the wall to prevent perched balls.
- Bumper kicks target a minimum outward speed; a 32-unit/s cap bounds energy spikes.
- Table geometry supplies both physics and rendering.
- Interpolated ball position and flipper angle, trails, impact rings and pulses.
- Static bloom is cached once. A reusable blurred sprite supplies moving halos.
- `physics.bmx` has no renderer dependency. `input.bmx` extends Max2D's existing
  virtual controls with rectangular action buttons.

This is an arcade physics prototype. It does not model airborne balls, elevated
ramps, real-machine rubber calibration or a saved high score.
Those can follow once the table feel has been tried and tuned. The geometric
artwork is drawn directly in BlitzMax; there are no external assets.

## Checks

From the repository directory:

```sh
../../bin/bmk makeapp -r -o /tmp/flux-physics demos/pinball/physics_test.bmx
/tmp/flux-physics
../../bin/bmk makeapp -r -o /tmp/flux-input demos/pinball/input_test.bmx
/tmp/flux-input
```

Physics checks cover launch-lane delivery, one-way gate/reset, flipper rise within 100 ms, limits/return, a 30-unit/s
rail collision, actual bumper contact scoring/impulse, a flipper strike, final
ball drain, both slingshot faces/backs/bottom caps, rollover and jackpot rules,
Forge charging, activation, target collisions, timeout, safe gate closure and drain reset,
40 open-Forge trajectories returning to the flippers within eight seconds,
Frenzy/Multiball charging, activation, completion and expiry, simultaneous contacts,
second-ball switches, Forge clearance, all drain orders, persistent rewards,
and a deterministic two-minute simulation with repeated strokes.
Input checks cover independent fingers, launcher/pause/mute hit regions, release,
DPI scaling and letterbox offsets.

A console build can automate a twelve-second rendered session:

```sh
../../bin/bmk makeapp -r -o /tmp/flux-test demos/pinball/pinball.bmx
/tmp/flux-test --capture-dir /tmp/flux-captures
```

This uses a simple scripted player, writes three screenshots and exits with a
physics/score summary. It is a smoke test, not a test of human play quality.
Add `--test-modes` to exercise Frenzy activation and two-ball rendering.
Use the console build for arguments on macOS: this SDK's GUI appstub discards
command-line arguments. `--test` runs without screenshots.

Verified on macOS with the SDL GPU / Metal backend, the headless physics checks,
and synthetic touch input. Other platforms have not yet been tested for this demo.

## References

The implementation is written for this demo. Useful background references:

- [Local motors and limits example](../../../physics.mod/box2d.mod/examples/motorsandlimits.bmx)
- [Vector Pinball](https://github.com/dozingcat/Vector-Pinball): a complete example
  of Box2D-based pinball and motor-driven flippers.
- [Phaser Box2D pinball example](https://samme.github.io/phaser-examples-mirror/box2d/pinball.html)

## Reactor presentation and sound

The presentation is procedural BlitzMax artwork: machined core housings, etched
circuit panels, glass highlights, animated plasma, rail light chases, tapered
ball trails, impact sparks, shockwaves and power-cell celebrations. Frenzy adds
energy filaments between cores; the Forge glows with rising embers; Multiball
has orbiting blue lights and a distinct second-ball halo.

`visuals.bmx` uses graded distortion followed by a texture mask in reusable
`TMax2DEffectBuffers`, cached outline and inner-shadow effects for the core
inserts, cached shadow halos, and a dynamic bright-pass/blur/bloom pass over the
playfield. The interface is composited afterwards to keep text clear. The scene
uses up to 2x resolution on high-DPI displays. Particles and shockwaves use fixed
pools, and effect render images are prepared once and released on shutdown.
Unavailable effects fall back to simpler rendering.

`sound.bmx` synthesizes eight short cues at startup: core hits, slingshots,
flippers, launch, mode start, completion, drain and rollovers. SDL3 plays these
through a bounded twelve-voice pool with stereo placement and conservative
volume. Press **M** or tap **SFX ON/OFF** to mute; pausing silences current cues.
The game still runs if an audio device is unavailable. No music is bundled yet;
the cues leave space for the separately generated soundtrack.

The effects pass and both game modes were smoke-tested on macOS with Metal and
OpenGL, and the mute touch region is covered by the input checks.
