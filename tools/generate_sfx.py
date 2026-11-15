#!/usr/bin/env python3
"""Synthesises the game's retro sound effects into assets/audio/sfx/*.wav.

All sounds are generated from scratch here (no third-party samples), so they
can live in the public repository. Re-run after tweaking:
    python tools/generate_sfx.py
Requires numpy.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "sfx"
rng = np.random.default_rng(7)


def t(d):
    return np.linspace(0, d, int(RATE * d), endpoint=False)


def env(n, attack=0.005, decay=1.0, curve=3.0):
    """Linear attack, then a power-curve decay blended with a linear one."""
    x = np.linspace(0, 1, n)
    a = np.minimum(1.0, np.arange(n) / max(1, int(attack * RATE)))
    d = (1 - x) ** curve * decay + (1 - decay) * (1 - x)
    return a * d


def tone(freq, d, kind="square"):
    tt = t(d)
    if callable(freq):
        phase = 2 * np.pi * np.cumsum(freq(tt)) / RATE
    else:
        phase = 2 * np.pi * freq * tt
    if kind == "square":
        return np.sign(np.sin(phase))
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if kind == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    return np.sin(phase)


def noise(d):
    return rng.uniform(-1, 1, int(RATE * d))


def lowpass(x, k=0.2):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def save(name, x, vol=0.6):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    data = (x / peak * vol * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def main():
    d = 0.12; save("swing", lowpass(noise(d), 0.35) * env(int(RATE * d), 0.01, 1, 2) * np.linspace(1, 0.4, int(RATE * d)), 0.35)
    d = 0.09; save("hit", (tone(lambda x: 220 - 900 * x, d) * 0.6 + noise(d) * 0.5) * env(int(RATE * d), 0.001, 1, 4), 0.55)
    d = 0.18; save("hit_heavy", (tone(lambda x: 160 - 500 * x, d) * 0.7 + lowpass(noise(d), 0.4) * 0.6) * env(int(RATE * d), 0.001, 1, 3), 0.7)
    d = 0.25; save("hurt", (tone(lambda x: 420 - 900 * x, d, "saw") * 0.7 + noise(d) * 0.2) * env(int(RATE * d), 0.002, 1, 2), 0.5)
    d = 0.16; save("dodge", lowpass(noise(d), 0.15) * env(int(RATE * d), 0.03, 1, 1.5) + tone(lambda x: 300 + 900 * x, d, "sine") * 0.15 * env(int(RATE * d)), 0.4)
    d = 0.5; save("flash", (tone(lambda x: 600 + 1400 * x, d, "sine") * 0.6 + tone(lambda x: 900 + 2100 * x, d, "tri") * 0.3) * env(int(RATE * d), 0.01, 1, 2.5), 0.45)
    d = 0.12; save("pickup", np.concatenate([tone(880, d / 2, "square") * env(int(RATE * d / 2)), tone(1320, d / 2, "square") * env(int(RATE * d / 2))]), 0.3)
    d = 0.1; save("equip", (tone(300, d, "square") * 0.5 + noise(d) * 0.3) * env(int(RATE * d), 0.001, 1, 5), 0.35)
    d = 0.2; save("use", tone(lambda x: 500 + 300 * np.sin(x * 40), d, "tri") * env(int(RATE * d), 0.01), 0.35)
    d = 0.6; save("attune", sum(tone(f, d, "sine") * env(int(RATE * d), 0.02 + i * 0.05, 1, 2) for i, f in enumerate([523, 659, 784, 1047])), 0.4)
    d = 0.45; save("enemy_death", (tone(lambda x: 700 - 650 * x, d, "sine") * 0.6 + lowpass(noise(d), 0.1) * 0.5) * env(int(RATE * d), 0.005, 1, 1.6), 0.5)
    d = 0.35; save("stamp_warn", tone(lambda x: 200 + 400 * x, d, "square") * 0.4 * env(int(RATE * d), 0.05, 0.6, 1), 0.3)
    d = 0.3; save("stamp", (lowpass(noise(d), 0.25) + tone(lambda x: 90 - 60 * x, d, "sine")) * env(int(RATE * d), 0.001, 1, 3), 0.8)
    d = 1.2; save("boss_roar", (tone(lambda x: 70 + 10 * np.sin(x * 9), d, "saw") * 0.6 + lowpass(noise(d), 0.05) * 0.8) * env(int(RATE * d), 0.15, 1, 1.2), 0.7)
    d = 0.05; save("ui_click", tone(1200, d, "square") * env(int(RATE * d), 0.001, 1, 6), 0.2)
    d = 0.18; save("ui_open", tone(lambda x: 400 + 800 * x, d, "tri") * env(int(RATE * d), 0.005), 0.25)
    d = 0.35; save("door", (lowpass(noise(d), 0.08) + tone(lambda x: 140 - 40 * x, d, "sine") * 0.4) * env(int(RATE * d), 0.02, 1, 2), 0.5)
    d = 1.4; save("bell", sum(tone(f, d, "sine") * a for f, a in [(1180, 1.0), (1180 * 2.76, 0.4), (1180 * 5.4, 0.2)]) * env(int(RATE * d), 0.002, 1, 4), 0.5)
    d = 0.22; save("shard", (tone(lambda x: 1600 - 1200 * x, d, "tri") * 0.6 + noise(d) * 0.15) * env(int(RATE * d), 0.005, 1, 2), 0.35)
    d = 0.15; save("coin", np.concatenate([tone(1047, 0.05, "square"), tone(1568, 0.1, "square") * env(int(RATE * 0.1))]), 0.25)
    d = 0.3; save("step_in", tone(lambda x: 300 - 200 * x, d, "sine") * env(int(RATE * d), 0.01, 1, 2), 0.3)
    print(f"Wrote {len(list(OUT.glob('*.wav')))} sounds to {OUT}")


if __name__ == "__main__":
    main()
