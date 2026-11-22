# -*- coding: utf-8 -*-
"""Genera los iconos de los logros (512x512 PNG, sin transparencia) para Play Console y
App Store Connect. Salida: icon/achievements/<clave>.png (la clave es la de GameServices).

Se dibuja a 4x y se reduce para suavizar los bordes. Uso: python tools/make_achievement_icons.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "icon", "achievements")
SIZE = 512
S = 4  # sobremuestreo
W = SIZE * S
C = W / 2

BG_TOP = (52, 32, 110)
BG_BOTTOM = (22, 12, 52)
RING = (255, 205, 70)
RING_DARK = (190, 130, 30)
ACCENT = (115, 255, 230)
WHITE = (255, 255, 255)
GOLD = (255, 210, 80)
MARBLE = (120, 110, 255)


def background():
    img = Image.new("RGB", (W, W), BG_BOTTOM)
    draw = ImageDraw.Draw(img)
    for y in range(W):
        t = y / W
        color = tuple(int(BG_TOP[i] * (1 - t) + BG_BOTTOM[i] * t) for i in range(3))
        draw.line([(0, y), (W, y)], fill=color)
    # Medalla: anillo dorado con disco interior.
    r = W * 0.44
    draw.ellipse([C - r, C - r, C + r, C + r], fill=RING_DARK)
    r2 = W * 0.425
    draw.ellipse([C - r2, C - r2, C + r2, C + r2], fill=RING)
    r3 = W * 0.37
    draw.ellipse([C - r3, C - r3, C + r3, C + r3], fill=(40, 26, 92))
    return img, draw


def star_points(cx, cy, outer, inner=None, points=5, rotation=-math.pi / 2):
    inner = inner or outer * 0.45
    out = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = rotation + i * math.pi / points
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def marble(draw, cx, cy, r, color=MARBLE):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    hr = r * 0.32
    draw.ellipse([cx - r * 0.45 - hr, cy - r * 0.45 - hr, cx - r * 0.45 + hr, cy - r * 0.45 + hr],
                 fill=(225, 225, 255))


def first_goal(draw):
    # Bandera de meta a cuadros.
    pole_x = C - W * 0.14
    draw.rectangle([pole_x - W * 0.012, C - W * 0.24, pole_x + W * 0.012, C + W * 0.25], fill=WHITE)
    cell = W * 0.06
    for row in range(3):
        for col in range(5):
            color = WHITE if (row + col) % 2 == 0 else (20, 20, 30)
            x = pole_x + col * cell
            y = C - W * 0.23 + row * cell
            draw.rectangle([x, y, x + cell, y + cell], fill=color)
    marble(draw, C + W * 0.1, C + W * 0.17, W * 0.08)


def three_stars(draw):
    for dx, dy, r in [(-0.17, 0.06, 0.12), (0.17, 0.06, 0.12), (0, -0.06, 0.16)]:
        draw.polygon(star_points(C + dx * W, C + dy * W, r * W), fill=GOLD, outline=RING_DARK)


def beat_ghost(draw):
    # La canica fantasma (translúcida, como en el juego) y la tuya adelantándola.
    gx, gy, gr = C + W * 0.1, C - W * 0.06, W * 0.12
    draw.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=(95, 88, 165), outline=(190, 190, 255),
                 width=int(W * 0.012))
    draw.ellipse([gx - gr * 0.6, gy - gr * 0.6, gx - gr * 0.2, gy - gr * 0.2], fill=(150, 150, 220))
    for i in range(3):
        y = C + W * (0.06 + i * 0.05)
        draw.rounded_rectangle([C - W * 0.3, y - W * 0.008, C - W * 0.19 - i * W * 0.03, y + W * 0.008],
                               radius=W * 0.008, fill=ACCENT)
    marble(draw, C - W * 0.07, C + W * 0.11, W * 0.11)


def steady_hand(draw):
    # Canica sobre una pasarela estrecha.
    draw.polygon([(C - W * 0.3, C + W * 0.12), (C + W * 0.3, C + W * 0.12),
                  (C + W * 0.26, C + W * 0.17), (C - W * 0.26, C + W * 0.17)], fill=ACCENT)
    draw.rectangle([C - W * 0.03, C + W * 0.17, C + W * 0.03, C + W * 0.28], fill=(80, 200, 190))
    marble(draw, C, C + W * 0.0, W * 0.11)


def close_call(draw):
    # Reloj de arena con muy poca arena arriba.
    top, bottom, half = C - W * 0.22, C + W * 0.22, W * 0.15
    draw.rectangle([C - half - W * 0.03, top - W * 0.03, C + half + W * 0.03, top], fill=GOLD)
    draw.rectangle([C - half - W * 0.03, bottom, C + half + W * 0.03, bottom + W * 0.03], fill=GOLD)
    glass = (200, 230, 255)
    draw.polygon([(C - half, top), (C + half, top), (C + W * 0.02, C), (C - W * 0.02, C)], fill=glass)
    draw.polygon([(C - W * 0.02, C), (C + W * 0.02, C), (C + half, bottom), (C - half, bottom)], fill=glass)
    sand = (255, 190, 80)
    draw.polygon([(C - W * 0.035, C - W * 0.03), (C + W * 0.035, C - W * 0.03), (C, C)], fill=sand)
    draw.rectangle([C - W * 0.006, C, C + W * 0.006, bottom - W * 0.08], fill=sand)
    draw.polygon([(C - half + W * 0.01, bottom), (C + half - W * 0.01, bottom), (C, bottom - W * 0.1)], fill=sand)


def wifi_win(draw):
    # Ondas de wifi y una corona encima de una canica.
    cx, cy = C, C + W * 0.16
    for i, r in enumerate([0.12, 0.2, 0.28]):
        rr = r * W
        draw.arc([cx - rr, cy - rr, cx + rr, cy + rr], 225, 315, fill=ACCENT, width=int(W * 0.035))
    marble(draw, cx, cy, W * 0.06)
    crown_y = C - W * 0.2
    pts = [(C - W * 0.14, crown_y + W * 0.08), (C - W * 0.14, crown_y - W * 0.03), (C - W * 0.07, crown_y + W * 0.02),
           (C, crown_y - W * 0.07), (C + W * 0.07, crown_y + W * 0.02), (C + W * 0.14, crown_y - W * 0.03),
           (C + W * 0.14, crown_y + W * 0.08)]
    draw.polygon(pts, fill=GOLD, outline=RING_DARK)


def all_levels(draw):
    # Copa.
    draw.pieslice([C - W * 0.17, C - W * 0.3, C + W * 0.17, C + W * 0.06], 0, 180, fill=GOLD)
    draw.rectangle([C - W * 0.17, C - W * 0.21, C + W * 0.17, C - W * 0.12], fill=GOLD)
    for side in (-1, 1):
        x = C + side * W * 0.2
        draw.arc([x - W * 0.07, C - W * 0.2, x + W * 0.07, C - W * 0.04], 0, 360, fill=GOLD, width=int(W * 0.025))
    draw.rectangle([C - W * 0.03, C + W * 0.05, C + W * 0.03, C + W * 0.16], fill=GOLD)
    draw.rounded_rectangle([C - W * 0.13, C + W * 0.16, C + W * 0.13, C + W * 0.22], radius=W * 0.015, fill=RING_DARK)


def all_stars(draw):
    draw.polygon(star_points(C, C + W * 0.01, W * 0.27, W * 0.12), fill=GOLD, outline=RING_DARK)
    for a in range(8):
        ang = a * math.pi / 4 + math.pi / 8
        x, y = C + math.cos(ang) * W * 0.31, C + math.sin(ang) * W * 0.31
        draw.polygon(star_points(x, y, W * 0.025), fill=WHITE)


ICONS = {
    "first_goal": first_goal, "three_stars": three_stars, "beat_ghost": beat_ghost,
    "steady_hand": steady_hand, "close_call": close_call, "wifi_win": wifi_win,
    "all_levels": all_levels, "all_stars": all_stars,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for key, paint in ICONS.items():
        img, draw = background()
        paint(draw)
        img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        img.save(os.path.join(OUT, key + ".png"), optimize=True)
    print("Iconos en", os.path.normpath(OUT))
