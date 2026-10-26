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
| PORT-81 | Touch controls for the web build: an on-screen SNES pad on phones and tablets | `feature/cld-touch-controls` | Ready to test |
| PORT-82 | ROAD TRIP: a roguelike mode beside STORY, a road map of branching stops, a match at each, gear to pick, a garage between trips (port ADR-087) | `feature/cld-trip-run` | Ready to test |
| PORT-83 | The painted venues: WESTERN, ROOFTOP, PIRATES, MOTEL, FAIR, DRIVE-IN, MALL, from generated paintings (port ADR-088) | `feature/cld-venue-art-r1` | Ready to test |
| PORT-84 | The lite Web build: smaller music and ambience, no announcer, ROAD TRIP or painted venues; the Web zip 51 MB to 21 MB (port ADR-089) | `feature/cld-web-lite` | Ready to test |
| PORT-85 | OPTIONS in the pause menu: the title's OPTIONS pages over a paused match (port ADR-090) | `feature/cld-pause-options` | Ready to test |
| PORT-86 | ROAD TRIP tuning: leg 1 a bit harder, the partner late less often (port ADR-091) | `feature/cld-trip-tune` | Ready to test |
| PORT-87 | ROAD TRIP round two: THE VAN (stats, the locker, sets), TRADE IN, 19 items, the diner, 13 detours, the ROAD HOGS, a story across trips and the SCRAPBOOK (port ADR-092) | `feature/cld-trip-roads` | Ready to test |
| PORT-88 | The announcer's ROAD TRIP lines: 29 on the list to record, wired in (port ADR-093) | `feature/cld-trip-more` | Ready to test |
| PORT-89 | TODAY'S TRIP: the date's map, the same for everyone (port ADR-093) | `feature/cld-trip-more` | Ready to test |
| PORT-90 | Partner bonds: levels, their own items and scenes (port ADR-093) | `feature/cld-trip-more` | Ready to test |
| PORT-91 | The islands: a secret fourth leg and the encore against Dale Dawson (port ADR-093) | `feature/cld-trip-more` | Ready to test |
| PORT-92 | Postcards: one for every venue and detour, on the SCRAPBOOK (port ADR-093) | `feature/cld-trip-more` | Ready to test |
| PORT-93 | The map pen and NOW PLAYING (port ADR-093) | `feature/cld-trip-more` | Ready to test |
| PORT-94 | ROAD TRIP balance pass: the gear curve measured, sets easier to finish (port ADR-093) | `feature/cld-trip-more` | Ready to test |
| PORT-96 | ROAD TRIP fuzz tests (random trips, the story over many trips, every story map, old saves); the generator's rare rule-breaking leg fixed | `feature/cld-trip-tests` | Done |
| PORT-95 | Smart play: CPUs at the kitchen line, moving up together, your partner following you, placed shots; tunable on F2 (port ADR-094) | `feature/cld-smart-ai` | Ready to test |
| PORT-97 | Shirt patterns: twelve for the ladder teams, Dawson and the ROAD HOGS, and a career PATTERN row; beat a team to wear theirs (port ADR-095) | `feature/cld-shirts` | Ready to test |
| PORT-98 | ROAD TRIP plays every modifier (INVERSE, GLOW, MULTI BALL...) as a grudge twist; SHORT held slows your feet (port ADR-096) | `feature/cld-trip-mods-dink` | Ready to test |
| PORT-99 | ROAD TRIP: a FROM THE GARAGE card before a trip, your starting stats and what the GARAGE (and what is NEW) adds (port ADR-097) | `feature/cld-trip-mods-dink` | Ready to test |
| PORT-100 | ROAD TRIP map: the roads on from the stop under the cursor in gold, the stops they miss faded (port ADR-098) | `feature/cld-trip-path-preview` | Ready to test |
| PORT-101 | PLAYERS 2P with one pad no longer locks the menus: every menu hears every pad; the pad is 2P's only on the court (known issue #93) | `feature/cld-2p-menu-pad` | Ready to test |

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
- **v0.33.0** (2026-10-24): PORT-79 text centred, PORT-80 cleanup round 6,
  PORT-81 touch controls, PORT-82 ROAD TRIP (tag `v0.33.0`, on
  `feature/cld-release-0.33.0`).
- **v0.34.0** (2026-10-24): PORT-83 the painted venues: WESTERN, ROOFTOP,
  PIRATES, MOTEL, FAIR, DRIVE-IN, MALL (tag `v0.34.0`, on
  `feature/cld-release-0.34.0`).
