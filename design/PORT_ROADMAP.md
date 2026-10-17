# Port roadmap: the 9-hour run

A chain of branches, each cut from the previous one's tip, so the last
branch holds everything. Each branch is about an hour. When a branch's
work is in, its row here flips status in the same commit, and the next
branch starts. Nothing is pushed, and nothing goes to `main`.

**Status:**

- **Done:** automated checks cover it fully (tests, golden traces,
  screenshots). Nothing needs your judgement.
- **Ready to test:** it works and is verified, but it needs a human to
  feel or look at it. The row says what to try.
- **Planned / In progress / Blocked:** as written.

**Every branch, before it's marked:**

- `game/tools/test.sh` passes (82+ tests plus the end-to-end smoke).
- The golden traces are unchanged unless the branch is meant to change
  play. If it is, the commit says why.
- Screenshots of anything visual.
- `design/KNOWN_ISSUES.md` and the relevant ADR are updated.

## Chain

```
feature/cld-godot-port                 (done: the playable port)
 ├─ practice session  ─┐               (running now, own branches)
 └─ opponent looks    ─┤  merged in at step 0 (needs your OK)
                       ▼
 1 feature/cld-feel
 2 feature/cld-audio
 3 feature/cld-menus
 4 feature/cld-player-select
 5 feature/cld-court-colors
 6 feature/cld-night
 7 feature/cld-watcher-replay
 8 feature/cld-records
 9 feature/cld-release
```

## Tasks

### 0. Merge the two running sessions

