#!/usr/bin/env python3
"""Genera la música, el ambiente y los efectos del juego (assets/audio/*.ogg).

Todo el audio se sintetiza aquí desde cero con numpy (sin muestras de
terceros), así que no hay licencias que revisar. Requiere numpy y ffmpeg con
libvorbis. Uso:

    python3 tools/generate_audio.py

Los bucles (música y ambiente) terminan mezclados con su inicio para que se
repitan sin cortes; en Godot se importan con loop activado (.import).
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1742)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env_adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = max(na, 1)
    e[:na] = np.linspace(0, 1, na)
    e[na:na + nd] = np.linspace(1, s, len(e[na:na + nd]))
    if nr > 0:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def lowpass_fast(x, cutoff):
    # Versión vectorizada aproximada con convolución exponencial.
    a = np.exp(-2 * np.pi * cutoff / SR)
    n = int(min(len(x), 6 / (1 - a)))
    k = (1 - a) * a ** np.arange(n)
    y = np.convolve(x, k)[: len(x)]
    return np.convolve(y, k)[: len(x)]


def saw(f, t, detune=0.0):
    ph = (f * (1 + detune)) * t
    return 2 * (ph - np.floor(ph + 0.5))


def pad(notes, sec, cutoff=900, amp=0.18):
    t = t_axis(sec)
    x = np.zeros_like(t)
    for n in notes:
        f = midi(n)
        for d in (-0.004, 0.0, 0.005):
            x += saw(f, t, d)
    x = lowpass_fast(x / (len(notes) * 3), cutoff)
    return x * env_adsr(len(t), a=sec * 0.35, d=0.1, s=1.0, r=sec * 0.35) * amp


def pluck(note, sec=1.6, amp=0.25, bright=0.5):
    """Cuerda pulsada (Karplus-Strong)."""
    f = midi(note)
    n = int(sec * SR)
    period = int(SR / f)
    buf = rng.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(n):
        v = buf[i % period]
        out[i] = v
        buf[i % period] = 0.5 * (v + buf[(i + 1) % period]) * (0.994 + 0.004 * bright)
    return out * amp * env_adsr(n, a=0.002, d=0.05, s=1.0, r=0.3)


def kick(amp=0.6, sec=0.45, f0=110, f1=40):
    t = t_axis(sec)
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7) * amp


def tick(amp=0.12, sec=0.05, cutoff=6000):
    n = rng.uniform(-1, 1, int(sec * SR))
    n = n - lowpass_fast(n, cutoff * 0.3)
    return n * np.exp(-np.linspace(0, 12, len(n))) * amp


def add(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i]


def seamless(x, fade=2.0):
    """Mezcla la cola con el inicio para que el bucle no tenga corte."""
    n = int(fade * SR)
    head = x[:n].copy()
    tail = x[-n:]
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def reverb(x, amount=0.25, times=(0.067, 0.113, 0.171, 0.233), decay=0.45):
    y = x.copy()
    for k, d in enumerate(times):
        i = int(d * SR)
        g = amount * decay ** k
        y[i:] += x[:-i] * g
    return y


def write(name, x, quality=3):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * 0.89
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", str(quality), dst], check=True)
    os.remove(path)
    print("%-16s %6.1f s  %4d KB" % (name, len(x) / SR, os.path.getsize(dst) // 1024))


# ---------------------------------------------------------------------------
# Música
# ---------------------------------------------------------------------------
def music_menu():
    """Portada: acordes graves en re menor y una cuerda pulsada que arpegia."""
    bar = 4.0
    chords = [[38, 50, 53, 57], [34, 46, 50, 53], [31, 43, 46, 50], [33, 45, 49, 52]]  # Dm Bb Gm A
    total = bar * 8 + 2.0
    x = np.zeros(int(total * SR))
    for i in range(8):
        c = chords[i % 4]
        add(x, pad(c, bar + 2.0, cutoff=700, amp=0.22), i * bar)
        arp = [c[1] + 12, c[2] + 12, c[3] + 12, c[2] + 12]
        for k, n in enumerate(arp):
            if (i + k) % 3 != 2:
                add(x, pluck(n, 1.8, 0.11), i * bar + 0.5 + k * 0.75)
    x = reverb(x, 0.35)
    return seamless(x, 2.0)


def music_explore():
    """Exploración: pulso grave a 84 ppm, reloj que marca y notas sueltas."""
    bpm = 84
    beat = 60 / bpm
    bars = 8
    total = beat * 4 * bars + 2.0
    x = np.zeros(int(total * SR))
    roots = [38, 38, 34, 36]
    for b in range(bars):
        r = roots[b % 4]
        add(x, pad([r, r + 7, r + 15], beat * 4 + 2.0, cutoff=500, amp=0.16), b * beat * 4)
        for q in range(4):
            at = (b * 4 + q) * beat
            add(x, kick(0.28, f0=80, f1=38), at)
            add(x, tick(0.05), at + beat * 0.5)
            add(x, tick(0.03), at)
        if b % 2 == 1:
            add(x, pluck(r + 26, 2.0, 0.08), b * beat * 4 + beat * 2.5)
    x = reverb(x, 0.25)
    return seamless(x, 2.0)


def music_chase():
    """Persecución: 120 ppm, bombo y cuerdas cortas insistentes."""
    bpm = 120
    beat = 60 / bpm
    bars = 8
    total = beat * 4 * bars + 1.0
    x = np.zeros(int(total * SR))
    roots = [38, 38, 39, 36]
    for b in range(bars):
        r = roots[b % 4]
        add(x, pad([r, r + 12, r + 15], beat * 4 + 1.0, cutoff=1400, amp=0.12), b * beat * 4)
        for e in range(8):
            at = (b * 8 + e) * beat * 0.5
            t = t_axis(beat * 0.4)
            note = midi(r + 24 + (3 if e % 4 == 3 else 0))
            stab = saw(note, t) * np.exp(-t * 9) * 0.12
            add(x, lowpass_fast(stab, 2200), at)
            if e % 2 == 0:
                add(x, kick(0.45, f0=120, f1=45), at)
            add(x, tick(0.04, cutoff=8000), at + beat * 0.25)
    x = reverb(x, 0.2)
    return seamless(x, 1.0)


def ambient_city():
    """Ciudad al atardecer: rumor de tráfico, carros que pasan y pájaros."""
    sec = 40.0
    t = t_axis(sec)
    noise = rng.normal(0, 1, len(t))
    rumble = lowpass_fast(noise, 120) * 6
    swell = 0.7 + 0.3 * np.sin(2 * np.pi * t / sec * 3)
    x = rumble * swell
    # Carros que pasan: ruido filtrado que crece y se va.
    for at in (3.0, 11.5, 19.0, 27.5, 34.0):
        d = rng.uniform(3.0, 5.0)
        tt = t_axis(d)
        car = lowpass_fast(rng.normal(0, 1, len(tt)), rng.uniform(300, 600)) * 3
        car *= np.sin(np.pi * tt / d) ** 2
        add(x, car * rng.uniform(0.5, 0.9), at)
    # Pájaros: trinos cortos y agudos.
    for _ in range(26):
        at = rng.uniform(0, sec - 1)
        f0 = rng.uniform(2600, 4200)
        for k in range(rng.integers(2, 5)):
            tt = t_axis(0.09)
            f = f0 + 900 * np.sin(np.pi * tt / 0.09)
            chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.09) ** 2
            add(x, chirp * 0.06, at + k * 0.13)
    return seamless(x, 3.0)


def ambient_rain():
    """Aguacero: ruido rosado filtrado, gotas sueltas y algún trueno lejano."""
    sec = 30.0
    t = t_axis(sec)
    noise = rng.normal(0, 1, len(t))
    hiss = (lowpass_fast(noise, 4500) - lowpass_fast(noise, 600)) * 0.35
    body = lowpass_fast(rng.normal(0, 1, len(t)), 900) * 1.2
    x = (hiss + body) * (0.85 + 0.15 * np.sin(2 * np.pi * t / sec * 2))
    for _ in range(220):
        at = rng.uniform(0, sec - 0.1)
        add(x, tick(rng.uniform(0.03, 0.09), 0.03, rng.uniform(2500, 7000)), at)
    for at in (6.0, 21.0):
        d = 4.0
        tt = t_axis(d)
        thunder = lowpass_fast(rng.normal(0, 1, len(tt)), 140) * 5 * np.exp(-tt * 1.1) * np.minimum(1, tt * 6)
        add(x, thunder, at)
    return seamless(x, 3.0)


# ---------------------------------------------------------------------------
# Efectos
# ---------------------------------------------------------------------------
def tone(f, sec, amp=0.3, decay=6.0, harm=(1.0, 0.3, 0.12)):
    t = t_axis(sec)
    y = sum(a * np.sin(2 * np.pi * f * (k + 1) * t) for k, a in enumerate(harm))
    return y * np.exp(-t * decay) * amp * env_adsr(len(t), a=0.004, d=0.0, s=1.0, r=0.02)


def seq(parts):
    total = max(at + len(s) / SR for at, s in parts)
    x = np.zeros(int(total * SR) + 1)
    for at, s in parts:
        add(x, s, at)
    return x


def sfx_all():
    out = {}
    out["click"] = seq([(0.0, tick(0.5, 0.04, 5000)), (0.0, tone(1400, 0.05, 0.15, 60))])
    out["hover"] = tone(2200, 0.03, 0.06, 90, (1.0,))
    out["key"] = tone(1180, 0.08, 0.25, 30, (1.0, 0.2))
    out["pickup"] = reverb(seq([(0.0, tone(midi(74), 0.5, 0.3)), (0.08, tone(midi(78), 0.5, 0.3)),
                                (0.16, tone(midi(81), 0.8, 0.3, 4))]), 0.3)
    out["discover"] = reverb(seq([(0.0, tone(midi(69), 1.4, 0.25, 2.5)), (0.12, tone(midi(76), 1.3, 0.22, 2.5)),
                                  (0.24, tone(midi(81), 1.2, 0.2, 2.5)), (0.36, tone(midi(88), 1.1, 0.15, 3))]), 0.4)
    clack = seq([(0.0, kick(0.5, 0.12, 400, 120)), (0.0, tick(0.6, 0.06, 3000))])
    out["unlock"] = reverb(seq([(0.0, clack), (0.18, clack * 0.7), (0.32, tone(midi(79), 0.9, 0.25, 3)),
                                (0.42, tone(midi(86), 0.9, 0.22, 3))]), 0.3)
    buzz_t = t_axis(0.16)
    buzz = lowpass_fast(saw(110, buzz_t), 900) * 0.4 * env_adsr(len(buzz_t), 0.005, 0, 1, 0.03)
    out["error"] = seq([(0.0, buzz), (0.2, buzz)])
    out["hint"] = reverb(seq([(0.0, tone(midi(84), 1.0, 0.2, 3.5)), (0.14, tone(midi(91), 1.0, 0.14, 3.5))]), 0.4)
    out["open"] = lowpass_fast(rng.normal(0, 1, int(0.25 * SR)), 1800) * np.sin(np.linspace(0, np.pi, int(0.25 * SR))) * 0.5
    out["alert"] = seq([(0.0, tone(988, 0.16, 0.25, 4, (1.0, 0.5))), (0.18, tone(784, 0.2, 0.25, 4, (1.0, 0.5)))])
    st = t_axis(1.4)
    stab = sum(lowpass_fast(saw(midi(n), st), 1200) for n in (38, 41, 44)) * np.exp(-st * 2.2) * 0.25
    out["caught"] = reverb(seq([(0.0, stab), (0.0, kick(0.8, 0.8, 90, 30))]), 0.3)
    win = seq([(0.0, pad([50, 57, 62, 66], 3.0, 1500, 0.3))] +
              [(0.1 + k * 0.12, tone(midi(n), 1.6, 0.22, 2.0)) for k, n in enumerate([62, 66, 69, 74, 78, 81])])
    out["win"] = reverb(win, 0.4)
    out["lose"] = reverb(seq([(k * 0.28, tone(midi(n), 1.0, 0.25, 3)) for k, n in enumerate([62, 61, 58, 53])]), 0.35)
    # Movimiento: salto, aterrizaje y deslizada (ruido filtrado con envolvente corta).
    def whoosh(sec, f0, f1, amp):
        n = int(sec * SR)
        tt = np.arange(n) / SR
        cut = np.linspace(f0, f1, n)
        w = np.zeros(n)
        raw = rng.normal(0, 1, n)
        for i in range(0, n, 256):
            w[i:i + 256] = lowpass_fast(raw[i:i + 256], cut[i])
        return w * np.sin(np.pi * tt / sec) * amp
    out["jump"] = seq([(0.0, whoosh(0.18, 800, 2400, 0.5)), (0.0, kick(0.25, 0.08, 220, 120))])
    out["land"] = seq([(0.0, kick(0.6, 0.18, 120, 50)), (0.0, tick(0.3, 0.06, 1500))])
    out["slide"] = whoosh(0.6, 2200, 700, 0.45)
    out["throw"] = whoosh(0.22, 600, 3000, 0.45)
    can_t = t_axis(0.5)
    can = sum(np.sin(2 * np.pi * f * can_t) * np.exp(-can_t * d) for f, d in ((1320, 9), (2210, 12), (3410, 16))) * 0.18
    out["can"] = seq([(0.0, tick(0.6, 0.03, 7000)), (0.0, can), (0.16, can * 0.5), (0.27, can * 0.25)])
    out["coin"] = reverb(seq([(0.0, tone(midi(88), 0.25, 0.25, 10)), (0.07, tone(midi(93), 0.6, 0.25, 5))]), 0.25)
    out["alarm"] = seq([(k * 0.32, tone(1100 if k % 2 == 0 else 820, 0.3, 0.22, 1.5, (1.0, 0.6, 0.3))) for k in range(6)])
    out["levelup"] = reverb(seq([(k * 0.1, tone(midi(n), 1.2, 0.22, 2.5)) for k, n in enumerate([67, 71, 74, 79, 83, 86])]), 0.45)
    out["checkpoint"] = reverb(seq([(0.0, tone(midi(76), 0.7, 0.25, 4)), (0.1, tone(midi(83), 0.9, 0.22, 3.5))]), 0.35)
    out["achievement"] = reverb(seq([(0.0, pad([60, 64, 67, 72], 1.8, 1800, 0.2))] +
                                    [(0.05 + k * 0.09, tone(midi(n), 1.0, 0.2, 3)) for k, n in enumerate([72, 76, 79, 84])]), 0.45)
    out["camera"] = seq([(0.0, tick(0.7, 0.03, 6000)), (0.05, kick(0.3, 0.05, 900, 400)), (0.09, tick(0.4, 0.05, 3000))])
    out["buy"] = reverb(seq([(0.0, tick(0.4, 0.03, 5000)), (0.03, tone(midi(81), 0.3, 0.2, 8)),
                             (0.1, tone(midi(86), 0.6, 0.22, 5))]), 0.3)
    return out


# ---------------------------------------------------------------------------
# Versión 0.6: la gran huida
# ---------------------------------------------------------------------------
def music_finale():
    """Huida final: 132 ppm, bajo en re que sube por terceras y un motivo de
    cuerda pulsada que se repite; más brillante que la persecución."""
    bpm = 132
    beat = 60 / bpm
    bars = 8
    total = beat * 4 * bars + 1.5
    x = np.zeros(int(total * SR))
    roots = [38, 41, 43, 45]
    for b in range(bars):
        r = roots[b % 4]
        add(x, pad([r + 12, r + 19, r + 24], beat * 4 + 1.5, cutoff=1800, amp=0.1), b * beat * 4)
        for e in range(8):
            at = (b * 8 + e) * beat * 0.5
            t = t_axis(beat * 0.45)
            bass = saw(midi(r + (12 if e % 2 else 0)), t) * np.exp(-t * 7) * 0.16
            add(x, lowpass_fast(bass, 900), at)
            if e % 2 == 0:
                add(x, kick(0.5, f0=130, f1=45), at)
            if e in (2, 6):
                snare = lowpass_fast(rng.normal(0, 1, int(0.18 * SR)), 4500) * np.exp(-t_axis(0.18) * 18) * 0.35
                add(x, snare, at)
            add(x, tick(0.035, cutoff=9000), at + beat * 0.25)
        motif = [r + 26, r + 29, r + 31, r + 33]
        for k, n in enumerate(motif):
            add(x, pluck(n, 1.2, 0.09, 0.7), b * beat * 4 + k * beat)
    x = reverb(x, 0.22)
    return seamless(x, 1.5)


def loop_drone():
    """Zumbido de dron: hélices (tono que ondula) más ruido de aire."""
    sec = 4.0
    t = t_axis(sec)
    wob = 1 + 0.02 * np.sin(2 * np.pi * 0.5 * t)
    buzz = sum(np.sin(2 * np.pi * f * wob * t) * a for f, a in ((180, 0.4), (360, 0.25), (540, 0.12), (720, 0.06)))
    air = lowpass_fast(rng.normal(0, 1, len(t)), 1800) * 0.5
    return seamless(buzz * 0.5 + air, 0.5)


def loop_zipline():
    """Roldana sobre el cable: silbido metálico que vibra."""
    sec = 2.0
    t = t_axis(sec)
    hiss = lowpass_fast(rng.normal(0, 1, len(t)), 5000) * 0.5
    whine = np.sin(2 * np.pi * (880 + 40 * np.sin(2 * np.pi * 9 * t)) * t) * 0.12
    return seamless(hiss + whine, 0.3)


def sfx_v06():
    out = {}
    def noise_burst(sec, cutoff, decay, amp):
        n = int(sec * SR)
        return lowpass_fast(rng.normal(0, 1, n), cutoff) * np.exp(-np.arange(n) / SR * decay) * amp
    out["step"] = seq([(0.0, noise_burst(0.09, 1400, 40, 0.6)), (0.0, kick(0.25, 0.07, 140, 70))])
    out["roll"] = seq([(0.0, noise_burst(0.45, 900, 6, 0.5)), (0.0, kick(0.4, 0.15, 110, 45)), (0.25, kick(0.25, 0.12, 90, 40))])
    out["thud"] = reverb(seq([(0.0, kick(0.9, 0.5, 90, 30)), (0.0, noise_burst(0.3, 700, 10, 0.6))]), 0.2)
    out["zone"] = reverb(seq([(0.0, pad([62, 69, 74], 2.0, 1400, 0.16))] +
                             [(0.1 + k * 0.16, tone(midi(n), 1.4, 0.16, 2.2)) for k, n in enumerate([74, 81, 86])]), 0.5)
    hit_t = t_axis(2.0)
    boom = sum(lowpass_fast(saw(midi(n), hit_t), 600) for n in (26, 33, 38)) * np.exp(-hit_t * 1.4) * 0.22
    out["cinematic"] = reverb(seq([(0.0, boom), (0.0, kick(1.0, 1.2, 70, 25)), (0.0, noise_burst(1.2, 3000, 3, 0.25))]), 0.45)
    out["drone_alert"] = seq([(k * 0.14, tone(1500 if k % 2 == 0 else 1900, 0.12, 0.22, 6, (1.0, 0.4))) for k in range(5)])
    clunk = seq([(0.0, kick(0.6, 0.15, 300, 90)), (0.0, tick(0.5, 0.06, 2500))])
    out["safe"] = reverb(seq([(0.0, clunk), (0.25, clunk * 0.8), (0.5, clunk * 0.6),
                              (0.8, tone(midi(74), 1.0, 0.22, 3)), (0.95, tone(midi(81), 1.0, 0.2, 3))]), 0.3)
    out["zip_start"] = seq([(0.0, tick(0.6, 0.05, 6000)), (0.02, kick(0.4, 0.1, 500, 200))])
    return out


def main_v06():
    os.makedirs(OUT, exist_ok=True)
    write("music_finale", music_finale(), 3)
    write("loop_drone", loop_drone(), 3)
    write("loop_zipline", loop_zipline(), 3)
    for name, x in sfx_v06().items():
        write("sfx_" + name, x, 4)


def main():
    os.makedirs(OUT, exist_ok=True)
    write("music_menu", music_menu(), 3)
    write("music_explore", music_explore(), 3)
    write("music_chase", music_chase(), 3)
    write("ambient_city", ambient_city(), 2)
    write("ambient_rain", ambient_rain(), 2)
    for name, x in sfx_all().items():
        write("sfx_" + name, x, 4)
    main_v06()


if __name__ == "__main__":
    import sys
    # --v06: solo los sonidos nuevos de la versión 0.6 (no reescribe los demás).
    if "--v06" in sys.argv:
        main_v06()
    else:
        main()
