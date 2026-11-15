#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

echo "=== 0. Comprobaciones de seguridad ==="
bash -n scripts/deployment/env/05-crear-contenedor.sh
docker volume inspect "$VOLNAME" >/dev/null

MONTAJE=$(docker inspect -f \
  '{{range .Mounts}}{{if eq .Destination "/opt/oracle/oradata"}}{{.Name}}{{end}}{{end}}' \
  "$CONTNAME")
[[ "$MONTAJE" == "$VOLNAME" ]] || {
  echo "ERROR: el volumen montado no coincide"; exit 1;
}

ACTUAL=$(docker inspect -f '{{.Image}}' "$CONTNAME")
CONFIGURADA=$(docker image inspect -f '{{.Id}}' "$IMG")
[[ "$ACTUAL" == "$CONFIGURADA" ]] || {
  echo "ERROR: la imagen configurada difiere de la actual. Revisar antes de borrar."
  exit 1
}

COMPROBACION=$(docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" <<'SQL'
WHENEVER SQLERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT COUNT(*) || '|' ||
       SUM(CASE WHEN file_name LIKE '/opt/oracle/oradata/FREE/FREEPDB1/%'
                THEN 1 ELSE 0 END)
FROM dba_data_files
WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\';
EXIT
SQL
)
[[ "$(printf '%s' "$COMPROBACION" | tr -d '[:space:]')" == "5|5" ]] || {
  echo "ERROR: no estan los cinco datafiles en la carpeta correcta."
  exit 1
}

echo "=== 1. ANTES: identidad, archivos y datos ==="
bash scripts/ops/sysdba.sh scripts/lab4/03-verificar-negocio.sql

echo "=== 2. Parada limpia y eliminacion SOLO del contenedor ==="
printf '%s\n' 'WHENEVER SQLERROR EXIT FAILURE' \
  'SHUTDOWN IMMEDIATE;' 'EXIT' |
  docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"

docker stop -t 120 "$CONTNAME" >/dev/null
docker rm "$CONTNAME"
docker volume ls --filter "name=$VOLNAME"

echo "=== 3. Recrear con el mismo volumen ==="
bash scripts/deployment/env/05-crear-contenedor.sh
bash scripts/ops/esperar-healthy.sh

echo "=== 4. DESPUES: identidad, archivos y datos ==="
bash scripts/ops/sysdba.sh scripts/lab4/03-verificar-negocio.sql

echo "=== 5. Puertos publicados ==="
docker port "$CONTNAME"
if docker port "$CONTNAME" | grep -q 8181; then
  echo "ERROR: sigue publicado el puerto 8181."
  exit 1
fi

echo "OK: prueba completada y puerto 8181 no publicado."
