"""HD sound effects and venue ambience for the Godot port (no SNES limits).

Everything is synthesized here, with numpy only and fixed seeds: no
recorded or third-party audio, as with the SNES set (ADR-029/031), which
stays in audio/snes-sfx. Techniques:
  * modal synthesis: a struck object is a sum of exponentially decaying
    partials (the ball's shell, the paddle face, the court, the net cord);
  * shaped noise: white noise filtered in the frequency domain (a smooth
    band-pass), for clicks, scuffs, breath, wind, water and claps;
  * convolution reverb with a synthesized room (exponentially decaying,
    darkening noise plus early reflections), for a sense of place;
  * variants with jittered parameters, so repeated sounds aren't identical.
Effects are 48 kHz mono (the game pans them); applause and ambience are
48 kHz stereo; ambience loops seamlessly (an equal-power crossfade).

    .venv/bin/python audio/hd-sfx/make_sfx.py           # writes audio/hd-sfx/out
    .venv/bin/python audio/hd-sfx/make_sfx.py --report  # and prints levels
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 48000
OUT = Path(__file__).resolve().parent / "out"


# --- building blocks -------------------------------------------------------------

def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def db(x):
    return 10 ** (x / 20.0)


def band(x, lo, hi, order=2):
    """A smooth band-pass (Butterworth-shaped magnitude) applied by FFT.
    lo=0 is a low-pass, hi=None a high-pass."""
    n = len(x)
    if n == 0:
        return x
    size = 1 << (2 * n - 1).bit_length()   # zero-padded: no wrap-around
    spec = np.fft.rfft(x, size, axis=0)
    f = np.fft.rfftfreq(size, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-6)) ** (2 * order))
    if hi:
        g *= 1 / np.sqrt(1 + (f / hi) ** (2 * order))
    if spec.ndim == 2:
        g = g[:, None]
    return np.fft.irfft(spec * g, size, axis=0)[:n]


def noise(rng, seconds, channels=1):
    n = int(seconds * SR)
    return rng.standard_normal((n, channels) if channels > 1 else n)


def pink(rng, seconds, channels=1):
    """1/f noise, by shaping white noise's spectrum."""
    w = noise(rng, seconds, channels)
    spec = np.fft.rfft(w, axis=0)
    f = np.fft.rfftfreq(w.shape[0], 1 / SR)
    g = 1 / np.sqrt(np.maximum(f, 20.0))
    if spec.ndim == 2:
        g = g[:, None]
    p = np.fft.irfft(spec * g, w.shape[0], axis=0)
    return p / (np.max(np.abs(p)) + 1e-9)


def modes(seconds, partials, glide=0.0, phase_rng=None):
    """Decaying partials: [(Hz, decay seconds, amplitude), ...]. `glide`
    bends every partial down by that fraction over its decay."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for freq, decay, amp in partials:
        f = freq * (1 - glide * (1 - np.exp(-t / max(decay, 1e-4))))
        ph = np.cumsum(2 * np.pi * f / SR)
        if phase_rng is not None:
            ph += phase_rng.uniform(0, 2 * np.pi)
        out += amp * np.sin(ph) * np.exp(-t / decay)
    return out


def env_exp(seconds, attack, decay):
    t = t_axis(seconds)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def fit(x, n):
    """Pad or cut to n samples."""
    if len(x) >= n:
        return x[:n]
    pad = np.zeros((n - len(x),) + x.shape[1:])
    return np.concatenate([x, pad])


def room_ir(rng, seconds, decay, brightness=6000, early=(), stereo=False):
    """A synthesized room: early reflections, then decaying noise that
    darkens as it fades."""
    ch = 2 if stereo else 1
    t = t_axis(seconds)
    tail = noise(rng, seconds, ch)
    shape = np.exp(-t / decay)
    if ch == 2:
        shape = shape[:, None]
    tail *= shape
    # darken: blend a low-passed copy in over time
    dark = band(tail, 0, brightness * 0.3)
    mix = np.clip(t / seconds, 0, 1)
    if ch == 2:
        mix = mix[:, None]
    tail = band(tail, 0, brightness) * (1 - mix) + dark * mix
    tail *= 0.08
    for delay, gain in early:
        i = int(delay * SR)
        if i < len(tail):
            if ch == 2:
                tail[i, 0] += gain
                tail[min(i + int(0.0007 * SR), len(tail) - 1), 1] += gain * 0.9
            else:
                tail[i] += gain
    return tail


def convolve(x, ir):
    """FFT convolution; mono x with a stereo ir gives stereo."""
    if x.ndim == 1 and ir.ndim == 2:
        x = np.stack([x, x], axis=1)
    n = len(x) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    X = np.fft.rfft(x, size, axis=0)
    H = np.fft.rfft(ir, size, axis=0)
    return np.fft.irfft(X * H, size, axis=0)[:n]


def reverb(x, rng, wet, seconds=0.4, decay=0.12, brightness=7000, early=(), stereo=False):
    """The dry sound plus its room. `wet` is the room's energy against the
    dry sound's (0.1 = the room 10 dB under the sound), whatever the room."""
    ir = room_ir(rng, seconds, decay, brightness, early, stereo)
    w = convolve(x, ir)
    dry = x if not stereo or x.ndim == 2 else np.stack([x, x], axis=1)
    dry = fit(dry, len(w))
    e_dry = np.sqrt(np.mean(np.square(dry))) + 1e-12
    e_wet = np.sqrt(np.mean(np.square(w))) + 1e-12
    return dry + w * (wet * e_dry / e_wet)


