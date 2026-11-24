#!/usr/bin/env bash
# Simulacro B: ausencia controlada de una copia multiplexada.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh

MARCA="$(ts)"
INVENTARIO="$EVID_LAB5/config/${MARCA}_14b-controlfiles-previos.txt"
PARADA="$EVID_LAB5/script/${MARCA}_14b-parada-previa.script.log"
FALLO="$EVID_LAB5/script/${MARCA}_14b-arranque-fallido.script.log"
PARADA2="$EVID_LAB5/script/${MARCA}_14b-parada-nomount.script.log"
ALERT="$EVID_LAB5/script/${MARCA}_14b-alert-controlfile.script.log"
METRICAS="$EVID_LAB5/config/${MARCA}_14b-metricas.txt"

sql() {
  {
    printf 'WHENEVER OSERROR EXIT FAILURE\nWHENEVER SQLERROR EXIT FAILURE\n'
    cat
  } | docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"
}

echo "=== 1. INVENTARIO Y ESTADO INICIAL ==="

sql <<'SQL'
DECLARE
  n NUMBER;
  modo VARCHAR2(30);
BEGIN
  SELECT open_mode INTO modo FROM v$database;
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20024, 'La CDB no esta READ WRITE');
  END IF;

  SELECT open_mode INTO modo FROM v$pdbs WHERE name = 'FREEPDB1';
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20024, 'FREEPDB1 no esta READ WRITE');
  END IF;

  SELECT COUNT(*) INTO n FROM v$controlfile;
  IF n <> 3 THEN
    RAISE_APPLICATION_ERROR(-20024, 'Se esperaban tres control files');
  END IF;

  SELECT COUNT(*) INTO n FROM v$controlfile WHERE status IS NOT NULL;
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20024, 'Hay control files con estado anomalo');
  END IF;
END;
/
EXIT SUCCESS
SQL

sql > "$INVENTARIO" <<'SQL'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 32767 TRIMSPOOL ON
SELECT name FROM v$controlfile ORDER BY name;
EXIT SUCCESS
SQL

mapfile -t CONTROLES < <(
  sed '/^[[:space:]]*$/d; s/^[[:space:]]*//; s/[[:space:]]*$//' "$INVENTARIO"
)

test "${#CONTROLES[@]}" -eq 3 || {
  echo "ERROR: inventario de control files inesperado."
  cat "$INVENTARIO"
  exit 1
}

VICTIMA=''
SANA=''

for ARCHIVO in "${CONTROLES[@]}"; do
  [[ "$ARCHIVO" =~ ^/[a-zA-Z0-9_./-]+$ ]] || {
    echo "ERROR: ruta no admitida: $ARCHIVO"
    exit 1
  }

  docker exec "$CONTNAME" test -s "$ARCHIVO"
  docker exec "$CONTNAME" test ! -L "$ARCHIVO"

  if [[ "$ARCHIVO" == */control03.ctl ]]; then
    test -z "$VICTIMA"
    VICTIMA="$ARCHIVO"
  elif [ -z "$SANA" ]; then
    SANA="$ARCHIVO"
  fi
done

test -n "$VICTIMA"
test -n "$SANA"
test "$VICTIMA" != "$SANA"

APARTADA="${VICTIMA}.simulacro-b-${MARCA}"
docker exec "$CONTNAME" test ! -e "$APARTADA"

printf 'Copia que se apartara: %s\n' "$VICTIMA"
printf 'Copia sana para reparar: %s\n' "$SANA"
printf 'Ubicacion temporal: %s\n' "$APARTADA"

INICIO_ALERT="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

echo "=== 2. PARADA LIMPIA Y AUSENCIA CONTROLADA ==="
T0="$(date +%s)"

sql > "$PARADA" 2>&1 <<'SQL'
SHUTDOWN IMMEDIATE
EXIT SUCCESS
SQL

grep -q 'ORACLE instance shut down' "$PARADA" || {
  echo "ERROR: no se confirma la parada; no se aparta ningun archivo."
  cat "$PARADA"
  exit 1
}

cat "$PARADA"

docker exec "$CONTNAME" mv -- "$VICTIMA" "$APARTADA"
docker exec "$CONTNAME" test ! -e "$VICTIMA"
docker exec "$CONTNAME" test -s "$APARTADA"

echo "=== 3. ARRANQUE FALLIDO ESPERADO ==="

# El error esperado queda aislado en su propia evidencia.
docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" \
  > "$FALLO" 2>&1 <<'SQL'
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR CONTINUE NONE
STARTUP
EXIT SUCCESS
SQL

grep -q 'ORA-00205' "$FALLO" || {
  echo "ERROR: no aparece el fallo esperado ORA-00205."
  echo "Revisar: $FALLO"
  exit 1
}

ESTADO="$(
  sql <<'SQL'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT status FROM v$instance;
EXIT SUCCESS
SQL
)"
ESTADO="$(printf '%s\n' "$ESTADO" | xargs)"

