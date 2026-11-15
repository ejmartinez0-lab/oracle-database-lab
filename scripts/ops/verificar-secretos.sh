#!/usr/bin/env bash
set +x
set -euo pipefail
source config.env

PATRON=$(mktemp)
HISTORIAL=$(mktemp)
chmod 600 "$PATRON" "$HISTORIAL"
trap 'rm -f "$PATRON" "$HISTORIAL"' EXIT

echo "=== Escaneo de secretos: archivos e historial local disponible ==="
git log --all -p --no-ext-diff --no-textconv > "$HISTORIAL"

fallos=0
for VARIABLE in ORACLE_PWD OPS_RO_PWD; do
  SECRETO=${!VARIABLE:-}

  if [[ -z "$SECRETO" ]]; then
    echo "FALLO: $VARIABLE no esta definida."
    fallos=$((fallos+1))
    continue
  fi

  printf '%s\n' "$SECRETO" > "$PATRON"

  if COINCIDENCIAS=$(git grep -I -l -F -f "$PATRON" -- .); then
    ARCHIVOS=$(printf '%s\n' "$COINCIDENCIAS" | wc -l)
  else
    CODIGO=$?
    [[ "$CODIGO" == 1 ]] || exit "$CODIGO"
    ARCHIVOS=0
  fi

  if LINEAS=$(grep -F -c -f "$PATRON" "$HISTORIAL"); then
    :
  else
    CODIGO=$?
    [[ "$CODIGO" == 1 ]] || exit "$CODIGO"
  fi

  echo "$VARIABLE: archivos con coincidencia=$ARCHIVOS; lineas en historial=$LINEAS"

  if (( ARCHIVOS > 0 || LINEAS > 0 )); then
    fallos=$((fallos+1))
  fi
done

unset SECRETO

if (( fallos == 0 )); then
  echo "OK: sin coincidencias de las dos contrasenas comprobadas."
else
  echo "FALLO: revisar secretos antes de hacer push."
fi

exit "$fallos"
