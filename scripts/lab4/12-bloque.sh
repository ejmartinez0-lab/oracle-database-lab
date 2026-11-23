#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

TS=$(ts)
mkdir -p "$EVID_LAB4/script" "$EVID_LAB4/config"
LOG="$EVID_LAB4/script/${TS}_12-bloque.script.log"
DEST="$EVID_LAB4/config/${TS}_12-volcado-bloque.trc.txt"

bash scripts/ops/sysdba.sh scripts/lab4/12-bloque.sql "$LOG"

TRAZA=$(sed -n 's/^TRAZA_LAB4=//p' "$LOG" | tr -d '\r' | tail -n 1)
case "$TRAZA" in
  /opt/oracle/diag/*.trc) ;;
  *)
    echo "ERROR: no se ha obtenido una ruta de traza valida."
    exit 1
    ;;
esac

docker cp "$CONTNAME:$TRAZA" "$DEST"
test -s "$DEST"

echo
echo "Traza copiada a: $DEST"
wc -l "$DEST"
echo "Log de ejecucion: $LOG"
