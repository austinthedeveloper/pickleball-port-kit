"""The Godot port's soundtrack (PORT-22, ADR-052): the SNES game never had
music (ADR-029/031, M4-AUDIO-03), so this is new, and original.

Everything is composed and synthesized here, with numpy only and fixed
seeds, like the HD effects (../hd-sfx/make_sfx.py): no recorded or
third-party audio. A small note sequencer reads the parts written below
(melodies as note:beats text, chords as symbols, bass, arpeggio, comp and
drum parts as 16-step strings, one per bar) and plays them on simple voices:
  * band-limited additive oscillators (saw, square, pulse, triangle) with a
    resonant low-pass applied per harmonic, so a filter can sweep per note
    without aliasing: the bass, the leads and the brass;
  * wavetables for the long pad notes (detuned saws, a slow filter wobble);
  * two-operator FM for the electric piano and the bells, modal partials
    for the marimba;
  * drums from swept sines and shaped noise (kick, snare, rim, clap, hats,
    shaker, toms, crash);
  * a dotted-eighth ping-pong echo (the SNES's echo, in stereo) and a
    convolution reverb with a synthesized hall; the pads duck under the kick.
Loops are 48 kHz stereo and seamless: everything is mixed circularly (a
note or reverb tail that runs past the end sounds at the start), so the
last sample leads into the first. Stingers are one-shots with their tails.

    .venv/bin/python audio/music/make_music.py           # writes audio/music/out
    .venv/bin/python audio/music/make_music.py --report  # and prints levels
    .venv/bin/python audio/music/make_music.py title     # just one track
"""
import sys
import wave
from fractions import Fraction
from pathlib import Path

import numpy as np

SR = 48000
OUT = Path(__file__).resolve().parent / "out"
TAU = 2 * np.pi


# --- building blocks -------------------------------------------------------------

def db(x):
    return 10 ** (x / 20.0)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'F#5', 'Bb4', 'C6' -> MIDI note number (C4 = 60)."""
    i, acc = 1, 0
    while i < len(name) and name[i] in "#b":
        acc += 1 if name[i] == "#" else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + NOTE[name[0]] + acc


def gain_curve(x, lo, hi, order=2):
    """A smooth band-pass's magnitude at frequencies x (lo=0: low-pass)."""
    g = np.ones_like(x)
    if lo:
        g = g / np.sqrt(1 + (lo / np.maximum(x, 1e-6)) ** (2 * order))
    if hi:
        g = g / np.sqrt(1 + (x / hi) ** (2 * order))
    return g


def band(x, lo, hi, order=2, circular=False):
    """A band-pass applied by FFT (zero phase). `circular` filters a loop
    as a loop (no padding, so the seam stays seamless)."""
    n = x.shape[0]
    size = n if circular else 1 << (2 * n - 1).bit_length()
    spec = np.fft.rfft(x, size, axis=0)
    g = gain_curve(np.fft.rfftfreq(size, 1 / SR), lo, hi, order)
    if spec.ndim == 2:
        g = g[:, None]
    return np.fft.irfft(spec * g, size, axis=0)[:n]


def env(n_on, attack, decay, sustain, release, total=None):
    """An ADSR over n_on held samples then the release (time constants in
    seconds; the release runs for 5 of them, or to `total` samples)."""
    rel = int(release * 5 * SR)
    n = total if total is not None else n_on + rel
    t = np.arange(n) / SR
    on = n_on / SR
    a = np.where(t < attack, t / max(attack, 1e-6),
                 sustain + (1 - sustain) * np.exp(-(t - attack) / max(decay, 1e-6)))
    at_off = a[min(n_on, n - 1)] if n_on < n else a[-1]
    out = np.where(t < on, a, at_off * np.exp(-(t - on) / max(release, 1e-6)))
    k = min(n, int(0.004 * SR))
    out[n - k:] *= np.linspace(1, 0, k)          # lands on zero
    return out


