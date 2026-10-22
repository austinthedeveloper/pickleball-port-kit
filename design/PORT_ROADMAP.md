# Port roadmap

The milestone sheet for the Godot port. Branches chain, each cut from the
previous one's tip, with the `feature/cld-` prefix; nothing goes to
`main` (you review and merge). When a branch's work is in, its row flips
status in the same commit. The finished tasks, in full, are in
`design/PORT_HISTORY.md`.

**Status:**

- **Done:** automated checks cover it fully (tests, golden traces,
  screenshots), or you've played it and approved it.
- **Ready to test:** it works and is verified, but it needs a human to
  feel or look at it. The row says what to try.
- **Planned / In progress / Blocked:** as written.

**Every branch, before it's marked:**

- `game/tools/test.sh` passes (every suite plus the end-to-end smoke).
- The golden traces are unchanged unless the branch is meant to change
  play. If it is, the commit says why, and an ADR covers it.
- Screenshots of anything visual.
- `design/KNOWN_ISSUES.md` and the relevant ADR are updated.

## Index

| Task | What | Branch | Status |
|---|---|---|---|
| PORT-00 | Merge the two running sessions | | Done |
| PORT-01 | Game feel | `feature/cld-feel` | Ready to test |
| PORT-02 | Sound | `feature/cld-audio` | Ready to test |
| PORT-03 | The menu tree | `feature/cld-menus` | Ready to test |
| PORT-04 | Player Select | `feature/cld-player-select` | Ready to test |
| PORT-05 | Court colours | `feature/cld-court-colors` | Done |
| PORT-06 | Night courts | `feature/cld-night` | Ready to test |
| PORT-07 | The watcher | `feature/cld-watcher-replay` | Ready to test |
| PORT-08 | Records and initials | `feature/cld-records` | Done |
| PORT-09 | Release prep | `feature/cld-release` | Ready to test |
| PORT-10 | Organize the code | `feature/cld-cleanup` | Done |
| PORT-11 | Modern menus | `feature/cld-modern-ui` | Ready to test |
| PORT-12 | Remapping and accessibility | `feature/cld-controls` | Ready to test |
| PORT-13 | Post-match stats | `feature/cld-match-stats` | Ready to test |
| PORT-14 | A livelier HUD | `feature/cld-hud-polish` | Ready to test |
| PORT-15 | Controller support | `feature/cld-controller` | Ready to test |
| PORT-16 | Four players on controllers | `feature/cld-multiplayer` | Ready to test |
| PORT-17 | Open play | `feature/cld-open-play` | Ready to test |
| PORT-18 | HD sounds | `feature/cld-hd-audio` | Done |
| PORT-19 | The park, modernised | `feature/cld-park-redesign` | Done |
| PORT-20 | DINOSAUR, SPACE and UNDERSEA | `feature/cld-fun-venues` | Done |
| PORT-21 | Career players | `feature/cld-career` | Done |
| PORT-22 | Music | `feature/cld-music` | Done |
| PORT-23 | A cleanup round | `feature/cld-cleanup-2` | Done |
| PORT-24 | The overhead | `feature/cld-overhead` | Ready to test |
| PORT-25 | The tournament | `feature/cld-tournament` | Ready to test |
| PORT-26 | The kitchen rule | `feature/cld-kitchen-rule` | Ready to test |
| PORT-27 | Cleanup round 3 | `feature/cld-cleanup-3` | Done |
| PORT-28 | Controller glyphs | `feature/cld-pad-glyphs` | Ready to test |
| PORT-29 | The couch cup | `feature/cld-couch-cup` | Ready to test |
| PORT-30 | How to play | `feature/cld-tutorial` | Ready to test |
| PORT-31 | Online play | `feature/cld-online` | Ready to test |
| PORT-32 | The in-game updater | `feature/cld-updater` | Done |
| PORT-34 | Update at launch, lessons, addresses | `feature/cld-polish-0.9.2` | Ready to test |
| PORT-35 | Catch the sim up to the ROM (TUNING_VERSION 4) | `feature/cld-sim-catchup` | Done |
| PORT-36 | About this project, and Tiny Chair | `feature/cld-about` | In progress |
| PORT-37 | Period-true park: ROOKIE / CLUB / CHAMP, park points | `feature/cld-park` | Ready to test |
| PORT-38 | Career: 13 hats, 16 unlocks, the Hat Museum | `feature/cld-hats` | Ready to test |
| PORT-39 | The show: rings, celebrations, critters, quips | `feature/cld-show` | Ready to test |
| PORT-40 | The Pickleball '95 promises | `feature/cld-sideout` ... | In progress |
| PORT-41 | Four swings and the short hold | `feature/cld-four-shots` | Ready to test |
| PORT-42 | Cleanup round 4: files, code, docs | `feature/cld-cleanup` | Done |
| PORT-43 | Rally heat: fire at 10, focus from 15 | `feature/cld-rally-heat` | Released (v0.14.0) |
| PORT-44 | Story mode: Save the Park | `feature/cld-story` | Released (v0.15.0) |
| PORT-45 | PICKLEBALL 101: the real game's rules | `feature/cld-pickleball-101` | Released (v0.15.0) |
| PORT-46 | BALL SPEED slider on MODIFIERS | `feature/cld-ball-speed` | Released (v0.16.0) |
| PORT-47 | 78% ball by default, BALL SIZE | `feature/cld-ball-defaults` | Released (v0.17.0) |
| PORT-48 | Longer rallies: CPU ERRORS, the paced ball | `feature/cld-ai-rallies` | Released (v0.17.0) |
| PORT-49 | The tuning panel (F2, TUNE) | `feature/cld-tuning-panel` | Released (v0.17.0) |
| PORT-50 | 85% ball speed, 110% ball size by default | `feature/cld-ball-defaults-2` | Released (v0.18.0) |
| PORT-51 | PLAY OF THE MATCH | `feature/cld-play-of-the-match` | Released (v0.18.0) |
| PORT-52 | The announcer (voiced, no text) | `feature/cld-announcer-script` | Released (v0.19.0) |
| PORT-53 | Announcer trims, its switch; the replay's players move | `feature/cld-announcer-trim` | Released (v0.19.1) |
| PORT-54 | The stands' people move with the camera; achievements | `feature/cld-crowd-parallax`, `feature/cld-achievements` | Released (v0.20.0) |
| PORT-55 | The announcer's second batch (advantage, deuce, achievements, specials, power-ups) | `feature/cld-announcer-additions`, `feature/cld-announcer-specials`, `feature/cld-voices-ash` | Done |
| PORT-56 | The near-side reach (display only) | `feature/cld-near-reach` | Released (v0.20.0) |
| PORT-57 | The title's RECORD line; OPEN PLAY's locations and the GYM | `feature/cld-title-record`, `feature/cld-park-locations` | Released (v0.21.0) |
| PORT-58 | Local multiplayer: any split, the modes as tabs; the player tags | `feature/cld-lobby-sides`, `feature/cld-player-tags` | Released (v0.21.0) |
| PORT-59 | Cleanup round 5: branches, code, docs | `feature/cld-cleanup-5` | Done |
| PORT-60 | The park: paddles a player, winners staying said | `feature/cld-park-stacking` | Released (v0.21.1) |
| PORT-61 | The swing-arm ball machine | `feature/cld-ball-machine` | Released (v0.22.0) |
| PORT-62 | Player specials and powerups: a running design doc | `feature/cld-specials-doc` | In progress |
| PORT-63 | Practice without the announcer | `feature/cld-practice-quiet` | Released (v0.22.1) |
| PORT-64 | The title menu regrouped: five places to go | `feature/cld-menu-regroup` | Released (v0.23.0) |
| PORT-65 | SPECIALS: the meter and PICKLE SMASH | `feature/cld-specials` | Released (v0.24.0) |
| PORT-66 | Effects: bounce marks, camera flashes, the net cord | `feature/cld-effects` | Ready to test |

