# ADR-117 — Menus for a Finger

Status: **Accepted 2026-11-22** (asked for by the user after playing the
Web build on a phone: "can't enter room code on multiplayer", "visible
controls turn off at certain times and it's not clear you can click on
menu items after that ... I think the only way to confirm is to press
start at the top left", "menus are just a bit too thin for confident
clicking").
Milestone: `PORT-174`.
Builds on: ADR-086 (the touch pad), PORT-151..154 (phones), ADR-110
(the room's letter grid).

## Context

The test was on v0.43 (before the letter grid), but all three held on
v0.45:

- **Room codes.** The grid was the only way to enter a code by touch,
  but JOIN with a short code, or the grid's own JOIN before four letters,
  left ROOM in key-typing mode with the grid shut. A phone has no
  keyboard (the game has no text field, so none opens), and a second tap
  on ROOM turned typing *off*.
- **The pad steps aside.** A part of the touch pad with a panel under it
  hides (ADR-086), so on most landscape menus only START, L and R stay.
  Menus still took taps, but nothing said so, and BACK (A or Y) had gone.
  Player Select took no taps at all: START was the only way through.
- **Thin rows.** A row is 28 px of the 960×540 picture, about 18 px on a
  landscape phone, and a tap pressed the row the moment the finger
  landed.

## Decision

**A finger acts on lifting.** A tap (Godot's emulated mouse,
`DEVICE_ID_EMULATION`) shows the row it lands on and presses it when the
finger lifts there. A finger that slides off and lets go presses nothing.
On a value row, a tap on the left arrow steps back and anywhere else
steps on. A real mouse is unchanged: it clicks on press.

**Taller rows where there's room.** On a touch screen
(`MenuPage.touch_rows`: TOUCH PAD ON, or not OFF on a touchscreen, set
by main at start), a page spreads its rows into its panel's spare room,
and down to the `floor_y` its screen allows, up to 36 px
(`TOUCH_ROW_H`). A screen that hasn't said otherwise keeps its panel's
size, so nothing moves into another screen's text.
- The title's pages may reach y 530, because on a touch screen the key
  legend under them is hidden (the pad's own buttons say it). ACHIEVEMENTS
  keeps 28 px: its description line sits under its panel.
- The result is MAIN 36, PLAY 34, MATCH SETUP 35, PLAYER and COURT 36.
  The long pages (OPTIONS, CONTROLS, MODIFIERS, RECORDS) have no room and
  stay at 28.
- The room grid may reach the info panel (y 386), so its rows are 36.
- `test_layout.test_touch_rows` runs twenty screens' cases again with
  touch rows on.

**Prompts are buttons.** A MenuPage's prompts (and Player Select's) are
`PromptBar.tappable`. On a touch screen they're framed in gold, and the
touch pad presses a tapped prompt's action as it does its own buttons
(BACK presses Y). So SELECT and BACK work even when the pad's B and A
have stepped aside. The bar on the title, which only names the
controls, doesn't take taps.

**Player Select by tap.** A thumbnail picks its shirt. The player picks
the other body. A paddle picks that paddle; elsewhere on the paddle
panel, its left half steps back and its right half steps on. Each tap
becomes the pad presses it stands for (`SelectScreen.presses_for`), so
the PlayerSelect rules (a colour 1P took, 2P's turn) hold. On a touch
screen the bar reads NEXT, PLAY and BACK, all tappable.

**The room never waits for keys.** JOIN with a short room opens the
grid. The grid's JOIN waits for four letters. ROOM always opens the grid
when it's shut. The hint on a touch screen is "TAP EACH LETTER, THEN
JOIN."

## Consequences

- Taps act a moment later (on lifting), which is how phone buttons
  behave. The pad's own buttons still press on touch, as a game pad's do.
- ONLINE's own page keeps 28 px rows (its info panel sits under it). It
  is the busiest flow a phone player uses with thin rows (KNOWN_ISSUES
  #102).
- Changing TOUCH PAD takes effect for row heights when the title is next
  built; prompts and taps follow the device at once.
- Not verified on a phone yet: the tests drive the emulated mouse and the
  pad's touch path, and the browser pane can't make real touches.
