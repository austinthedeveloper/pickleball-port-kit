# ADR-052 — Godot port: integer sim, read-only presentation

Status: **Accepted 2026-10-16**
Milestone: `PORT-01`. Depends on: ADR-011 (projection), ADR-018 (doubles),
ADR-019 (shots), ADR-020 (paddles), ADR-023 (opponents), ADR-025 (options),
ADR-044 (charged serve); the 960×540 art (art/levels).

## Decision

The modern port is a Godot 4.7 project in `game/`. Its simulation is a
line-by-line port of the SNES C sim (`reference/snes-src/src`: ball,
collision, player, serve, rules, game flow, main.c's CPU schedule, and
ai.c) to pure GDScript in `game/sim/`, kept integer-exact: 12.4 fixed point
in ints, C's truncating division, and the u8/u16 wraps masked where the C
state wraps. Presentation (`game/view/`) only reads the sim and its event
stream, at the 960×540 art density, through the art's court geometry.

## Why

- **Playbook rule 1.** The C sim is already tuned and tested; porting it
  exactly means its tests and balance numbers port with it, and a golden
  trace protects them from day one.
- **Playbook rule 2.** A read-only view keeps every display feature (art,
  HUD, crowd, sound, animation variants) free of simulation risk; a test
  proves it frame by frame.
- **Determinism for free.** GDScript ints are 64-bit and integer math is
  exact on every platform, so no fixed-point library is needed.

## Details

- **Frame pipeline** (playbook 0.3): human intents → CPU thinks on the
  shipped schedule (singles CPU every frame; a doubles lane cover every
  4th frame staggered by slot; the demo P1 every other frame) →
  `game_update` (players, serve or live play, rules, result phases) →
  events → presentation. `Sim.step()` is the whole sim frame, run at a
  fixed 60 Hz in `_physics_process`.
