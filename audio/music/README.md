# Music

The Godot port's soundtrack (PORT-22, ADR-052). The SNES game never had
music (ADR-029/031, `M4-AUDIO-03`: the venue ambience stood in), so this
is new and original. Everything is composed and synthesized by
`make_music.py` with numpy and fixed seeds, so a rebuild gives the same
files. There is no recorded or third-party audio, as with the effects in
`../hd-sfx`.

```sh
.venv/bin/python audio/music/make_music.py --report   # writes out/, prints levels (about 90 s)
.venv/bin/python audio/music/make_music.py title      # just the tracks whose name has "title"
cp audio/music/out/*.wav game/assets/audio/           # or game/tools/sync_assets.sh
```

| Track | Where | Key, tempo, length | What's in it |
|---|---|---|---|
| `music_title` | The title, every page | D major, 132 BPM, 16 bars (29 s) | A pulse-wave lead with a ping-pong echo, a bell doubling the second half, a driving bass, saw pads, marimba, a kit with fills. |
| `music_park` | The park (open play) | G major, 116 BPM, 16 bars (33 s) | A bouncy whistle lead, marimba offbeat stabs, a walking-ish bass, claps, a tom fill. |
| `music_match_park` | A match at the PARK | F major, 100 BPM, 16 bars (38 s) | Calm, softly swung: electric piano comping, a round bass, rim and hats; a flute melody in the second half. |
| `music_match_lakeside` | A match at LAKESIDE | A major, 94 BPM, 16 bars (41 s) | Breezy: rolling marimba, long bass notes, soft pads, shaker and snaps; a bell melody in the second half. |
| `music_match_sunset` | A match at SUNSET | Eb major, 86 BPM, 16 bars (45 s) | Warm and swung: mellow electric piano, a slow bass, rim clicks; a round lead in the second half. |
| `music_won` | A match won | D major (6 s) | A brass fanfare up the triad, a held chord, crash and bells. |
| `music_lost` | A match lost | (7 s) | A friendly sliding "aww" to a soft G minor chord. |
| `music_cleared` | The ladder cleared | E major (9 s) | A snare roll, then a bigger fanfare a key up from the title's, a held chord and bells. |

How it's made:

- **Parts as text.** Melodies are `note:beats` (`F#5:3/4`, `r:1/2`);
  chords are symbols (`Bbmaj7`, `A7sus4`, `Amaj9/C#`); bass, arpeggio,
  comping and drum parts are 16-step strings, one per bar (`R-R-O-R-...`:
  root, octave, fifth, third, seventh, approach note). A melody that
  doesn't fill its bars fails the build.
- **Voices.** Band-limited additive oscillators (saw, square, pulse,
  triangle) with a resonant low-pass applied per harmonic, so filters
  sweep without aliasing (bass, leads, brass); wavetable pads of detuned
  saws with a slow filter wobble; two-operator FM for the electric piano
  and bells; modal partials for the marimba; drums from swept sines and
  shaped noise.
- **The mix.** A little timing and velocity humanizing (seeded); pads
  duck under the kick; a dotted-eighth ping-pong echo (the SNES's echo,
  in stereo) and a convolution reverb with a synthesized hall; a soft
  knee keeps peaks under -1 dBFS; TPDF dither to 16 bits.
- **Seamless loops.** A loop is mixed circularly: a note, echo or reverb
  tail that runs past the end sounds at the start, and the filters and
  the reverb work on the loop as a loop, so the last sample leads into the
  first (`--report` prints the seam's jump next to an ordinary step).

All files are 48 kHz 16-bit stereo. Match loops are mastered at -20 dBFS
RMS (calm under play), the title and park at -17/-18, stingers at -16/-18.
In the game (`game/view/music.gd`) the whole soundtrack sits `BASE_DB`
(-9 dB) under the effects, at the MUSIC level, and ducks under the
applause and the whistle.
