-- Lab 4 v3, I.3: diccionario y vistas dinamicas como C##OPS_RO.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET SQLFORMAT DEFAULT
SET LINESIZE 170 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
COLUMN usuario FORMAT A18
COLUMN contenedor FORMAT A18
COLUMN familia FORMAT A35
COLUMN type FORMAT A12
COLUMN view_definition FORMAT A150 WORD_WRAPPED

PROMPT === 1. Usuario y contenedor actuales ===
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

PROMPT === 2. Familias de vistas del diccionario ===
SELECT 'USER: objetos propios' AS familia, COUNT(*) AS vistas
FROM dba_views WHERE owner = 'SYS' AND view_name LIKE 'USER\_%' ESCAPE '\'
UNION ALL
SELECT 'ALL: objetos accesibles', COUNT(*)
FROM dba_views WHERE owner = 'SYS' AND view_name LIKE 'ALL\_%' ESCAPE '\'
UNION ALL
SELECT 'DBA: contenedor actual', COUNT(*)
FROM dba_views WHERE owner = 'SYS' AND view_name LIKE 'DBA\_%' ESCAPE '\'
UNION ALL
SELECT 'CDB: datos de contenedores', COUNT(*)
FROM dba_views WHERE owner = 'SYS' AND view_name LIKE 'CDB\_%' ESCAPE '\'
UNION ALL
SELECT 'V$: vistas dinamicas', COUNT(*)
FROM v$fixed_table WHERE type = 'VIEW' AND name LIKE 'V$%'
UNION ALL
SELECT 'GV$: vistas globales', COUNT(*)
FROM v$fixed_table WHERE type = 'VIEW' AND name LIKE 'GV$%';

PROMPT === 3. DBA frente a CDB como cuenta de observabilidad ===
SELECT 'DBA_TABLESPACES' AS familia, COUNT(*) AS tablespaces
FROM dba_tablespaces
UNION ALL
SELECT 'CDB_TABLESPACES', COUNT(*)
FROM cdb_tablespaces;

SELECT c.name AS contenedor, COUNT(*) AS tablespaces
FROM cdb_tablespaces t
JOIN v$containers c ON c.con_id = t.con_id
GROUP BY c.name
ORDER BY c.name;

PROMPT === 4. Estructuras fijas por tipo ===
SELECT type, COUNT(*) AS cantidad
FROM v$fixed_table
GROUP BY type
ORDER BY type;

PROMPT === 5. Definicion interna de GV$LOG ===
SELECT view_definition
FROM v$fixed_view_definition
WHERE view_name = 'GV$LOG';

EXIT
