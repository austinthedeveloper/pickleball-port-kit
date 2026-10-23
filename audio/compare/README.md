# Audio size comparison

Smaller-file versions of nine of the game's sounds, to listen to beside
the originals before choosing a build-time audio format. Nothing here
changes what the game ships.

```sh
.venv/bin/pip install soundfile                                # once: libsndfile with Vorbis + LAME
.venv/bin/python audio/compare/make_compare.py                 # out/ and the tables below
.venv/bin/python audio/compare/make_compare.py --estimate      # also encode every shipped clip (~40 s)
```

The script reads `audio/hd-sfx/out`, `audio/music/out` and
`audio/announcer/out` and never writes to them. It rebuilds `out/` and
the tables between the markers below. ffmpeg isn't installed on the
build machine and isn't needed: `soundfile` wheels bundle libvorbis and
LAME. `<name>_original.wav` is a byte-for-byte copy of the source, so git
stores it once.

## What the game ships today

| Source | Clips | Format | WAV on disk |
|---|---:|---|---:|
| `hd-sfx/out` (SFX) | 30 | 48 kHz 16-bit, mono (stereo: applause) | 1.6 MB |
| `hd-sfx/out` (ambience loops) | 7 | 48 kHz 16-bit stereo, 40 s each | 51.3 MB |
| `music/out` | 12 | 48 kHz 16-bit stereo | 67.8 MB |
| `announcer/out` | 298 | 24 kHz 16-bit mono | 27.7 MB |

`sync_assets.sh` copies the WAVs into `game/assets/audio/`, and every
`.wav.import` has `compress/mode=2`, Godot's **QOA** (about 3.2 bits per
sample, roughly a fifth of 16-bit PCM). So the `.pck` doesn't carry 149 MB
of PCM: it carries about **30 MB of QOA**, which is almost all of the
34 MB `.pck`. The useful comparison is Ogg against QOA, not Ogg against
WAV. The QOA size is in every table as "what ships now". It isn't a file
you can play outside Godot.

## Files to listen to

Each group is in `out/`: play `<name>_original.wav`, then its variants.

- **SFX**: `hit` (a single paddle hit, 0.3 s), `bounce`, `applause` (stereo
  crowd, 3.4 s). Variants: Ogg q6/q4/q2, IMA-ADPCM WAV, 22.05 kHz mono
  16-bit WAV, MP3.
- **Loops**: `ambience_park` (a 40 s ambience bed), `music_title`,
  `music_match_park`. Variants: Ogg q6/q4/q2, MP3.
- **Announcer**: `ann_ace_1` (short), `ann_smash_winner_2`, `ann_quip_11`
  (the longest line). Variants: Ogg q4/q2, IMA-ADPCM WAV, MP3.

Things to listen for: pre-echo (a smear just before the attack) on `hit`
at q2; swirl or "underwater" hiss in `applause` and `ambience_park`
(noise-like sounds are what Vorbis handles worst at low rates); sibilance
on the announcer at q2 (24 kHz input, so Vorbis has fewer bits to start
with).

Every Ogg and MP3 decodes to exactly the source's frame count (libsndfile
writes the end trim). The IMA-ADPCM WAVs come out up to about 2,000
samples longer: libsndfile pads the last block with silence. Godot's
own IMA-ADPCM import (compress/mode=1) doesn't pad.

<!-- make_compare.py: begin -->

Sizes are on disk; % is of the original WAV. "What ships now" is
the clip's Godot import (QOA, compress/mode=2), read from
`game/.godot/imported/`: what it takes in the `.pck` today.

