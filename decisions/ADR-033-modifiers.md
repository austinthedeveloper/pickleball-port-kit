# ADR-033 — Play Modifiers

Status: **Accepted 2026-10-13**
Depends on: ADR-019 (shots), ADR-021/032 (save), ADR-025 (options, slow
ball), ADR-027 (two-tone kitchen).

## Title page

**MODIFIERS** is a title entry between OPTIONS and PRACTICE (SINGLES,
DOUBLES, COURT, RECORDS, OPTIONS, MODIFIERS, PRACTICE). It works like the
OPTIONS page:

- Up/Down picks a row and Left/Right toggles it; both wrap.
- B or Start keeps the change and saves if anything changed. Y puts back the
  old values. The prompt is `@ OK  Y CANCEL`.

| Row | Off | On | What it does |
|---|---|---|---|
| BALL | NORMAL | BIG | A 14 px ball; reach and sweet spot are 4 px larger |
| SPEED | NORMAL | FAST | The ball takes an extra step every 3rd frame (4/3 speed) |
| SCORING | FIRST TO | WIN BY 2 | First to POINTS, but only with a two-point lead |
| KITCHEN | NORMAL | LAVA | Stepping into your own kitchen during a rally loses the point |

- The modifiers combine freely. They are one bit each in
  `MatchConfig.modifiers` and `SaveSettings.modifiers` (`MODIFIER_*`).
  Player Select copies the saved bits into the match, as it does the options.
- The attract demo plays without modifiers. Practice uses BIG and FAST; it
  has no score and no kitchen rule.
- **Not "first to 11":** M4-MOD-01 listed first to 11, but POINTS on the
  OPTIONS page has offered 11 since ADR-025. WIN BY 2 is the rule that
  real games to 11 add.

## Rules and physics

- **BIG BALL:** `g_hit_box` (collision.c) replaces the `HIT_REACH_*` and
  `HIT_SWEET_*` constants in the contact checks and in the CPU's swing
  lookahead, so the CPUs and the KID assist see the same reach. It is
  configured only when the setting changes (`g_hit_box.big`); `main()` sets
  the normal box at boot.
- **FAST BALL:** extends the slow-ball pace of ADR-025. Steps per tick are
  the difficulty's steps plus one on every 3rd tick
  (`modifiers_ball_steps`): MEDIUM and HARD step 16 times in 12 frames, EASY
  13, and KID 12 (a fast KID ball moves at normal speed). Arcs, bounces, and
  landing spots are unchanged; a 40-step shot lands after 30 frames.
  - Two steps in one frame report both steps' events.
  - The pace is a 24-entry table (`g_ball_pace`), built at the start of a
    paced match. The CPU lookahead reads it inline: as three nested calls
    per step, it dropped 106 frames in a 2,400-frame doubles match.
  - The swing early-out counts frames: with FAST BALL, N predicted steps
    are stored as N - N/4 - 1 frames, never more than the real count.
- **WIN BY 2:** `MODIFIERS_SCORE_WINS` decides the match, the crowd's
  match-point volume, and `MATCH POINT` (`game_match_point`). At deuce,
  neither team is on match point.
- **LAVA:** each live frame, a player whose ground point is past their
  kitchen line toward the net (and between the sidelines) loses the point:
  `LAVA!` (`GAME_FAULT_LAVA`, with the fault whistle).
  - CPU intercepts stop 8 px behind the kitchen line
    (`modifiers_lava_target`). CPUs rarely go that far forward anyway (they
    meet the ball 10 px behind its bounce), but a drop shot pulls the
    default CPU to x 155; with LAVA it stops at 175.
  - Humans get no help: staying out is the game.

## Presentation

- **Big ball:** a 32×32 object (OAM 0, large) using the empty sprite-sheet
  slot 11, plus a wider 8×8 shadow (object 11). The OBJ tile count is
  unchanged (208 of 256).
- **Lava kitchen:** the kitchen's two ground entries become
  `g_court_lava_colors`. The asset build derives them from
  `court_colors.json` (`"lava"`) and checks line and ball contrast like
  every other kitchen preset. The court shows lava in a LAVA match and, on
  the title, while the MODIFIERS page is open with KITCHEN on LAVA (a live
  preview); it changes back when the page closes or the match ends.
