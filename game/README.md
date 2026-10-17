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

| Action | Keyboard | Controller (shown as Xbox) |
|---|---|---|
| Move, aim at contact | Arrows / WASD | D-pad or left stick |
| Hit (standard), serve | Space or J | A |
| Drive | K | B |
| Soft (lob; dink aimed away from the net) | L | X |
| Pause; on the result, back to the title | Enter / Esc | Menu |

Any controller works (Xbox, PlayStation, Switch Pro, most others), on
the Xbox layout; the game always shows Xbox buttons. Plug in or pull out
a pad at any time (a match pauses if one drops). CONTROLS (in OPTIONS)
remaps keys and buttons; VIBRATION is in ACCESSIBILITY.

Hold a swing button at the serve for the charged serve (ADR-044): let go on
the way up for pace; a tap is the safe classic serve. F3 toggles the
diagnostics overlay. 2P versus: set PLAYERS on the title; with two pads
the first is P1's, with one pad P1 plays on the keyboard.

## The title menu

MAIN: **SINGLES** / **DOUBLES** open Player Select (shirt, body, paddle
with POWER / CONTROL / SPEED; 2P picks next on pad 2), then the match.
**MATCH SETUP**: VS (LADDER plays your saved rung at the team's home
court, with their intro card; the default CPU; or any team), DIFFICULTY,
POINTS, PLAYERS (1P, 2P versus). **PRACTICE** (ADR-028): the ball machine
feeds a drill (SHOT, TARGET, RATE, RETURN TO) and counts your return
streak. **COURT**: VENUE, TIME (DAY, DUSK, NIGHT), SURFACE, KITCHEN,
SURROUND, LINES, previewed on the demo. **MODIFIERS**: BIG BALL, FAST
BALL, WIN BY 2, LAVA. **OPTIONS**: CAMERA, SOUND, FULLSCREEN, SCALE.
**RECORDS**: wins, the best streak and longest rally with who holds them,
shutouts, the ladder, practice, the record against each team, and ERASE
RECORDS (B twice). Y backs out of any page. Start pauses a match: RESUME,
RESTART, MAIN MENU. Settings, records and the ladder are saved
(`user://save_a.json`/`save_b.json`, layout v4).

## Release

```sh
game/tools/export.sh --check        # the .pck export and a headless boot (no templates needed)
game/tools/export.sh                # every preset into build/ (needs Godot's export templates)
python3 game/tools/release_notes.py # game/RELEASE_NOTES.md from design/PORT_ROADMAP.md
.venv/bin/python game/tools/make_icon.py   # game/icon.png from the art
```

`export.sh` refuses a tree with uncommitted changes (`--dev` allows it)
and writes `build_id.txt` (`git describe --always --dirty`), which the
title shows; from a checkout the title says `BUILD DEV <describe>`.

## Layout

| Path | What |
|---|---|
| `sim/` | The deterministic simulation: `k.gd` constants, `types.gd` records, `sim.gd` (ball, collision, players, serve, rules, game, frame pipeline), `ai.gd` (the CPU), `practice.gd` (the ball machine), `select.gd` (Player Select), `replay.gd` (close calls), `opponents.gd`, `paddles.gd`. Pure: no Nodes, time, or randomness. |
| `view/` | Presentation, read-only: `match_view.gd`, `hud.gd`, `court_view.gd` (world → screen), `menu_page.gd` (every menu page), `title_screen.gd`, `practice_page.gd`, `select_screen.gd`, `crowd.gd`, `watcher.gd`, `camera_lean.gd`, `court_style.gd` (+ shader: court colours, time of day), `close_call.gd`, `feel.gd`, `audio_map.gd`/`sfx.gd`, `player_look.gd` (+ palette shader), `practice_view.gd`, `bitmap_text.gd`, `debug_overlay.gd`. |
| `meta/` | `save.gd` (two-copy save with migration, layout v4), `story.gd` (cards, results, quips), `initials.gd` (the record initials card), `settings.gd` (every setting, load/store, match config), `build_info.gd`. |
| `game_ui/controls.gd` | Input map (autoload), P1/P2 intents, tap latch, SNES pad bits for menus. |
| `tests/` | Headless runner and suites; `golden/` traces; `golden.gd` regenerates them. |
| `tools/` | `test.sh`, `export.sh`, `release_notes.py`, `make_icon.py`, `sync_assets.sh` (copies `art/levels/out` and the SFX in), `screenshot.gd` (title pages, matches, `court=`, `time=`, `pause`, `closecall`, `initials`), `point_log.gd` (why each point ended). |
| `assets/` | Synced art and audio (don't edit here; rebuild in `art/levels`). |
| `data/` | `opponents.json`, `paddles.json`, `court_colors.json`, `venues.json`, … copied from the kit's `data/`. |

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
