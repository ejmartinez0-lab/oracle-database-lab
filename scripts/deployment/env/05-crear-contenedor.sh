#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

if docker container inspect "$CONTNAME" >/dev/null 2>&1; then
  echo "El contenedor $CONTNAME ya existe; no se crea de nuevo."
  docker ps -a --filter "name=$CONTNAME"
  exit 0
fi

docker volume inspect "$VOLNAME" >/dev/null 2>&1 ||
  docker volume create "$VOLNAME" >/dev/null

if docker run --rm -v "$VOLNAME:/datos:ro" "$HELPER_IMG" \
  test -d /datos/FREE; then

  echo "El volumen ya contiene FREE: se reutiliza sin pasar contrasenas."
  docker run -d \
    --name "$CONTNAME" \
    -p "$PORTDB:1521" \
    -v "$VOLNAME:/opt/oracle/oradata" \
    "$IMG"
else
  echo "Volumen vacio: primera creacion de la base."
  set -a
  source config.env
  set +a
  : "${ORACLE_PWD:?Falta ORACLE_PWD en config.env}"

  docker run -d \
    --name "$CONTNAME" \
    -p "$PORTDB:1521" \
    -e ORACLE_PWD \
    -v "$VOLNAME:/opt/oracle/oradata" \
    "$IMG"
fi

echo "Contenedor $CONTNAME creado."
docker ps --filter "name=$CONTNAME"
