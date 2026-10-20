# CLAUDE.md

Pickleball '94 port kit: the SNES game's docs, data, C reference sim, art,
and the Godot 4.7 port in `game/`. Branch per change with the
`feature/cld-` prefix; never commit to `main` (the human reviews and
merges).

## Commands

```sh
game/tools/test.sh                                   # all Godot tests, headless (must pass)
godot --path game                                    # play
godot --headless --path game -s res://tests/golden.gd  # regenerate golden traces (play changes only)
game/tools/sync_assets.sh                            # after rebuilding art/levels
.venv/bin/python art/levels/tools/build.py           # rebuild the 960x540 art (needs .venv: numpy, pillow)
godot --path game --resolution 960x540 -s res://tools/screenshot.gd -- <title|singles|doubles|demo|practice> <park|lakeside|sunset> <frames> <out.png>
godot --headless --path game -s res://tools/point_log.gd -- doubles 2   # why each point ended
game/tools/export.sh --check                         # .pck export + headless boot (refuses a dirty tree; --dev)
python3 game/tools/release_notes.py                  # game/RELEASE_NOTES.md from the roadmap sheet
game/tools/conformance_import.sh                     # the SNES repo's conformance traces (KEEP=1: full lines)
python3 game/tools/version.py set X.Y.Z              # the version, everywhere (design/VERSIONING.md)
```

Releases are versioned (semver, tags `vX.Y.Z`, `game/CHANGELOG.md`); the
steps are in `design/VERSIONING.md`. GitHub Actions runs `test.sh` on every
push and pull request (`.github/workflows/ci.yml`); pushing a `vX.Y.Z` tag
builds all four platforms and publishes them to the GitHub release
(`release.yml`). Godot's version and SHA-512s are pinned in
`.github/actions/setup-godot/action.yml`.

`design/PORT_ROADMAP.md` is the milestone sheet (an index of every PORT
task, releases, the current phase's tasks, open "For you" questions);
keep it current with each branch. Finished tasks, in full, live in
`design/PORT_HISTORY.md`. `game/README.md` has the file layout.

**The canon bible** is `../pickleball/docs/PICKLEBALL_94_BIBLE.md` (the
project lead's; the remaster is one of its artifacts and may not
contradict it). `design/BIBLE_PLAN.md` lists what it asks of the port and
the gaps (phase 5 in the roadmap). The SNES repo's decisions are cited as
"SNES ADR-n": its numbers from 052 on are not this repo's. This repo keeps
its own numbering (next: ADR-069).

## Rules of the code (game/)

- **The sim is pure and exact.** `game/sim/` uses ints only (12.4 fixed
  point), no Nodes, no time, no randomness. Mask u8/u16 state where the C
  wraps (`& 0xff`, `& 0xffff`). GDScript `/` on ints truncates like C;
  `>>` floors, like the C's arithmetic shift.
- **The sim follows the C reference.** The SNES repo's `src/` (at
  `K.TUNING_VERSION`) is the source of truth for rules and AI; keep
  functions in the same order and shape so they diff against it.
  `test_conformance` replays the ROM's conformance traces frame by frame
  (port ADR-059); remaster-only rules switch off there (`MatchConfig.overhead`).
  `reference/snes-src` is the old 0.18.1 snapshot. Behaviour changes need an ADR.
- **Presentation never writes to the sim** (`test_view_never_writes_to_the_sim`).
  Display choices (animation variants, effects, crowd) live in `game/view/`.
- **CPU schedule = shipped schedule.** `Sim.step()` runs the CPUs as
  main.c does (doubles lane covers every 4th frame); tests use `step()`,
  not ad hoc AI calls, unless porting a C test that did otherwise.
- **Typed GDScript.** `:=` can't infer from Array elements or untyped
  ternaries: annotate (`var x: int = arr[i]`). `Projection` is a built-in
  type name; the world→screen helper is `CourtView`.
- **Modals swallow their closing input** (playbook rule 9): a new match
  ignores input for `INPUT_LOCK_FRAMES`; a menu page change locks for
  `SWITCH_LOCK` and clears the latch; the intro and initials cards set
  the lock as they close.
- **Panels and labels come from `UiKit`** (`view/ui_kit.gd`), not
  hand-built NinePatchRects.
- **A MatchView disposes its sim** when freed (`Sim.dispose()` breaks the
  Sim↔AI↔practice cycles; `test_leaks.gd`). Anything else that holds a
  Sim past its screen must call it too.
- **Menus are MenuPages** (`view/menu_page.gd`): rows by id, driven by
  move/change/press (keys, pad and mouse alike). Tests select rows by id
  (`page.select("sound")`), never by counting presses (playbook §4.8).
  Pages animate; call `settle()` in a test that needs the final state.
- **Prompts, not button names in text**: help lines are `PromptBar`s of
  `[action, "LABEL"]`, so they follow the device and any remap.
- **Settings live in `Settings`** (`meta/settings.gd`), not on screens.
- **The save is versioned** (`meta/save.gd`, layout v6). A new saved key
  with a harmless default can ride on `defaults()` (missing keys fill);
  a changed meaning needs a new version, a migration, and a test that
  loads the old image.
- **Display-only features prove it**: a test that runs the view and a
  bare sim side by side and compares snapshots (see `test_feel.gd`,
  `test_replay.gd`).
- **The bitmap fonts** have caps, digits, and `!?.,:-'/%+ ` only. `test_layout` fails on any other character.
- **`scenes/boot.gd` is the first scene and the one file an update can't
  replace** (ADR-057): keep it tiny, load no game script in it before
  the pack. There are no autoloads: boot adds the Controls and Updates
  nodes. Tests load `scenes/main.tscn` directly.
- **Text never collides** (`tests/test_layout.gd`): no two visible texts
  overlap, none leaves the screen, and text in a panel stays clear of its
  frame, with every value of every row tried. A new screen or state gets
  a case there.

## Before calling it done

1. `game/tools/test.sh` passes (golden traces unchanged unless the change
   is meant to alter play, with the reason in the commit).
2. Look at a screenshot of anything visual.
3. Update `design/KNOWN_ISSUES.md` for new defects and the ADR for
   decisions.
