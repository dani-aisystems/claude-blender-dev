"""Synthesise every sound in THE LAST LIGHT (host Python + numpy; no downloads, fully owned).

  tools/py projects/games/last_light/audio/synth.py

Writes 16-bit mono WAV (44.1 kHz) to godot/assets/audio/. Loops are crossfaded end-into-start so
they repeat seamlessly; every file is peak-normalised to <= -1 dBFS. Prints SYNTH_RESULT {json}.
"""

import json
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "godot" / "assets" / "audio"
rng = np.random.default_rng(1953)


def t(sec):
    return np.arange(int(round(sec * SR))) / SR


def noise(sec):
    return rng.standard_normal(int(round(sec * SR)))


def band(x, lo=None, hi=None, slope=1.0):
    """FFT band filter with soft edges (lo/hi in Hz)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** (2 * slope))
    if hi:
        g *= 1 / (1 + (f / hi) ** (2 * slope))
    return np.fft.irfft(X * g, n=len(x))


def env(n, a=0.01, d=0.3, curve=3.0):
    e = np.ones(n)
    na = max(1, int(a * SR))
    e[:na] = np.linspace(0, 1, na)
    tail = np.arange(n - na) / SR
    e[na:] = np.exp(-tail / max(d, 1e-4) * curve / 3.0)
    return e


def lfo(sec, rate, depth, phase=0.0):
    return 1 + depth * np.sin(2 * np.pi * rate * t(sec) + phase)


def smooth_rand(sec, rate, seed):
    r = np.random.default_rng(seed)
    k = max(2, int(sec * rate) + 2)
    pts = r.uniform(0, 1, k)
    x = np.linspace(0, k - 1, int(round(sec * SR)))
    return np.interp(x, np.arange(k), pts)


def loopify(x, xf=1.5):
    n = int(xf * SR)
    head, tail = x[:n], x[-n:]
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = tail * (1 - w) + head * w
    return x


def norm(x, peak_db=-1.0):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * (10 ** (peak_db / 20))


def save(name, x, peak_db=-1.0):
    OUT.mkdir(parents=True, exist_ok=True)
    x = norm(np.nan_to_num(x), peak_db)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    RESULT[name] = round(len(x) / SR, 2)


RESULT = {}


# ------------------------------------------------------------------ ambience loops

def wind():
    sec = 24
    base = band(noise(sec), 80, 900)
    gust = smooth_rand(sec, 0.35, 2) ** 2
    howl = band(noise(sec), 300, 520, 2.5) * (gust * 1.4)
    x = base * (0.45 + 0.8 * gust) + howl * 0.6
    save("amb_wind", loopify(x), -4)


def rain_glass():
    sec = 16
    hiss = band(noise(sec), 1500, 9000) * 0.35
    drops = np.zeros(int(sec * SR))
    idx = rng.integers(0, len(drops) - 2000, 2600)
    for i in idx:
        L = rng.integers(200, 900)
        drops[i:i + L] += rng.uniform(0.2, 1.0) * np.sin(2 * np.pi * rng.uniform(2500, 6000) * t(L / SR)) * env(L, 0.0005, 0.004)
    save("amb_rain", loopify(hiss + band(drops, 1200, 12000) * 0.8), -6)


def sea():
    sec = 30
    swell = smooth_rand(sec, 0.12, 5)
    surf = band(noise(sec), 60, 1200) * (0.2 + swell ** 1.5)
    boom = band(noise(sec), 30, 140) * (smooth_rand(sec, 0.08, 6) ** 3)
    save("amb_sea", loopify(surf + boom * 1.5), -5)


def generator():
    sec = 8
    tt = t(sec)
    f0 = 25.0
    x = sum((1 / k) * np.sin(2 * np.pi * f0 * k * tt + k) for k in range(1, 9))
    knock = np.zeros_like(tt)
    for i in range(int(sec * f0 / 2)):
        p = int(i * SR / (f0 / 2))
        L = 700
        if p + L < len(knock):
            knock[p:p + L] += env(L, 0.001, 0.01) * band(noise(L / SR), 200, 2000)
    save("gen_idle", loopify(x * 0.6 + knock * 0.5 + band(noise(sec), 100, 400) * 0.15, 0.5), -6)


def hum():
    sec = 6
    tt = t(sec)
    x = np.sin(2 * np.pi * 50 * tt) + 0.5 * np.sin(2 * np.pi * 100 * tt) + 0.25 * np.sin(2 * np.pi * 150 * tt)
    x += band(noise(sec), 2000, 5000) * 0.03
    save("hum", loopify(x, 0.5), -12)


def clockwork():
    sec = 5
    x = np.zeros(int(sec * SR))
    for i in range(int(sec * 4)):
        p = int(i * SR / 4) + int(rng.integers(0, 200))
        L = 1500
        if p + L < len(x):
            x[p:p + L] += env(L, 0.0005, 0.006) * band(noise(L / SR), 1800, 7000) * (1.0 if i % 2 else 0.6)
    x += band(noise(sec), 60, 200) * 0.08
    save("clockwork", loopify(x, 0.3), -8)


def static_loop():
    sec = 6
    x = band(noise(sec), 400, 6000) * (0.6 + 0.4 * smooth_rand(sec, 6, 9))
    crackle = np.zeros(int(sec * SR))
    for i in rng.integers(0, len(crackle) - 300, 240):
        crackle[i:i + 120] += rng.uniform(-1, 1) * env(120, 0.0001, 0.001)
    save("static", loopify(x + crackle * 2.0, 0.3), -9)


def motor_grind():
    sec = 3
    tt = t(sec)
    x = band(noise(sec), 200, 1800) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 7 * tt)))
    x += 0.4 * np.sign(np.sin(2 * np.pi * 61 * tt)) * band(noise(sec), 50, 300)
    save("motor_grind", loopify(x, 0.2), -4)


# ------------------------------------------------------------------ one-shots

def thunder(k):
    sec = 7
    rr = np.random.default_rng(100 + k)
    x = band(rr.standard_normal(int(sec * SR)), 20, 260)
    e = env(len(x), 0.04 + 0.05 * k, 2.2 + k * 0.4)
    crack = band(rr.standard_normal(int(0.25 * SR)), 300, 4000) * env(int(0.25 * SR), 0.001, 0.08)
    y = x * e * (0.6 + 0.4 * smooth_rand(sec, 3, 200 + k))
    y[:len(crack)] += crack * (0.8 if k == 0 else 0.3)
    save(f"thunder_{k}", y, -2)


def click(name, f=2500, d=0.012, body=None):
    L = int(0.08 * SR)
    x = band(noise(L / SR), f * 0.5, f * 2) * env(L, 0.0003, d)
    if body:
        x += np.sin(2 * np.pi * body * t(L / SR)) * env(L, 0.0005, 0.03) * 0.6
    save(name, x, -3)


def breaker():
    L = int(0.6 * SR)
    x = band(noise(L / SR), 80, 3000) * env(L, 0.0005, 0.05)
    x += np.sin(2 * np.pi * 70 * t(L / SR)) * env(L, 0.001, 0.15)
    save("breaker_trip", x, -1)


def crank():
    sec = 1.6
    tt = t(sec)
    rate = 7 + 6 * tt
    ph = np.cumsum(rate) / SR
    x = (np.sin(2 * np.pi * ph) > 0.6).astype(float) * band(noise(sec), 100, 900)
    save("gen_crank", x + band(noise(sec), 100, 400) * 0.1, -3)


def footsteps(name, metal=True, n=4):
    for k in range(n):
        L = int(0.35 * SR)
        rr = np.random.default_rng(300 + k + (0 if metal else 50))
        x = band(rr.standard_normal(L), 150, 1500) * env(L, 0.001, 0.04)
        if metal:
            for fr in (420 + 60 * k, 1170 + 80 * k, 2650):
                x += np.sin(2 * np.pi * fr * t(L / SR)) * env(L, 0.001, 0.12) * 0.25
        save(f"{name}_{k}", x, -3)


def knock():
    L = int(0.5 * SR)
    x = band(noise(L / SR), 60, 900) * env(L, 0.0005, 0.03)
    x += np.sin(2 * np.pi * 95 * t(L / SR)) * env(L, 0.001, 0.09) * 0.9
    x += np.sin(2 * np.pi * 380 * t(L / SR)) * env(L, 0.001, 0.05) * 0.3    # steel door ring
    save("knock", x, -1)


def door_heavy():
    sec = 2.4
    tt = t(sec)
    bolt = band(noise(0.3), 500, 5000) * env(int(0.3 * SR), 0.001, 0.05)
    creak_f = 180 + 60 * np.sin(2 * np.pi * 0.7 * tt) + 40 * smooth_rand(sec, 8, 11)
    creak = np.sin(2 * np.pi * np.cumsum(creak_f) / SR) * (np.sin(2 * np.pi * 23 * tt) > 0.2) * 0.4
    x = np.zeros(len(tt))
    x[:len(bolt)] += bolt
    x += band(creak, 100, 2000) * np.clip(tt - 0.4, 0, 1) * np.clip(2.2 - tt, 0, 1)
    save("door_heavy", x + band(noise(sec), 30, 200) * 0.3 * env(len(tt), 0.5, 1.0), -2)


def base_door():
    L = int(1.8 * SR)
    x = band(noise(L / SR), 40, 400) * env(L, 0.002, 0.25)
    x = band(x, None, 600)       # far away, through stone
    save("door_base", x, -6)


def paper_slide():
    sec = 1.2
    x = band(noise(sec), 2000, 9000) * (np.sin(np.pi * t(sec) / sec) ** 2)
    save("paper_slide", x, -6)


def horn(name, f, sec=2.6):
    tt = t(sec)
    x = sum((1 / k) * np.sin(2 * np.pi * f * k * tt) for k in range(1, 7))
    e = np.clip(tt / 0.15, 0, 1) * np.clip((sec - tt) / 0.5, 0, 1)
    save(name, band(x * e, 80, 2500), -3)


def squelch():
    L = int(0.12 * SR)
    save("squelch", band(noise(L / SR), 800, 5000) * env(L, 0.0005, 0.04), -8)


def blip():
    L = int(0.02 * SR)
    save("blip", np.sin(2 * np.pi * 1800 * t(L / SR)) * env(L, 0.0002, 0.006), -18)


def ui_click():
    click("ui_click", 3200, 0.008, 900)
    L = int(0.05 * SR)
    save("ui_hover", np.sin(2 * np.pi * 1300 * t(L / SR)) * env(L, 0.001, 0.01), -20)


def pad(name, notes, sec, seed, brightness=1.0, tension=False):
    tt = t(sec)
    x = np.zeros(len(tt))
    for i, n in enumerate(notes):
        f = 440 * 2 ** ((n - 69) / 12)
        det = 1 + 0.002 * np.sin(2 * np.pi * (0.07 + 0.03 * i) * tt)
        voice = sum((0.5 ** k) * np.sin(2 * np.pi * f * (k + 1) * det * tt + i) for k in range(4))
        x += voice * (0.6 + 0.4 * smooth_rand(sec, 0.1, seed + i))
    if tension:
        x += 0.3 * np.sin(2 * np.pi * 41.2 * tt) * (0.5 + 0.5 * smooth_rand(sec, 0.2, seed + 9))
    air = band(noise(sec), 300, 3000) * 0.04
    x = band(x, 40, 1800 * brightness) + air
    save(name, loopify(x, 4.0), -10)


def main():
    wind()
    rain_glass()
    sea()
    generator()
    hum()
    clockwork()
    static_loop()
    motor_grind()
    for k in range(3):
        thunder(k)
    click("click_switch", 2200, 0.012, 160)
    click("click_knob", 1600, 0.02, 220)
    click("click_button", 1200, 0.03, 120)
    ui_click()
    breaker()
    crank()
    save("gen_stop", band(noise(2.0), 30, 300) * env(int(2.0 * SR), 0.01, 0.8), -4)
    footsteps("step_metal", True)
    footsteps("step_stone", False)
    knock()
    door_heavy()
    base_door()
    paper_slide()
    horn("horn_fishing", 233)
    horn("horn_ship", 98, 3.6)
    squelch()
    blip()
    pad("music_menu", [50, 57, 62, 64, 69], 48, 1, 0.8)          # D modal, open and cold
    pad("music_tension", [38, 45, 51, 56], 40, 7, 0.6, tension=True)
    print("SYNTH_RESULT", json.dumps({"files": len(RESULT), "seconds": RESULT}))


if __name__ == "__main__":
    main()
