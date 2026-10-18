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

- [x] `PORT-08` A RECORDS page: wins and losses by mode, the longest
  rally, ladder clears, the best practice streak, and a record against
  each opponent. Initials on a new record, with an arcade keyboard, a
  30-frame input lockout and only on a finished match. The save goes to
  layout v4 with a migration (practice took v3).
  - Accept: save tests for the v3 to v4 migration and the initials rules
    (from `test_save.c`), and the record tests ported. Records never
    count in the demo.
  - Verified: save layout **v4** (practice had already taken v3): the
    win streak and best streak, shutouts, wins and losses against each
    ladder team, and who holds the best streak and the longest rally;
    v3 migrates with everything kept and nobody holding a record.
    `meta/initials.gd` is story.c's initials card (A-Z wrapping, held
    Up/Down repeating after 16 frames then every 4, B/A/Right next, Y/Left
    back, Start saves, nothing but Up/Down for 30 frames, the letters
    shown kept after 30 seconds, starting from the session's last
    initials). A finished match that beat a record opens it before the
    result screen, with the match waiting under it; RESTART and MAIN
    MENU drop the request but keep the number; a run extends its own
    streak record without asking again. RECORDS shows SINGLES, DOUBLES,
    BEST STREAK and LONGEST RALLY (holder, then count, --- for nobody),
    SHUTOUTS, LADDER with clears, PRACTICE BEST, VS (Left/Right through
    the teams), and ERASE RECORDS (press B twice; settings stay).
    `test_records.gd` (7 tests): the v3 to v4 migration; test_save.c's
    initials rules; test_story.c's card rules; the card after a finished
    match only (vs and shutouts recorded, the sim waiting, RESTART
    dropping the request); 6,000 demo frames recording nothing; the page.
    140/140 plus the e2e; golden traces unchanged. Screenshots: the
    initials card and the RECORDS page.
  - Status: **Done**. (A quick look: win a match and enter initials.)

### 9. `feature/cld-release`: release prep (playbook 0.1, §9)

- [x] `PORT-09` Export presets (macOS, Windows, Linux, Web). A build ID
  on the title (commit plus a dirty flag). An app icon from the art. A
  headless export check. Release notes generated from this sheet.
  `CLAUDE.md` refreshed.
  - Accept: exports build headless. The build ID matches `git describe`,
    and a dirty tree is refused.
  - Verified: `game/export_presets.cfg` (macOS universal, Windows,
    Linux, Web; tests and tools left out, `build_id.txt` carried, into
    `build/`). `tools/export.sh` refuses uncommitted changes (checked:
    "refused" on the dirty tree before this commit), writes
    `build_id.txt` from `git describe --always --dirty`, exports the
    `.pck` headless and boots it for 200 frames (no export templates
    needed), then exports each preset when templates are installed.
    `meta/build_info.gd`: the title's top right shows `BUILD <id>`, or
    `BUILD DEV <describe>` from a checkout. `game/icon.png` from P1's
    head in the art (`tools/make_icon.py`), set as the project icon.
    `tools/release_notes.py` writes `game/RELEASE_NOTES.md` from this
    sheet. CLAUDE.md and the README refreshed. `test_release.gd` (3
    tests): the build ID matches `git describe` (and DEV in a checkout),
    the title shows it, the icon is 256 px and set, and the four presets
    leave out tests and tools, carry the ID, and export into `build/`.
    143/143 plus the e2e; golden traces unchanged; `export.sh --check`
    passes on the committed tree.
  - Status: **Ready to test**: the platform exports need Godot's export
    templates, which aren't installed here (see "For you"). Then run
    `game/tools/export.sh` and try a build.

## Phase 2: beyond the SNES (started 2026-10-17)

The port is feature-complete against the SNES. Phase 2 cleans up and then
designs past the 16-bit limits: smooth motion, mouse and device-aware
prompts, remapping, stats. The chain continues from
`feature/cld-release`. The sim and the golden traces stay untouched
unless a branch says otherwise.

```
feature/cld-release        (pushed)
 10 feature/cld-cleanup
 11 feature/cld-modern-ui
 12 feature/cld-controls
 13 feature/cld-match-stats
 14 feature/cld-hud-polish
```

### 10. `feature/cld-cleanup`: organize the code

