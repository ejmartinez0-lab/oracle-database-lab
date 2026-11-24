#!/usr/bin/env bash
# Adaptacion: conserva los logs de ambas sesiones y espera su terminacion.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh

MARCA="$(ts)"
A="$EVID_LAB5/script/${MARCA}_12-sesion-a.script.log"
B="$EVID_LAB5/script/${MARCA}_12-sesion-b.script.log"

echo "Espera preventiva de 45 segundos antes de la prueba de flashback."
sleep 45

bash scripts/ops/sysdba.sh scripts/lab5/12-sesion-a.sql > "$A" 2>&1 &
PID_A=$!

sleep 5

CODIGO_B=0
bash scripts/ops/sysdba.sh scripts/lab5/12-sesion-b.sql > "$B" 2>&1 || CODIGO_B=$?

CODIGO_A=0
wait "$PID_A" || CODIGO_A=$?

printf '\n=== SESION B ===\n'
cat "$B"
printf '\n=== SESION A ===\n'
cat "$A"

test "$CODIGO_A" -eq 0
test "$CODIGO_B" -eq 0

python3 - "$A" "$B" <<'PY'
from pathlib import Path
import re
import sys

a = Path(sys.argv[1]).read_text(errors="replace")
b = Path(sys.argv[2]).read_text(errors="replace")
if re.search(r"^\s*(ORA-|SP2-|PLS-)\d+", a, re.M):
    raise SystemExit("ERROR: fallo en la sesion A.")

codes = re.findall(r"^\s*((?:ORA|SP2|PLS)-\d+)", b, re.M)
if not any(c in {"ORA-00054", "ORA-30006"} for c in codes):
    raise SystemExit("ERROR: no se observo el bloqueo esperado.")
unexpected = set(codes) - {"ORA-00054", "ORA-30006", "ORA-40097"}
if unexpected:
    raise SystemExit("ERROR en sesion B: " + str(unexpected))

states = re.findall(r"^\s*101\s+([A-Z]+)\s*$", b, re.M)
if states != ["ACTIVO", "EGRESADO", "ACTIVO", "ACTIVO"]:
    raise SystemExit("Secuencia de estados inesperada: " + repr(states))
print("LECTURA_CONSISTENTE_VERIFICADA_OK")
PY
