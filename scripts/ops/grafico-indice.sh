#!/usr/bin/env bash
# Adaptado del Lab 5 v3, C.4. Genera treedump y procesa una copia local.
# Uso: bash scripts/ops/grafico-indice.sh ESQUEMA INDICE [evidencia]
# Solo laboratorio: usa SYSDBA y escribe una traza en el ADR.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh

[[ $# -ge 2 && $# -le 3 ]] || {
  echo "Uso: $0 ESQUEMA INDICE [evidencia]" >&2
  exit 2
}
OWNER=${1^^}
INDICE=${2^^}
LOG=${3:-/dev/null}
for nombre in "$OWNER" "$INDICE"; do
  [[ "$nombre" =~ ^[A-Z][A-Z0-9_\$#]*$ && ${#nombre} -le 128 ]] || {
    echo "Nombre simple no valido." >&2
    exit 2
  }
done
[[ "$LOG" == /dev/null ]] || mkdir -p "$(dirname "$LOG")"

TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

main() {
  cat > "$TMP/consulta.sql" <<SQL
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 1000 VERIFY OFF
ALTER SESSION SET CONTAINER=FREEPDB1;
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n
  FROM dba_indexes i
  JOIN dba_tablespaces t ON t.tablespace_name=i.tablespace_name
  WHERE i.owner='$OWNER' AND i.index_name='$INDICE'
    AND i.partitioned='NO' AND i.status='VALID'
    AND i.index_type IN
      ('NORMAL','NORMAL/REV','FUNCTION-BASED NORMAL')
    AND t.block_size=8192;
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20010,
      'Indice inexistente o no admitido: requiere B-tree valido, no particionado y bloque de 8 KiB.');
  END IF;
END;
/
COLUMN oid NEW_VALUE oid NOPRINT
SELECT TO_CHAR(object_id, 'FM99999999999999999999') AS oid
FROM dba_objects
WHERE owner='$OWNER' AND object_name='$INDICE' AND object_type='INDEX';
ALTER SESSION SET tracefile_identifier='grafico_indice';
ALTER SESSION SET EVENTS 'immediate trace name treedump level &oid';
SELECT 'TRACE=' || value FROM v\$diag_info
WHERE name='Default Trace File';
EXIT
SQL

  if ! bash scripts/ops/sysdba.sh "$TMP/consulta.sql" > "$TMP/sql.log"; then
    cat "$TMP/sql.log"
    return 1
  fi

  TRAZA=$(sed -n 's/^[[:space:]]*TRACE=//p' "$TMP/sql.log" | tr -d '\r')
  [[ -n "$TRAZA" && "$TRAZA" != *$'\n'* && "$TRAZA" == /*.trc ]] || {
    cat "$TMP/sql.log"
    echo "No se obtuvo una unica ruta de traza."
    return 1
  }

  docker cp "$CONTNAME:$TRAZA" "$TMP/indice.trc" >/dev/null

  python3 - "$TMP/indice.trc" "$OWNER" "$INDICE" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(errors="replace")
starts = list(re.finditer(r"(?im)^.*begin tree dump.*$", text))
if starts:
    text = text[starts[-1].end():]
    end = re.search(r"(?im)^.*end tree dump.*$", text)
    if end:
        text = text[:end.start()]

leaves = []
leaf_lines = [line for line in text.splitlines()
              if re.match(r"^\s*leaf:\s*0x", line, re.I)]

for line in leaf_lines:
    m = re.search(r"\brow:\s*(\d+)\.(\d+)\s+avs:\s*(\d+)", line, re.I)
    if not m:
        raise SystemExit("Formato de hoja no reconocido; no se inventan medidas.")
    n, live, free = map(int, m.groups())
    if not 0 <= live <= n or not 0 <= free <= 7996:
        raise SystemExit("Valores fuera del modelo de 7996 bytes utiles.")
    used = (7996 - free) / 7996
    occupancy = used * live / n if n else 0.0
    leaves.append((n, live, free, used, occupancy))

if not leaves:
    raise SystemExit("No se encontraron hojas en el treedump; revisar formato.")

count = len(leaves)
total = sum(x[0] for x in leaves)
live = sum(x[1] for x in leaves)
avg_live = sum(x[4] for x in leaves) / count
avg_used = sum(x[3] for x in leaves) / count

print(f"{sys.argv[2]}.{sys.argv[3]}")
print("Modelo: 7996 bytes utiles por hoja; ocupacion viva aproximada.")
print(f"Hojas={count}; entradas vivas={live}; borradas={total-live}")
print(f"Media de entradas vivas/hoja={live/count:.2f}")
print(f"Ocupacion viva estimada={100*avg_live:.2f}%")
print(f"Espacio usado medio={100*avg_used:.2f}%")
print(f"Hojas sin entradas vivas={sum(x[1] == 0 for x in leaves)}")
print(f"Hojas con ocupacion viva inferior al 50%={sum(x[4] < .5 for x in leaves)}")

bins = [0] * 10
for leaf in leaves:
    bins[min(9, int(leaf[4] * 10))] += 1
print("\nHistograma de ocupacion viva estimada")
for i, value in enumerate(bins):
    bar = "#" * round(50 * value / max(bins))
    upper = "100" if i == 9 else str(i * 10 + 9)
    print(f"{i*10:02d}-{upper:>3}% {value:7d} {bar}")

groups = min(64, count)
symbols = " .:-=#"
mapping = []
for i in range(groups):
    chunk = leaves[i*count//groups:(i+1)*count//groups]
    mean = sum(x[4] for x in chunk) / len(chunk)
    level = sum(mean >= threshold for threshold in (.1, .3, .5, .7, .9))
    mapping.append(symbols[level])

print("\nMapa en orden de recorrido de hojas del treedump")
print("|" + "".join(mapping) + "|")
print("Leyenda: espacio <10%; . <30%; : <50%; - <70%; = <90%; # >=90%.")
print("En un B-tree normal: izquierda claves bajas, derecha claves altas.")
print("En REVERSE el orden es el de la clave interna invertida.")
print("El mapa es diagnostico: no recomienda reconstruir por si solo.")
PY
}

main 2>&1 | tee "$LOG"
