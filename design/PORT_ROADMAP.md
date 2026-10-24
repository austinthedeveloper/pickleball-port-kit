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
| PORT-66 | Effects: bounce marks, camera flashes, the net cord | `feature/cld-effects` | Released (v0.26.0) |
| PORT-67 | The players' new body: a V torso, longer legs, a forehand with the body in it | `feature/cld-player-hd-body-v2` | Released (v0.27.0) |
| PORT-68 | SPECIALS' meters under the players | `feature/cld-meters-under-players` | Released (v0.28.0) |
| PORT-69 | Saved replays: SAVE LAST RALLY, REPLAYS, and in the demo | `feature/cld-saved-replays` | Released (v0.28.0) |
| PORT-70 | SAVE on PLAY OF THE MATCH | `feature/cld-potm-save` | Released (v0.29.0) |
| PORT-71 | Replays trimmed to the rally: from the serve, no pauses | `feature/cld-replay-trim` | Released (v0.30.0) |
| PORT-72 | Pads: L is SHORT, R is SPECIAL, the triggers mirror them | `feature/cld-pad-mapping` | Released (v0.31.0) |
| PORT-73 | Generic pads (SNES USB): MAP BUTTONS, saved per pad | `feature/cld-pad-mapping` | Released (v0.31.0) |
| PORT-74 | "A controller is recommended" at startup | `feature/cld-pad-mapping` | Released (v0.31.0) |
| PORT-75 | Smaller audio: the music and ambience as Ogg (the `.pck` 34 to 18.5 MB) | `feature/cld-audio-compare` | Released (v0.31.0) |
| PORT-76 | DINOSAUR and DINO PARK: the Carnotaurus (with Nathan) wanders, with the dinosaur game's Spinosaurus, baby and pterodactyl | `feature/cld-dino-park-dinosaurs` | Released (v0.32.0) |
| PORT-77 | The dinosaur game's levels as courts: RUINS, GLACIER, LAB, STATION | `feature/cld-dino-levels` | Released (v0.32.0) |
| PORT-78 | Keyboard controls you can guess: a WASD + J K L preset and an arrows + Z X C one, keys drawn where they sit | `feature/cld-keyboard-layout` | Planned (parked: you're thinking it over) |
| PORT-79 | Text centred in the menu bars and the prompts' keys | `feature/cld-text-centring` | Ready to test |
| PORT-80 | Cleanup round 6: one copy of the shot effects, the title's way back, the dinosaurs' looks; tests for the gaps | `feature/cld-cleanup-6` | Done |
| PORT-82 | ROAD TRIP: a roguelike mode beside STORY, a road map of branching stops, a match at each, gear to pick, a garage between trips (a plan: `design/ROAD_TRIP.md`) | `feature/cld-story-roguelike` | Planned (answered; stage 1 on your go) |

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
- **v0.26.0** (2026-10-22): PORT-66 bounce marks, camera flashes, the net
  cord (tag `v0.26.0`, on `feature/cld-release-0.26.0`).
- **v0.27.0** (2026-10-22): PORT-67 the players' new body and forehand
  (tag `v0.27.0`, on `feature/cld-release-0.27.0`).
- **v0.28.0** (2026-10-22): PORT-68 the SPECIALS meters under the players,
  PORT-69 saved replays (tag `v0.28.0`, on `feature/cld-release-0.28.0`).
- **v0.29.0** (2026-10-22): PORT-70 SAVE on PLAY OF THE MATCH (tag
  `v0.29.0`, on `feature/cld-release-0.29.0`).
- **v0.30.0** (2026-10-22): PORT-71 replays trimmed to the rally (tag
  `v0.30.0`, on `feature/cld-release-0.30.0`).
- **v0.31.0** (2026-10-22): PORT-72 L for SHORT and R for SPECIAL, PORT-73
  generic pads mapped, PORT-74 a controller recommended, PORT-75 smaller
  audio (tag `v0.31.0`, on `feature/cld-release-0.31.0`).
- **v0.32.0** (2026-10-22): PORT-76 the Carnotaurus and friends at
  DINOSAUR and DINO PARK, PORT-77 RUINS, GLACIER, LAB and STATION (tag
  `v0.32.0`, on `feature/cld-release-0.32.0`).

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

### 62. `feature/cld-specials-doc`: player specials and powerups (asked for 2026-10-21)

- [ ] `PORT-62` `design/SPECIALS_AND_POWERUPS.md`, a running document:
  a SPECIAL button with a meter (route A), powerups on the court (route
  B), or both (route C, the pick so far); specials by paddle, with the
  '95 overhead smash as PICKLE SMASH; the first powerup list. Nothing
  built yet.
  - Status: **In progress** (waiting on the questions in the doc).

### 78. `feature/cld-keyboard-layout`: keyboard controls you can guess (asked for 2026-10-23, parked)

- [ ] `PORT-78` The keyboard layout (`game_ui/controls.gd`) grew one SNES
  button at a time: hit Space/J, drive K, soft L, slice I, short
  Shift/U, special O, so nothing about where the keys sit says which shot
  is which, and the prompts show the first key only (SHIFT, not the U I O
  over J K L grid). There's no single standard, but two conventions:
  emulators (RetroArch, Snes9x: arrows, Z = B, X = A, A = Y, S = X,
  Q/W = L/R, Enter = Start) and PC action games (WASD, the common actions
  on J K L, the rare ones on U I O). The proposal: two presets on
  CONTROLS, on top of REBIND (`game_ui/bindings.gd`):

  | | WASD (default) | Arrows |
  |---|---|---|
  | Hit | J | Z |
  | Drive | K | X |
  | Soft | L | C |
  | Slice | I | S |
  | Special | O | D |
  | Short (held) | Shift or Space | Shift |

  The three shots in one row in one order, the rarer ones on the row
  above. And the lesson cards draw the keys where they sit (a little
  keyboard) instead of a line of names.
  - Needs: an ADR (new defaults), `test_controls` and the prompts, a
    save with remapped keys still loading (a preset is a saved key with a
    harmless default, so no new layout version), `test_layout` cases for
    the card and the preset row.
  - Status: **Planned**, parked until you've decided the layout.

### 79. `feature/cld-text-centring`: text centred in the bars and keys (asked for 2026-10-23)

- [x] `PORT-79` Known issue 77: the menus' highlight bar, MAP BUTTONS'
  bar and the prompts' keys had their text about 3 px low (the offsets
  didn't allow for the small font's outline and shadow). The bars start
  2 px above the letters (the change arrows and the mouse's row bands
  follow), keys and pills are 24 px tall with a 2 px lip, and the key
  letters and their labels share one height (`PromptBar.TEXT_Y`). Display
  only, no ADR.
  - Verified: 470/470 plus the e2e, golden traces unchanged; before and
    after screenshots of the title and a practice match.
  - Status: **Ready to test**: look at any menu and the prompts, and at
    a pad's prompts (the round buttons' letters moved up 3 px; not
    screenshotted).