- **v0.35.0** (2026-10-24): PORT-84 the lite Web build (tag `v0.35.0`, on
  `feature/cld-release-0.35.0`).
- **v0.36.0** (2026-10-25): ROAD TRIP round two and three: THE VAN, a
  story across trips, TODAY'S TRIP, bonds, the islands, postcards; pause
  OPTIONS (tag `v0.36.0`, on `feature/cld-release-0.36.0`).
- **v0.37.0** (2026-10-25): PORT-95 smart play, PORT-96 ROAD TRIP fuzz
  tests and the generator fix, PORT-97 shirt patterns (tag `v0.37.0`, on
  `feature/cld-release-0.37.0`).
- **v0.38.0** (2026-10-26): PORT-98 every modifier on a trip and SHORT
  held, PORT-99 FROM THE GARAGE (tag `v0.38.0`, on
  `feature/cld-release-0.38.0`).
- **v0.39.0** (2026-10-26): PORT-100 the map previews where a choice leads
  (tag `v0.39.0`, on `feature/cld-release-0.39.0`).
- **v0.39.1** (2026-10-26): PORT-101 PLAYERS 2P with one pad no longer
  locks the menus (tag `v0.39.1`, on `feature/cld-release-0.39.1`).

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

### 81. `feature/cld-touch-controls`: touch controls on the web (asked for 2026-10-23)

- [x] `PORT-81` The web build had no touch input (a tap on a menu row
  worked, through Godot's mouse emulation; a match couldn't be played).
  Godot has touch events and `TouchScreenButton`, but no D-pad node, so
  one `TouchPad` node (`view/touch_pad.gd`, port ADR-086) tracks the
  fingers and presses the input map's actions through `Input`: a SNES
  pad with the D-pad bottom left, B A Y X bottom right (hit, drive, soft,
  slice), START, L (SHORT) and R (SPECIAL) up top. The prompts follow it
  (B HIT, A DRIVE...). TOUCH PAD on CONTROLLER: AUTO (a touch screen, no
  pad), ON, OFF. Taps off the pad still drive the menus; a tap on a
  button doesn't click the row under it; a part with a menu's panel under
  it steps aside. No controller card on a phone.
  - Verified: 487/487 plus the e2e. `test_touch` (synthetic touches:
    every action, the D-pad's eight ways, two thumbs, a slide, a tap
    shorter than a tick), a
    `test_layout` case, the e2e with real touches through the event
    queue; screenshots of the title, COURT, a match, pause, the result
    and practice with the pad up. Golden traces unchanged.
  - Status: **Ready to test** on a phone: export the web build
    (`game/tools/export.sh`), serve it and open it on a phone in
    landscape. Try a match (move and hit with two thumbs, hold L while
    hitting), the menus by tap, and whether the buttons sit right under
    your thumbs. Known issue 79 lists what couldn't be checked here.

### 82. `feature/cld-trip-run`: ROAD TRIP, a roguelike mode (asked for 2026-10-23)

