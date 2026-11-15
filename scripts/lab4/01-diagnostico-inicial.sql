-- Diagnostico inicial: solo lectura.
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK OFF
COLUMN host_name FORMAT A16
COLUMN name FORMAT A85
COLUMN value FORMAT A65

PROMPT === 1. Instancia ===
SELECT instance_name, host_name, version_full, status,
       TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS arranque
FROM v$instance;

PROMPT === 2. Base de datos ===
SELECT name, cdb, log_mode, open_mode FROM v$database;

PROMPT === 3. Contenedores ===
SELECT con_id, name, open_mode FROM v$containers ORDER BY con_id;

PROMPT === 4. Datafiles de FREEPDB1 ===
SELECT d.file#, d.name, ROUND(d.bytes/1048576) AS mb
FROM v$datafile d
JOIN v$pdbs p ON p.con_id = d.con_id
WHERE p.name = 'FREEPDB1'
ORDER BY d.file#;

PROMPT === 5. Destinos de creacion de archivos y recuperacion ===
SELECT name, NVL(value, '(vacio)') AS value
FROM v$parameter
WHERE name IN ('db_create_file_dest', 'db_recovery_file_dest');

EXIT
