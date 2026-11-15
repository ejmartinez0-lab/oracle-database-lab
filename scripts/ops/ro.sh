#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
source config.env

SQLFILE=${1:?Uso: ro.sh archivo.sql [servicio]}
SERVICE=${2:-$SERVICE_CDB}
[[ -f "$SQLFILE" ]] || {
  echo "ERROR: no existe $SQLFILE"; exit 2;
}
: "${OPS_RO_PWD:?Falta OPS_RO_PWD}"
[[ "$OPS_RO_PWD" =~ ^[A-Za-z][A-Za-z0-9]{15,}$ ]] || {
  echo "ERROR: formato de contrasena no admitido"; exit 2;
}

{
  printf 'SET ECHO OFF VERIFY OFF\n'
  printf 'WHENEVER OSERROR EXIT FAILURE\n'
  printf 'WHENEVER SQLERROR EXIT FAILURE\n'
  printf 'CONNECT c##ops_ro/"%s"@localhost:%s/%s\n' \
    "$OPS_RO_PWD" "$PORTDB" "$SERVICE"
  printf '@%s\nEXIT\n' "$SQLFILE"
} | sql -S /nolog
