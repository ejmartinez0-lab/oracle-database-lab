#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
SQLFILE=${1:?Uso: sysdba.sh archivo.sql [archivo-evidencia]}
[[ -f "$SQLFILE" ]] || { echo "No existe: $SQLFILE"; exit 2; }

if [[ -n "${2:-}" ]]; then
  mkdir -p "$(dirname "$2")"
  docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" \
    < "$SQLFILE" 2>&1 | tee "$2"
else
  docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" \
    < "$SQLFILE"
fi