- [x] `PORT-00` Merge the practice-mode and opponent-looks branches into
  the chain's base. Each goes in only if its own tests pass. Conflicts
  get resolved, and both features are re-run together.
  - Accept: one branch with both features, with `test.sh` green.
  - Verified: practice 90/90 and looks 84/84 (each with the e2e) on their
    own branches. `feature/cld-godot-port` fast-forwarded to practice
    (which also brought the roadmap commit), then looks merged in. The doc
    conflicts (ADR-052, KNOWN_ISSUES #31-35, screenshot.gd) were resolved
    keeping both sides. Combined: 92/92 plus the e2e. Screenshots: the
    PIRATES in their looks, and practice with the machine.
  - Status: **Done**.

### 1. `feature/cld-feel`: game feel (product brief "punchy")

- [x] `PORT-01` Contact punch: a short screen shake on drives and
  put-aways, a ball trail on fast shots, squash on the bounce, a swing
  whoosh frame on the paddle, and dust when a player plants.
  - Accept: everything is display-only and the golden traces don't move.
    Each effect has a switch in the code, so one can be dropped if it's
    too much.
  - Verified: `view/feel.gd`, with each effect switched in `Feel.ON`.
    `test_feel.gd`: a drive shakes and settles, a standard low shot
    doesn't, the bounce squashes and restores, the trail follows only
    drive-pace balls, and the whoosh shows on the first contact frame
    and fades. 1,200 frames with everything on leave the sim identical to
    a bare one. 97/97 plus the e2e; golden traces unchanged. The arc and
    trail were checked in a forced-draw screenshot.
  - Status: **Ready to test**: play a few rallies. Hit drives (K), and
    lob high to get a put-away back. Do the shake, trail and arc feel
    right, or too much?

### 2. `feature/cld-audio`: sound (ADR-029, ADR-031)

- [x] `PORT-02` Hits pitched by shot type. Hits, bounces and the net
  panned by court x. A crowd that swells with the rally's length and
  hushes on match point. Applause sized to the point. Ambience fades at
  scene changes. A SOUND setting (ALL / NO CROWD / OFF), saved.
  - Accept: an event-to-sound test like `test_audio.c` (shot to pitch,
    x to pan, rally to crowd level, OFF means silent). Nothing plays
    during the title demo except ambience.
  - Verified: `view/audio_map.gd` maps events to sounds and is pure.
    `view/sfx.gd` plays them on panned 2D players (three voices per
    effect) and runs the ambience: fade-in, rally swell, match-point hush.
    `test_audio.gd`: effects per event, pitch by shot, pan by x, quieter
    later bounces, applause 6..13 by rally and 15 for the match winner,
    NO CROWD and OFF, the demo silent while a match makes sounds.
    104/104 plus the e2e; golden traces unchanged. SOUND is in the save
    and loaded at start; its menu row lands with PORT-03's OPTIONS page.
  - Status: **Ready to test**: listen to the mix. Are hits, bounces and
    the whistle balanced? Is the applause too loud? Is the ambience swell
    on long rallies noticeable but not distracting?

### 3. `feature/cld-menus`: the menu tree (ADR-025, ADR-030, playbook §7)

- [x] `PORT-03` A main menu with pages (PLAY, OPTIONS, MODIFIERS,
  RECORDS) built on one reusable settings-row component, replacing
  today's one long title list. A pause menu (RESUME / RESTART / MAIN
  MENU). Every modal swallows its closing input (rule 9). Window options
  (fullscreen, integer scale).
  - Accept: menu tests that jump to a page by name, not by counting
    presses (playbook §4.8). The end-to-end smoke is extended through
    pause, then RESTART, then MAIN MENU. Settings survive a restart.
  - Verified: `view/menu_page.gd`, one row component (id, label,
    value, change, press) behind every page and the pause menu. MAIN:
    SINGLES, DOUBLES, MATCH SETUP, PRACTICE, MODIFIERS (four toggles),
    OPTIONS (CAMERA, SOUND, FULLSCREEN, SCALE), RECORDS; each sub-page ends
    in BACK, and Y backs out. `test_menus.gd` (8 tests) opens every page by
    name, changes rows by id, toggles modifiers into the match config,
    reads an old save's MODS preset as bits, saves and reloads every
    setting, and runs the pause rows (RESUME unpauses through the sim,
    RESTART starts over without serving, MAIN MENU leaves). The e2e now
    goes MAIN → OPTIONS → SOUND → back → SINGLES → card → serve → point →
    pause → RESTART → pause → MAIN MENU, and checks the saved SOUND.
    112/112 plus the e2e; golden traces unchanged. Screenshots: MAIN,
    OPTIONS, the pause menu. The e2e had a false pass, now fixed
    (KNOWN_ISSUES #36).
  - Status: **Ready to test**: walk the menus with the keyboard and a
    pad. Do the pages read well, is Y-to-back natural, and do FULLSCREEN
    and SCALE behave on your display?

### 4. `feature/cld-player-select`: Player Select (ADR-020)

- [x] `PORT-04` Choose a shirt colour, male or female, and a paddle,
  with POWER, CONTROL and SPEED bars, following the select concept art.
  Colours stay unique per match (ADR-010). 2P picks on its own pad.
  CPUs take the remaining colours.
  - Accept: config tests (uniqueness, the paddle reaches the sim, CPU
    defaults). A screenshot matches the concept's layout. The paddle
    actually changes play (a stats-harness check: the red paddle's shots
    fly sooner).
  - Verified: `sim/select.gd` is select.c (rows, B steps and confirms,
    Start confirms, Y climbs back, 2P skips 1P's colour) plus
    match_config_select (CPUs take the free colours in order, the
    standard paddle, slots 1 and 3 female). `view/select_screen.gd`
    follows the concept: portrait, four shirt thumbnails, four paddles
    with POWER / CONTROL / SPEED bars. SINGLES and DOUBLES open it; 2P
    picks next on pad 2. The last choice is saved and used for ladder
    rungs and practice. A human's chosen paddle is drawn in hand
    (`PlayerLook.for_team`). `test_select.gd` (7 tests): test_select.c
    ported; unique colours over every 1P/2P pick in both modes; CPU
    defaults; the paddle reaches the sim; in 6,000 frames of bot play the
    red paddle's shots reach the bounce sooner than the standard's; the
    role sheet in the team palette equals the colour sheet pixel for
    pixel; the title's select flow. 119/119 plus the e2e (now through
    Player Select: RED, WOOD, and both reach the match); golden traces
    unchanged. Screenshot: the select screen against the concept.
  - Status: **Ready to test**: pick a colour, body and paddle; try WOOD
    vs RED for a few rallies. With a second pad, set PLAYERS to 2P VS.

### 5. `feature/cld-court-colors`: court colours (ADR-022, ADR-027)

- [x] `PORT-05` A COURT page: VENUE plus SURFACE, KITCHEN (with SAME),
  SURROUND and LINES presets from `court_colors.json`, previewed live
  behind the page. Recolouring uses the court mask's roles in a shader.
  - Accept: a contrast test: lines against the surface, and the ball
    against every surface, at `min_line_contrast` and
    `min_ball_contrast` (playbook §4.7). DEFAULT matches the painted
    ground pixel for pixel.
  - Verified: `view/court_style.gd` + `court_style.gdshader`: each
    ground pixel's mask role picks its part's preset, scaled by the
    pixel's brightness against the venue's painted base (the SNES
    generator's rule, per pixel), so the paint's texture and shading stay.
    All DEFAULT draws the ground unshaded. MAIN's COURT row opens VENUE,
    SURFACE, KITCHEN (SAME first), SURROUND, LINES, on the right so the
    demo court recolours live beside it; saved. `test_court.gd` (5
    tests): presets match the data and fit eight cells; DEFAULT is the
    identity at every venue (and no shader); each preset touches only its
    part (a SAME kitchen follows the surface); contrast at every venue for
    every surface and kitchen against every line (worst 2.65, min 2.5) and
    the ball (worst 2.68, min 2.0); the page, the save, and a bad index
    loading as DEFAULT. 124/124 plus the e2e; golden traces unchanged.
    Screenshots: the COURT page (BLUE / SLATE / CONCRETE / YELLOW), and
    SUNSET in PINK / LIME / SNOW.
  - Status: **Done**. (Have a look at a few combinations if you like.)

### 6. `feature/cld-night`: night courts (ADR-045)

- [x] `PORT-06` TIME = DAY, DUSK or NIGHT. The backdrop darkens by the
  ADR's factors and the court stays lit under floodlights. The crowd
  dims and night ambience plays.
  - Accept: the contrast test extended to every time of day. A shadow
    stays visible on the darkest court (KNOWN_ISSUES #26's lesson).
    Screenshots of all three times at all three venues.
  - Verified: TIME (DAY / DUSK / NIGHT) follows VENUE on the COURT page,
    saved. The backdrop layers, the stands' crowd and the surround take
    the time's dark scales (modulate, and the ground shader by mask
    role); the court parts and the net take its lit scales; players,
    ball and HUD keep their colours. NIGHT plays the crickets (SUNSET's
    loop) at every venue. On a court too dark for a dark shadow (BLACK)
    shadows draw grey (KNOWN_ISSUES #26's lesson). `test_night.gd` (5
    tests): DAY changes nothing, no time brightens, NIGHT goes blue; line
    and ball contrast for every court at every time and venue (worst
    lines 2.65, ball 2.68, lines on LAVA 3.60); a shadow visible on every
    court at every time (worst 1.22, min 1.2); the night view's layer
    scales, crowd, players and crickets; the TIME row and save. 129/129
    plus the e2e; golden traces unchanged. Screenshots: all three times
    at all three venues, and BLACK at NIGHT with grey shadows.
  - Status: **Ready to test**: COURT → TIME → NIGHT (and DUSK) at each
    venue. Is NIGHT dark enough, too dark, or too blue?

### 7. `feature/cld-watcher-replay`: the watcher (ADR-042) and close calls (ADR-041)

- [x] `PORT-07` In singles, the opponent's partner sits out at the
  venue's watcher spot and cheers their side. A close out-call after a
  long rally freezes and shows a close-up of the bounce with a caption
  ("OUT BY A HAIR!").
  - Accept: a port of `test_replay.c`. The replay shows only for long
    rallies that land just out: never for short rallies, other faults or
    wide misses. Display-only, so the golden traces don't move.
  - Verified: `sim/replay.gd` is replay.c (pure). On the point result's
    first frame the view checks the rally (8+ shots) and the landing
    (6 inches or less past a line; the farther line past a corner) and
    shows `view/close_call.gd`: the line and the ground beyond, cropped
    from the venue's ground layer at 3x (so COURT colours and TIME
    follow), the ball dropping in slow motion onto its spot with its
    shadow and one small bounce, its edge as far past the line's edge as
    it landed, and the caption (OUT BY A HAIR! / 1 INCH! / N INCHES!).
    The quip waits. The watcher: in a singles ladder match the captain's
    partner, in their own look at crowd size, takes the seat at the
    venue's `watcher` spot (the top half when sitting), faces the court,
    hops and cheers when their teammate wins a point or the match, and
    darkens with the crowd at NIGHT. `test_replay.gd` (5 tests):
    test_replay.c ported (each line and direction, a hair, a corner, and
    none for a short rally, another fault, a wide miss, or no line); the
    view's close-up (caption, the ball resting past the line, the quip
    held back, gone after the point); the watcher only in singles ladder
    matches (not doubles, the default CPU, the demo, practice, or 2P),
    one seat taken at each venue, the cheer and hop, NIGHT; 1,500 frames
    identical to a bare sim. 134/134 plus the e2e; golden traces
    unchanged. Screenshots: the close-up at PARK, KIDDO watching at all
    three venues.
  - Status: **Ready to test**: play a singles ladder match (KIDDO watches
    DAD). The close-up needs an 8-shot rally that lands just out, so it's
    rare; `tools/screenshot.gd -- singles park 160 out.png closecall`
    forces one if you want to look without waiting.

