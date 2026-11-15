#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

MAX=${1:-600}
FMT='{{if .State.Health}}{{.State.Health.Status}}{{else}}sin-healthcheck{{end}}'
SONDA="SELECT d.open_mode || p.open_mode
FROM v\$database d, v\$pdbs p WHERE p.name = '$SERVICE_PDB';"

for ((t=0; t<=MAX; t+=10)); do
  salud=$(docker inspect -f "$FMT" "$CONTNAME")
  modo=$(
    printf '%s\n' \
      'WHENEVER SQLERROR EXIT 1' \
      'SET HEADING OFF FEEDBACK OFF PAGESIZE 0' \
      "$SONDA" 'EXIT' |
      docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" 2>/dev/null |
      tr -d '[:space:]'
  ) || modo=""

  echo "t=${t}s docker=$salud cdb+pdb=${modo:-no-disponible}"

  if [[ "$modo" == "READWRITEREADWRITE" ]]; then
    exit 0
  fi
  sleep 10
done

echo "ERROR: la base no quedó abierta en ${MAX}s." >&2
exit 1
