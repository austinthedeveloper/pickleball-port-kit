# ADR-086 — An On-Screen Pad for Touch Screens

Status: **Accepted 2026-10-23**
Milestone: `PORT-81`. Asked for by the user: "web version: I want mobile
control support if it doesn't exist and is something that godot offers".
Amends: PORT-11 and PORT-28 (prompts follow the device), ADR-082 (the
controller card at startup).

## Context

The web build (`export_presets.cfg`'s Web preset, `release.yml`'s
`-web.zip`) had no touch input: nothing in `game/` read
`InputEventScreenTouch`. On a phone the only thing that worked was a tap
on a menu row, through Godot's `emulate_mouse_from_touch` (on by default),
so a match couldn't be played.

What Godot 4.7 offers:

- `InputEventScreenTouch` and `InputEventScreenDrag`, one per finger
  (`index`), in the viewport's 960x540 coordinates after the stretch.
- `TouchScreenButton`: a Node2D that presses an input-map action, with a
  "touch screens only" visibility. It's one button per node, with no
  directional pad and no slide from one button to the next, and its
  pressed state can't be fed by tests without a real touch screen
  (headless reports none, so the button stays hidden).
- No virtual joystick or D-pad node in the engine.
- `DisplayServer.is_touchscreen_available()` (on the web: the browser
  reports touch events).
- `Input.parse_input_event(InputEventAction)`: an action pressed through
  the same queue as keys, so `_input`, the latch and
  `is_action_just_pressed` all see it.
- `emulate_mouse_from_touch`: the first finger is also a mouse, with
  `device == InputEvent.DEVICE_ID_EMULATION`.

## Decision

1. **One node, `TouchPad`** (`game/view/touch_pad.gd`, a CanvasLayer the
   input node adds as its child), rather than seven `TouchScreenButton`s
   and a hand-made D-pad. It tracks each finger, works out what it's on,
   and sends `InputEventAction` presses and releases through `Input`. So
   the pad is one more device on the existing input map: the sim, menus,
   the latch (a tap shorter than a tick) and `read_intent` are unchanged,
   and the pad never touches the sim.
2. **Drawn as a SNES pad**, like the game's own: the D-pad bottom left
   (eight ways, a dead centre, a thumb that starts on it keeps steering
   when it wanders off), B A Y X bottom right in the Super Famicom's
   colours (B hit, A drive, Y soft, X slice, by position as on a pad),
   START top left, L (SHORT, held) and R (SPECIAL) under the top corners,
   where a pad's shoulders are. A finger can slide from one face button
   to the next. Translucent (72%).
3. **Prompts follow it.** A finger makes `GameControls.TOUCH` the last
   device (as do the mouse events Godot makes of it); the prompts then
   draw the pad's buttons (`Prompts.touch_glyph`: B HIT, A DRIVE...),
   fixed, since remapping is the keys' and pads'.
4. **Shown** (TOUCH PAD on CONTROLLER, saved as `touch_pad`): AUTO, the
   default, shows it on a touch screen with no pad connected while touch
   is the last device used (a key press hides it until the next touch);
   ON always; OFF never. A touch screen with no pad starts on touch. The
   "a controller is recommended" card doesn't open when the pad shows.
5. **Menus still work by tap.** A tap off the pad is the mouse, as
   before (a tap on a value cycles it, MenuPage's `press`). On a button,
   the emulated mouse is swallowed in `_input`, before the GUI, so a tap
   on B doesn't also click the row under it.
6. **It steps aside from panels.** `test_layout`'s rule (text never
   collides) holds with the pad up: a part (the D-pad, the faces, each
   pill) with a panel under it hides and takes no touches, so the panel's
   rows get the tap. Panels join a group in `UiKit.panel` for this. In
   matches, practice, pause and the result card the corners are clear, so
   the whole pad shows; on COURT and the career card the faces step
   aside (both pages have BACK rows).

## Consequences

- Tests: `test_touch` (each button's action, the D-pad's eight ways,
  two thumbs and a slide, a tap reaching the intent, taps on buttons not
  reaching the GUI, stepping aside, the device and prompts, the setting
  saved), `test_layout.test_touch_pad` (every title page, a match served
  and paused, the bracket), and the e2e sends real touches through the
  event queue (Y on the pad backs out of MATCH SETUP, a tap on QUICK MATCH
  opens it). Save layout v6 unchanged (`touch_pad` fills from defaults).
- Not verified without a phone (known issue 79): the feel and size of
  the buttons under a thumb, multi-touch in mobile browsers,
  `is_touchscreen_available()` on each browser, and whether the browser's
  own gestures (scroll, zoom, a long-press menu) get in the way.
- A touch laptop on AUTO starts with the pad up; a key press hides it.
