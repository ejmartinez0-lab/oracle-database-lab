#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

echo "=== 1. Procesos de background de la instancia ==="
PROCESOS=$(docker top "$CONTNAME" -eo pid,user,rss,args)
printf '%s\n' "$PROCESOS" |
  grep -E '(ora|db)_[a-z0-9]+_FREE' | sed -n '1,15p'
echo "Recuento de procesos de background:"
printf '%s\n' "$PROCESOS" |
  grep -cE '(ora|db)_[a-z0-9]+_FREE'

echo "=== 2. Procesos servidor y listener ==="
printf '%s\n' "$PROCESOS" | grep -E 'oracleFREE|tnslsnr' || true

echo "=== 3. Memoria y CPU del contenedor ==="
docker stats --no-stream \
  --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}' "$CONTNAME"

echo "=== 4. Archivos del CDB y de la PDB ==="
docker exec "$CONTNAME" bash -c \
  'ls -lh /opt/oracle/oradata/FREE
   echo "--- FREEPDB1 ---"
   ls -lh /opt/oracle/oradata/FREE/FREEPDB1'

echo "=== 5. Listener y servicios registrados ==="
docker exec "$CONTNAME" lsnrctl status |
  grep -E 'Service|Instance|Listening|Uptime'
