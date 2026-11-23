-- Lab 4 v3, J.2: inventario de archivos como C##OPS_RO.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET SQLFORMAT DEFAULT
SET LINESIZE 210 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
COLUMN usuario FORMAT A18
COLUMN contenedor FORMAT A14
COLUMN tipo FORMAT A22
COLUMN ruta FORMAT A95
COLUMN estado FORMAT A14
COLUMN name FORMAT A35
COLUMN value FORMAT A110 WORD_WRAPPED
COLUMN username FORMAT A18
COLUMN account_status FORMAT A20
COLUMN event FORMAT A28

PROMPT === 1. Contexto ===
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

PROMPT === 2. Archivos de datos, temporales, control y redo ===
SELECT 'datafile' AS tipo, c.name AS contenedor, d.name AS ruta,
       ROUND(d.bytes / 1048576, 1) AS mb, d.status AS estado
FROM v$datafile d JOIN v$containers c ON c.con_id = d.con_id
UNION ALL
SELECT 'tempfile', c.name, t.name,
       ROUND(t.bytes / 1048576, 1), t.status
FROM v$tempfile t JOIN v$containers c ON c.con_id = t.con_id
UNION ALL
SELECT 'control file', 'CDB', name,
       ROUND(block_size * file_size_blks / 1048576, 1), NVL(status, 'OK')
FROM v$controlfile
UNION ALL
SELECT 'redo grupo ' || TO_CHAR(l.group#), 'CDB', f.member,
       ROUND(l.bytes / 1048576, 1), l.status
FROM v$log l JOIN v$logfile f ON f.group# = l.group#
ORDER BY 1, 2, 3;

PROMPT === 3. Grupos y miembros de redo ===
SELECT group#, members, ROUND(bytes / 1048576, 1) AS mb_por_miembro,
       status, archived
FROM v$log ORDER BY group#;

PROMPT === 4. Resumen de archivos actuales ===
SELECT 'datafiles' AS tipo, COUNT(*) AS archivos,
       ROUND(SUM(bytes) / 1048576, 1) AS mb
FROM v$datafile
UNION ALL
SELECT 'tempfiles', COUNT(*), ROUND(SUM(bytes) / 1048576, 1)
FROM v$tempfile
UNION ALL
SELECT 'control files', COUNT(*),
       ROUND(SUM(block_size * file_size_blks) / 1048576, 1)
FROM v$controlfile
UNION ALL
SELECT 'miembros redo', COUNT(*), ROUND(SUM(l.bytes) / 1048576, 1)
FROM v$log l JOIN v$logfile f ON f.group# = l.group#;

PROMPT === 5. Configuracion y archivos relacionados ===
SELECT name, NVL(value, '(sin configurar)') AS value
FROM v$parameter
WHERE name IN (
  'spfile', 'diagnostic_dest', 'db_create_file_dest',
  'db_recovery_file_dest', 'db_recovery_file_dest_size',
  'control_files', 'db_block_size'
)
ORDER BY name;

SELECT file_name AS ruta, format AS formato
FROM v$passwordfile_info;

SELECT name, value FROM v$diag_info
WHERE name IN ('ADR Home', 'Diag Alert', 'Diag Trace')
ORDER BY name;

SELECT name, log_mode, open_mode FROM v$database;

PROMPT === 6. Usuarios del password file ===
SELECT username, sysdba, sysoper, sysbackup, account_status
FROM v$pwfile_users;

PROMPT === 7. TEMP por contenedor ===
SELECT con_id, tablespace_name, contents, bigfile
FROM cdb_tablespaces
WHERE contents = 'TEMPORARY'
ORDER BY con_id, tablespace_name;

PROMPT === 8. FRA y destinos de archivado ===
SELECT name AS ruta,
       ROUND(space_limit / 1048576, 1) AS limite_mb,
       ROUND(space_used / 1048576, 1) AS usados_mb,
       ROUND(space_reclaimable / 1048576, 1) AS recuperables_mb
FROM v$recovery_file_dest;

SELECT dest_id, status, destination, error
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

PROMPT === 9. Esperas de redo acumuladas desde el arranque ===
SELECT event, total_waits,
       ROUND(time_waited_micro / NULLIF(total_waits, 0) / 1000, 3)
         AS media_ms
FROM v$system_event
WHERE event IN ('log file parallel write', 'log file sync')
  AND con_id = 0
ORDER BY event;

EXIT