def fade_tail(x, seconds=0.01):
    n = min(len(x), int(seconds * SR))
    ramp = np.linspace(1, 0, n)
    if x.ndim == 2:
        ramp = ramp[:, None]
    x = x.copy()
    x[-n:] *= ramp
    return x


def trim_silence(x, floor_db=-70):
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    idx = np.where(a > db(floor_db) * np.max(a))[0]
    return x[: idx[-1] + 1] if len(idx) else x


def normalize(x, peak_db):
    x = x - np.mean(x, axis=0)
    return x / (np.max(np.abs(x)) + 1e-12) * db(peak_db)


def match(x, body_rms_db, peak_db, body=0.05):
    """Variants at one loudness: the first `body` seconds' RMS at the
    target, then pulled down if that would exceed the peak ceiling."""
    x = x - np.mean(x, axis=0)
    n = max(1, int(body * SR))
    r = np.sqrt(np.mean(np.square(x[:n]))) + 1e-12
    x = x * db(body_rms_db) / r
    p = np.max(np.abs(x))
    return x * min(1.0, db(peak_db) / p)


def pan_stereo(x, pan):
    """Equal-power pan of a mono signal, -1 left .. 1 right."""
    a = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1 if pcm.ndim == 1 else 2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# --- the effects -----------------------------------------------------------------

def paddle_hit(rng, kind):
    """A paddle meeting a hollow plastic ball: a hard click, the ball's shell
    ringing (bright, short partials), the paddle face's lower 'thock', a
    burst of airy noise from the holes, and a small court's reflections.
    kind: standard, drive (harder, brighter, more slap), soft (padded),
    slice (SNES ADR-056: padded and dull, with the brush of the face across
    the ball for the spin), or smash (the overhead, PORT-24: the hardest crack, a deep slap, and the
    air tearing off the ball after it)."""
    j = lambda: rng.uniform(0.96, 1.04)
    dur = 0.32
    n = int(dur * SR)
    hard = {"standard": 1.0, "drive": 1.45, "soft": 0.55, "slice": 0.7, "smash": 1.9}[kind]
    click = fit(band(noise(rng, 0.004), 2500, 14000) * env_exp(0.004, 0.0002, 0.0009), n)
    shell = modes(dur, [(1180 * j(), 0.020, 1.0), (1890 * j(), 0.015, 0.7),
                        (2660 * j(), 0.011, 0.45), (3710 * j(), 0.007, 0.3),
                        (5150 * j(), 0.004, 0.15 * hard)], glide=0.03, phase_rng=rng)
    face = modes(dur, [(470 * j(), 0.030, 0.55 * hard), (830 * j(), 0.022, 0.35),
                       (1320 * j(), 0.016, 0.2)], glide=0.05, phase_rng=rng)
    holes = band(noise(rng, dur), 900, 3200) * env_exp(dur, 0.0006, 0.018)
    x = click * (1.6 * hard) + shell * 0.9 + face * 0.8 + holes * 0.35
    if kind in ("soft", "slice"):
        x = band(x, 0, 2600 if kind == "soft" else 2000, order=2) * 1.6
        x *= np.clip(t_axis(dur) / 0.0025, 0, 1)
    if kind == "slice":
        # the brush: a short band of noise sweeping down as the face slides
        tt = t_axis(dur)
        brush = band(noise(rng, dur), 700, 2400) * np.clip(tt / 0.004, 0, 1) * np.exp(-tt / 0.04)
        x += brush * 0.22
    if kind in ("drive", "smash"):
        # the face slap: a low, fast body on the hit
        x += modes(dur, [(185 * j(), 0.018, 0.5 * hard / 1.45)], glide=0.1, phase_rng=rng)
        x = x + band(x, 4000, None) * 0.4
    if kind == "smash":
        # a deeper thump under the slap, and the air off the ball: a
        # falling band of noise for 0.2 s after the crack
        x += modes(dur, [(96 * j(), 0.035, 0.45)], glide=0.15, phase_rng=rng)
        tt = t_axis(dur)
        air = noise(rng, dur)
        air = band(air, 1200, 5200) * np.clip((tt - 0.006) / 0.01, 0, 1) * np.exp(-tt / 0.07)
        x += band(air, 600, 3000) * 0.5 + air * 0.25
    x = reverb(x, rng, wet=0.14, seconds=0.3, decay=0.06, brightness=8000,
               early=[(0.009, 0.35), (0.017, 0.22), (0.026, 0.15)])
    target = {"standard": -17.0, "drive": -15.0, "soft": -21.0, "slice": -22.0, "smash": -13.5}[kind]
    return fade_tail(trim_silence(match(x, target, -1.0), -60), 0.02)


