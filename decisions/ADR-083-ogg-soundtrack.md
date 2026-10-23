# ADR-083 — The Soundtrack and Ambience Ship as Ogg

Status: **Accepted 2026-10-22**
Milestone: `PORT-75` (the user asked for smaller audio files to compare,
"this is for building", then, after the comparison: "ok let's do your
plan").
Builds on: ADR-052 (the soundtrack), PORT-18 (the HD sounds and ambience).

## Context

Audio was about 30 MB of the 34 MB `.pck`. Every clip shipped as a WAV
that Godot imports as QOA (`compress/mode=2`, about a fifth of 16-bit
PCM). The 12 music files and 7 ambience loops (48 kHz stereo) were 24 MB
of that. The 328 effects and announcer lines were 6 MB.
`audio/compare/README.md` measured the options on nine clips and on every
shipped clip.

## Decision

- **Music and ambience ship as Ogg Vorbis, q4** (oggenc's scale).
  `game/tools/sync_assets.sh` encodes them with `game/tools/encode_ogg.py`
  (soundfile in `.venv`) into `game/assets/audio/*.ogg` and drops their
  WAVs. The kit keeps the WAVs as the masters (`audio/music/out`,
  `audio/hd-sfx/out`).
- **Effects and the announcer stay WAV/QOA.** Ogg would save about 1 MB
  on them. The shortest clips come out larger than QOA (Ogg's headers), a
  hit plays several times a second, and QOA is the cheaper decode.
- **Loops loop in code**, as they did: `Music.play_loop` and `Sfx.setup`
  set `AudioStreamOggVorbis.loop` (was `AudioStreamWAV.LOOP_FORWARD` with
  `loop_end` at the end). The `.ogg.import` files keep `loop=false`, so a
  stinger (`music_won`, `music_lost`, `music_cleared`) plays once.
- **Reproducible files.** libsndfile gives each Ogg stream a random serial,
  so `encode_ogg.py` sets one from the file's name and rewrites the pages'
  CRCs: a rebuild of an unchanged WAV gives the same bytes, and the sync
  skips files whose WAV is unchanged (same mtime).

## Consequences

- The `.pck` goes from about 34 MB to 18.5 MB (measured: the Linux pack
  export). The platform exports shrink by the same 15 MB or so.
- Every decoded Ogg has its WAV's exact frame count, so the loops keep their
  length and the circular mixes (`audio/music/README.md`) still meet. At
  the wrap, though, the jump from the last sample to the first is a little
  larger than in the WAV. It stays within each clip's normal
  sample-to-sample range, except `music_match_park` and `ambience_space`,
  which go just over it (KNOWN_ISSUES #74).
- `sync_assets.sh` now needs `.venv` with soundfile, as the art build
  already needs numpy and pillow. CI doesn't sync, so it is unaffected.
- Tests: `test_music.test_loops_loop_and_stingers_dont`, and
  `test_audio.test_every_venue_has_its_ambience` checks each loop is Ogg
  and loops.
