# ADR-089 — The Lite Web Build

Status: **Accepted 2026-10-24**
Milestone: `PORT-84` (the user: "I don't really care about the app size
other than the web version. Is there a way to thin that build only?",
then: "re-encode the music and ambience smaller for the web build only,
and add a lite flag that drops the announcer, ROAD TRIP and the painted
venues from the web build").
Builds on: ADR-057 (the pack and the updater), ADR-076 (the announcer),
ADR-083 (Ogg music), ADR-087 (ROAD TRIP), ADR-088 (the painted venues).

## Context

v0.34.0's Web download was 51 MB: a 41 MB game pack (music 11 MB,
ambience 11 MB, ROAD TRIP's art 6 MB, the announcer 6 MB, the painted
venues 5 MB) and the 40 MB engine (`index.wasm`, about 10 MB zipped).
The desktop builds' size doesn't matter; a page that loads in a browser
does.

## Decision

**The Web build is "lite"**, and only it:

- **Its preset** (`export_presets.cfg`, Web) has the custom feature
  `lite` and an `exclude_filter` that leaves out
  `assets/audio/announcer/*`, `assets/trip/*`, and each painted venue's
  layers, match track and ambience.
- **The game asks `Settings.lite`** (`OS.has_feature("lite")`):
  - The painted venues are `VENUES`' last seven (`Settings.PAINTED`), so
    the lite build has the first ones. `Settings.venue_count()` and
    `venues()` give them; COURT > VENUE goes round those; a saved index
    past them (a 0.34.0 Web save) clamps back; GLOBETROTTER is every
    venue the build has.
  - MAIN has no ROAD TRIP and OPTIONS no ANNOUNCER, VOICE VOLUME or
    COMMENTARY (`TitleScreen.LITE_HIDDEN`, dropped as a page is built).
  - `main` makes no `Announcer`, so every line goes nowhere (the
    commentary already allows for none).
  - `VENUES` itself stays whole, so the sim, the tests and the desktop
    builds are unchanged.
- **Smaller audio, Web only.** `export.sh` exports the Web preset from a
  copy of the project (`build/web-src`) whose music and ambience are
  re-encoded from the WAVs by `encode_ogg.py --web`: Vorbis q1 (q4 on
  the desktop) and the ambience in mono (crowd and weather beds lose
  little). Godot can't import audio differently per platform, so the
  copy is the way. The release workflow sets up a `.venv` with
  soundfile for it.
- **The check:** `export.sh` boots the Web pack on the desktop engine
  for 600 frames (the title and a demo) and fails on a load error;
  `test_lite.gd` ties the preset's filters to `Settings.PAINTED` and
  plays the lite title.

Result: the Web pack 41 MB to 12 MB, the Web zip 51 MB to 21 MB. The
engine is now most of it.

## Consequences

- The Web build has no voice, no ROAD TRIP and eleven venues; the
  desktop builds have everything. A Web ROAD TRIP in progress (0.33.0 to
  0.34.0) waits in the browser's save, unseen.
- Anything new that's desktop-only goes in the Web preset's
  `exclude_filter`, behind `Settings.lite`, and in `test_lite.gd`.
- Not done: a smaller engine (a custom web template without 3D and the
  unused modules, about 5 MB of the zip), and downloading the left-out
  parts on demand instead of dropping them.
