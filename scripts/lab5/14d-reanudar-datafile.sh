#!/usr/bin/env bash
# Simulacro D controlado: OFFLINE, perdida real, RESTORE y RECOVER.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh

FNO=16
FNAME='/opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf'
TAG='LAB5_D_20261124T211036Z'

MARCA="$(ts)"
VALIDACION="$EVID_LAB5/script/${MARCA}_14d-revalidacion-rman.script.log"
RMAN_LOG="$EVID_LAB5/script/${MARCA}_14d-restore-recover.script.log"
METRICAS="$EVID_LAB5/config/${MARCA}_14d-metricas.txt"

sql() {
  {
    printf 'WHENEVER OSERROR EXIT FAILURE\nWHENEVER SQLERROR EXIT FAILURE\n'
    cat
  } | docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"
}

comprobar_rman() {
  if grep -En '(^|[[:space:]])(RMAN-[0-9]{5}|ORA-[0-9]{5})' "$1"; then
    echo "ERROR: RMAN ha informado un error o aviso."
    exit 1
  fi
}

echo "=== REANUDACION D: COMPROBACIONES PREVIAS ==="

docker exec "$CONTNAME" test -s "$FNAME"
docker exec "$CONTNAME" test ! -L "$FNAME"

sql <<'SQL'
DECLARE
  n NUMBER;
  modo VARCHAR2(30);
BEGIN
  SELECT open_mode INTO modo FROM v$database;
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20028, 'La CDB no esta READ WRITE');
  END IF;

  SELECT log_mode INTO modo FROM v$database;
  IF modo <> 'ARCHIVELOG' THEN
    RAISE_APPLICATION_ERROR(-20028, 'La base no esta en ARCHIVELOG');
  END IF;

  SELECT open_mode INTO modo FROM v$pdbs WHERE name = 'FREEPDB1';
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20028, 'FREEPDB1 no esta READ WRITE');
  END IF;

  SELECT COUNT(*) INTO n
  FROM v$datafile d
  JOIN v$tablespace t ON t.ts# = d.ts# AND t.con_id = d.con_id
  JOIN v$pdbs p ON p.con_id = d.con_id
  WHERE d.file# = 16
    AND d.name = '/opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf'
    AND d.status IN ('OFFLINE', 'RECOVER')
    AND p.name = 'FREEPDB1'
    AND t.name = 'TBS_ACADEMIA';

  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20028, 'Identidad o estado del archivo inesperados');
  END IF;

  SELECT COUNT(*) INTO n FROM v$datafile_header
  WHERE file# = 16
    AND status = 'OFFLINE'
    AND recover = 'YES'
    AND error IS NULL;

  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20028, 'La cabecera no coincide con el diagnostico');
  END IF;

  SELECT COUNT(*) INTO n FROM v$recover_file
  WHERE file# = 16 AND online_status = 'OFFLINE';

  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20028, 'No se confirma el archivo fuera de linea');
  END IF;
END;
/
EXIT SUCCESS
SQL

echo "=== REVALIDACION DEL RESPALDO SIN CREAR OTRA COPIA ==="

docker exec -i "$CONTNAME" rman target / \
  2>&1 <<RMAN | tee "$VALIDACION"
RUN {
  ALLOCATE CHANNEL d1 DEVICE TYPE DISK;
  RESTORE DATAFILE $FNO FROM TAG '$TAG' VALIDATE;
  RELEASE CHANNEL d1;
}
EXIT;
RMAN

comprobar_rman "$VALIDACION"
grep -q 'Finished restore' "$VALIDACION"
grep -qi 'validation complete' "$VALIDACION"

echo "=== CONTINUACION DESDE EL BORRADO DEL ARCHIVO OFFLINE ==="
echo "La pausa de diagnostico no se incluye en los tiempos siguientes."
T0="$(date +%s)"
docker exec "$CONTNAME" rm -- "$FNAME"
docker exec "$CONTNAME" test ! -e "$FNAME"
TFALLO="$(date +%s)"

printf 'Ausencia fisica comprobada: %s\n' "$FNAME"

sql <<'SQL'
SET LINESIZE 200
COLUMN name FORMAT A100
SELECT file#, status, name FROM v$datafile WHERE file# = 16;
SELECT name, open_mode FROM v$pdbs WHERE name = 'FREEPDB1';
EXIT SUCCESS
SQL