def court_bounce(rng):
    """The ball on a hard court: the court's dull low thump, the ball's
    shell (quieter than a hit), and a little scuff of grit."""
    j = lambda: rng.uniform(0.95, 1.05)
    dur = 0.25
    n = int(dur * SR)
    thump = modes(dur, [(205 * j(), 0.030, 1.0), (330 * j(), 0.022, 0.6), (520 * j(), 0.015, 0.3)],
                  glide=0.08, phase_rng=rng)
    shell = modes(dur, [(1020 * j(), 0.013, 0.45), (1640 * j(), 0.009, 0.3), (2380 * j(), 0.006, 0.15)],
                  glide=0.02, phase_rng=rng)
    scuff = band(noise(rng, dur), 2000, 7000) * env_exp(dur, 0.0003, 0.006)
    click = fit(band(noise(rng, 0.003), 1500, 9000) * env_exp(0.003, 0.0002, 0.0008), n)
    x = thump + shell + scuff * 0.25 + click * 0.8
    x = reverb(x, rng, wet=0.18, seconds=0.35, decay=0.07, brightness=6000,
               early=[(0.011, 0.3), (0.021, 0.18)])
    return fade_tail(trim_silence(match(x, -20.0, -3.0), -60), 0.02)


def net_hit(rng):
    """The ball into the net: a soft low thud, the tape's twang, and the
    mesh rattling (a thinning shower of tiny clicks)."""
    dur = 0.6
    t = t_axis(dur)
    thud = modes(dur, [(118, 0.06, 1.0), (176, 0.045, 0.5)], glide=0.15, phase_rng=rng)
    twang = modes(dur, [(182, 0.20, 0.35), (364, 0.14, 0.18), (547, 0.09, 0.1)], phase_rng=rng)
    rattle = np.zeros_like(t)
    grains = 90
    for _ in range(grains):
        start = rng.exponential(0.09)
        if start > dur - 0.01:
            continue
        g = band(noise(rng, 0.0015), 2500, 8000) * np.hanning(int(0.0015 * SR))
        i = int(start * SR)
        rattle[i:i + len(g)] += g[: len(rattle) - i] * np.exp(-start / 0.12) * rng.uniform(0.3, 1.0)
    x = thud * 0.9 + twang + rattle * 0.3
    x = reverb(x, rng, wet=0.15, seconds=0.4, decay=0.08, early=[(0.012, 0.25)])
    return fade_tail(trim_silence(normalize(x, -2.0)), 0.03)


def whistle(rng):
    """A referee's pea whistle: a ~2.9 kHz tone with its overtones, the pea
    rolling (irregular flutter at ~30 Hz in pitch and level), breath, and
    a firm attack and release."""
    dur = 0.55
    t = t_axis(dur)
    flutter_rate = 31 + 3 * np.sin(2 * np.pi * 1.7 * t)
    flutter = np.sin(np.cumsum(2 * np.pi * flutter_rate / SR))
    jitter = band(rng.standard_normal(len(t)), 0, 40) * 6
    f0 = 2920 + 55 * flutter + jitter
    ph = np.cumsum(2 * np.pi * f0 / SR)
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    am = 1 - 0.35 * (0.5 + 0.5 * flutter)
    breath = band(noise(rng, dur), 3000, 6500) * 0.06
    shape = np.clip(t / 0.018, 0, 1) * np.clip((dur - t) / 0.11, 0, 1) ** 1.5
    x = (tone * am + breath) * shape
    x = reverb(x, rng, wet=0.12, seconds=0.5, decay=0.12, brightness=9000,
               early=[(0.014, 0.3), (0.031, 0.2)])
    return fade_tail(trim_silence(normalize(x, -5.0)), 0.03)


