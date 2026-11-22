# ADR-119 — The Web Build on Phones: the Whole Screen, and the Pad

Status: **Accepted 2026-10-29**, merged 2026-11-22. Written as port
ADR-106 for PORT-114 on `feature/cld-web-mobile`, which never merged;
both numbers went to other work meanwhile, so it is ADR-119 and
PORT-176 now. The lead asked for it back after playing v0.46.0 on a
phone ("We had it where they were weighted differently").
Milestone: `PORT-176`. Asked for by the user: "improve the web version as
much as we can ... I don't seem to have touch controls ... I'd like for it
to take up as much room as possible, maybe it even suggests to hold the
phone in landscape". Amends: ADR-086 (the touch pad), ADR-089 (the lite
Web build).

## Context

On a phone the Web build used little of the screen. SCALE was PIXEL
(`content_scale_stretch` integer) everywhere: a phone held sideways is
about 360-430 CSS px high at a device pixel ratio of 2-3, so 540 game
pixels fit once or twice with the rest black. In an emulated 740x360
phone (DPR 2, a 1480x720 canvas) the game drew at 960x540, 42% of the
screen. The page also kept Godot's default shell: margins under the notch,
browser bars, no hint to turn the phone, and no full screen.

The touch pad (ADR-086) was there and worked in an emulated phone
(Chrome's touch emulation, synthetic touches into Godot's own listeners):
it shows on AUTO when `DisplayServer.is_touchscreen_available()` (on the
web, `"ontouchstart" in window`) says so. The lead didn't see it on their
phone; which phone, browser and build is an open question (For you).

## Decision

1. **SCALE starts on FILL in a browser** (`Settings.web`,
   `OS.has_feature("web")`), saved under its own key, `integer_scale_web`
   (default 0), so the Web build's old saves, which stored PIXEL as the
   default and never as a choice, don't keep it. The desktop key and
   default are unchanged. A new key with a harmless default: save layout
   v6 unchanged.
2. **FULLSCREEN is the page's in a browser.** The row reads the page's
   live state and asks for full screen from the row's own tap or press (a
   page may only ask just after one); `apply_window` leaves the mode
   alone there, so changing SCALE can't drop out of full screen. Where the
   browser has no full-screen API (an iPhone's Safari) the row is gone.
3. **The page's additions** live in `game/tools/web_head.html`, copied
   into the Web preset's `html/head_include` by `tools/web_head.py`
   (`test_web` checks they match): the viewport covers the notch
   (`viewport-fit=cover`), no zoom, text selection or long-press menu;
   the first tap asks for full screen and then locks landscape (Android
   Chrome); held upright on a touch screen, a card says TURN YOUR PHONE
   SIDEWAYS (a tap dismisses it); home-screen app tags for iOS.
4. **An installable app** (Godot's PWA option): display full screen,
   orientation landscape, black. On an iPhone, Add to Home Screen is the
   way to lose the browser bars. The service worker also caches the game
   for the next visit. Cross-origin isolation through the worker is off:
   the build has no threads.
5. **A touch always counts.** `GameControls.touch_seen`, set by the first
   `InputEventScreenTouch`, stands in for `is_touchscreen_available()` in
   the pad's AUTO, so a browser that says it has no touch screen still
   gets the pad once a finger lands.

6. **The face buttons weighted round HIT.** On a phone the SNES diamond's
   buttons came out about 30 pt across, too small (the lead, 2026-10-29).
   They are now laid out as a GameCube pad's: B (HIT, the shot most
   played) a big round button (80 px across), X (SLICE) and A (DRIVE)
   kidneys on an arc over and right of it, Y (SOFT) a small round button
   below left. Letters and colours stay the SNES pad's, so the prompts
   still name them. A touch anywhere in the cluster presses the button
   whose edge is nearest (within 12 px), so there are no dead gaps; a
   finger still slides from one to the next. The pills grew a little
   (104x36).
7. **L and R within a thumb's reach.** At the top corners they were out
   of reach (the lead, 2026-10-29). R (SPECIAL) is a shot, so it sits over
   the face cluster, for the right thumb. L (SHORT) is held while a shot
   is played, which on glass would take the left thumb off the D-pad: on
   the touch pad it is a toggle over the D-pad instead, a tap on (lit
   yellow), a tap off; every shot goes short while it is on, and it lets
   go when the pad hides. The pad still only sends the `short` action (a
   press, held, then a release), so the sim and the pads are unchanged.
   The tutorial's HOLD SHORT reads a little wrong on touch (TAP), left as
   it is for now. START stays top left. The cluster and the D-pad sit high enough to clear the
   screens' help line; `test_layout` now fails on screen text under any
   shown part of the pad.

## Merged with 0.44's phone work (2026-11-22)

0.44 (PORT-151..155, port ADR-107) did its own phone work, so the merge
settles where they overlap:

- **SCALE:** 0.44's SCALE AUTO fills a phone's screen already (no whole
  scale covers 85% of it), so decision 1's separate web key is dropped.
- **Upright:** 0.44 plays upright, with the pad under the picture. The
  card still asks for landscape. A tap on the card plays upright: full
  screen, without the landscape lock that the first tap elsewhere asks
  for. The weighted cluster scales up under the picture like the rest.
- **WORDS:** TOUCH BUTTONS WORDS keeps four equal round buttons in a
  diamond, since a word doesn't fit a kidney. The weighted cluster is the
  letters' layout, and the default.
- **The page:** main's touch-action, long-press and zoom guards moved into
  `tools/web_head.html`.

## Consequences

- In the emulated 740x360 phone the game fills the height (a 1280x720
  draw in a 1480x720 canvas, 87% of the screen, the rest the 16:9 bars).
- Not done: the pad's buttons in the side bars (Godot's `keep` aspect
  draws nothing outside the 16:9 view; the bars are about 75 CSS px wide
  on a 19.5:9 phone, less than a thumb's D-pad). It waits for a real phone
  (KNOWN_ISSUES #79).
- Tests: `test_web` (the scale default and its key, the FULLSCREEN row,
  a touch bringing the pad, the preset's page and app settings);
  `test_touch.test_the_faces_round_hit` (HIT the big one, no overlaps, no
  gaps); `test_layout`'s pad-over-text check.
