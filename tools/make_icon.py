# -*- coding: utf-8 -*-
"""Genera el icono del juego en SVG (lienzo de 1024x1024).

Salidas en icon/ (luego tools/render_icons.gd las convierte a PNG):
  icon_full.svg        icono completo, cuadrado y sin transparencias (App Store, icono del proyecto)
  icon_background.svg  capa de fondo del icono adaptable de Android (fondo + pista)
  icon_foreground.svg  capa delantera del icono adaptable (canica + líneas de velocidad)
  icon_monochrome.svg  silueta para los iconos temáticos de Android 13+

La canica va centrada en el lienzo para que, al separar fondo y primer plano
(icono adaptable de Android), las dos capas coincidan.

Uso: python tools/make_icon.py
"""
import io
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "icon")

# Vectores isométricos: U avanza por la pista (hacia arriba a la derecha), V la cruza.
U = (78.0, -45.0)
V = (78.0, 45.0)
# Esquina de la baldosa (0, 0). Elegida para que, en x = 512, el borde trasero de la pista
# quede en y ≈ 405 y el delantero en y ≈ 675 (cada baldosa a lo ancho baja 90 px).
TRACK_ORIGIN = (-60.0, 735.0)
TRACK_FIRST = -3
TRACK_LAST = 17
TRACK_WIDTH = 3
SIDE_DEPTH = 70.0

MARBLE = (512.0, 440.0)
MARBLE_R = 200.0


def pt(i, j):
    return (TRACK_ORIGIN[0] + U[0] * i + V[0] * j, TRACK_ORIGIN[1] + U[1] * i + V[1] * j)


def poly(points, fill):
    return '<polygon points="%s" fill="%s"/>' % (" ".join("%.1f,%.1f" % p for p in points), fill)


def defs():
    return """<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#3a2478"/>
    <stop offset="1" stop-color="#140a33"/>
  </linearGradient>
  <radialGradient id="halo" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#7fd8ff" stop-opacity="0.5"/>
    <stop offset="1" stop-color="#7fd8ff" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="glass" cx="0.36" cy="0.3" r="0.78">
    <stop offset="0" stop-color="#f4fbff"/>
    <stop offset="0.28" stop-color="#8fd0ff"/>
    <stop offset="0.7" stop-color="#2f6fe0"/>
    <stop offset="1" stop-color="#15297a"/>
  </radialGradient>
  <radialGradient id="shadow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#0a0520" stop-opacity="0.7"/>
    <stop offset="1" stop-color="#0a0520" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="swirl" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ffb347"/>
    <stop offset="1" stop-color="#ff5e7e"/>
  </linearGradient>
  <clipPath id="ball"><circle cx="%.1f" cy="%.1f" r="%.1f"/></clipPath>
</defs>""" % (MARBLE[0], MARBLE[1], MARBLE_R)


def background():
    return ('<rect width="1024" height="1024" fill="url(#bg)"/>'
            '<circle cx="%.1f" cy="%.1f" r="440" fill="url(#halo)"/>' % (MARBLE[0], MARBLE[1]))


def track():
    parts = []
    # Lateral del bloque, bajo el borde delantero
    for i in range(TRACK_FIRST, TRACK_LAST):
        a, b = pt(i, TRACK_WIDTH), pt(i + 1, TRACK_WIDTH)
        shade = "#3b2d7a" if i % 2 == 0 else "#33276c"
        parts.append(poly([a, b, (b[0], b[1] + SIDE_DEPTH), (a[0], a[1] + SIDE_DEPTH)], shade))
    # Baldosas del damero
    for i in range(TRACK_FIRST, TRACK_LAST):
        for j in range(TRACK_WIDTH):
            color = "#ece8ff" if (i + j) % 2 == 0 else "#a99cf0"
            parts.append(poly([pt(i, j), pt(i + 1, j), pt(i + 1, j + 1), pt(i, j + 1)], color))
    # Bordes luminosos
    for j in (0, TRACK_WIDTH):
        a, b = pt(TRACK_FIRST, j), pt(TRACK_LAST, j)
        parts.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#9ff5ff" stroke-width="7" stroke-linecap="round"/>'
                     % (a[0], a[1], b[0], b[1]))
    return "\n".join(parts)


def speed_lines(color="#c9f7ff", opacity=(0.95, 0.8, 0.6)):
    """Estelas en sentido contrario al avance (-U), saliendo de detrás de la canica."""
    length_u = (U[0] ** 2 + U[1] ** 2) ** 0.5
    ux, uy = U[0] / length_u, U[1] / length_u
    px, py = -uy, ux  # perpendicular en pantalla
    lines = []
    for k, (offset, length, width) in enumerate([(-120, 250, 24), (-10, 330, 28), (100, 210, 22)]):
        sx = MARBLE[0] - ux * MARBLE_R * 0.8 + px * offset
        sy = MARBLE[1] - uy * MARBLE_R * 0.8 + py * offset
        lines.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-opacity="%.2f" stroke-width="%d" stroke-linecap="round"/>'
                     % (sx, sy, sx - ux * length, sy - uy * length, color, opacity[k], width))
    return "\n".join(lines)


def swirl(shift, color, width):
    """Franja curva dentro del cristal, desplazada `shift` radios hacia abajo."""
    cx, cy, r = MARBLE[0], MARBLE[1], MARBLE_R
    dy = r * shift
    return ('<path d="M %.1f %.1f C %.1f %.1f, %.1f %.1f, %.1f %.1f S %.1f %.1f, %.1f %.1f" '
            'fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-opacity="0.9"/>'
            % (cx - r * 1.05, cy + r * 0.1 + dy,
               cx - r * 0.5, cy - r * 0.45 + dy, cx - r * 0.05, cy + r * 0.55 + dy, cx + r * 0.4, cy + dy,
               cx + r * 0.85, cy - r * 0.55 + dy, cx + r * 1.1, cy - r * 0.35 + dy,
               color, r * width))


def marble():
    cx, cy, r = MARBLE[0], MARBLE[1], MARBLE_R
    return "\n".join([
        # sombra sobre la pista, algo desplazada hacia el lado contrario a la luz
        '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="url(#shadow)"/>' % (cx + 40, cy + r * 0.95, r * 1.05, r * 0.36),
        '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="url(#glass)"/>' % (cx, cy, r),
        '<g clip-path="url(#ball)">',
        swirl(0.0, "url(#swirl)", 0.2),
        swirl(0.45, "#6fffe0", 0.09),
        '</g>',
        '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="#c9f1ff" stroke-width="8" stroke-opacity="0.8"/>' % (cx, cy, r - 4),
        '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#ffffff" fill-opacity="0.85" transform="rotate(-35 %.1f %.1f)"/>'
        % (cx - r * 0.38, cy - r * 0.45, r * 0.3, r * 0.16, cx - r * 0.38, cy - r * 0.45),
        '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff" fill-opacity="0.9"/>' % (cx - r * 0.12, cy - r * 0.62, r * 0.06),
    ])


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n%s\n%s\n</svg>\n'
            % (defs(), body))


def main():
    os.makedirs(OUT, exist_ok=True)
    mono = speed_lines("#ffffff", (1, 1, 1)) + '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff"/>' % (MARBLE[0], MARBLE[1], MARBLE_R)
    files = {
        "icon_full.svg": svg(background() + track() + speed_lines() + marble()),
        "icon_background.svg": svg(background() + track()),
        "icon_foreground.svg": svg(speed_lines() + marble()),
        "icon_monochrome.svg": svg(mono),
    }
    for name, content in files.items():
        with io.open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
        print("escrito", name)


if __name__ == "__main__":
    main()