def one_clap(rng):
    """A single clap: a 1-4 ms crack of band-passed noise whose colour
    depends on the hands (cupped: darker, flat: brighter)."""
    centre = rng.uniform(800, 2600)
    width = rng.uniform(0.6, 1.4)
    dur = rng.uniform(0.010, 0.022)
    g = band(noise(rng, dur), centre / (1 + width), centre * (1 + width))
    return g * env_exp(dur, 0.0004, rng.uniform(0.0015, 0.004))


def applause(rng):
    """A park crowd's applause after a point: ~45 people clapping at their
    own rates and places (stereo), a cheer bed with vowel-like formants,
    swelling quickly and thinning out, in an open-air space."""
    dur = 2.8
    n = int(dur * SR)
    out = np.zeros((n, 2))
    t = t_axis(dur)
    crowd = np.clip(t / 0.18, 0, 1) * np.exp(-np.maximum(t - 0.5, 0) / 0.75)
    for _ in range(45):
        pan = rng.uniform(-0.9, 0.9)
        rate = rng.uniform(3.6, 6.2)
        start = rng.uniform(0.0, 0.25)
        stop = rng.uniform(1.0, 2.4)
        gain = rng.uniform(0.25, 1.0) * (0.4 if abs(pan) > 0.7 else 1.0)
        tt = start
        while tt < stop:
            c = one_clap(rng)
            i = int(tt * SR)
            if i + len(c) >= n:
                break
            out[i:i + len(c)] += pan_stereo(c, pan) * gain * crowd[i]
            tt += 1 / rate * rng.uniform(0.85, 1.15)
    # the cheer: formant-shaped noise ("yeah"/"woo"), wavering
    voice = noise(rng, dur, 2)
    cheer = band(voice, 500, 900) * 0.8 + band(voice, 1100, 1700) * 0.45
    waver = 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(1.5, 3) * t + rng.uniform(0, 6))
    cheer *= (crowd * waver)[:, None] * 0.35
    x = out + cheer
    x = reverb(x, rng, wet=0.22, seconds=1.2, decay=0.35, brightness=6000,
               early=[(0.02, 0.2), (0.045, 0.12)], stereo=True)
    return fade_tail(trim_silence(normalize(x, -2.0)), 0.15)


def ui_tone(rng, notes, step, decay, bright=0.3):
    """Menu sounds: soft mallet-like notes (a sine with a quickly fading
    overtone and a tiny tick), one after another, in a little room."""
    dur = step * (len(notes) - 1) + decay * 5
    t = t_axis(dur)
    x = np.zeros_like(t)
    for k, f in enumerate(notes):
        i = int(k * step * SR)
        tt = t[: len(t) - i]
        e = np.exp(-tt / decay) * np.clip(tt / 0.002, 0, 1)
        note = np.sin(2 * np.pi * f * tt) + bright * np.sin(2 * np.pi * 3.98 * f * tt) * np.exp(-tt / (decay * 0.25))
        x[i:] += note * e * (0.85 if k else 1.0)
    tick = fit(band(noise(rng, 0.002), 3000, 10000) * env_exp(0.002, 0.0001, 0.0005), len(t))
    x += tick * 0.25
    x = reverb(x, rng, wet=0.1, seconds=0.3, decay=0.06)
    return fade_tail(trim_silence(normalize(x, -6.0)), 0.02)


# --- ambience ----------------------------------------------------------------------

LOOP = 40.0
FADE = 2.0


def seamless(x):
    """An equal-power crossfade of the last FADE seconds into the first:
    the result is LOOP seconds and loops without a seam."""
    n = int(LOOP * SR)
    f = int(FADE * SR)
    head = x[:f]
    tail = x[n:n + f]
    a = np.linspace(0, np.pi / 2, f)[:, None]
    body = x[:n].copy()
    body[:f] = head * np.sin(a) + tail * np.cos(a)
    return body


def wind(rng, seconds, lo=150, hi=1800, depth=0.6, rate=0.12):
    w = band(pink(rng, seconds, 2), lo, hi)
    t = t_axis(seconds)
    gust = 1 - depth + depth * (0.5 + 0.5 * band(rng.standard_normal(len(t)), 0, rate * 4) /
                                 0.02).clip(-1, 1)
    return w * gust[:, None]


def place(out, sound, at, pan, gain):
    i = int(at * SR)
    if i >= len(out):
        return
    s = pan_stereo(sound, pan) * gain
    m = min(len(s), len(out) - i)
    out[i:i + m] += s[:m]


