import csv
import math
import re
import sys
from html import escape
from pathlib import Path

log = Path(sys.argv[1])
base = Path(sys.argv[2])
text = log.read_text(errors="replace")
pattern = re.compile(
    r"^\s*(\d*(?:[.,]\d+)?)\s*%?\s+"
    r"(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$"
)
rows = []
for line in text.splitlines():
    m = pattern.match(line)
    if not m:
        continue
    pct = float(m[1].replace(",", "."))
    if not 0 < pct <= 100:
        continue
    tail = m[6].split("->")[0].strip()
    plan = "completo" if "recorrido completo" in tail.lower() else "indice"
    rows.append([pct, *map(int, m.group(2, 3, 4, 5)), plan])

expected = [0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100]
rows.sort()
if [r[0] for r in rows] != expected:
    raise SystemExit(
        "ERROR: no se han identificado los 12 puntos esperados. "
        "Se conserva el log; no se inventan datos."
    )
if any(min(r[2:5]) <= 0 for r in rows):
    raise SystemExit("ERROR: alguna medida de lecturas no es positiva.")

with base.with_suffix(".csv").open("w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        "porcentaje_nominal", "filas_nominales",
        "lecturas_cf_bueno", "lecturas_cf_malo",
        "lecturas_tabla_completa", "plan_estimado_cf_malo",
    ])
    writer.writerows(rows)

events = []
for col, label in [(2, "CF bueno supera tabla"), (3, "CF malo supera tabla")]:
    for i, r in enumerate(rows):
        if r[col] > r[4]:
            if i:
                events.append((rows[i-1][0], r[0], label))
            else:
                events.append((r[0], r[0], label + " ya en primer punto"))
            break
for a, b in zip(rows, rows[1:]):
    if a[5] != b[5]:
        events.append((a[0], b[0], "Cambio de plan: " + a[5] + " a " + b[5]))

W, H = 1100, 700
left, right, top, bottom = 100, 1060, 70, 500
ymin = math.floor(math.log10(min(min(r[2:5]) for r in rows)))
ymax = math.ceil(math.log10(max(max(r[2:5]) for r in rows)))
if ymax == ymin:
    ymax += 1

def x(v):
    return left + (math.log10(v) + 2) / 4 * (right - left)

def y(v):
    return bottom - (math.log10(v) - ymin) / (ymax - ymin) * (bottom - top)

svg = [
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
    '<rect width="100%" height="100%" fill="white"/>',
    '<g font-family="sans-serif" font-size="13" fill="#222">',
    '<text x="100" y="30" font-size="21">TiendaSur: agrupamiento y punto de equilibrio medido</text>',
]
for tick in [0.01, 0.1, 1, 10, 100]:
    xx = x(tick)
    svg += [
        f'<path d="M {xx} {top} V {bottom}" stroke="#ddd"/>',
        f'<text x="{xx}" y="{bottom+23}" text-anchor="middle">{tick:g}%</text>',
    ]
for power in range(ymin, ymax + 1):
    value = 10 ** power
    yy = y(value)
    svg += [
        f'<path d="M {left} {yy} H {right}" stroke="#ddd"/>',
        f'<text x="{left-10}" y="{yy+4}" text-anchor="end">{value:g}</text>',
    ]
for lo, hi, label in events:
    xx = x(hi)
    svg.append(
        f'<path d="M {xx} {top} V {bottom}" stroke="#888" stroke-dasharray="5,5"/>'
    )
for col, color, label in [
    (2, "#1570b8", "Indice CF bueno"),
    (3, "#c64436", "Indice CF malo"),
    (4, "#238544", "Tabla completa"),
]:
    points = " ".join(f"{x(r[0]):.2f},{y(r[col]):.2f}" for r in rows)
    svg.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="2.5"/>')
    for r in rows:
        svg.append(f'<circle cx="{x(r[0])}" cy="{y(r[col])}" r="3" fill="{color}"/>')
    pos = 120 + (col - 2) * 300
    svg.append(f'<text x="{pos}" y="560" fill="{color}">{label}</text>')

svg += [
    '<text x="450" y="540">Porcentaje nominal de filas (escala logaritmica)</text>',
    '<text x="100" y="55">Eje vertical: lecturas logicas, escala logaritmica</text>',
]
notes = []
for lo, hi, label in events:
    note = f"{label}: intervalo muestreado [{lo:g}%, {hi:g}%]"
    notes.append(note)
    svg.append(f'<text x="100" y="{590 + 22*(len(notes)-1)}">{escape(note)}</text>')
svg += [
    '<text x="100" y="680">Lineas entre muestras: guia visual; no son mediciones intermedias. Plan: EXPLAIN PLAN.</text>',
    '</g></svg>',
]
base.with_suffix(".svg").write_text("\n".join(svg), encoding="utf-8")
base.with_suffix(".txt").write_text(
    "\n".join(notes) + "\nCruces acotados por muestras, no umbrales exactos.\n",
    encoding="utf-8",
)
print("OK: 12 puntos validados; CSV y grafica SVG generados.")
for note in notes:
    print(note)
