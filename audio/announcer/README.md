# The announcer

The voice of the remaster's announcer (PORT-52, ADR-076). The script is
`design/announcer/SCRIPT.md` (and `lines.csv`, one row per clip); the
user recorded it with an AI voiceover (the voice and model of each clip
are in `raw/manifest.json`).

```sh
.venv/bin/python audio/announcer/prep.py   # raw/ -> out/, and game/data/announcer.json
game/tools/sync_assets.sh                  # out/ -> game/assets/audio/announcer/
```

- `raw/`: the recordings as delivered, 48 kHz mono, one per id.
- `out/`: trimmed, one loudness (-20 dB RMS, soft-limited, peaks under
  -1 dBFS), 24 kHz. These are what the game plays.

A re-recorded line: replace its file in `raw/` (same id), run both
commands. A new line: add it to `design/announcer/make_script.py`,
record it, and give `view/commentary.gd` a reason to say it.
