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
| PORT-43 | Rally heat: fire at 10, focus from 15 | `feature/cld-rally-heat` | Ready to test |
| PORT-44 | Story mode: Save the Park | `feature/cld-story` | Ready to test |
| PORT-45 | PICKLEBALL 101: the real game's rules | `feature/cld-pickleball-101` | Ready to test |
| PORT-46 | BALL SPEED slider on MODIFIERS | `feature/cld-ball-speed` | Ready to test |
| PORT-47 | 78% ball by default, BALL SIZE | `feature/cld-ball-defaults` | Ready to test |
| PORT-48 | Longer rallies: CPU ERRORS, the paced ball | `feature/cld-ai-rallies` | Ready to test |
| PORT-49 | The tuning panel (F2, TUNE) | `feature/cld-tuning-panel` | Ready to test |
| PORT-50 | 85% ball speed, 110% ball size by default | `feature/cld-ball-defaults-2` | Ready to test |
| PORT-51 | PLAY OF THE MATCH | `feature/cld-play-of-the-match` | Ready to test |
| PORT-52 | The announcer (voiced, no text) | `feature/cld-announcer-script` | Ready to test |
| PORT-53 | Announcer trims, its switch; the replay's players move | `feature/cld-announcer-trim` | Ready to test |
| PORT-54 | The stands' people move with the camera; achievements | `feature/cld-crowd-parallax`, `feature/cld-achievements` | Ready to test |
| PORT-55 | The announcer's second batch (advantage, deuce, achievements) | `feature/cld-announcer-additions` | In progress |
| PORT-56 | The near-side reach (display only) | `feature/cld-near-reach` | Ready to test |

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

### 42. `feature/cld-cleanup`: cleanup round 4 (asked for 2026-10-19)

- [x] `PORT-42` Organize the files, optimize the code, clean up the docs.
  Docs: one heading per roadmap task (the release notes had dropped
  PORT-37 to 40), the finished tasks moved to the history, the SNES-era
  docs into `design/snes/`, 37 broken links fixed, KNOWN_ISSUES split
  into open, resolved and the SNES game's, the READMEs current. Code: text
  doesn't redraw unchanged, hidden menu pages and the hidden lobby stop
  working every frame, the lobby dresses a card only when it changes,
  palettes.json and manifest.json are read once, the host screen reads
  the adapters once; dead code out; `UiKit`, `PlayerLook.team_sheet` and
  `TestSuite.fresh_save` own what was copied; the AI's and Feel's
  references typed. Then the splits: `title_pages.gd` (the title's page
  tables), `hud_cards.gd` (the HUD's cards), `park_message.gd` (the park's
  panel text), `sim/multi_ball.gd` (MULTI BALL, so `sim.gd` keeps the C's
  shape), and `MenuPage.drive()` for the five copies of the menu keys.
  - Verified: 365/365 plus the e2e, golden and conformance traces
    unchanged; no broken links; screenshots of the title, lobby, park, a
    match, a result and the museum unchanged.
  - Status: **Done**.

### 43. `feature/cld-rally-heat`: rally heat (asked for 2026-10-19)

- [x] `PORT-43` Visual cues for a long rally (ADR-068), display only: at
  10 shots the ball and the RALLY sign catch fire; from 15, and a step
  darker every 5 after, everything but the court dims, the players in a
  spotlight; the point's end lets it go. The ball speeding up as a rally
  goes on is set aside for now.
  - Verified: `test_rally_heat` (thresholds, the cap, fire and focus in a
    held 40-shot rally and out after, none in the demo or MULTI BALL, a
    match plays as a bare sim). 369/369 plus the e2e, golden traces
    unchanged. Screenshots at 12, 25 (LAKESIDE) and 40 shots.
  - Status: **Ready to test**: play a long rally; say if the steps should
    come sooner, go darker, or the fire be bigger.

### 44. `feature/cld-story`: story mode (asked for 2026-10-19)

- [x] `PORT-44` STORY: SAVE THE PARK (ADR-069), the SNES story's plot
  told as a visual novel: eight chapters, one per ladder team, each a
  chapter card, a scene at its venue and time (you and Pepper, the team,
  Grimsby on the loudspeaker or in letters), a doubles match with
  Pepper and the chapter's twist, and the petition signed; the ending,
  THE END, and an epilogue pointing to Dawson. Progress is saved; a
  clear unlocks Dawson.
  - Verified: `test_story_mode` (the script, the configs, the progress,
    the paging, title to scene to match); `test_layout` on every page
    with keyboard and pad prompts. 375/375 plus the e2e, golden traces
    unchanged. Screenshots of a chapter card, a talk page, the
    loudspeaker, a letter, the petition and the title's STORY row.
  - Status: **Ready to test**: play chapter 1; say what to change in
    the writing (`game/data/story.json`), the pacing, or the twists.
  - Fix (`feature/cld-story-paper`): Grimsby's notices and the petition
    were hard to read (the outlined fonts tinted dark ran together); the
    paper's text is now ink: the letters' fill alone, solid, no outline
    (`BitmapText.ink`).

