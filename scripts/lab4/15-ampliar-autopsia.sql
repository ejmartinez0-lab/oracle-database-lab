-- Lab 4 v3: corroborar destinos, errores y archivos.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET SQLFORMAT DEFAULT
SET LINESIZE 240 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
SET TRIMSPOOL ON
COLUMN name FORMAT A100
COLUMN member FORMAT A100
COLUMN destination FORMAT A100
COLUMN error FORMAT A90
COLUMN message_text FORMAT A180 WORD_WRAPPED
COLUMN value FORMAT A120

PROMPT === 1. Control files y redo sin cortar las rutas ===
SELECT name FROM v$controlfile ORDER BY name;
SELECT group#, member FROM v$logfile ORDER BY group#, member;

PROMPT === 2. Destinos de archivado configurados ===
SELECT dest_id, status, target, destination, error
FROM v$archive_dest
WHERE destination IS NOT NULL
ORDER BY dest_id;

PROMPT === 3. Ultimos archived logs registrados con nombre ===
SELECT thread#, sequence#,
       TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS completado,
       archived, deleted, status, name
FROM v$archived_log
WHERE name IS NOT NULL
ORDER BY completion_time DESC NULLS LAST, recid DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT === 4. Texto de los errores observados en las ultimas 24 horas ===
SELECT TO_CHAR(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS momento,
       message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (INSTR(message_text, 'ORA-00800') > 0
       OR INSTR(message_text, 'ORA-65025') > 0)
ORDER BY originating_timestamp;

PROMPT === 5. Destinos de diagnostico ===
SELECT name, value
FROM v$diag_info
WHERE name IN ('ADR Home', 'Diag Trace', 'Diag Alert')
ORDER BY name;

PROMPT === 6. Datafiles: asignacion actual frente a limite declarado ===
SELECT con_id,
       ROUND(SUM(bytes) / 1048576, 2) AS mib_asignados,
       ROUND(SUM(
         CASE WHEN autoextensible = 'YES' THEN GREATEST(bytes, maxbytes)
              ELSE bytes END
       ) / 1048576, 2) AS mib_limite_archivos
FROM cdb_data_files
GROUP BY con_id
ORDER BY con_id;

PROMPT === FIN DE LA AMPLIACION ===
