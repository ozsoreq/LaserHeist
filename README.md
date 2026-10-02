# Sky Stack

A physics tower-builder made with **Godot 4.7.1**. A crane drops one odd object
at a time. Steer it, rotate it and let go, and try to build the tallest tower
you can, from a floating island in a meadow all the way up to deep space.

## Play

1. Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/)
   (the standard build is enough).
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press **F5** (Run Project).

| Action | Keyboard | Mouse / touch | Gamepad |
|---|---|---|---|
| Move the crane | A / D or ← / → | move the mouse, or hold ◀ ▶ | d-pad / left stick |
| Rotate 45° | Q / E (also Z, X, ↑) | wheel or right click, or ⟲ ⟳ | LB / RB |
| Drop | Space, ↓ or Enter | left click, or DROP | A |
| Pause | Esc / P | II | Start |

You start with **3 hearts**. Every piece that falls off the island costs one.
Each time you reach a new sky zone you get a heart back, up to 5. Your score is
the highest point your settled tower reached. The record is saved on the
device (`user://sky_stack.cfg`).

## Objects

New objects join the random mix as your tower climbs.

| Object | Unlocks at | What it's like |
|---|---|---|
| Crate | start | Trusty and square |
| Plank | start | Long and thin, bridges gaps |
| Roof | 15 m | A triangle that's hard to build on |
| Barrel | 25 m | Rolls unless you wedge it in |
| Pillow | 40 m | Light and very grippy |
| Anvil | 60 m | Very heavy, steadies a wobbly tower |
| Glue Block | 90 m | Welds itself to the first things it touches |
| Ice Block | 130 m | Almost no friction |
| Balloon Crate | 180 m | Drifts down gently, nearly weightless |
| Spring | 240 m | Bouncy: other pieces boing off it |
| Steel Beam | 320 m | Long, heavy and dependable |

## Sky zones

| Zone | From | Twist |
|---|---|---|
| Meadow | 0 m | Calm |
| Rooftops | 40 m | Hot-air balloons |
| Cloud Sea | 120 m | Drifting clouds |
| Jet Stream | 250 m | Wind gusts push falling pieces sideways |
| Stratosphere | 450 m | Lighter wind, gravity at 70% |
| Low Orbit | 700 m | Gravity at 45%, satellites |
| Deep Space | 1000 m | Gravity at 30%, a ringed planet |

Pieces sitting far below the top of the tower are "set in stone" (frozen in
place). That keeps very tall towers stable and the physics cheap.

## Project layout

```
project.godot            Godot 4.7.1, Compatibility renderer, 720×1280 portrait
scenes/main.tscn         entry scene
scripts/main.gd          game loop: crane, spawning, scoring, hearts, camera
scripts/piece.gd         Piece (RigidBody2D): held / falling / landed, wind, glue
scripts/piece_catalog.gd all objects: physics, unlocks, procedural drawing
scripts/zones.gd         sky zones: colours, gravity and wind by altitude
scripts/sky_background.gd parallax sky (hills, clouds, birds, planes, stars)
scripts/island.gd        the floating island
scripts/hud.gd           HUD, touch buttons, title / pause / game-over panels
scripts/sfx.gd           procedural sound effects (no audio files)
scripts/game_state.gd    autoload: input bindings and the saved record
tests/                   headless tests and a screenshot script
```

All art and sound is generated in code, so the project has no asset files
besides the icon.

## Tests

```bash
godot --headless --fixed-fps 60 res://tests/test.tscn
```

The tests check the object catalog and zones. They then let an autopilot
drop every kind of object and confirm that the tower grows past 40 m, that a
piece falling off costs a heart, and that the game ends and saves the record.
The exit code is 0 when everything passes.

To regenerate screenshots, run the screenshot script on a machine with a
display:

```bash
godot --rendering-driver opengl3 res://tests/screenshots.tscn -- out=/tmp/shots
```

## Exporting

Use **Project → Export** in the editor. Install the 4.7.1 export templates
when Godot asks, then add a preset for Web, Windows, macOS, Linux or Android.
The project uses the Compatibility renderer, so the Web export works in any
WebGL 2 browser.
