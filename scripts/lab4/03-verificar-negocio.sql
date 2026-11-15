WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK OFF
COLUMN tablespace_name FORMAT A16
COLUMN file_name FORMAT A65
COLUMN owner FORMAT A22
COLUMN online_status FORMAT A14

PROMPT === Identidad de la base ===
SELECT dbid, name, open_mode FROM v$database;

ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT === Datafiles de negocio ===
SELECT tablespace_name, file_name,
       ROUND(bytes/1048576) AS mb, online_status
FROM dba_data_files
WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\'
ORDER BY tablespace_name;

PROMPT === Tablas por propietario ===
SELECT owner, COUNT(*) AS tablas
FROM dba_tables
WHERE owner LIKE 'ADMIN\_%' ESCAPE '\'
GROUP BY owner ORDER BY owner;

PROMPT === Datos de Academia ===
SELECT
  (SELECT COUNT(*) FROM admin_academia.aca_estudiantes) AS estudiantes,
  (SELECT estado FROM admin_academia.aca_estudiantes
   WHERE estudiante_id = 101) AS estado_fila_101
FROM dual;

EXIT