echo "=== 5. RESTORE DESDE LA ETIQUETA EXACTA Y RECOVER ==="
TR0="$(date +%s)"

docker exec -i "$CONTNAME" rman target / \
  2>&1 <<RMAN | tee "$RMAN_LOG"
RUN {
  ALLOCATE CHANNEL d1 DEVICE TYPE DISK;
  RESTORE DATAFILE $FNO FROM TAG '$TAG';
  RECOVER DATAFILE $FNO;
  RELEASE CHANNEL d1;
}
EXIT;
RMAN

comprobar_rman "$RMAN_LOG"
grep -q 'Finished restore' "$RMAN_LOG"
grep -q 'Finished recover' "$RMAN_LOG"
grep -qi 'media recovery complete' "$RMAN_LOG"
docker exec "$CONTNAME" test -s "$FNAME"

echo "=== 6. ONLINE Y COMPROBACION DEL CAMBIO POSTERIOR ==="

sql <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE 16 ONLINE;

SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
  estado_actual VARCHAR2(30);
  n NUMBER;
BEGIN
  SELECT estado INTO estado_actual
  FROM admin_academia.aca_estudiantes
  WHERE estudiante_id = 104;

  IF estado_actual IS NULL OR estado_actual <> 'EGRESADO' THEN
    RAISE_APPLICATION_ERROR(-20027,
      'No se conserva el cambio posterior a la copia: ' || estado_actual);
  END IF;

  SELECT COUNT(*) INTO n FROM admin_academia.aca_estudiantes;
  IF n <> 20000 THEN
    RAISE_APPLICATION_ERROR(-20027, 'Recuento inesperado de estudiantes');
  END IF;

  SELECT COUNT(*) INTO n FROM v$datafile
  WHERE file# = 16 AND status = 'ONLINE';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20027, 'El archivo no esta ONLINE');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: fila 104=EGRESADO despues de RESTORE y RECOVER');
  DBMS_OUTPUT.PUT_LINE('OK: 20000 estudiantes y datafile 16 ONLINE');
END;
/
PROMPT CAMBIO_POSTERIOR_RECUPERADO_OK
EXIT SUCCESS
SQL

T1="$(date +%s)"

echo "=== 7. LIMPIEZA Y COMPROBACION DE MATRICULAS ==="

sql <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
UPDATE admin_academia.aca_estudiantes
SET estado = 'ACTIVO'
WHERE estudiante_id = 104;
COMMIT;

DECLARE estado_actual VARCHAR2(30);
BEGIN
  SELECT estado INTO estado_actual
  FROM admin_academia.aca_estudiantes
  WHERE estudiante_id = 104;
  IF estado_actual IS NULL OR estado_actual <> 'ACTIVO' THEN
    RAISE_APPLICATION_ERROR(-20027, 'La fila 104 no ha vuelto a ACTIVO');
  END IF;
END;
/
EXIT SUCCESS
SQL

sql < scripts/lab5/14c-verificar-matriculas.sql

{
  printf 'Simulacro D: perdida controlada de un datafile\n'
  printf 'Variante: archivo OFFLINE antes de eliminarlo; no fallo inesperado en linea\n'
  printf 'Datafile: %s | %s\n' "$FNO" "$FNAME"
  printf 'Copia utilizada: %s\n' "$TAG"
  printf 'Desde reanudacion previa al borrado hasta datos verificados: %s segundos\n' "$((T1-T0))"
  printf 'Desde ausencia fisica hasta datos verificados: %s segundos\n' "$((T1-TFALLO))"
  printf 'Desde inicio RESTORE/RECOVER hasta datos verificados: %s segundos\n' "$((T1-TR0))"
  printf 'RPO observado para la transaccion de prueba: 0\n'
  printf 'Prueba: fila 104=EGRESADO confirmada despues del backup y recuperada\n'
  printf 'Estado final de fila 104 tras limpieza: ACTIVO\n'
  printf 'No se ha probado el cierre automatico de la PDB por fallo de medio.\n'
} | tee "$METRICAS"

echo "SIMULACRO_D_COMPLETO_OK"
