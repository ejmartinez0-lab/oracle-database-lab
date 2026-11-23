#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

echo "=== 1. Montajes del contenedor ==="
docker inspect "$CONTNAME" --format \
  '{{range .Mounts}}tipo={{.Type}} destino={{.Destination}} origen={{.Source}}{{println}}{{end}}'

docker exec -i "$CONTNAME" bash -s <<'SH'
set -euo pipefail

echo
echo "=== 2. Archivos de datos, control y redo: bytes reales ==="
find /opt/oracle/oradata/FREE -maxdepth 3 -type f \
  \( -name '*.dbf' -o -name '*.ctl' -o -name 'redo*.log' \) \
  -exec stat -c '%s bytes | %n' {} \; | sort -k4

echo
echo "=== 3. SPFILE y password file: enlaces y destinos ==="
for f in \
  /opt/oracle/product/26ai/dbhomeFree/dbs/spfileFREE.ora \
  /opt/oracle/product/26ai/dbhomeFree/dbs/orapwFREE
do
  ls -l "$f"
  real=$(readlink -f "$f")
  printf 'Ruta real: %s\n' "$real"
  stat -c '%s bytes | %n' "$real"
done

echo
echo "=== 4. Destino de archivado: ruta real y ocupacion ==="
arch=/opt/oracle/product/26ai/dbhomeFree/dbs/arch
if [ -d "$arch" ]; then
  ls -ld "$arch"
  real=$(readlink -f "$arch")
  printf 'Ruta real: %s\n' "$real"
  du -sh "$real"
  printf 'Numero de archivos regulares: '
  find "$real" -type f -printf '.\n' | wc -l
else
  echo "El directorio de archivado no existe en esta ruta."
fi

echo
echo "=== 5. ADR, alert log y trazas ==="
adr=/opt/oracle/diag/rdbms/free/FREE
printf 'Ruta real del ADR: '
readlink -f "$adr"
stat -c '%s bytes | %n' "$adr/trace/alert_FREE.log"
du -sh "$adr"
printf 'Numero de trazas .trc: '
find "$adr/trace" -maxdepth 1 -type f -name '*.trc' -printf '.\n' | wc -l

echo
echo "=== 6. Espacio disponible dentro del contenedor ==="
df -h /opt/oracle/oradata /opt/oracle/diag
SH
