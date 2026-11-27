# -*- coding: utf-8 -*-
"""Genera los efectos de sonido y la música del juego por síntesis (sin grabaciones ajenas).

Salidas en sounds/ (WAV mono de 16 bits; Godot los importa y comprime):
  efectos: roll (bucle), hit, land, fall, zap, respawn, beep, go, tick, win, lose, star,
           click, achievement, launch
  música:  music_menu, music_game (bucles sin cortes)

El resultado es siempre el mismo (semilla fija), así que se puede volver a generar sin
que cambien los archivos. Uso: python tools/make_sounds.py
"""
import os
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "sounds")
SFX_RATE = 44100
MUSIC_RATE = 32000
rng = np.random.default_rng(2026)


# --- Utilidades ----------------------------------------------------------------

def t_axis(seconds, rate):
    return np.arange(int(seconds * rate)) / rate


def save(name, data, rate, peak=0.9):
    data = np.asarray(data, dtype=np.float64)
    top = np.max(np.abs(data))
    if top > 0:
        data = data / top * peak
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def fade(data, rate, fade_in=0.002, fade_out=0.01):
    data = data.copy()
    a = max(1, int(fade_in * rate))
    b = max(1, int(fade_out * rate))
    data[:a] *= np.linspace(0, 1, a)
    data[-b:] *= np.linspace(1, 0, b)
    return data


def lowpass(data, rate, cutoff):
    """Filtro paso bajo en frecuencia (suave, sin desfase)."""
    spec = np.fft.rfft(data)
    freqs = np.fft.rfftfreq(len(data), 1 / rate)
    spec *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spec, len(data))


def bandpass(data, rate, center, width):
    spec = np.fft.rfft(data)
    freqs = np.fft.rfftfreq(len(data), 1 / rate)
    spec *= np.exp(-((freqs - center) / width) ** 2)
    return np.fft.irfft(spec, len(data))


def highpass(data, rate, cutoff):
    spec = np.fft.rfft(data)
    freqs = np.fft.rfftfreq(len(data), 1 / rate)
    spec *= 1 / (1 + (cutoff / np.maximum(freqs, 1)) ** 4)
    return np.fft.irfft(spec, len(data))


def bell(freq, seconds, rate, decay=1.0):
    t = t_axis(seconds, rate)
    partials = [(1.0, 1.0, 1.0), (2.76, 0.45, 0.6), (5.4, 0.25, 0.35), (8.9, 0.12, 0.2)]
    out = np.zeros_like(t)
    for ratio, amp, d in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (decay * d))
    return fade(out, rate, 0.001, 0.02)


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def reverb(data, rate, seconds=1.6, mix=0.25):
    """Reverberación por convolución con ruido que decae (sala pequeña y suave)."""
    n = int(seconds * rate)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / rate * 4.0 / seconds)
    ir = lowpass(ir, rate, 4000)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = len(data) + n
    wet = np.fft.irfft(np.fft.rfft(data, size) * np.fft.rfft(ir, size), size)
    dry = np.concatenate([data, np.zeros(n)])
    return dry * (1 - mix) + wet * mix


# --- Efectos -------------------------------------------------------------------

