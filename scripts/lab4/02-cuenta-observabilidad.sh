#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
source config.env

: "${OPS_RO_PWD:?Falta OPS_RO_PWD en config.env}"
[[ "$OPS_RO_PWD" =~ ^[A-Za-z][A-Za-z0-9]{15,}$ ]] || {
  echo "ERROR: formato de contrasena no admitido por este ejecutor."
  exit 2
}

{
  printf 'SET ECHO OFF VERIFY OFF\n'
  printf 'DEFINE ops_pwd = %s\n' "$OPS_RO_PWD"
  cat scripts/lab4/02-cuenta-observabilidad.sql
} | docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"