## Releases

- **v0.1.0** (2026-10-17): PORT-00 to PORT-15, the first versioned
  release (`game/CHANGELOG.md`, `design/VERSIONING.md`). Tag `v0.1.0`, on
  `feature/cld-release-0.1.0`; GitHub release published (source only,
  since there are no export templates here yet).
- **v0.2.0** (2026-10-17): PORT-16 multiplayer. Tag `v0.2.0`, on
  `feature/cld-release-0.2.0`; GitHub release published (source only).
- **v0.2.1** (2026-10-17): the first release with builds (macOS, Windows,
  Linux, Web). Godot's export templates are now installed here, and a
  macOS export setting is fixed. Tag `v0.2.1`, on
  `feature/cld-release-0.2.1`.
- **v0.3.0** (2026-10-17): PORT-17 open play. The first release built and
  published by CI (tag `v0.3.0`, on `feature/cld-release-0.3.0`).
- **v0.3.1** (2026-10-17): text and layout fixes, with a layout test
  over every screen (tag `v0.3.1`, on `feature/cld-release-0.3.1`).
- **v0.4.0** (2026-10-17): PORT-18 HD sound (tag `v0.4.0`, on
  `feature/cld-release-0.4.0`).
- **v0.5.0** (2026-10-17): PORT-19 the park, modernised (tag `v0.5.0`, on
  `feature/cld-release-0.5.0`).
