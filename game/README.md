# Pickleball '94 — Godot port

Arcade pickleball at 960×540, ported from the SNES game. Godot **4.7**
(pinned; installed with Homebrew: `brew install godot`). Decision record:
`decisions/ADR-052-godot-port.md`.

## Run

```sh
godot --path game            # play
game/tools/test.sh           # all tests, headless
```

## Controls

| SNES | Keyboard | Gamepad |
|---|---|---|
| D-pad (move, aim at contact) | Arrows / WASD | D-pad or left stick |
| B: standard hit, serve | Space or J | South (A/Cross) |
| A: drive | K | East (B/Circle) |
| Y: soft (lob; dink aimed away from the net) | L | West (X/Square) |
| Start: pause; on the result, back to the title | Enter / Esc | Start |

Hold a swing button at the serve for the charged serve (ADR-044): let go on
the way up for pace; a tap is the safe classic serve. F3 toggles the
diagnostics overlay. 2P versus: set PLAYERS on the title and plug in a
second pad.

## The title menu

SINGLES / DOUBLES start a match. VENUE (park, lakeside, sunset), VS
(LADDER plays your saved rung at the team's home court, with their intro
card; or the default CPU; or any team), DIFFICULTY (KID, EASY, MEDIUM,
HARD), POINTS, MODS (BIG BALL, FAST BALL, WIN BY 2, LAVA, all four),
PLAYERS (1P, 2P versus), CAMERA (off, or how far it leans), and PRACTICE
(ADR-028): the ball machine feeds a drill (SHOT, TARGET, RATE, RETURN TO)
and counts your return streak; Start pauses, B on the pause screen goes
back to the title and keeps a new best. Settings,
records, and the ladder are saved (`user://save_a.json`/`save_b.json`).

## Layout

| Path | What |
|---|---|
| `sim/` | The deterministic simulation: `k.gd` constants, `types.gd` records, `sim.gd` (ball, collision, players, serve, rules, game, frame pipeline), `ai.gd` (the CPU), `practice.gd` (the ball machine), `opponents.gd`, `paddles.gd`. Pure: no Nodes, time, or randomness. |
| `view/` | Presentation, read-only: `match_view.gd`, `hud.gd`, `court_view.gd` (world → screen), `bitmap_text.gd`, `sfx.gd`, `title_screen.gd`, `practice_view.gd`, `debug_overlay.gd`. |
| `meta/` | `save.gd` (two-copy save with migration), `story.gd` (cards, results, quips). |
| `game_ui/controls.gd` | Input map (autoload), P1/P2 intents, tap latch. |
| `tests/` | Headless runner and suites; `golden/` traces; `golden.gd` regenerates them. |
| `tools/` | `test.sh`, `sync_assets.sh` (copies `art/levels/out` and the SFX in), `screenshot.gd`, `point_log.gd` (why each point ended). |
| `assets/` | Synced art and audio (don't edit here; rebuild in `art/levels`). |
| `data/` | `opponents.json`, `paddles.json`, … copied from the kit's `data/`. |

## Tests and gates

`tools/test.sh` runs every suite headless and fails on any failure or a
test that ran no assertions:

- ported SNES host tests (physics, hits, rules, serve, doubles, match flow);
- golden traces (`tests/golden/`): per-frame hashes of the sim over three
  scripted runs: any change to play shows up;
- stats harness (`test_ladder.gd`): difficulty and ladder order;
- perf gate (`test_perf.gd`): the worst case, named, with headroom;
- view checks: the painted court is the called court, and the view never
  writes to the sim.

A change that is meant to alter play regenerates the traces
(`godot --headless --path game -s res://tests/golden.gd`) and says why in
the commit. Screenshots for visual checks:

```sh
godot --path game --resolution 960x540 -s res://tools/screenshot.gd -- doubles sunset 400 /tmp/shot.png
godot --path game --resolution 960x540 -s res://tools/screenshot.gd -- practice_kitchen park 145 /tmp/practice.png
```