### 80. `feature/cld-cleanup-6`: cleanup round 6 (asked for 2026-10-23)

- [x] `PORT-80` The local branches merged into `origin/main` deleted (33;
  `feature/cld-release-0.26.0` kept: it has commits its remote branch
  lacks, though `main` has them; the two in agent worktrees stay). The
  code: a hit's spark and smash pop in one place (`MatchView.contact_fx`,
  the match's and PLAY OF THE MATCH's replay); SAVE LAST RALLY's rules in
  `Highlight` next to PLAY OF THE MATCH's SAVE; one `TitleScreen.back_to`
  for the seven ways back to a page; the dinosaurs' looks once
  (`DinoWalkers.LOOKS`, merged into DINOSAUR's and DINO PARK's casts,
  checked equal to the old tables); `PadMaps.short_name` for CONTROLLER
  and MAP BUTTONS; QUICK MATCH and MODE share their row; "PRESS AGAIN" for
  "B AGAIN" (prompts, not button names); stale comments (the announcer's
  recorded lines, the SNES icons). The tests: `TestSuite.title_screen` for
  25 copies of the title's setup. New: a rally saved once by SAVE LAST
  RALLY and PLAY OF THE MATCH, whichever first, and a new match forgetting
  the best; replay files that aren't replays, another format, two in one
  second; practice's view against a bare sim; QUICK MATCH's DOUBLES and
  SPECIALS surviving a restart (and an old save without the key);
  `test_layout` for the park's YOU STAY ON COURT and 2 TEAMS AHEAD, the
  CONTROLLER page at its longest name and every status, and the mouse
  picking a row anywhere on its bar; pad names cut to fit. The docs:
  PORT-55, 59 to 77 (but 62) moved to `PORT_HISTORY.md`.
  Then, at your call: replays show the match's light effects too (the
  bounce marks, and the camera flashes when a saved one is watched from
  REPLAYS; none behind the title's menu, as in the demo).
  And known issue 78: SMASH! pop-ups one at a time (two could overlap).
  - Verified: 477/477 plus the e2e, golden traces unchanged; the release
    notes regenerate the same; the title's menu and prompts pixel for
    pixel the same.
  - Status: **Done**.

