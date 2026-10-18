# HD sound effects and ambience

The Godot port's sounds, remade without the SNES's limits (16 kHz mono
in 22 KiB of sound RAM). Everything is synthesized by `make_sfx.py` with
numpy and fixed seeds, so a rebuild gives the same files. There is no
recorded or third-party audio. The SNES set stays in `../snes-sfx`.

```sh
.venv/bin/python audio/hd-sfx/make_sfx.py --report   # writes out/, prints levels
cp audio/hd-sfx/out/*.wav game/assets/audio/          # or game/tools/sync_assets.sh
```

| Sound | How it's made | Variants |
|---|---|---|
| Hit (standard, drive, soft) | A hard click, the hollow ball's shell ringing (decaying partials around 1.2-5 kHz), the paddle face's lower "thock", airy noise from the holes, and a small court's reflections. A drive adds a low face slap and more bite; a soft shot is padded and darker. | 4 each |
| Bounce | The court's dull thump (~200-500 Hz), a quieter shell ring, and a scuff of grit. | 3 |
| Net | A soft low thud, the tape's twang, and the mesh rattling (a thinning shower of tiny clicks). | |
| Whistle | A pea whistle: ~2.9 kHz with overtones, the pea's irregular ~30 Hz flutter, and a little breath. | |
| Applause | About 45 clappers, each with their own rate, hands and place in the stereo field, over a cheer bed. It swells fast and thins out. | |
| Menu blip / confirm / back | Soft mallet notes (C6; C6 then G6; B5 then E5). | |
| Ambience (6 venues) | 40 s stereo loops, seamless, all at -24 dBFS RMS. PARK: wind in the trees, a distant crowd and the city, birdsong. LAKESIDE: breeze, waves lapping, gulls. SUNSET: evening breeze, traffic far off, a chorus of crickets. Also DINOSAUR (jungle), SPACE (drones and sparkles) and UNDERSEA (rumble and bubbles), for venues to come. | |

All files are 48 kHz 16-bit. Effects are mono (the game pans them by
court position), and applause and ambience are stereo. Hits and bounces
are matched by the loudness of their first 50 ms, so variants don't jump
in volume. The game plays a different variant each time (never the same
twice running), a few percent higher or lower (`game/view/sfx.gd`).