def harmonic_amps(wave_, k, pw=0.5):
    k = np.asarray(k, dtype=float)
    if wave_ == "saw":
        return 1 / k
    if wave_ == "square":
        return np.where(k % 2 == 1, 1 / k, 0.0)
    if wave_ == "pulse":
        return 2 * np.sin(np.pi * k * pw) / (np.pi * k) * np.pi / 2
    if wave_ == "tri":
        return np.where(k % 2 == 1, (-1) ** ((k - 1) // 2) / k ** 2, 0.0)
    raise ValueError(wave_)


def lp_resp(x, res):
    """A 4-pole-like low-pass at x = f / cutoff, with a resonant bump."""
    return 1 / np.sqrt(1 + x ** 4) + res * np.exp(-((x - 1) / 0.22) ** 2)


def osc(f_t, wave_, pw=0.5, cutoff=None, res=0.0, phase=0.0, maxk=48):
    """A band-limited oscillator by additive synthesis. `f_t` is the
    frequency per sample (vibrato, glides); `cutoff` (Hz, scalar or per
    sample) filters each harmonic, so it can sweep without aliasing."""
    ph = TAU * np.cumsum(f_t) / SR + phase
    fmax = float(np.max(f_t))
    k_max = int(min(maxk, SR * 0.45 / fmax))
    if cutoff is not None:
        k_max = min(k_max, int(np.max(cutoff) * 5 / float(np.min(f_t))) + 1)
    out = np.zeros_like(ph)
    for k, a in zip(range(1, k_max + 1), harmonic_amps(wave_, np.arange(1, k_max + 1), pw)):
        if a == 0:
            continue
        if cutoff is None:
            out += a * np.sin(k * ph)
        else:
            out += a * lp_resp(k * f_t / cutoff, res) * np.sin(k * ph)
    return out


def table_osc(f_t, amps, phase=0.0, size=4096):
    """A wavetable oscillator (one band-limited cycle, interpolated): cheap
    for long notes with a fixed tone."""
    th = np.arange(size + 1) / size * TAU
    table = np.zeros(size + 1)
    for k, a in enumerate(amps, 1):
        table += a * np.sin(k * th)
    pos = (np.cumsum(f_t) / SR + phase / TAU) % 1.0 * size
    return np.interp(pos, np.arange(size + 1), table)


def vibrato(n, depth_cents, rate, delay, phase=0.0):
    t = np.arange(n) / SR
    ramp = np.clip((t - delay) / 0.3, 0, 1)
    return 2 ** (depth_cents * ramp * np.sin(TAU * rate * t + phase) / 1200)


def cents(c):
    return 2 ** (c / 1200)


# --- voices: each returns a mono note (or (n, 2) for stereo voices) --------------

def v_bass(m, dur, vel, rng, bright=1.0):
    f = hz(m)
    n_on = int(dur * SR)
    e = env(n_on, 0.003, 0.22, 0.72, 0.025)
    n = len(e)
    t = np.arange(n) / SR
    cut = f * 1.6 + (500 + 1500 * vel) * bright * np.exp(-t / 0.075)
    f_t = np.full(n, f)
    saw = osc(f_t, "saw", cutoff=cut, res=0.35, phase=rng.uniform(0, TAU))
    sq = osc(f_t, "square", cutoff=cut * 0.7, phase=rng.uniform(0, TAU))
    sub = np.sin(TAU * f * t)
    return (0.5 * saw + 0.35 * sq + 0.75 * sub) * e * vel


def v_lead(m, dur, vel, rng, pw=0.25, bright=3800, detune=0.0, vib=14):
    f = hz(m) * cents(detune)
    e = env(int(dur * SR), 0.006, 0.35, 0.78, 0.07)
    n = len(e)
    t = np.arange(n) / SR
    f_t = f * vibrato(n, vib, 5.6, 0.16, rng.uniform(0, TAU))
    cut = bright * (0.65 + 0.35 * np.exp(-t / 0.25)) * (0.7 + 0.3 * vel)
    return osc(f_t, "pulse", pw=pw, cutoff=cut, res=0.15, phase=rng.uniform(0, TAU)) * e * vel


def v_whistle(m, dur, vel, rng):
    """A square-ish whistle lead (the park's), short and bouncy."""
    f = hz(m)
    e = env(int(dur * SR), 0.004, 0.12, 0.55, 0.05)
    n = len(e)
    f_t = f * vibrato(n, 10, 6.2, 0.12, rng.uniform(0, TAU))
    tone = osc(f_t, "square", cutoff=2600 + 1800 * vel, res=0.1, phase=rng.uniform(0, TAU))
    tone += 0.5 * np.sin(TAU * np.cumsum(f_t) / SR)
    return tone * e * vel


def v_flute(m, dur, vel, rng):
    f = hz(m)
    e = env(int(dur * SR), 0.045, 0.4, 0.85, 0.09)
    n = len(e)
    f_t = f * vibrato(n, 16, 5.0, 0.22, rng.uniform(0, TAU))
    ph = TAU * np.cumsum(f_t) / SR
    tone = np.sin(ph) + 0.22 * np.sin(2 * ph + 0.3) + 0.07 * np.sin(3 * ph + 1.1)
    breath = band(rng.standard_normal(n), f * 1.2, f * 4, order=2)
    breath *= 0.12 / (np.std(breath) + 1e-9) * (0.4 + 0.6 * np.exp(-np.arange(n) / SR / 0.08))
    return (tone + breath) * e * vel


def v_mellow(m, dur, vel, rng):
    """A soft, round synth lead (the sunset's): triangle and a dark saw."""
    f = hz(m)
    e = env(int(dur * SR), 0.03, 0.5, 0.8, 0.12)
    n = len(e)
    f_t = f * vibrato(n, 12, 4.8, 0.25, rng.uniform(0, TAU))
    tone = osc(f_t, "tri") + 0.35 * osc(f_t, "saw", cutoff=f * 3, phase=rng.uniform(0, TAU))
    return tone * e * vel


def v_brass(m, dur, vel, rng, swell=0.05):
    """Fanfare brass: three detuned saws through a swelling filter."""
    f = hz(m)
    e = env(int(dur * SR), 0.018, 0.4, 0.85, 0.12)
    n = len(e)
    t = np.arange(n) / SR
    cut = f * 1.3 + 3200 * vel * (1 - np.exp(-t / swell)) * (0.7 + 0.3 * np.exp(-t / 0.5))
    out = np.zeros(n)
    for c in (-7, 0, 6):
        f_t = f * cents(c) * vibrato(n, 8, 5.2, 0.3, rng.uniform(0, TAU))
        out += osc(f_t, "saw", cutoff=cut, res=0.2, phase=rng.uniform(0, TAU), maxk=36)
    return out / 3 * e * vel


def v_pad(m, dur, vel, rng, cutoff=1100, attack=0.45, release=0.6, voices=(-9, 0, 8)):
    """Detuned saws spread across the stereo field, with a slow filter
    wobble (two wavetables, dark and bright, crossfaded)."""
    f = hz(m)
    e = env(int(dur * SR), attack, 1.2, 0.85, release)
    n = len(e)
    t = np.arange(n) / SR
    k = np.arange(1, int(min(40, SR * 0.45 / f)) + 1)
    dark = harmonic_amps("saw", k) * lp_resp(k * f / (cutoff * 0.7), 0.1)
    bright = harmonic_amps("saw", k) * lp_resp(k * f / (cutoff * 1.4), 0.1)
    wob = 0.5 + 0.5 * np.sin(TAU * 0.17 * t + rng.uniform(0, TAU))
    out = np.zeros((n, 2))
    pans = np.linspace(-0.6, 0.6, len(voices))
    for c, p in zip(voices, pans):
        f_t = np.full(n, f * cents(c))
        ph = rng.uniform(0, TAU)
        s = (1 - wob) * table_osc(f_t, dark, ph) + wob * table_osc(f_t, bright, ph)
        a = (p + 1) * np.pi / 4
        out[:, 0] += s * np.cos(a) * np.sqrt(2)
        out[:, 1] += s * np.sin(a) * np.sqrt(2)
    return out / len(voices) * (e * vel)[:, None]


def v_epiano(m, dur, vel, rng, warm=1.0):
    """A two-operator FM electric piano, with its tine's ping."""
    f = hz(m)
    n_on = int(dur * SR)
    n = n_on + int(0.6 * SR)
    t = np.arange(n) / SR
    idx = (0.35 + 1.5 * vel / warm) * np.exp(-t / 0.5) + 0.2
    body = np.sin(TAU * f * t + idx * np.sin(TAU * f * t))
    tine = 0.12 * vel * np.sin(TAU * f * 14 * t) * np.exp(-t / 0.035) if f * 14 < 18000 else 0
    amp = np.exp(-t / 2.2)
    rel = np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.12))
    k = int(0.004 * SR)
    rel[-k:] *= np.linspace(1, 0, k)
    att = np.clip(t / 0.002, 0, 1)
    return (body + tine) * amp * rel * att * vel


def v_bell(m, dur, vel, rng, ratio=3.5, decay=1.1):
    """A celesta-like FM bell."""
    f = hz(m)
    n = int((max(dur, 0.2) + decay * 2.5) * SR)
    t = np.arange(n) / SR
    idx = 1.8 * vel * np.exp(-t / 0.35)
    s = np.sin(TAU * f * t + idx * np.sin(TAU * f * ratio * t))
    s *= np.exp(-t / decay) * np.clip(t / 0.0015, 0, 1)
    k = int(0.004 * SR)
    s[-k:] *= np.linspace(1, 0, k)
    return s * vel


def v_marimba(m, dur, vel, rng):
    f = hz(m)
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    s = np.sin(TAU * f * t) * np.exp(-t / 0.32)
    s += 0.28 * np.sin(TAU * f * 3.93 * t) * np.exp(-t / 0.08)
    s += 0.08 * np.sin(TAU * f * 9.2 * t) * np.exp(-t / 0.018)
    s *= np.clip(t / 0.0012, 0, 1)
    k = int(0.004 * SR)
    s[-k:] *= np.linspace(1, 0, k)
    return s * vel


# --- drums -----------------------------------------------------------------------

def _shaped(rng, seconds, lo, hi, decay, attack=0.0005, order=2):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    x = band(rng.standard_normal(n), lo, hi, order)
    x /= np.std(x) + 1e-9
    e = np.exp(-t / decay) * np.clip(t / attack, 0, 1)
    k = int(0.003 * SR)
    e[-k:] *= np.linspace(1, 0, k)
    return x * e


def d_kick(rng):
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 46 + 120 * np.exp(-t / 0.032)
    body = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.22)
    click = 0.25 * _shaped(rng, 0.42, 1500, 7000, 0.004)
    s = np.tanh(1.6 * (body + click)) / np.tanh(1.6)
    s[-200:] *= np.linspace(1, 0, 200)
    return s


def d_snare(rng):
    t = np.arange(int(0.34 * SR)) / SR
    tone = (0.6 * np.sin(TAU * 188 * t) + 0.3 * np.sin(TAU * 336 * t)) * np.exp(-t / 0.05)
    return 0.8 * tone + 0.5 * _shaped(rng, 0.34, 1400, 9000, 0.11)


def d_rim(rng):
    t = np.arange(int(0.12 * SR)) / SR
    tone = np.sin(TAU * 1720 * t) * np.exp(-t / 0.012)
    return 0.6 * tone + 0.45 * _shaped(rng, 0.12, 2000, 6000, 0.007)


def d_clap(rng):
    x = np.zeros(int(0.32 * SR))
    for i, at in enumerate((0.0, 0.009, 0.018, 0.026)):
        burst = _shaped(rng, 0.32 - at, 900, 5000, 0.006 if i < 3 else 0.09)
        j = int(at * SR)
        x[j:j + len(burst)] += burst * (0.7 if i < 3 else 0.9)
    return x * 0.6


def _metal(rng, seconds):
    """Six square waves at inharmonic ratios (a classic drum machine's cymbal)."""
    t = np.arange(int(seconds * SR)) / SR
    m = sum(np.sign(np.sin(TAU * f * t + rng.uniform(0, TAU)))
            for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0))
    return m / 6


