#!/usr/bin/env bash
# Proteccion adicional al escenario del kit: recuperacion desde otra sesion.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh
MARCA="$(ts)"
RESCATE="$EVID_LAB5/script/${MARCA}_11-rescate-limite.script.log"

recuperar() {
  timeout 30s bash scripts/ops/sysdba.sh \
    scripts/lab5/11-recuperar-limite.sql
}

trap 'recuperar || echo "ERROR: comprobar manualmente el limite de la FRA."' EXIT

(
  sleep 20
  recuperar
) > "$RESCATE" 2>&1 &
PID_RESCATE=$!

CODIGO=0
timeout 90s bash scripts/ops/sysdba.sh \
  scripts/lab5/11-fra-llena.sql || CODIGO=$?

ESTADO_RESCATE=0
wait "$PID_RESCATE" || ESTADO_RESCATE=$?
cat "$RESCATE"

recuperar
trap - EXIT

test "$ESTADO_RESCATE" -eq 0 || {
  echo "ERROR: fallo la sesion de rescate programada."
  exit 1
}

test "$CODIGO" -eq 0 || {
  echo "ERROR: el escenario termino con codigo $CODIGO."
  echo "Se ha vuelto a ejecutar la recuperacion del limite a 4G."
  exit 1
}