def chirp(rng, f0, f1, dur, warble=0.0, warble_rate=40.0, harm=0.2):
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / dur) ** 0.7
    f = f * (1 + warble * np.sin(2 * np.pi * warble_rate * t))
    ph = np.cumsum(2 * np.pi * f / SR)
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return (np.sin(ph) + harm * np.sin(2 * ph)) * e


def bird_phrase(rng):
    kind = rng.integers(3)
    notes = []
    base = rng.uniform(2800, 4600)
    for k in range(rng.integers(3, 7)):
        if kind == 0:     # rising whistles
            notes.append(chirp(rng, base * 0.8, base * 1.25, rng.uniform(0.05, 0.09), harm=0.1))
        elif kind == 1:   # trill
            notes.append(chirp(rng, base, base * 0.95, rng.uniform(0.03, 0.05), 0.08, 55))
        else:             # two-tone "tee-oo"
            notes.append(chirp(rng, base * 1.2, base * 0.7, rng.uniform(0.08, 0.13), 0.02, 30))
        notes.append(np.zeros(int(rng.uniform(0.03, 0.09) * SR)))
    return np.concatenate(notes)


def murmur(rng, seconds, level=0.25):
    """A distant crowd: voice-band noise with slow, uneven swells."""
    v = band(pink(rng, seconds, 2), 220, 1400)
    t = t_axis(seconds)
    swell = 0.7 + 0.3 * np.sin(2 * np.pi * 0.07 * t + rng.uniform(0, 6))
    return v * swell[:, None] * level


def amb_park(rng):
    s = LOOP + FADE
    out = wind(rng, s, 120, 2500, 0.5) * 0.35 + murmur(rng, s, 0.22)
    out += band(pink(rng, s, 2), 40, 140) * 0.05          # the city, far off
    tt = 0.3
    while tt < s - 1:
        place(out, bird_phrase(rng), tt, rng.uniform(-0.8, 0.8), rng.uniform(0.05, 0.13))
        tt += rng.uniform(1.0, 3.2)
    return out


def gull(rng):
    dur = rng.uniform(0.35, 0.55)
    t = t_axis(dur)
    f = 1050 + 450 * np.sin(np.pi * t / dur) - 250 * (t / dur) ** 2
    rough = 1 + 0.15 * np.sin(2 * np.pi * 70 * t)
    ph = np.cumsum(2 * np.pi * f / SR)
    v = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)) * rough
    return band(v * np.sin(np.pi * t / dur) ** 0.8, 600, 5000)


def amb_lakeside(rng):
    s = LOOP + FADE
    out = wind(rng, s, 100, 1500, 0.4) * 0.25 + murmur(rng, s, 0.18)
    t = t_axis(s)
    tt = 0.0
    while tt < s:                                         # waves lapping
        d = rng.uniform(0.7, 1.6)
        lap = band(noise(rng, d), 180, 900) * np.sin(np.pi * t_axis(d) / d) ** 2
        place(out, lap, tt, rng.uniform(-0.6, 0.6), rng.uniform(0.04, 0.08))
        tt += rng.uniform(0.5, 1.4)
    tt = 1.5
    while tt < s - 2:                                     # gulls, two or three calls
        pan = rng.uniform(-0.9, 0.9)
        for k in range(rng.integers(1, 4)):
            place(out, gull(rng), tt + k * rng.uniform(0.45, 0.7), pan, rng.uniform(0.04, 0.09))
        tt += rng.uniform(4.0, 9.0)
    return out


def cricket(rng, rate, carrier, pulses):
    """One field cricket's chirp: a few fast pulses of a pure high tone."""
    pulse = 0.012
    gap = 0.018
    t = t_axis(pulse)
    p = np.sin(2 * np.pi * carrier * t) * np.sin(np.pi * t / pulse) ** 2
    parts = []
    for k in range(pulses):
        parts += [p, np.zeros(int(gap * SR))]
    return np.concatenate(parts)


def amb_sunset(rng):
    s = LOOP + FADE
    out = wind(rng, s, 90, 1200, 0.3) * 0.2 + murmur(rng, s, 0.16)
    out += band(pink(rng, s, 2), 35, 120) * 0.06          # distant traffic
    for c in range(6):
        pan = rng.uniform(-0.9, 0.9)
        carrier = rng.uniform(4200, 5200)
        period = rng.uniform(0.45, 0.9)
        gain = rng.uniform(0.02, 0.05) * (0.5 if c > 3 else 1.0)
        pulses = int(rng.integers(3, 5))
        tt = rng.uniform(0, period)
        while tt < s:
            place(out, cricket(rng, period, carrier, pulses), tt, pan, gain)
            tt += period * rng.uniform(0.95, 1.05)
    return out


