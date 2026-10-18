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
the Xbox layout; the game always shows Xbox buttons. For now every pad
is treated as an Xbox pad; other types and their own glyphs are a later
job (`design/KNOWN_ISSUES.md` #39).

**MULTIPLAYER** (on MAIN): up to four players, one controller each.
Press A to join, pick a SIDE (in doubles your partner is whoever shares
your side; an empty place goes to a CPU), SHIRT, BODY and PADDLE, press A
when ready, and Menu to start. LB and RB switch singles and doubles. Plug in or pull out
a pad at any time (a match pauses if one drops). CONTROLS (in OPTIONS)
remaps keys and buttons; VIBRATION is in ACCESSIBILITY.

No volleys from inside your own kitchen (ADR-055): stand in it all you
like, but let the ball bounce there or you lose the point (KITCHEN!).
Swing at a high, falling ball (a lob you get under) with HIT or DRIVE
for an **overhead smash** (ADR-053): fast and steep; SOFT still blocks it.
Hold a swing button at the serve for the charged serve (ADR-044): let go on
the way up for pace; a tap is the safe classic serve. F3 toggles the
diagnostics overlay. 2P versus: set PLAYERS on the title; with two pads
the first is P1's, with one pad P1 plays on the keyboard.

## The title menu

MAIN: **SINGLES** / **DOUBLES** open Player Select (shirt, body, paddle
with POWER / CONTROL / SPEED; 2P picks next on pad 2), then the match.
**OPEN PLAY** walks the park (ADR-034): put your paddle in a court's
stack and play when your turn comes. **MULTIPLAYER**: the four-pad lobby
(above). **TOURNAMENT** (ADR-054): an eight-entry knockout against the
ladder teams, each match at the opponent's home court, between matches the
bracket. **MATCH SETUP**: VS (LADDER plays your saved rung at the team's
home court, with their intro card; the default CPU; or any team),
DIFFICULTY, POINTS, PLAYERS (1P, 2P versus). **PRACTICE** (ADR-028): the
ball machine feeds a drill (SHOT, TARGET, RATE, RETURN TO) and counts
your return streak. **COURT**: VENUE (PARK, LAKESIDE, SUNSET, DINOSAUR,
SPACE, UNDERSEA), TIME (DAY, DUSK, NIGHT), SURFACE, KITCHEN, SURROUND,
LINES, previewed on the demo. **MODIFIERS**: BIG BALL, FAST BALL, WIN BY
2, LAVA. **OPTIONS**: CAMERA, SOUND, MUSIC, FULLSCREEN, SCALE, CONTROLS,
ACCESSIBILITY. **CAREER** (ADR-047): three player slots, each a named
player with a look, lifetime stats and unlocks; the active one is 1P.
Behind it, **RECORDS**: wins, the best streak and longest rally with who
holds them, shutouts, the ladder, practice, the record against each
team, and ERASE RECORDS (twice). Y backs out of any page. Start pauses a
match: RESUME, RESTART, MAIN MENU. Settings, records, careers and the
ladder are saved (`user://save_a.json`/`save_b.json`, layout v5).

## Release

```sh
game/tools/export.sh --check        # the .pck export and a headless boot (no templates needed)
game/tools/export.sh                # every preset into build/ (needs Godot's export templates)
python3 game/tools/release_notes.py # game/RELEASE_NOTES.md from the roadmap and its history
.venv/bin/python game/tools/make_icon.py   # game/icon.png from the art
```

Builds for each release are on the GitHub releases page, from v0.2.1.
macOS builds are ad-hoc signed, not notarized: the first time, right-click
the app and choose Open. The Web build needs to be served over HTTP (not
opened as a file).

`export.sh` refuses a tree with uncommitted changes (`--dev` allows it)
and writes `build_id.txt` (`git describe --always --dirty`), which the
title shows; from a checkout the title says `BUILD DEV <describe>`.

## Layout

| Path | What |
|---|---|
| `sim/` | The deterministic simulation: `k.gd` constants, `types.gd` records, `sim.gd` (ball, collision, players, serve, rules, game, frame pipeline), `ai.gd` (the CPU), `practice.gd` (the ball machine), `select.gd` (Player Select), `replay.gd` (close calls), `open_play.gd` (the park's courts and stacks), `career.gd` (career stats and unlocks), `opponents.gd`, `paddles.gd`. Pure: no Nodes, time, or randomness. |
| `view/` match | `match_view.gd` (one match: the scene, the frame, events) with `match_actors.gd` (people, ball, sparks), `match_input.gd` (intents, pause menu) and `match_end.gd` (records, the initials and UNLOCKED! cards), `court_view.gd` (world → screen), `court_style.gd` (+ shader: court colours, time of day), `hud.gd`, `crowd.gd`, `watcher.gd`, `camera_lean.gd`, `close_call.gd`, `feel.gd`, `player_look.gd` (+ palette shader), `practice_view.gd`, `debug_overlay.gd`. |
| `view/` menus | `title_screen.gd` (the title and its pages), `title_career.gd` (the CAREER pages), `menu_page.gd` (every menu page), `bracket_screen.gd` (the tournament), `select_screen.gd` (Player Select), `lobby_screen.gd` (multiplayer), `practice_page.gd`, `career_keyboard.gd`, `career_preview.gd`, `park_view.gd` (open play), `prompts.gd`/`prompt_bar.gd` (device-aware button prompts), `ui_kit.gd` (panels and text), `bitmap_text.gd`. |
| `view/` sound | `audio_map.gd`/`sfx.gd` (effects and ambience), `music.gd` (the soundtrack: crossfades, stingers, ducking). |
| `meta/` | `save.gd` (two-copy save with migration, layout v5), `settings.gd` (every setting, load/store, match config), `story.gd` (cards, results, quips), `initials.gd` (the record initials card), `career_page.gd` (CAREER's input logic), `lobby.gd` (the multiplayer lobby's logic), `match_stats.gd` (post-match stats), `tournament.gd` (the bracket's logic), `build_info.gd`. |
| `game_ui/` | `controls.gd` (input map autoload, P1..P4 intents, tap latch, SNES pad bits for menus), `bindings.gd` (remapping). |
| `tests/` | Headless runner and suites; `golden/` traces; `golden.gd` regenerates them. |
| `tools/` | `test.sh`, `export.sh`, `version.py`, `release_notes.py`, `make_icon.py`, `sync_assets.sh` (copies `art/levels/out` and the audio in), `screenshot.gd` (title pages, matches, `court=`, `time=`, `pause`, `closecall`, `initials`, `result`, `smash`, `bracket`, `bracket_semi`, `bracket_out`, `bracket_won`), `point_log.gd` (why each point ended), `contact_probe.gd` (contact heights and smashes over bot matches). |
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
