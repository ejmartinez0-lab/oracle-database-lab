#!/usr/bin/env bash
# Simulacro A adaptado: transaccion abierta en una sesion y ABORT desde otra.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh

MARCA="$(ts)"
SESION="$EVID_LAB5/script/${MARCA}_14a-transaccion-abierta.script.log"
ALERT="$EVID_LAB5/script/${MARCA}_14a-alert-recuperacion.script.log"
METRICAS="$EVID_LAB5/config/${MARCA}_14a-metricas.txt"

sql() {
  {
    printf 'WHENEVER OSERROR EXIT FAILURE\nWHENEVER SQLERROR EXIT FAILURE\n'
    cat
  } | docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"
}

echo "=== 1. ESTADO INICIAL ==="
sql <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM admin_academia.aca_estudiantes
   WHERE estudiante_id IN (102, 103) AND estado = 'ACTIVO';
  IF n <> 2 THEN
    RAISE_APPLICATION_ERROR(-20023, 'Las filas 102 y 103 deben partir de ACTIVO');
  END IF;
END;
/
EXIT SUCCESS
SQL

INICIO_ALERT="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

echo "=== 2. CAMBIO CONFIRMADO Y TRANSACCION ABIERTA ==="
sql > "$SESION" 2>&1 <<'SQL' &
ALTER SESSION SET CONTAINER = FREEPDB1;
EXEC DBMS_APPLICATION_INFO.SET_MODULE('LAB5_SIM_A', 'TX_ABIERTA')
UPDATE admin_academia.aca_estudiantes
 SET estado = 'EGRESADO' WHERE estudiante_id = 102;
COMMIT;
UPDATE admin_academia.aca_estudiantes
 SET estado = 'INACTIVO' WHERE estudiante_id = 103;
SELECT estudiante_id, estado
FROM admin_academia.aca_estudiantes
WHERE estudiante_id IN (102, 103)
ORDER BY estudiante_id;
PROMPT TRANSACCION_A_PREPARADA
EXEC DBMS_SESSION.SLEEP(180)
ROLLBACK;
EXIT SUCCESS
SQL
PID_SESION=$!

LISTA=0
for _ in $(seq 1 30); do
  if grep -q '^TRANSACCION_A_PREPARADA' "$SESION"; then
    LISTA=1
    break
  fi
  if ! kill -0 "$PID_SESION" 2>/dev/null; then
    break
  fi
  sleep 1
done

if [ "$LISTA" -ne 1 ]; then
  echo "ERROR: la sesion no confirmo estar preparada. No se provoca la caida."
  cat "$SESION"
  exit 1
fi

sql <<'SQL'
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n
  FROM v$session s JOIN v$transaction t ON t.addr = s.taddr
  WHERE s.module = 'LAB5_SIM_A'
    AND s.con_id = (SELECT con_id FROM v$pdbs WHERE name = 'FREEPDB1');
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20023, 'No se confirma la transaccion abierta de A');
  END IF;
END;
/
EXIT SUCCESS
SQL

echo "=== 3. CAIDA BRUSCA DESDE LA RAIZ ==="
T0="$(date +%s)"
sql <<'SQL'
SHUTDOWN ABORT
EXIT SUCCESS
SQL

ESTADO_SESION=0
wait "$PID_SESION" || ESTADO_SESION=$?
echo "Codigo de la sesion interrumpida: $ESTADO_SESION"
echo "Su salida queda conservada en: $SESION"

echo "=== 4. ARRANQUE NORMAL ==="
sql <<'SQL'
STARTUP
DECLARE modo VARCHAR2(30);
BEGIN
  SELECT open_mode INTO modo FROM v$pdbs WHERE name = 'FREEPDB1';
  IF modo = 'MOUNTED' THEN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE FREEPDB1 OPEN';
  ELSIF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20023, 'PDB en estado inesperado: ' || modo);
  END IF;
END;
/
EXIT SUCCESS
SQL

echo "=== 5. COMPROBACION ANTES DE RESTAURAR LAS FILAS ==="
sql <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
  a VARCHAR2(30);
  b VARCHAR2(30);
BEGIN
  SELECT estado INTO a FROM admin_academia.aca_estudiantes
   WHERE estudiante_id = 102;
  SELECT estado INTO b FROM admin_academia.aca_estudiantes
   WHERE estudiante_id = 103;
  IF a IS NULL OR a <> 'EGRESADO' OR b IS NULL OR b <> 'ACTIVO' THEN
    RAISE_APPLICATION_ERROR(-20023,
      'Resultado inesperado: fila102=' || a || ' fila103=' || b);
  END IF;
  DBMS_OUTPUT.PUT_LINE('OK: 102=EGRESADO, cambio confirmado conservado');
  DBMS_OUTPUT.PUT_LINE('OK: 103=ACTIVO, cambio no confirmado deshecho');
END;
/
PROMPT SIMULACRO_A_DATOS_RECUPERADOS_OK
EXIT SUCCESS
SQL
T1="$(date +%s)"

echo "=== 6. LIMPIEZA DE LA FILA CONFIRMADA ==="
sql <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
UPDATE admin_academia.aca_estudiantes
 SET estado = 'ACTIVO' WHERE estudiante_id = 102;
COMMIT;
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM admin_academia.aca_estudiantes
   WHERE estudiante_id IN (102, 103) AND estado = 'ACTIVO';
  IF n <> 2 THEN
    RAISE_APPLICATION_ERROR(-20023, 'Las filas no han vuelto a ACTIVO');
  END IF;
END;
/
EXIT SUCCESS
SQL

echo "=== 7. ALERT LOG DE ESTA EJECUCION ==="
sql <<SQL | tee "$ALERT"
SET LINESIZE 240 PAGESIZE 0 FEEDBACK OFF HEADING OFF TRIMSPOOL ON
SELECT TO_CHAR(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS') ||
       ' ' || SUBSTR(message_text, 1, 200)
FROM v\$diag_alert_ext
WHERE originating_timestamp >=
      TO_TIMESTAMP_TZ('$INICIO_ALERT', 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
  AND REGEXP_LIKE(message_text,
      'crash recovery|redo scan|redo application|Recovery starting|need recovery',
      'i')
ORDER BY originating_timestamp;
EXIT SUCCESS
SQL

grep -Eiq 'crash recovery|redo scan|redo application|Recovery starting' "$ALERT" || {
  echo "ERROR: datos verificados, pero falta identificar la recuperacion en el alert log."
  exit 1
}

{
  printf 'Simulacro A: caida de instancia\n'
  printf 'Inicio: inmediatamente antes de solicitar SHUTDOWN ABORT\n'
  printf 'Fin: comprobacion correcta de las filas tras el arranque\n'
  printf 'Tiempo observado hasta recuperacion verificada: %s segundos\n' "$((T1-T0))"
  printf 'RPO observado en el cambio confirmado de prueba: 0\n'
  printf 'Fila 102 tras recuperar: EGRESADO\n'
  printf 'Fila 103 tras recuperar: ACTIVO\n'
  printf 'Estado despues de limpieza: ambas ACTIVO\n'
} | tee "$METRICAS"

echo "SIMULACRO_A_COMPLETO_OK"
