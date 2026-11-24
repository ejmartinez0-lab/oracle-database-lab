-- Lab 4 v3, Parte M: inventario de solo lectura antes de borrar.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
COLUMN username FORMAT A22
COLUMN owner FORMAT A22
COLUMN object_name FORMAT A30
COLUMN object_type FORMAT A20
COLUMN segment_name FORMAT A30
COLUMN tablespace_name FORMAT A20
COLUMN default_tablespace FORMAT A20
COLUMN file_name FORMAT A110

PROMPT === 1. Confirmar contenedor ===
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor FROM dual;

PROMPT === 2. Objetos del esquema que se eliminaria ===
SELECT object_name, object_type, status
FROM dba_objects
WHERE owner = 'LAB4PRUEBAS'
ORDER BY object_type, object_name;

PROMPT === 3. Todos los segmentos de LAB4PRUEBAS o de TBS_LAB4 ===
SELECT owner, segment_name, segment_type, tablespace_name,
       ROUND(bytes / 1048576, 3) AS mib
FROM dba_segments
WHERE owner = 'LAB4PRUEBAS'
   OR tablespace_name = 'TBS_LAB4'
ORDER BY owner, tablespace_name, segment_name;

PROMPT === 4. Usuarios con TBS_LAB4 como tablespace predeterminado ===
SELECT username, authentication_type, default_tablespace
FROM dba_users
WHERE default_tablespace = 'TBS_LAB4'
ORDER BY username;

PROMPT === 5. Datafiles asociados al tablespace ===
SELECT file_id, file_name, ROUND(bytes / 1048576, 3) AS mib
FROM dba_data_files
WHERE tablespace_name = 'TBS_LAB4'
ORDER BY file_id;

PROMPT === 6. Ultima comprobacion de los resultados del experimento ===
SELECT table_name, num_rows, blocks, chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS'
  AND table_name IN ('LECTURAS', 'MIGRA', 'ANCHA')
ORDER BY table_name;

PROMPT === FIN DEL INVENTARIO: NO SE HA BORRADO NADA ===
EXIT