- [x] `PORT-10` Split the two big view files: the title's pages move to
  their own builders, and MatchView's camera, crowd and watcher become
  components. Retire leftovers (the old MODS presets list stays only as
  a save reader). Every gdscript warning fixed; the folder layout
  documented.
  - Accept: no behaviour change (tests and golden traces unchanged, the
    e2e passes); the files are smaller and named for what they do.
  - Verified: `meta/settings.gd` (`Settings`) now owns every setting,
    loading and storing them, the window options and the match config;
    the title only edits it (650 to 456 lines). `PracticePage` takes the
    drill editor out of the title. MatchView's crowd, watcher and camera
    lean are components (`Crowd`, `Watcher`, `CameraLean`; 692 to 588
    lines). `GameControls.pad_bits()` replaces two copies of the pad-bit
    reader. The old MODS presets survive only as `OLD_MOD_PRESETS`, to
    read old saves. Two fixes on the way: the e2e was flaky (two physics
    ticks in one frame could flush a press and its release together); it
    now runs one tick per frame and passed six runs in a row. And a
    leftover `build_id.txt` from an export made a checkout show a stale
    build ID; checkouts now always ask git. 143/143 plus the e2e; golden
    traces unchanged; screenshots match.
  - Status: **Done**.

### 11. `feature/cld-modern-ui`: modern menus

- [x] `PORT-11` Menus that move: pages slide and fade, the cursor eases
  between rows, a highlight bar replaces the ball icon, values tick
  with arrows. Fades between the title and a match. Button prompts
  follow the last device used (keyboard keys or pad glyphs). Mouse:
  hover selects a row, click presses, wheel changes.
  - Accept: menu tests still select by id; new tests for the device
    switch, the mouse mapping and the transitions finishing; inputs
    during a transition are swallowed (rule 9).
  - Verified: `MenuPage` redone: a highlight bar that eases between rows
    (the ball icon is gone), the selected label slides in a little,
    arrows on rows you can change, a pop when a value changes, and pages
    that slide and fade in over 8 frames (from the right going in, the
    left coming back) while menu input waits. Mouse: hover selects, click
    presses, the wheel changes, right click backs out (title pages and
    the pause menu). `Prompts` / `PromptBar`: every help line is now
    glyphs for the device touched last: key caps with the bound key on
    the keyboard; on a pad the bound face button as the pad shows it
    (Xbox letters, Nintendo letters, PlayStation shapes) or START / D-PAD.
    Screens fade out and in (8 + 10 frames), the old screen frozen while
    it fades. Also: the perf gate timed one run, so an OS hiccup could
    fail it (6 ms once); it now keeps each frame's faster time over two
    identical runs. `test_modern_ui.gd` (6 tests): device switching
    (stick drift ignored, the mouse counts as keyboard), prompt labels for
    every family, a bar redrawing on a device change, the mouse driving a
    page, slides swallowing clicks and settling, the bar easing, the
    value pop, the title waiting out a slide, and the fade swapping at
    black. 149/149 plus the e2e (re-timed for the transitions); golden
    traces unchanged. Screenshots: MAIN with key caps, OPTIONS with
    PlayStation shapes, pause with Nintendo letters, Player Select with
    Xbox.
  - Status: **Ready to test**: try the menus with the mouse, then pick up
    a pad mid-menu and watch the prompts switch.

### 12. `feature/cld-controls`: remapping and accessibility

