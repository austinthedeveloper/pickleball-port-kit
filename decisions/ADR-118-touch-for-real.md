# ADR-118 — Touch, Tested with Real Fingers

Status: **Accepted 2026-11-22** (the user, on a phone with v0.46.0: "still
can't do anything on player select other than press start", "the room
typing is terrible. I can't figure out how to even enter a letter I
selected").
Milestone: `PORT-175`.
Builds on: ADR-117 (menus for a finger), ADR-086 (the touch pad),
PORT-116 (the room's letter grid).

## Context

ADR-117's Player Select taps passed their tests and did nothing on a
phone. The screen is a `Control` whose size was never set: 0×0, so the
GUI never gave it a tap. The tests called its `_gui_input` directly and
never noticed.

The room's letter grid is a menu whose rows each hold five letters in the
small font. A tap had to pick the row, then the letter by how near it
fell, then lift on the same row. The letters are about 10 px apart on a
phone, and nothing showed which one a finger was on.

## Decision

**Player Select takes the whole screen** (`size = 960×540`). On touch,
its prompts are PLAY and BACK, and the screen reads their taps itself
(`PromptBar.own_taps`). BACK leaves from any row, where the pad's Y steps
up one row.

**A keypad for the room on a touch screen.** With touch the last device
used, ROOM (or a short JOIN) opens big keys instead of the grid:
- the 20 letters, five to a row, in the big font on 100×62 keys;
- DELETE and BACK down the right, with JOIN two keys tall and dim until
  four letters are in.

A key lights while a finger is on it and types when the finger lifts
there; sliding off types nothing, as on a menu row (ADR-117). Keys and
pads keep the grid, and a pad press switches back to it (`grid_open` is
the state, and `_sync_grid` shows the one for the device).

**Fingers are tested end to end.** `tests/e2e_touch.gd` boots the real
main scene and sends only `InputEventScreenTouch` through the event queue
(Godot makes the first finger a mouse, as a phone's browser does). It
covers:
- a shirt and a paddle on Player Select, then BACK;
- ROOM, four letters, DELETE, a slide-off, then BACK.

`test.sh` runs it after the input e2e. Without the size fix it fails on
all three Player Select taps.

## Consequences

- A screen built as a `Control` needs a size to take taps. The e2e is
  where that shows.
- The weighted face buttons and the "turn to landscape" card the user
  remembered are from PORT-114 (`feature/cld-web-mobile`, three commits
  after v0.43.0), which never merged; 0.44's phone work (PORT-151..155)
  went upright instead. Bringing them back is a "For you" decision.