def amb_jungle(rng):
    s = LOOP + FADE
    t = t_axis(s)
    out = wind(rng, s, 150, 2000, 0.4) * 0.18
    buzz = band(noise(rng, s, 2), 5500, 8500) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.3 * t))[:, None]
    out += buzz * 0.03
    tt = 0.5
    while tt < s - 1:
        place(out, bird_phrase(rng) * 0.8, tt, rng.uniform(-0.9, 0.9), rng.uniform(0.04, 0.1))
        tt += rng.uniform(0.8, 2.0)
    tt = 6.0
    while tt < s - 3:                                      # something big, far away
        d = 1.8
        roar = band(noise(rng, d), 60, 400) * np.sin(np.pi * t_axis(d) / d) ** 2
        roar += modes(d, [(55, 0.8, 0.3), (82, 0.6, 0.2)])
        place(out, roar, tt, rng.uniform(-0.5, 0.5), 0.12)
        tt += rng.uniform(12, 18)
    return out


def amb_space(rng):
    s = LOOP + FADE
    t = t_axis(s)
    pad = np.zeros((len(t), 2))
    for f, pan in [(55, -0.4), (55.4, 0.4), (82.5, -0.2), (110.3, 0.3), (164.8, 0.0)]:
        pad += pan_stereo(np.sin(2 * np.pi * f * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * t + f)), pan)
    pad *= 0.06
    hiss = band(noise(rng, s, 2), 3000, 9000) * 0.008
    out = pad + hiss
    tt = 1.0
    while tt < s - 2:                                      # sparkles
        f = rng.uniform(1500, 4000)
        ping = modes(1.5, [(f, 0.4, 1.0), (f * 2.76, 0.15, 0.3)], phase_rng=rng)
        place(out, ping, tt, rng.uniform(-0.9, 0.9), rng.uniform(0.02, 0.05))
        tt += rng.uniform(1.5, 4.0)
    return reverb(out, rng, wet=0.35, seconds=2.5, decay=0.9, brightness=5000, stereo=True)


def bubble(rng):
    d = rng.uniform(0.02, 0.05)
    t = t_axis(d)
    f0 = rng.uniform(350, 1400)
    f = f0 * (1 + 2.5 * t / d)
    return np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-t / (d * 0.4))


def amb_undersea(rng):
    s = LOOP + FADE
    out = band(pink(rng, s, 2), 30, 300) * 0.35
    tt = 0.0
    while tt < s - 0.1:
        pan = rng.uniform(-0.8, 0.8)
        for k in range(rng.integers(1, 6)):
            place(out, bubble(rng), tt + k * rng.uniform(0.03, 0.09), pan, rng.uniform(0.03, 0.08))
        tt += rng.uniform(0.2, 1.1)
    return reverb(out, rng, wet=0.3, seconds=1.5, decay=0.5, brightness=2500, stereo=True)


def squeak(rng):
    """A sneaker on a gym floor: a quick bright rubber chirp."""
    f0 = rng.uniform(1800, 2600)
    return chirp(rng, f0, f0 * rng.uniform(1.15, 1.4), rng.uniform(0.05, 0.09), warble=0.04,
                 warble_rate=90.0, harm=0.35)


def amb_gym(rng):
    """THE GYM (ADR-078): a hall's echoey murmur and the ventilation's hum,
    sneakers squeaking and balls bouncing on other courts."""
    s = LOOP + FADE
    out = murmur(rng, s, 0.2)
    out += band(pink(rng, s, 2), 60, 180) * 0.07         # the air handlers
    tt = 0.2
    while tt < s - 1:
        if rng.random() < 0.6:
            place(out, squeak(rng), tt, rng.uniform(-0.9, 0.9), rng.uniform(0.04, 0.09))
        else:
            place(out, fit(court_bounce(rng), int(0.25 * SR)), tt, rng.uniform(-0.9, 0.9),
                  rng.uniform(0.05, 0.1))
        tt += rng.uniform(0.35, 1.4)
    return reverb(out, rng, wet=0.35, seconds=1.2, decay=0.45, brightness=5000, stereo=True)


# ADR-085: the dinosaur game's levels as venues

def crackle(rng, seconds, rate=40):
    """A fire: sparse pops and snaps over a low roar."""
    out = band(pink(rng, seconds, 2), 80, 600) * 0.25
    n = int(seconds * rate)
    for _ in range(n):
        d = rng.uniform(0.003, 0.012)
        pop = band(noise(rng, d), 1500, 7000) * np.exp(-t_axis(d) / (d * 0.3))
        place(out, pop, rng.uniform(0, seconds - 0.02), rng.uniform(-0.6, 0.6), rng.uniform(0.1, 0.5))
    return out