def d_hat(rng, open_=False):
    sec = 0.45 if open_ else 0.09
    t = np.arange(int(sec * SR)) / SR
    x = 0.6 * _metal(rng, sec) + 0.5 * rng.standard_normal(len(t))
    x = band(x, 7000, 16000, order=3)
    x /= np.std(x) + 1e-9
    e = np.exp(-t / (0.13 if open_ else 0.022))
    e[-200:] *= np.linspace(1, 0, 200)
    return x * e * 0.5


def d_shaker(rng):
    return 0.35 * _shaped(rng, 0.11, 5000, 13000, 0.035, attack=0.008)


def d_tom(rng, f0=130):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.5 * np.exp(-t / 0.03))
    s = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / 0.2)
    s += 0.15 * _shaped(rng, 0.5, 300, 3000, 0.03)
    s[-200:] *= np.linspace(1, 0, 200)
    return s


def d_crash(rng):
    sec = 2.6
    t = np.arange(int(sec * SR)) / SR
    x = 0.5 * _metal(rng, sec) + rng.standard_normal(len(t))
    x = band(x, 3500, 15000, order=2)
    x /= np.std(x) + 1e-9
    e = np.exp(-t / 0.9) * np.clip(t / 0.002, 0, 1)
    e[-400:] *= np.linspace(1, 0, 400)
    return x * e * 0.4


DRUMS = {"kick": d_kick, "snare": d_snare, "rim": d_rim, "clap": d_clap,
         "hat": d_hat, "ohat": lambda r: d_hat(r, True), "shaker": d_shaker,
         "tom": d_tom, "tomlo": lambda r: d_tom(r, 92), "crash": d_crash}
DRUM_PAN = {"kick": 0.0, "snare": 0.05, "rim": -0.15, "clap": 0.1, "hat": 0.3, "ohat": 0.3,
            "shaker": -0.35, "tom": 0.25, "tomlo": -0.2, "crash": -0.25}
HIT = {"X": 1.0, "x": 0.8, "o": 0.5, "-": 0.3}


# --- harmony ---------------------------------------------------------------------

QUALITY = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10],
           "maj7": [0, 4, 7, 11], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9],
           "sus4": [0, 5, 7], "7sus4": [0, 5, 7, 10], "add9": [0, 4, 7, 14],
           "maj9": [0, 4, 7, 11, 14], "m9": [0, 3, 7, 10, 14], "9": [0, 4, 7, 10, 14],
           "dim": [0, 3, 6], "m7b5": [0, 3, 6, 10]}


def chord(sym):
    """'F#m7', 'Bbmaj9', 'A/C#' -> {root, tones (semitones), bass} pitch classes."""
    main, _, slash = sym.partition("/")
    i = 2 if len(main) > 1 and main[1] in "#b" else 1
    root = (NOTE[main[0]] + (1 if main[1:2] == "#" else -1 if main[1:2] == "b" else 0)) % 12
    tones = QUALITY[main[i:]]
    bass = root
    if slash:
        bass = (NOTE[slash[0]] + (1 if slash[1:2] == "#" else -1 if slash[1:2] == "b" else 0)) % 12
    return {"root": root, "tones": tones, "bass": bass, "name": sym}


def progression(text):
    """'D Bm G:2 A:2 ...' -> [(start beat, beats, chord)]; a bar is 4 beats."""
    out, beat = [], 0.0
    for tok in text.split():
        sym, _, beats = tok.partition(":")
        b = float(Fraction(beats)) if beats else 4.0
        out.append((beat, b, chord(sym)))
        beat += b
    return out


def chord_at(prog, beat):
    for start, beats, c in prog:
        if start <= beat + 1e-6 < start + beats:
            return c
    return prog[-1][2]


def next_chord(prog, beat):
    for start, _, c in prog:
        if start > beat + 1e-6:
            return c
    return prog[0][2]


def voicing(c, center=62, top_extensions=True):
    """Close-position voicing of a chord's tones nearest `center`."""
    pcs = [(c["root"] + t) % 12 for t in c["tones"]]
    best, best_cost = None, 1e9
    for low in range(center - 10, center + 3):
        notes = []
        for pc in pcs:
            n = low + (pc - low) % 12
            notes.append(n)
        notes.sort()
        cost = abs(np.mean(notes) - center) + (notes[-1] - notes[0]) * 0.15
        if cost < best_cost:
            best, best_cost = notes, cost
    return best


def melody(text):
    """'D5:.75 F#5:.75 r:1 ...' -> [(beat, beats, midi or None, vel)]. A
    trailing ! accents a note, ? softens it; durations may be fractions."""
    out, beat = [], 0.0
    for tok in text.split():
        vel = 0.8
        if tok.endswith("!"):
            vel, tok = 1.0, tok[:-1]
        elif tok.endswith("?"):
            vel, tok = 0.55, tok[:-1]
        name, _, beats = tok.partition(":")
        b = float(Fraction(beats)) if beats else 1.0
        out.append((beat, b, None if name == "r" else midi(name), vel))
        beat += b
    return out


def bars_long(notes, bars):
    """Checks a melody fills whole bars (a typo in a duration shows here)."""
    end = notes[-1][0] + notes[-1][1]
    assert abs(end - bars * 4) < 1e-6, f"melody is {end} beats, not {bars * 4}"
    return notes


# --- the mixer -------------------------------------------------------------------