### 45. `feature/cld-pickleball-101`: the real game (asked for 2026-10-19)

- [x] `PORT-45` PICKLEBALL 101 (ADR-070), on PRACTICE: eight lessons on
  real pickleball (the court, the serve, the two-bounce rule, the
  kitchen, keeping score, line calls, playing smart, court manners),
  each page with an animated court diagram, 17 quizzes, TRY IT links to
  the matching HOW TO PLAY drills. Progress saved (DONE, PERFECT).
  - Verified: `test_course` (the data, the real numbers, the progress, a
    lesson, PRACTICE to the course and a drill and back); `test_layout`
    on every page and quiz state with keyboard and pad prompts. 382/382
    plus the e2e, golden traces unchanged. Screenshots of the list, the
    serve's pages, the kitchen, the dink, a score call, a quiz before
    and after, a closing page and PRACTICE.
  - Status: **Ready to test**: read a lesson or two; say if anything
    should be explained differently (`game/data/pickleball101.json`).
  - Added (`feature/cld-rally-scoring-lesson`, the user's note): KEEPING
    SCORE now names side-out as the park's way and adds rally scoring
    (every rally scores; this game plays it; MODIFIERS, RULES, SIDE-OUT
    switches) with a quiz.

### 46. `feature/cld-ball-speed`: ball speed (asked for 2026-10-20)

- [x] `PORT-46` BALL SPEED (ADR-071), MODIFIERS' first row: 70% to 130% in
  1% steps, 100% the ball as it was. A shot lands where it was aimed over
  100 / speed as many frames (so a slower ball also arcs a little
  higher, as MOON does). Saved; every match, drill and online game gets
  it.
  - Verified: `test_ball_speed` (the flight, the sim's setting, a match
    at 90%, the save, lobby, online and the row). 386/386 plus the e2e,
    golden traces unchanged. Screenshot of MODIFIERS.
  - Status: **Ready to test**: try 90% to 95%; say where it feels right
    and I can make that the default.

### 47. `feature/cld-ball-defaults`: the ball's defaults (asked for 2026-10-20)

- [x] `PORT-47` (ADR-072) BALL SPEED defaults to 78% (the user's pick;
  untouched 0.16.0 saves move to it); BALL SIZE, display only, 80-150%,
  105% by default.
  - Verified: `test_ball_speed` (the default, the migration, the size on
    the sprite and shadow, not the reach). 388/388 plus the e2e, golden
    and conformance traces unchanged (they run the ROM's 100%).
    Screenshots of MODIFIERS and a match.
  - Status: **Ready to test**.

### 48. `feature/cld-ai-rallies`: longer rallies (asked for 2026-10-20)

- [x] `PORT-48` (ADR-073) Measured with `tools/rally_stats.gd`. BALL
  SPEED now paces the ball as the ROM does on KID and EASY (same flights,
  slower; ADR-071's higher arcs had made balls unreachable), drawn
  gliding; CPU ERRORS on MATCH SETUP, 50% by default, spaces the CPUs'
  late swings. Doubles rallies at MEDIUM: 8.1 shots (the ROM) to about
  12.5; singles 6.4 to 9.
  - Verified: `test_rallies`, `test_ball_speed`. 391/391 plus the e2e,
    golden and conformance traces unchanged.
  - Status: **Ready to test**: say if rallies should run longer still
    (CPU ERRORS lower) or the CPUs should reach more.

### 49. `feature/cld-tuning-panel`: the tuning panel (asked for 2026-10-20)

- [x] `PORT-49` (ADR-074) F2 or the pause menu's TUNE: a flyout during a
  match, the match waiting. BALL SPEED, BALL SIZE and CPU ERRORS live
  (and saved); every modifier and rule, with APPLY restarting the match
  with them; DEFAULTS. Not online or in the demo.
  - Verified: `test_tuning` (a retuned sim plays as one built so, where
    it is, live sliders, APPLY rebuilds and plays, the pause menu);
    `test_layout`. 397/397 plus the e2e, golden traces unchanged.
    Screenshot over a doubles match.
  - Status: **Ready to test**: say what else belongs on it.

### 50. `feature/cld-ball-defaults-2`: new ball defaults (asked for 2026-10-20)

- [x] `PORT-50` (ADR-072, since) BALL SPEED 85% and BALL SIZE 110% by
  default, the user's picks after playing 0.17.0; untouched saves move
  to them (`ball_speed_v` 2), choices are kept.
  - Verified: `test_ball_speed` (the defaults, saves from 0.16.0 and
    0.17.0 untouched and chosen). `test_rallies` now samples four teams:
    at 85%, CPU ERRORS 50% still lengthens rallies (9.6 to 12.3 there;
    `rally_stats` over 12 matches: doubles 9.0 to 11.2, singles 6.8 to
    10.8). 397/397 plus the e2e, golden traces unchanged.
  - Status: **Ready to test**.

### 51. `feature/cld-play-of-the-match`: PLAY OF THE MATCH (dealer's choice, 2026-10-20)

- [x] `PORT-51` (ADR-075) When a match ends, its longest rally replayed
  television-style (REPLAY bug, card, half-speed finish, how it was won),
  skippable; the real rally, re-run from the recorded inputs by a second
  sim and checked against the live one.
  - Verified: `test_highlight` (exact to the rally's end, through a
    RESTART and a retune; the live match untouched; skip; where it is);
    `test_layout`. 403/403 plus the e2e, golden traces unchanged.
    Screenshots of the card and of a replay.
  - Status: **Ready to test**: finish a match with a long rally. Say if
    it should be optional (a setting), or show a second-best too.

### 52. `feature/cld-announcer-script`: the announcer (asked for 2026-10-20)

- [x] `PORT-52` A voiced 1994 TV announcer, with no text on screen (the
  user: captions would clutter it). Step 1 done: the script,
  `design/announcer/SCRIPT.md` and `lines.csv` (253 lines by trigger:
  the title, venues, teams by their canon players, modifiers, serves and
  aces, score calls built from numbers, rally shots, long rallies, how
  each point ended, streaks and match point, pickle puns, pauses and
  replays, the match's end, the ladder, bracket and story), with the
  recording spec. `make_script.py` makes both. Step 2: the user records
  them with an AI voiceover. Step 3: wiring them to the events, with a
  volume, how often it talks, and ducking.
  - Step 2: the user's recordings, `audio/announcer/raw/` (253, all
    there); `audio/announcer/prep.py` trims them, evens their loudness
    and halves the rate for the game.
  - Step 3 (ADR-076): `view/announcer.gd` (the voice: one line at a
    time by priority, stale lines dropped, variants, the music and crowd
    ducked) and `view/commentary.gd` (what it says, from the match's
    events); ANNOUNCER and COMMENTARY on OPTIONS.
  - Verified: `test_announcer`. 408/408 plus the e2e, golden traces
    unchanged. Screenshot of OPTIONS. Nothing heard here (headless):
    the timing is checked, the sound isn't.
  - Status: **Ready to test**: play a match with sound. Say if it talks
    too much or too little (COMMENTARY), or a line should go.

### 53. `feature/cld-announcer-trim`: after playing 0.19.0 (asked for 2026-10-20)

- [x] `PORT-53` The team intros out (too long); `design/announcer/removed.txt`,
  the list of lines to take out, honoured by `prep.py` (244 clips now);
  ANNOUNCER an ON/OFF switch, VOICE VOLUME its own row (ADR-076, since).
  PLAY OF THE MATCH's players were frozen in the match's end reaction:
  fixed (KNOWN_ISSUES #67, ADR-075, since).
  - Verified: `test_announcer` (no team lines, the switch, a 0.19.0
    save's OFF), `test_highlight` (the replayed players animate; it
    fails without the fix). 409/409 plus the e2e, golden traces
    unchanged. Screenshots of OPTIONS and a replay.
  - Status: **Ready to test**: add any line to `removed.txt` (or tell me
    its id).

### 54. `feature/cld-crowd-parallax`, `feature/cld-achievements` (asked for 2026-10-21)

- [x] `PORT-54` The crowd and the watcher move with the stands as the
  camera leans (KNOWN_ISSUES #68). Achievements (ADR-077): thirteen,
  PICKLED first; a toast and a chime as each unlocks; RECORDS >
  ACHIEVEMENTS lists them with how to earn each.
  - Verified: `test_view` (the stands' people), `test_achievements`,
    `test_layout`. 417/417 plus the e2e, golden traces unchanged.
    Screenshot of ACHIEVEMENTS.
  - Status: **Ready to test**: say which achievements to add next.

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
  - Status: **In progress**: waiting for the recordings.

### 56. `feature/cld-near-reach`: the near-side reach (asked for 2026-10-21)

- [x] `PORT-56` KNOWN_ISSUES #69, the look only (the user's call): a ball on
  the near side of a player gets the low reach and a step down toward it;
  the ROM's hit area is unchanged.
  - Verified: `test_view` (`test_near_side_reach`). 419/419 plus the e2e,
    golden traces unchanged.
  - Status: **Ready to test**.

## For you

Questions and things to try, added as the run goes. Nothing here blocks
the chain: each has a default I've gone with.

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

