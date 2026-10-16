# ADR-030 — Pause Menu

Status: **Accepted 2026-10-13**
Depends on: ADR-028 (practice), ADR-029 (menu sounds).

## Menu

**Start** pauses a match or a practice session. Start used to leave practice
at once; it now pauses there too. The pause shows a box over the court:

| Choice | Does |
|---|---|
| **RESUME** | Back to the game (so do Start and Y) |
| **RESTART** | A fresh match with the same players and opponent, or a fresh practice session |
| **MAIN MENU** | Back to the title. Practice saves a new best streak first. |

- Up/Down choose (wrapping) and B or A confirms, with the menu sounds.
- The menu opens on RESUME.
- The frame a choice is made keeps its buttons from the game: the B that
  picks RESUME must not also swing.
- `src/pause_menu.c` is pure (host-tested). `main.c` acts on its result.
  Pausing itself is still `GameState.paused`, toggled by Start in
  `game_update`.
- **HUD:** the pause key is `0x80 | choice` (`HUD_IS_PAUSED`). It is checked
  before the practice key, so practice can pause. Moving the cursor redraws
  only the items. The box sits in rows 9–13, inside the area the next
  scene's clear wipes.
- The practice banner reads `START  PAUSE`.

## Tests

- `test/test_pause_menu.c`:
  - choices wrap
  - B/A act and Y resumes
  - Start pauses and unpauses, and the game stands still while paused
  - practice pauses instead of leaving
- `test/smoke/pause.timeline`: pause a ladder match, move to MAIN MENU,
  and B returns to the title. `practice.timeline` now leaves through the
  menu.
- Zero overruns on every timeline.
