"""Smaller-file versions of a few of the game's sounds, to compare by ear
and by size before choosing a build-time audio format.

    .venv/bin/python audio/compare/make_compare.py             # out/ + README.md
    .venv/bin/python audio/compare/make_compare.py --estimate  # also encode every
                                                               # shipped clip once

Reads the generated WAVs (hd-sfx/out, music/out, announcer/out) and never
writes to them. Encoding goes through the soundfile package (libsndfile
with libvorbis and LAME built in); ffmpeg is not needed. Install it with
`.venv/bin/pip install soundfile`.

Nothing here changes what the game ships: game/assets/audio still gets the
WAVs, which Godot imports as QOA (compress/mode=2).
"""

import argparse
import glob
import os
import shutil
import sys
import tempfile

import numpy as np

try:
    import soundfile as sf
except ImportError:
    sys.exit("make_compare.py needs soundfile: .venv/bin/pip install soundfile")

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.dirname(HERE)
KIT = os.path.dirname(AUDIO)
OUT = os.path.join(HERE, "out")
IMPORTED = os.path.join(KIT, "game", ".godot", "imported")

# (short name, source, kind)
SAMPLES = [
    ("hit", "hd-sfx/out/0_hit.wav", "sfx"),
    ("bounce", "hd-sfx/out/1_bounce.wav", "sfx"),
    ("applause", "hd-sfx/out/4_applause.wav", "sfx"),
    ("ambience_park", "hd-sfx/out/ambience_park.wav", "loop"),
    ("music_title", "music/out/music_title.wav", "loop"),
    ("music_match_park", "music/out/music_match_park.wav", "loop"),
    ("ann_ace_1", "announcer/out/ace_1.wav", "voice"),
    ("ann_smash_winner_2", "announcer/out/smash_winner_2.wav", "voice"),
    ("ann_quip_11", "announcer/out/quip_11.wav", "voice"),
]

# Vorbis quality is oggenc's -q scale (0..10); libsndfile takes a
# compression level, 1 - q/10.
OGG = {"sfx": [6, 4, 2], "loop": [6, 4, 2], "voice": [4, 2]}


def ogg(q):
    return ("ogg_q%d.ogg" % q, "Ogg Vorbis q%d" % q,
            dict(format="OGG", subtype="VORBIS", compression_level=1 - q / 10))


MP3 = ("mp3_vbr.mp3", "MP3 VBR (LAME, middle quality)",
       dict(format="MP3", subtype="MPEG_LAYER_III", bitrate_mode="VARIABLE",
            compression_level=0.5))
ADPCM = ("ima_adpcm.wav", "IMA-ADPCM WAV (4-bit), as Godot's RAM mode",
         dict(format="WAV", subtype="IMA_ADPCM"))


def resample(x, sr, to):
    """FFT resample: fine for clips of a few seconds."""
    n = int(round(len(x) * to / sr))
    spec = np.fft.rfft(x, axis=0)
    keep = n // 2 + 1
    if keep <= spec.shape[0]:
        spec = spec[:keep]
    else:
        pad = np.zeros((keep - spec.shape[0],) + spec.shape[1:], spec.dtype)
        spec = np.concatenate([spec, pad])
    y = np.fft.irfft(spec, n, axis=0) * (n / len(x))
    return np.clip(y, -1.0, 1.0)


def mono(x):
    return x.mean(axis=1) if x.ndim == 2 else x


def describe(path):
    i = sf.info(path)
    return "%d Hz, %s, %s" % (i.samplerate, "stereo" if i.channels == 2 else "mono",
                              i.subtype_info)


def qoa_size(src):
    """Size of the clip as the game ships it now (Godot's imported QOA
    .sample), when the project has been imported."""
    name = os.path.basename(src)
    hits = glob.glob(os.path.join(IMPORTED, name + "-*.sample"))
    return os.path.getsize(hits[0]) if hits else None


def variants(kind):
    out = [ogg(q) for q in OGG[kind]]
    if kind in ("sfx", "voice"):
        out.append(ADPCM)
    out.append(MP3)
    return out


def make(name, src, kind):
    """Writes out/<name>_*.{wav,ogg,mp3}; returns table rows."""
    path = os.path.join(AUDIO, src)
    data, sr = sf.read(path, dtype="float64")
    orig = os.path.join(OUT, name + "_original.wav")
    shutil.copyfile(path, orig)
    base = os.path.getsize(orig)
    rows = [(os.path.basename(orig), "original: " + describe(orig), base)]
    qoa = qoa_size(src)
    if qoa:
        rows.append(("(not a file)", "what ships now: Godot QOA import", qoa))
    for suffix, label, kw in variants(kind):
        f = os.path.join(OUT, "%s_%s" % (name, suffix))
        sf.write(f, data, sr, **kw)
        rows.append((os.path.basename(f), label, os.path.getsize(f)))
    if kind == "sfx":
        f = os.path.join(OUT, name + "_22k_mono.wav")
        sf.write(f, resample(mono(data), sr, 22050), 22050, subtype="PCM_16")
        rows.append((os.path.basename(f), "22050 Hz mono 16-bit WAV", os.path.getsize(f)))
    return rows


