-- Lab 4 v3, Parte N: autopsia de solo lectura.
-- Uso: bash scripts/ops/ro.sh este_archivo.sql
-- Argumento SQL opcional: ruta del SPOOL mediante DEFINE previo.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET SQLFORMAT DEFAULT
SET LINESIZE 220 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
SET TRIMSPOOL ON
COLUMN instancia FORMAT A14
COLUMN host_name FORMAT A18
COLUMN usuario FORMAT A20
COLUMN contenedor FORMAT A16
COLUMN name FORMAT A36
COLUMN value FORMAT A100
COLUMN owner FORMAT A22
COLUMN grantee FORMAT A22
COLUMN tablespace_name FORMAT A22
COLUMN tipo FORMAT A20
COLUMN codigo FORMAT A12

SPOOL &salida_spool

PROMPT === 1. Identidad, instancia y base de datos ===
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

SELECT instance_name AS instancia, host_name, version_full,
       status, database_status,
       TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS arranque
FROM v$instance;

SELECT dbid, name, cdb, open_mode, log_mode,
       force_logging, flashback_on, database_role
FROM v$database;

SELECT con_id, name, open_mode
FROM v$containers ORDER BY con_id;

PROMPT === 2. Memoria ===
SELECT name, value
FROM v$parameter
WHERE name IN (
  'memory_target', 'sga_target', 'sga_max_size',
  'pga_aggregate_target', 'pga_aggregate_limit'
)
ORDER BY name;

SELECT name, ROUND(bytes / 1048576, 2) AS mib
FROM v$sgainfo
WHERE name IN (
  'Maximum SGA Size', 'Buffer Cache Size',
  'Shared Pool Size', 'Large Pool Size', 'Redo Buffers'
)
ORDER BY name;

PROMPT === 3. Procesos ===
SELECT CASE WHEN background IS NULL THEN 'No background'
            ELSE 'Background' END AS tipo,
       COUNT(*) AS procesos
FROM v$process
GROUP BY CASE WHEN background IS NULL THEN 'No background'
              ELSE 'Background' END;

SELECT pname, spid
FROM v$process
WHERE pname IN ('PMON', 'SMON', 'DBW0', 'LGWR', 'CKPT', 'LREG')
ORDER BY pname;

PROMPT === 4. Archivos y destinos ===
SELECT 'Datafiles' AS tipo, COUNT(*) AS archivos,
       ROUND(SUM(bytes) / 1048576, 2) AS mib
FROM v$datafile
UNION ALL
SELECT 'Tempfiles', COUNT(*), ROUND(SUM(bytes) / 1048576, 2)
FROM v$tempfile
UNION ALL
SELECT 'Control files', COUNT(*),
       ROUND(SUM(block_size * file_size_blks) / 1048576, 2)
FROM v$controlfile;

SELECT group#, bytes / 1048576 AS mib_por_miembro,
       members, status
FROM v$log ORDER BY group#;

SELECT name FROM v$controlfile ORDER BY name;

SELECT group#, member FROM v$logfile ORDER BY group#, member;

SELECT name, value
FROM v$parameter
WHERE name IN (
  'spfile', 'diagnostic_dest', 'db_recovery_file_dest',
  'db_recovery_file_dest_size', 'db_block_size'
)
ORDER BY name;

PROMPT === 5. Almacenamiento por contenedor ===
SELECT u.con_id, u.tablespace_name,
       ROUND(u.used_space * t.block_size / 1048576, 2) AS mib_usados,
       ROUND(u.tablespace_size * t.block_size / 1048576, 2)
         AS mib_capacidad_metrica,
       ROUND(u.used_percent, 2) AS pct_usado
FROM cdb_tablespace_usage_metrics u
JOIN cdb_tablespaces t
  ON t.con_id = u.con_id AND t.tablespace_name = u.tablespace_name
ORDER BY u.con_id, u.tablespace_name;

SELECT con_id, segment_type AS tipo, COUNT(*) AS segmentos,
       ROUND(SUM(bytes) / 1048576, 2) AS mib
FROM cdb_segments
GROUP BY con_id, segment_type
ORDER BY con_id, segment_type;

PROMPT === 6. Indices de los esquemas de negocio ===
SELECT i.con_id, i.owner, COUNT(*) AS indices,
       SUM(CASE WHEN i.uniqueness = 'UNIQUE' THEN 1 ELSE 0 END) AS unicos,
       MAX(i.blevel + 1) AS altura_max,
       SUM(CASE WHEN i.last_analyzed IS NULL THEN 1 ELSE 0 END)
         AS sin_fecha_estadisticas,
       SUM(CASE WHEN i.clustering_factor > 0.5 * t.num_rows
                THEN 1 ELSE 0 END) AS cf_mayor_media_tabla,
       SUM(CASE WHEN i.status NOT IN ('VALID', 'N/A')
                THEN 1 ELSE 0 END) AS no_validos
FROM cdb_indexes i
JOIN cdb_tables t
  ON t.con_id = i.con_id
 AND t.owner = i.table_owner
 AND t.table_name = i.table_name
WHERE i.owner LIKE 'ADMIN\_%' ESCAPE '\'
GROUP BY i.con_id, i.owner
ORDER BY i.con_id, i.owner;

PROMPT === 7. Usuarios y concesiones directas del rol DBA ===
SELECT con_id, common, COUNT(*) AS usuarios,
       SUM(CASE WHEN oracle_maintained = 'N' THEN 1 ELSE 0 END)
         AS no_mantenidos_por_oracle
FROM cdb_users
GROUP BY con_id, common
ORDER BY con_id, common;

SELECT r.con_id, r.grantee
FROM cdb_role_privs r
JOIN cdb_users u
  ON u.con_id = r.con_id AND u.username = r.grantee
WHERE r.granted_role = 'DBA' AND u.oracle_maintained = 'N'
ORDER BY r.con_id, r.grantee;

PROMPT === 8. Servicios activos ===
SELECT con_id, name, network_name
FROM v$active_services
ORDER BY con_id, name;

PROMPT === 9. Parametros seleccionados para revision ===
SELECT name, value, isdefault, ismodified
FROM v$parameter
WHERE name IN (
  'open_cursors', 'processes', 'sessions', 'db_files',
  'common_user_prefix', 'db_create_file_dest',
  'remote_login_passwordfile', 'local_listener'
)
ORDER BY name;

PROMPT === 10. Alert log del contenedor actual: ultimas 24 horas ===
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor,
       SYSTIMESTAMP AS momento_consulta
FROM dual;

SELECT REGEXP_SUBSTR(message_text, 'ORA-[0-9]{5}') AS codigo,
       COUNT(*) AS registros,
       TO_CHAR(MAX(originating_timestamp), 'YYYY-MM-DD HH24:MI:SS')
         AS ultima_aparicion
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]{5}')
GROUP BY REGEXP_SUBSTR(message_text, 'ORA-[0-9]{5}')
ORDER BY registros DESC, codigo;

PROMPT === FIN DE LA AUTOPSIA ===
SPOOL OFF
