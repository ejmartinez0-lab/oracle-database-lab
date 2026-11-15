@scripts/ops/marca.sql
SPOOL docs/bitacora/lab4/evidencia/spool/&marca._07-parametros-lectura.spool.log

SET SQLFORMAT DEFAULT
SET LINESIZE 220 PAGESIZE 100 FEEDBACK OFF
COLUMN name FORMAT A30
COLUMN value FORMAT A85
COLUMN display_value FORMAT A16
COLUMN sid FORMAT A12

PROMPT === 1. Archivo de parametros utilizado ===
SELECT name, value
FROM v$parameter
WHERE name = 'spfile';

PROMPT === 2. Valores efectivos y posibilidad de modificacion ===
SELECT name, display_value, isdefault, ismodified,
       issys_modifiable AS sysmod,
       isses_modifiable AS sesmod,
       ispdb_modifiable AS pdbmod
FROM v$parameter
WHERE name IN (
  'db_name', 'db_block_size', 'compatible', 'cpu_count',
  'memory_size', 'memory_target', 'sga_target',
  'pga_aggregate_target', 'pga_aggregate_limit',
  'processes', 'sessions', 'open_cursors', 'db_files',
  'undo_tablespace', 'undo_retention', 'db_create_file_dest',
  'db_recovery_file_dest', 'db_recovery_file_dest_size',
  'vector_memory_size', 'inmemory_size', 'enable_pluggable_database'
)
ORDER BY name;

PROMPT === 3. Parametros especificados en el SPFILE, sin ocultos ===
SELECT sid, name, value
FROM v$spparameter
WHERE isspecified = 'TRUE'
AND name NOT LIKE '\_%' ESCAPE '\'
ORDER BY name, sid;

PROMPT === 4. Recuento de parametros ===
SELECT COUNT(*) AS documentados,
       SUM(CASE WHEN isdefault = 'FALSE' THEN 1 ELSE 0 END)
         AS no_por_defecto,
       SUM(CASE WHEN issys_modifiable = 'FALSE' THEN 1 ELSE 0 END)
         AS estaticos_segun_vista
FROM v$parameter;

PROMPT === 5. Estado inicial de los parametros del experimento ===
SELECT name, value
FROM v$parameter
WHERE name IN ('open_cursors', 'db_files', 'processes', 'memory_size')
ORDER BY name;

SELECT sid, name, value, isspecified
FROM v$spparameter
WHERE name IN ('open_cursors', 'db_files')
ORDER BY name, sid;

SPOOL OFF
