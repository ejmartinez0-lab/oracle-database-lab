#!/usr/bin/env bash
set -euo pipefail
set +x
source scripts/deployment/env/00-config.sh

PWD_PRUEBA=$(python3 -c 'import secrets; print("L4a" + secrets.token_hex(12))')

docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" <<SQL
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET ECHO OFF VERIFY OFF FEEDBACK ON
SET LINESIZE 170 PAGESIZE 100 TAB OFF
COLUMN usuario FORMAT A18
COLUMN contenedor FORMAT A18
COLUMN prueba FORMAT A38
COLUMN owner FORMAT A20
COLUMN table_name FORMAT A25

ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT === 1. Comprobar que el nombre de prueba esta libre ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_users WHERE username = 'LAB4ANALISTA';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20020, 'LAB4ANALISTA ya existe. No se ha borrado ni modificado.');
  END IF;
END;
/

CREATE USER lab4analista IDENTIFIED BY "$PWD_PRUEBA";
GRANT CREATE SESSION TO lab4analista;

CONNECT lab4analista/"$PWD_PRUEBA"@localhost:1521/FREEPDB1

PROMPT === 2. Usuario local con solo CREATE SESSION ===
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

SELECT 'USER_TABLES: tablas propias' AS prueba, COUNT(*) AS cantidad
FROM user_tables
UNION ALL
SELECT 'ALL_TABLES: tablas de Academia', COUNT(*)
FROM all_tables WHERE owner = 'ADMIN_ACADEMIA';

PROMPT === 3. Errores esperados: catalogo, datos ajenos y cambio de contenedor ===
WHENEVER SQLERROR CONTINUE
SELECT COUNT(*) FROM dba_tables;
SELECT COUNT(*) FROM v\$session;
SELECT COUNT(*) FROM admin_academia.aca_estudiantes;
ALTER SESSION SET CONTAINER = CDB\$ROOT;
WHENEVER SQLERROR EXIT FAILURE

CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT === 4. Conceder lectura limitada al esquema Academia ===
GRANT READ ANY TABLE ON SCHEMA admin_academia TO lab4analista;

CONNECT lab4analista/"$PWD_PRUEBA"@localhost:1521/FREEPDB1

SELECT owner, table_name
FROM all_tables
WHERE owner = 'ADMIN_ACADEMIA'
ORDER BY table_name;

SELECT COUNT(*) AS estudiantes
FROM admin_academia.aca_estudiantes;

PROMPT === 5. Otro esquema sigue cerrado y leer no permite escribir ===
WHENEVER SQLERROR CONTINUE
SELECT COUNT(*) FROM admin_clinica.cli_pacientes;
UPDATE admin_academia.aca_estudiantes
SET estado = estado
WHERE estudiante_id = 101;
ROLLBACK;
WHENEVER SQLERROR EXIT FAILURE

CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT === 6. Eliminar el usuario temporal ===
DROP USER lab4analista;

SELECT COUNT(*) AS usuarios_prueba_restantes
FROM dba_users
WHERE username = 'LAB4ANALISTA';

SELECT estado AS estado_fila_101
FROM admin_academia.aca_estudiantes
WHERE estudiante_id = 101;

EXIT
SQL
