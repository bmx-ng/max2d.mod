# Afterlight

A small, complete greenhouse puzzle written in BlitzMax. Guide a maintenance
robot through three rooms, push an energy cell onto its socket, redirect the
beam with mirrors, and restore the heartwood tree. Leave each powered room
through the airlock on its right edge. There is no timer or failure screen.

## Build and play

From the Max2D repository directory, using the bcc2 SDK:

```sh
../../bin/bmk makeapp -r -t gui -o demos/afterlight/Afterlight demos/afterlight/afterlight.bmx
```

On macOS this creates `Afterlight.app` beside the source. Do not append `.app`
to the output argument: BMK adds it. On Windows it produces an executable.
The default renderer is SDL GPU (Metal on macOS). SDL3 and the same module
versions used by the rest of this repository are required.

Other renderer builds use `-ud max2d_gl`, `-ud max2d_d3d11`, or
`-ud max2d_d3d9`. The latter two require Windows. If optional effects are
unavailable, ordinary puzzle drawing continues without their embellishments.
Native D3D builds are provided by source configuration but have not yet been
validated specifically for this demo.

The illustration is embedded in the executable. Scalable text uses Arial on
macOS, Segoe UI on Windows or DejaVu Sans on Linux when present; otherwise the
built-in font is used. No downloads or external asset paths are needed at runtime.

## Controls

| Action | Keyboard / mouse | Touch |
| --- | --- | --- |
| Begin / replay | Enter, Space, or click the large button | ACT |
| Move / push cell | WASD or arrows | Touch the left half and drag |
| Rotate adjacent mirror / show hint | E, Space, or ACT panel button | ACT |
| Undo within current room | Z or UNDO panel button | UNDO |
| Pause / resume | Escape or MENU panel button | MENU |
| Reset room | R; or reset button in pause menu | UNDO while paused |
| Resume from pause | Enter / E / Space or Resume button | ACT |
| Exit | Close window; Escape at title/ending | Platform window controls |

Touch controls appear when used. A floating joystick captures one finger;
buttons accept another finger independently. The right-hand buttons use safe-area
layout and render at native output resolution. Movement is cardinal and repeats
at a fixed interval, so analog diagonals cannot skip cells. Touch callbacks have
been tested synthetically; this demo has not yet been played on physical touch
hardware or packaged for mobile platforms.

A room transition is a checkpoint: undo history starts fresh in the next room.
Reset also clears that room's history. The displayed move total retains earlier
attempts; undo subtracts reverted moves. Restarting from the title resets it.

## How it uses Max2D

- `Max2D.TileMap`: a rectangular floor grid with reusable texture tiles.
- `Max2D.ScalableFont`: text at virtual and native display scales.
- `Max2D.VirtualJoystick`: floating stick, independent action touches and safe areas.
- Cached `TMax2DBloom`: beam/receiver glow rebuilt when puzzle state changes.
- Cached `TMax2DShadow`: soft shadows reused beneath robot and battery.
- Cached `TMax2DInnerShadow`: recessed socket shading.
- `ApplyLayerAlphaMask`: clips the energy fill to its circular gauge.
- Animated robot movement, foliage, spores and flowering tree.
- Fixed virtual resolution with letterboxing keeps drawing and mouse coordinates
  consistent. All simulation rules are independent of rendering.

This intentionally small game uses image effects for its lighting appearance;
it does not add a scene lighting engine or custom shader-package ABI.
The cover/ending illustration is generated artwork; gameplay art is drawn in
BlitzMax. See [asset provenance and prompt](assets/README.md).

## Source layout

- `afterlight.bmx`: application, presentation, cached artwork and input loop.
- `model.bmx`: movement, pushing, mirror tracing, room progression and undo.
- `input.bmx`: keyboard/stick conversion to a cardinal step.
- `rules_test.bmx`: breadth-first solver through the real rules, checking undo.
- `touch_test.bmx`: joystick callbacks driving the real model and shared input.

## Verification

From the repository directory:

```sh
../../bin/bmk makeapp -r -o /tmp/afterlight-rules demos/afterlight/rules_test.bmx
/tmp/afterlight-rules
../../bin/bmk makeapp -r -o /tmp/afterlight-touch demos/afterlight/touch_test.bmx
/tmp/afterlight-touch
```

The solver finds solutions of 13, 14 and 19 actions for rooms 1–3 and verifies
undo along explored routes. The touch test covers neutral capture, movement,
pushing, a simultaneous undo finger, one-shot hits, rotation and cancellation.

For screenshots, build a console executable, which still opens a game window:

```sh
../../bin/bmk makeapp -r -o /tmp/afterlight-capture demos/afterlight/afterlight.bmx
/tmp/afterlight-capture --capture-dir /tmp/afterlight-captures
```

This saves five framebuffer images (title, rooms 1–3, ending) and exits. It sets
representative board states for visual inspection; solvability is checked by the
separate rules test. Use a console build on macOS because this SDK's GUI appstub
does not forward command-line arguments. Capture paths should be absolute.

Validated on macOS: release GUI build, Metal and OpenGL framebuffer captures,
puzzle solver, and synthetic touch tests. No comparative performance claim is
made, and no physical touchscreen test is implied.