- [x] `PORT-12` A CONTROLS page: rebind every action for keyboard and
  pad, with conflict swaps and RESET, saved. ACCESSIBILITY: screen shake
  and flashes on/off, a bigger HUD text option, and a hold-to-charge
  serve assist.
  - Accept: rebinding tests (a rebind reaches the input map, a conflict
    swaps, reset restores, the save keeps it); every option checked
    against its effect.
  - Verified: `game_ui/bindings.gd`: P1's main key and pad button per
    action (HIT, DRIVE, SOFT, START, the four moves), applied to the input
    map (the sticks stay on the moves), saved in `settings.bindings`. A
    rebind that takes another action's key or button swaps it over, so
    nothing is left unbound. OPTIONS gains CONTROLS (B on a row, then
    press the key or button; Esc cancels; RESET DEFAULTS) and
    ACCESSIBILITY: SCREEN SHAKE, FLASHES (the white hit flash), HUD TEXT
    (LARGE scales the banners, quips and result line 1.5x) and SERVE
    ASSIST (holding B lets go by itself at 24 of 30 on the way up; an
    input aid, the sim's rules unchanged). Pad prompts now name D-pad,
    shoulder and stick buttons per family. `test_controls.gd` (5 tests):
    a rebind reaching the map and the prompts, conflicts swapping keys and
    buttons with every action still bound, reset, the save keeping
    remaps, malformed saves loading defaults, the page listening (key,
    pad, Esc, reset, swallowed press), and each accessibility option
    against its effect (shake, flash, large text, the assist serving
    strong where plain holding never serves). 154/154 plus the e2e;
    golden traces unchanged. Screenshots: CONTROLS (Xbox and Nintendo)
    and ACCESSIBILITY.
  - Status: **Ready to test**: remap a key and a pad button, play a
    point, and restart the game to see them kept. Try SERVE ASSIST.

### 13. `feature/cld-match-stats`: post-match stats

- [x] `PORT-13` After the result: a stats card per side (points won on
  serve, winners by shot type, faults by kind, longest rally, average
  rally), collected from sim events, display only. Totals roll into the
  records.
  - Accept: stats tests against scripted points; a side-by-side run
    proves it display only.
  - Verified: `meta/match_stats.gd` collects from the events: points,
    serve points won, aces (an unreturned serve), winners (never
    returned) by the winning shot, errors (faults) by kind, shots,
    drives, and every rally's length. The result screen shows a stats
    card (after the initials card, never in the demo or practice) with
    the banner moved up over it and the prompts below; a rematch clears
    it. P1's points won and lost, aces and winners roll into the records
    (two new RECORDS rows). `test_stats.gd` (4 tests): scripted points
    (a drive winner, an ace, an error, serve points, the rows); a whole
    bot match adding up (points equal the score, a rally per point, every
    shot counted); the card's timing and the totals; 1,500 doubles frames
    with stats on identical to a bare sim. 158/158 plus the e2e; golden
    traces unchanged. Screenshots: singles at SUNSET and doubles at PARK.
  - Status: **Ready to test**: finish a match and read the card.

### 14. `feature/cld-hud-polish`: a livelier HUD

- [x] `PORT-14` Scores that pop when they change, a serve indicator
  (who serves, and in doubles which server), a live rally counter for
  long rallies, and a MATCH POINT pulse.
  - Accept: HUD tests for each element's trigger; screenshots.
  - Verified: scores grow and flash gold for 14 frames when they go up
    (not on a reset); a ball beside a score panel marks the serving side;
    in doubles a marker in the server's team colour bobs over their head
    while they set up and toss; a RALLY counter shows from the fifth shot
    of a live rally and pops on each shot (not in the demo or practice);
    MATCH POINT pulses. The serve prompt is a prompt bar now: the bound
    button, "SERVE  HOLD FOR POWER". `test_hud.gd` (4 tests): each
    element against its trigger and its absence. 162/162 plus the e2e;
    golden traces unchanged. Screenshot: a doubles serve with the marker
    and prompt.
  - Status: **Ready to test**: play a doubles match and a long singles
    rally.

### 15. `feature/cld-controller`: controller support (asked for 2026-10-17)

- [x] `PORT-15` The standard approach most games take. Any pad Godot's
  SDL mappings know (Xbox, PlayStation, Switch Pro, most generic pads) is
  read on the Xbox layout, and **everything shown uses Xbox buttons**:
  A, B, X and Y in their colours, LB/RB/LS/RS, the Menu and View buttons,
  and a drawn D-pad. In one-player any connected pad drives P1, so you
  just pick one up. With 2P on, the first pad is P1's and the second P2's;
  with one pad, P1 plays on the keyboard and P2 on the pad. Pads can be
  plugged and unplugged at any time; a toast says CONTROLLER CONNECTED or
  DISCONNECTED, and losing one mid-match pauses it. Holding a stick or
  the D-pad in a menu repeats (300 ms, then every 85 ms, in real time).
  Rumble on your own contact (a drive harder, a soft shot barely), with
  VIBRATION in ACCESSIBILITY.
  - Accept: tests for pad assignment and the input map following it,
    hot-plug news, menu repeat timing, a lost pad pausing (not the
    demo), the toast, rumble only for a human's shots on a pad and only
    with VIBRATION on.
  - Verified: `test_controller.gd` (6 tests) as above, plus the prompt
    tests now checking Xbox glyphs for every pad. One fix along the way:
    the first menu repeat counted frames, which raced on fast refresh
    rates, so it now runs on the clock. 168/168 plus the e2e; golden traces
    unchanged. Screenshots: CONTROLS, pause and the title's prompt bar on
    a pad. No physical controller here, so rumble and hot-plug are tested
    through their code paths only.
  - Status: **Ready to test**: plug in a controller (and pull it out
    mid-match), try the menus with the stick, and feel the rumble.

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

### 16. `feature/cld-multiplayer`: four players on controllers (asked for 2026-10-17)

- [x] `PORT-16` MULTIPLAYER on MAIN opens a lobby. Up to four
  controllers join with A, each taking the first free player number
  (P1-P4) and a card: SIDE, SHIRT (unique), BODY, PADDLE. LB/RB switch
  SINGLES and DOUBLES. In doubles **the players choose their sides, and
  whoever shares a side is their partner**; an empty place on a side gets a
  CPU (free colour, standard paddle). A readies, B un-readies or leaves,
  and Menu starts once everyone is ready and the teams work. Every human
  plays on their own pad; anyone's Menu pauses and anyone's A works the
  pause menu; a P1-P4 tag floats over each player in their colour. Friends'
  matches leave the records alone. All pads are taken to be Xbox pads on
  the default layout for now (KNOWN_ISSUES #39).
  - Accept: lobby rule tests; the match config it builds; four humans in
    the sim each moved only by their own intent; the view reading four
    controllers, pausing on anyone's Menu, and the title's lobby end to
    end.
  - Verified: `meta/lobby.gd` (pure rules), `view/lobby_screen.gd`, the
    pad layer in `game_ui/controls.gd` (pads read directly, with
    `fake_pads` so tests can drive four controllers), multiplayer input in
    `MatchView`, and tags in the HUD. One sim change: KID's swing assist
    now covers slot 3 too (main.c assisted slots 0-2, since 2P sat on slot
    2). No existing config has a human there, so the golden traces are
    unchanged. Also: B now backs out of every menu on a pad (the Xbox
    convention), as well as X. `test_multiplayer.gd` (7 tests). 176/176
    plus the e2e. Screenshots: the lobby with three players, and a
    four-player doubles match with the tags.
  - Status: **Ready to test**: needs two to four controllers. MAIN →
    MULTIPLAYER, A to join, pick sides, A to ready, Menu to start.

### 17. `feature/cld-open-play`: open play (ADR-034, the "long" candidate)

- [x] `PORT-17` OPEN PLAY on MAIN (the third row, as on the SNES) opens
  the park: three courts at three skill levels (UNDER 3.5 teal, 3.5-4.5
  gold, 4.5+ red), each with a ladder game going to 7 and a paddle rack at
  its gate, and the clubhouse beside them. Walk with the D-pad (the fences
  and walls are solid); B at a rack stacks your paddle, takes it back, or
  moves it. When your paddle reaches the top at a changeover the park
  calls you ("YOUR GAME!", "WITH PETE VS GOTH CLUB") and starts a doubles
  match at the park against the team drawn, with the captain next in line
  as your partner (their look, paddle, and play style), at the court's
  difficulty (KID stays KID), on the saved points and modifiers: no intro
  card, no ladder change. B on the result goes back to the park ("YOU WON
  5-3"), Start to the title. In the clubhouse: B at the records board
  turns its pages, B at the ball machine starts practice on the saved
  drill (PARK on its pause menu comes back), and the teams waiting sit on
  the bench. 2P comes along as your partner with PLAYERS 2P, or Start on
  pad 2 in the park.
  - Accept: test_open_play.c and test_opponents.c's test_partner ported
    and passing; the park view only reads the park; MAIN reaches the
    park, the call starts the match, B on its result comes back; the
    golden traces unchanged; screenshots of the park.
  - Verified: `sim/open_play.gd` (open_play.c in order, ints, its own
    xorshift16), `view/park_view.gd` (render_park.c: the panel's lines
    as text + `PromptBar`), `MatchConfig.partner`/`open_play`,
    `Settings.open_play_config`, the park kept in `scenes/main.gd`.
    `test_open_play.gd` (15 tests): the C's levels, start, walking and
    sliding, stacking, your turn (called after 21 s, as the C's "about
    20"), the 20-minute soak (45/46/48 games by court, every team only at
    its level and in exactly one place), 2P, the clubhouse, the partner;
    plus the config, the panel's lines (and that the font has every
    glyph), the view vs a bare park over 3,000 frames, MAIN → park → game
    → park → title, and the ball machine's round trip. `MenuPage.ROW_H`
    30 → 28 so ten MAIN rows clear the prompt bar. No save change.
    191/191 plus the e2e; golden traces unchanged. Screenshots: the park
    (stacked on court 2), the clubhouse with a records page, the call,
    a park game with PETE partnering, and MAIN with OPEN PLAY.
  - Status: **Ready to test**: MAIN → OPEN PLAY. Walk to a rack, B,
    and wait about 20 s; play the game; B on the result. Try the
    clubhouse board and ball machine. Look at the park art (drawn in
    code, KNOWN_ISSUES #40).

### 18. `feature/cld-hd-audio`: HD sounds (asked for 2026-10-17)

- [x] `PORT-18` Every effect and ambience loop remade without the SNES's
  limits by `audio/hd-sfx/make_sfx.py` (numpy, fixed seeds; see its
  README). Shots have their own samples instead of a pitched one; hits and
  bounces have variants played round-robin with a little pitch spread.
  The SNES set stays in `audio/snes-sfx`.
  - Verified: levels, lengths, DC and loop seams measured (`--report`, and
    each loop's seam jump is no bigger than an ordinary sample step);
    spectrograms looked over, which caught and fixed a reverb that hissed
    and a filter that wrapped a sound's end onto its start.
    `test_audio.gd`: the sound per shot, and every named effect having its
    samples. 197/197 plus the e2e; a windowed match plays with no audio
    errors.
  - Status: **Ready to test**: nobody has listened yet. Play a rally,
    lose a point to the net, win one, and sit on the title at each venue
    and at NIGHT.

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

- **PORT-08 records:** your first win on this build asks for initials,
  because the best streak starts at 0 in the new layout. The SNES records
  page's L + R + X erase became an ERASE RECORDS row you press twice.

- **PORT-09 release:** the Godot 4.7.2 export templates are installed now
  (downloaded with your OK on 2026-10-17 and checked against Godot's
  SHA-512 sums). `game/tools/export.sh` builds all four into `build/`. macOS builds
  are ad-hoc signed only, so Gatekeeper will need a right-click > Open.
  The version is 0.9.0 in the presets and `project.godot`; tell me what
  you want it to be.

- **PORT-11 modern UI:** (since PORT-15, every pad shows Xbox buttons.) The game still names the swing buttons by SNES role (hit,
  drive, soft), so on an Xbox pad "hit" shows A. Fades are 8 frames out,
  10 in. Say if any of it feels slow.

- **PORT-12 controls:** only P1's main key per action is remappable; the
  second keys (arrows, J, Esc) stay unless a rebind takes them. 2P's pad
  keeps the default layout. SERVE ASSIST lets go at 24 of 30, which is
  strong but not the fastest; tell me if it should aim higher.

- **PORT-13 stats:** a "winner" here is a ball the other side never got
  back (it bounced twice); points won on the other side's fault count as
  their errors. With the CPU's style, most points end in errors, so
  winners stay low. Say if you want other rows (kitchen time, dinks,
  serve speed).

- **PORT-16 multiplayer:** the keyboard can't join the lobby (it's
  controllers only, as asked); it only backs out of an empty lobby.
  Someone must be on the left side: the sim's slot 0 is always a human.
  The CPUs in a multiplayer match use the MATCH SETUP difficulty. Friends'
  matches don't touch the records or the ladder. Do you want stats-only
  records per player number?

- **PORT-17 open play:** the park is drawn in code (there's no park art
  in `art/levels`), and its people are the match sprites at a third of
  their size, so their faces still show. You walk it in your last Player
  Select choice. Court 1 reads UNDER 3.5 because the bitmap font has no
  `<` (a glyph would be a small art task). Your park games count in the
  doubles record and the VS row for that team. Say if the park should be
  bigger (a 3x zoom would scroll more, like the SNES's two screens).

- **PORT-18 sound:** I can't hear these: they were checked by measuring
  and looking at spectrograms. Tell me which sounds are off (too bright,
  too quiet, too long, wrong character) and I'll retune them in
  `make_sfx.py`. The mix trims are in `Sfx.TRIM_DB`.

## If time runs short or long

- **Short:** 7 and 8 can swap with 9, so the release prep never gets
  squeezed out.
- **Long:** open play (ADR-034) was the next candidate, rated an
  expensive wildcard; it got its own branch (PORT-17,
  `feature/cld-open-play`) and an ADR-052 amendment.
- **Out of scope for this run:** career (ADR-047), with a reason
  recorded in `design/IDEAS.md`.
