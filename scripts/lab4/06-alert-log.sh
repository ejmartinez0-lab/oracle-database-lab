#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

ALERT="/opt/oracle/diag/rdbms/free/FREE/trace/alert_FREE.log"
LINEAS=${1:-400}

echo "=== Archivo revisado ==="
echo "$ALERT"

echo "=== Parada, arranque y apertura: ultimas $LINEAS lineas ==="
CONTENIDO=$(docker exec "$CONTNAME" tail -n "$LINEAS" "$ALERT")

printf '%s\n' "$CONTENIDO" |
  grep -E -i \
  'Shutting down|Starting ORACLE|Instance shutdown complete|ALTER DATABASE|Completed|Successful mount|Successful open|Pluggable database.*opened|Opening pdb|Crash Recovery|Thread 1 opened|ORA-' ||
  true

echo "=== Mensajes ORA con contexto en el mismo fragmento ==="
if printf '%s\n' "$CONTENIDO" | grep -q 'ORA-'; then
  printf '%s\n' "$CONTENIDO" | grep -n -B 2 -A 5 'ORA-'
else
  echo "No aparecen mensajes ORA- en el fragmento revisado."
fi
