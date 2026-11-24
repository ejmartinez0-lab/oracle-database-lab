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
COLUMN usuario FORMAT A20
COLUMN contenedor FORMAT A18
COLUMN username FORMAT A20
COLUMN default_attr FORMAT A14
COLUMN all_containers FORMAT A16

ALTER SESSION SET CONTAINER = CDB\$ROOT;

PROMPT === 1. Comprobar que el nombre comun esta libre ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM cdb_users
  WHERE username = 'C##LAB4AUDITOR';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20021, 'C##LAB4AUDITOR ya existe. No se ha modificado.');
  END IF;
END;
/

CREATE USER c##lab4auditor IDENTIFIED BY "$PWD_PRUEBA" CONTAINER=ALL;
GRANT CREATE SESSION, SET CONTAINER TO c##lab4auditor CONTAINER=ALL;
GRANT SELECT_CATALOG_ROLE TO c##lab4auditor CONTAINER=ALL;

CONNECT c##lab4auditor/"$PWD_PRUEBA"@localhost:1521/FREE

PROMPT === 2. Usuario comun sin CONTAINER_DATA configurado ===
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

SELECT con_id, COUNT(*) AS tablespaces
FROM cdb_tablespaces
GROUP BY con_id
ORDER BY con_id;

SELECT con_id, COUNT(*) AS sesiones
FROM v\$session
GROUP BY con_id
ORDER BY con_id;

PROMPT === 3. Con SET CONTAINER puede entrar en FREEPDB1 ===
ALTER SESSION SET CONTAINER = FREEPDB1;

SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

SELECT COUNT(*) AS tablespaces_pdb
FROM dba_tablespaces;

PROMPT === 4. Comparar atributos desde SYS en la raiz ===
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = CDB\$ROOT;

SELECT username, default_attr, all_containers
FROM cdb_container_data
WHERE username IN ('C##OPS_RO', 'C##LAB4AUDITOR')
ORDER BY username;

PROMPT === 5. Eliminar el usuario comun temporal ===
DROP USER c##lab4auditor;

SELECT COUNT(*) AS usuarios_comunes_prueba_restantes
FROM cdb_users
WHERE username = 'C##LAB4AUDITOR';

ALTER SESSION SET CONTAINER = FREEPDB1;

SELECT COUNT(*) AS usuarios_locales_prueba_restantes
FROM dba_users
WHERE username = 'LAB4ANALISTA';

EXIT
SQL
