# ADR-090 — OPTIONS in the Pause Menu

Status: **Accepted 2026-10-24**
Milestone: `PORT-85` (the user: "Add Options when pausing a game. Options
like sound are only available on the main menu for some reason", then: "I
really just want the same options menu that's on the home screen,
assuming there's no game modifier hidden in there").
Builds on: ADR-074 (TUNE over the pause menu), ADR-076 (the announcer's
rows), ADR-082 (CONTROLLER, MAP BUTTONS).

## Context

SOUND, MUSIC, the announcer, CAMERA, the keys and the pads could only be
set from the title's OPTIONS. Changing one meant leaving the match.

## Decision

- **One set of pages.** OPTIONS, ACCESSIBILITY, CONTROLS and CONTROLLER
  (with MAP BUTTONS and rebinding) moved from `title_pages.gd` to
  `view/options_pages.gd`, built on a host screen. The title is one
  host and `view/options_panel.gd` (`OptionsPanel`) is the other.
- **Pause > OPTIONS**, between TUNE and MAIN MENU, in every match that
  has a pause menu, practice included. The panel opens over the paused
  match the way TUNE does, the HUD hidden, and the match waits.
- **Nothing on them is a rule.** CAMERA, HUD TEXT, SCREEN SHAKE and
  FLASHES are display settings, and SERVE ASSIST is an input aid
  (PORT-12). The modifiers stay on TUNE. Closing saves the settings and
  applies the two a match reads at its start: CAMERA (`camera.percent`)
  and HUD TEXT (`Hud.apply_text_size`). The rest already apply live.
- **The lite Web build** (ADR-089) leaves out the announcer's rows here
  too.

## Consequences

- A new OPTIONS row goes in `OptionsPages` and shows in both places.
  `test_menus.test_pause_options` checks that the pause's pages have the
  title's rows, and `test_layout.test_pause_options` tries every value.
- UPDATES is there too: pressing it when an update is ready restarts the
  game, as it does from the title.
