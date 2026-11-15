#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

DESTDIR="$DATA_ROOT/FREE/FREEPDB1"

sysdba() {
  docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"
}

echo "=== 1. Datafiles de negocio pendientes de reubicar ==="
LISTA=$(sysdba <<'SQL'
WHENEVER SQLERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 400 TRIMOUT ON
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT tablespace_name || '|' || file_name
FROM dba_data_files
WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\'
AND file_name NOT LIKE '/opt/oracle/oradata/FREE/FREEPDB1/%'
ORDER BY tablespace_name;
EXIT
SQL
)

if [[ -z "${LISTA//[[:space:]]/}" ]]; then
  echo "Nada que reubicar: todos estan en $DESTDIR."
else
  while IFS='|' read -r TBS ORIG; do
    TBS=$(printf '%s' "$TBS" | xargs)
    ORIG=$(printf '%s' "$ORIG" | xargs)
    [[ -n "$TBS" ]] || continue

    [[ "$TBS" =~ ^TBS_[A-Z0-9_]+$ ]] || {
      echo "ERROR: nombre de tablespace inesperado: $TBS"; exit 1;
    }

    NUEVO="$DESTDIR/$(basename "$ORIG")"

    echo "=== $TBS: $ORIG -> $NUEVO ==="

    docker exec "$CONTNAME" test -f "$ORIG"
    docker exec "$CONTNAME" test -d "$DESTDIR"
    if docker exec "$CONTNAME" test -e "$NUEVO"; then
      echo "ERROR: el destino ya existe. No se sobrescribe."
      exit 1
    fi

    echo "a. OFFLINE NORMAL"
    sysdba <<SQL
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER TABLESPACE $TBS OFFLINE NORMAL;
EXIT
SQL

    echo "b. Copiar conservando permisos; mantener original"
    docker exec "$CONTNAME" cp -p "$ORIG" "$NUEVO"

    echo "c. Actualizar ruta, poner ONLINE y limitar crecimiento"
    sysdba <<SQL
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER TABLESPACE $TBS RENAME DATAFILE '$ORIG' TO '$NUEVO';
ALTER TABLESPACE $TBS ONLINE;
ALTER DATABASE DATAFILE '$NUEVO'
  AUTOEXTEND ON NEXT 50M MAXSIZE 1G;
EXIT
SQL

    echo "d. ONLINE correcto: retirar el archivo original"
    docker exec "$CONTNAME" rm -- "$ORIG"

  done <<< "$LISTA"
fi

echo "=== 2. Resultado final ==="
sysdba <<'SQL'
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK OFF
COLUMN tablespace_name FORMAT A16
COLUMN file_name FORMAT A65
COLUMN estado_tbs FORMAT A12
COLUMN autoextensible FORMAT A5
ALTER SESSION SET CONTAINER = FREEPDB1;

SELECT d.tablespace_name, d.file_name,
       t.status AS estado_tbs, d.autoextensible,
       ROUND(d.bytes/1048576) AS mb,
       ROUND(d.maxbytes/1048576) AS max_mb
FROM dba_data_files d
JOIN dba_tablespaces t ON t.tablespace_name = d.tablespace_name
WHERE d.tablespace_name LIKE 'TBS\_%' ESCAPE '\'
ORDER BY d.tablespace_name;
EXIT
SQL