- **Projection.** World x 16..240, y 90..170 map to the art's court
  (`CourtView`, the manifest's corners); height is scaled per row so the
  12 px net is the painted net. Tests compare the projected corners,
  kitchen lines, and net height with the manifest.
- **Animation variants** (overhead, scoop, reach) are chosen display-side
  at the swing's first frame from the ball height and shot; the sim has
  one swing.
- **Data.** `data/opponents.json` (styles, ladder), `paddles.json`. The
  SNES generator's paddle tables aren't in the kit, so `Paddles` rebuilds
  them from the documented rule (3/64 per point off the baseline); the
  standard paddle is exactly the C constants.
- **Ported:** singles, doubles (ADR-018 lanes and teamwork), shot types,
  the charged serve, paddle stats, opponent styles, difficulty including
  the KID/EASY slow ball and KID's swing assist, the demo, 2P versus,
  modifiers (ADR-033: BIG BALL, FAST BALL, WIN BY 2, LAVA), the save with
  migration (playbook §6; settings, records, ladder), the ladder
  (ADR-023), story cards and quips (ADR-026/048), the camera lean
  with parallax (ADR-050/051, OFF by default), practice (ADR-028), and
  ladder opponents' own looks and hats (M4-OPP-04).
- **Practice** (*amended 2026-10-16*): `sim/practice.gd` is practice.c in
  its order (settings, the page editor, plan/aim/turn/feed, streaks,
  zones). It stays pure: the saved drill and the zone's saved best come in
  on the `MatchConfig` (`SaveGame.practice_config`), and leaving
  (`practice_finish`) is `SaveGame.finish_practice`. `new_match` begins a
  session instead of a serve and `game_update` runs it instead of the
  phases, as game.c does; the crowd's every-fifth cheer is an
  `EVENT_CROWD` event rather than an audio call. MAIN's PRACTICE row
  opens the page (SHOT, TARGET, RATE, RETURN TO, BEST STREAK;
  B plays, Y backs out); the session uses the title's DIFFICULTY. There's
  no Player Select in the port, so P1 plays the standard look and paddle.
  The pause menu is RESUME / MAIN MENU (which saves the best).
  `art/levels` has no ball machine, so `view/practice_view.gd` draws one
  (body, hopper of balls, wheels, a nozzle turning up/centre/down and
  kicking back) and the zone's blinking corners. Save layout v3 adds the
  drill and the bests; a v2 save carries everything over.
- **Opponent looks** (display only). Ladder opponents on slots 2-3 draw
  from the indexed role sheets through `view/palette_swap.gdshader`;
  `PlayerLook` builds the palette from `opponents.json`'s 5-bit colours
  (expanded as `v << 3 | v >> 2`) plus `palettes.json`'s base and the
  member's paddle. The SNES roles have fewer steps than the 960x540
  ones, so the deep shirt (D, the shadow darkened 38%), deep skin (1),
  hair shadow and shine (h, i), bright shorts (W) and shoe shadow (K)
  are derived. Hats are role overlay sheets like the cap, built in
  `art/levels/tools/players.py` after the SNES hats: visor and headband
  in the shoe accent, tricorn in hair with a white trim, bandana in the
  shirt ramp; `hat: "hair"` draws none. Humans and the default CPU keep
  the team-colour sheets.
- **Feel and sound** (display only, PORT-01/02). `view/feel.gd`: shake
  on drives and put-aways, a trail on drive-pace balls, squash on the
  bounce, a whoosh arc, plant dust, each switched in `Feel.ON`.
  `view/audio_map.gd` is audio_events.c as a pure function (pitch by
  shot, pan by court x, applause by rally); `view/sfx.gd` plays it and
  runs the ambience (ADR-031). SOUND = ALL / NO CROWD / OFF.
- **Menus** (PORT-03, ADR-025/030). `view/menu_page.gd` is the one
  settings-row component: rows are dictionaries (id, label, value,
  change, press) driven by move/change/press, so tests select rows by id.
  The title is MAIN (SINGLES, DOUBLES, MATCH SETUP, PRACTICE, MODIFIERS,
  OPTIONS, RECORDS) over sub-pages, each ending in BACK (Y too); a page
  change locks menu input for 6 frames and clears the latch (rule 9).
  MODIFIERS are four ON/OFF toggles saved as `mod_bits` (an older save's
  `mods` preset is read as its bits). OPTIONS: CAMERA, SOUND,
  FULLSCREEN, SCALE (PIXEL = integer stretch, FILL = fractional). The
  pause menu is RESUME / RESTART / MAIN MENU on the same component;
  RESUME hands the sim its own Start, so pausing stays in the sim.
- **Player Select** (PORT-04, ADR-020). `sim/select.gd` is select.c and
  match_config_select; `TitleScreen.config_for` takes the 1P (and 2P)
  choice, then the ladder team on slots 2-3. The team-colour sheets hold
  a paddle in the shirt's colour, so a human whose paddle differs draws
  through `PlayerLook.for_team` (the role sheets in the team palette:
  light skin, brown hair, the cap, the chosen paddle); a test checks the
  role sheet in that palette equals the colour sheet. The 1P choice is
  saved (`settings.player`) and used for ladder rungs and practice.
  2P's screen reads pad 2 (and P1's keys, so one keyboard can set up a
  2P match).
- **Court colours** (PORT-05, ADR-022/027). The HD ground has no
  palette, so `view/court_style.gdshader` recolours by the court mask's
  roles: a pixel becomes its part's preset scaled by its brightness
  against the venue's painted base (the mean of the manifest ramp), the
  per-pixel form of the SNES generator's rule. Choices are preset
  indices per part (`settings.court`), 0 being DEFAULT (SAME for the
  kitchen); all DEFAULT leaves the ground unshaded. VENUE moved from MATCH
  SETUP to the COURT page with them. `data/court_colors.json` is copied
  from the kit.
- **Night** (PORT-06, ADR-045). The time's channel scales go on the
  layers as modulate (dark for the backdrop, stands, fence and front;
  lit for the net), on the crowd sprites (dark), and in the ground shader
  by mask role (lit for roles 3-8, dark for the surround). One
  deviation: the lines take half the lit dimming, since the SNES's 5-bit
  tables round YELLOW on LIME at NIGHT to 2.61 while float scales give
  2.45. Shadows draw grey on a court whose luminance is under 0.02
  (BLACK at any time), from the SNES rule in KNOWN_ISSUES #26. NIGHT's ambience is the
  venue whose `venues.json` loop is the time's (crickets: SUNSET).
