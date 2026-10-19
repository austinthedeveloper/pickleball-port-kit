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
| PORT-32 | The in-game updater | `feature/cld-updater` | Ready to test |

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

## Phase 3 (started 2026-10-18)

From the v0.6.0 release: a cleanup round, the overhead, and a tournament.

```
feature/cld-release-0.6.0   (v0.6.0)
 23 feature/cld-cleanup-2
 24 feature/cld-overhead
 25 feature/cld-tournament
```

## Tasks

### 23. `feature/cld-cleanup-2`: a cleanup round (asked for 2026-10-18)

- [x] `PORT-23` Step back and organize, and fix what turned up: players
  flashing in the top-left corner whenever the title's demo restarted (a
  new COURT or TIME), every match leaking its whole sim, the title's
  CAREER pages split into their own component, one `UiKit` for the
  panels and labels seven screens built by hand, and the docs: this
  sheet down to an index (the full tasks moved to
  `design/PORT_HISTORY.md`), `game/README.md` and `CLAUDE.md` current.
  Two open defects closed on the way: the e2e's save is per checkout
  (KNOWN_ISSUES #42) and `sync_assets.sh` keeps the import files (#43).
  - Accept: a test for each fix; no visual change from the dedupe;
    golden traces unchanged.
  - Verified: `test_view.test_new_view_places_everyone_at_once` (a new
    MatchView has everyone placed before its first tick: the cause was
    `_update_visuals` running only from the tick), `test_leaks.gd` (ten
    matches built and freed leave at most 20 objects; `Sim.dispose()`
    breaks the Sim/AI and Sim/practice cycles, and a MatchView disposes
    its sim when freed; a probe measured +778 objects for 30 matches
    before, +29 after). `view/title_career.gd` takes the CAREER pages
    out of `title_screen.gd`; `view/ui_kit.gd` (panel, text). Golden
    traces unchanged. Screenshots: Player Select, a doubles HUD and the
    lobby, unchanged.
  - Status: **Done**.

### 24. `feature/cld-overhead`: the overhead (asked for 2026-10-18)

- [x] `PORT-24` A smash, which the SNES never had (ADR-053): a HIT or
  DRIVE swing at a falling ball 20 px up or higher becomes
  `SHOT_OVERHEAD`, twice a drive's pace, hit flat or down, aimed like a
  standard shot, and lengthened just enough to clear the tape (a dumped
  overhead only when it can't). SOFT still blocks. The CPUs smash with no
  new logic (their put-away and any lob they get under). The view: the
  overhead frames, SMASH! over the contact, the biggest shake and rumble,
  its own sound (`0_hit_smash*`), and a SMASHES row on the stats card.
  - Accept: a sim change with an ADR and regenerated golden traces; the
    stats harness unchanged; tests for the rule, the flight, real play
    and the view; screenshots.
  - Verified: `test_overhead.gd` (a falling ball at the line is smashed
    by HIT and DRIVE and the event says so; SOFT, a rising ball, or one a
    pixel lower is not; a smash lands sooner and flatter than a drive and
    in; from five depths and three aims it clears the net; three doubles
    matches through `Sim.step()` see smashes that end points; the view's
    overhead frame, SMASH!, the shake, and nothing written to the sim),
    `test_stats.test_a_smash_winner`. Measured with
    `tools/contact_probe.gd`: 9% of singles shots and 15% of doubles
    shots are smashes; doubles rallies 6.5 → 5.3 shots, singles
    unchanged. Stats harness unchanged (10, 6, 0, 0; 8 and 0; 0 and 18).
    Golden traces regenerated: only `doubles_demo` moves (line 584, its
    first smash). 243/243 plus the e2e. Screenshots: a smash at SUNSET
    with SMASH! over it, and the stats card with its SMASHES row.
  - Status: **Ready to test**: get under a lob (practice: SHOT LOB) and
    swing with HIT or DRIVE. Does it feel strong enough, and too common
    in doubles?

### 25. `feature/cld-tournament`: the tournament (chosen 2026-10-18)

- [x] `PORT-25` TOURNAMENT on MAIN (ADR-054): an eight-entry knockout,
  you as top seed and seven ladder teams (the warm-up HENDERSON sits
  out), QUARTERFINAL, SEMIFINAL, FINAL, each match at the opponent's home
  court with their intro card. The bracket screen (`view/bracket_screen.gd`)
  shows the draw, scores, connectors and the champion; START / MODE /
  BACK before it starts, PLAY / FORFEIT (twice) / BACK during, NEW
  TOURNAMENT after. The other matches are decided from the tournament's
  seed (the higher rung usually wins) and appear one at a time when you
  come back. The result screen says BRACKET, and OUT AS SEMIFINALIST or
  CHAMPION! when it ends. Saved: the bracket in play, and cups in the
  records (RECORDS: SHUTOUTS  CUPS). MAIN's footer prompt went (the
  key legend says HIT) to make room for the row.
  - Accept: pure logic with tests; the save round-trip and an older save;
    the screen by row id; a real match recording through the view; main's
    loop; layout cases; screenshots; golden traces unchanged.
  - Verified: `test_tournament.gd` (the draw and seeding; your road; out
    in the semi and the rest playing out; the same seed the same bracket,
    favourites 133 to 47 upsets over 60 draws; the save, its floats, an
    older save, `record_cup`; START, MODE, FORFEIT by row id; the reveal;
    a real KID match recorded and B going to the bracket; the title ->
    bracket -> match -> bracket loop in the real main scene),
    `test_layout.test_tournament` (four states, singles and doubles, an
    eight-letter career name, every row, and MAIN's TOURNAMENT at QF).
    253/253 plus the e2e; golden traces unchanged. Screenshots: a fresh
    draw, in the semi, out in doubles, champions, and the title.
  - Status: **Ready to test**: TOURNAMENT on MAIN. Is the road's ramp
    right (SNOWBIRDS first), and do upsets feel too common or too rare?

### 26. `feature/cld-kitchen-rule`: no volleys from the kitchen (reported 2026-10-18)

- [x] `PORT-26` A volley from inside your own kitchen loses the point,
  KITCHEN! (ADR-055; the SNES left it out as "ARCADE RULES"). Standing in
  it, or hitting a ball that bounced there, stays legal. The two-bounce
  rule's VOLLEY! comes first. The CPUs never volley from their kitchen
  (they step back or let it bounce). Manual, guide and README updated.
  - Accept: tests for the rule and its edges; the CPUs proven through
    `Sim.step()`; golden traces and the stats harness unchanged.
  - Verified: `test_kitchen.gd` (a volley from either kitchen faults with
    KITCHEN! to the other side; a bounced ball in the kitchen, a volley
    from behind the line, and the other side's player are fine; while
    the return must bounce, a receiver's kitchen volley is KITCHEN! and
    a server's early one VOLLEY!; four net-rushing doubles matches, 64
    volleys, no kitchen fault; TWINS put in their kitchen don't volley
    from it, and without the AI check they do and lose the point).
    258/258 plus the e2e; golden traces unchanged.
  - Status: **Ready to test**: stand in your kitchen and try to volley.

### 27. `feature/cld-cleanup-3`: split the match view (chosen 2026-10-18)

- [x] `PORT-27` `view/match_view.gd` (about 800 lines) loses three parts,
  each a RefCounted holding the view, as the title's CAREER pages did:
  `match_actors.gd` (the people and ball: sprites, frames, the swing
  choice, sparks, SMASH!), `match_input.gd` (each slot's intents,
  multiplayer pads, the input lock, SERVE ASSIST, a dropped pad, the pause
  menu) and `match_end.gd` (records, ladder, bracket and career at the
  result; the initials and UNLOCKED! cards). The view keeps the scene,
  the frame and the events (471 lines) and thin wrappers for what the
  HUD, tools and tests use.
  - Verified: 258/258 plus the e2e, golden traces unchanged, the leak
    test still at its bound; a screenshot of a doubles smash unchanged.
  - Status: **Done**.

### 28. `feature/cld-pad-glyphs`: each pad's own buttons (chosen 2026-10-18)

- [x] `PORT-28` Prompts draw the pad family's buttons (`view/prompts.gd`):
  Xbox (as before, and any unknown pad), PlayStation (cross, circle,
  square, triangle drawn as shapes; L1 R1 L3 R3, OPTIONS, CREATE) and
  Nintendo (B A Y X by position, since Godot maps pads by position; L R,
  + and -, all grey). The family comes from the last pad's name
  (`Prompts.family_of`), or BUTTON ICONS on CONTROLS (AUTO, XBOX,
  PLAYSTATION, NINTENDO; saved, a new key with a default). Display only:
  the bindings don't change.
  - Verified: `test_controller.test_pad_families` (names to families,
    each family's faces, shoulders, Start and Back, the forced setting, the
    keyboard unaffected), `test_controller.test_button_icons_row` (by row
    id, saved), `test_layout.test_pad_families` (every title page, the
    lobby, the serve and pause HUD, and the bracket, in each family).
    Screenshots: the title and lobby on PlayStation, the title and OPTIONS
    on Nintendo.
  - Status: **Ready to test**: plug in a PlayStation or Switch pad. Does
    it pick the right icons? Is your pad's name one I don't know?

### 29. `feature/cld-couch-cup`: the couch cup (chosen 2026-10-18)

- [x] `PORT-29` A multiplayer tournament (ADR-054 amendment): the lobby's
  LB / RB step through SINGLES, DOUBLES, SINGLES CUP and DOUBLES CUP; a
  cup enters each player (singles) or side (doubles) in an eight-entry
  bracket as its top seeds, in separate quarters, with CPU teams from the
  ladder's top. Human against CPU at the team's court; human against human
  on their own pads. A round's CPU matches wait for its human matches. The
  bracket screen says COUCH CUP, names the entries in their shirt colours,
  and PLAY sends each human slot's pad. Its own save slot; never in the
  records. The HUD now names a multiplayer side by its players.
  - Verified: `test_couch_cup.gd` (the lobby's four modes and its entries;
    four humans in four quarters; CPU matches waiting; P1 against P2 in a
    final on two pads; a doubles team against a CPU team at their court,
    and P3 alone with a CPU partner; both out and the rest playing out;
    the save slots apart and round-tripping; a match's end through the
    view recording the cup and not the records; the bracket screen by row
    id), `test_layout.test_couch_cup` (the lobby in both cup modes, the
    bracket fresh, in play and over, three couch match HUDs at 20-20),
    `test_multiplayer` (LB / RB stepping). Solo brackets unchanged.
    Screenshots: a doubles and a singles cup bracket.
  - Status: **Ready to test**: MULTIPLAYER, RB twice, join with two pads.

### 30. `feature/cld-tutorial`: HOW TO PLAY (chosen 2026-10-18)

- [x] `PORT-30` Six lessons (`meta/tutorial.gd`, `view/tutorial_view.gd`),
  each a real sim with one goal read from its events: RALLY (the ball
  machine at you: 3 returns), SHOTS (a DRIVE and a SOFT landed), SMASH (the
  machine lobs: 1 smash in), SERVE (vs a KID CPU: 2 in), TWO BOUNCES (2
  rallies past the rule), THE KITCHEN (2 volleys from behind the line).
  A card first (the match waits, its press doesn't swing), then a banner
  with the progress and advice after a miss (VOLLEY!, KITCHEN!, a serve
  fault, a missed lob), LESSON DONE!, and the next. MAIN's PRACTICE opens
  a page: HOW TO PLAY (from the first lesson not done), LESSON (any one),
  BALL MACHINE. MAIN's PRACTICE row says HOW TO PLAY until one's done.
  Lessons record nothing but themselves (`records.lessons`, a bit each).
  - Verified: `test_tutorial.gd` (each lesson's sim and look; the machine
    lessons' counting by shot; the match lessons' goals and advice; the
    card holding the match; TWO BOUNCES played through by the bot to
    LESSON DONE! and the next; a lesson only reads the sim; the save and
    an older one; main's loop through two lessons and out; the lob can be
    smashed, 9 of 200 spot and timing tries; RALLY was also played by the
    bot, done in 552 frames), `test_layout.test_tutorial` (every card,
    banner with advice, and LESSON DONE!, on keys and a PlayStation pad;
    the PRACTICE page), `test_menus` (PRACTICE, BALL MACHINE, and back).
    278/278 plus the e2e; golden traces unchanged. Screenshots: the RALLY
    and SMASH cards, THE KITCHEN's banner with advice, the PRACTICE page.
  - Status: **Ready to test**: PRACTICE > HOW TO PLAY. Is SMASH too hard?

### 31. `feature/cld-online`: online play (asked for 2026-10-18)

- [x] `PORT-31` 1 vs 1 singles over the internet by address (ADR-056,
  your choices: direct connections, singles first). MULTIPLAYER opens a
  page: LOCAL (the lobby) or ONLINE (`view/online_screen.gd`: HOST A
  MATCH, ADDRESS, JOIN). ENet on UDP 24994; HELLO with the versions and
  looks; the host's START sends the match; lockstep over the exact sim
  with an input delay fitted to the measured round trip, a wait when an
  input is late, a hash every 2 s against desyncs. Menu leaves (twice in
  play), the host rematches, nothing recorded. README: how to connect
  (same Wi-Fi, Tailscale, or a forwarded port).
  - Verified: `test_online.gd` (11 tests: packing, lockstep at three
    latencies compared frame by frame, waiting, a desync caught, the
    handshake, versions, the delay, ENet on this machine for 600 frames,
    two MatchViews playing a match through, two ONLINE screens connecting
    over ENet, main's flow), `test_layout.test_online`, `test_multiplayer`
    (LOCAL). Golden traces unchanged. Screenshots: ONLINE idle, hosting,
    connected; the MULTIPLAYER page. Not verified: two real machines.
  - Played (2026-10-18): two computers on the same Wi-Fi connected and
    played with no lag noticed. The second address the host showed was a
    virtual adapter's and couldn't be joined; the screen now offers only
    reachable ones, labelled (KNOWN_ISSUES #55).
  - Status: **Ready to test**: with a friend. Start on the same Wi-Fi, then
    over Tailscale.

### 32. `feature/cld-updater`: updates in the game (asked for 2026-10-18)

- [x] `PORT-32` OPTIONS > UPDATES (ADR-057): a check of GitHub's latest
  release at start, the news on the title, a download of just the game's
  .pck (checked against the release's SHA-256), and RESTART onto it. The
  boot scene (`scenes/boot.gd`, now the main scene) loads a newer
  downloaded pack before anything else, then adds the input map and the
  updater (no longer autoloads) and the title; a start that never reaches
  the title is skipped next time. CI publishes the .pck and its manifest
  (`tools/update_manifest.py`) with each release. The layout test now
  also fails on a character the font can't draw (it found ONLINE's
  invisible typing cursor).
  - Verified: `test_updater.gd` (7 tests), `test_layout.test_updater`; by
    hand, an exported 0.8.1 macOS app started a 0.9.9 pack (a class only
    in the update ran, the version said 0.9.9, the title cleared the
    mark) and fell back from a damaged one. 298/298 plus the e2e; golden
    traces unchanged.
  - Status: **Ready to test**: after 0.9.0, the next release (0.9.1) is
    the first real update. Not tried on Windows or Linux.

## For you

Questions and things to try, added as the run goes. Nothing here blocks
the chain: each has a default I've gone with.

- **PORT-21 career:** your existing save moves to layout v5 with no
  players and nobody active, so everything plays as before until you make
  one. Delete is a DELETE PLAYER row pressed twice (the SNES's L+R+X).
  The editor's portrait sits in its own panel and the title demo keeps
  playing behind (the SNES froze the demo and recoloured its P1). 1P's
  HUD panel shows the whole name. Multiplayer matches don't count for a
  career player (as they don't for the records). Say if you'd want
  career stats on the clubhouse board too.


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
  feel bigger. No 2P/multiplayer tournament yet.

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

- **PORT-31 online:** only tested on one machine (two copies talking
  over localhost, and a simulated slow line), never between two
  computers. Tell me the round trip you get (if it feels laggy, rollback
  is the next step, ADR-056) and anything that goes wrong, with the
  message the screen shows. The guest plays on the right side of the
  court; flipping the view so each of you is on the left is possible.

- **Next, from your note (2026-10-18):** the screen shake is too jarring.
  Today ACCESSIBILITY > SCREEN SHAKE only turns it on or off; the plan is
  a strength slider like CAMERA's (OFF, 25%..100%) with a gentler default
  (KNOWN_ISSUES #58).