### hit (`audio/hd-sfx/out/0_hit.wav`, sfx)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/hit_original.wav` | original: 48000 Hz, mono, Signed 16 bit PCM | 28.0 KB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 6.1 KB | 21.6% |
| `out/hit_ogg_q6.ogg` | Ogg Vorbis q6 | 7.2 KB | 25.6% |
| `out/hit_ogg_q4.ogg` | Ogg Vorbis q4 | 6.2 KB | 22.1% |
| `out/hit_ogg_q2.ogg` | Ogg Vorbis q2 | 5.4 KB | 19.4% |
| `out/hit_ima_adpcm.wav` | IMA-ADPCM WAV (4-bit), as Godot's RAM mode | 8.1 KB | 28.7% |
| `out/hit_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 3.1 KB | 11.1% |
| `out/hit_22k_mono.wav` | 22050 Hz mono 16-bit WAV | 12.9 KB | 46.0% |

### bounce (`audio/hd-sfx/out/1_bounce.wav`, sfx)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/bounce_original.wav` | original: 48000 Hz, mono, Signed 16 bit PCM | 32.7 KB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 7.0 KB | 21.4% |
| `out/bounce_ogg_q6.ogg` | Ogg Vorbis q6 | 7.4 KB | 22.5% |
| `out/bounce_ogg_q4.ogg` | Ogg Vorbis q4 | 6.3 KB | 19.3% |
| `out/bounce_ogg_q2.ogg` | Ogg Vorbis q2 | 5.6 KB | 17.0% |
| `out/bounce_ima_adpcm.wav` | IMA-ADPCM WAV (4-bit), as Godot's RAM mode | 10.1 KB | 30.7% |
| `out/bounce_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 3.0 KB | 9.2% |
| `out/bounce_22k_mono.wav` | 22050 Hz mono 16-bit WAV | 15.1 KB | 46.0% |

### applause (`audio/hd-sfx/out/4_applause.wav`, sfx)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/applause_original.wav` | original: 48000 Hz, stereo, Signed 16 bit PCM | 645.7 KB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 130.8 KB | 20.3% |
| `out/applause_ogg_q6.ogg` | Ogg Vorbis q6 | 116.3 KB | 18.0% |
| `out/applause_ogg_q4.ogg` | Ogg Vorbis q4 | 66.7 KB | 10.3% |
| `out/applause_ogg_q2.ogg` | Ogg Vorbis q2 | 56.3 KB | 8.7% |
| `out/applause_ima_adpcm.wav` | IMA-ADPCM WAV (4-bit), as Godot's RAM mode | 162.1 KB | 25.1% |
| `out/applause_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 77.8 KB | 12.0% |
| `out/applause_22k_mono.wav` | 22050 Hz mono 16-bit WAV | 148.3 KB | 23.0% |

### ambience_park (`audio/hd-sfx/out/ambience_park.wav`, loop)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/ambience_park_original.wav` | original: 48000 Hz, stereo, Signed 16 bit PCM | 7.32 MB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 1.48 MB | 20.2% |
| `out/ambience_park_ogg_q6.ogg` | Ogg Vorbis q6 | 874.1 KB | 11.7% |
| `out/ambience_park_ogg_q4.ogg` | Ogg Vorbis q4 | 564.1 KB | 7.5% |
| `out/ambience_park_ogg_q2.ogg` | Ogg Vorbis q2 | 457.4 KB | 6.1% |
| `out/ambience_park_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 615.1 KB | 8.2% |

### music_title (`audio/music/out/music_title.wav`, loop)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/music_title_original.wav` | original: 48000 Hz, stereo, Signed 16 bit PCM | 5.33 MB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 1.08 MB | 20.2% |
| `out/music_title_ogg_q6.ogg` | Ogg Vorbis q6 | 615.6 KB | 11.3% |
| `out/music_title_ogg_q4.ogg` | Ogg Vorbis q4 | 428.4 KB | 7.9% |
| `out/music_title_ogg_q2.ogg` | Ogg Vorbis q2 | 315.5 KB | 5.8% |
| `out/music_title_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 492.8 KB | 9.0% |

### music_match_park (`audio/music/out/music_match_park.wav`, loop)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/music_match_park_original.wav` | original: 48000 Hz, stereo, Signed 16 bit PCM | 7.03 MB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 1.42 MB | 20.2% |
| `out/music_match_park_ogg_q6.ogg` | Ogg Vorbis q6 | 751.6 KB | 10.4% |
| `out/music_match_park_ogg_q4.ogg` | Ogg Vorbis q4 | 513.9 KB | 7.1% |
| `out/music_match_park_ogg_q2.ogg` | Ogg Vorbis q2 | 401.7 KB | 5.6% |
| `out/music_match_park_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 588.2 KB | 8.2% |

### ann_ace_1 (`audio/announcer/out/ace_1.wav`, voice)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/ann_ace_1_original.wav` | original: 24000 Hz, mono, Signed 16 bit PCM | 26.7 KB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 5.8 KB | 21.7% |
| `out/ann_ace_1_ogg_q4.ogg` | Ogg Vorbis q4 | 7.2 KB | 27.1% |
| `out/ann_ace_1_ogg_q2.ogg` | Ogg Vorbis q2 | 6.4 KB | 23.8% |
| `out/ann_ace_1_ima_adpcm.wav` | IMA-ADPCM WAV (4-bit), as Godot's RAM mode | 7.1 KB | 26.4% |
| `out/ann_ace_1_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 4.1 KB | 15.2% |

### ann_smash_winner_2 (`audio/announcer/out/smash_winner_2.wav`, voice)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/ann_smash_winner_2_original.wav` | original: 24000 Hz, mono, Signed 16 bit PCM | 86.2 KB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 17.8 KB | 20.7% |
| `out/ann_smash_winner_2_ogg_q4.ogg` | Ogg Vorbis q4 | 16.4 KB | 19.0% |
| `out/ann_smash_winner_2_ogg_q2.ogg` | Ogg Vorbis q2 | 12.9 KB | 15.0% |
| `out/ann_smash_winner_2_ima_adpcm.wav` | IMA-ADPCM WAV (4-bit), as Godot's RAM mode | 22.1 KB | 25.6% |
| `out/ann_smash_winner_2_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 12.6 KB | 14.6% |

### ann_quip_11 (`audio/announcer/out/quip_11.wav`, voice)

| File | Format | Size | % of WAV |
|---|---|---:|---:|
| `out/ann_quip_11_original.wav` | original: 24000 Hz, mono, Signed 16 bit PCM | 287.1 KB | 100.0% |
| (not a file) | what ships now: Godot QOA import | 58.5 KB | 20.4% |
| `out/ann_quip_11_ogg_q4.ogg` | Ogg Vorbis q4 | 43.8 KB | 15.3% |
| `out/ann_quip_11_ogg_q2.ogg` | Ogg Vorbis q2 | 33.7 KB | 11.8% |
| `out/ann_quip_11_ima_adpcm.wav` | IMA-ADPCM WAV (4-bit), as Godot's RAM mode | 73.1 KB | 25.4% |
| `out/ann_quip_11_mp3_vbr.mp3` | MP3 VBR (LAME, middle quality) | 35.7 KB | 12.4% |

### Every clip the game loads (`--estimate`)

| Group | Files | WAV | QOA (ships now) | Ogg q4 | Ogg q2 |
|---|---:|---:|---:|---:|---:|
| SFX | 30 | 1.61 MB | 344.2 KB | 255.0 KB | 221.0 KB |
| Ambience loops | 7 | 51.27 MB | 10.36 MB | 3.87 MB | 3.18 MB |
| Music | 12 | 67.80 MB | 13.70 MB | 4.77 MB | 3.66 MB |
| Announcer | 298 | 27.73 MB | 5.72 MB | 4.81 MB | 3.89 MB |
| **All** | 347 | 148.41 MB | 30.11 MB | 13.69 MB | 10.94 MB |

<!-- make_compare.py: end -->

## What it would save

From the estimate table (QOA is what ships now):

- **Ogg q4 for everything**: about 30 MB → 14 MB of audio, so a `.pck`
  of roughly 18 MB instead of 34 MB.
- **Ogg only for music and ambience, QOA kept for SFX and announcer**:
  24 MB → 8.6 MB for the loops, a `.pck` of roughly 19 MB. This is nearly
  all of the saving (the 19 music and ambience files are 80% of the audio) and
  keeps the 328 short clips on the format Godot plays most cheaply.
- Ogg on the SFX and announcer saves only about 1 MB more (6.1 → 5.1 MB
  at q4), and the shortest clips (`hit`, `ann_ace_1`) come out *larger*
  than QOA, because each Ogg file carries about 4 KB of codebook headers.

Platform exports (60 to 93 MB) also hold the engine binary, so they
shrink by the same ~15 MB, not in proportion.

## Doing it at build time in Godot (notes, not changes)

Godot's WAV importer can't produce Vorbis: an `.ogg` has to exist as a
file under `game/assets/`. The cleanest place is `sync_assets.sh`: keep
the WAVs as the kit's masters and have it encode `music_*`/`ambience_*`
to `.ogg` (this script's `ogg()` settings) instead of copying them. Things
that would change or need care:

- **Load paths and types.** `view/music.gd` and `view/sfx.gd` (ambience)
  load `"... .wav"` by name and type the result as `AudioStreamWAV`. Ogg
  loads as `AudioStreamOggVorbis`.
- **Looping.** `music.gd` and `sfx.gd` set
  `stream.loop_mode = AudioStreamWAV.LOOP_FORWARD` at load. The Ogg
  equivalent is `stream.loop = true` (or `edit/loop=true` and
  `loop_offset` in the `.ogg.import`). The loops are mixed circularly
  (`audio/music/README.md`) and the Ogg files keep the exact length, so
  the seam should hold. Still, listen to a few wraps of each in the game:
  a Vorbis frame that spans the end and the start can click quietly.
  Stingers (`music_won`, `music_lost`, `music_cleared`) don't loop.
- **Latency and CPU on short SFX.** Ogg is decoded while it plays, and a
  hit plays several times a second during a rally. QOA (or IMA-ADPCM,
  compress/mode=1) is cheap to decode and has no headers. Keep the short
  SFX on WAV import.
- **The announcer's trims.** `prep.py` trims each line, and the imports
  have `edit/trim=false`, so the clip plays as cut. Ogg keeps the exact
  length, but the announcer saves little (above) and its lines queue
  back to back, so leave it on QOA.
- **Cheaper knobs on the WAV importer**, with no code change:
  `force/max_rate` (with `force/max_rate_hz`) and `force/mono` halve QOA's
  size for one clip. Mono would flatten the stereo ambience and applause,
  though, and these knobs save less than Ogg on the loops.
- **Tests.** The game's tests load scenes that load these streams, so a
  switch has to rerun `test.sh` and check that the leak and view tests
  don't depend on the stream type.
- **Web export.** Vorbis decodes in the engine on every platform, with no
  browser codec involved.
- MP3 is here for reference only. Godot imports it, but Ogg is as small
  at the same quality, and MP3's frames make gapless loops harder.