- **v0.6.0** (2026-10-18): PORT-20 the fun venues, PORT-21 career, PORT-22
  music, merged and fixed on `feature/cld-integration-0.6` (tag `v0.6.0`,
  on `feature/cld-release-0.6.0`).
- **v0.7.0** (2026-10-18): PORT-23 the cleanup round, PORT-24 the
  overhead, PORT-25 the tournament (tag `v0.7.0`, on
  `feature/cld-release-0.7.0`).
- **v0.8.0** (2026-10-18): PORT-26 the kitchen rule, PORT-27 cleanup round
  3, PORT-28 controller glyphs, PORT-29 the couch cup, PORT-30 how to
  play, PORT-31 online play (tag `v0.8.0`, on `feature/cld-release-0.8.0`).
- **v0.8.1** (2026-10-18): the HOST screen offers only reachable addresses
  (KNOWN_ISSUES #55; tag `v0.8.1`, on `feature/cld-release-0.8.1`).
- **v0.9.0** (2026-10-18): PORT-32 the in-game updater; the first release
  with the .pck and manifest it downloads (tag `v0.9.0`, on
  `feature/cld-release-0.9.0`).
- **v0.9.1** (2026-10-18): CAMERA starts at 50%; the first release to
  arrive through the in-game updater (tag `v0.9.1`, on
  `feature/cld-release-0.9.1`).
- **v0.9.2** (2026-10-18): PORT-34 update at launch, lessons, addresses
  (tag `v0.9.2`, on `feature/cld-release-0.9.2`).
- **v0.9.3** (2026-10-18): PORT-41 the four swings and the short hold
  (tag `v0.9.3`, on `feature/cld-release-0.9.3`).
- **v0.10.0** (2026-10-18): PORT-35 the sim caught up to the ROM, PORT-36
  About this project, PORT-37 the period-true park, PORT-38 the hats and
  the Hat Museum (tag `v0.10.0`, on `feature/cld-release-0.10.0`).
- **v0.11.0** (2026-10-18): PORT-39 the show (tag `v0.11.0`, on
  `feature/cld-release-0.11.0`).
- **v0.12.0** (2026-10-19): PORT-40 part one, the '95 promises: side-out
  scoring, the momentum rule, MOON, BOUNCY, WIND, DINK OR DIE, SUDDEN
  DEATH, Dale Dawson (tag `v0.12.0`, on `feature/cld-release-0.12.0`).
- **v0.12.1** (2026-10-19): online, the host's Ethernet address labelled
  and listed first (KNOWN_ISSUES #65; tag `v0.12.1`, on
  `feature/cld-release-0.12.1`).
- **v0.12.2** (2026-10-19): fuller backdrops, LAKESIDE's lake and town
  and the PARK and SUNSET skylines across the width (KNOWN_ISSUES #66;
  tag `v0.12.2`, on `feature/cld-release-0.12.2`).
- **v0.13.0** (2026-10-19): MULTI BALL (PORT-40, ADR-067) and the
  SCREEN SHAKE strength (KNOWN_ISSUES #58; tag `v0.13.0`, on
  `feature/cld-release-0.13.0`).
- **v0.13.1** (2026-10-19): PORT-42, cleanup round 4 (tag `v0.13.1`, on
  `feature/cld-release-0.13.1`).
- **v0.14.0** (2026-10-19): PORT-43 rally heat (tag `v0.14.0`, on
  `feature/cld-release-0.14.0`).
- **v0.15.0** (2026-10-19): PORT-44 story mode and PORT-45 PICKLEBALL
  101 (tag `v0.15.0`, on `feature/cld-release-0.15.0`).
- **v0.15.1** (2026-10-20): the story's paper in ink, rally scoring in
  KEEPING SCORE (tag `v0.15.1`, on `feature/cld-release-0.15.1`).
- **v0.16.0** (2026-10-20): PORT-46 BALL SPEED (tag `v0.16.0`, on
  `feature/cld-release-0.16.0`).
- **v0.17.0** (2026-10-20): PORT-47 78% ball and BALL SIZE, PORT-48
  longer rallies, PORT-49 the tuning panel (tag `v0.17.0`, on
  `feature/cld-release-0.17.0`).
- **v0.18.0** (2026-10-20): PORT-50 85% ball and 110% size by default,
  PORT-51 PLAY OF THE MATCH (tag `v0.18.0`, on
  `feature/cld-release-0.18.0`).
- **v0.19.0** (2026-10-20): PORT-52 the announcer (tag `v0.19.0`, on
  `feature/cld-release-0.19.0`).
- **v0.19.1** (2026-10-20): PORT-53 announcer trims and switch, the
  replay's players move (tag `v0.19.1`, on `feature/cld-release-0.19.1`).
- **v0.20.0** (2026-10-21): PORT-54 the stands' people and achievements,
  PORT-55's fallbacks (its lines still to record), PORT-56 the near-side
  reach (tag `v0.20.0`, on `feature/cld-release-0.20.0`).
- **v0.21.0** (2026-10-21): PORT-57 the RECORD line, DINO PARK, THE GYM
  and the GYM venue; PORT-58 the lobby's splits and tabs, the player tags
  (tag `v0.21.0`, on `feature/cld-release-0.21.0`).
- **v0.21.1** (2026-10-21): PORT-60 the park's paddles a player, winners
  staying said (tag `v0.21.1`, on `feature/cld-release-0.21.1`).
- **v0.22.0** (2026-10-21): PORT-61 the swing-arm ball machine (tag
  `v0.22.0`, on `feature/cld-release-0.22.0`).
- **v0.22.1** (2026-10-21): PORT-63 practice without the announcer (tag
  `v0.22.1`, on `feature/cld-release-0.22.1`).
- **v0.23.0** (2026-10-21): PORT-64 the title menu regrouped (tag
  `v0.23.0`, on `feature/cld-release-0.23.0`).
- **v0.24.0** (2026-10-21): PORT-65 SPECIALS, the meter and PICKLE SMASH
  (tag `v0.24.0`, on `feature/cld-release-0.24.0`).
- **v0.25.0** (2026-10-21): PORT-55 the announcer re-recorded, with the
  second batch (tag `v0.25.0`, on `feature/cld-release-0.25.0`).

## Phase 5: the bible (planned 2026-10-18)

From the project lead's canon bible v0.3 (`../pickleball/docs/PICKLEBALL_94_BIBLE.md`):
the remaster is "faithfully remastered" with the '95 features delivered,
so it must do what the ROM does, and the ROM has moved on 22 decisions
since the port was copied at 0.18.1. `design/BIBLE_PLAN.md` has the gap
list, fact by fact. The order puts the sim first: once it matches the ROM
frame for frame (the SNES repo's conformance traces), the rest copies the
ROM instead of guessing.

```
feature/cld-release-0.9.2   (v0.9.2)
 35 catch the sim up to the ROM
 36 about this project, Tiny Chair
 37 period-true park
 38 career and the Hat Museum
 39 the show
 40 the '95 promises
```

Done and moved to `design/PORT_HISTORY.md`: 35, 37, 38, 39 (and 41, from
the same request). Open: 36 and 40.

### 36. `feature/cld-about`: about this project, and Tiny Chair

- [x] `PORT-36` About this project, and Tiny Chair: the bible's ground
  rule 1 note, and a Tiny Chair splash in the A-11 colours after a name
  search.
  - Done: `ABOUT.md` (the game is real, its 1993 history invented; no
    real brands; not affiliated with Nintendo), linked from both READMEs
    and every new release's notes (`tools/release_body.py`). It names no
    studio: Tiny Chair, Ferry Dock and Sunvale all wait on the bible's name
    search. The game keeps its fiction (the rule is about release pages).
  - Status: **In progress**: the splash waits on the name search and the
    logo's final art (bible A-11); the releases already published don't
    carry the line (For you).

### 40. `feature/cld-sideout`: the Pickleball '95 promises (and the branches after it)

- [x] `PORT-40` The Pickleball '95 promises (bible §5.8): Dale Dawson as an
  unlockable (§3), side-out scoring, the momentum rule, new modifiers;
  the overhead smash is already in (PORT-24).
  - Done: side-out scoring (ADR-063: MODIFIERS > RULES > SIDE-OUT; the
    scoring rules got their own RULES page); the momentum rule (ADR-064:
    RULES > MOMENTUM); MOON, BOUNCY, WIND, DINK OR DIE and SUDDEN DEATH
    (ADR-065); Dale Dawson (ADR-066: unlocked by a ladder clear, on VS;
    plays doubles alone and fast); MULTI BALL (ADR-067: RULES > MULTI
    BALL). Left: the line judge, the club manager.
  - Status: **In progress**.

### 55. `feature/cld-announcer-additions`: the announcer's second batch (asked for 2026-10-21)

- [ ] `PORT-55` A second list to record, `design/announcer/ADDITIONS.md`
  and `additions.csv` (17 lines, `make_additions.py` makes both): under
  WIN BY 2 past game point, advantage (serving or receiving side) and
  deuce; an achievement's line as it unlocks. The game already asks for
  them and falls back to what it said before ("win by two", nothing) until
  they're in `audio/announcer/raw/`. Score calls need nothing new: the
  numbers go to twenty-five.
  - Verified: `test_announcer` (the extension, the fallback, a recorded
    batch said). 418/418 plus the e2e.
  - 2026-10-21, `feature/cld-announcer-specials`: now 54 lines. Added
    SPECIALS' (the intro, a meter filling, PICKLE SMASH, its pop-up
    return, a smash that wins or sets up the point; wired, with a smash's
    line as the fallback), the other six achievements' own lines, and
    twelve power-up lines for later (not wired: power-ups aren't built).
    GLOBETROTTER's line no longer counts venues (there are seven now).
    `test_announcer.test_the_specials_lines`.
  - 2026-10-21, `feature/cld-voices-ash`: the user re-recorded the whole
    script in one voice (298 clips: the first batch and the additions,
    no team intros) and they replace the old ones. The new takes run
    longer, so the big in-rally calls get more room (rally counts up to
    4 s, PICKLE SMASH 3 s; a shot's call still 1.3 s). `test_announcer`
    now asks for every second-batch line.
  - Status: **Done** (the power-up lines wait for power-ups).


### 59. `feature/cld-cleanup-5`: cleanup round 5 (asked for 2026-10-21)

- [x] `PORT-59` The local branches merged into `origin/main` deleted (73;
  the two still checked out in agent worktrees, both merged, stay until
  those are cleaned up). The code: the three sliders (BALL SPEED, BALL
  SIZE, CPU ERRORS) defined once (`Settings.SLIDERS`, `Settings.nudge`,
  `view/setting_rows.gd`) for the title and the tuning panel; PLAY OF THE
  MATCH's event handling in `highlight.gd`, out of `match_view.gd`; a
  dead `Announcer.speak_ids`; `TestSuite.match_view` for the tests' match
  setup. The docs: PORT-42 to 58 (but 55) moved to `PORT_HISTORY.md`, the
  index naming each task's release; `decisions/README.md`, an index of
  the ADRs; the bible plan's list of the remaster's own additions; the
  README's file layout.
  - Verified: 423/423 plus the e2e, golden traces unchanged; the release
    notes regenerate the same (57 of 58 tasks); MODIFIERS and the tuning
    panel unchanged on screen.
  - Status: **Done**.

### 60. `feature/cld-park-stacking`: the park's stack and winners staying (asked for 2026-10-21)

- [x] `PORT-60` KNOWN_ISSUES #71: the rack draws a pair of paddles for
  each waiting team (one a player, as real stacking reads), the panel
  counts the teams ahead of you, and a win that keeps you on says so
  (WINNERS STAY ON, then YOU STAY ON COURT n with STEP OFF at its rack).
  The park's rules (SNES ADR-070 to 072) are unchanged.
  - Verified: `test_open_play` (27, with `test_staying_on_is_said`).
    424/424 plus the e2e, golden traces unchanged. Screenshots of the rack
    and the panel.
  - Status: **Released (v0.21.1)**.

### 61. `feature/cld-ball-machine`: the swing-arm ball machine (asked for 2026-10-21)

- [x] `PORT-61` KNOWN_ISSUES #34: practice's machine is row C of
  `art/concept/ball-machine.png`, a cart with a hopper of balls and a
  launcher arm on a pivot, built in Aseprite (`art/sprites/machine`:
  `machine.py` draws the layers, `build_machine.lua` makes
  `machine.aseprite` and the sheet). The arm has nine angles and swings
  through them toward the sim's pose (up, centre, down) instead of
  snapping; it recoils along itself on a feed. Display only: the sim's
  poses and feeds are unchanged.
  - Verified: `test_practice.test_machine_arm_swings`; 425/425 plus the
    e2e, golden traces unchanged. Screenshots in practice at the park.
  - Status: **Ready to test**.

### 62. `feature/cld-specials-doc`: player specials and powerups (asked for 2026-10-21)

- [ ] `PORT-62` `design/SPECIALS_AND_POWERUPS.md`, a running document:
  a SPECIAL button with a meter (route A), powerups on the court (route
  B), or both (route C, the pick so far); specials by paddle, with the
  '95 overhead smash as PICKLE SMASH; the first powerup list. Nothing
  built yet.
  - Status: **In progress** (waiting on the questions in the doc).

### 63. `feature/cld-practice-quiet`: practice without the announcer (asked for 2026-10-21)

- [x] `PORT-63` KNOWN_ISSUES #72: no announcer in practice. With no
  points there, its rally lines counted the machine's feeds, missed or
  not, as one long rally. Lessons and matches are unchanged.
  - Verified: `test_announcer.test_practice_is_quiet`; 426/426 plus the
    e2e, golden traces unchanged.
  - Status: **Released (v0.22.1)**.

### 64. `feature/cld-menu-regroup`: the title menu regrouped (asked for 2026-10-21)

- [x] `PORT-64` ADR-079: MAIN is STORY, PLAY, PRACTICE, PLAYER and
  OPTIONS (was twelve rows). PLAY has QUICK MATCH (SINGLES or DOUBLES,
  one row), TOURNAMENT, OPEN PLAY and MULTIPLAYER; QUICK MATCH opens
  MATCH SETUP (START, MODE, PLAYERS, VS, DIFFICULTY, CPU ERRORS, POINTS,
  COURT, MODIFIERS); PLAYER has the players, RECORDS, ACHIEVEMENTS and
  the HAT MUSEUM. BACK goes to the page you came from; after a match the
  title opens where it started (MATCH SETUP after a quick match).
  Mocked up first with the game's panels, then built as mocked.
  - Verified: `test_menus` (the whole tree, and coming back after a
    match), the suites that walked MAIN now reach rows by id
    (`TitleScreen.reveal`), `test_layout` on every page; 427/427 plus the
    e2e (now through MATCH SETUP), golden traces unchanged. Screenshots
    of MAIN, PLAY, MATCH SETUP and PLAYER.
  - Status: **Released (v0.23.0)**.

### 65. `feature/cld-specials`: SPECIALS, the meter and PICKLE SMASH (asked for 2026-10-21)

- [x] `PORT-65` ADR-080: SPECIALS on RULES (off by default, off in the
  ROM's game). Each player's meter fills with shots, points won and time
  in a rally; SPECIAL (O, the right trigger) spends a full one on PICKLE
  SMASH: twice a drive's pace, never stretched, always over the net,
  aimed deep away from the other side, and its return pops up soft (the
  knock-back). The CPUs use it too. Meters under the score panels, a
  PICKLE SMASH prompt, the PICKLE SMASH! pop.
  - Verified: `test_specials` (10: off by default, the fills, spending,
    the flight, the knock-back, the CPUs, not in practice or MULTI BALL,
    online's packing, the meters display only), `test_shots` and
    `test_controls` (the trigger, SHORT still LB or RB), `test_layout`
    (the meters and prompts); 436/436 plus the e2e, golden traces
    unchanged. `rally_stats` with mods=131072: the smasher's side wins 56%
    (doubles) and 79% (singles) of rallies with a smash. Screenshots of
    the meters and a PICKLE SMASH.
  - Status: **Released (v0.24.0)**.

### 66. `feature/cld-effects`: three light effects (asked for 2026-10-22)

- [x] `PORT-66` `view/court_effects.gd`, display only and deterministic:
  a scuff where the ball bounces, fading over four seconds (a dozen at
  most); camera flashes among the crowd at the big moments (a 15, 20, 25
  or 30-shot rally, PICKLE SMASH, match point, the match won), none with
  FLASHES off or in the demo; the net wobbles (a couple of pixels) when a
  ball clips the tape and carries over, with the net's sound, and when one
  goes into it. A few shapes a frame each, no new shaders or particles.
  - Verified: `test_feel` (the marks, the flashes and FLASHES off, the net
    cord and settling; the view against a bare sim); 440/440 plus the
    e2e, golden traces unchanged. Screenshots of the marks and a burst of
    flashes (`screenshot.gd ... camflash`).
  - Status: **Ready to test**.

## For you

Questions and things to try, added as the run goes. Nothing here blocks
the chain: each has a default I've gone with.

- **PORT-65 SPECIALS:** PICKLE SMASH's strength is a first guess
  (ADR-080 has the numbers and the knobs). Say if it should win more or
  less often, or fill faster or slower.

- **PORT-62 specials and powerups:** four questions at the end of
  `design/SPECIALS_AND_POWERUPS.md` (route A, B or C; specials by paddle
  or by character; canon '95 feature or party mode; GOLDEN BALL).

- **PORT-52 announcer:** the canon bible has no announcer; this one is
  the remaster's, unnamed. Say if they should have a name, or if any line
  doesn't suit the game. The lines are in `design/announcer/SCRIPT.md`.

- **PORT-44 story:** the script is mine, from the canon plot. The bible
  names Pepper and Grimsby but not the chapters' twists or titles; say
  if any should change. Pepper's look is the SNES story.json's.

- **PORT-40 Dale Dawson:** the bible marks his name "[PROPOSED; name
  search required]"; he's data (`game/data/dawson.json`) if it changes.
  His look (red shirt, headband, wood paddle) and lines are mine to start.

- **PORT-20 fun venues:** the art is generated, like the other levels,
  with no hand pass. Say if a creature should be bigger, or if the
  onlookers should be creatures only (four people stand among them, so the
  watcher has company). At NIGHT the crickets play at SPACE and UNDERSEA
  too, as ADR-045 has it; each venue could keep its own loop at night
  instead.

- **PORT-22 music:** I can't hear these either: they were checked by
  measuring levels, seams and keys. Tell me which tracks are off (tempo,
  a voice too loud or too bright, a melody you'd change, too busy under
  play) and I'll rework them in `make_music.py`. The whole soundtrack's
  level against the effects is `Music.BASE_DB` (-9 dB); the duck is
  `Music.DUCK_DB`.

- **PORT-24 overhead:** the line is 20 px (the top of the reach is 24),
  falling balls only, and any HIT or DRIVE there smashes. It's automatic
  so a lob you get under is always punishable; if you'd rather DRIVE only
  smash (HIT a gentler overhead), it's one line. The swing's animation is
  guessed at the windup (a ball over 17 px), so a drive at a ball 18-19 px
  up can show the overhead frames without smashing (KNOWN_ISSUES #49).

- **PORT-25 tournament:** you're the top seed, so the first round is the
  easiest team in the draw; a random draw would be more of a lottery (say
  if you'd prefer it). The other teams' matches are decided by odds from
  the ladder, not played (ADR-054 says why). Matches use MATCH SETUP's
  points; finals could be longer (to 15 or win by 2) if you want them to
  feel bigger.

- **PORT-29 couch cup:** the humans are the top seeds, so with four of
  you the CPU teams in the draw are the four strongest. Two of you can't
  meet before the semis (four: before the semis either). A cup uses MATCH
  SETUP's difficulty and points like the lobby's matches. Say if you'd
  rather draw humans at random.

- **PORT-30 how to play:** the SMASH lesson is the hard one: the overhead
  window (a ball 20-24 px up, falling) is short against a steep lob, so a
  scripted player finds it on 9 of 200 tries. The card says where to
  stand and when; the goal is one smash. If it's still too fiddly, the
  machine's lob could come down flatter in that lesson, or the overhead
  line could drop a little (a sim change, ADR-053).

- **PORT-31 online:** played between two computers on one network
  (2026-10-18 and 2026-10-19, KNOWN_ISSUES #55, #65); room codes through
  a relay are set aside until you want to pay for hosting. Tell me the
  round trip you get (if it feels laggy, rollback
  is the next step, ADR-056) and anything that goes wrong, with the
  message the screen shows. The guest plays on the right side of the
  court; flipping the view so each of you is on the left is possible.

- **Phase 5, the bible:** two questions still open.
  1. **The park's sign says RIVERDALE PARK** in the remaster's art. The
     bible keeps Riverdale [OPEN] and off anything that claims the game
     calls it that (Q10). Keep the sign, or blank it until you decide?
  2. **The menus.** The ROM's nine title entries have a set order (SNES
     ADR-065); the port's menus are its own. I'd keep the port's (it has
     more modes), unless you want the ROM's order.

- **PORT-36 about:** releases 0.1.0 to 0.9.3 are public without the
  "About this project" line (new ones carry it). I can add it to each
  published release's notes with `gh release edit`; that changes public
  pages, so it waits for your OK. And the Tiny Chair splash waits on the
  bible's name search and the logo's final art.