### 82. `feature/cld-story-roguelike`: ROAD TRIP, a roguelike mode (asked for 2026-10-23)

- [ ] `PORT-82` A plan, nothing built: `design/ROAD_TRIP.md`, with your
  first answers in. A mode of its own beside STORY (which stays): you and
  a partner drive to the SUMMER OPEN, where the Champs defend their
  title. A road map on the van's dashboard: three legs of three columns
  of stops (PICKUP GAME, GRUDGE MATCH, YARD SALE, PRO SHOP, MOTEL,
  DETOUR), a big match ending each of the first two legs and the final
  ending the third, about 12 stops and 30 minutes at most. You start
  weak (a plain paddle and cap, every stat at 1 of 20); gear picked one of
  three at least every two stops (the game's paddles and hats, items,
  one-sided rules) makes a trip strong. Three hearts, and the trip can
  end. MILES fill the GARAGE's fixed ladder of lasting rewards (stats,
  gear, a heart, and cosmetics for the van); beaten captains become
  partners; HEAT. Everything stays inside the mode. The trip's stats and
  rules are a sim change behind `MatchConfig.trip`, off in conformance,
  with an ADR. A new save key (v6 stays). [IMAGE] notes through the doc
  brief an image agent. Seven build stages.
  - Art: all 19 images accepted 2026-10-24, the third draft set with
    round 4's five fixes (`art/roadtrip-v3/`, `art/roadtrip-r4-fixes/`;
    the doc's "The accepted art" lists them). Stage 6 imports them.
  - Status: **Planned**: every question answered; stage 1
    (`feature/cld-trip-run`) starts on your go.

## For you

Questions and things to try, added as the run goes. Nothing here blocks
the chain: each has a default I've gone with.

- **PORT-82 ROAD TRIP:** all answered. The [IMAGE] notes in
  `design/ROAD_TRIP.md` are ready for an image agent; say when to start
  stage 1.

- **PORT-78 the keyboard:** parked at your request. When you've thought
  it over: which presets (WASD + J K L, arrows + Z X C, both), which is
  the default, and does Space stay as a key for hit or become SHORT?

- **PORT-77 the levels:** the names are RUINS, GLACIER, LAB and STATION
  (8 cells fit COURT's page). The crowd is the same crowd everywhere, so
  GLACIER's spectators are in shorts; say if they should be bundled up.
  They live on COURT > VENUE only for now (your call).

- **PORT-76 the dinosaurs:** the Carnotaurus walks with Nathan up (the
  solo `walk`/`idle` tags are one line away in `export.sh` and `CAST`).
  Say if you'd rather see the raptor or the T. rex in place of the painted
  ones. In DINO PARK he strolls the path among the people; say if he
  should keep to the grass instead.

- **PORT-72 the shoulders:** the bible says "hold L or R to hit short"
  (SNES ADR-056); at your request the remaster now has L for SHORT and R
  for SPECIAL (ADR-082). Should the bible's control line change to match
  (and the ROM, which has no SPECIAL, keep L or R)?

- **PORT-75 smaller audio:** the music and ambience are Ogg q4 now. If
  a track sounds worse than its WAV (`audio/compare/out/` has q6, q4 and
  q2 of three of them), say so: `QUALITY` in `game/tools/encode_ogg.py`
  changes them all (q6 adds about 4 MB to the `.pck`).

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