def make_roll():
    # Bucle de 1 s: ruido marrón filtrado (rodar sobre baldosas) con un leve traqueteo.
    # Se genera en frecuencia, así que empieza y acaba igual (bucle sin chasquido).
    rate = SFX_RATE
    n = rate
    spec = rng.standard_normal(n // 2 + 1) + 1j * rng.standard_normal(n // 2 + 1)
    freqs = np.fft.rfftfreq(n, 1 / rate)
    shape = np.exp(-((freqs - 220) / 180) ** 2) + 0.35 * np.exp(-((freqs - 900) / 400) ** 2)
    spec *= shape
    spec[0] = 0
    noise = np.fft.irfft(spec, n)
    t = np.arange(n) / rate
    rattle = 1 + 0.25 * np.sin(2 * np.pi * 12 * t) + 0.15 * np.sin(2 * np.pi * 31 * t)
    save("roll", noise * rattle, rate, 0.8)


def make_hit():
    # "Clac" de canica de cristal: parciales agudos inarmónicos que se apagan muy rápido.
    rate = SFX_RATE
    t = t_axis(0.35, rate)
    out = np.zeros_like(t)
    for f, a, d in [(2350, 1.0, 0.06), (3720, 0.6, 0.04), (5150, 0.35, 0.025), (1180, 0.4, 0.05)]:
        out += a * np.sin(2 * np.pi * f * t) * np.exp(-t / d)
    click = highpass(rng.standard_normal(len(t)), rate, 2500) * np.exp(-t / 0.004)
    save("hit", fade(out + 0.6 * click, rate, 0.0005, 0.02), rate)


def make_land():
    rate = SFX_RATE
    t = t_axis(0.3, rate)
    thump = np.sin(2 * np.pi * (140 * t - 60 * t ** 2)) * np.exp(-t / 0.06)
    noise = lowpass(rng.standard_normal(len(t)), rate, 700) * np.exp(-t / 0.03)
    save("land", fade(thump + 0.8 * noise, rate, 0.001, 0.03), rate)


def make_fall():
    # Silbido que baja (caída al vacío).
    rate = SFX_RATE
    t = t_axis(0.9, rate)
    freq = 950 * np.exp(-t * 2.0) + 150
    phase = 2 * np.pi * np.cumsum(freq) / rate
    tone = np.sin(phase) + 0.3 * np.sin(2 * phase)
    env = np.minimum(t / 0.05, 1) * np.exp(-t * 1.8)
    air = bandpass(rng.standard_normal(len(t)), rate, 1200, 600) * 0.15
    save("fall", fade((tone + air) * env, rate, 0.002, 0.08), rate, 0.75)


def make_zap():
    # Chisporroteo (ácido, atrapado por un enemigo): ruido con burbujas y un tono que baja.
    rate = SFX_RATE
    t = t_axis(0.6, rate)
    hiss = highpass(rng.standard_normal(len(t)), rate, 1800)
    bubbles = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 23 * t))
    tone = np.sin(2 * np.pi * np.cumsum(520 * np.exp(-t * 3) + 90) / rate)
    env = np.exp(-t * 5)
    save("zap", fade((0.5 * hiss * bubbles + tone) * env, rate, 0.001, 0.05), rate, 0.7)


def make_respawn():
    rate = SFX_RATE
    t = t_axis(0.25, rate)
    freq = 400 + 900 * (t / t[-1]) ** 0.7
    tone = np.sin(2 * np.pi * np.cumsum(freq) / rate)
    env = np.minimum(t / 0.01, 1) * np.exp(-t * 9)
    save("respawn", fade(tone * env, rate), rate, 0.6)


def simple_tone(freq, seconds, decay, rate=SFX_RATE):
    t = t_axis(seconds, rate)
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(4 * np.pi * freq * t)
    return fade(tone * np.exp(-t / decay), rate, 0.003, 0.03)


def make_beeps():
    save("beep", simple_tone(660, 0.22, 0.12), SFX_RATE, 0.6)
    save("go", simple_tone(1320, 0.5, 0.25), SFX_RATE, 0.7)


def make_tick():
    # Taco de madera: tono corto con golpe de ruido.
    rate = SFX_RATE
    t = t_axis(0.12, rate)
    tone = np.sin(2 * np.pi * 1700 * t) * np.exp(-t / 0.018)
    knock = bandpass(rng.standard_normal(len(t)), rate, 2500, 900) * np.exp(-t / 0.006)
    save("tick", fade(tone + 0.7 * knock, rate, 0.0005, 0.01), rate, 0.55)


def make_win():
    # Fanfarria corta: arpegio de do mayor con campanas y un acorde final.
    rate = SFX_RATE
    total = np.zeros(int(2.4 * rate))
    for i, note in enumerate([72, 76, 79, 84]):
        start = int(i * 0.12 * rate)
        b = bell(midi(note), 1.6, rate, 0.9)
        total[start:start + len(b)] += b * (0.8 if i < 3 else 1.0)
    chord_start = int(0.48 * rate)
    for note in [60, 64, 67, 72]:
        t = t_axis(1.8, rate)
        pad = np.sin(2 * np.pi * midi(note) * t) * np.exp(-t / 0.9) * 0.35
        total[chord_start:chord_start + len(pad)] += fade(pad, rate, 0.02, 0.2)
    save("win", reverb(total, rate, 1.2, 0.2), rate)


def make_lose():
    rate = SFX_RATE
    total = np.zeros(int(1.3 * rate))
    for i, note in enumerate([67, 62]):
        t = t_axis(0.8, rate)
        f = midi(note)
        tone = (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * 2 * f * t)
                + 0.2 * np.sin(2 * np.pi * 3 * f * t)) * np.exp(-t / 0.35)
        start = int(i * 0.3 * rate)
        total[start:start + len(t)] += fade(tone, rate, 0.005, 0.1)
    save("lose", total, rate, 0.6)


def make_star():
    rate = SFX_RATE
    b = bell(midi(88), 1.0, rate, 0.5) + 0.5 * bell(midi(95), 1.0, rate, 0.3)
    save("star", reverb(b, rate, 0.8, 0.2), rate, 0.7)