def kb(n):
    return "%.1f KB" % (n / 1024) if n < 1024 * 1024 else "%.2f MB" % (n / 1024 / 1024)


def estimate():
    """Encodes every clip the game ships at q4 and q2; sums per group."""
    groups = [
        ("SFX", "hd-sfx/out/[0-9]*.wav"),
        ("Ambience loops", "hd-sfx/out/ambience_*.wav"),
        ("Music", "music/out/*.wav"),
        ("Announcer", "announcer/out/*.wav"),
    ]
    rows = []
    with tempfile.TemporaryDirectory() as tmp:
        for title, pattern in groups:
            files = sorted(glob.glob(os.path.join(AUDIO, pattern)))
            wav = sum(os.path.getsize(f) for f in files)
            qoa = [qoa_size(os.path.relpath(f, AUDIO)) for f in files]
            qoa = sum(qoa) if all(qoa) else None
            sizes = {}
            for q in (4, 2):
                total = 0
                for f in files:
                    data, sr = sf.read(f, dtype="float64")
                    t = os.path.join(tmp, "x.ogg")
                    sf.write(t, data, sr, **ogg(q)[2])
                    total += os.path.getsize(t)
                sizes[q] = total
            rows.append((title, len(files), wav, qoa, sizes[4], sizes[2]))
            print("  %-15s %3d files  wav %s  qoa %s  q4 %s  q2 %s" % (
                title, len(files), kb(wav), kb(qoa) if qoa else "?",
                kb(sizes[4]), kb(sizes[2])))
    return rows


BEGIN, END = "<!-- make_compare.py: begin -->", "<!-- make_compare.py: end -->"


def readme(table, est):
    """Rewrites the generated part of README.md, between the markers."""
    lines = ["Sizes are on disk; % is of the original WAV. \"What ships now\" is",
             "the clip's Godot import (QOA, compress/mode=2), read from",
             "`game/.godot/imported/`: what it takes in the `.pck` today.", ""]
    for name, src, kind, rows in table:
        base = rows[0][2]
        lines += ["### %s (`audio/%s`, %s)" % (name, src, kind), "",
                  "| File | Format | Size | % of WAV |", "|---|---|---:|---:|"]
        for f, label, size in rows:
            cell = "`out/%s`" % f if f.endswith((".wav", ".ogg", ".mp3")) else f
            lines.append("| %s | %s | %s | %.1f%% |" % (cell, label, kb(size),
                                                         100 * size / base))
        lines.append("")
    if est:
        lines += ["### Every clip the game loads (`--estimate`)", "",
                  "| Group | Files | WAV | QOA (ships now) | Ogg q4 | Ogg q2 |",
                  "|---|---:|---:|---:|---:|---:|"]
        tot = [0, 0, 0, 0, 0]
        for title, n, wav, qoa, q4, q2 in est:
            lines.append("| %s | %d | %s | %s | %s | %s |" % (
                title, n, kb(wav), kb(qoa) if qoa else "?", kb(q4), kb(q2)))
            for i, v in enumerate((n, wav, qoa or 0, q4, q2)):
                tot[i] += v
        lines.append("| **All** | %d | %s | %s | %s | %s |" % (
            tot[0], kb(tot[1]), kb(tot[2]), kb(tot[3]), kb(tot[4])))
        lines.append("")
    path = os.path.join(HERE, "README.md")
    text = open(path).read()
    head, rest = text.split(BEGIN)
    if not est and "--estimate" in rest.split(END)[0]:
        # keep the last estimate rather than drop it
        old = rest.split(END)[0]
        lines.append(old[old.index("### Every clip"):].strip())
        lines.append("")
    tail = rest.split(END)[1]
    with open(path, "w") as fh:
        fh.write(head + BEGIN + "\n\n" + "\n".join(lines) + "\n" + END + tail)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--estimate", action="store_true",
                    help="also encode every shipped clip and estimate the .pck saving")
    args = ap.parse_args()
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    table = []
    for name, src, kind in SAMPLES:
        rows = make(name, src, kind)
        table.append((name, src, kind, rows))
        print("%-20s %s" % (name, "  ".join("%s %s" % (r[0].split(name + "_")[-1], kb(r[2]))
                                            for r in rows)))
    est = estimate() if args.estimate else None
    readme(table, est)
    print("wrote", os.path.relpath(OUT, KIT), "and README.md")


if __name__ == "__main__":
    main()
