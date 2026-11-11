# ADR-107 — Phones and Handhelds

Status: **Accepted 2026-11-11** (asked for by the user: "do the Phones
and handhelds", the phase 6 milestone 2027-08). Milestone: `PORT-151` to
`PORT-155` (GitHub issues #41 to #45). Builds on ADR-086 (the touch pad),
ADR-089 (the lite Web build).

## Context

The touch pad (PORT-81) had only been tried headless; a phone held
upright showed the 16:9 picture as a strip with the pad on top of it; a
handheld PC's 1280x800 screen, under PIXEL (whole-number) scaling, got a
960x540 island in a black frame; and the Web build's first download was
about 22 MB compressed (the engine's wasm 10 MB, the game's pack 12).

## Decision

**Upright phones (PORT-152).** When the window is taller than wide,
`Settings.apply_window` keeps the picture's width
(`CONTENT_SCALE_ASPECT_KEEP_WIDTH`, fractional scaling): the 960x540
game at the top, the space below it the touch pad's. The pad
(`TouchPad.layout_for`) moves into that space and grows with it (up to
2.4x, capped so the D-pad and the diamond sit side by side): L, START
and R in a row over the D-pad and B A Y X. On its side the phone keeps
the old layout. The window's size is watched, so turning the phone
chooses again.

**TOUCH BUTTONS (PORT-151)**, on CONTROLS next to TOUCH PAD: SNES (the
pad's letters, as before) or WORDS: HIT, DRIVE, SOFT, SLICE, SHORT,
SPECIAL, START on bigger buttons, and the touch prompts say the same
words. A saved key with a harmless default (`touch_words`).

**The Web page (PORT-151)** gets a head include: no pinch or double-tap
zoom, no long-press menu or text selection, no pull-to-refresh, no tap
highlight (`touch-action`, `overscroll-behavior`, `contextmenu` and
`gesturestart` prevented).

**SCALE AUTO (PORT-153)**, the new default: whole-number scaling when the
biggest whole scale covers 85% of the window each way (1920x1080, 4K,
1920x1200), else FILL (1280x800, 1366x768, 2560x1440, and any upright
window). PIXEL and FILL stay as choices. A save before this keeps an
explicit FILL; its PIXEL (the old default) becomes AUTO.

**Leaving the app pauses (PORT-153).** Focus lost or the app suspended
(`NOTIFICATION_APPLICATION_FOCUS_OUT`, `_PAUSED`: a handheld put to sleep,
a phone's home button, another window) opens the pause menu, as a pad
dropping out does. Never online (there's no pause there) or in the demo.
Handheld PCs' pads (Steam Deck, ROG Ally, Legion Go) draw Xbox letters,
which their buttons are.

**The Web build's sound pack (PORT-154).** The Web pack leaves out the
music and ambience (`exclude_filter`); `tools/sound_pack.gd` packs them,
as imported, into `sound.pck` beside `index.html` (export.sh, from the
Web project's own imports, minus what the Web build leaves out anyway).
`SoundPack` (`meta/sound_pack.gd`) fetches it once the game is running,
writes it to `user://` and loads it over the game's pack; the loop
wanted then starts (`Music.retry`). Until then the menus are quiet but
for their effects; a match started before it arrives has no ambience.

Measured (this export, gzip -9 as a server would send it):

| | Before | After |
|---|---|---|
| Game pack | 13.1 MB (12.0 MB gz) | 4.5 MB |
| Engine (wasm + js) | 10.1 MB gz | 10.1 MB gz |
| First download | about 22 MB | **13 MB** |
| Sound pack, after the title | | 8.6 MB |

`export.sh` fails the Web build if the first download passes
`WEB_BUDGET_MB` (16 MB); the release workflow runs it, so a release over
budget fails. The engine is most of what's left: a smaller one needs a
custom export template (Godot built without what the game doesn't use).

Checked in the built-in browser on the real Web export: the pack loads
("sound pack: loaded"), an upright 375x812 phone shows the pad under the
picture and a touch on B opens PLAY, and 844x390 keeps the landscape pad.

## Consequences

- Still not tried on a real phone (KNOWN_ISSUES #79): iOS Safari and
  Android Chrome, several fingers at once, the thumbs' reach. The
  browser pane emulates touch, not a phone.
- "Under 5 seconds" holds on about 25 Mbps (13 MB); slower lines wait
  longer, mostly for the engine (KNOWN_ISSUES #97).
- Tests: `test_handhelds.gd` (SCALE AUTO by screen, old saves, upright
  layouts at four phone sizes with SNES and WORDS, the pads, leaving
  pauses, the sound pack's files and the Web preset), `test_menus` (SCALE
  round), `test_touch` (unchanged layouts).