def make_click():
    rate = SFX_RATE
    t = t_axis(0.06, rate)
    tone = np.sin(2 * np.pi * 1200 * t) * np.exp(-t / 0.012)
    save("click", fade(tone, rate, 0.0005, 0.01), rate, 0.4)


def make_achievement():
    # Brillo ascendente (logro conseguido).
    rate = SFX_RATE
    total = np.zeros(int(1.8 * rate))
    for i, note in enumerate([79, 83, 86, 91, 95]):
        start = int(i * 0.07 * rate)
        b = bell(midi(note), 1.2, rate, 0.5) * (0.6 + 0.1 * i)
        total[start:start + len(b)] += b
    save("achievement", reverb(total, rate, 1.0, 0.25), rate, 0.75)


# --- Música --------------------------------------------------------------------

def epiano(freq, seconds, rate, velocity=1.0):
    """Piano eléctrico por FM: ataque brillante que se suaviza."""
    t = t_axis(seconds, rate)
    index = 1.6 * np.exp(-t / 0.25)
    mod = np.sin(2 * np.pi * freq * t)
    out = np.sin(2 * np.pi * freq * t + index * mod) * np.exp(-t / 1.4)
    return fade(out * velocity, rate, 0.003, 0.08)


def pluck(freq, seconds, rate, bright=6):
    """Cuerda pulsada aditiva: los armónicos altos se apagan antes."""
    t = t_axis(seconds, rate)
    out = np.zeros_like(t)
    for h in range(1, bright + 1):
        if freq * h > rate / 2.5:
            break
        out += np.sin(2 * np.pi * freq * h * t) / h * np.exp(-t * (3 + 4 * h))
    return fade(out, rate, 0.002, 0.03)


def bass(freq, seconds, rate):
    t = t_axis(seconds, rate)
    out = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)
    env = np.minimum(t / 0.01, 1) * np.exp(-t / 0.5)
    return fade(out * env, rate, 0.003, 0.04)


def kick(rate):
    t = t_axis(0.3, rate)
    freq = 45 + 90 * np.exp(-t * 30)
    return fade(np.sin(2 * np.pi * np.cumsum(freq) / rate) * np.exp(-t / 0.12), rate, 0.001, 0.02)


def hat(rate, length=0.05):
    t = t_axis(length, rate)
    return fade(highpass(rng.standard_normal(len(t)), rate, 7000) * np.exp(-t / 0.012), rate, 0.0005, 0.005)


def place(buffer, sound, start):
    """Suma `sound` en `buffer` desde `start`; lo que se pasa del final vuelve al principio
    (así el bucle queda perfecto: las colas de notas y la reverberación continúan)."""
    n = len(buffer)
    for offset in range(0, len(sound), n):
        chunk = sound[offset:offset + n]
        s = (start + offset) % n
        first = min(len(chunk), n - s)
        buffer[s:s + first] += chunk[:first]
        if first < len(chunk):
            buffer[:len(chunk) - first] += chunk[first:]


def loop_reverb(buffer, rate, seconds, mix):
    wet = reverb(buffer, rate, seconds, 1.0)
    out = buffer * (1 - mix)
    place(out, wet * mix, 0)
    return out


def make_music_menu():
    # Tranquila, 84 pulsaciones: piano eléctrico, bajo suave y campanitas.
    rate = MUSIC_RATE
    bpm = 84
    beat = 60 / bpm
    chords = [  # Cmaj7, Am7, Fmaj7, G6 (x2) y luego Em7, Am7, Dm7, G7
        [48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 52, 59],
        [48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 52, 59],
        [40, 47, 50, 55], [45, 52, 55, 60], [38, 45, 48, 53], [43, 50, 53, 59],
        [41, 48, 52, 57], [43, 50, 52, 59], [48, 55, 59, 64], [43, 50, 53, 59],
    ]
    bars = len(chords)
    buffer = np.zeros(int(bars * 4 * beat * rate))
    melody_pattern = [(0, 2), (1.5, 3), (2, 1), (3, 2)]
    for bar, chord in enumerate(chords):
        bar_start = bar * 4 * beat
        root = chord[0]
        place(buffer, bass(midi(root - 12), 3.5 * beat, rate) * 0.55, int(bar_start * rate))
        place(buffer, bass(midi(root - 12 + 7), 0.9 * beat, rate) * 0.35, int((bar_start + 2.5 * beat) * rate))
        for i, note in enumerate(chord[1:]):
            place(buffer, epiano(midi(note + 12), 4 * beat, rate, 0.28), int((bar_start + i * 0.03) * rate))
        place(buffer, epiano(midi(chord[2] + 12), 2 * beat, rate, 0.18), int((bar_start + 2 * beat) * rate))
        if bar % 2 == 1 or bar >= 8:
            for pos, index in melody_pattern:
                note = chord[index % len(chord)] + 24
                place(buffer, bell(midi(note), 1.5, rate, 0.6) * 0.16, int((bar_start + pos * beat) * rate))
    buffer = loop_reverb(buffer, rate, 2.2, 0.3)
    save("music_menu", buffer, MUSIC_RATE, 0.55)