def screech(rng, f0=1400):
    """A raptor's call, far off: a falling, rasping cry."""
    d = rng.uniform(0.5, 0.8)
    c = chirp(rng, f0, f0 * 0.45, d, warble=0.06, warble_rate=70, harm=0.6)
    return band(c, 300, 5000)


def amb_ruins(rng):
    """RUINS: wind through the broken towers, the fires crackling, the
    river below, a raptor calling now and then, a far-off collapse."""
    s = LOOP + FADE
    out = wind(rng, s, 120, 1400, 0.6) * 0.16
    out += crackle(rng, s) * 0.08
    out += band(pink(rng, s, 2), 200, 900) * 0.04            # the river
    out += murmur(rng, s, 0.12)
    tt = 4.0
    while tt < s - 2:
        place(out, screech(rng), tt, rng.uniform(-0.9, 0.9), rng.uniform(0.04, 0.07))
        tt += rng.uniform(7, 13)
    tt = 15.0
    while tt < s - 4:                                        # rubble, far away
        d = 2.5
        rumble = band(noise(rng, d), 40, 300) * np.exp(-t_axis(d) / 0.8)
        place(out, rumble, tt, rng.uniform(-0.6, 0.6), 0.25)
        tt += rng.uniform(16, 22)
    return reverb(out, rng, wet=0.2, seconds=1.5, decay=0.5, brightness=4000, stereo=True)


def amb_glacier(rng):
    """GLACIER: a howling wind off the peaks, the ice creaking, the snow
    hissing past, a pterodactyl crying high up."""
    s = LOOP + FADE
    t = t_axis(s)
    out = wind(rng, s, 200, 1100, 0.85, rate=0.08) * 0.22
    howl = band(pink(rng, s, 2), 500, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.06 * t))[:, None]
    out += howl * 0.12
    out += band(noise(rng, s, 2), 4000, 9000) * 0.005        # blown snow
    out += murmur(rng, s, 0.1)
    tt = 3.0
    while tt < s - 3:                                        # the ice groans
        d = rng.uniform(0.8, 1.6)
        f0 = rng.uniform(70, 140)
        groan = chirp(rng, f0, f0 * rng.uniform(1.3, 1.8), d, warble=0.1, warble_rate=18, harm=0.8)
        place(out, band(groan, 50, 900), tt, rng.uniform(-0.8, 0.8), 0.06)
        tt += rng.uniform(5, 9)
    tt = 11.0
    while tt < s - 2:
        place(out, screech(rng, 2200), tt, rng.uniform(-0.9, 0.9), 0.035)
        tt += rng.uniform(13, 19)
    return reverb(out, rng, wet=0.3, seconds=2.2, decay=0.8, brightness=5000, stereo=True)


def beep(rng):
    f = rng.choice([880.0, 1046.5, 1318.5, 1760.0])
    d = rng.uniform(0.05, 0.1)
    return np.sin(2 * np.pi * f * t_axis(d)) * np.exp(-t_axis(d) / 0.08)


def amb_lab(rng):
    """LAB, indoors: the mains hum and the pumps, the tanks bubbling, the
    consoles beeping, a valve venting steam, the crowd in a hard room."""
    s = LOOP + FADE
    t = t_axis(s)
    hum = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((60, 1.0), (120, 0.5), (180, 0.25), (240, 0.12)))
    out = pan_stereo(hum, 0.0) * 0.05
    out += band(pink(rng, s, 2), 60, 300) * 0.08 * (0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * t))[:, None]
    out += murmur(rng, s, 0.15)
    tt = 0.0
    while tt < s - 0.1:
        place(out, bubble(rng), tt, rng.uniform(-0.5, 0.5), rng.uniform(0.02, 0.06))
        tt += rng.uniform(0.04, 0.3)
    tt = 0.7
    while tt < s - 1:
        for k in range(int(rng.integers(1, 4))):
            place(out, beep(rng), tt + k * 0.12, rng.uniform(-0.8, 0.8), 0.04)
        tt += rng.uniform(1.5, 4.5)
    tt = 9.0
    while tt < s - 3:
        d = 1.6
        hiss = band(noise(rng, d), 2000, 9000) * np.sin(np.pi * t_axis(d) / d) ** 0.5
        place(out, hiss, tt, rng.uniform(-0.7, 0.7), 0.05)
        tt += rng.uniform(10, 15)
    return reverb(out, rng, wet=0.35, seconds=1.0, decay=0.35, brightness=6000, stereo=True)