### 8. `feature/cld-records`: records and initials (ADR-021, ADR-040)

- [ ] `PORT-08` A RECORDS page: wins and losses by mode, the longest
  rally, ladder clears, the best practice streak, and a record against
  each opponent. Initials on a new record, with an arcade keyboard, a
  30-frame input lockout and only on a finished match. The save goes to
  layout v3 with a migration.
  - Accept: save tests for the v2 to v3 migration and the initials rules
    (from `test_save.c`), and the record tests ported. Records never
    count in the demo.
  - Verified: —
  - Status: Planned. It should be **Done**, plus a quick look.

### 9. `feature/cld-release`: release prep (playbook 0.1, §9)

- [ ] `PORT-09` Export presets (macOS, Windows, Linux, Web). A build ID
  on the title (commit plus a dirty flag). An app icon from the art. A
  headless export check. Release notes generated from this sheet.
  `CLAUDE.md` refreshed.
  - Accept: exports build headless. The build ID matches `git describe`,
    and a dirty tree is refused.
  - Verified: —
  - Status: Planned. It will be **Ready to test**: you run a build.

## For you

Questions and things to try, added as the run goes. Nothing here blocks
the chain: each has a default I've gone with.

- **PORT-01 feel:** does the shake feel right? It's 3 px on drives and
  4 px on put-aways, over 8-10 frames. The trail shows only on drives (a
  deep standard shot is just under its speed threshold), and the CPUs
  drive only on put-aways, so you'll mostly see it on your own drives
  (K). Default: as built. Any effect can be switched off in `Feel.ON`.