- [x] `PORT-82` ROAD TRIP (port ADR-087; the plan with your answers and the
  art: `design/ROAD_TRIP.md`; the art in `art/roadtrip-v3` and
  `art/roadtrip-r4-fixes`, imported to `game/assets/trip`). A mode on MAIN
  beside STORY: you and a partner drive to the SUMMER OPEN on a road map
  of three legs (three columns of stops in three lanes, then a big match;
  the last leg's is the final against the Champs). Stops: PICKUP GAME,
  GRUDGE MATCH, YARD SALE, PRO SHOP, MOTEL, DETOUR. You start weak (a
  plain paddle and cap, four stats at 1 of 20); gear picked one of three
  (the game's paddles and hats, stacking items, partner training,
  one-sided rules) makes a trip strong. Three hearts; the trip can end.
  The miles fill the GARAGE's fixed ladder of lasting rewards (starting
  stats, a heart, gear, van paints and ornaments); beaten captains become
  partners; a trip won opens the next HEAT. Nothing counts outside the
  trip. Seeded: the map, picks, shop and detours are the same wherever
  played. The sim: `MatchConfig.trip` (a slot's stats, a CPU's style, the
  left side's perks), off everywhere else.
  - Verified: 500+ tests plus the e2e, golden and conformance traces
    unchanged; `test_road_trip` (the data, 300 seeds' maps, trips won and
    lost, the save, the sim's stats and perks), `test_trip_screens` (the
    real main scene from the title to a trip's end, three seeds),
    `test_layout` on every trip screen and text. Screenshots of every
    screen (`tools/trip_shot.gd`).
  - Status: **Ready to test**: play a trip or three. Say how it feels:
    too easy or hard (the bot wins leg 1 from the start and needs about
    12 in every stat for the final), the length, the prices, the gear.
    Not built: the cassettes and the map's pen colour (KNOWN_ISSUES #82,
    #83).

### 83. `feature/cld-venue-art-r1`: the painted venues (asked for 2026-10-24)

- [x] `PORT-83` Seven venues from generated paintings (port ADR-088), after
  STATION on COURT > VENUE: WESTERN, ROOFTOP, PIRATES, MOTEL (the drained
  pool from ROAD TRIP's motel), FAIR, DRIVE-IN, MALL. The loop was ROAD
  TRIP's: I wrote the prompts and reviewed each round, you generated
  (`art/venues-r1`: prompts, references, concepts, plates, cutouts,
  locals, both reviews; MOTEL's re-layout in `art/venues-r2-fixes`).
  `art/levels/tools/painted.py` cuts the layers and paints the court on
  each floor; every venue has its own locals (`Crowd` takes a venue's
  sheet), its court presets, its own ambience and match track. MALL and the DRIVE-IN
  ignore TIME (indoors; already night). ROAD TRIP's legs visit them.
  - Verified: the full suite plus the e2e, golden traces unchanged; the
    existing venues' art and sounds byte-identical; `test_court` (their
    presets, their locals), `test_night`, `test_layout` (the COURT page's
    new names). Screenshots of each in a match.
  - Status: **Ready to test**: play a match at each. Say if a scene, its
    crowd or its sound should change. Not done: the announcer's lines
    (KNOWN_ISSUES #85); no parallax (#86).

### 84. `feature/cld-web-lite`: the lite Web build (asked for 2026-10-24)

- [x] `PORT-84` The Web build thinned, the desktop builds untouched (port
  ADR-089). Its preset carries the `lite` feature and leaves out the
  announcer, ROAD TRIP's art and the seven painted venues; the game,
  with `Settings.lite` on, hides ROAD TRIP and the announcer's rows and
  goes round the first eleven venues. `export.sh` exports it from a copy
  with its music and ambience re-encoded smaller (q1, the ambience mono).
  The Web pack is 12 MB (was 41), the zip 21 MB (was 51).
  - Verified: the full suite plus the e2e (`test_lite`, a lite case in
    `test_layout`); a full export, the Web pack booted headless with
    `lite` on and the left-out files absent; the Web build served
    locally and played in a browser (title, setup, a match), no console
    errors.
  - Status: **Ready to test**: open the Web build and listen to the
    music and the crowd. If q1 sounds rough, the setting is
    `WEB_QUALITY` in `game/tools/encode_ogg.py`.

### 85. `feature/cld-pause-options`: OPTIONS in the pause menu (asked for 2026-10-24)

- [x] `PORT-85` Pause > OPTIONS (port ADR-090): the title's OPTIONS,
  ACCESSIBILITY, CONTROLS and CONTROLLER pages over a paused match, from
  one builder (`view/options_pages.gd`) both screens use. Closing saves
  them and applies CAMERA and HUD TEXT to the match.
  - Verified: the full suite plus the e2e (`test_menus.test_pause_options`:
    the same rows as the title's, the match waits, saved and applied;
    `test_layout.test_pause_options`: every page, every value);
    screenshots of the pause menu, OPTIONS and ACCESSIBILITY over a match.
  - Status: **Ready to test**: pause a match and change the sound.

### 86. `feature/cld-trip-tune`: ROAD TRIP tuning (asked for 2026-10-24)

- [x] `PORT-86` After your first trip (port ADR-091): leg 1's grudge and
  big matches are MEDIUM and its CPU errors 60% of the rest's, so its
  rallies are about twice as long. The partner is late on every 12th ball
  (was 7th), further apart with each CONTROL point from the MOTEL. Legs 2
  and 3 and the final are unchanged.
  - Verified: the full suite plus the e2e (`test_road_trip.test_the_tuning`);
    the bot's runs before and after (`tools/trip_balance.gd`, and counts of
    how each point ended).
  - Status: **Ready to test**: play a trip. Say if leg 1 is now right, and
    whether Pepper still lets balls go by.

### 87. `feature/cld-trip-roads`: ROAD TRIP round two (asked for 2026-10-24)

- [x] `PORT-87` ROAD TRIP grows (port ADR-092, no sim change): THE VAN
  over the map (Y / I) shows your stats as bars by where each point comes
  from, your partner's, and your gear; replaced paddles and hats go in
  the van's locker to swap back in; TRADE IN at the PRO SHOP; eight item
  sets. 19 new items, 4 hazards, 13 detours (7 at painted venues), the
  DINER (a meal for the next match). The story now grows across trips:
  20 beats in four arcs (THE VAN, THE ROAD HOGS, THE CHAMPS, THE MIXTAPE)
  with lasting rewards (three story paddles, cassettes for the map's
  music), the ROAD HOGS as recurring rivals from the second trip, a
  captain partner's own start, and the SCRAPBOOK on ROAD TRIP's page.
  - Art: eight images from `art/roadtrip-r5/PROMPTS.md`, all accepted
    and imported (`REVIEW.md`).
  - Verified: the full suite plus the e2e (new: `test_road_trip`'s
    second-round tests, `test_trip_screens.test_the_story_across_trips`,
    `test_layout`'s VAN, SCRAPBOOK and story cases); screenshots of THE
    VAN, the map with the ROAD HOGS, their scene, the SCRAPBOOK, the
    diner, a venue detour, the shop and the GARAGE.
  - Status: **Ready to test**: take two or three trips.

### 88. `feature/cld-trip-more`: the announcer's ROAD TRIP lines (asked for 2026-10-24)

- [x] `PORT-88` 29 ROAD TRIP lines added to the announcer's second batch
  (`design/announcer/ADDITIONS.md`, now 105 lines) and wired in: a
  stop's kind opens its match, your last heart, hazards, the meal, the
  one-sided rules' saves, the SUMMER OPEN and the encore won. Each is
  used once recorded.
  - Status: **Ready to test** once you've recorded them.

### 89. `feature/cld-trip-more`: TODAY'S TRIP (asked for 2026-10-24)

- [x] `PORT-89` A row on ROAD TRIP's page: today's map (from the date),
  HEAT 0, Pepper, no GARAGE or story, so it's the same for everyone; the
  best result kept for the day, days won on the records.
  - Status: **Ready to test**.

### 90. `feature/cld-trip-more`: partner bonds (asked for 2026-10-24)

- [x] `PORT-90` Every partner earns bond points with you (a win each,
  three for a title). Level 1: +1 to their stats; 2: their own item and a
  scene; 3: +2 and a line from the announcer at the big matches.
  - Status: **Ready to test**.

### 91. `feature/cld-trip-more`: the islands (asked for 2026-10-24)

- [x] `PORT-91` A secret fourth leg past the SUMMER OPEN, open once a
  story is finished or HEAT 5 is won: THE ISLANDS, ending in THE ENCORE
  against Dale Dawson, with its own three-chapter story.
  - Art: the islands' map paper (`art/roadtrip-r6/PROMPTS.md`;
    placeholder meanwhile).
  - Status: **Ready to test** (to see it now: finish a story, or ask me
    for a save that has one).

### 92. `feature/cld-trip-more`: postcards (asked for 2026-10-24)

- [x] `PORT-92` A postcard for every venue played and detour taken (38),
  on the SCRAPBOOK; 8, 16 and 24 earn new map pens.
  - Status: **Ready to test**.

### 93. `feature/cld-trip-more`: the map pen and NOW PLAYING (asked for 2026-10-24)

- [x] `PORT-93` MAP PEN in the GARAGE colours the road driven; the
  cassette chosen shows on a NOW PLAYING card as the map opens.
  - Status: **Ready to test**.

### 94. `feature/cld-trip-more`: a ROAD TRIP balance pass (asked for 2026-10-24)

- [x] `PORT-94` `tools/trip_gear_stats.gd` measures how far gear takes
  the stats: no runaway POWER (7 at the final on a new GARAGE), but sets
  were rarely finished, so one card in two is now a missing piece of a
  set you've started (0.2 sets a trip to 0.5).
  - Verified (88 to 94): the full suite plus the e2e; screenshots of the
    islands map, POSTCARDS, the results, the home and the GARAGE.
  - Status: **Ready to test**: say how the sets feel.

### 96. `feature/cld-trip-tests`: more ROAD TRIP tests (asked for 2026-10-25)

- [x] `PORT-96` `test_trip_fuzz`: 120 random trips checked after every
  step (hearts, cash, stats, the locker, save round trips, picks, always
  a way on, an end), 50 trips on one save (beats in order and once, the
  scrapbook and postcards only growing, the islands once open), every
  story map, the islands end to end, the day's trip the same for a full
  and a new save, bonds across finishes, a pre-round-two save played to
  its end, and the data's references. It found a bug, fixed: when 400
  draws of a leg all broke the leg rules, the generator kept the last
  (1 leg in 7,000); generator 3 keeps drawing.
  - Verified: the full suite plus the e2e (about 9 s added).

### 95. `feature/cld-smart-ai`: smart play (asked for 2026-10-25)

- [x] `PORT-95` A remaster-only layer over the ROM's AI (port ADR-094),
  three knobs a CPU: KITCHEN (wait just behind the kitchen line once the
  rules allow), TOGETHER (a CPU pair level; your partner follows you up,
  and half way back), AIM (third-shot drops, dinks cross-court, the ball
  to whoever's back, drives down the middle). Profiles by difficulty and
  for your partner in `data/ai_smarts.json`; F2 > SMART PLAY tunes them
  live and saves them.
  - Verified: the full suite plus the e2e (`test_smart_ai`, the tuning
    page in `test_layout`; the conformance and golden traces unchanged);
    `tools/smart_stats.gd`: the SNOWBIRDS wait at 58 px from the net
    instead of 89; MEDIUM a touch harder (42% of points to the CPUs, was
    39%), HARD clearly (54%).
  - Status: **Ready to test**: play a doubles match at HARD, and press
    F2 > SMART PLAY to change any knob mid-match.

### 97. `feature/cld-shirts`: shirt patterns (asked for 2026-10-25)

- [x] `PORT-97` Twelve shirt patterns (port ADR-095), generated on the
  player rig in `players.py` so they follow every pose: RUGBY, CHEST
  BAND, SASH, RAGLAN, RINGER, PINSTRIPE, POLKA DOTS, TIE-DYE, FLAMES,
  HAWAIIAN, CHEVRON, SPLIT, each a body sheet in a new design colour
  (two palette roles). Every ladder team wears one in its own colours,
  and so do Dale Dawson (FLAMES) and the ROAD HOGS (CHEVRON). A career
  player picks one on EDIT's PATTERN row: PLAIN and RINGER free, a
  team's pattern for beating them, and POLKA DOTS, CHEVRON and FLAMES
  from wins, aces and ladder clears (eleven unlocks after the ROM's
  sixteen; the mask widened, the save still v6). Player Select is
  unchanged.
  - Verified: the full suite plus the e2e (`test_career.test_patterns`,
    `test_view`, every pattern on EDIT in `test_layout`); screenshots of
    a doubles match against every team and the EDIT page; a lineup of
    every opponent.
  - Status: **Ready to test**: play the ladder and say which patterns or
    colours miss.

### 98. `feature/cld-trip-mods-dink`: every modifier on a trip, SHORT held (asked for 2026-10-26)

- [x] `PORT-98` A grudge's twist draws from every modifier and rule
  (FAST BALL, GLOW, INVERSE, WIN BY 2, SIDE-OUT, MOMENTUM, SUDDEN DEATH
  and MULTI BALL added); the map's panel gives TODAY its own line.
  Holding SHORT slows a human to 7/8 top speed, remaster only (port
  ADR-096).
  - Verified: the full suite plus the e2e (`test_shots`
    `test_short_held_slows_the_feet`, `test_road_trip.test_the_data`
    checks every toggle is reachable, `test_layout` every twist with a
    hazard and SPECIALS on the map); golden and conformance traces
    unchanged; screenshots of the map panel and an INVERSE match.
  - Status: **Ready to test**: hold SHORT and feel the drag; play a few
    grudges for the new twists.

### 99. `feature/cld-trip-mods-dink`: FROM THE GARAGE (asked for 2026-10-26)

- [x] `PORT-99` A new trip opens on a FROM THE GARAGE card: the stats
  you start with, what the GARAGE adds (stats, hearts, cash, paddle), and
  in gold what's NEW since the last trip began (meta `garage_steps`, save
  still v6). None before the first step, none on TODAY'S TRIP (port
  ADR-097).
  - Verified: the full suite plus the e2e
    (`test_road_trip.test_the_garage_card`, the card at the ladder's top
    in `test_layout`); a screenshot (`trip_shot.gd start_garage`).
  - Status: **Ready to test**: start a trip once you have some MILES.

### 100. `feature/cld-trip-path-preview`: where a choice leads (asked for 2026-10-26)

- [x] `PORT-100` On ROAD TRIP's map, the stop under the cursor shows
  where it leads: a gold highlighter from the van to it and along every
  road on to the big match, and the leg's stops those roads miss faded.
  Display only (port ADR-098).
  - Verified: the full suite plus the e2e
    (`test_road_trip.test_where_a_choice_leads`, `test_trip_screens`);
    screenshots of each first choice and a leg-2 stop
    (`trip_shot.gd map cursor=N`).
  - Status: **Ready to test**: move the cursor over the first column's
    stops on a new trip.

### 101. `feature/cld-2p-menu-pad`: one pad and PLAYERS 2P (a tester's report, 2026-10-26)

- [x] `PORT-101` With one pad, PLAYERS 2P gave the pad to 2P and put P1
  on the keyboard by re-pointing the input map's pad events at no pad, so
  MATCH SETUP (and every menu after it) stopped hearing the pad: the
  menu looked frozen until a key set PLAYERS back. The split now holds
  only while 2P is on the court (`GameControls.split`, set by main for a
  match with 2P in it and the park); everywhere else the input map hears
  every pad. Player Select's 2P turn still reads 2P's pad as before.
  - Verified: the full suite plus the e2e
    (`test_controller.test_menus_hear_every_pad`).
  - Status: **Ready to test**: one pad, MATCH SETUP > PLAYERS 2P, then
    move on the pad; start a 2P match (keyboard is P1, the pad 2P).

## For you

Questions and things to try, added as the run goes. Nothing here blocks
the chain: each has a default I've gone with.

- **PORT-98 SHORT held:** 7/8 top speed is a guess at "slight"
  (`K.SHORT_HELD_SPEED`). Say if it should bite more, or less.

- **PORT-97 shirt patterns:** play a few ladder teams and open CAREER >
  EDIT > PATTERN. Say which patterns or team colours miss; mocks of a
  motif you'd like (a logo, a number) are welcome, and the patterns are
  easy to retune in `art/levels/tools/players.py`.

- **PORT-95 smart play:** try MEDIUM and HARD doubles, and a match with
  a CPU partner (come up to the kitchen: they should come with you). The
  knobs are on F2 > SMART PLAY; tell me the numbers you settle on and
  I'll make them the defaults.

- **PORT-88 to 94 ROAD TRIP round three:** record the 29 ROAD TRIP
  lines when you can (`design/announcer/ADDITIONS.md`, group ROAD TRIP).
  Try TODAY'S TRIP. The islands open once a story is finished or HEAT 5
  is won; say if you'd like them easier to reach. Two images to make:
  `art/roadtrip-r6/PROMPTS.md`.

- **PORT-87 ROAD TRIP round two:** take two or three trips (the story
  starts on the second). Press Y (I on the keyboard) on the map for THE
  VAN. Say which new items or sets feel dull or too strong, whether the
  ROAD HOGS should be harder, and what you think of the story's beats
  (they're in `data/trip.json` to edit).

- **PORT-84 the lite Web build:** listen to the Web build's music and
  crowd (q1, the crowd in mono). Say if it's too rough, or if you want
  any of the left-out parts back on the web.

- **PORT-83 the painted venues:** play a match at each. The names are
  WESTERN, ROOFTOP, PIRATES, MOTEL, FAIR, DRIVE-IN and MALL. Each has a
  new match track and ambience: say if one misses the mark.

- **PORT-82 ROAD TRIP:** built and playable (MAIN > ROAD TRIP). Play a
  few trips and say what to change: the difficulty, the length, prices
  and cash, the gear (which items are dull or too strong), the GARAGE's
  pace. The numbers are a first guess (KNOWN_ISSUES #82).

- **PORT-81 touch:** the pad is a SNES pad (B A Y X, L R up top). Say if
  you'd rather have big labelled buttons (HIT, DRIVE...) or fewer of them
  on phones; and whether TOUCH PAD should default to ON in the web build
  rather than AUTO.

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

