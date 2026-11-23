-- Lab 4 v3, Parte I: contexto y visibilidad desde raiz y PDB.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 170 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
COLUMN usuario FORMAT A16
COLUMN contenedor FORMAT A18
COLUMN name FORMAT A18
COLUMN open_mode FORMAT A12
COLUMN familia FORMAT A25
COLUMN value FORMAT A20
COLUMN username FORMAT A18
COLUMN common FORMAT A6
COLUMN account_status FORMAT A20

ALTER SESSION SET CONTAINER = CDB$ROOT;

PROMPT === 1. Contexto y contenedores desde la raiz ===
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor,
       SYS_CONTEXT('USERENV', 'CON_ID') AS con_id
FROM dual;

SELECT con_id, name, open_mode, restricted
FROM v$containers
ORDER BY con_id;

PROMPT === 2. Datafiles y redo vistos desde la raiz ===
SELECT con_id, COUNT(*) AS datafiles
FROM v$datafile
GROUP BY con_id
ORDER BY con_id;

SELECT con_id, COUNT(*) AS grupos_redo
FROM v$log
GROUP BY con_id
ORDER BY con_id;

PROMPT === 3. DBA frente a CDB desde la raiz ===
SELECT 'DBA_TABLESPACES' AS familia, COUNT(*) AS tablespaces
FROM dba_tablespaces
UNION ALL
SELECT 'CDB_TABLESPACES', COUNT(*)
FROM cdb_tablespaces;

SELECT con_id, COUNT(*) AS tablespaces
FROM cdb_tablespaces
GROUP BY con_id
ORDER BY con_id;

PROMPT === 4. Prefijo de usuarios comunes ===
SELECT name, NVL(value, '(vacio)') AS value
FROM v$parameter
WHERE name = 'common_user_prefix';

PROMPT === 5. Cuenta de observabilidad en los contenedores visibles ===
SELECT con_id, username, common, account_status
FROM cdb_users
WHERE username = 'C##OPS_RO'
ORDER BY con_id;

ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT === 6. Mismas consultas desde FREEPDB1 ===
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor,
       SYS_CONTEXT('USERENV', 'CON_ID') AS con_id
FROM dual;

SELECT con_id, COUNT(*) AS datafiles
FROM v$datafile
GROUP BY con_id
ORDER BY con_id;

SELECT 'DBA_TABLESPACES' AS familia, COUNT(*) AS tablespaces
FROM dba_tablespaces
UNION ALL
SELECT 'CDB_TABLESPACES', COUNT(*)
FROM cdb_tablespaces;

SELECT con_id, COUNT(*) AS tablespaces
FROM cdb_tablespaces
GROUP BY con_id
ORDER BY con_id;

EXIT