- **PORT-02 audio:** the mix levels are my guesses: hits at about -2 dB,
  applause 6..15 of 15, ambience at -12 dB with the swell. Tell me
  anything too loud or too quiet. Pan is full width by court x; if it's
  too wide on headphones, I'll halve it.

- **PORT-03 menus:** Start pauses on a point result as well as in play
  (the sim always allowed it; an old smoke check said otherwise and was
  wrong). Keep that, or should a pause only be possible during a rally?
  Also: SINGLES and DOUBLES stay on MAIN, so the common case is one press;
  the rest of the old list moved to MATCH SETUP. The window options are
  untested on a real display here (headless has no window).

- **PORT-04 Player Select:** CPUs still draw the colour sheets, so a
  red CPU holds a red paddle while playing the standard (blue) paddle's
  stats (KNOWN_ISSUES #37). I left it: it reads better than a blue
  paddle on every shirt. Say if you'd rather CPUs show blue. The paddle
  icons are drawn in code from the paddle palettes, since the art has no
  paddle icons; real icons would be a small art task.

- **PORT-06 night:** one port-side deviation. YELLOW lines on a LIME
  kitchen at NIGHT measured 2.45, under the 2.5 minimum. The SNES's
  5-bit tables happen to round it up to 2.61, but the HD port scales in
  float. So the lines take half the night's dimming ("they catch the
  floodlights"), which puts the worst case at 2.65. Shadows off the
  court, on a dark surround at NIGHT, are faint (KNOWN_ISSUES #38).
  There are no floodlight poles or light pools in the art; a lighting
  pass would be an art task.

- **PORT-07 replay/watcher:** the close-up's baseline is slanted, because
  it crops the real perspective ground rather than a flat SNES tile map.
  I think it reads as "the real spot", but say if you'd prefer a flat,
  square-on view. The watcher is the partner's match sprite at half size;
  sitting shows the top half above the bench, as on the SNES.

## If time runs short or long

- **Short:** 7 and 8 can swap with 9, so the release prep never gets
  squeezed out.
- **Long:** open play (ADR-034) is the next candidate. The playbook
  rates it an expensive wildcard, so it would get its own branch and
  ADR.
- **Out of scope for this run:** career (ADR-047), with a reason
  recorded in `design/IDEAS.md`.
