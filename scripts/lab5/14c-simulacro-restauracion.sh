#!/usr/bin/env bash
# Simulacro C: flashback drop y restauracion del volumen en frio.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh

COPIA='/home/esteban/oracle-database-lab/backups/20261124T204154Z_lab5-pre-simulacro-c'
FK='docs/bitacora/lab5/evidencia/config/20261124T204149Z_14c-recrear-claves-ajenas.sql'
META='docs/bitacora/lab5/evidencia/config/20261124T204149Z_14c-metadatos-previos.txt'
VERIFICAR='scripts/lab5/14c-verificar-matriculas.sql'

MARCA="$(ts)"
ACTUAL="$EVID_LAB5/config/${MARCA}_14c-metadatos-restaurados.txt"
RESTAURACION="$EVID_LAB5/script/${MARCA}_14c-restauracion-volumen.script.log"
METRICAS="$EVID_LAB5/config/${MARCA}_14c-metricas.txt"

sql() {
  {
    printf 'WHENEVER OSERROR EXIT FAILURE\nWHENEVER SQLERROR EXIT FAILURE\n'
    cat
  } | docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"
}

snapshot() {
  sql <<'SQL'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SET LINESIZE 32767 TRIMSPOOL ON TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;

SELECT 'FILAS|' || COUNT(*)
FROM admin_academia.aca_matriculas;

SELECT 'RESTRICCION|' || constraint_name || '|' ||
       constraint_type || '|' || status || '|' || validated ||
       '|' || r_owner || '|' || r_constraint_name || '|' || delete_rule
FROM dba_constraints
WHERE owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS'
ORDER BY constraint_name;

SELECT 'COLUMNA_RESTRICCION|' || constraint_name || '|' ||
       position || '|' || column_name
FROM dba_cons_columns
WHERE owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS'
ORDER BY constraint_name, position;

SELECT 'INDICE|' || index_name || '|' || index_type ||
       '|' || uniqueness || '|' || status
FROM dba_indexes
WHERE table_owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS'
ORDER BY index_name;

SELECT 'COLUMNA_INDICE|' || index_name || '|' ||
       column_position || '|' || column_name || '|' || descend
FROM dba_ind_columns
WHERE table_owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS'
ORDER BY index_name, column_position;

EXIT SUCCESS
SQL
}

comparar_original() {
  snapshot > "$ACTUAL"
  diff -u \
    <(sed '/^[[:space:]]*$/d; s/[[:space:]]*$//' "$META") \
    <(sed '/^[[:space:]]*$/d; s/[[:space:]]*$//' "$ACTUAL")
}

echo "=== 1. RESPALDO Y ESTADO DE PARTIDA ==="
test -s "$COPIA/SHA256SUMS"
test -s "$COPIA/volumen.tar.gz"
test -s "$FK"
test -s "$META"
test "$(grep -c 'ADD CONSTRAINT' "$FK")" -eq 2

(
  cd "$COPIA"
  sha256sum -c SHA256SUMS
)

sql < "$VERIFICAR"
comparar_original

sql <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_recyclebin
  WHERE owner = 'ADMIN_ACADEMIA' AND original_name = 'ACA_MATRICULAS';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Hay entradas previas de la tabla en la papelera');
  END IF;

  SELECT COUNT(*) INTO n
  FROM dba_constraints c JOIN dba_constraints p
    ON p.owner = c.r_owner AND p.constraint_name = c.r_constraint_name
  WHERE c.constraint_type = 'R'
    AND p.owner = 'ADMIN_ACADEMIA' AND p.table_name = 'ACA_MATRICULAS';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Hay claves ajenas entrantes no previstas');
  END IF;
END;
/
EXIT SUCCESS
SQL

echo "=== 2. DROP SIN PURGE Y FLASHBACK ==="
TF0="$(date +%s)"

sql <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET recyclebin = ON;
DROP TABLE admin_academia.aca_matriculas;

SET LINESIZE 200
COLUMN original_name FORMAT A24
COLUMN object_name FORMAT A40
SELECT original_name, object_name, type
FROM dba_recyclebin
WHERE owner = 'ADMIN_ACADEMIA' AND original_name = 'ACA_MATRICULAS';

FLASHBACK TABLE admin_academia.aca_matriculas TO BEFORE DROP;
EXIT SUCCESS
SQL

echo "=== 3. RECREACION DE CLAVES AJENAS Y VERIFICACION ==="

{
  printf 'ALTER SESSION SET CONTAINER = FREEPDB1;\n'
  cat "$FK"
  printf '\nEXIT SUCCESS\n'
} | sql

sql < "$VERIFICAR"
TF1="$(date +%s)"

echo "=== 4. DROP CON PURGE Y COMPROBACION DE AUSENCIA ==="
TP0="$(date +%s)"

sql <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
DROP TABLE admin_academia.aca_matriculas PURGE;

DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_tables
  WHERE owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20025, 'La tabla sigue presente');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_recyclebin
  WHERE owner = 'ADMIN_ACADEMIA' AND original_name = 'ACA_MATRICULAS';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20025, 'La tabla sigue en la papelera');
  END IF;

  BEGIN
    EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM admin_academia.aca_matriculas' INTO n;
    RAISE_APPLICATION_ERROR(-20025, 'La tabla aun se puede consultar');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE <> -942 THEN
        RAISE;
      END IF;
  END;
END;
/
PROMPT TABLA_PURGADA_Y_AUSENTE_OK
EXIT SUCCESS
SQL

echo "=== 5. RESTAURACION COMPLETA DE LA COPIA EXACTA ==="
TR0="$(date +%s)"

bash scripts/ops/restaurar-estado.sh "$COPIA" --si \
  2>&1 | tee "$RESTAURACION"

grep -q '^Restauracion terminada\.' "$RESTAURACION"

echo "=== 6. VERIFICACION DE TABLA Y METADATOS ORIGINALES ==="
sql < "$VERIFICAR"
comparar_original

T1="$(date +%s)"
echo "OK: recuento y metadatos coinciden con el estado original."
echo "SIMULACRO_C_RESTAURACION_VERIFICADA_OK"

{
  printf 'Simulacro C: borrado logico y restauracion completa\n'
  printf 'Copia restaurada: %s\n' "$COPIA"
  printf 'Flashback + recreacion de FK + verificacion: %s segundos\n' "$((TF1-TF0))"
  printf 'Restauracion + verificacion de tabla y metadatos: %s segundos\n' "$((T1-TR0))"
  printf 'Desde solicitud de DROP PURGE hasta tabla verificada: %s segundos\n' "$((T1-TP0))"
  printf 'Punto de recuperacion: estado de la copia en frio indicada\n'
  printf 'No se generaron cambios de negocio posteriores para medir perdida de datos.\n'
  printf 'El intervalo temporal desde la copia no equivale por si solo a datos perdidos.\n'
  printf 'Resultado: 60000 filas y metadatos originales comprobados.\n'
  printf 'La comprobacion no es una comparacion fila a fila del contenido.\n'
} | tee "$METRICAS"

echo "SIMULACRO_C_COMPLETO_OK"
