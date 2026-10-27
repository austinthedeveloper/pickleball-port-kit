# Pickleball '94 — Godot port

> **About this project:** the game is real; its 1993 history is invented.
> See [ABOUT.md](../ABOUT.md).

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
| Slice (slow, never deep, steady off a stretch) | I | Y |
| Short (hold: any swing goes short) | Shift or U | LB or RB |
| Special (SPECIALS on: PICKLE SMASH with a full meter) | O | RT |
| Pause; on the result, back to the title | Enter / Esc | Menu |

Any controller works (Xbox, PlayStation, Switch Pro, most others), by
button position: the south button hits, east drives, west is soft. The
prompts show your pad's own buttons (PORT-28): Xbox letters, PlayStation
shapes, or Nintendo letters, from the pad's name; BUTTON ICONS on
CONTROLS picks one if your pad isn't recognised. Per-player remaps are
still a later job (`design/KNOWN_ISSUES.md` #39).

**MULTIPLAYER** (on MAIN): up to four players, one controller each.
Press A to join, pick a SIDE (in doubles your partner is whoever shares
your side; an empty place goes to a CPU), SHIRT, BODY and PADDLE, press A
when ready, and Menu to start. LB and RB step through SINGLES, DOUBLES, SINGLES CUP and DOUBLES CUP:
a **cup** enters everyone (each player, or each side in doubles) in a
tournament bracket with CPU teams filling it out (PORT-29). Plug in or pull out
a pad at any time (a match pauses if one drops). CONTROLS (in OPTIONS)
remaps keys and buttons; VIBRATION is in ACCESSIBILITY.

No volleys from inside your own kitchen (ADR-055): stand in it all you
like, but let the ball bounce there or you lose the point (KITCHEN!).
Swing at a high, falling ball (a lob you get under) with HIT or DRIVE
for an **overhead smash** (ADR-053): fast and steep; SOFT still blocks it.
Hold a swing button at the serve for the charged serve (ADR-044): let go on
the way up for pace; a tap is the safe classic serve. F3 toggles the
diagnostics overlay. 2P versus: set PLAYERS on MATCH SETUP; with two
pads the first is P1's, with one pad P1 plays on the keyboard.

## Updates

From 0.9.0 the game keeps itself up to date. From 0.9.2, when you open
it, it checks for a new version and, if there is one, downloads it
(about 23 MB) and restarts on it before the title. Only the desktop builds do this; a release that changes
Godot itself sends you to the releases page instead (ADR-057).

## Playing online

MAIN > MULTIPLAYER > **ONLINE**: 1 vs 1 singles with a friend (ADR-056).
You both need the same version of the game (the desktop build; the Web
build can't).

1. **The host** picks HOST A MATCH. The screen shows their address and
   waits. The match uses the host's COURT, POINTS and MODIFIERS.
2. **The friend** picks ADDRESS, types the host's address (Enter when
   done; paste works), then JOIN.
3. Once you're connected, the host picks START MATCH.

How the friend reaches the host:

- **Same Wi-Fi or router:** use an address the host's screen shows. A
  computer on both Ethernet and Wi-Fi shows both, the wired one first;
  if one doesn't answer, try the other.
- **Over the internet, easiest:** both install [Tailscale](https://tailscale.com)
  (free), sign in, and join the same network; use the host's TAILSCALE
  address (100.x.y.z), which the screen shows once Tailscale is on. No
  router changes.
- **Over the internet, without a VPN:** the host forwards **UDP port
  24994** on their router to their computer, and the friend uses the
  host's public address.

The first time you host, macOS or Windows may ask to allow incoming
connections: allow it. On Windows, if a friend still can't reach you,
check the network is set to **Private** (Settings > Network & internet >
your Wi-Fi or Ethernet > Network profile type): Windows blocks incoming
calls on a Public network. In a match, Menu pressed twice leaves; the host's
button on the result is the rematch.

## The title menu

MAIN (ADR-079): **STORY**, **ROAD TRIP** (port ADR-087: a roguelike
drive to the SUMMER OPEN on a map of stops, gear picked on the way, three
hearts, a GARAGE of lasting rewards between trips), **PLAY**, **PRACTICE**, **PLAYER** (the
career players, RECORDS, ACHIEVEMENTS, the HAT MUSEUM), **OPTIONS**. PLAY:
**QUICK MATCH** (SINGLES or DOUBLES) opens MATCH SETUP, whose START opens
Player Select (shirt, body, paddle with POWER / CONTROL / SPEED; 2P picks
next on pad 2), then the match.
**OPEN PLAY** walks the park (ADR-034): put your paddle in a court's
stack and play when your turn comes. The courts are ROOKIE, CLUB and
CHAMP; a career player earns park points that open the upper two, winners
stay on for two games, and SLICE at your rack picks a partner from the
teams you've beaten (ADR-060). **MULTIPLAYER**: the four-pad lobby
(above). **TOURNAMENT** (ADR-054): an eight-entry knockout against the
ladder teams, each match at the opponent's home court, between matches the
bracket. **MATCH SETUP** (QUICK MATCH's page; COURT and MODIFIERS are on it): MODE, VS (LADDER plays your saved rung at the team's
home court, with their intro card; the default CPU; any team; and, once
you've cleared a ladder, DALE DAWSON, who plays doubles alone: ADR-066),
DIFFICULTY, POINTS, PLAYERS (1P, 2P versus). **PRACTICE**: **HOW TO PLAY** (PORT-30), six short lessons (rally,
shots, the smash, the serve, the two-bounce rule, the kitchen), each a
real match or ball-machine drill with one goal; and the **BALL MACHINE**
(ADR-028), which feeds a drill (SHOT, TARGET, RATE, RETURN TO) and counts
your return streak. **COURT**: VENUE (PARK, LAKESIDE, SUNSET, DINOSAUR,
SPACE, UNDERSEA, GYM, RUINS, GLACIER, LAB, STATION, and ADR-088's painted
WESTERN, ROOFTOP, PIRATES, MOTEL, FAIR, DRIVE-IN, MALL), TIME (DAY, DUSK, NIGHT), SURFACE, KITCHEN, SURROUND,
LINES, previewed on the demo. **MODIFIERS**: BIG BALL, FAST BALL, GHOST
BALL, POPCORN, ICE, GLOW, INVERSE, MOON, BOUNCY, WIND, and **RULES**: WIN
BY 2, LAVA, SIDE-OUT, MOMENTUM, DINK OR DIE, SUDDEN DEATH, MULTI BALL, and **SPECIALS** (ADR-080: a meter, and PICKLE SMASH on SPECIAL)
(ADR-063 to 067). **OPTIONS**: CAMERA, SOUND, MUSIC, FULLSCREEN, SCALE,
CONTROLS, ACCESSIBILITY (SCREEN SHAKE strength, FLASHES, HUD TEXT, SERVE
ASSIST, VIBRATION), UPDATES. **CAREER** (ADR-047): three player slots,
each a named player with a look, lifetime stats and unlocks; the active
one is 1P. A player's card opens the **HAT MUSEUM** (ADR-061): every hat
in a case, the ones still to earn as silhouettes with how to get them.
Behind it, **RECORDS**: wins, the best streak and longest rally with who
holds them, shutouts, the ladder, practice, the record against each
team, and ERASE RECORDS (twice). Y backs out of any page. Start pauses a
match: RESUME, RESTART, MAIN MENU. Settings, records, careers and the
ladder are saved (`user://save_a.json`/`save_b.json`, layout v6).

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
opened as a file). It's the lite build (port ADR-089): smaller music and
ambience, and no announcer, ROAD TRIP or painted venues.

`export.sh` refuses a tree with uncommitted changes (`--dev` allows it)
and writes `build_id.txt` (`git describe --always --dirty`), which the
title shows; from a checkout the title says `BUILD DEV <describe>`.

## Layout

| Path | What |
|---|---|
| `sim/` | The deterministic simulation: `k.gd` constants, `types.gd` records, `sim.gd` (ball, collision, players, serve, rules, game, frame pipeline, in the C's order), `multi_ball.gd` (the port-only MULTI BALL), `sim_state.gd` (the whole state saved and loaded, ADR-100), `ai.gd` (the CPU), `practice.gd` (the ball machine), `select.gd` (Player Select), `replay.gd` (close calls), `open_play.gd` (the park's courts and stacks), `career.gd` (career stats and unlocks), `opponents.gd`, `paddles.gd`. Pure: no Nodes, time, or randomness. |
| `view/` match | `match_view.gd` (one match: the scene, the frame, events) with `match_actors.gd` (people, ball, sparks), `match_input.gd` (intents, pause menu) and `match_end.gd` (records, the initials and UNLOCKED! cards), `court_view.gd` (world → screen), `court_style.gd` (+ shader: court colours, time of day), `hud.gd` (with `hud_cards.gd`: the intro, initials, UNLOCKED! and stats cards), `crowd.gd`, `watcher.gd`, `camera_lean.gd`, `close_call.gd`, `feel.gd`, `flair.gd` (point reactions, emotes, the net's shiver), `rally_heat.gd` (a long rally's fire and focus), `critter.gd` (each venue's critter), `dino_walkers.gd` (the Carnotaurus and friends at DINOSAUR and DINO PARK, and the Carnotaurus at the LAB), `wind_view.gd`, `player_look.gd` (+ palette shader), the `glow_outline`, `invert` and `shadow_tint` shaders, `practice_view.gd`, `ball_glide.gd` (a paced ball drawn gliding), `highlight.gd` (PLAY OF THE MATCH: the recording and the replay), `tuning_panel.gd` (F2: the tuning flyout), `debug_overlay.gd` (F3). |
| `view/` menus | `title_screen.gd` (the title), `title_pages.gd` (its pages' rows), `title_career.gd` (the CAREER pages), `menu_page.gd` (every menu page, and `drive()`: one frame of the menu keys), `bracket_screen.gd` (the tournament), `select_screen.gd` (Player Select), `lobby_screen.gd` (multiplayer), `practice_page.gd`, `tutorial_view.gd` (a lesson's card and banner), `story_scene.gd` (STORY's scenes: the cast, the dialog, the cards), `trip_home.gd`, `trip_map.gd`, `trip_pick.gd`, `trip_shop.gd`, `trip_scene.gd`, `trip_van.gd` and `trip_art.gd` (ROAD TRIP's home, GARAGE and SCRAPBOOK, its map, PICK ONE, the PRO SHOP, its scenes, THE VAN, and its art with the placeholders' stand-ins), `course_screen.gd` and `court_diagram.gd` (PICKLEBALL 101), `career_keyboard.gd`, `online_screen.gd` (host and join), `career_preview.gd`, `hat_museum.gd`, `update_screen.gd` (the update at launch), `park_view.gd` (open play) with `park_message.gd` (its panel's text), `prompts.gd`/`prompt_bar.gd` (device-aware button prompts), `touch_pad.gd` (the on-screen pad, PORT-81), `ui_kit.gd` (panels and text), `setting_rows.gd` (rows shared by the title and the tuning panel), `bitmap_text.gd`. |
| `view/` sound | `audio_map.gd`/`sfx.gd` (effects and ambience), `music.gd` (the soundtrack: crossfades, stingers, ducking), `announcer.gd` (the announcer's voice) and `commentary.gd` (what it says in a match). |
| `net/` | Online play (ADR-056): `lockstep.gd` (inputs and the desync check), `online_session.gd` (the handshake and the match's inputs), `net_link.gd` with `enet_link.gd` (UDP) and `loopback_link.gd` (tests). |
| `scenes/` | `boot.gd` (the first scene: loads a downloaded update's pack, then starts the game; ADR-057), `main.gd` (title, park, matches and the screens between). |
| `meta/` | `save.gd` (two-copy save with migration, layout v6), `settings.gd` (every setting, load/store, match config), `story.gd` (cards, results, quips), `initials.gd` (the record initials card), `career_page.gd` (CAREER's input logic), `lobby.gd` (the multiplayer lobby's logic), `match_stats.gd` (post-match stats), `tournament.gd` (the bracket's logic), `tutorial.gd` (HOW TO PLAY's lessons), `story_mode.gd` (STORY's chapters, matches and progress), `road_trip.gd` (ROAD TRIP: the seeded map, a trip, its gear and the GARAGE), `course.gd` (PICKLEBALL 101's lessons and progress), `achievements.gd` (the achievements, their checks), `museum.gd` (the HAT MUSEUM's input logic), `saved_replays.gd` (REPLAYS' files, ADR-081), `updater.gd` (the in-game updater), `build_info.gd`. |
| `game_ui/` | `controls.gd` (the input map, added by boot as the Controls node; P1..P4 intents, tap latch, SNES pad bits for menus), `bindings.gd` (remapping). |
| `tests/` | Headless runner and suites; `golden/` traces; `golden.gd` regenerates them. |
| `tools/` | `test.sh`, `export.sh`, `version.py`, `release_notes.py`, `release_body.py` (a GitHub release's text), `update_manifest.py` (the updater's manifest), `conformance_import.sh` (the ROM's conformance traces), `make_icon.py`, `sync_assets.sh` (copies `art/levels/out` and the audio in), `encode_ogg.py` (the music and ambience as Ogg, ADR-083), `screenshot.gd` (title pages, matches, `court=`, `time=`, `pause`, `closecall`, `initials`, `result`, `smash`, `bracket`, `bracket_semi`, `bracket_out`, `bracket_won`), `point_log.gd` (why each point ended), `contact_probe.gd` (contact heights and smashes over bot matches). |
| `assets/` | Synced art and audio (don't edit here; rebuild in `art/levels`). |
| `data/` | `opponents.json` and `quips.json` (the ROM's, at TUNING_VERSION 4), `career.json`, `paddles.json`, `court_colors.json`, `venues.json` (as the kit's `data/`), and the port's `dawson.json` (Dale Dawson), `story.json` (STORY's script and Pepper), `announcer.json` (the announcer's clips and lengths) and `pickleball101.json` (PICKLEBALL 101's lessons). |

## Tests and gates

`tools/test.sh` runs every suite headless and fails on any failure or a
test that ran no assertions:

- ported SNES host tests (physics, hits, rules, serve, doubles, match flow);
- golden traces (`tests/golden/`): per-frame hashes of the sim over three
  scripted runs: any change to play shows up;
- stats harness (`test_ladder.gd`): difficulty and ladder order;
- perf gate (`test_perf.gd`): the worst case, named, with headroom;
- conformance (`test_conformance.gd`): the ROM's traces, frame by frame
  (ADR-059);
- view checks: the painted court is the called court, the view never
  writes to the sim, and no text collides (`test_layout.gd`).

A change that is meant to alter play regenerates the traces
(`godot --headless --path game -s res://tests/golden.gd`) and says why in
the commit. Screenshots for visual checks:

```sh
godot --path game --resolution 960x540 -s res://tools/screenshot.gd -- doubles sunset 400 /tmp/shot.png
godot --path game --resolution 960x540 -s res://tools/screenshot.gd -- practice_kitchen park 145 /tmp/practice.png
```
