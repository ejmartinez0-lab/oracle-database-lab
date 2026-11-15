#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

echo "=== A. Diagnostico SQL ==="
docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" \
  < scripts/lab4/01-diagnostico-inicial.sql

echo "=== B. Rutas reales de los datafiles de negocio ==="
LISTA=$(docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" <<'SQL'
WHENEVER SQLERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 400 TRIMOUT ON
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT file_name
FROM dba_data_files
WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\'
ORDER BY tablespace_name;
EXIT
SQL
)

while IFS= read -r f; do
  f=$(printf '%s' "$f" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -n "$f" ]] || continue
  real=$(docker exec "$CONTNAME" readlink -f "$f")
  case "$real" in
    "$DATA_ROOT/FREE/FREEPDB1/"*)
      echo "DENTRO, carpeta estandar: $f -> $real" ;;
    "$DATA_ROOT/"*)
      echo "DENTRO, carpeta NO estandar: $f -> $real" ;;
    *)
      echo "FUERA del volumen: $f -> $real" ;;
  esac
done <<< "$LISTA"

echo "=== C. ORACLE_HOME/dbs y sus enlaces ==="
docker exec "$CONTNAME" bash -c \
  'echo "ORACLE_HOME=$ORACLE_HOME"; ls -ld "$ORACLE_HOME/dbs"; ls -l "$ORACLE_HOME/dbs/"'
