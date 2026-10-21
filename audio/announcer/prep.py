"""The announcer's clips for the game (PORT-52, ADR-076): from the raw
recordings in raw/ (one WAV per line of design/announcer/lines.csv) to
out/, which game/tools/sync_assets.sh copies into the game.

Each clip is trimmed (20 ms before the voice, 80 ms after), set to one
loudness (the voiced part's RMS at TARGET_DB, a soft limiter on the
peaks, held under -1 dBFS),
and resampled 48 kHz -> 24 kHz (a windowed-sinc low-pass first): plenty
for a voice, half the size. Writes each clip's length to game/data/announcer.json:
the game times its lines by it.

    .venv/bin/python audio/announcer/prep.py
"""
import glob
import json
import os
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "out")
INDEX = os.path.join(HERE, "..", "..", "game", "data", "announcer.json")
RATE = 24000
TARGET_DB = -20.0
KNEE = 0.5                       ## the soft limiter starts here (-6 dBFS)
PEAK_DB = -1.0
GATE = 0.01                      # the envelope above this is voice
LEAD = 0.02
TAIL = 0.08


def read(path):
    w = wave.open(path)
    assert w.getnchannels() == 1 and w.getsampwidth() == 2, path
    a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768
    return a, w.getframerate()


def lowpass_half(a):
    """A 63-tap windowed-sinc low-pass at a quarter of the rate, then every
    other sample: 48 kHz to 24 kHz without aliasing."""
    n = np.arange(-31, 32)
    h = np.sinc(n / 2.0) / 2.0 * np.blackman(63)
    h /= h.sum()
    return np.convolve(a, h, "same")[::2]


def prep(a, rate):
    env = np.convolve(np.abs(a), np.ones(rate // 100) / (rate // 100), "same")
    voiced = np.where(env > GATE)[0]
    if len(voiced) == 0:
        return a, 0.0
    lo = max(0, voiced[0] - int(LEAD * rate))
    hi = min(len(a), voiced[-1] + int(TAIL * rate))
    a = a[lo:hi]
    core = a[voiced[0] - lo:voiced[-1] - lo]
    rms = np.sqrt(np.mean(core ** 2)) + 1e-12
    a = a * 10 ** ((TARGET_DB - 20 * np.log10(rms)) / 20)
    # a soft knee over KNEE: a shout's peaks round off instead of the whole
    # clip turning down, then the ceiling
    m = np.abs(a)
    over = m > KNEE
    a[over] = np.sign(a[over]) * (KNEE + (1 - KNEE) * np.tanh((m[over] - KNEE) / (1 - KNEE)))
    limit = 10 ** (PEAK_DB / 20)
    peak = np.max(np.abs(a))
    if peak > limit:
        a *= limit / peak
    # 5 ms fades: no click at the cut
    f = int(0.005 * rate)
    a[:f] *= np.linspace(0, 1, f)
    a[-f:] *= np.linspace(1, 0, f)
    if rate == 2 * RATE:
        a = lowpass_half(a)
    elif rate != RATE:
        sys.exit("expected 48 or 24 kHz: %s" % rate)
    return a, len(a) / RATE


def write(path, a):
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes((np.clip(a, -1, 1) * 32767).astype("<i2").tobytes())
    w.close()


def main():
    os.makedirs(OUT, exist_ok=True)
    files = sorted(glob.glob(os.path.join(RAW, "*.wav")))
    total = 0.0
    index = {}
    for p in files:
        a, rate = read(p)
        b, secs = prep(a, rate)
        write(os.path.join(OUT, os.path.basename(p)), b)
        index[os.path.basename(p)[:-4]] = round(secs, 3)
        total += secs
    with open(INDEX, "w") as f:
        json.dump({"comment": "The announcer's clips and their lengths in seconds "
                   "(audio/announcer/prep.py writes this; PORT-52, ADR-076).", "clips": index},
                  f, indent=1, sort_keys=True)
    print("%d clips, %.0f s, into %s; index %s" % (len(files), total, OUT, os.path.normpath(INDEX)))


if __name__ == "__main__":
    main()
