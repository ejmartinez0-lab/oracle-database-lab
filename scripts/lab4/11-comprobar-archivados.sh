#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

docker exec -i "$CONTNAME" bash -s <<'SH'
set -euo pipefail

echo "=== 1. Configuracion y ultimos archivados registrados ==="
sqlplus -s -L "/ as sysdba" <<'SQL'
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON
COLUMN name FORMAT A30
COLUMN value FORMAT A125
COLUMN archivo FORMAT A125

SELECT name, NVL(value, '(sin configurar)') AS value
FROM v$parameter
WHERE name IN (
  'log_archive_dest',
  'log_archive_dest_1',
  'log_archive_format'
)
ORDER BY name;

SELECT thread#, sequence#, status, deleted,
       TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS completado,
       name AS archivo
FROM v$archived_log
WHERE name IS NOT NULL
ORDER BY completion_time DESC, recid DESC
FETCH FIRST 5 ROWS ONLY;

EXIT
SQL

echo
echo "=== 2. Existencia y ruta real de esos archivos ==="
archivos=$(sqlplus -s -L "/ as sysdba" <<'SQL'
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 1000 TRIMOUT ON
SELECT name FROM (
  SELECT name, completion_time, recid
  FROM v$archived_log
  WHERE name IS NOT NULL
  ORDER BY completion_time DESC, recid DESC
)
WHERE ROWNUM <= 5;
EXIT
SQL
)

if [ -z "$archivos" ]; then
  echo "No hay nombres de archivados registrados para comprobar."
else
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -f "$f" ]; then
      stat -c '%s bytes | %n' "$f"
      real=$(readlink -f "$f")
      printf 'Ruta real: %s\n' "$real"
      case "$real" in
        /opt/oracle/oradata/*)
          echo "DENTRO del volumen de datos"
          ;;
        *)
          echo "FUERA del volumen de datos"
          ;;
      esac
    else
      printf 'No existe actualmente: %s\n' "$f"
    fi
  done <<< "$archivos"
fi
SH