def amb_station(rng):
    """STATION, indoors: the engines' low drone, the air through the vents,
    the consoles' chirps, a door sighing open now and then."""
    s = LOOP + FADE
    t = t_axis(s)
    pad = np.zeros((len(t), 2))
    for f, pan in [(41.2, -0.3), (41.5, 0.3), (61.8, 0.0), (82.4, -0.2), (123.6, 0.2)]:
        pad += pan_stereo(np.sin(2 * np.pi * f * t) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.04 * t + f)), pan)
    out = pad * 0.06
    out += band(pink(rng, s, 2), 250, 2200) * 0.05            # the vents
    out += murmur(rng, s, 0.12)
    tt = 0.5
    while tt < s - 1:
        place(out, beep(rng) * 0.7, tt, rng.uniform(-0.9, 0.9), 0.035)
        tt += rng.uniform(1.0, 3.5)
    tt = 7.0
    while tt < s - 3:
        d = 0.9
        door = band(noise(rng, d), 600, 5000) * np.exp(-t_axis(d) / 0.3)
        door += modes(d, [(110, 0.3, 0.4)])
        place(out, door, tt, rng.uniform(-0.8, 0.8), 0.08)
        tt += rng.uniform(9, 14)
    return reverb(out, rng, wet=0.3, seconds=1.4, decay=0.5, brightness=5000, stereo=True)


AMBIENCE = {"ambience_park": amb_park, "ambience_lakeside": amb_lakeside,
            "ambience_sunset": amb_sunset, "ambience_dinosaur": amb_jungle,
            "ambience_space": amb_space, "ambience_undersea": amb_undersea,
            "ambience_gym": amb_gym, "ambience_ruins": amb_ruins, "ambience_glacier": amb_glacier,
            "ambience_lab": amb_lab, "ambience_station": amb_station}


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(np.square(x))) + 1e-12)


def report(name, x):
    peak = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
    a = x if x.ndim == 1 else x.mean(axis=1)
    spec = np.abs(np.fft.rfft(a))
    f = np.fft.rfftfreq(len(a), 1 / SR)
    centroid = float(np.sum(f * spec) / (np.sum(spec) + 1e-12))
    ch = 1 if x.ndim == 1 else 2
    print(f"{name:24s} {len(x) / SR:6.2f}s {ch}ch  peak {peak:6.1f} dBFS  rms {rms_db(x):6.1f} dBFS"
          f"  centroid {centroid:6.0f} Hz  dc {float(np.mean(a)):+.4f}")


def main():
    show = "--report" in sys.argv
    made = {}
    rng = np.random.default_rng(1994)
    for kind, stem in [("standard", "0_hit"), ("drive", "0_hit_drive"), ("soft", "0_hit_soft"),
                       ("slice", "0_hit_slice"), ("smash", "0_hit_smash")]:
        for v in range(4):
            made[f"{stem}{'' if v == 0 else '_' + str(v + 1)}"] = paddle_hit(np.random.default_rng(100 + v * 7 + len(stem)), kind)
    for v in range(3):
        made[f"1_bounce{'' if v == 0 else '_' + str(v + 1)}"] = court_bounce(np.random.default_rng(200 + v))
    made["2_net"] = net_hit(np.random.default_rng(300))
    made["3_whistle"] = whistle(np.random.default_rng(400))
    made["4_applause"] = applause(np.random.default_rng(500))
    made["5_blip"] = ui_tone(np.random.default_rng(600), [1046.5], 0.0, 0.035, 0.25)
    made["6_confirm"] = ui_tone(np.random.default_rng(601), [1046.5, 1568.0], 0.07, 0.07, 0.35)
    made["7_back"] = ui_tone(np.random.default_rng(602), [987.8, 659.3], 0.055, 0.05, 0.25)
    # ADR-077: an achievement, a rising C major arpeggio to the octave
    made["8_achievement"] = ui_tone(np.random.default_rng(603), [1046.5, 1318.5, 1568.0, 2093.0],
                                    0.075, 0.12, 0.4)
    for name, fn in AMBIENCE.items():
        a = seamless(fn(np.random.default_rng(700 + len(name))))
        a = a - np.mean(a, axis=0)
        made[name] = a / (np.sqrt(np.mean(np.square(a))) + 1e-12) * db(-24) # every loop at -24 dBFS RMS
        made[name] = np.clip(made[name], -db(-1), db(-1))
    for name, x in made.items():
        write(name, x)
        if show:
            report(name, x)
    print(f"wrote {len(made)} files to {OUT}")


if __name__ == "__main__":
    main()
