# ADR-082 — Pads: L Short, R Special; Generic Pads Mapped; a Controller Recommended

Status: **Accepted 2026-10-22**
Milestones: `PORT-72` (the shoulders), `PORT-73` (generic pads),
`PORT-74` (the controller card). Asked for by the user, who plays with
modern pads and has SNES-style USB pads they want to use.
Amends: ADR-080 (SPECIAL's input), PORT-12 (remapping), PORT-15 and
PORT-28 (controllers and their prompts).

## Decision

### 1. L is SHORT, R is SPECIAL; the triggers mirror them

- On a pad, the left shoulder (LB, L1, L) and the left trigger are
  **SHORT**; the right shoulder (RB, R1, R) and the right trigger are
  **SPECIAL** (PICKLE SMASH). Before, SHORT was either shoulder and
  SPECIAL the right trigger only (ADR-080).
- The keyboard is unchanged: SHORT is Shift or U, SPECIAL is O.
- A trigger stays on its action whatever button the action is rebound to
  on CONTROLS (`Bindings.TRIGGERS`). 2P's and multiplayer's pads, read
  directly (`GameControls.read_pad_intent`), follow the same layout.
- **Old saves:** saved bindings had SPECIAL's button as -1 ("none"; the
  trigger was implied). No action can be left without a button now, so a
  loaded -1 means "the default" and SPECIAL gets R. SHORT's saved L keeps
  its meaning (the left shoulder; the right one now belongs to SPECIAL).
  This is a load rule inside the v6 layout, with `test_pad_maps`
  loading an old image (`test_old_bindings_load`), not a new version.

**Departs from the canon bible.** The bible's control line says "hold L or
R to hit short" (SNES ADR-056), and ADR-080 kept both shoulders on SHORT
for that reason. The user asked for this change (2026-10-22). The SNES ROM
keeps L or R; the remaster's pad layout now differs from it. Whether the
bible should change to match is a "For you" question in
`design/PORT_ROADMAP.md`.

### 2. A pad SDL doesn't know is mapped once, by asking

**What happened before.** Godot 4.7 reads pads through SDL3. A pad in
SDL's mapping database (Xbox, PlayStation, Switch, many others) arrives as
a standard gamepad: its south button is `JOY_BUTTON_A`, and so on. A pad
SDL doesn't know (a cheap SNES USB clone, often named "USB Gamepad")
arrives raw: its own button numbers taken as Godot's button constants,
its axes as axes 0, 1..., and a hat as the four D-pad buttons. So on a
typical DragonRise SNES pad (X 0, A 1, B 2, Y 3, L 4, R 5, SELECT 8,
START 9, the D-pad on axes 0 and 1) the D-pad moved (axes 0 and 1 are the
left stick's), X was HIT, A DRIVE, B SOFT, Y SLICE, L and R and SELECT did
nothing (BACK, GUIDE, RIGHT STICK), and START was LB, so SHORT: no pause.
The prompts showed Xbox letters.

**Now:**

- OPTIONS, CONTROLS, **CONTROLLER** (a new page; BUTTON ICONS moved
  there to keep CONTROLS at 14 rows) shows the pad in hand and **MAP
  BUTTONS**: STANDARD for a pad SDL knows, UNKNOWN for one it doesn't,
  MAPPED for one mapped here, NO PAD. A press on an UNKNOWN or MAPPED pad
  opens the mapping screen; on a STANDARD pad it does nothing (its buttons
  are remapped per action on CONTROLS, as before).
- The screen asks for each action in turn, UP, DOWN, LEFT, RIGHT, HIT,
  DRIVE, SOFT, SLICE, SHORT, SPECIAL, START, naming the SNES button for
  each (HIT: SNES B, DRIVE: SNES A, SOFT: SNES Y, SLICE: SNES X, SHORT: L,
  SPECIAL: R). Any raw input answers: a button, a hat direction, or half
  an axis pushed past 0.6 (an axis resting far from 0, an analog trigger,
  is never taken). An input can't answer two steps. Backspace steps back,
  Esc cancels (the keyboard, since the pad's buttons mean nothing yet).
  The last answer is stored once it's let go of, so nothing is held down
  across the change.
- Each answer becomes the standard button that action has by default (HIT
  the south button, SHORT the left shoulder...), and the whole becomes an
  **SDL-format mapping string** (`GUID,NAME,a:b2,b:b1,dpup:-a1,...`)
  given to `Input.add_joy_mapping`. Godot then treats the pad as a
  standard one: the input map, P1's rebinds, 2P's direct reading, the
  menus and the prompts need nothing of their own. If the D-pad wasn't on
  axes 0 and 1, those stay the left stick.
- **Why this route** (over translating events ourselves): Godot's SDL
  driver (4.7's `drivers/sdl/joypad_sdl.cpp`: `mapping_handled =
  SDL_IsGamepad(...)`) marks only SDL's own gamepads as "mapping
  handled"; a raw
  joystick goes through Godot's mapping table (`Input.add_joy_mapping`,
  `is_joy_known`), so a mapping there works as a database entry would.
  Translating raw events in a script would leave the raw events in the
  input map too (button 9 would still be LB), and every reader of pads
  would need to know.
- **Saved per pad model**, by `Input.get_joy_guid` (SDL's GUID: vendor,
  product, version, so two of the same pad share one map), in the save's
  `settings.pad_maps` (`{guid: {name, map}}`), a new key with a harmless
  default (`{}`), so no layout change. Given to Input at load and again
  whenever a pad connects. **CLEAR MAPPING** forgets it.
- **Prompts:** a mapped pad, or an unknown one, draws as a **SNES** pad
  (a new BUTTON ICONS family): B A Y X by position in the Super Famicom's
  colours, L, R, START, SELECT; a trigger shows its shoulder's letter. A
  pad whose name says SNES or Super Famicom is SNES too.

**Limits.** Only one hat (hat 0) is read. A raw button numbered 11 to 14
can't be told from the hat on an unmapped pad (Godot reports both as the
D-pad buttons) and is taken as the hat; SNES pads have 12 buttons at most,
numbered from 0, so button 11 is the only one at risk. A pad SDL knows but
maps oddly isn't offered the screen; its buttons are fixed per action on
CONTROLS. Godot's raw-joystick path can't be driven headless (there's no
scripted way to connect a fake joypad), so the tests check the capture,
the string, the save, and what the map turns raw events into
(`PadMaps.translate`, the same rules), not Godot's own use of it.

### 3. "A controller is recommended"

- At startup, if no pad is connected and **PAD NOTICE** is on (CONTROLLER;
  saved as `settings.pad_notice`, default on), the title opens on a card:
  A CONTROLLER IS RECOMMENDED, with **OK** and **DON'T SHOW AGAIN**. Once a
  session. A pad connecting closes it. OK, DON'T SHOW AGAIN or back leave
  it for MAIN, swallowing the press (rule 9). It's a MenuPage (with body
  lines, `MenuPage.set_body`), so the mouse works too: the people who see
  it are the ones without a pad.
