#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

if (( $# < 1 )); then
  echo "Uso: bash $0 migracion [migracion...]"
  echo "Indicar los nombres sin la extension .sql"
  exit 2
fi

DEST="$EVID_LAB4/spool"
mkdir -p "$DEST"

for MIG in "$@"; do
  FILE="database/migrations/$MIG.sql"
  [[ -f "$FILE" ]] || {
    echo "ERROR: no existe $FILE"
    exit 2
  }

  LOG="$DEST/$(ts)_04-${MIG}.spool.log"
  echo "Aplicando $MIG"

  if ! docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" \
    < "$FILE" 2>&1 | tee "$LOG"; then
    echo "ERROR: revisa $LOG antes de continuar."
    exit 1
  fi
done

echo "Migraciones aplicadas. Evidencias en $DEST"
