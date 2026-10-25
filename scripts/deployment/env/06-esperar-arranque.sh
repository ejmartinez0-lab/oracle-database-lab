#!/usr/bin/env bash
set -euo pipefail

source scripts/deployment/env/00-config.sh

FMT='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'

echo "Esperando a que $CONTNAME este healthy (max. 5 min)"
estado=starting

for i in $(seq 1 60); do
  estado=$(docker inspect -f "$FMT" "$CONTNAME")
  echo "intento $i: $estado"

  if [ "$estado" = "healthy" ]; then
    break
  fi

  sleep 5
done

if [ "$estado" != "healthy" ]; then
  echo "AVISO: el contenedor no llego a healthy; revisa el log de abajo"
fi

echo
echo "Estado final"
docker ps --filter "name=$CONTNAME" --format '{{.Names}} {{.Status}}'

echo
echo "Registro de arranque (docker logs)"
docker logs "$CONTNAME" 2>&1
