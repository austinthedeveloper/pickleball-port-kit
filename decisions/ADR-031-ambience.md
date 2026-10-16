# ADR-031 — Venue Ambience

Status: **Accepted 2026-10-13**
Takes the place of title music for now (`M4-AUDIO-03`): a quiet background
loop instead of a tune.
Depends on: ADR-024 (venues), ADR-029 (sound effects).

## What plays

Each venue loops a soft crowd murmur, with calls dropped in at random:

| Venue | Calls |
|---|---|
| PARK | Birds: quick rising whistles at four pitches |
| LAKESIDE | Gulls ("kee-ow") and small waves lapping |
| SUNSET | Crickets |

`venues.json` gives each venue its `ambience`. The loop plays on the title
(the attract demo's venue) and in matches and practice.

## How

- `tools/assetgen/ambience.py` synthesizes the samples with fixed seeds.
  The murmur is 8 kHz and cross-faded to loop seamlessly; the calls are
  16 kHz. It writes one IT module per venue (`ambience_N.it`):
  - the murmur on channel 1, looping, at volume 26 of 64
  - the calls on channels 2–3, with a per-row chance, a random pitch, and
    a random volume
  - three 64-row patterns (about 7.7 s each) in a loop, so the order
    doesn't repeat obviously
- smconv builds them after the effects (`-f` checks each module plus the
  effects against sound RAM: 22–29 KiB to spare). The soundbank is now
  48.8 KiB, so it spans ROM banks 14–15 (`SOUNDBANK__0/1`, registered last
  first).
- `audio_ambience(venue)` runs from `render_load_court`, during its fade:
  - It reloads only when the venue changes: `spcStop`, `spcLoad` the
    module, the effects again (loading a module replaces them), then
    `spcPlay`.
  - It plays at module volume 150 of 255.
  - The first court load at boot does the only effects load, so boot is
    about 8 frames longer than before, not 70.
  - `spcPlay` is a queued command. It is handed over by the normal
    per-frame `audio_update`; `spcFlush` hung the boot.
- **SOUND option:** ALL plays the ambience. NO CROWD and OFF stop it (the
  murmur is crowd). Changing the option applies at once (`audio_refresh`).
- `make sfx-preview` also mixes each venue's loop into
  `build/sfx/ambience_<venue>.wav` (46 s), using the module's own rows,
  pitches, and volumes.

## Checks

- `test/test_audio.c`: the ambience follows the venue and the SOUND option.
- **MesenCE voice probe:**
  - the murmur (voice 0) starts at boot on the idle title, with bird calls
    on voice 1
  - choosing SUNSET restarts it with crickets
  - effects keep playing on voices 6–7 throughout
- Zero overruns on every timeline. The golden trace differs only before the
  first match (boot).