class Song:
    """A piece being rendered: buses of stereo audio (circular when it
    loops), a tempo, and the parts' helpers."""

    def __init__(self, bpm, bars, seed, loop=True, tail=0.0, swing=0.0):
        self.spb = 60.0 / bpm
        self.beats = bars * 4
        self.n_loop = int(round(self.beats * self.spb * SR))
        self.loop = loop
        self.n = self.n_loop if loop else self.n_loop + int(tail * SR)
        self.rng = np.random.default_rng(seed)
        self.swing = swing
        self.buses = {}
        self.sends = {}                     # bus -> (reverb, echo)
        self.kicks = []
        self.drum_kits = {}

    def time(self, beat, human=0.004):
        frac = beat % 0.5
        if abs(frac - 0.25) < 1e-6:
            beat += self.swing             # swung sixteenths
        return beat * self.spb + self.rng.uniform(-human, human)

    def bus(self, name, reverb=0.2, echo=0.0):
        if name not in self.buses:
            self.buses[name] = np.zeros((self.n, 2))
            self.sends[name] = (reverb, echo)
        return self.buses[name]

    def add(self, name, sig, t, pan=0.0, gain=1.0):
        buf = self.bus(name)
        if sig.ndim == 1:
            a = (pan + 1) * np.pi / 4
            sig = np.stack([sig * np.cos(a), sig * np.sin(a)], axis=1) * np.sqrt(2)
        elif pan:
            sig = sig * np.array([min(1, 1 - pan), min(1, 1 + pan)])
        sig = sig * gain
        i = int(round(t * SR))
        if self.loop:
            i %= self.n
            while len(sig):
                k = min(len(sig), self.n - i)
                buf[i:i + k] += sig[:k]
                sig = sig[k:]
                i = 0
        else:
            i = max(i, 0)
            k = min(len(sig), self.n - i)
            if k > 0:
                buf[i:i + k] += sig[:k]

    def vel(self, v, spread=0.06):
        return float(np.clip(v * (1 + self.rng.uniform(-spread, spread)), 0.05, 1.0))

    # parts

    def notes(self, bus, voice, notes, at_bar=0, transpose=0, pan=0.0, gain=1.0, gate=0.92, **kw):
        for beat, beats, m, v in notes:
            if m is None:
                continue
            b = at_bar * 4 + beat
            sig = voice(m + transpose, beats * self.spb * gate, self.vel(v), self.rng, **kw)
            self.add(bus, sig, self.time(b), pan, gain)

    def pads(self, bus, prog, voice=v_pad, center=62, gain=1.0, vel=0.7, **kw):
        for start, beats, c in prog:
            for m in voicing(c, center):
                sig = voice(m, beats * self.spb, self.vel(vel, 0.03), self.rng, **kw)
                self.add(bus, sig, self.time(start, 0.0), 0.0, gain)

    def steps(self, bars, beat0=0.0):
        """Walks 16-step patterns, one string per bar: yields (beat, char,
        length in beats to the next event or rest)."""
        for b, pat in enumerate(bars):
            pat = pat.replace(" ", "")
            for s, ch in enumerate(pat):
                if ch in ".-":
                    continue
                length = 1
                while s + length < len(pat) and pat[s + length] == "-":
                    length += 1
                yield beat0 + b * 4 + s * 0.25, ch, length * 0.25

    def bass(self, bus, prog, bars, voice=v_bass, low=33, gain=1.0, gate=0.85, **kw):
        """Bass steps: R root (or the slash bass), O octave, 5 fifth, 3 third,
        7 seventh, L the fifth below, a a chromatic approach to the next chord."""
        for beat, ch, length in self.steps(bars):
            c = chord_at(prog, beat)
            r = low + (c["bass"] - low) % 12
            third = next((t for t in c["tones"] if t in (3, 4)), 4)
            sev = next((t for t in c["tones"] if t in (10, 11)), 10)
            nxt = next_chord(prog, beat)
            m = {"R": r, "O": r + 12, "5": r + 7, "3": r + third, "7": r + sev, "L": r - 5,
                 "a": low + (nxt["bass"] - low) % 12 - 1}[ch]
            sig = voice(m, length * self.spb * gate, self.vel(0.85), self.rng, **kw)
            self.add(bus, sig, self.time(beat, 0.002), 0.0, gain)

    def arp(self, bus, prog, bars, voice, center=72, gain=1.0, pan=0.0, gate=0.9, vel=0.7, **kw):
        """Arpeggio steps: digits index the chord's tones upwards from its
        voicing around `center`."""
        for beat, ch, length in self.steps(bars):
            v = voicing(chord_at(prog, beat), center)
            i = int(ch)
            m = v[i % len(v)] + 12 * (i // len(v))
            sig = voice(m, length * self.spb * gate, self.vel(vel), self.rng, **kw)
            self.add(bus, sig, self.time(beat), pan, gain)

    def comp(self, bus, prog, bars, voice, center=62, gain=1.0, gate=0.9, vel=0.65, spread=0.012, **kw):
        """Chord stabs: x (or X accented, o soft) plays the whole voicing,
        lightly strummed; '-' holds it."""
        for beat, ch, length in self.steps(bars):
            notes = voicing(chord_at(prog, beat), center)
            for j, m in enumerate(notes):
                sig = voice(m, length * self.spb * gate, self.vel(vel * HIT.get(ch, 0.8) / 0.8), self.rng, **kw)
                self.add(bus, sig, self.time(beat) + j * spread, (j / max(1, len(notes) - 1) - 0.5) * 0.5, gain)

    def drums(self, bus, bars, kit, gain=1.0, at_bar=0):
        """`bars`: [{instrument: 16-step string}], one dict per bar."""
        for b, parts in enumerate(bars):
            for inst, pat in parts.items():
                for beat, ch, _ in self.steps([pat], (at_bar + b) * 4):
                    self.hit(bus, inst, beat, HIT.get(ch, 0.8), kit.get(inst, 1.0) * gain)

    def hit(self, bus, inst, beat, vel, gain=1.0):
        kits = self.drum_kits.setdefault(inst, [DRUMS[inst](np.random.default_rng(900 + i * 31 + len(inst)))
                                                for i in range(4)])
        sig = kits[int(self.rng.integers(len(kits)))]
        t = self.time(beat, 0.002)
        if inst == "kick":
            self.kicks.append(t)
        self.add(bus, sig, t, DRUM_PAN[inst], gain * self.vel(vel))

    # the mix

    def sidechain(self, name, depth=0.35, release=0.18):
        """Ducks a bus under the kick (a modern pump, gently)."""
        if name not in self.buses or not self.kicks:
            return
        n = self.n
        g = np.zeros(n)
        k = int(release * 5 * SR)
        shape = np.exp(-np.arange(k) / SR / release)
        for t in self.kicks:
            i = int(round(t * SR)) % n if self.loop else int(round(t * SR))
            idx = np.arange(i, i + k)
            idx = idx % n if self.loop else idx[idx < n]
            g[idx] = np.maximum(g[idx], shape[:len(idx)])
        self.buses[name] *= (1 - depth * g)[:, None]

    def render(self, rt60=1.8, echo_beats=0.75, echo_fb=0.38, seed=7, target_rms=-18.0):
        dry = sum(self.buses.values())
        rev_in = sum(b * self.sends[k][0] for k, b in self.buses.items())
        echo_in = sum(b * self.sends[k][1] for k, b in self.buses.items())
        wet = reverb(rev_in, rt60, np.random.default_rng(seed), self.loop)
        if np.any(echo_in):
            wet = wet + echo(echo_in, echo_beats * self.spb, echo_fb, self.loop)
        mixed = dry + wet
        mixed = band(mixed, 28, None, order=2, circular=self.loop)
        mixed -= mixed.mean(axis=0)
        return master(mixed, target_rms)


def reverb(x, rt60, rng, circular):
    """Convolution with a synthesized hall: early reflections, then
    decorrelated noise per channel that decays (faster in the highs)."""
    sec = min(rt60 * 1.4, 3.0)
    n = int(sec * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for ch in range(2):
        lo = band(rng.standard_normal(n), 0, 2500, order=2)
        hi = band(rng.standard_normal(n), 2500, 9000, order=2)
        tail = lo * np.exp(-6.9 * t / rt60) + 0.6 * hi * np.exp(-6.9 * t / (rt60 * 0.45))
        tail *= np.clip((t - 0.012) / 0.02, 0, 1)                    # pre-delay
        for at, g in ((0.011, 0.5), (0.019, 0.35), (0.027, 0.3), (0.041, 0.22)):
            j = int((at + ch * 0.0023) * SR)
            ir[j, ch] += g * (1 if (j + ch) % 2 else -1)
        ir[:, ch] += tail * 0.02
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    m = x.shape[0]
    size = m if circular else 1 << (m + n).bit_length()
    out = np.zeros((m, 2))
    for ch in range(2):
        y = np.fft.irfft(np.fft.rfft(x[:, ch], size) * np.fft.rfft(ir[:, ch], size), size)
        out[:, ch] = y[:m]
    return band(out, 180, 9000, order=2, circular=circular) * 0.5


def echo(x, delay, fb, circular, taps=7):
    """A ping-pong echo: repeats alternate left and right, each darker."""
    mono = x.mean(axis=1)
    d = int(round(delay * SR))
    out = np.zeros_like(x)
    m = len(mono)
    for i in range(1, taps + 1):
        tap = band(mono, 250, 5200 / (1 + 0.35 * i), order=1, circular=circular) if circular \
            else band(mono, 250, 5200 / (1 + 0.35 * i), order=1)
        if circular:
            tap = np.roll(tap, i * d)
        else:
            tap = np.concatenate([np.zeros(min(i * d, m)), tap])[:m]
        out[:, (i - 1) % 2] += tap * fb ** (i - 1) * 0.6
    return out


def master(x, target_rms):
    """Level to a target RMS, then a soft knee keeps peaks under -1 dBFS."""
    x = x / (np.sqrt(np.mean(x ** 2)) + 1e-12) * db(target_rms)
    th, ceil = db(-6), db(-1)
    a = np.abs(x)
    over = a > th
    y = x.copy()
    y[over] = np.sign(x[over]) * (th + (ceil - th) * np.tanh((a[over] - th) / (ceil - th)))
    return y


def fade_out(x, seconds):
    k = int(seconds * SR)
    x = x.copy()
    x[-k:] *= np.linspace(1, 0, k)[:, None] ** 2
    return x


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(len(name))
    dither = (rng.uniform(-0.5, 0.5, x.shape) + rng.uniform(-0.5, 0.5, x.shape)) / 32767
    pcm = np.clip(np.round((x + dither) * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# --- the tracks ------------------------------------------------------------------

def bars_of(*pairs):
    """('pattern', count), ... -> a list with each pattern repeated."""
    out = []
    for pat, count in pairs:
        out += [pat] * count
    return out


def title():
    """The title theme: bright and upbeat, D major, 132 BPM, 16 bars. A
    pulse-wave lead with the echo, a bell doubling it in the second half,
    a driving bass, saw pads, and a kit with fills into each half."""
    s = Song(132, 16, seed=101)
    prog = progression("D Bm G A D Bm Em7 A7 Gmaj7 A6 F#m7 Bm7 Em7 F#m7 G A7sus4:2 A7:2")
    a = melody("D5:3/4! F#5:3/4 A5:1/2 B5:1/2 A5:1/2 F#5:1 "
               "F#5:1/2 E5:1/2 D5:1/2 E5:1 F#5:1/2 D5:1 "
               "G5:3/4! B5:3/4 D6:1/2 B5:1/2 A5:1/2 G5:1 "
               "A5:3/2 G5:1/2 F#5:1/2 E5:1/2 C#5:1 "
               "D5:3/4! F#5:3/4 A5:1/2 B5:1/2 A5:1/2 D6:1 "
               "C#6:1/2 B5:1/2 A5:1/2 F#5:1 A5:1/2 B5:1 "
               "G5:3/4 F#5:3/4 E5:1/2 D5:1/2 E5:1/2 G5:1 "
               "F#5:1/2 E5:1/2 C#5:1/2 E5:1/2 A5:2")
    b = melody("B5:3/2! A5:1/2 F#5:1 D5:1 E5:3/2 F#5:1/2 E5:1 C#5:1 "
               "A5:3/2! C#6:1/2 A5:1 F#5:1 B5:3 r:1/2 A5:1/2 "
               "G5:3/2 F#5:1/2 E5:1 G5:1 A5:3/2 G5:1/2 F#5:1 A5:1 "
               "B5:1/2 A5:1/2 G5:1/2 B5:1/2 D6:1! C#6:1/2 B5:1/2 A5:5/2 r:1/2 A4:1/2 C#5:1/2")
    bars_long(a, 8), bars_long(b, 8)
    s.bus("lead", reverb=0.25, echo=0.32)
    for det, pan in ((-6, -0.22), (6, 0.22)):
        s.notes("lead", v_lead, a, 0, pan=pan, gain=0.32, detune=det)
        s.notes("lead", v_lead, b, 8, pan=pan, gain=0.32, detune=det, pw=0.33)
    s.bus("bell", reverb=0.4, echo=0.25)
    s.notes("bell", v_bell, b, 8, transpose=12, gain=0.13, pan=0.3)
    s.bus("pads", reverb=0.35)
    s.pads("pads", prog, center=62, gain=0.2)
    s.bus("bass", reverb=0.04)
    s.bass("bass", prog, bars_of(("R-R-O-R-R-R-O-5a", 15), ("R-R-O-R-R-5-O-5a", 1)), gain=0.55)
    s.bus("arp", reverb=0.3, echo=0.2)
    s.arp("arp", prog, bars_of(("0.1.2.1.0.1.2.3.", 8), ("....2.1.....2.3.", 8)), v_marimba,
          center=74, gain=0.14, pan=-0.35)
    groove = {"kick": "X.....x.X..x....", "snare": "....X.......X...",
              "hat": "x.x.x.x.x.x.x...", "ohat": "..............x."}
    lift = dict(groove, shaker="oxoxoxoxoxoxoxox")
    fill = {"kick": "X.....x.X.......", "snare": "....X...X.x.XxXX", "hat": "x.x.x.x........."}
    s.bus("drums", reverb=0.12)
    bars = [groove] * 7 + [fill] + [lift] * 7 + [fill]
    s.drums("drums", bars, {"kick": 0.75, "snare": 0.42, "hat": 0.16, "ohat": 0.12, "shaker": 0.12})
    for bar in (0, 8):
        s.hit("drums", "crash", bar * 4, 0.9, 0.22)
    s.sidechain("pads", 0.4)
    return s.render(rt60=1.9, target_rms=-17.0)


def match_park():
    """Under play at the park: a laid-back F major groove, 100 BPM, softly
    swung. Electric piano comping, a round bass, rim and brushes, a light
    bell answer; the flute only joins in the second half."""
    s = Song(100, 16, seed=202, swing=0.04)
    prog = progression("Fmaj7 Em7:2 A7:2 Dm7 Cm7:2 F7:2 Bbmaj7 Am7 Gm7 C7sus4 "
                       "Fmaj7 Em7:2 A7:2 Dm7 Cm7:2 F7:2 Bbmaj7 Bbm6 Am7:2 D7:2 Gm7:2 C7:2")
    s.bus("keys", reverb=0.3)
    s.comp("keys", prog, bars_of(("x--.--x-.x--.-..", 15), ("x--.--x-x--.x-..", 1)),
           v_epiano, center=63, gain=0.2)
    s.bus("bass", reverb=0.05)
    s.bass("bass", prog, bars_of(("R--.-.R.5-.O.R..", 7), ("R--.-.R.5-.3.R.a", 1),
                                 ("R--.-.R.5-.O.R..", 7), ("R--.R.5.R--.5.a.", 1)),
           gain=0.55, bright=0.7)
    s.bus("pads", reverb=0.4)
    s.pads("pads", prog, center=60, gain=0.09, cutoff=800)
    fl = melody("r:1 A5:1/2 C6:1/2 E6:3/2 r:1/2 "
                "D6:1 B5:1/2 G5:1/2 A5:3/2 r:1/2 "
                "r:1/2 F5:1/2 A5:1/2 C6:1/2 D6:1 C6:1/2 A5:1/2 "
                "Bb5:1 G5:1/2 Eb5:1/2 A5:3/2 r:1/2 "
                "D6:3/2 C6:1/2 A5:1 F5:1 "
                "Db6:3/2 C6:1/2 Bb5:1 G5:1 "
                "C6:1 A5:1/2 E5:1/2 F#5:1 A5:1 "
                "G5:1 Bb5:1/2 A5:1/2 G5:3/2 r:1/2")
    bars_long(fl, 8)
    s.bus("flute", reverb=0.4, echo=0.18)
    s.notes("flute", v_flute, fl, 8, gain=0.19, pan=0.12)
    s.bus("bell", reverb=0.45, echo=0.25)
    s.arp("bell", prog, bars_of(("................", 4), ("........2..1.0..", 4), ("................", 8)),
          v_bell, center=77, gain=0.07, pan=-0.3)
    groove = {"kick": "x.....x...x.....", "rim": "....x.......x...",
              "hat": "oxo.oxo.oxo.oxo.", "shaker": "..o...o...o...o."}
    end = dict(groove, rim="....x.......x.x.")
    s.bus("drums", reverb=0.1)
    s.drums("drums", [groove] * 7 + [end] + [groove] * 7 + [end],
            {"kick": 0.6, "rim": 0.3, "hat": 0.1, "shaker": 0.12})
    s.sidechain("pads", 0.3)
    return s.render(rt60=1.6, echo_beats=0.75, echo_fb=0.32, target_rms=-20.0)


def match_gym():
    """Under play in THE GYM (ADR-078): a punchy E minor funk, 112 BPM, in a
    big echoey hall. Clavinet-ish electric piano stabs, a busy octave bass,
    brass hits, a tight kit with claps that ring off the walls; a whistle
    lead in the second half."""
    s = Song(112, 16, seed=707, swing=0.02)
    prog = progression("Em9 A9 Em9 A9 Cmaj7 B7 Em9 A9 "
                       "Em9 A9 Gmaj7 F#7 Cmaj7 Am7 B7sus4:2 B7:2")
    s.bus("keys", reverb=0.25)
    s.comp("keys", prog, bars_of(("x.x..x.x..x.x...", 15), ("x.x..x.x.x.x.x.x", 1)),
           v_epiano, center=64, gain=0.2, vel=0.7)
    s.bus("bass", reverb=0.04)
    s.bass("bass", prog, bars_of(("R.O.R..OR.5.O.R.", 7), ("R.O.R..O5.3.O.a.", 1),
                                 ("R.O.R..OR.5.O.R.", 7), ("R.R.5.5.O.O.5.a.", 1)),
           gain=0.6, bright=1.0)
    s.bus("brass", reverb=0.35)
    s.comp("brass", prog, bars_of(("................", 4), ("X..........x....", 4),
                                  ("X..........x....", 7), ("X.x.x.x.........", 1)),
           v_brass, center=67, gain=0.12)
    s.bus("pads", reverb=0.4)
    s.pads("pads", prog, center=60, gain=0.06, cutoff=900)
    wh = melody("r:1 B5:1/2 D6:1/2 E6:1 D6:1/2 B5:1/2 "
                "A5:1 C#6:1/2 E6:1/2 G6:1 E6:1 "
                "r:1/2 B5:1/2 D6:1/2 E6:1/2 G6:1 F#6:1/2 E6:1/2 "
                "C#6:3/2 A5:1/2 B5:2 "
                "r:1 G5:1/2 B5:1/2 D6:1 B5:1 "
                "A#5:1 C#6:1/2 F#6:1/2 E6:2 "
                "E6:1 D6:1/2 B5:1/2 C6:1 A5:1 "
                "B5:3/2 F#5:1/2 B5:2")
    bars_long(wh, 8)
    s.bus("whistle", reverb=0.45, echo=0.2)
    s.notes("whistle", v_whistle, wh, 8, gain=0.17, pan=0.1)
    groove = {"kick": "x.....x...x..x..", "snare": "....x.......x...",
              "hat": "x.x.x.x.x.x.x.x.", "clap": "....o.......o..."}
    fill = dict(groove, snare="....x.......x.xx", tom="..........x.x...")
    s.bus("drums", reverb=0.28)
    s.drums("drums", [groove] * 7 + [fill] + [groove] * 7 + [fill],
            {"kick": 0.65, "snare": 0.35, "hat": 0.09, "clap": 0.18, "tom": 0.25})
    s.sidechain("pads", 0.3)
    return s.render(rt60=2.4, echo_beats=0.5, echo_fb=0.3, target_rms=-20.0)


def match_lakeside():
    """Under play by the lake: a breezy A major float, 94 BPM. Rolling
    marimba sixteenths, soft pads, long bass notes, shaker and finger
    snaps; a bell melody in the second half."""
    s = Song(94, 16, seed=303)
    prog = progression("Amaj9 C#m7 Dmaj9 E6 Amaj9 C#m7 Bm7 E7sus4 "
                       "F#m9 C#m7 Dmaj9 Amaj9/C# Bm7 C#m7 Dmaj9 E7sus4:2 E7:2")
    s.bus("marimba", reverb=0.35, echo=0.12)
    s.arp("marimba", prog, bars_of(("0213021302130213", 16)), v_marimba, center=70, gain=0.13,
          pan=-0.2, vel=0.6)
    s.bus("pads", reverb=0.45)
    s.pads("pads", prog, center=62, gain=0.13, cutoff=900, attack=0.8)
    s.bus("bass", reverb=0.06)
    s.bass("bass", prog, bars_of(("R-----.R--5---.-", 7), ("R-----.R--5-O-a-", 1),
                                 ("R-----.R--5---.-", 7), ("R-----.R--5-O-a-", 1)),
           gain=0.5, bright=0.5)
    mel = melody("r:1/2 A5:1/2 C#6:1/2 E6:3/2 C#6:1 "
                 "B5:1 G#5:1/2 E5:1/2 G#5:2 "
                 "r:1/2 F#5:1/2 A5:1/2 C#6:1/2 E6:1 C#6:1 "
                 "B5:3/2 A5:1/2 G#5:1 E5:1 "
                 "r:1/2 D6:1/2 C#6:1/2 B5:1/2 A5:1 F#5:1 "
                 "G#5:3/2 E5:1/2 B5:1 G#5:1 "
                 "A5:1 F#5:1/2 A5:1/2 C#6:1 E6:1 "
                 "D6:1 B5:1 G#5:3/2 r:1/2")
    bars_long(mel, 8)
    s.bus("bell", reverb=0.5, echo=0.3)
    s.notes("bell", v_bell, mel, 8, gain=0.17, pan=0.2, ratio=2.0, decay=1.4)
    groove = {"kick": "x.......x..x....", "clap": "....o.......o...", "shaker": "oxo.oxo.oxo.oxo."}
    s.bus("drums", reverb=0.15)
    s.drums("drums", [groove] * 16, {"kick": 0.55, "clap": 0.22, "shaker": 0.14})
    s.sidechain("pads", 0.25)
    return s.render(rt60=2.2, echo_beats=0.75, echo_fb=0.35, target_rms=-20.0)


def match_sunset():
    """Under play at sunset: warm Eb major, 86 BPM, swung. Mellow electric
    piano chords, a soft pad, a slow bass, rim clicks; a round lead in the
    second half."""
    s = Song(86, 16, seed=404, swing=0.07)
    prog = progression("Ebmaj7 Cm9 Abmaj7 Bb7sus4 Ebmaj7 Gm7:2 C7:2 Fm9 Bb7 "
                       "Abmaj7 Gm7 Fm9 Ebmaj7 Cm9 Abmaj7 Fm9 Bb7sus4:2 Bb7:2")
    s.bus("keys", reverb=0.35)
    s.comp("keys", prog, bars_of(("x-------.-x-----", 16)), v_epiano, center=63, gain=0.2,
           warm=2.2, spread=0.02)
    s.bus("pads", reverb=0.45)
    s.pads("pads", prog, center=58, gain=0.1, cutoff=700, attack=0.9)
    s.bus("bass", reverb=0.05)
    s.bass("bass", prog, bars_of(("R-----.5--R---.-", 7), ("R-----.5--R-3-a-", 1),
                                 ("R-----.5--R---.-", 7), ("R-----.5--R-3-a-", 1)),
           gain=0.55, bright=0.4)
    mel = melody("C6:3/2 Bb5:1/2 G5:1 Eb5:1 "
                 "F5:1 G5:1/2 Bb5:1/2 D6:2 "
                 "C6:3/2 Ab5:1/2 G5:1 F5:1 "
                 "G5:3 r:1 "
                 "r:1/2 Eb5:1/2 G5:1/2 Bb5:1/2 D6:3/2 C6:1/2 "
                 "Eb6:3/2 C6:1/2 G5:1 Ab5:1 "
                 "G5:1 Ab5:1/2 C6:1/2 Eb6:1 C6:1 "
                 "Eb6:1 D6:1 r:2")
    bars_long(mel, 8)
    s.bus("lead", reverb=0.45, echo=0.25)
    s.notes("lead", v_mellow, mel, 8, gain=0.2, pan=0.1)
    s.bus("bell", reverb=0.5, echo=0.3)
    s.arp("bell", prog, bars_of(("................", 2), ("..........2.1...", 2), ("................", 4),
                                ("................", 8)), v_bell, center=79, gain=0.06, pan=-0.3)
    groove = {"kick": "x.........x.....", "rim": "....x.......x...", "hat": "o.o.o.o.o.o.o.o."}
    s.bus("drums", reverb=0.12)
    s.drums("drums", [groove] * 16, {"kick": 0.55, "rim": 0.28, "hat": 0.08})
    s.sidechain("pads", 0.25)
    return s.render(rt60=2.0, echo_beats=0.75, echo_fb=0.33, target_rms=-20.0)


def match_dinosaur():
    """Under play in the jungle: D dorian, 104 BPM. A marimba ostinato,
    toms and shaker for the drums, a plucky bass; brass stabs and a marimba
    melody join in the second half. Adventurous, but not loud."""
    s = Song(104, 16, seed=505)
    prog = progression("Dm7 C Bbmaj7 C Dm7 C Gm7 A7sus4 "
                       "Dm7 F C Gm7 Bbmaj7 C Dm7:2 C:2 Dm7")
    s.bus("marimba", reverb=0.3, echo=0.1)
    s.arp("marimba", prog, bars_of(("0.2.1.2.0.2.1.3.", 16)), v_marimba, center=69, gain=0.13,
          pan=-0.25, vel=0.6)
    s.bus("pads", reverb=0.4)
    s.pads("pads", prog, center=60, gain=0.08, cutoff=750)
    s.bus("bass", reverb=0.05)
    s.bass("bass", prog, bars_of(("R..R..5.R..R.O.5", 7), ("R..R..5.R..R.5.a", 1),
                                 ("R..R..5.R..R.O.5", 7), ("R..R..5.R.5.O.a.", 1)),
           gain=0.5, bright=0.8)
    s.bus("brass", reverb=0.35)
    s.comp("brass", prog, bars_of(("................", 8), ("X.......x.x.....", 8)), v_brass,
           center=62, gain=0.1)
    mel = melody("D5:1 F5:1/2 G5:1/2 A5:1 C6:1 "
                 "A5:1/2 G5:1/2 F5:1 G5:2 "
                 "F5:1 A5:1/2 C6:1/2 D6:1 C6:1 "
                 "A5:3 r:1 "
                 "D6:1 C6:1/2 A5:1/2 G5:1 F5:1 "
                 "G5:1 A5:1/2 C6:1/2 A5:2 "
                 "F5:1 E5:1/2 D5:1/2 E5:1 G5:1 "
                 "D5:3 r:1")
    bars_long(mel, 8)
    s.bus("lead", reverb=0.35, echo=0.2)
    s.notes("lead", v_marimba, mel, 8, transpose=12, gain=0.16, pan=0.2)
    groove = {"kick": "X.....x...X.....", "tomlo": "..x.......x.....", "tom": "........x.....o.",
              "shaker": "oxoxoxoxoxoxoxox"}
    end = dict(groove, tom="........x.x.x.x.")
    s.bus("drums", reverb=0.14)
    s.drums("drums", [groove] * 7 + [end] + [groove] * 7 + [end],
            {"kick": 0.6, "tom": 0.28, "tomlo": 0.3, "shaker": 0.1})
    s.sidechain("pads", 0.3)
    return s.render(rt60=1.8, echo_beats=0.75, echo_fb=0.3, target_rms=-20.0)


def match_space():
    """Under play among the stars: C lydian, 90 BPM. A pulse-wave arpeggio
    through a long echo, wide slow pads, a held bass and a light kit; a
    bell melody floats over the second half."""
    s = Song(90, 16, seed=606)
    prog = progression("Cmaj9 D Em7 D Cmaj9 D Bm7 Em7 "
                       "Am9 D Gmaj7 Cmaj9 Am7 Bm7 Cmaj9:2 D:2 Em7")
    s.bus("arp", reverb=0.4, echo=0.35)
    for pan, det in ((-0.3, -5), (0.3, 5)):
        s.arp("arp", prog, bars_of(("0123012301230123", 16)), v_lead, center=72, gain=0.06,
              pan=pan, vel=0.55, pw=0.5, bright=2600, detune=det, vib=0)
    s.bus("pads", reverb=0.6)
    s.pads("pads", prog, center=62, gain=0.13, cutoff=1000, attack=1.2, release=1.0)
    s.bus("bass", reverb=0.08)
    s.bass("bass", prog, bars_of(("R-------R-----5-", 16)), gain=0.45, bright=0.4)
    mel = melody("E6:2 D6:1 B5:1 "
                 "A5:2 B5:1 D6:1 "
                 "E6:3/2 F#6:1/2 G6:1 E6:1 "
                 "D6:4 "
                 "C6:2 B5:1 A5:1 "
                 "B5:2 D6:1 F#6:1 "
                 "G6:3/2 F#6:1/2 E6:1 D6:1 "
                 "E6:4")
    bars_long(mel, 8)
    s.bus("bell", reverb=0.6, echo=0.35)
    s.notes("bell", v_bell, mel, 8, gain=0.14, pan=0.1, ratio=3.5, decay=1.6)
    groove = {"kick": "x.......x.......", "clap": "....o.......o...", "hat": "..o...o...o...o."}
    s.bus("drums", reverb=0.2)
    s.drums("drums", [groove] * 16, {"kick": 0.5, "clap": 0.16, "hat": 0.09})
    s.sidechain("pads", 0.3)
    return s.render(rt60=2.8, echo_beats=0.75, echo_fb=0.4, target_rms=-20.0)


def match_undersea():
    """Under play under the sea: E minor, 80 BPM, lightly swung. Marimba
    drops through a heavy echo (bubbles), soft electric piano, a slow bass,
    a muted kit; a flute melody drifts over the second half."""
    s = Song(80, 16, seed=707, swing=0.05)
    prog = progression("Em9 Cmaj7 Am9 Bm7 Em9 Cmaj7 F#m7b5 B7sus4 "
                       "Cmaj7 Bm7 Am9 Em9 Cmaj7 D6 Am9:2 B7sus4:2 Em9")
    s.bus("drops", reverb=0.45, echo=0.4)
    s.arp("drops", prog, bars_of(("0..2..1..3..2...", 16)), v_marimba, center=76, gain=0.1,
          pan=0.25, vel=0.5)
    s.bus("keys", reverb=0.4)
    s.comp("keys", prog, bars_of(("x-------........", 16)), v_epiano, center=60, gain=0.15, warm=2.0)
    s.bus("pads", reverb=0.55)
    s.pads("pads", prog, center=59, gain=0.1, cutoff=650, attack=1.0)
    s.bus("bass", reverb=0.06)
    s.bass("bass", prog, bars_of(("R-------5-------", 15), ("R-------5---3-a-", 1)),
           gain=0.5, bright=0.35)
    mel = melody("B5:2 G5:1 E5:1 "
                 "F#5:2 G5:1 A5:1 "
                 "B5:3/2 A5:1/2 G5:1 F#5:1 "
                 "E5:4 "
                 "G5:2 A5:1 B5:1 "
                 "C6:2 B5:1 A5:1 "
                 "B5:3/2 G5:1/2 F#5:1 D#5:1 "
                 "E5:4")
    bars_long(mel, 8)
    s.bus("flute", reverb=0.5, echo=0.25)
    s.notes("flute", v_flute, mel, 8, gain=0.17, pan=-0.1)
    groove = {"kick": "x.........x.....", "rim": "........x.......", "shaker": "..o...o...o...o."}
    s.bus("drums", reverb=0.18)
    s.drums("drums", [groove] * 16, {"kick": 0.5, "rim": 0.2, "shaker": 0.1})
    s.sidechain("pads", 0.25)
    return s.render(rt60=2.4, echo_beats=0.75, echo_fb=0.42, target_rms=-20.0)


def park():
    """The park in open play: a playful G major romp, 116 BPM. A whistle
    lead, a bouncy bass, marimba offbeat stabs, claps and a tom fill."""
    s = Song(116, 16, seed=505, swing=0.05)
    prog = progression("G Em C D7 G B7 Em A7:2 D7:2 C D Bm Em Am7 D7 G D7sus4:2 D7:2")
    mel = melody("D5:1/2! G5:1/2 B5:1/2 G5:1/2 D6:1 B5:1 "
                 "C6:1/2 B5:1/2 A5:1/2 G5:1/2 E5:1 G5:1 "
                 "E5:1/2 G5:1/2 C6:1/2 E6:1/2 D6:1/2 C6:1/2 B5:1/2 A5:1/2 "
                 "A5:3/2 F#5:1/2 D5:1 r:1 "
                 "D5:1/2! G5:1/2 B5:1/2 G5:1/2 D6:1 G6:1 "
                 "F#6:1/2 D#6:1/2 B5:1/2 A5:1/2 F#5:1 D#5:1 "
                 "E5:1/2 G5:1/2 B5:1/2 E6:1/2 D6:1/2 B5:1/2 G5:1 "
                 "A5:1/2 C#6:1/2 E6:1 D6:1/2 C6:1/2 A5:1 "
                 "E6:3/2! D6:1/2 C6:1 G5:1 "
                 "F#6:3/2 E6:1/2 D6:1 A5:1 "
                 "D6:1/2 B5:1/2 F#5:1/2 B5:1/2 D6:1 F#6:1 "
                 "E6:2 r:1 B5:1/2 C6:1/2 "
                 "E6:1 C6:1/2 A5:1/2 G5:1 E5:1 "
                 "F#5:1/2 A5:1/2 C6:1/2 D6:1/2 F#6:1 E6:1/2 D6:1/2 "
                 "B5:1/2 D6:1/2 G6:1 F#6:1/2 E6:1/2 D6:1 "
                 "D6:1 C6:1 A5:1 F#5:1")
    bars_long(mel, 16)
    s.bus("lead", reverb=0.22, echo=0.25)
    s.notes("lead", v_whistle, mel, 0, gain=0.24, pan=0.08, gate=0.7)
    s.bus("stabs", reverb=0.25)
    s.comp("stabs", prog, bars_of(("..x...x...x...x.", 16)), v_marimba, center=67, gain=0.1, gate=0.5)
    s.bus("bass", reverb=0.04)
    s.bass("bass", prog, bars_of(("R-.5O-.5R-.5O-.a", 16)), gain=0.55, bright=1.1, gate=0.7)
    s.bus("pads", reverb=0.35)
    s.pads("pads", prog, center=60, gain=0.08, cutoff=900)
    groove = {"kick": "X...x...X...x...", "clap": "....x.......x...",
              "hat": "..x...x...x...x.", "shaker": "oxoxoxoxoxoxoxox"}
    fill = {"kick": "X...x...X.......", "clap": "....x...........",
            "tom": "........x.x.....", "tomlo": "............x.x.", "hat": "..x...x........."}
    s.bus("drums", reverb=0.12)
    s.drums("drums", [groove] * 7 + [fill] + [groove] * 7 + [fill],
            {"kick": 0.65, "clap": 0.3, "hat": 0.12, "shaker": 0.1, "tom": 0.35, "tomlo": 0.35})
    s.hit("drums", "crash", 0, 0.8, 0.18)
    s.sidechain("pads", 0.35)
    return s.render(rt60=1.6, echo_beats=0.75, echo_fb=0.3, target_rms=-18.0)


def stinger_won():
    """Match won: a short brass fanfare up a D major triad, a big chord."""
    s = Song(140, 2, seed=606, loop=False, tail=2.4)
    fan = melody("D5:1/3! F#5:1/3 A5:1/3 D6:3/4! C#6:1/4 D6:5/2!")
    s.bus("brass", reverb=0.3)
    s.notes("brass", v_brass, fan, gain=0.4)
    s.notes("brass", v_lead, fan, transpose=12, gain=0.12, pw=0.3)
    s.bus("pads", reverb=0.4)
    for m in (62, 66, 69, 74, 76):
        s.add("brass", v_brass(m, 2.5 * s.spb, 0.75, s.rng), s.time(2.0, 0.0), (m - 68) / 16, 0.16)
    s.pads("pads", [(2.0, 3.0, chord("Dadd9"))], center=64, gain=0.14, attack=0.05)
    s.bus("bass", reverb=0.05)
    s.add("bass", v_bass(38, 2.4 * s.spb, 0.9, s.rng), s.time(2.0, 0.0), 0.0, 0.55)
    s.bus("drums", reverb=0.2)
    for beat, inst, v in ((0, "snare", 0.5), (1 / 3, "snare", 0.6), (2 / 3, "snare", 0.7),
                          (1, "tom", 0.9), (1.75, "tom", 0.7), (2, "kick", 1.0), (2, "crash", 1.0)):
        s.hit("drums", inst, beat, v, {"snare": 0.4, "tom": 0.45, "kick": 0.8, "crash": 0.3}[inst])
    s.bus("bell", reverb=0.5, echo=0.3)
    s.notes("bell", v_bell, melody("r:2 D6:1/4 F#6:1/4 A6:1/4 D7:1"), gain=0.08)
    return fade_out(s.render(rt60=1.8, echo_beats=0.5, target_rms=-16.0), 0.5)


def stinger_lost():
    """Match lost: a friendly 'aww', sliding down to a soft minor chord."""
    s = Song(96, 2, seed=707, loop=False, tail=2.2)
    line = melody("Bb4:3/4 A4:3/4 Ab4:3/4 G4:3!")
    s.bus("brass", reverb=0.35)
    s.notes("brass", v_brass, line, gain=0.34, swell=0.12)
    s.notes("brass", v_mellow, line, transpose=-12, gain=0.12)
    s.bus("pads", reverb=0.45)
    s.pads("pads", [(2.25, 3.0, chord("Gm6"))], center=60, gain=0.13, cutoff=700, attack=0.3)
    s.bus("bass", reverb=0.05)
    s.add("bass", v_bass(43, 2.6 * s.spb, 0.7, s.rng, bright=0.4), s.time(2.25, 0.0), 0.0, 0.5)
    s.bus("drums", reverb=0.2)
    for beat, inst, v in ((0, "tomlo", 0.5), (0.75, "tomlo", 0.45), (1.5, "tomlo", 0.4), (2.25, "kick", 0.6)):
        s.hit("drums", inst, beat, v, 0.4)
    return fade_out(s.render(rt60=2.0, target_rms=-18.0), 0.6)


def stinger_cleared():
    """The ladder cleared: a snare roll, then a bigger fanfare in E major
    (a key up from the title's D), a held chord, crash and bells."""
    s = Song(132, 4, seed=808, loop=False, tail=2.0)
    prog = progression("E:2 E:4 A:2 B:2 E:6")
    line = melody("r:2 B4:1/2! E5:1/2 G#5:1/2 B5:3/2! A5:1/2 G#5:1/2 "
                  "A5:1/2! C#6:1/2 E6:1 D#6:1/2 C#6:1/2 B5:1 E6:4!")
    s.bus("brass", reverb=0.3)
    s.notes("brass", v_brass, line, gain=0.38)
    s.notes("brass", v_lead, line, transpose=12, gain=0.1, pw=0.3)
    s.bus("pads", reverb=0.4)
    s.pads("pads", prog[1:], center=62, gain=0.15, attack=0.08)
    for m in (64, 68, 71, 76):
        s.add("brass", v_brass(m, 3.5 * s.spb, 0.7, s.rng), s.time(10.0, 0.0), (m - 70) / 14, 0.14)
    s.bus("bass", reverb=0.05)
    s.bass("bass", prog, ["........R-.R..R-", "R-.R..R-R-.5..O-", "R---------------"], gain=0.5)
    s.bus("drums", reverb=0.2)
    for i in range(8):
        s.hit("drums", "snare", i * 0.25, 0.35 + i * 0.08, 0.32)
    groove = {"kick": "X.....x.X.....x.", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."}
    s.drums("drums", [{"kick": "........X.....x.", "hat": "........x.x.x.x."}, groove,
                      {"kick": "X...x...X.......", "snare": "....oxxX........", "hat": "x.x.x..........."}],
            {"kick": 0.75, "snare": 0.38, "hat": 0.14})
    s.hit("drums", "crash", 2, 0.8, 0.24)
    s.hit("drums", "crash", 10, 1.0, 0.32)
    s.hit("drums", "kick", 10, 1.0, 0.8)
    s.bus("bell", reverb=0.5, echo=0.3)
    s.notes("bell", v_bell, melody("r:10 E6:1/4 G#6:1/4 B6:1/4 E7:1/4 B6:1/4 G#6:1/4 E7:1"), gain=0.08)
    return fade_out(s.render(rt60=2.0, echo_beats=0.5, target_rms=-16.0), 0.7)


STINGERS = ("music_won", "music_lost", "music_cleared")
TRACKS = {"music_title": title, "music_match_park": match_park, "music_match_lakeside": match_lakeside,
          "music_match_sunset": match_sunset, "music_match_dinosaur": match_dinosaur,
          "music_match_space": match_space, "music_match_undersea": match_undersea,
          "music_match_gym": match_gym, "music_park": park, "music_won": stinger_won,
          "music_lost": stinger_lost, "music_cleared": stinger_cleared}


def report(name, x):
    peak = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
    line = f"{name:24s} {len(x) / SR:6.2f}s  peak {peak:6.1f} dBFS  rms {rms:6.1f} dBFS"
    if name not in STINGERS:            # a loop's last sample leads into its first
        seam = np.max(np.abs(x[0] - x[-1]))
        step = np.percentile(np.abs(np.diff(x, axis=0)), 99)
        line += f"  seam {seam:.4f} (99% step {step:.4f})"
    print(line)


def main():
    show = "--report" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name, fn in TRACKS.items():
        if only and not any(o in name for o in only):
            continue
        x = fn()
        write(name, x)
        if show:
            report(name, x)
    print(f"wrote to {OUT}")


if __name__ == "__main__":
    main()
