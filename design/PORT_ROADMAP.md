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

- [ ] `PORT-00` Merge the practice-mode and opponent-looks branches into
  the chain's base. Each goes in only if its own tests pass. Conflicts
  get resolved, and both features are re-run together.
  - Accept: one branch with both features, with `test.sh` green.
  - Verified: —
  - Status: **Blocked on your OK** (merging is your call). Without it,
    the chain starts from `feature/cld-godot-port` and those branches
    stay apart.

### 1. `feature/cld-feel`: game feel (product brief "punchy")

- [ ] `PORT-01` Contact punch: a short screen shake on drives and
  put-aways, a ball trail on fast shots, squash on the bounce, a swing
  whoosh frame on the paddle, and dust when a player plants.
  - Accept: everything is display-only and the golden traces don't move.
    Each effect has a switch in the code, so one can be dropped if it's
    too much.
  - Verified: —
  - Status: Planned. It will be **Ready to test**: feel needs your hands.

### 2. `feature/cld-audio`: sound (ADR-029, ADR-031)

- [ ] `PORT-02` Hits pitched by shot type. Hits, bounces and the net
  panned by court x. A crowd that swells with the rally's length and
  hushes on match point. Applause sized to the point. Ambience fades at
  scene changes. A SOUND setting (ALL / NO CROWD / OFF), saved.
  - Accept: an event-to-sound test like `test_audio.c` (shot to pitch,
    x to pan, rally to crowd level, OFF means silent). Nothing plays
    during the title demo except ambience.
  - Verified: —
  - Status: Planned. It will be **Ready to test** (the mix levels).

### 3. `feature/cld-menus`: the menu tree (ADR-025, ADR-030, playbook §7)

- [ ] `PORT-03` A main menu with pages (PLAY, OPTIONS, MODIFIERS,
  RECORDS) built on one reusable settings-row component, replacing
  today's one long title list. A pause menu (RESUME / RESTART / MAIN
  MENU). Every modal swallows its closing input (rule 9). Window options
  (fullscreen, integer scale).
  - Accept: menu tests that jump to a page by name, not by counting
    presses (playbook §4.8). The end-to-end smoke is extended through
    pause, then RESTART, then MAIN MENU. Settings survive a restart.
  - Verified: —
  - Status: Planned. It will be **Ready to test** (navigation feel).

### 4. `feature/cld-player-select`: Player Select (ADR-020)

- [ ] `PORT-04` Choose a shirt colour, male or female, and a paddle,
  with POWER, CONTROL and SPEED bars, following the select concept art.
  Colours stay unique per match (ADR-010). 2P picks on its own pad.
  CPUs take the remaining colours.
  - Accept: config tests (uniqueness, the paddle reaches the sim, CPU
    defaults). A screenshot matches the concept's layout. The paddle
    actually changes play (a stats-harness check: the red paddle's shots
    fly sooner).
  - Verified: —
  - Status: Planned. It will be **Ready to test**.

### 5. `feature/cld-court-colors`: court colours (ADR-022, ADR-027)

- [ ] `PORT-05` A COURT page: VENUE plus SURFACE, KITCHEN (with SAME),
  SURROUND and LINES presets from `court_colors.json`, previewed live
  behind the page. Recolouring uses the court mask's roles in a shader.
  - Accept: a contrast test: lines against the surface, and the ball
    against every surface, at `min_line_contrast` and
    `min_ball_contrast` (playbook §4.7). DEFAULT matches the painted
    ground pixel for pixel.
  - Verified: —
  - Status: Planned. It should be **Done**, since the tests cover it.

### 6. `feature/cld-night`: night courts (ADR-045)

- [ ] `PORT-06` TIME = DAY, DUSK or NIGHT. The backdrop darkens by the
  ADR's factors and the court stays lit under floodlights. The crowd
  dims and night ambience plays.
  - Accept: the contrast test extended to every time of day. A shadow
    stays visible on the darkest court (KNOWN_ISSUES #26's lesson).
    Screenshots of all three times at all three venues.
  - Verified: —
  - Status: Planned. It will be **Ready to test** (the look).

### 7. `feature/cld-watcher-replay`: the watcher (ADR-042) and close calls (ADR-041)

- [ ] `PORT-07` In singles, the opponent's partner sits out at the
  venue's watcher spot and cheers their side. A close out-call after a
  long rally freezes and shows a close-up of the bounce with a caption
  ("OUT BY A HAIR!").
  - Accept: a port of `test_replay.c`. The replay shows only for long
    rallies that land just out: never for short rallies, other faults or
    wide misses. Display-only, so the golden traces don't move.
  - Verified: —
  - Status: Planned. It will be **Ready to test**.

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

## If time runs short or long

- **Short:** 7 and 8 can swap with 9, so the release prep never gets
  squeezed out.
- **Long:** open play (ADR-034) is the next candidate. The playbook
  rates it an expensive wildcard, so it would get its own branch and
  ADR.
- **Out of scope for this run:** career (ADR-047), with a reason
  recorded in `design/IDEAS.md`.
