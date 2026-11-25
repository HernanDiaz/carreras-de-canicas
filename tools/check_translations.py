"""Comprueba locale/translations.csv frente al código.

- Cada clave usada con tr("CLAVE") en scripts/ y levels/ existe en el CSV.
- Ninguna celda está vacía (todas las claves traducidas a todos los idiomas).
- Los formatos (%d, %.1f, %s...) son los mismos en todos los idiomas que en inglés.
- No hay claves repetidas.

Uso: python tools/check_translations.py   (sale con código 1 si encuentra algo)
"""
import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FORMAT = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[dfsxXc%]")

with open(ROOT / "locale" / "translations.csv", encoding="utf-8", newline="") as f:
    rows = list(csv.reader(f))
header, rows = rows[0], rows[1:]
languages = header[1:]
problems = []
keys = {}
for row in rows:
    if not row:
        continue
    key = row[0]
    if key in keys:
        problems.append("clave repetida: " + key)
    keys[key] = row
    if len(row) != len(header):
        problems.append("%s: %d columnas en vez de %d" % (key, len(row), len(header)))
        continue
    english = sorted(FORMAT.findall(row[1]))
    for language, text in zip(languages, row[1:]):
        if not text.strip():
            problems.append("%s: falta en %s" % (key, language))
        elif sorted(FORMAT.findall(text)) != english:
            problems.append("%s: formato distinto en %s (%s)" % (key, language, text))

used = set()
for folder in ("scripts", "levels"):
    for path in (ROOT / folder).rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        used.update(re.findall(r'\btr\("([A-Z0-9_]+)"\)', text))
        # Claves que se traducen después: nombres de nivel y avisos (caída, ácido...).
        used.update(re.findall(r'\bname = "([A-Z0-9_]+)"', text))
        used.update(re.findall(r'(?:emit|_respawn)\("([A-Z0-9_]+)"', text))
for key in sorted(used - keys.keys()):
    problems.append("se usa en el código pero no está en el CSV: " + key)

for problem in problems:
    print(problem)
print("Traducciones: %d claves, %d idiomas, %d problemas" % (len(keys), len(languages), len(problems)))
sys.exit(1 if problems else 0)