- **Close call and watcher** (PORT-07, ADR-041/042). `sim/replay.gd`
  is replay.c; the view checks it when the phase becomes the point
  result (game.c checks on that phase's first frame; the ball hasn't
  moved between). The close-up crops the ground layer (with its court
  material) at 3x instead of the SNES's generated tile blocks, so the
  line keeps its perspective slant. The watcher is the partner's role
  sheet at half size in their palette (the SNES used a park person in
  the captain's palette for lack of a fifth OBJ palette); it hides the
  spectator at the seat it takes.
- **Records and initials** (PORT-08, ADR-021/040). Save layout v4 adds
  the streaks, shutouts, `vs` (wins and losses per ladder team) and
  `initials`; `new_records` and `streak_held` are session-only, as the
  SNES keeps them in WRAM. `meta/initials.gd` is story.c's card, driven
  by SNES pad bits; the view waits under it as under the intro card. The
  ERASE RECORDS row (two presses) stands in for L + R + X.
- **Release** (PORT-09). Export presets for macOS, Windows, Linux and
  Web (the Compatibility renderer, which Web needs). `tools/export.sh`
  refuses uncommitted tracked changes, stamps `build_id.txt` from
  `git describe --always --dirty` (shown on the title), checks the
  platform-free `.pck` boots headless, then exports with the templates.
- **Beyond the SNES** (phase 2, PORT-10..). `Settings` holds every
  setting; the title only edits it. Menus ease, slide and take the
  mouse (`MenuPage`); prompts follow the device and the live bindings
  (`Prompts`, `PromptBar`); screens fade (`scenes/main.gd`). None of it
  touches the sim.
- **Not ported yet:** open play (ADR-034), career (ADR-047).

## Rejected (and why)

- **Floats with a tolerance.** The golden trace and the C balance numbers
  need exact reproduction; ints cost nothing here.
- **A new sim designed for the engine.** It would throw away the tuned
  AI and every test; the C structure (one module per section) is kept so
  a diff against the reference stays readable.
- **GUT for tests.** A 60-line runner keeps the project self-contained and
  fails the run on a script error (a test that runs no assertions fails).
- **Godot physics.** Not deterministic across frames/platforms for this
  use, and the rules are 2D-plus-height arithmetic.

## Verification

`game/tools/test.sh` (headless: 90 tests, then an end-to-end input smoke
that boots the real main scene and plays through the input map):

- Ported C host tests: PHY-01..05, HIT-01/02, RUL-01..03, SCR-01, RST-01
  (20 rematches equal a fresh match), serve setup/boxes, the charged-serve
  sweep (every level, rising and falling, every aim, both teams and
  boxes), shot types, paddle stats, doubles rotation and lane ownership,
  and test_practice.c (settings and the editor; every shot to every target
  lands where asked; the nozzle's turns and AT YOU; each zone's streak
  and its own best; leaving saves). The bot's streaks equal the C's
  exactly: 8 on MIX/RANDOM and 32 with the KID assist alone.
- Balance: a stand-in that mistimes every 2nd shot wins 0/20, every 10th
  18/20 (the C build measured 1 and 19); bot wins by difficulty KID..HARD
  10/6/0/0 of 10; ladder first rung 8 vs last rung 0.
- Golden traces: three scripted runs (singles demo, doubles demo, bot vs
  CPU) × 9000 frames, hashed per frame.
- Presentation: the view's sim equals a bare sim for 1500 frames (and
  with the camera on); the painted court is the called court; every venue
  builds.
- Save: blank, newer copy wins, torn copy falls back, sequence wrap, v1
  migrates, a v2 image migrates to v3 (practice), a future layout is
  rejected. Ladder: a win advances and
  offers the next rung. Story: lines fit the font; quips a third of the
  time, from the right side, never repeated. Modifiers: pace counts, the
  FAST arc (40 steps in 30 frames, same landing), BIG reach, WIN BY 2
  through deuce, LAVA faults and no CPU in the lava.
- Perf gate: worst case named (doubles, four CPUs, KID ball): 159 µs worst
  frame, 4% of a quarter-frame budget.
