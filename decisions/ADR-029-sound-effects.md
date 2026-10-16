# ADR-029 — Sound Effects

Status: **Accepted 2026-10-13**
Ends ADR-009 ("no audio through M3") for sound effects. Music stays out
(`M4-AUDIO-03`).
Depends on: the event seam (`src/events.c`), ADR-021 (save), ADR-025
(options).

## Driver

PVSnesLib's **SNESMOD** (sm-spc) runs on the SPC700.

- At boot, `spcBoot`, `spcSetBank`, and `spcLoadEffect` for each effect.
- An effect starts with `spcEffect(pitch, index, volume << 4 | pan)`.
- The soundbank comes from `smconv` (`-s -b 7`), fed by
  `assets/generated/sfx.it`, and sits in its own ROM bank, 7.

## The effects

`tools/assetgen/sfx.py` synthesizes every effect with the Python standard
library, using fixed seeds. There is no recorded or third-party audio. It
writes a minimal Impulse Tracker file (one 16-bit sample and one instrument
per effect, plus one empty pattern), and `sfx.h` with the indices.

| Effect | Sound | Length |
|---|---|---:|
| HIT | Hollow paddle "pock": 1050/1700/2600 Hz partials and a click | 90 ms |
| BOUNCE | Lower court "tok": 380 Hz plus grit | 70 ms |
| NET | 140 Hz thump with a rattle | 220 ms |
| WHISTLE | Pea whistle: 2.9 kHz with a 28 Hz wobble and breath | 420 ms |
| APPLAUSE | Random claps (thinning out) over a murmur | 1.4 s |
| BLIP / CONFIRM / BACK | Menu tones | 40–140 ms |

- Samples are 16 kHz and play at SNESMOD pitch 4.
- **Budget:** 22.3 KiB of BRR samples; the module takes 22.4 KiB of ARAM,
  leaving about 35 KiB free. The ROM bank holds 23.6 KiB, and the ROM now
  has about 51 KiB free (build report).
- `make sfx-preview` writes each effect as a WAV in `build/sfx/` to listen
  to.

## Mapping (`src/audio_events.c`)

| Event | Effect |
|---|---|
| SERVE | HIT |
| HIT | HIT: DRIVE at pitch 5 (sharper), SOFT at 3 (duller), standard at 4 |
| BOUNCE | BOUNCE (later bounces quieter) |
| FAULT | NET for a net fault, otherwise WHISTLE |
| POINT | APPLAUSE: volume 6 to 13 by shots in the rally, 15 for the match-winning point |
| Practice | BOUNCE now emitted there too, and APPLAUSE every 5th return in a row |
| Menus | BLIP for a move, CONFIRM for a choice, BACK for Y. Title, pages, Player Select, the intro card, and pause. |

- Game sounds are panned by the ball's court x. The attract demo is silent;
  the title has menu sounds only.
- **OPTIONS → SOUND:** ALL, NO CROWD, or OFF. It is stored in the save's
  spare settings byte, which was 0 = ALL, so no version bump was needed.
- Under `HOST_TEST`, the module keeps the event counts and records the last
  effect (`g_audio_last`) instead of calling SNESMOD.

## Frame budget

- `spcEffect` only queues a command. `spcProcess` hands commands to the
  SPC700 and waits for each to be taken, which costs 60–110 scanlines.
- It runs after the frame's work, just before VBlank, and only when the
  work ended by scanline 130. Otherwise it waits up to 3 frames, then runs
  anyway, so an effect is at most a few frames late.
- The COURT page recolour waits for scanline 110 (it was 150), so it and a
  row redraw don't share a busy frame.
- *Amended (late whistle and applause):* one `spcProcess` call can leave
  commands queued. A fault plays the whistle and the point's applause on
  the same frame, and the second used to wait for the next sound (often the
  next point's serve). `spcProcess` now keeps running for 6 frames after
  the last effect. In MesenCE, both voices start within 3–6 frames of the
  request.
- Results: zero overruns on idle, records, court, venue, options,
  practice, golden, the doubles match, and the 3,000-frame title.

## Verification

- `test/test_audio.c` (host):
  - effect, pitch, pan, and volume for each event
  - the crowd scales with the rally, and the match-winning point is loudest
  - NO CROWD and OFF
  - the attract demo is silent
  - menu sounds play on the title
- **MesenCE:** a Lua probe read the SPC700 voices' `envVolume` from
  `emu.getState()` each frame. It showed voices sounding:
  - for menu presses
  - for practice feeds and bounces
  - for each serve, hit, and bounce of the golden match, and about 1.4 s
    of applause after each point
- PVSnesLib's own effects example was used to check the probe itself.
- Real-hardware listening is still to do (`M4-AUDIO-04`).

## Found on the way

`g_story` (ADR-026) was never initialized at boot. RAM is random at
power-on, so a non-zero `card` froze the attract demo under an invisible
"card" for up to 5 s and played a stray confirm sound. It is now set by
`story_initialize()` in `main`.
