#!/usr/bin/env bash
# Adaptacion del procedimiento J: errores SQL estrictos y rutas comprobadas.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh
NUEVA="$DATA_ROOT/FREE/control03.ctl"

sql() {
  {
    printf 'WHENEVER OSERROR EXIT FAILURE\nWHENEVER SQLERROR EXIT FAILURE\n'
    cat
  } | docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"
}

SALIDA="$(sql <<'SQL'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 1000 TRIMSPOOL ON
SELECT 'CTL|' || name FROM v$controlfile ORDER BY name;
EXIT SUCCESS
SQL
)"

mapfile -t CONTROLES < <(printf '%s\n' "$SALIDA" | sed -n 's/^CTL|//p')
test "${#CONTROLES[@]}" -ge 2 || {
  echo "ERROR: no se identifican al menos dos control files."
  exit 1
}

for RUTA in "${CONTROLES[@]}"; do
  [[ "$RUTA" =~ ^/opt/oracle/oradata/[A-Za-z0-9_./-]+$ ]] || {
    echo "ERROR: ruta inesperada: $RUTA"
    exit 1
  }
  docker exec "$CONTNAME" test -s "$RUTA"
done

printf 'Control file registrado: %s\n' "${CONTROLES[@]}"

if printf '%s\n' "${CONTROLES[@]}" | grep -Fxq "$NUEVA"; then
  echo "La tercera copia ya esta registrada; no se repite el cambio."
  exit 0
fi

test "${#CONTROLES[@]}" -eq 2 || {
  echo "ERROR: configuracion distinta de dos copias; revisar."
  exit 1
}

if docker exec "$CONTNAME" test -e "$NUEVA"; then
  echo "ERROR: control03.ctl existe pero no esta registrado. No se sobrescribe."
  exit 1
fi

LISTA="$(printf "'%s'," "${CONTROLES[@]}" "$NUEVA")"
LISTA="${LISTA%,}"

echo "=== 1. Registrar tercera ruta en SPFILE ==="
printf "ALTER SYSTEM SET control_files=%s SCOPE=SPFILE;\nEXIT SUCCESS\n" \
  "$LISTA" | sql

echo "=== 2. Parada limpia ==="
printf 'SHUTDOWN IMMEDIATE\nEXIT SUCCESS\n' | sql

echo "=== 3. Copia fisica con Oracle parado ==="
docker exec "$CONTNAME" cp -p -- "${CONTROLES[0]}" "$NUEVA"
docker exec "$CONTNAME" test -s "$NUEVA"
docker exec "$CONTNAME" cmp -- "${CONTROLES[0]}" "$NUEVA"

echo "=== 4. Arranque y apertura de FREEPDB1 si procede ==="
sql <<'SQL'
STARTUP
DECLARE modo VARCHAR2(30);
BEGIN
  SELECT open_mode INTO modo FROM v$pdbs WHERE name = 'FREEPDB1';
  IF modo = 'MOUNTED' THEN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE FREEPDB1 OPEN';
  ELSIF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20019, 'FREEPDB1 en estado inesperado: ' || modo);
  END IF;
END;
/
EXIT SUCCESS
SQL

bash scripts/ops/esperar-healthy.sh