def make_music_game():
    # Más movida, 116 pulsaciones: bajo en corcheas, arpegio pulsado, bombo y charles suaves.
    rate = MUSIC_RATE
    bpm = 116
    beat = 60 / bpm
    chords = [  # Am, F, C, G (x2) y luego Dm, Am, F, E
        [45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [48, 55, 60, 64, 67], [43, 50, 55, 59, 62],
        [45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [48, 55, 60, 64, 67], [43, 50, 55, 59, 62],
        [38, 45, 50, 53, 57], [45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [40, 47, 52, 56, 59],
        [38, 45, 50, 53, 57], [45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [40, 47, 52, 56, 59],
    ]
    bars = len(chords)
    buffer = np.zeros(int(bars * 4 * beat * rate))
    k = kick(rate) * 0.5
    arp_order = [1, 2, 3, 4, 3, 2, 3, 4]
    for bar, chord in enumerate(chords):
        bar_start = bar * 4 * beat
        root = chord[0]
        for eighth in range(8):
            start = bar_start + eighth * beat / 2
            note = root - 12 if eighth % 4 != 3 else root - 12 + 12
            place(buffer, bass(midi(note), 0.45 * beat, rate) * 0.5, int(start * rate))
            place(buffer, pluck(midi(chord[arp_order[eighth]] + 12), 0.6, rate) * 0.22, int(start * rate))
            if eighth % 2 == 1:
                place(buffer, hat(rate) * 0.18, int(start * rate))
        for b in range(4):
            if b % 2 == 0:
                place(buffer, k, int((bar_start + b * beat) * rate))
            else:
                place(buffer, hat(rate, 0.12) * 0.25, int((bar_start + b * beat) * rate))
        if bar >= 8:
            # Segunda mitad: melodía de campanas por encima.
            for pos, index in [(0, 4), (1, 3), (1.5, 4), (2.5, 2), (3, 3)]:
                place(buffer, bell(midi(chord[index] + 12), 1.0, rate, 0.4) * 0.14,
                      int((bar_start + pos * beat) * rate))
    buffer = loop_reverb(buffer, rate, 1.4, 0.18)
    save("music_game", buffer, MUSIC_RATE, 0.55)


def make_launch():
    # Zas que sube: soplido que se aclara y un muelle (catapulta, plataformas de salto).
    rate = SFX_RATE
    t = t_axis(0.55, rate)
    sweep = 300 + 1400 * (t / t[-1]) ** 0.6
    noise = rng.standard_normal(len(t))
    air = np.zeros_like(t)
    # Ruido filtrado por tramos con el centro subiendo.
    pieces = 8
    for i in range(pieces):
        a, b = i * len(t) // pieces, (i + 1) * len(t) // pieces
        air[a:b] = bandpass(noise, rate, float(sweep[(a + b) // 2]), 500)[a:b]
    spring_freq = 180 + 520 * (1 - np.exp(-t * 9))
    spring = np.sin(2 * np.pi * np.cumsum(spring_freq) / rate) * np.exp(-t * 7) * 0.6
    env = np.minimum(t / 0.03, 1) * np.exp(-t * 3.5)
    save("launch", fade((air * 0.5 + spring) * env, rate, 0.001, 0.06), rate, 0.75)


def make_checkpoint():
    # Campanita suave de dos notas (mi y si agudos): punto de control nuevo.
    rate = SFX_RATE
    t = t_axis(0.4, rate)
    out = np.zeros_like(t)
    for start, freq in [(0.0, 1318.5), (0.07, 1975.5)]:
        k = np.clip(t - start, 0, None)
        on = (t >= start).astype(float)
        tone = np.sin(2 * np.pi * freq * k) + 0.25 * np.sin(2 * np.pi * freq * 2 * k)
        out += tone * on * np.minimum(k / 0.004, 1) * np.exp(-k * 11)
    save("checkpoint", fade(out * 0.5, rate, 0.001, 0.05), rate, 0.45)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for make in [make_roll, make_hit, make_land, make_fall, make_zap, make_respawn, make_beeps,
                 make_tick, make_win, make_lose, make_star, make_click, make_achievement,
                 make_music_menu, make_music_game, make_launch, make_checkpoint]:
        make()
    print("Sonidos generados en", os.path.normpath(OUT))