- `tools/art/author_sprites.py` does not draw the machine (ADR-028) or the
  big ball; both were drawn into the PNGs directly.

## Save

`SaveData` layout 8 adds `modifiers` and a reserved byte. The reserved byte
keeps the checksum at an even offset, so host and SNES layouts match: 42
bytes. Layout 7 (v0.5.0) is frozen as `SaveV7` and migrates with every
field carried over; the modifiers start off (ADR-032's rule).

## Measured

`test_modifiers.c`: bot (the CPU AI, mistiming every 5th shot) against the
default CPU, 12 matches each:

| Modifier | Bot wins | Shots per point |
|---|---:|---:|
| none | 9 | 6.9 |
| BIG BALL | 2 | 5.7 |
| FAST BALL | 0 | 4.2 |
| WIN BY 2 | 9 | 6.7 |
| LAVA | 9 | 6.9 |

- **AI against AI, a big ball shortens rallies:** with a larger sweet spot,
  fewer contacts are stretched, so more shots go where they were aimed:
  deep and 14 px inside a sideline, which is hard to return. Growing only
  the reach, only the sweet spot, or only the height did the same. For a
  human the ball is easier to touch, which is what the modifier is for.
- **Fast ball** favours the default CPU over the bot.
- LAVA changes nothing AI against AI: no CPU stepped into the lava against
  any ladder opponent, in singles or doubles.

## Frame budget

- **Modifiers off:** the golden trace is identical, and the golden, idle,
  and every other `make perf` timeline has zero overruns. Getting there
  meant moving cost off the attract demo's restart frame, which already
  took 222 scanlines (223 overruns): one style lookup per CPU slot,
  no difficulty call at MEDIUM, the hit box configured only on a change,
  and the win rule as a macro. The title's page lookup is now one test.
- **Singles with all four:** zero overruns (`modifiers.timeline`).
- **Doubles with all four:** 26-48 overruns in 2,400 frames, depending on
  the emulator's power-on state (`modifiers_doubles.timeline`; budget 60).
  The same ladder doubles match without modifiers drops 18, and 17 on the
  previous build (KNOWN_ISSUES #14). FAST BALL adds the most: the swing
  lookahead probes up to 10 ball steps instead of 7, and its heaviest stage
  grows from 46 to 57 scanlines.
  *Since then (R15 notes in docs/REFACTOR_PLAN.md):* 7-14, budget 20; the
  same match without modifiers drops none.
- **Back to the title:** after MAIN MENU, the logo waits for a frame under
  `HUD_TITLE_PROMPT_LIMIT`. The demo's light frames there reach about 110,
  the old limit, so whether the logo drew in time or was forced onto a
  heavy frame (235 scanlines) after six waits depended on a fraction of a
  scanline: `pause.timeline` dropped a frame in about half the runs with
  this branch, even with every modifier check compiled out. The limit is
  now 116 (the logo costs about 98, so the frame still ends by about 214):
  no drops in 10 runs.
- The collision and swing-lookahead range checks are now one unsigned
  compare per axis (`HIT_WITHIN`); the probe compiles to 104 lines instead
  of 164.

## Tests

- `test/test_modifiers.c` (host): values and the editor; Player Select
  copies the bits (and the demo has none); step counts per difficulty; the
  fast arc lands in the same place in 30 frames instead of 40; big reach and
  sweet spot; WIN BY 2 through a full match (5-4 plays on, deuce, 5-7
  wins); LAVA faults (on the kitchen line, outside the sidelines, without
  the modifier); the lava colours touch only the kitchen; the drop-shot
  chase; bot matches with each modifier; no CPU in the lava across the
  ladder.
- `test/test_save.c: test_migrate_v7`, and a MesenCE boot from a v7 `.srm`:
  version 8 in RAM and both SRAM copies, every field carried over.
- `test/smoke/modifiers.timeline`: all four on, the lava preview, a
  singles match with the big ball, and P1 walking into the kitchen (LAVA!).
  `modifiers_doubles.timeline`: the same in doubles.
- `options.timeline` now presses Up three times to reach OPTIONS. Its Down
  after OPTIONS had landed on PRACTICE since ADR-028, so it was opening a
  practice session; three Downs now reach SINGLES and its KID match.
