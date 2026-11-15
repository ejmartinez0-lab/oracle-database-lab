#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

ORIGEN=${1:?Uso: restaurar-estado.sh carpeta-backup [--si]}
ORIGEN=$(realpath "$ORIGEN")
CONFIRMAR=${2:-}

echo "1. Verificar integridad antes de modificar nada"
[[ -f "$ORIGEN/SHA256SUMS" ]]
[[ -s "$ORIGEN/volumen.tar.gz" ]]
(
  cd "$ORIGEN"
  sha256sum --check SHA256SUMS
)
cat "$ORIGEN/manifiesto.txt"

echo "2. Confirmacion"
echo "ATENCION: se sustituira TODO el contenido del volumen $VOLNAME."
if [[ "$CONFIRMAR" != "--si" ]]; then
  read -r -p "Escribe el nombre del volumen para confirmar: " respuesta
  [[ "$respuesta" == "$VOLNAME" ]] || {
    echo "Cancelado; no se ha modificado nada."
    exit 1
  }
fi

docker pull "$HELPER_IMG"
RECREAR=no

echo "3. Parada del entorno actual"
if docker inspect "$CONTNAME" >/dev/null 2>&1; then
  MONTAJE=$(docker inspect -f \
    '{{range .Mounts}}{{if eq .Destination "/opt/oracle/oradata"}}{{.Name}}{{end}}{{end}}' \
    "$CONTNAME")
  [[ "$MONTAJE" == "$VOLNAME" ]] || {
    echo "ERROR: el volumen montado no coincide con el configurado."
    exit 1
  }
  if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTNAME")" == true ]]; then
    printf '%s\n' 'SHUTDOWN IMMEDIATE;' 'EXIT' |
      docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" || true
    docker stop -t 120 "$CONTNAME" >/dev/null
  fi
else
  RECREAR=si
fi

echo "4. Restauracion del volumen conservando propietarios y permisos"
docker volume create "$VOLNAME" >/dev/null
docker run --rm \
  -v "$VOLNAME:/destino" \
  -v "$ORIGEN:/origen:ro" \
  "$HELPER_IMG" sh -ec \
  'find /destino -mindepth 1 -delete
   tar --numeric-owner -xzpf /origen/volumen.tar.gz -C /destino'

if [[ "$RECREAR" == si ]]; then
  bash scripts/deployment/env/05-crear-contenedor.sh
  docker stop -t 120 "$CONTNAME" >/dev/null
fi

echo "5. Restauracion de archivos externos"
if [[ -s "$ORIGEN/extras/mapa.txt" ]]; then
  while IFS='|' read -r archivo ruta; do
    [[ -n "$archivo" && -n "$ruta" ]]
    gunzip -c "$ORIGEN/extras/$archivo" |
      docker cp -a - "$CONTNAME:$(dirname "$ruta")"
    echo "Restaurado: $ruta"
  done < "$ORIGEN/extras/mapa.txt"
else
  echo "Ninguno: todos los archivos estaban dentro del volumen."
fi

echo "6. Arranque y verificacion"
docker start "$CONTNAME" >/dev/null
bash scripts/ops/esperar-healthy.sh

docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" <<'SQL'
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 160 PAGESIZE 50 FEEDBACK OFF
SELECT instance_name, status FROM v$instance;
SELECT name, open_mode, log_mode FROM v$database;
SELECT name, open_mode FROM v$pdbs;
SELECT owner, COUNT(*) AS tablas
FROM cdb_tables
WHERE owner LIKE 'ADMIN\_%' ESCAPE '\'
GROUP BY owner ORDER BY owner;
EXIT
SQL

echo "Restauracion terminada."
