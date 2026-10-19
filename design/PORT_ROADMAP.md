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

## For you

Questions and things to try, added as the run goes. Nothing here blocks
the chain: each has a default I've gone with.

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

