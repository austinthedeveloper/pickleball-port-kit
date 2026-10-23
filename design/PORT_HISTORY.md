# Port history: the finished tasks

The finished tasks of the port, in full, moved out of
`design/PORT_ROADMAP.md` (PORT-00 to 22 in PORT-23; 23 to 39 and 41 in the
2026-10-19 cleanup; 42 to 58, but 55, in the 2026-10-21 one; 55, 59 to 77, but 62, in the
2026-10-23 one) so the sheet stays short. Each block
is as it was when its branch landed. `game/tools/release_notes.py` reads
this file and the sheet together.

## Phase 1 chain

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

## Phase 2 chain: beyond the SNES (started 2026-10-17)

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
  - Status: **Done**: you listened and they sound good (2026-10-17).

### 19. `feature/cld-park-redesign`: the park, modernised (asked for 2026-10-17)

- [x] `PORT-19` The open-play park, taking the old screen as a
  wireframe: a 3/4 view from about a second storey, twice as close, the
  camera following you (a little ahead as you walk; framing the room
  inside the clubhouse). Art by `art/park/build_park.py` with the venue
  pixel kit: the ground (striped grass, a concrete walkway with spurs,
  the courts in their level colours, the clubhouse floor, baked shadows)
  and upright sprites sorted with the people by depth (chain-link fences,
  sliced where they run into the picture; nets; racks with the waiting
  paddles; benches; lamps; trees; the clubhouse's walls and roof). The roof
  fades away and the front wall ghosts while you're inside; a tree's canopy
  fades when you walk behind it. HUD: OPEN PLAY and EXIT top left, a COURTS
  panel top right (level, score or NEXT/YOU, +N waiting), and the message
  and prompts at the bottom. The park sim is untouched.
  - Verified: `test_open_play.gd` unchanged and passing (the view only
    reads the park); `test_layout.gd` now also checks the park's HUD
    outside and in the clubhouse, which caught a prompt bar leaving its
    old text up for a frame (fixed in `PromptBar`). 197/197 plus the e2e;
    golden traces unchanged. Screenshots: the walkway by court 2, the
    call, and the clubhouse.
  - Status: **Done**: you looked and approved it (2026-10-17).

### 20. `feature/cld-fun-venues`: DINOSAUR, SPACE and UNDERSEA (asked for 2026-10-17)

- [x] `PORT-20` The SNES's other three venues (ADR-046), drawn at
  960x540 by the level pipeline in the levels' style and manifest format:
  each has the eight parallax layers, the court mask, its venues.json
  default court (DINOSAUR GREEN / ORANGE / GRASS / WHITE, SPACE NAVY /
  PURPLE / ASPHALT / CYAN, UNDERSEA AQUA / NAVY / SAND / WHITE), four
  standing spectators, and a watcher spot behind the fence. DINOSAUR: a
  sunset jungle, palms, a volcano with lava and smoke, a long-neck over the
  trees, pterodactyls; a stegosaurus, raptors, a triceratops and a T. rex
  over a wooden palisade. SPACE: stars, a nebula, Earth, Saturn, a moon,
  a dome, a rocket on its gantry; aliens and astronauts behind a lit
  chain-link fence. UNDERSEA: light shafts and bubbles, a shipwreck, fish,
  jellyfish, a turtle, kelp and coral; an octopus, crabs, a pufferfish, a
  seahorse and a starfish along a rope fence. The creatures are shapes lit
  by `pix.solid` (`art/levels/tools/critters.py`). In the game: the COURT
  page's VENUE cycles all six, the ladder's GYM BROS, GOTH CLUB and SURF
  CREW play at home there (VS sets the venue), the venues' own ambience
  loops play by day, and every TIME works (NIGHT plays the crickets, as on
  the SNES).
  - Accept: all six venues playable and selectable; the existing three
    venues' art byte-identical; the court-colour, night and layout tests
    cover the new venues; golden traces unchanged.
  - Verified: the park, lakeside and sunset layers rebuild byte-identical
    (the player and crowd sheets that flip under KNOWN_ISSUES #35 were
    kept as committed). New tests: `test_court` (the fun venues paint their
    venues.json presets), `test_night` (every venue at DUSK and NIGHT: the
    backdrop and crowd dim, the court lit, the ambience),
    `test_audio` (every venue has and plays its loop), `test_layout`
    (a singles HUD at every venue and time, vs the home team with the
    watcher out), `test_view` (every venue builds); the existing contrast
    and watcher tests now loop over six venues, which caught a dim CYAN
    line paint at SPACE (fixed: the paint is the preset). 201/201 plus the
    e2e; golden traces unchanged. Screenshots: each venue at DAY and
    NIGHT in a ladder singles match, and the COURT page at UNDERSEA.
  - Status: **Done**: you played and listened, and approved it for v0.6.0 (2026-10-18).

### 22. `feature/cld-music`: music (asked for 2026-10-17)

- [x] `PORT-22` An original soundtrack, where the SNES had none
  (ADR-029/031's `M4-AUDIO-03`; ADR-052 amended): a title theme (D major,
  132 BPM), the park's theme for open play (G, 116), a calmer match loop
  per venue (PARK: F, 100, electric piano and flute; LAKESIDE: A, 94,
  marimba and bells; SUNSET: Eb, 86, mellow keys and a round lead), and
  stingers for match won, match lost and ladder cleared. All composed and
  synthesized by `audio/music/make_music.py` (numpy, fixed seeds; see its
  README): 48 kHz stereo, loops seamless. `view/music.gd` crossfades
  between screens, stings a match's end, ducks under the applause and the
  whistle, and follows SOUND; MUSIC (OFF..100%) on OPTIONS, saved.
  - Verified: `test_music.gd` (each screen's track through the real main
    scene, the equal-power crossfade, the stingers from a real match and
    none from the demo, the duck, the MUSIC row, its save and an older
    save's default). Loop seams measured (`--report`). 205/205 plus the
    e2e; golden traces unchanged.
  - Integration (0.6): with the fun venues merged, the three new venues
    got their own match loops too (DINOSAUR: D dorian, 104 BPM, marimba,
    toms and brass; SPACE: C lydian, 90 BPM, echoing pulse arpeggios and
    bells; UNDERSEA: E minor, 80 BPM, marimba drops and flute), since the
    music test asks every venue for one.
  - Status: **Done**: you played and listened, and approved it for v0.6.0 (2026-10-18).

### 21. `feature/cld-career`: career players (ADR-047, asked for 2026-10-17)

- [x] `PORT-21` MAIN's RECORDS row is now CAREER: three save slots, each a
  named player with a look, lifetime stats and unlocks, and the old
  records behind a RECORDS row. A slot opens the player's card (singles
  and doubles W-L, aces, shutouts, best streak, longest rally, unlocks
  n/9 and the next with its hint) and makes them active; an empty slot
  makes a new player, named on an arcade keyboard, then dressed in the
  editor (body, skin, hair, shirt, hat, paddle; locked hair and hats are
  skipped; a GEAR row shows the hat's shift on the paddle), with a big
  portrait beside it. NO PLAYER plays as before. The active player is
  1P: Player Select starts on their look (skin, hair and hat on the
  portrait and thumbnails, the gear in the bars), the HUD shows their
  name, open play, the ball machine and the park's walk-around sprite
  use their saved look, and their hat's gear applies to their paddle
  (ADR-047 stage 4). Matches against the CPU (not the demo, practice, 2P
  versus, or multiplayer) count, and after the initials card an
  UNLOCKED! card lists what was just earned.
  - Accept: test_career.c and test_career_page.c ported and passing; save
    v5 with a test loading a v4 image; a career match recorded through
    the view; the view equal to a bare sim; the title's CAREER pages by
    row id; layout cases for every new screen; golden traces unchanged;
    screenshots.
  - Verified: `sim/career.gd`, `meta/career_page.gd`, `Paddles.profile`,
    `MatchConfig.set_career`/`set_career_p1`, `SaveGame` v5, CAREER in
    `view/title_screen.gd` with `view/career_keyboard.gd` and
    `view/career_preview.gd`, `PlayerLook.for_career`, the HUD's name
    and UNLOCKED! card. `test_career.gd` (23 tests) and
    `test_layout.test_career_screens` (the slots, the card at every
    unlock count, every editor value, the keyboard at every length and
    key, the HUD and the card at their widest). 221/221 plus the e2e;
    golden traces unchanged. The screenshots caught the career tables
    being read before they were loaded (the look fell back to the team
    sheet); fixed by loading them with the first `Career`. Screenshots:
    the slots, the card, the editor, the keyboard, a singles and a
    doubles match in the look, the UNLOCKED! card, Player Select, and the
    park.
  - Status: **Done**: you played and listened, and approved it for v0.6.0 (2026-10-18).

## Questions asked along the way

Each had a default that stands; ask again any time.

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

## Phase 1 contingency

- **Short:** 7 and 8 can swap with 9, so the release prep never gets
  squeezed out.
- **Long:** open play (ADR-034) was the next candidate, rated an
  expensive wildcard; it got its own branch (PORT-17,
  `feature/cld-open-play`) and an ADR-052 amendment.
- **Out of scope for this run:** career (ADR-047), with a reason
  recorded in `design/snes/IDEAS.md`. (Since ported: PORT-21,
  `feature/cld-career`.)

## Phase 3 and 4 (started 2026-10-18)

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

### 34. `feature/cld-polish-0.9.2`: from playing 0.9.1 (2026-10-18)

- [x] `PORT-34` Four things you found: the update now comes up when the
  game opens and can't be skipped (`view/update_screen.gd`, ADR-057
  amended); OPTIONS > UPDATES no longer sticks on 98%; HOW TO PLAY's match
  lessons play HENDERSON at full speed (KID's slowed ball read as
  slowdown) and THE KITCHEN is a ball-machine drill; ONLINE's HOST screen
  shows up to two addresses, 192.168 first, named by adapter.
  - Verified: `test_updater.test_the_update_screen` (each state: straight
    on, waiting then on, no way past a download, the bar, INSTALLED, a
    failed restart, offline, RETRY / PLAY, GET IT / PLAY),
    `test_layout.test_update_screen`, `test_tutorial` (HENDERSON, the
    kitchen drill's counting and advice, a volley feasible on 9 of 120
    spot and timing tries, TWO BOUNCES played through), `test_online` (a
    PC with two adapters). The lessons' frame cost measured: under 0.1 ms.
    302/302 plus the e2e. Screenshots: the update screen downloading,
    installed, failed.
  - Status: **Ready to test**: 0.9.1 gets 0.9.2 from OPTIONS > UPDATES
    once; from then on updates come up at launch.

## Phase 5: the bible (planned 2026-10-18)

The plan and its open tasks are in `design/PORT_ROADMAP.md`.

### 35. `feature/cld-sim-catchup`: catch the sim up to the ROM (planned 2026-10-18)

- [x] `PORT-35` The sim is the ROM's at TUNING_VERSION 4 (port ADR-059;
  with PORT-41's slice). The SNES repo's conformance traces come in by
  `tools/conformance_import.sh` and `test_conformance` replays all four
  scenarios frame by frame: every frame matches. On the way: the ROM's
  `opponents.json` and `quips.json` (the rebalance, serve power and duds,
  sixteen quips and the deck), the serve's depth, aim and power, the lane
  covers' stagger per match, KID's top speed, ICE and POPCORN in the sim
  and the AI, GHOST in the view, the kitchen line, and a ladder per mode
  (save v6, a quit resets it). GHOST BALL, POPCORN, ICE are on MODIFIERS.
  - Verified: `test_conformance` (4 x 5400 frames, the tuning version),
    `test_save` (a v5 image keeps both places; per-mode advance, quit and
    clear), `test_view` (pause, MAIN MENU resets a ladder only), `test_story`
    (the deck), `test_layout` (MODIFIERS and RECORDS moved). Harness:
    10, 9, 4, 3 and 10 to 3 (the ROM's rebalance). Golden traces
    regenerated (the CPUs). 314/314 plus the e2e. Screenshots: MODIFIERS,
    RECORDS.
  - Status: **Done**: the conformance traces are the proof. The upper
    rungs are easier than before (the ROM's playtest); say if they feel
    off.

### 41. `feature/cld-four-shots`: four swings and the short hold (asked for 2026-10-18)

- [x] `PORT-41` The first piece of PORT-35 (ADR-058): SNES ADR-056 and 057.
  SLICE (slow, never deep, steady), SHORT held (any swing goes short, the
  D-pad still moves), the fast drop's long spray off a stretch, and CPUs
  that slice (WALT, RAVEN, VLAD 3; ACE, JADE 4). Pad by position: SLICE
  north, SHORT LB or RB; keyboard I and Shift/U; both on CONTROLS. The
  overhead moved to shot 4 so the slice has the C's number; its own sound;
  the key legend and the SHOTS lesson teach all four.
  - Verified: `test_shots.gd` (the SNES repo's C tests, ported: the slice
    and fast drop's flights, the short hold on fake pads for both teams,
    RAVEN slicing 11 of 91 rally swings, none at 0; a high slice stays a
    slice; the bindings), `test_controls`, `test_tutorial`, `test_layout`
    (now also failing on a panel off the screen, which caught CONTROLS at
    13 rows). Golden traces: only doubles_demo, for the overhead's number
    (identical under the old one). 307/307 plus the e2e. Screenshots: the
    legend on keys and an Xbox pad, CONTROLS, the SHOTS card.
  - Status: **Ready to test**: try I / Y for the slice and hold Shift / LB
    with each swing.

### 37. `feature/cld-park`: the period-true park (planned 2026-10-18)

- [x] `PORT-37` Period-true park: courts ROOKIE / CLUB / CHAMP (the port
  shows DUPR-style `UNDER 3.5`), park points, winners stay on (two wins),
  pick your partner (SNES ADR-070 to 072).
  - Done (ADR-060): the courts renamed; park points on the career player
    (10 to start, CLUB at 15, CHAMP at 25; locked racks say what they
    need); winners stay on for two wins, you included; SLICE at your rack
    picks a partner from the teams you've beaten. The SNES tests are
    ported.
  - Status: **Ready to test**.

### 38. `feature/cld-hats`: career and the Hat Museum (planned 2026-10-18)

- [x] `PORT-38` Career and the Hat Museum: 13 hats and 16 unlocks (the port
  has 6 and 9), the museum (SNES ADR-059 to 061), new hat art.
  - Done (ADR-061): BEANIE, BUCKET, BACKCAP, WHIRLY, VIKING, CHEF and
    CROWN drawn for the HD players and earned as in the ROM; the HAT
    MUSEUM from the player's card (cases, silhouettes, hints, B wears).
    The SNES museum and career tests are ported.
  - Status: **Ready to test**.

### 39. `feature/cld-show`: the show (planned 2026-10-18)

- [x] `PORT-39` The show: rings at each player's feet, celebrations,
  slumps, emotes, net shiver, critters, more quips, and GLOW / INVERSE
  redone for full colour (SNES ADR-054, 063, 064, 066).
  - Done (ADR-062): filled circles at the feet (the user's call over the
    SNES ring); celebrations, slumps and dives (six new poses); the
    emotes; the net's shiver, drive squash and spin streaks; the gull,
    satellite and fish; the trophy; GLOW and INVERSE. The quips came with
    PORT-35. Left: the practice pickle.
  - Status: **Ready to test**.

## After the bible: the user's asks (2026-10-19 to 21)

PORT-42 to 58 (but 55, still waiting on its recordings), moved here in
the 2026-10-21 cleanup.

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

### 56. `feature/cld-near-reach`: the near-side reach (asked for 2026-10-21)

- [x] `PORT-56` KNOWN_ISSUES #69, the look only (the user's call): a ball on
  the near side of a player gets the low reach and a step down toward it;
  the ROM's hit area is unchanged.
  - Verified: `test_view` (`test_near_side_reach`). 419/419 plus the e2e,
    golden traces unchanged.
  - Status: **Ready to test**.

### 57. `feature/cld-title-record`, `feature/cld-park-locations` (asked for 2026-10-21)

- [x] `PORT-57` The title's line under the logo is just the RECORD (the
  ladder's place resets on a quit, so it isn't progress; RECORDS keeps it
  and the clears). OPEN PLAY's locations (ADR-078): THE PARK, DINO PARK,
  THE GYM, one plan in three looks; THE GYM's games at the new indoor GYM
  venue (always lit, its own ambience and music).
  - Verified: `test_park_locations`, `test_night`, `test_court`. 423/423
    plus the e2e, golden traces unchanged; the park's art and every
    venue's but the GYM's byte for byte. Screenshots of DINO PARK, THE
    GYM and a match at the GYM.
  - Status: **Ready to test**: walk both, and play a game in each.

### 58. `feature/cld-lobby-sides`, `feature/cld-player-tags` (asked for 2026-10-21)

- [x] `PORT-58` The lobby: doubles takes any split (two players together
  against two CPUs, or one each side with a CPU partner; humans only on
  the right swap ends); LB / RB go round the four modes, shown as tabs;
  the line says who plays whom ("P1 + P2 VS CPU + CPU"). The tags over
  the players: the text centred, the pointer in the player's colour
  (KNOWN_ISSUES #70).
  - Verified: `test_multiplayer`, `test_couch_cup`, `test_layout`. 423/423
    plus the e2e. Screenshots of the lobby and the tags.
  - Status: **Ready to test**.

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

### 67. `feature/cld-player-hd-body-v2`: the players' body and swing (asked for 2026-10-22)

- [x] `PORT-67` A side-by-side test first (`art/sprites/hd/v2/`: v2
  `.aseprite` copies of the 48 px players, old-vs-v2 GIFs and a still),
  then the same changes in the game's players (`art/levels/tools/players.py`):
  the shirt tapers from the shoulders to the waist (a V, not a bean), the
  hips sit higher (a shorter torso, longer legs), the shorts are narrower
  at the waist and a little longer. The forehand uses the body: the windup
  coils the shoulders and loads the back leg, contact drives onto the
  front knee with the back heel up, and the follow-through wraps the
  paddle up (tilted forward, clear of the face) with the back foot
  dragging on its toe. The head is left alone: no head code changed and
  every pose keeps its neck, so heads, caps and hats are pixel-identical
  (every cap and hat overlay sheet is byte-identical to before).
  - Verified: all 21 poses compared old vs new, male and female, and the
    head footprint diffed per frame (no changes); 440/440 plus the e2e,
    golden traces unchanged (art only). Screenshots of doubles at the park.
  - Status: **Ready to test**.

### 68. `feature/cld-meters-under-players`: the SPECIALS meters under the players (asked for 2026-10-22)

- [x] `PORT-68` ADR-080, amended: each player's SPECIALS meter is a small
  fixed-width bar under their feet (in their colour, gold when full),
  following them, flipped or not, all four in doubles, instead of a bar
  under the score panel that grew with the team name. The PICKLE SMASH
  prompt stays under the score panel. Display only.
  - Verified: `test_specials` (the bars follow the players: under the
    feet, centred, a fixed width; still display only), `test_layout` (the
    players at the runoff's corners and the net: no bar meets a text or
    leaves the screen); 441/441 plus the e2e, golden traces unchanged.
    Screenshots of singles and doubles with the meters part full, and a
    full one with the prompt.
  - Status: **Ready to test**: play a match with SPECIALS on (RULES) and
    say if the bars read at a glance and sit well under the feet.

### 69. `feature/cld-saved-replays`: saved replays (asked for 2026-10-22)

- [x] `PORT-69` ADR-081: **SAVE LAST RALLY** on the pause menu keeps the
  rally that ended last (PLAY OF THE MATCH's recording, cut after it) as
  a file under `user://replays/`, six at most. **REPLAYS** on PLAYER
  lists them, newest first; a press watches one full screen with a SAVED
  REPLAY card (or, with ON PRESS set to DELETE, deletes it). **IN THE
  DEMO** (on) lets the title's demo play them, every other time, between
  live matches. A replay from another sim lists as OLD VERSION.
  - Verified: `test_saved_replays` (exact playback from the file, the live
    match untouched, FULL, OLD VERSION, the title's REPLAYS and demo),
    `test_layout` (REPLAYS at its widest, the pause row, the card),
    `test_menus`; 447/447 plus the e2e, golden traces unchanged. A replay
    recorded in one run played back exactly in another. Screenshots of
    the pause menu, REPLAYS, and a replay playing
    (`screenshot.gd ... replays savelast` / `title_replays ... replays watch`).
  - Status: **Ready to test**: save a good rally from the pause menu, then
    watch it from PLAYER, REPLAYS, and let the title sit to see it in the
    demo.

### 70. `feature/cld-potm-save`: SAVE on PLAY OF THE MATCH (asked for 2026-10-22)

- [x] `PORT-70` ADR-081, amended: while PLAY OF THE MATCH plays, SAVE
  (soft: X or L, beside SKIP) keeps the match's best rally in REPLAYS.
  The card says SAVED (and SAVE goes) or REPLAYS FULL; never twice, and
  not on a saved replay's own card.
  - Verified: `test_saved_replays` (SAVE during PLAY OF THE MATCH, played
    back exactly from the file; once; FULL; none on a saved replay),
    `test_layout` (the card with SAVE, SAVED and REPLAYS FULL),
    `test_highlight`; 448/448 plus the e2e, golden traces unchanged.
    Screenshots of the card before and after SAVE
    (`screenshot.gd ... potm potmsave replays`).
  - Status: **Ready to test**.

### 71. `feature/cld-replay-trim`: replays trimmed to the rally (asked for 2026-10-22)

- [x] `PORT-71` ADR-081, amended: a replay (saved, or PLAY OF THE MATCH)
  opens just before the serve is struck, not at the serve's setup; any
  pause in the rally runs unseen (the sim steps while paused, so the
  pause menu used to show in the replay); and it ends 50 frames after the
  point (was 80). The recording is unchanged, so the replay is still
  exact. Replays saved before this have no serve frame and still open at
  the setup, but skip their pauses.
  - Verified: `test_saved_replays` (P1 a human who waits four seconds to
    serve and pauses ten seconds mid-rally: the replay opens 45 frames
    before the serve, never draws a paused frame, and still ends on the
    rally's exact snapshot), `test_highlight`; 449/449 plus the e2e,
    golden traces unchanged. Screenshot of a replay's opening frame.
  - Status: **Ready to test**: save a rally you paused in, and one you
    waited to serve, and watch them from REPLAYS.

### 72. `feature/cld-pad-mapping`: L for SHORT, R for SPECIAL (asked for 2026-10-22)

- [x] `PORT-72` ADR-082: on a pad, L and the left trigger are SHORT, R
  and the right trigger SPECIAL (PICKLE SMASH); SHORT was either shoulder
  and SPECIAL the right trigger. The keyboard is unchanged. A save's old
  bindings load with R on SPECIAL. Departs from the bible's "L or R"
  (For you).
  - Verified: `test_pad_maps` (the shoulders and triggers, an old save's
    bindings), `test_shots`, `test_controls`, `test_controller`; golden
    traces unchanged.
  - Status: **Ready to test**: try L and R in a rally.

### 73. `feature/cld-pad-mapping`: generic pads, mapped (asked for 2026-10-22)

- [x] `PORT-73` ADR-082: OPTIONS, CONTROLS, **CONTROLLER**: the pad in
  hand, **MAP BUTTONS** for a pad SDL doesn't know (it asks for each
  action, naming the SNES button, from the pad's raw buttons, hat or
  axes), **CLEAR MAPPING**, BUTTON ICONS (moved here, with a new SNES
  family) and PAD NOTICE. The map becomes an SDL mapping string given to
  Godot, saved per pad model (GUID) and given again whenever the pad
  connects; a mapped pad draws as a SNES pad.
  - Verified: `test_pad_maps` (a SNES USB pad's raw events mapped and
    then driving P1's actions, 2P's reading and the menus, a hat D-pad,
    undo, cancel, a resting trigger axis, the save), `test_layout` (MAP
    BUTTONS at every step, CONTROLLER with every value). Screenshots of
    MAP BUTTONS and CONTROLLER (`screenshot.gd -- title_padmap`,
    `title_pad`, `title_controls`). Not verified: a real generic pad
    (Godot's raw-joystick path can't be driven headless).
  - Status: **Ready to test**: plug in a SNES USB pad, open OPTIONS,
    CONTROLS, CONTROLLER, and see what MAP BUTTONS says. UNKNOWN: press
    it and answer each step. STANDARD: SDL knows it already; try it in a
    match, and fix any button on CONTROLS.

### 74. `feature/cld-pad-mapping`: a controller recommended (asked for 2026-10-22)

- [x] `PORT-74` ADR-082: with no pad connected, the title opens on A
  CONTROLLER IS RECOMMENDED (OK, DON'T SHOW AGAIN), once a session; a pad
  connecting closes it.
  - Verified: `test_pad_maps` (the title's flow, the card), `test_layout`
    (the card), and the e2e (it now dismisses the card); 459/459 with the
    branches together. Screenshot of the card (`screenshot.gd --
    title_notice`).
  - Status: **Ready to test**: start the game with no pad plugged in.

### 75. `feature/cld-audio-compare`: smaller audio (asked for 2026-10-22)

- [x] `PORT-75` ADR-083: first a comparison: nine clips (three SFX, the
  park ambience, two music tracks, three announcer lines) in Ogg q6/q4/q2,
  IMA-ADPCM, 22 kHz mono and MP3 beside their originals, with sizes
  against the QOA the game shipped (`audio/compare/`, `make_compare.py
  --estimate`). Then the switch: the 12 music files and 7 ambience loops
  ship as Ogg q4, encoded by `sync_assets.sh` (`tools/encode_ogg.py`,
  reproducible bytes); effects and the announcer stay WAV/QOA. The `.pck`
  goes from about 34 MB to 18.5 MB.
  - Verified: `test_music.test_loops_loop_and_stingers_dont`,
    `test_audio.test_every_venue_has_its_ambience` (each loop Ogg and
    looping); 459/459 plus the e2e, golden traces unchanged; the exported
    `.pck` boots clean. Every Ogg decodes to its WAV's exact length.
    Not verified: by ear (KNOWN_ISSUES #74: two loops' seams to listen to).
  - Status: **Ready to test**: play a match at the park and at SPACE
    past the loop's end (about 40 s) and listen at the wrap; compare the
    title music with `audio/compare/out/music_title_original.wav`.

### 76. `feature/cld-dino-park-dinosaurs`: the dinosaur game's dinosaurs at DINOSAUR (asked for 2026-10-22)

- [x] `PORT-76` ADR-084: the Carnotaurus of the SNES dinosaur game, with
  Nathan up, walks the DINOSAUR venue's stands behind the fence (his own
  `mount_walk` and `mount_idle` frames, 1x), stops to look about, turns
  back, and once a lap walks off the right edge and returns. From the same
  game: the Spinosaurus breathes in the jungle's gap, the baby dinosaur
  patrols the jungle's edge (2x), and the pterodactyl crosses the sky
  behind the volcano. The sprites are exported as drawn
  (`art/sprites/dinos/export.sh`, the dinosaur repo only read) and drawn
  by `view/dino_walkers.gd`: display only, from the frame count, each on
  a backdrop layer's parallax and tint. The raptor, T. rex and
  Brachiosaurus were tried and left out (the venue paints all three).
  OPEN PLAY's DINO PARK has them too: the Carnotaurus strolls the sand
  path among the people (sorted by his feet), the baby patrols the grass
  by the T. rex statue, the pterodactyl flies over the courts. He roars
  (his `mount_roar`) when a long rally (10+ shots) ends or a match is
  won, and in DINO PARK when you come back a winner.
  - Verified: `test_dinos.gd` (only on DINOSAUR, the sim untouched, two
    views agree, the route crosses and turns and loops without a jump,
    behind the fence; DINO PARK has its cast and the other parks none,
    OpenPlay untouched, two parks agree; the roar holds the route and
    resumes it, a long rally ends in one, a won game in DINO PARK too),
    `test_view`, `test_layout`; 469/469 plus the e2e, golden traces
    unchanged; screenshots at four frames, at NIGHT, mid-roar
    (`screenshot.gd ... roar`), and of DINO PARK.
  - Status: **Ready to test**: play a match at DINOSAUR and watch the
    fence line for a minute (his lap is about 80 s) and for a roar after
    a long rally; walk DINO PARK's path, and come back from a win there.

### 77. `feature/cld-dino-levels`: the dinosaur game's levels as courts (asked for 2026-10-22)

- [x] `PORT-77` ADR-085: four venues from the dinosaur game's level
  concepts (`../dinosaur/assets/levels`), after the GYM on COURT > VENUE.
  **RUINS** (`01-ruins.png`): a burning, drowned city under a purple and
  orange sunset, a broken bridge, mossy pillars and rusted girders, the
  crowd on a mossy wall; PURPLE court, CLAY kitchen, cracked CONCRETE.
  **GLACIER** (`ice-wilderness.png`): snowy peaks at dusk, ice spires,
  the aqueduct hung with icicles, snowy pines; BLUE and NAVY on SNOW.
  **LAB** (`science-lab.png`, indoors): green tanks with a T. rex, a
  raptor and a long-neck's skeletons, a hazard-striped catwalk, consoles,
  a raptor loose on the deck behind a yellow rail; BLACK and GREEN, YELLOW
  lines, steel plates. **STATION** (`space.png`, indoors): windows on a
  nebula, a ringed planet, asteroids and a wreck, orange-lit rails and
  consoles, an astronaut and a drone; SLATE and ORANGE on deck plates.
  Dinosaurs only at the LAB (your call after the first cut): there Nathan
  rides the Carnotaurus along the deck (ADR-084's sprites, with the roar).
  Each has its own ambience and match track; the announcer's lines for
  them are in the batch to record (until then: the format).
  - Verified: `test_dinos` (the Carnotaurus on the LAB's deck, behind the
    fence; none at the other three), `test_court` (each paints its
    presets), `test_announcer`, and every suite that runs all venues;
    470/470 plus the e2e, golden traces unchanged; the existing venues'
    art and audio byte-identical; screenshots of all four in a match
    (`art/levels/out/previews/{ruins,glacier,lab,station}.png`).
  - Status: **Ready to test**: COURT > VENUE, play a game at each and
    listen to the ambience and track; try TIME at RUINS and GLACIER (LAB
    and STATION stay lit).