test "$ESTADO" = 'STARTED' || {
  echo "ERROR: se esperaba STARTED/NOMOUNT; estado: $ESTADO"
  exit 1
}

echo "Fallo esperado confirmado; evidencia: $FALLO"
echo "Instancia STARTED: no se ha podido montar la base."

echo "=== 4. PARADA Y REPARACION DESDE LA COPIA SANA ==="
TR0="$(date +%s)"

sql > "$PARADA2" 2>&1 <<'SQL'
SHUTDOWN ABORT
EXIT SUCCESS
SQL

grep -q 'ORACLE instance shut down' "$PARADA2" || {
  echo "ERROR: no se confirma la parada anterior a la copia."
  cat "$PARADA2"
  exit 1
}

cat "$PARADA2"

docker exec "$CONTNAME" test ! -e "$VICTIMA"
docker exec "$CONTNAME" test -s "$SANA"
docker exec "$CONTNAME" cp -p -- "$SANA" "$VICTIMA"
docker exec "$CONTNAME" cmp -- "$SANA" "$VICTIMA"

echo "Copia reparada e identica a la copia sana antes del arranque."

echo "=== 5. ARRANQUE Y VERIFICACION ==="

sql <<'SQL'
STARTUP
DECLARE modo VARCHAR2(30);
BEGIN
  SELECT open_mode INTO modo FROM v$pdbs WHERE name = 'FREEPDB1';
  IF modo = 'MOUNTED' THEN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE FREEPDB1 OPEN';
  ELSIF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20024, 'PDB en estado inesperado: ' || modo);
  END IF;
END;
/
SET LINESIZE 200
COLUMN name FORMAT A100
SELECT name, status FROM v$controlfile;

DECLARE
  n NUMBER;
  modo VARCHAR2(30);
BEGIN
  SELECT open_mode INTO modo FROM v$database;
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20024, 'CDB no abierta en lectura/escritura');
  END IF;

  SELECT COUNT(*) INTO n FROM v$controlfile;
  IF n <> 3 THEN
    RAISE_APPLICATION_ERROR(-20024, 'No hay tres control files');
  END IF;

  SELECT COUNT(*) INTO n FROM v$controlfile WHERE status IS NOT NULL;
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20024, 'Estado anomalo de control file');
  END IF;
END;
/

ALTER SESSION SET CONTAINER = FREEPDB1;
DECLARE n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM admin_academia.aca_estudiantes;
  IF n <> 20000 THEN
    RAISE_APPLICATION_ERROR(-20024, 'Recuento inesperado de estudiantes');
  END IF;

  SELECT COUNT(*) INTO n FROM admin_academia.aca_estudiantes
   WHERE estudiante_id IN (102, 103) AND estado = 'ACTIVO';
  IF n <> 2 THEN
    RAISE_APPLICATION_ERROR(-20024, 'Estado inesperado de las filas de A');
  END IF;
END;
/
PROMPT SIMULACRO_B_DATOS_RECUPERADOS_OK
EXIT SUCCESS
SQL

T1="$(date +%s)"

echo "=== 6. DIAGNOSTICO DEL FALLO EN EL ALERT LOG ==="

sql <<SQL | tee "$ALERT"
SET LINESIZE 240 PAGESIZE 0 FEEDBACK OFF HEADING OFF TRIMSPOOL ON
SELECT TO_CHAR(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS') ||
       ' ' || SUBSTR(message_text, 1, 200)
FROM v\$diag_alert_ext
WHERE originating_timestamp >=
      TO_TIMESTAMP_TZ('$INICIO_ALERT', 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM')
  AND REGEXP_LIKE(message_text,
      'ORA-00205|ORA-00210|ORA-00202|ORA-27037|control03[.]ctl', 'i')
ORDER BY originating_timestamp;
EXIT SUCCESS
SQL

grep -Fq "$VICTIMA" "$ALERT" || {
  echo "ERROR: falta identificar la ruta afectada en el alert log."
  exit 1
}

# El apartado no es un respaldo reutilizable. Se retira tras verificar.
docker exec "$CONTNAME" rm -- "$APARTADA"

{
  printf 'Simulacro B: ausencia de una copia del control file\n'
  printf 'Archivo afectado: %s\n' "$VICTIMA"
  printf 'Copia sana utilizada: %s\n' "$SANA"
  printf 'Fallo esperado: ORA-00205; instancia STARTED/NOMOUNT\n'
  printf 'Tiempo desde solicitud de parada hasta datos verificados: %s segundos\n' "$((T1-T0))"
  printf 'Tiempo desde inicio de reparacion hasta datos verificados: %s segundos\n' "$((T1-TR0))"
  printf 'Alcance de comprobacion: 20000 estudiantes y filas 102/103 ACTIVO\n'
  printf 'Recuperacion: copia multiplexada actual; sin RESETLOGS\n'
} | tee "$METRICAS"

echo "SIMULACRO_B_COMPLETO_OK"
