#!/usr/bin/env bash
set -euo pipefail

source scripts/deployment/env/00-config.sh

set -a
source config.env
set +a

# Si el contenedor ya existe, no se crea otra vez.
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTNAME"; then
  echo "El contenedor $CONTNAME ya existe; no se crea de nuevo."
  docker ps -a --filter "name=$CONTNAME"
  exit 0
fi

docker run -d --name "$CONTNAME" \
  -p "$PORTDB:1521" \
  -p "$PORTORDS:8181" \
  -e ORACLE_PWD="$ORACLE_PWD" \
  -e APP_USER=alumno \
  -e APP_USER_PASSWORD="$APP_USER_PWD" \
  -v "$VOLNAME:/opt/oracle/oradata" \
  "$IMG"

echo "Contenedor $CONTNAME creado."
docker ps --filter "name=$CONTNAME"
