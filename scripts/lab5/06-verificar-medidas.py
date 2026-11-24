import csv
import re
import sys
from collections import Counter
from pathlib import Path

text = Path(sys.argv[1]).read_text(errors="replace")
errors = re.findall(r"^\s*((?:ORA|SP2|PLS)-\d+)", text, re.M)
if errors:
    raise SystemExit("Errores en el log: " + ", ".join(errors))

pattern = re.compile(
    r"^\s*([^:\r\n]+):\s*2000\s+"
    r"(INSERT|UPDATE estado|UPDATE import(?:e)?|DELETE)\s+"
    r"filas=\s*(\d+)[^\r\n]*?"
    r"por fila:\s*([\d.,]+)\s+bloques,\s*(\d+)\s+bytes de redo",
    re.M,
)
rows = []
for label, operation, count, blocks, redo in pattern.findall(text):
    label = label.strip()
    if label == "hoy":
        scenario = "hoy"
    elif label.lower().startswith("compa"):
        scenario = "companero"
    elif label == "V005":
        scenario = "V005"
    else:
        raise SystemExit("Escenario no reconocido: " + label)
    operation = "UPDATE importe" if operation.startswith("UPDATE import") else operation
    rows.append([
        scenario, operation, int(count),
        float(blocks.replace(",", ".")), int(redo),
    ])

expected = Counter({
    (s, op): 1
    for s in ("hoy", "companero", "V005")
    for op in ("INSERT", "UPDATE estado", "UPDATE importe", "DELETE")
})
actual = Counter((r[0], r[1]) for r in rows)
if actual != expected:
    raise SystemExit("Mediciones incompletas o duplicadas: " + str(dict(actual)))
if any(r[2] != 2000 for r in rows):
    raise SystemExit("Alguna medicion no informa 2000 operaciones.")

with Path(sys.argv[2]).open("w", newline="") as f:
    writer = csv.writer(f, lineterminator="\n")
    writer.writerow([
        "escenario", "operacion", "operaciones",
        "bloques_modificados_por_fila", "bytes_redo_por_fila",
    ])
    writer.writerows(rows)

print("OK: doce medidas verificadas, sin repetir DML.")
for scenario, operation, count, blocks, redo in rows:
    print(f"{scenario:10} {operation:15} {blocks:5.1f} bloques/fila; {redo} bytes redo/fila")
